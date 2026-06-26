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
with Interfaces.C; use Interfaces.C;
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.SD_SPI;
with ESP32S3.SPI;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   package SD_SPI renames ESP32S3.SD_SPI;
   package SPI    renames ESP32S3.SPI;
   use type SD_SPI.Status;
   use type SD_SPI.Block;

   --  Console report -- ROM printf glue in glue.c (the reliable path here).
   procedure Banner;  pragma Import (C, Banner, "native_sd_banner");
   procedure Init_R (Status, Kind : int);  pragma Import (C, Init_R, "native_sd_init");
   procedure Read_R (Which, Status, B0, B1, B2, B3 : int);
   pragma Import (C, Read_R, "native_sd_read");
   procedure Write_R (Status : int);  pragma Import (C, Write_R, "native_sd_write");
   procedure Verify_R (Ok : int);     pragma Import (C, Verify_R, "native_sd_verify");
   procedure Done;    pragma Import (C, Done, "native_sd_done");

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

   --  Report a block read: pass status + the first four bytes to the C glue.
   procedure Report_Read (Which  : int;
                          Status : SD_SPI.Status;
                          Data   : SD_SPI.Block) is
   begin
      Read_R (Which, int (SD_SPI.Status'Pos (Status)),
              int (Data (0)), int (Data (1)), int (Data (2)), int (Data (3)));
   end Report_Read;
begin
   delay until Clock + Milliseconds (200);
   Banner;

   SD_SPI.Setup
     (Card_Device, Host => SPI.SPI2,
      Sclk => SCLK_Pin, Mosi => MOSI_Pin, Miso => MISO_Pin, Cs => CS_Pin,
      Init_Clock_Hz => Init_Clock_Hz, Data_Clock_Hz => Data_Clock_Hz);

   SD_SPI.Initialize (Card_Device, Card_Status);
   Init_R (int (SD_SPI.Status'Pos (Card_Status)),
           int (SD_SPI.Card_Kind'Pos (SD_SPI.Kind (Card_Device))));

   if Card_Status = SD_SPI.OK then
      SD_SPI.Read_Block (Card_Device, Test_LBA, Original, Card_Status);
      Report_Read (1, Card_Status, Original);

      if Card_Status = SD_SPI.OK then
         --  Write the SAME bytes back (non-destructive), then re-read.
         SD_SPI.Write_Block (Card_Device, Test_LBA, Original, Card_Status);
         Write_R (int (SD_SPI.Status'Pos (Card_Status)));

         if Card_Status = SD_SPI.OK then
            SD_SPI.Read_Block (Card_Device, Test_LBA, Read_Back, Card_Status);
            Report_Read (2, Card_Status, Read_Back);
            Verify_R
              (Boolean'Pos (Card_Status = SD_SPI.OK
                            and then Original = Read_Back));
         end if;
      end if;
   end if;

   Done;

   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
