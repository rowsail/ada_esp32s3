--  Dynamic wear-leveling FTL over the W25Q SPI NOR flash (bare-metal ESP32-S3)
--  =========================================================================
--  What it demonstrates
--    The stack  Block_Dev.WL  ->  Block_Dev.W25Q_Source  ->  ESP32S3.W25Q.
--    ESP32S3.Block_Dev.WL is the "Option B" dynamic wear-leveling FTL: it remaps
--    512-byte logical sectors over the flash so a hot logical block migrates
--    across physical blocks instead of wearing one out, keeping its O(1) state
--    in two ping-pong config blocks.
--
--    The example formats a fresh volume, writes a distinct pattern to a band of
--    logical sectors -- enough writes to trigger several "moves" (mapping
--    rotations) -- and verifies every read-back.  It then ATTACHES A BRAND-NEW
--    volume over the same flash and Mounts it (no format): if the ping-pong
--    config recovers the move counter, every sector still reads back correctly.
--
--  This ERASES + WRITES the flash (low data band + the two config blocks near
--  the top of the chip).  Safe here: the flash is dedicated to this experiment.
--
--  Build & run
--    ./x run esp32s3_wl             --  embedded profile (build.sh sets it)
--
--  Output (with the flash wired)
--    [wl] dynamic wear-leveling FTL over W25Q SPI NOR (SPI2, CS=IO21)
--    [wl] flash JEDEC ef 40 19, 4-byte mode: OK
--    [wl] attached: 65512 logical sectors; formatted
--    [wl] wrote 32 sectors; moves performed: 8
--    [wl] read-back (same volume): PASS
--    [wl] remount (fresh volume + Mount) read-back: PASS
--    [wl] done.
--
--  Hardware
--    W25Q256FV on SPI2: SCLK=GPIO1  MOSI=GPIO4  MISO=GPIO45  CS=GPIO21.
with Interfaces;    use Interfaces;
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.SPI;
with ESP32S3.W25Q;
with ESP32S3.GPIO;
with ESP32S3.Log;
with ESP32S3.Block_Dev;             use ESP32S3.Block_Dev;
with ESP32S3.Block_Dev.W25Q_Source;
with ESP32S3.Block_Dev.WL;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   package SPI  renames ESP32S3.SPI;
   package W25Q renames ESP32S3.W25Q;
   package Log  renames ESP32S3.Log;
   package BDW  renames ESP32S3.Block_Dev.W25Q_Source;
   package WL   renames ESP32S3.Block_Dev.WL;
   use type Sector;

   SCLK_Pin : constant := 1;
   MOSI_Pin : constant := 4;
   MISO_Pin : constant := 45;
   CS_Pin   : constant ESP32S3.GPIO.Pin_Id := 21;
   Clock_Hz : constant := 8_000_000;

   --  Flash device + its single-GPIO chip select on IO21.
   CS_Cell : aliased W25Q.Pin_Cell := (Pin => CS_Pin);
   Flash   : W25Q.Flash :=
     (Host => SPI.SPI2, CS => W25Q.GPIO_Select'Access, Ctx => CS_Cell'Address);

   ID       : W25Q.JEDEC_ID;
   Mode_OK  : Boolean;
   Chip     : W25Q.Address;    --  flash size in bytes, detected from the JEDEC id

   --  Lower (raw) block device, then the wear-leveling volume over it.
   Raw      : aliased BDW.Source;
   Lower    : Device;
   Vol      : aliased WL.Volume;
   Dev      : Device;
   Formatted : Boolean;

   N_Sectors : constant := 32;          --  logical sectors to write/verify
   Update_Rate : constant := 4;         --  a move every 4 writes -> several moves

   --  A pattern unique to each logical sector.
   function Pattern (LBA : Sector_Index) return Sector is
      S : Sector;
   begin
      for I in S'Range loop
         S (I) := Unsigned_8 ((Natural (LBA) * 7 + I * 3 + 16#5A#) mod 256);
      end loop;
      return S;
   end Pattern;

   --  Read LBA 0 .. N_Sectors-1 from Target and check each against Pattern.
   function Verify (Target : Device) return Boolean is
      Got : Sector;
      OK  : Boolean := True;
   begin
      for L in 0 .. N_Sectors - 1 loop
         Read_Sector (Target, Sector_Index (L), Got);
         if Got /= Pattern (Sector_Index (L)) then
            OK := False;
         end if;
      end loop;
      return OK;
   end Verify;
begin
   delay until Clock + Milliseconds (200);
   Log.Put_Line ("[wl] dynamic wear-leveling FTL over W25Q SPI NOR (SPI2, CS=IO21)");

   SPI.Setup (SPI.SPI2, Mode => 0, Clock_Hz => Clock_Hz);
   SPI.Configure_Pins (SPI.SPI2, Sclk => SCLK_Pin, Mosi => MOSI_Pin,
                       Miso => MISO_Pin, Cs => SPI.No_Pin);
   W25Q.Init_Pin (CS_Cell);

   W25Q.Read_Identification (Flash, ID);
   W25Q.Initialize (Flash, Mode_OK);
   Log.Put ("[wl] flash JEDEC ");
   Log.Put_Hex (Unsigned_32 (ID.Manufacturer), 2); Log.Put (' ');
   Log.Put_Hex (Unsigned_32 (ID.Memory_Type), 2);  Log.Put (' ');
   Log.Put_Hex (Unsigned_32 (ID.Capacity), 2);
   Log.Put_Line (", 4-byte mode: " & (if Mode_OK then "OK" else "FAILED"));

   Chip := W25Q.Capacity_Bytes (ID);
   if ID.Manufacturer = 16#EF# and then Mode_OK and then Chip /= 0 then
      Log.Put ("[wl] detected ");
      Log.Put_Unsigned (Unsigned_32 (Chip / (1024 * 1024)));
      Log.Put_Line (" MB flash");
      --  Raw flash as a 512-byte block device (auto-sized), then the WL volume.
      BDW.Configure (Raw, Flash => Flash);
      Lower := BDW.Make (Raw'Access);

      WL.Attach (Vol, Lower, Update_Rate => Update_Rate);
      WL.Format (Vol);
      Dev := WL.Make (Vol'Access);
      Log.Put ("[wl] attached: ");
      Log.Put_Unsigned (Unsigned_32 (WL.Logical_Sectors (Vol)));
      Log.Put_Line (" logical sectors; formatted");

      for L in 0 .. N_Sectors - 1 loop
         Write_Sector (Dev, Sector_Index (L), Pattern (Sector_Index (L)));
      end loop;
      Log.Put ("[wl] wrote ");
      Log.Put (N_Sectors);
      Log.Put (" sectors; moves performed: ");
      Log.Put_Unsigned (Unsigned_32 (WL.Move_Count (Vol)));
      Log.New_Line;

      Log.Put_Line ((if Verify (Dev) then "[wl] read-back (same volume): PASS"
                     else "[wl] read-back (same volume): FAIL"));

      --  Simulated power cycle: a brand-new volume Mounted from the config alone.
      declare
         Vol2 : aliased WL.Volume;
         Dev2 : Device;
      begin
         WL.Attach (Vol2, Lower, Update_Rate => Update_Rate);
         WL.Mount (Vol2, Formatted);
         Dev2 := WL.Make (Vol2'Access);
         Log.Put_Line
           ((if Formatted and then Verify (Dev2)
             then "[wl] remount (fresh volume + Mount) read-back: PASS"
             else "[wl] remount (fresh volume + Mount) read-back: FAIL"));
      end;
   else
      Log.Put_Line ("[wl] no supported flash detected (id/size) -- check wiring / CS on IO21");
   end if;

   Log.Put_Line ("[wl] done.");
   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
