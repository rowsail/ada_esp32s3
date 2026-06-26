--  Ada native SD/MMC-host self-test (ESP32-S3, no FreeRTOS, no IDF)
--  ================================================================
--  What it demonstrates
--    The reusable HAL driver ESP32S3.SDMMC: it brings up the dedicated SDHOST
--    controller on Slot1 in 4-bit mode (clock + command + four data lines),
--    identifies the card, then does a NON-DESTRUCTIVE round-trip on one scratch
--    sector -- read it, write the same bytes back, read it again, and confirm
--    the re-read matches.  Because the bytes written are exactly what was just
--    read, no card content is lost.
--
--  Build & run
--    ./x run esp32s3_sdmmc           (build + flash + monitor)
--    Built as the EMBEDDED profile here (build.sh sets ESP32S3_RTS_PROFILE
--    =embedded).  The report prints over the USB-Serial-JTAG console via the
--    ROM esp_rom_printf glue in glue.c.
--
--  Output
--    With a real card wired the run prints, in order:
--      [sdmmc] init: OK   card: SDHC/SDXC   bus: 4-bit
--      [sdmmc] read#1: OK   first bytes = ...
--      [sdmmc] write-back: OK
--      [sdmmc] read#2: OK   first bytes = ...
--      [sdmmc] round-trip (re-read == original): PASS
--      [sdmmc] done.
--    PASS is the success line.  With NO card wired it prints "init: No_Card"
--    and stops cleanly at "done." (the in-tree smoke build).
--
--  Hardware
--    An SD card on Slot1, plus pull-ups (10k-50k) on CMD and every DATA line
--    (the SD bus idles high).  Default pins (route any free GPIOs):
--      CLK = GPIO14  CMD = GPIO15  D0 = GPIO2  D1 = GPIO4  D2 = GPIO12  D3 = GPIO13
--      card VDD = 3V3, VSS = GND.
with Interfaces;   use Interfaces;
with Interfaces.C; use Interfaces.C;
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.SDMMC;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   --  Console reporters, each implemented in glue.c (formats over esp_rom_printf).
   procedure Banner;
   pragma Import (C, Banner, "native_sdmmc_banner");
   procedure Init_R (Status, Kind, Width : int);
   pragma Import (C, Init_R, "native_sdmmc_init");
   procedure Read_R (Which, Status, B0, B1, B2, B3 : int);
   pragma Import (C, Read_R, "native_sdmmc_read");
   procedure Write_R (Status : int);
   pragma Import (C, Write_R, "native_sdmmc_write");
   procedure Verify_R (Ok : int);
   pragma Import (C, Verify_R, "native_sdmmc_verify");
   procedure Done;
   pragma Import (C, Done, "native_sdmmc_done");

   use type ESP32S3.SDMMC.Status;
   use type ESP32S3.SDMMC.Block;

   --  Slot1 SD-bus pins (GPIO numbers).  Routed through the GPIO matrix, so any
   --  free GPIO works; pull-ups on CMD/DATA are external (see header).
   Clk_Pin : constant := 14;
   Cmd_Pin : constant := 15;
   D0_Pin  : constant := 2;
   D1_Pin  : constant := 4;
   D2_Pin  : constant := 12;
   D3_Pin  : constant := 13;

   --  Identify the card slowly (<=400 kHz per the SD init spec), then run data
   --  transfers at 20 MHz.
   Init_Clock_Hz : constant := 400_000;
   Data_Clock_Hz : constant := 20_000_000;

   --  Bus width reported to the console: 4-bit (D0..D3) is what we set up.
   Bus_Width_Bits : constant := 4;

   --  Scratch sector for the non-destructive round-trip: LBA 0x2000 = sector
   --  8192.  Well past sector 0 (the partition table / boot sector).
   Test_LBA : constant ESP32S3.SDMMC.Block_Address := 16#2000#;

   C    : ESP32S3.SDMMC.Card;
   St   : ESP32S3.SDMMC.Status;
   Orig : ESP32S3.SDMMC.Block;   --  bytes read first, then written back
   Back : ESP32S3.SDMMC.Block;   --  the re-read, compared against Orig

   procedure Report_Read (Which : int; S : ESP32S3.SDMMC.Status;
                          B : ESP32S3.SDMMC.Block) is
   begin
      Read_R (Which, int (ESP32S3.SDMMC.Status'Pos (S)),
              int (B (0)), int (B (1)), int (B (2)), int (B (3)));
   end Report_Read;
begin
   delay until Clock + Milliseconds (200);
   Banner;

   ESP32S3.SDMMC.Setup
     (C, On => ESP32S3.SDMMC.Slot1,
      Clk => Clk_Pin, Cmd => Cmd_Pin,
      D0 => D0_Pin, D1 => D1_Pin, D2 => D2_Pin, D3 => D3_Pin,
      Width => ESP32S3.SDMMC.Width_4,
      Init_Clock_Hz => Init_Clock_Hz, Data_Clock_Hz => Data_Clock_Hz);

   ESP32S3.SDMMC.Initialize (C, St);
   Init_R (int (ESP32S3.SDMMC.Status'Pos (St)),
           int (ESP32S3.SDMMC.Card_Kind'Pos (ESP32S3.SDMMC.Kind (C))),
           Bus_Width_Bits);

   if St = ESP32S3.SDMMC.OK then
      ESP32S3.SDMMC.Read_Block (C, Test_LBA, Orig, St);
      Report_Read (1, St, Orig);

      if St = ESP32S3.SDMMC.OK then
         ESP32S3.SDMMC.Write_Block (C, Test_LBA, Orig, St);
         Write_R (int (ESP32S3.SDMMC.Status'Pos (St)));

         if St = ESP32S3.SDMMC.OK then
            ESP32S3.SDMMC.Read_Block (C, Test_LBA, Back, St);
            Report_Read (2, St, Back);
            Verify_R (Boolean'Pos (St = ESP32S3.SDMMC.OK and then Orig = Back));
         end if;
      end if;
   end if;

   Done;

   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
