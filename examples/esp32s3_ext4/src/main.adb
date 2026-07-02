--  Ada ext4-on-SD self-test (ESP32-S3, no FreeRTOS, no IDF)
--  ========================================================
--  What it demonstrates:
--    The pure-Ada filesystem (ESP32S3.Ext4) mounting a real ext4 (or ext2/3)
--    SD card layered over the SD-over-SPI block driver, then reading a file --
--    SD init, mount (reporting the block size), and the first bytes of
--    /hello.txt.  No ESP-IDF, no FreeRTOS.
--
--  Build & run:
--    ./x run esp32s3_ext4
--    Built as the EMBEDDED profile (build.sh sets ESP32S3_RTS_PROFILE=embedded),
--    because the filesystem uses exceptions + finalization.
--
--  Output (over USB-Serial-JTAG, via the ROM esp_rom_printf glue):
--    With a wired ext4 card holding /hello.txt = "hello...":
--      [ext4] SD card init: OK
--      [ext4] mount: OK   block size = 4096
--      [ext4] read /hello.txt: OK   first bytes = 68 65 6c 6c
--      [ext4] done.
--    With NO card wired it prints "SD card init: FAILED" and stops cleanly --
--    the boot + SD + mount path still runs; only the OK lines need a real card.
--
--  Hardware:
--    An SD card breakout on SPI2 (edit the pin constants below to match yours):
--      SCLK = GPIO12   MOSI = GPIO11   MISO = GPIO13   CS = GPIO10   VDD = 3V3.
--    Card setup on a Linux host:
--      mkfs.ext4 /dev/sdX1   (or ext2/3); then put a file at /hello.txt
--    Reading a default mkfs.ext4 card works; WRITES need a NON-metadata_csum
--    filesystem.  The SD block driver itself is not yet on-card-verified (see
--    its README), so bring that up first.
with Interfaces;    use Interfaces;
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.SD_SPI;
with ESP32S3.SPI;
with ESP32S3.Block_Dev;
with ESP32S3.Block_Dev.SD_SPI_Source;
with ESP32S3.Text_IO; use ESP32S3.Text_IO;   --  buffered console
with ESP32S3.Ext4;    use ESP32S3.Ext4;
with ESP32S3.Ext4.FS;
with ESP32S3.Ext4.Inode;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   --  Console reporters, formerly esp_rom_printf natives in glue.c, now pure Ada
   --  over the buffered ESP32S3.Text_IO console.

   --  Bare lowercase hex, zero-padded to Min_Digits (like C "%0Nx").
   Hex_Digit : constant array (0 .. 15) of Character := "0123456789abcdef";
   procedure Put_Hex (V : Unsigned_64; Min_Digits : Positive := 1) is
      Buf   : String (1 .. 16);
      X     : Unsigned_64 := V;
      First : Natural := Buf'Last;
   begin
      for I in reverse Buf'Range loop
         Buf (I) := Hex_Digit (Natural (X and 16#F#));
         X := Shift_Right (X, 4);
      end loop;
      for I in Buf'Range loop
         if Buf (I) /= '0' then
            First := I;
            exit;
         end if;
      end loop;
      if Buf'Last - First + 1 < Min_Digits then
         First := Buf'Last - Min_Digits + 1;
      end if;
      Put (Buf (First .. Buf'Last));
   end Put_Hex;

   procedure Banner is
   begin
      Put_Line ("[ext4] bare-metal pure-Ada ext4 over SD-over-SPI (needs a wired ext4 card)");
   end Banner;

   procedure Card_Result (Ok : Boolean) is
   begin
      Put_Line ("[ext4] SD card init: " & (if Ok then "OK" else "FAILED"));
   end Card_Result;

   procedure Mount_Result (Ok : Boolean; Block_Size : Natural) is
   begin
      Put ("[ext4] mount: " & (if Ok then "OK" else "FAILED") & "   block size = ");
      declare
         package Nat_IO is new Integer_IO (Natural);
      begin
         Nat_IO.Put (Block_Size, Width => 1);
      end;
      New_Line;
   end Mount_Result;

   procedure Read_Result (Ok : Boolean; B0, B1, B2, B3 : Natural) is
   begin
      Put ("[ext4] read /hello.txt: " & (if Ok then "OK" else "FAILED") & "   first bytes = ");
      Put_Hex (Unsigned_64 (B0), 2);
      Put (" ");
      Put_Hex (Unsigned_64 (B1), 2);
      Put (" ");
      Put_Hex (Unsigned_64 (B2), 2);
      Put (" ");
      Put_Hex (Unsigned_64 (B3), 2);
      New_Line;
   end Read_Result;

   procedure Done is
   begin
      Put_Line ("[ext4] done.");
   end Done;

   use type ESP32S3.SD_SPI.Status;

   --  SD-card breakout wiring on SPI2 (see the header).  Edit to your board.
   SD_Sclk : constant := 12;
   SD_Mosi : constant := 11;
   SD_Miso : constant := 13;
   SD_Cs   : constant := 10;

   --  Let the USB-Serial-JTAG console settle before the first line is printed.
   Console_Settle_Delay : constant Time_Span := Milliseconds (200);

   --  We read the file from its start into a small fixed buffer, and report
   --  only the first few bytes (glue.c prints exactly four: enough to recognise
   --  "hell" = 68 65 6c 6c).
   File_Start_Offset : constant U64 := 0;
   Read_Buffer_Size  : constant Natural := 16;   --  bytes read in one go

   Card        : aliased ESP32S3.SD_SPI.Card;
   Card_Status : ESP32S3.SD_SPI.Status;   --  SD init outcome (OK / error)
begin
   delay until Clock + Console_Settle_Delay;
   Banner;

   ESP32S3.SD_SPI.Setup
     (Card,
      Host => ESP32S3.SPI.SPI2,
      Sclk => SD_Sclk,
      Mosi => SD_Mosi,
      Miso => SD_Miso,
      Cs   => SD_Cs);
   ESP32S3.SD_SPI.Initialize (Card, Card_Status);
   Card_Result (Card_Status = ESP32S3.SD_SPI.OK);

   --  Only attempt the mount/read once the card itself answered.
   if Card_Status = ESP32S3.SD_SPI.OK then
      declare
         --  Present the card as a generic block device to the filesystem.
         Device : constant ESP32S3.Block_Dev.Device :=
           ESP32S3.Block_Dev.SD_SPI_Source.Make (Card'Access);
         Mount  : ESP32S3.Ext4.FS.Mount;
      begin
         Mount.Open (Device, Read_Only => True);
         Mount_Result (True, Natural (Mount.Block_Size));

         declare
            File_Info  : ESP32S3.Ext4.Inode.Info;
            Read_Buf   : Byte_Array (0 .. Read_Buffer_Size - 1);
            Bytes_Read : Natural;
         begin
            Mount.Stat (Mount.Lookup ("/hello.txt"), File_Info);
            Mount.Read_File (File_Info, File_Start_Offset, Read_Buf, Bytes_Read);
            Read_Result
              (True,
               Natural (Read_Buf (0)),
               Natural (Read_Buf (1)),
               Natural (Read_Buf (2)),
               Natural (Read_Buf (3)));
         exception
            --  Lookup/stat/read failed (missing file, bad fs, I/O error).
            when others =>
               Read_Result (False, 0, 0, 0, 0);
         end;
      exception
         --  Mounting failed (not an ext2/3/4 card, or an unreadable superblock).
         when others =>
            Mount_Result (False, 0);
      end;
   end if;

   Done;

   --  Nothing left to do; idle forever rather than return into the runtime.
   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
