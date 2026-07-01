--  SD card over SPI on the bare-metal ESP32-S3 (no FreeRTOS, no IDF)
--  ================================================================
--  What it demonstrates
--    The reusable HAL driver ESP32S3.SD_SPI: bring a card up on SPI2, print
--    what it is, then do a NON-DESTRUCTIVE round-trip on one scratch sector --
--    read it, write the very same bytes back, read again, and check the re-read
--    matches.  Because the bytes written back are exactly what was just read, no
--    card content is lost, so this is safe to run on a card that holds a
--    filesystem.
--
--  Build & run
--    ./x run esp32s3_sd_spi          --  embedded profile (build.sh sets it)
--    Report prints over USB-Serial-JTAG via the ROM printf glue in glue.c.
--
--  Output (with a card wired)
--    [sd-spi] init: OK   card: SDHC/SDXC
--    [sd-spi] read#1: OK   first bytes = .. .. .. ..
--    [sd-spi] write-back: OK
--    [sd-spi] read#2: OK   first bytes = .. .. .. ..
--    [sd-spi] round-trip (re-read == original): PASS
--    [sd-spi] done.
--    With no card wired it prints "init: No_Card" and stops cleanly.
--
--  Hardware
--    A micro-SD breakout on four free GPIOs + 3V3 (edit the pin constants below
--    to match your board):
--      SCLK = GPIO12   MOSI = GPIO11   MISO = GPIO13   CS = GPIO10
--      card VDD = 3V3, VSS = GND, 10k pull-up on MISO recommended.
with Interfaces;   use Interfaces;
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.SD_SPI;
with ESP32S3.SPI;
with ESP32S3.Text_IO;   use ESP32S3.Text_IO;   --  buffered console (no rom-printf)

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   package SD_SPI renames ESP32S3.SD_SPI;
   package SPI    renames ESP32S3.SPI;
   use type SD_SPI.Status;
   use type SD_SPI.Block;

   package Nat_IO is new Integer_IO (Natural);

   --  Decimal with no field padding (like C "%d").
   procedure Put_Nat (V : Natural) is
   begin
      Nat_IO.Put (V, Width => 1);
   end Put_Nat;

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
         if Buf (I) /= '0' then First := I; exit; end if;
      end loop;
      if Buf'Last - First + 1 < Min_Digits then
         First := Buf'Last - Min_Digits + 1;
      end if;
      Put (Buf (First .. Buf'Last));
   end Put_Hex;

   function Kind_Name (K : ESP32S3.SD_SPI.Card_Kind) return String is
     (case K is
         when ESP32S3.SD_SPI.Unknown  => "Unknown",
         when ESP32S3.SD_SPI.SD_V1    => "SD v1.x (SDSC)",
         when ESP32S3.SD_SPI.SD_V2_SC => "SD v2 SDSC",
         when ESP32S3.SD_SPI.SD_V2_HC => "SDHC/SDXC");

   --  Console reporters, formerly esp_rom_printf natives in glue.c, now pure Ada
   --  over the buffered ESP32S3.Text_IO console.

   procedure Banner is
   begin
      Put_Line ("[sd-spi] bare-metal SD-over-SPI self-test (needs a wired card)");
   end Banner;

   procedure Report_Init (Status : ESP32S3.SD_SPI.Status;
                          Kind   : ESP32S3.SD_SPI.Card_Kind) is
   begin
      Put ("[sd-spi] init: ");  Put (ESP32S3.SD_SPI.Status'Image (Status));
      Put ("   card: ");        Put_Line (Kind_Name (Kind));
   end Report_Init;

   procedure Report_Write (Status : ESP32S3.SD_SPI.Status) is
   begin
      Put_Line ("[sd-spi] write-back: " & ESP32S3.SD_SPI.Status'Image (Status));
   end Report_Write;

   procedure Report_Verify (Ok : Boolean) is
   begin
      Put_Line ("[sd-spi] round-trip (re-read == original): "
                & (if Ok then "PASS" else "FAIL"));
   end Report_Verify;

   procedure Done is
   begin
      Put_Line ("[sd-spi] done.");
   end Done;

   --  SPI2 pins for the card (edit to match your board / SD breakout).
   SCLK_Pin : constant := 12;
   MOSI_Pin : constant := 11;
   MISO_Pin : constant := 13;
   CS_Pin   : constant := 10;

   --  Card bring-up runs at <=400 kHz (the SD spec's identification clock);
   --  the driver then switches to the data clock for block transfers.
   Init_Clock_Hz : constant := 400_000;
   Data_Clock_Hz : constant := 8_000_000;

   --  A scratch sector to round-trip (sector 8192).  Far from the partition
   --  table / FAT, so a card with a filesystem is left untouched (and we write
   --  back exactly what we read).
   Test_LBA : constant SD_SPI.Block_Address := 16#2000#;

   Card_Device : SD_SPI.Card;
   Card_Status : SD_SPI.Status;
   Original    : SD_SPI.Block;     --  the scratch sector as first read
   Read_Back   : SD_SPI.Block;     --  the same sector re-read after write-back

   --  Report a block read: status + the first four bytes.
   procedure Report_Read (Which  : Natural;
                          Status : SD_SPI.Status;
                          Data   : SD_SPI.Block) is
   begin
      Put ("[sd-spi] read#");  Put_Nat (Which);
      Put (": ");              Put (SD_SPI.Status'Image (Status));
      Put ("   first bytes = ");
      Put_Hex (Unsigned_64 (Data (0)), 2);  Put (" ");
      Put_Hex (Unsigned_64 (Data (1)), 2);  Put (" ");
      Put_Hex (Unsigned_64 (Data (2)), 2);  Put (" ");
      Put_Hex (Unsigned_64 (Data (3)), 2);
      New_Line;
   end Report_Read;
begin
   delay until Clock + Milliseconds (200);
   Banner;

   SD_SPI.Setup
     (Card_Device, Host => SPI.SPI2,
      Sclk => SCLK_Pin, Mosi => MOSI_Pin, Miso => MISO_Pin, Cs => CS_Pin,
      Init_Clock_Hz => Init_Clock_Hz, Data_Clock_Hz => Data_Clock_Hz);

   SD_SPI.Initialize (Card_Device, Card_Status);
   Report_Init (Card_Status, SD_SPI.Kind (Card_Device));

   if Card_Status = SD_SPI.OK then
      SD_SPI.Read_Block (Card_Device, Test_LBA, Original, Card_Status);
      Report_Read (1, Card_Status, Original);

      if Card_Status = SD_SPI.OK then
         --  Write the SAME bytes back (non-destructive), then re-read.
         SD_SPI.Write_Block (Card_Device, Test_LBA, Original, Card_Status);
         Report_Write (Card_Status);

         if Card_Status = SD_SPI.OK then
            SD_SPI.Read_Block (Card_Device, Test_LBA, Read_Back, Card_Status);
            Report_Read (2, Card_Status, Read_Back);
            Report_Verify (Card_Status = SD_SPI.OK
                           and then Original = Read_Back);
         end if;
      end if;
   end if;

   Done;

   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
