--  A real ext4 filesystem on wear-leveled SPI NOR flash (bare-metal ESP32-S3)
--  =========================================================================
--  What it demonstrates  --  the WHOLE storage stack, end to end:
--
--      ESP32S3.Ext4  ->  Block_Dev.WL  ->  Block_Dev.W25Q_Source  ->  ESP32S3.W25Q
--
--    The pure-Ada ext4 FS mounts and reads, but does not mkfs; and the external
--    W25Q flash cannot be written by the host flasher.  So a tiny ext4 image
--    (built on a host with mkfs.ext4, holding /hello.txt and /docs/readme.txt)
--    is embedded in the firmware SPARSELY -- only its non-zero 512-byte sectors,
--    see src/flash_image.ads + gen_image.sh.  At boot the example:
--      1. brings up the flash and FORMATS a fresh wear-leveling volume over it,
--      2. INSTALLS the image by writing every filesystem sector through the WL
--         device (the embedded non-zero sectors, zeros elsewhere) -- so it lands
--         remapped+wear-leveled on the flash,
--      3. MOUNTS it read-WRITE with ESP32S3.Ext4 over the same WL device: reads
--         /hello.txt and /docs/readme.txt, then CREATES + writes /written.txt and
--         commits it.  The image has no journal, so Commit takes the FS's direct
--         flush path (no JBD2) -- the ext4 journal-off gate in action.
--      4. REMOUNTS and reads /written.txt back, proving the write reached flash
--         through the full path: ext4 -> WL remap -> SPI NOR.
--
--    This ERASES + WRITES the flash.  Safe here: the flash is dedicated to this
--    experiment and holds no other filesystem.
--
--  Build & run
--    ./x run esp32s3_ext4_flash      --  embedded profile; FS heap in PSRAM.
--
--  Output (with the flash wired)
--    [ext4f] ext4 on wear-leveled SPI NOR flash (SPI2, CS=IO21)
--    [ext4f] flash ef 40 19, 4-byte mode: OK
--    [ext4f] installing ext4 image: 512 sectors (31 non-zero)...
--    [ext4f] installed; WL moves during install: 8
--    [ext4f] mounted ext4 read-write (no journal); block size 4096
--    [ext4f] /hello.txt (55 bytes):
--    hello from pure-Ada ext4 on wear-leveled SPI NOR flash!
--    [ext4f] /docs/readme.txt (127 bytes):
--    This file lives in a real ext4 image installed on a W25Q256FV
--    over the Block_Dev.WL wear-leveling FTL, read by ESP32S3.Ext4.
--    [ext4f] created + committed /written.txt; WL moves now: 9
--    [ext4f] remounted read-only; the file just written:
--    [ext4f] /written.txt (47 bytes):
--    written on-device, no-journal commit to flash!
--    [ext4f] done.
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
with ESP32S3.Ext4;                  use ESP32S3.Ext4;
with ESP32S3.Ext4.FS;
with ESP32S3.Ext4.Inode;
with Flash_Image;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   package SPI  renames ESP32S3.SPI;
   package W25Q renames ESP32S3.W25Q;
   package Log  renames ESP32S3.Log;
   package BDW  renames ESP32S3.Block_Dev.W25Q_Source;
   package WL   renames ESP32S3.Block_Dev.WL;
   package FS   renames ESP32S3.Ext4.FS;

   SCLK_Pin : constant := 1;
   MOSI_Pin : constant := 4;
   MISO_Pin : constant := 45;
   CS_Pin   : constant ESP32S3.GPIO.Pin_Id := 21;
   Clock_Hz : constant := 8_000_000;

   CS_Cell : aliased W25Q.Pin_Cell := (Pin => CS_Pin);
   Flash   : W25Q.Flash :=
     (Host => SPI.SPI2, CS => W25Q.GPIO_Select'Access, Ctx => CS_Cell'Address);

   ID      : W25Q.JEDEC_ID;
   Mode_OK : Boolean;
   Chip    : W25Q.Address;     --  flash size in bytes, detected from the JEDEC id

   Raw : aliased BDW.Source;
   Vol : aliased WL.Volume;
   Dev : Device;

   --  Print Buf (0 .. Last-1) as text, one whole LINE per ROM-printf call:
   --  newlines break lines, other non-printables become '.', and a very long
   --  line is flushed in <=60-char pieces to stay under the console FIFO limit.
   --  Drain pause: the ESP32-S3 USB-Serial-JTAG ROM printf drops the head of a
   --  write that lands while its small FIFO is still draining a previous one, so
   --  space console writes out a touch.
   procedure Drain is
   begin
      delay until Clock + Milliseconds (20);
   end Drain;

   procedure Print_Text (Buf : Byte_Array; Last : Natural) is
      Line : String (1 .. 60);
      N    : Natural := 0;
      procedure End_Line is
      begin
         if N > 0 then
            Log.Put (Line (1 .. N));
            N := 0;
         end if;
         Log.New_Line;
         Drain;
      end End_Line;
   begin
      for I in 0 .. Last - 1 loop
         declare
            C : constant Character := Character'Val (Natural (Buf (I)));
         begin
            if C = ASCII.LF then
               End_Line;
            else
               N := N + 1;
               Line (N) := (if Character'Pos (C) in 32 .. 126 then C else '.');
               if N = Line'Last then     --  flush a very long line in pieces
                  Log.Put (Line);
                  N := 0;
                  Drain;
               end if;
            end if;
         end;
      end loop;
      if N > 0 then
         End_Line;
      end if;
   end Print_Text;

   --  A Byte_Array holding the bytes of Str (for Write_File).
   function To_Bytes (Str : String) return Byte_Array is
      B : Byte_Array (0 .. Str'Length - 1);
   begin
      for I in B'Range loop
         B (I) := Interfaces.Unsigned_8 (Character'Pos (Str (Str'First + I)));
      end loop;
      return B;
   end To_Bytes;

   --  Read one file by path and print its contents.
   procedure Show_File (M : in out FS.Mount; Path : String) is
      Info : ESP32S3.Ext4.Inode.Info;
      Buf  : Byte_Array (0 .. 511);
      Last : Natural;
   begin
      M.Stat (M.Lookup (Path), Info);
      M.Read_File (Info, 0, Buf, Last);
      Log.Put ("[ext4f] " & Path & " (");
      Log.Put (Last);
      Log.Put_Line (" bytes):");
      Print_Text (Buf, Last);
   end Show_File;
begin
   delay until Clock + Milliseconds (200);
   Log.Put_Line ("[ext4f] ext4 on wear-leveled SPI NOR flash (SPI2, CS=IO21)");

   SPI.Setup (SPI.SPI2, Mode => 0, Clock_Hz => Clock_Hz);
   SPI.Configure_Pins (SPI.SPI2, Sclk => SCLK_Pin, Mosi => MOSI_Pin,
                       Miso => MISO_Pin, Cs => SPI.No_Pin);
   W25Q.Init_Pin (CS_Cell);

   W25Q.Read_Identification (Flash, ID);
   W25Q.Initialize (Flash, Mode_OK);
   Log.Put ("[ext4f] flash ");
   Log.Put_Hex (Unsigned_32 (ID.Manufacturer), 2); Log.Put (' ');
   Log.Put_Hex (Unsigned_32 (ID.Memory_Type), 2);  Log.Put (' ');
   Log.Put_Hex (Unsigned_32 (ID.Capacity), 2);
   Log.Put_Line (", 4-byte mode: " & (if Mode_OK then "OK" else "FAILED"));

   Chip := W25Q.Capacity_Bytes (ID);
   if ID.Manufacturer = 16#EF# and then Mode_OK and then Chip /= 0 then
      Log.Put ("[ext4f] detected ");
      Log.Put_Unsigned (Unsigned_32 (Chip / (1024 * 1024)));
      Log.Put_Line (" MB flash");
      --  Wear-leveling volume over the raw flash (auto-sized to the fitted chip).
      BDW.Configure (Raw, Flash => Flash);
      WL.Attach (Vol, BDW.Make (Raw'Access), Update_Rate => 64);
      WL.Format (Vol);
      Dev := WL.Make (Vol'Access);

      --  Install the embedded image: write EVERY filesystem sector through WL
      --  (the stored non-zero sectors, zeros for the rest), so the FS later
      --  reads the exact image back, remapped + wear-leveled.
      Log.Put ("[ext4f] installing ext4 image: ");
      Log.Put (Flash_Image.FS_Sectors);
      Log.Put (" sectors (");
      Log.Put (Flash_Image.N_Stored);
      Log.Put_Line (" non-zero)...");
      declare
         Next : Natural := 0;            --  index into Flash_Image.Indices
         Sec  : Sector;
      begin
         for LS in 0 .. Flash_Image.FS_Sectors - 1 loop
            if Next < Flash_Image.N_Stored
              and then Flash_Image.Indices (Next) = LS
            then
               for B in Sec'Range loop
                  Sec (B) := Flash_Image.Blob (Next * 512 + B);
               end loop;
               Next := Next + 1;
            else
               Sec := (others => 0);
            end if;
            Write_Sector (Dev, Sector_Index (LS), Sec);
         end loop;
      end;
      Log.Put ("[ext4f] installed; WL moves during install: ");
      Log.Put_Unsigned (Unsigned_32 (WL.Move_Count (Vol)));
      Log.New_Line;

      --  Mount the freshly-installed filesystem READ-WRITE: read the existing
      --  files, then create + write a new one and Commit.  The image has no
      --  journal, so Commit takes the FS's direct flush path (no JBD2).
      declare
         Mnt  : FS.Mount;
         Note : ESP32S3.Ext4.Inode_Number;
      begin
         Mnt.Open (Dev, Read_Only => False);
         Log.Put ("[ext4f] mounted ext4 read-write (no journal); block size ");
         Log.Put_Unsigned (Unsigned_32 (Mnt.Block_Size));
         Log.New_Line;

         Show_File (Mnt, "/hello.txt");
         Show_File (Mnt, "/docs/readme.txt");

         Note := Mnt.Create_File ("/", "written.txt");
         Mnt.Write_File
           (Note, To_Bytes ("written on-device, no-journal commit to flash!"
                            & ASCII.LF));
         Mnt.Commit;
         Mnt.Close;
         Log.Put ("[ext4f] created + committed /written.txt; WL moves now: ");
         Log.Put_Unsigned (Unsigned_32 (WL.Move_Count (Vol)));
         Log.New_Line;
      exception
         when others =>
            Log.Put_Line ("[ext4f] mount/write FAILED");
      end;

      --  Remount and read the just-written file back, proving it reached flash.
      declare
         Mnt : FS.Mount;
      begin
         Mnt.Open (Dev, Read_Only => True);
         Log.Put_Line ("[ext4f] remounted read-only; the file just written:");
         Show_File (Mnt, "/written.txt");
         Mnt.Close;
      exception
         when others =>
            Log.Put_Line ("[ext4f] remount/read FAILED");
      end;
   else
      Log.Put_Line ("[ext4f] no supported flash detected (id/size) -- check wiring / CS on IO21");
   end if;

   Log.Put_Line ("[ext4f] done.");
   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
