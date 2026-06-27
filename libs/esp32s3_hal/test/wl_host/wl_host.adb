--  Host brute-force test for ESP32S3.Block_Dev.WL (the wear-leveling FTL).
--
--  A RAM array stands in for the raw medium (a lower Block_Dev).  We Attach +
--  Format the FTL over it, then drive thousands of random logical-sector writes
--  -- enough to walk the move counter around the region many times -- checking
--  every read against a reference model.  Finally we re-Attach + Mount a FRESH
--  volume over the SAME RAM (simulating a power cycle) and re-verify every
--  logical sector, which exercises the ping-pong config recovery and proves the
--  map is reconstructed from persisted state alone.
--
--  Exit status 0 = all checks pass.
with Ada.Text_IO;  use Ada.Text_IO;
with Ada.Command_Line;
with System;
with Interfaces;   use Interfaces;
with ESP32S3.Block_Dev;       use ESP32S3.Block_Dev;
with ESP32S3.Block_Dev.WL;

procedure Wl_Host is

   package WL renames ESP32S3.Block_Dev.WL;

   --  RAM-backed lower device: 64 erase blocks * 8 = 512 physical sectors.
   Phys_Sectors : constant := 512;
   Phys_Blocks  : constant := Phys_Sectors / 8;          --  64
   type Ram_Array is array (0 .. Phys_Sectors - 1) of Sector;
   Ram : Ram_Array := (others => (others => 16#FF#));

   --  Per-physical-block write histogram (to show wear spreading).
   Hist : array (0 .. Phys_Blocks - 1) of Natural := (others => 0);

   procedure R_Read (Ctx : System.Address; LBA : Sector_Index; Data : out Sector)
   is
      pragma Unreferenced (Ctx);
   begin
      Data := Ram (Natural (LBA));
   end R_Read;

   procedure R_Write (Ctx : System.Address; LBA : Sector_Index; Data : Sector) is
      pragma Unreferenced (Ctx);
   begin
      Ram (Natural (LBA)) := Data;
      Hist (Natural (LBA) / 8) := Hist (Natural (LBA) / 8) + 1;
   end R_Write;

   function R_Count (Ctx : System.Address) return Sector_Index is
      pragma Unreferenced (Ctx);
   begin
      return Phys_Sectors;
   end R_Count;

   Lower : constant Device :=
     (Ctx   => System.Null_Address,
      Read  => R_Read'Unrestricted_Access,
      Write => R_Write'Unrestricted_Access,
      Count => R_Count'Unrestricted_Access);

   --  Reference model: the last bytes written to each logical sector.
   Vol     : aliased WL.Volume;
   Fmt     : Boolean;
   Dev     : Device;
   N_Log   : Sector_Index;

   --  Deterministic LCG so a failure is reproducible.
   Seed : Unsigned_64 := 16#1234_5678#;
   function Rand return Unsigned_64 is
   begin
      Seed := Seed * 6364136223846793005 + 1442695040888963407;
      return Shift_Right (Seed, 17);
   end Rand;

   --  A sector pattern unique to (LBA, Tag): so each rewrite is distinguishable.
   function Pattern (LBA : Sector_Index; Tag : Unsigned_8) return Sector is
      S : Sector;
   begin
      for I in S'Range loop
         S (I) := Unsigned_8 ((Natural (LBA) + I * 7 + Natural (Tag) * 31) mod 256);
      end loop;
      return S;
   end Pattern;

   WL_Failures : Natural := 0;
   N_Writes    : constant := 40_000;

   procedure Check (Cond : Boolean; Msg : String) is
   begin
      if not Cond then
         WL_Failures := WL_Failures + 1;
         if WL_Failures <= 8 then
            Put_Line ("  FAIL: " & Msg);
         end if;
      end if;
   end Check;

begin
   WL.Attach (Vol, Lower, Update_Rate => 4);     --  small rate => many moves
   WL.Format (Vol);
   Dev   := WL.Make (Vol'Access);
   N_Log := WL.Logical_Sectors (Vol);
   Put_Line ("wl_host: " & N_Log'Image & " logical sectors over"
             & Sector_Index'Image (Phys_Sectors) & " physical");

   --  Tag the latest write to each logical sector so reads can be checked.
   declare
      Tag : array (0 .. Natural (N_Log) - 1) of Unsigned_8 := (others => 0);
      Written : array (0 .. Natural (N_Log) - 1) of Boolean := (others => False);
      LBA : Sector_Index;
      Got : Sector;
   begin
      for I in 1 .. N_Writes loop
         LBA := Sector_Index (Rand mod Unsigned_64 (N_Log));
         Tag (Natural (LBA)) := Tag (Natural (LBA)) + 1;
         Written (Natural (LBA)) := True;
         Write_Sector (Dev, LBA, Pattern (LBA, Tag (Natural (LBA))));

         --  Spot-check a random already-written sector each iteration.
         declare
            Q : constant Sector_Index :=
              Sector_Index (Rand mod Unsigned_64 (N_Log));
         begin
            if Written (Natural (Q)) then
               Read_Sector (Dev, Q, Got);
               Check (Got = Pattern (Q, Tag (Natural (Q))),
                      "live read mismatch at" & Q'Image);
            end if;
         end;
      end loop;

      --  Full sweep against the model before the simulated power cycle.
      for L in 0 .. Natural (N_Log) - 1 loop
         if Written (L) then
            Read_Sector (Dev, Sector_Index (L), Got);
            Check (Got = Pattern (Sector_Index (L), Tag (L)),
                   "pre-remount mismatch at" & L'Image);
         end if;
      end loop;
      Put_Line ("wl_host: live + full-sweep done (" & WL_Failures'Image
                & " failures so far)");

      --  Simulated power cycle: brand-new Volume over the SAME Ram, Mount, verify.
      declare
         Vol2 : aliased WL.Volume;
         Dev2 : Device;
      begin
         WL.Attach (Vol2, Lower, Update_Rate => 4);
         WL.Mount (Vol2, Fmt);
         Check (Fmt, "Mount did not find a valid config after writes");
         Dev2 := WL.Make (Vol2'Access);
         for L in 0 .. Natural (N_Log) - 1 loop
            if Written (L) then
               Read_Sector (Dev2, Sector_Index (L), Got);
               Check (Got = Pattern (Sector_Index (L), Tag (L)),
                      "post-remount mismatch at" & L'Image);
            end if;
         end loop;
      end;
   end;

   --  Wear-spreading: hammer ONE logical block on a fresh volume and confirm its
   --  writes land on MANY distinct physical blocks (a no-WL identity map would
   --  pin them all to one).  D = Phys_Blocks - 2 data+spare blocks here.
   Ram  := (others => (others => 16#FF#));
   Hist := (others => 0);
   declare
      Vol3   : aliased WL.Volume;
      Dev3   : Device;
      Hot    : constant Sector_Index := 5 * 8;        --  logical block 5, sector 0
      Hammer : constant := 8_000;
      Distinct : Natural := 0;
      Max_Blk  : Natural := 0;
      Data_Blocks : constant := Phys_Blocks - 2;      --  62 (config takes 2)
   begin
      WL.Attach (Vol3, Lower, Update_Rate => 4);
      WL.Format (Vol3);
      Dev3 := WL.Make (Vol3'Access);
      for I in 1 .. Hammer loop
         Write_Sector (Dev3, Hot, Pattern (Hot, Unsigned_8 (I mod 256)));
      end loop;
      --  Count, over the DATA region only, how many blocks took writes and the
      --  worst single-block load.
      for B in 0 .. Data_Blocks - 1 loop
         if Hist (B) > 0 then
            Distinct := Distinct + 1;
         end if;
         Max_Blk := Natural'Max (Max_Blk, Hist (B));
      end loop;
      Put_Line ("wl_host: hammered 1 logical block" & Hammer'Image
                & " times -> touched" & Distinct'Image & " of"
                & Data_Blocks'Image & " physical blocks, worst-block writes="
                & Max_Blk'Image);
      Check (Distinct >= Data_Blocks - 4,
             "wear not spread: only" & Distinct'Image & " physical blocks used");
      Check (Max_Blk <= Hammer / 4,
             "wear concentrated: one block took" & Max_Blk'Image & " writes");
   end;

   if WL_Failures = 0 then
      Put_Line ("wl_host: PASS (remap + persistence + wear-spreading verified over"
                & N_Writes'Image & " writes)");
      Ada.Command_Line.Set_Exit_Status (0);
   else
      Put_Line ("wl_host: FAIL ("
                & WL_Failures'Image & " mismatches)");
      Ada.Command_Line.Set_Exit_Status (1);
   end if;
end Wl_Host;
