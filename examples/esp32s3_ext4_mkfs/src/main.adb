--  Format a blank SPI NOR flash to ext4 ON-DEVICE, then use it (ESP32-S3)
--  =====================================================================
--  What it demonstrates  --  the pure-Ada mkfs, with no host involvement:
--
--      ESP32S3.Ext4.Mkfs  ->  Block_Dev.WL  ->  Block_Dev.W25Q_Source  ->  W25Q
--
--    Unlike esp32s3_ext4_flash (which installs a host-built image), this example
--    lays down a fresh ext4 filesystem ON THE BOARD with ESP32S3.Ext4.Mkfs -- a
--    minimal mkfs.ext4 (single block group, 4 KiB blocks, with or without a JBD2
--    journal -- see Use_Journal) -- straight onto the wear-leveling volume.  Then
--    it mounts the new filesystem read-write, creates a file and a subdirectory
--    with a file in it, STREAMS a 64 KB file with Append (256-byte chunks, never
--    holding the whole file -- into the single-indirect block map), commits
--    (through the journal if there is one, else a direct flush), remounts
--    read-only, reads the files back and byte-checks the streamed one.
--
--    Nothing is pre-baked: the filesystem is created from a blank volume on the
--    device.  The host's e2fsck validates the very same formatter in
--    libs/esp32s3_hal/test/mkfs_host.
--
--  This ERASES + WRITES the flash.  Safe here: the flash is dedicated to this
--  experiment and holds no other filesystem.
--
--  Build & run
--    ./x run esp32s3_ext4_mkfs       --  embedded profile; FS heap in PSRAM.
--
--  Output (with the flash wired)
--    [mkfs] format a blank SPI NOR flash to ext4 on-device (SPI2, CS=IO21)
--    [mkfs] flash ef 40 19, 4-byte mode: OK
--    [mkfs] wear-leveling volume: 65512 logical sectors
--    [mkfs] formatted ext4 (journaled); WL moves: <n>
--    [mkfs] mounted read-write; block size 4096
--    [mkfs] wrote /boot.txt, /logs/1.txt, streamed /logs/stream.bin; committed
--    [mkfs] remounted; reading back:
--    [mkfs] /boot.txt (42 bytes):
--    formatted on-device by ESP32S3.Ext4.Mkfs!
--    [mkfs] /logs/1.txt (14 bytes):
--    log entry one
--    [mkfs] /logs/stream.bin 65536 bytes via Append, readback PASS
--    [mkfs] done.
--
--  Hardware
--    W25Q256FV on SPI2: SCLK=GPIO1  MOSI=GPIO4  MISO=GPIO45  CS=GPIO21.
with Interfaces;    use Interfaces;
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.SPI;
with ESP32S3.W25Q;
with ESP32S3.GPIO;
with ESP32S3.Log;
with ESP32S3.Block_Dev; use ESP32S3.Block_Dev;
with ESP32S3.Block_Dev.W25Q_Source;
with ESP32S3.Block_Dev.WL;
with ESP32S3.Ext4;      use ESP32S3.Ext4;
with ESP32S3.Ext4.Mkfs;
with ESP32S3.Ext4.FS;
with ESP32S3.Ext4.Inode;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   package SPI renames ESP32S3.SPI;
   package W25Q renames ESP32S3.W25Q;
   package Log renames ESP32S3.Log;
   package BDW renames ESP32S3.Block_Dev.W25Q_Source;
   package WL renames ESP32S3.Block_Dev.WL;
   package FS renames ESP32S3.Ext4.FS;
   package Mkfs renames ESP32S3.Ext4.Mkfs;

   SCLK_Pin : constant := 1;
   MOSI_Pin : constant := 4;
   MISO_Pin : constant := 45;
   CS_Pin   : constant ESP32S3.GPIO.Pin_Id := 21;
   Clock_Hz : constant := 8_000_000;

   --  Streamed-file shape: 256 chunks of 256 bytes = 64 KiB (> 12 blocks, so the
   --  single-indirect map is used).  Byte at file offset O is O mod Pattern_Period;
   --  251 is the largest prime < 256, coprime with both the chunk and the 4 KiB
   --  block, so no boundary lines up with a repeat -- a mistake would show.
   Chunk_Bytes    : constant := 256;
   Chunk_Count    : constant := 256;
   Pattern_Period : constant := 251;

   --  Create a JBD2 journal (crash-safe commits) vs a no-journal volume.  A
   --  journal costs a fixed 4 MiB here, so for a small SPI flash the lighter
   --  no-journal volume (set this False) is usually the better choice; True
   --  exercises the on-device journaled formatter + the FS's JBD2 commit path.
   Use_Journal : constant Boolean := True;

   Flash : W25Q.Flash := (Host => SPI.SPI2, Clock_Hz => Clock_Hz, CS_Pin => CS_Pin, others => <>);

   ID      : W25Q.JEDEC_ID;
   Mode_OK : Boolean;
   Chip    : W25Q.Address;     --  flash size in bytes, detected from the JEDEC id

   Raw : aliased BDW.Source;
   Vol : aliased WL.Volume;
   Dev : Device;

   function To_Bytes (Str : String) return Byte_Array is
      Bytes : Byte_Array (0 .. Str'Length - 1);
   begin
      for I in Bytes'Range loop
         Bytes (I) := Interfaces.Unsigned_8 (Character'Pos (Str (Str'First + I)));
      end loop;
      return Bytes;
   end To_Bytes;

   --  Print Buf (0 .. Last-1) a line at a time, with a short drain between lines
   --  so the USB-Serial-JTAG ROM-printf FIFO does not drop the head of a write.
   procedure Print_Text (Buf : Byte_Array; Last : Natural) is
      Line  : String (1 .. 60);
      Count : Natural := 0;
      procedure End_Line is
      begin
         if Count > 0 then
            Log.Put (Line (1 .. Count));
            Count := 0;
         end if;
         Log.New_Line;
         delay until Clock + Milliseconds (20);
      end End_Line;
   begin
      for I in 0 .. Last - 1 loop
         declare
            Ch : constant Character := Character'Val (Natural (Buf (I)));
         begin
            if Ch = ASCII.LF then
               End_Line;
            else
               Count := Count + 1;
               Line (Count) := (if Character'Pos (Ch) in 32 .. 126 then Ch else '.');
               if Count = Line'Last then
                  Log.Put (Line);
                  Count := 0;
                  delay until Clock + Milliseconds (20);
               end if;
            end if;
         end;
      end loop;
      if Count > 0 then
         End_Line;
      end if;
   end Print_Text;

   procedure Show_File (M : in out FS.Mount; Path : String) is
      Info : ESP32S3.Ext4.Inode.Info;
      Buf  : Byte_Array (0 .. 255);
      Last : Natural;
   begin
      M.Stat (M.Lookup (Path), Info);
      M.Read_File (Info, 0, Buf, Last);
      Log.Put ("[mkfs] " & Path & " (");
      Log.Put (Last);
      Log.Put_Line (" bytes):");
      Print_Text (Buf, Last);
   end Show_File;
begin
   delay until Clock + Milliseconds (200);
   Log.Put_Line ("[mkfs] format a blank SPI NOR flash to ext4 on-device (SPI2, CS=IO21)");

   SPI.Setup (SPI.SPI2);
   SPI.Configure_Pins (SPI.SPI2, Sclk => SCLK_Pin, Mosi => MOSI_Pin, Miso => MISO_Pin);

   W25Q.Read_Identification (Flash, ID);
   W25Q.Initialize (Flash, Mode_OK);
   Log.Put ("[mkfs] flash ");
   Log.Put_Hex (Unsigned_32 (ID.Manufacturer), 2);
   Log.Put (' ');
   Log.Put_Hex (Unsigned_32 (ID.Memory_Type), 2);
   Log.Put (' ');
   Log.Put_Hex (Unsigned_32 (ID.Capacity), 2);
   Log.Put_Line (", 4-byte mode: " & (if Mode_OK then "OK" else "FAILED"));

   Chip := W25Q.Capacity_Bytes (ID);
   if ID.Manufacturer = 16#EF# and then Mode_OK and then Chip /= 0 then
      Log.Put ("[mkfs] detected ");
      Log.Put_Unsigned (Unsigned_32 (Chip / (1024 * 1024)));
      Log.Put_Line (" MB flash");
      BDW.Configure (Raw, Flash => Flash);    --  auto-size to whatever chip is fitted
      WL.Attach (Vol, BDW.Make (Raw'Access), Update_Rate => 64);
      WL.Format (Vol);
      Dev := WL.Make (Vol'Access);
      Log.Put ("[mkfs] wear-leveling volume: ");
      Log.Put_Unsigned (Unsigned_32 (WL.Logical_Sectors (Vol)));
      Log.Put_Line (" logical sectors");

      --  Create a fresh ext4 ON-DEVICE -- no host, no embedded image.
      Mkfs.Format (Dev, Volume_Label => "ESP32FLASH", Journal => Use_Journal);
      Log.Put ("[mkfs] formatted ext4 ");
      Log.Put ((if Use_Journal then "(journaled)" else "(no journal)"));
      Log.Put ("; WL moves: ");
      Log.Put_Unsigned (Unsigned_32 (WL.Move_Count (Vol)));
      Log.New_Line;

      --  Mount the new filesystem read-write and populate it.
      declare
         Mnt  : FS.Mount;
         Node : ESP32S3.Ext4.Inode_Number;
      begin
         Mnt.Open (Dev, Read_Only => False);
         Log.Put ("[mkfs] mounted read-write; block size ");
         Log.Put_Unsigned (Unsigned_32 (Mnt.Block_Size));
         Log.New_Line;

         Node := Mnt.Create_File ("/", "boot.txt");
         Mnt.Write_File (Node, To_Bytes ("formatted on-device by ESP32S3.Ext4.Mkfs!" & ASCII.LF));
         Mnt.Mkdir ("/", "logs");
         Node := Mnt.Create_File ("/logs", "1.txt");
         Mnt.Write_File (Node, To_Bytes ("log entry one" & ASCII.LF));

         --  Streaming: build the file a chunk at a time via Append, never holding
         --  the whole thing -- and large enough to use the single-indirect map.
         Node := Mnt.Create_File ("/logs", "stream.bin");
         declare
            Chunk : Byte_Array (0 .. Chunk_Bytes - 1);
         begin
            for Chunk_Index in 0 .. Chunk_Count - 1 loop
               for K in Chunk'Range loop
                  Chunk (K) := Unsigned_8 ((Chunk_Index * Chunk_Bytes + K) mod Pattern_Period);
               end loop;
               Mnt.Append (Node, Chunk);
            end loop;
         end;

         Mnt.Commit;
         Mnt.Close;
         Log.Put_Line
           ("[mkfs] wrote /boot.txt, /logs/1.txt, streamed /logs/stream.bin; committed");
      exception
         when others =>
            Log.Put_Line ("[mkfs] format/write FAILED");
      end;

      --  Remount and read the files back.
      declare
         Mnt : FS.Mount;
      begin
         Mnt.Open (Dev, Read_Only => True);
         Log.Put_Line ("[mkfs] remounted; reading back:");
         Show_File (Mnt, "/boot.txt");
         Show_File (Mnt, "/logs/1.txt");

         --  Verify the streamed file: every byte must equal offset mod Period.
         declare
            Info : ESP32S3.Ext4.Inode.Info;
            Got  : Byte_Array (0 .. Chunk_Bytes - 1);
            Last : Natural;
            Off  : Natural := 0;
            OK   : Boolean := True;
         begin
            Mnt.Stat (Mnt.Lookup ("/logs/stream.bin"), Info);
            while Off < Natural (Info.Size) loop
               Mnt.Read_File (Info, ESP32S3.Ext4.U64 (Off), Got, Last);
               exit when Last = 0;
               for K in 0 .. Last - 1 loop
                  if Got (K) /= Unsigned_8 ((Off + K) mod Pattern_Period) then
                     OK := False;
                  end if;
               end loop;
               Off := Off + Last;
            end loop;
            Log.Put ("[mkfs] /logs/stream.bin ");
            Log.Put_Unsigned (Unsigned_32 (Info.Size));
            Log.Put_Line
              (" bytes via Append, readback "
               & (if OK and then Off = Natural (Info.Size) then "PASS" else "FAIL"));
         end;
         Mnt.Close;
      exception
         when others =>
            Log.Put_Line ("[mkfs] remount/read FAILED");
      end;
   else
      Log.Put_Line ("[mkfs] no supported flash detected (id/size) -- check wiring / CS on IO21");
   end if;

   Log.Put_Line ("[mkfs] done.");
   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
