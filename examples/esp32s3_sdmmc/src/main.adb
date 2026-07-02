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
with Interfaces;    use Interfaces;
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.SDMMC;
with ESP32S3.Text_IO; use ESP32S3.Text_IO;   --  buffered console (no rom-printf)

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
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

   function Kind_Name (K : ESP32S3.SDMMC.Card_Kind) return String
   is (case K is
         when ESP32S3.SDMMC.Unknown => "Unknown",
         when ESP32S3.SDMMC.SDSC    => "SDSC",
         when ESP32S3.SDMMC.SDHC    => "SDHC/SDXC");

   --  Console reporters, formerly esp_rom_printf natives in glue.c, now pure Ada
   --  over the buffered ESP32S3.Text_IO console.

   procedure Banner is
   begin
      Put_Line ("[sdmmc] bare-metal native SD/MMC-host self-test (needs a wired card)");
   end Banner;

   procedure Report_Init
     (Status : ESP32S3.SDMMC.Status; Kind : ESP32S3.SDMMC.Card_Kind; Width : Natural) is
   begin
      Put ("[sdmmc] init: ");
      Put (ESP32S3.SDMMC.Status'Image (Status));
      Put ("   card: ");
      Put (Kind_Name (Kind));
      Put ("   bus: ");
      Put_Nat (Width);
      Put_Line ("-bit");
   end Report_Init;

   procedure Report_Write (Status : ESP32S3.SDMMC.Status) is
   begin
      Put_Line ("[sdmmc] write-back: " & ESP32S3.SDMMC.Status'Image (Status));
   end Report_Write;

   procedure Report_Verify (Ok : Boolean) is
   begin
      Put_Line ("[sdmmc] round-trip (re-read == original): " & (if Ok then "PASS" else "FAIL"));
   end Report_Verify;

   procedure Done is
   begin
      Put_Line ("[sdmmc] done.");
   end Done;

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

   C           : ESP32S3.SDMMC.Card;
   Card_Status : ESP32S3.SDMMC.Status;
   Orig        : ESP32S3.SDMMC.Block;   --  bytes read first, then written back
   Back        : ESP32S3.SDMMC.Block;   --  the re-read, compared against Orig

   procedure Report_Read (Which : Natural; S : ESP32S3.SDMMC.Status; B : ESP32S3.SDMMC.Block) is
   begin
      Put ("[sdmmc] read#");
      Put_Nat (Which);
      Put (": ");
      Put (ESP32S3.SDMMC.Status'Image (S));
      Put ("   first bytes = ");
      Put_Hex (Unsigned_64 (B (0)), 2);
      Put (" ");
      Put_Hex (Unsigned_64 (B (1)), 2);
      Put (" ");
      Put_Hex (Unsigned_64 (B (2)), 2);
      Put (" ");
      Put_Hex (Unsigned_64 (B (3)), 2);
      New_Line;
   end Report_Read;
begin
   delay until Clock + Milliseconds (200);
   Banner;

   ESP32S3.SDMMC.Setup
     (C,
      On            => ESP32S3.SDMMC.Slot1,
      Clk           => Clk_Pin,
      Cmd           => Cmd_Pin,
      D0            => D0_Pin,
      D1            => D1_Pin,
      D2            => D2_Pin,
      D3            => D3_Pin,
      Width         => ESP32S3.SDMMC.Width_4,
      Init_Clock_Hz => Init_Clock_Hz,
      Data_Clock_Hz => Data_Clock_Hz);

   ESP32S3.SDMMC.Initialize (C, Card_Status);
   Report_Init (Card_Status, ESP32S3.SDMMC.Kind (C), Bus_Width_Bits);

   if Card_Status = ESP32S3.SDMMC.OK then
      ESP32S3.SDMMC.Read_Block (C, Test_LBA, Orig, Card_Status);
      Report_Read (1, Card_Status, Orig);

      if Card_Status = ESP32S3.SDMMC.OK then
         ESP32S3.SDMMC.Write_Block (C, Test_LBA, Orig, Card_Status);
         Report_Write (Card_Status);

         if Card_Status = ESP32S3.SDMMC.OK then
            ESP32S3.SDMMC.Read_Block (C, Test_LBA, Back, Card_Status);
            Report_Read (2, Card_Status, Back);
            Report_Verify (Card_Status = ESP32S3.SDMMC.OK and then Orig = Back);
         end if;
      end if;
   end if;

   Done;

   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
