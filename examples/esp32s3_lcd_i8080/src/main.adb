--  Ada LCD (i80 8-bit parallel) self-test on the bare-metal ESP32-S3 (no IDF)
--  =========================================================================
--  What it demonstrates
--    The reusable HAL LCD driver (ESP32S3.LCD), the LCD half of the LCD_CAM
--    controller, driving an 8-bit Intel-8080 ("i80") parallel bus over GDMA:
--      * DMA-transmit a byte buffer and confirm the transfer completes;
--      * recover the pixel-clock rate by timing the transfer (one byte per
--        PCLK), and check it matches what was set.
--
--  Build & run
--    ./x run esp32s3_lcd_i8080
--    Needs the embedded profile (the driver's controlled Session uses
--    finalization, which light-tasking forbids); build.sh sets
--    ESP32S3_RTS_PROFILE=embedded.
--
--  Output -- three lines; both checks should end in PASS:
--    [lcd] bare-metal LCD i80 8-bit parallel DMA-TX self-test (no wiring)
--    [lcd] dma transmit (4000 bytes): trans-done=1  PASS
--    [lcd] pclk: set=200 kHz measured=200 kHz  PASS
--    [lcd] done.
--
--  Hardware / wiring
--    None (self-contained).  The driver routes the i80 bus to pads -- the
--    8-bit data bus D0..D7 on GPIO 4..11, the pixel clock PCLK on GPIO 13 --
--    but nothing is connected; the transfer-done interrupt and the wall-clock
--    timing alone verify the data path and clock divider.  WR/RD/DC/CS/RST,
--    the backlight, and a real panel + its geometry are not exercised by this
--    8-bit-transmit self-test.
with Interfaces;    use Interfaces;
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.LCD; use ESP32S3.LCD;
with ESP32S3.GPIO;
with ESP32S3.Log; use ESP32S3.Log;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   --  i80 bus pads.  Pixel clock (PCLK) on GPIO 13; the eight data lines
   --  D0..D7 on GPIO 4..11 (in that order).
   Pclk_Pin : constant ESP32S3.GPIO.Pin_Id := 13;
   D_Pins   : constant Data_Pins := (4, 5, 6, 7, 8, 9, 10, 11);

   Hz_Per_Khz : constant := 1_000;

   --  2 MHz: a realistic display clock, and crucially ABOVE ~625 kHz, where the
   --  pixel division has to be carried by the prescale (CLKCNT_N).  Below that
   --  threshold the divider lands entirely in the module stage and the prescale
   --  path is never exercised -- which is why the old 200 kHz test ran green even
   --  while CLKCNT_N was left at 0.  (This timing check validates clock
   --  GENERATION; data-edge setup integrity needs a hardware loopback / scope.)
   Set_Khz : constant := 2_000;

   --  One byte per PCLK.  At 2 MHz a single 4000-byte transfer is only 2 ms, too
   --  short to time accurately off the wall clock, so the transfer is repeated to
   --  build a ~50 ms window.
   type Buffer is array (0 .. 3_999) of Unsigned_8;
   Buf  : Buffer;
   Reps : constant := 25;

   --  A 0 .. 255 byte ramp written across the buffer (the transfer payload).
   Ramp_Step    : constant := 1;
   Ramp_Start   : constant := 0;
   Byte_Modulus : constant := 256;

   Console_Settle : constant Time_Span := Milliseconds (200);
   Idle_Interval  : constant Time_Span := Seconds (3600);
begin
   delay until Clock + Console_Settle;
   Put_Line ("[lcd] bare-metal LCD i80 8-bit parallel DMA-TX self-test " & "(no wiring)");

   for I in Buffer'Range loop
      Buf (I) := Unsigned_8 ((I * Ramp_Step + Ramp_Start) mod Byte_Modulus);
   end loop;

   declare
      S    : Session;
      Ok   : Boolean;
      T0   : Time;
      Secs : Float;
      Meas : Integer;
   begin
      Acquire
        (S,
         Pclk_Hz => Set_Khz * Hz_Per_Khz,
         Data    => D_Pins,
         Pclk    => Pclk_Pin);     --  own + configure
      Ok := True;
      T0 := Clock;
      for R in 1 .. Reps loop
         Transmit (S, Buf'Address, Buffer'Length, Ok);  --  blocks until done
         exit when not Ok;
      end loop;
      Secs := Float (To_Duration (Clock - T0));
      Release (S);

      --  trans-done proves the DMA -> LCD data path; one byte per PCLK, so the
      --  byte rate IS the pixel-clock rate.
      Put ("[lcd] dma transmit (");
      Put (Buffer'Length);
      Put (" bytes): trans-done=");
      Put (if Ok then 1 else 0);
      Put ("  ");
      Put_Line (if Ok then "PASS" else "FAIL");

      Meas := (if Secs = 0.0 then 0 else Integer (Float (Buffer'Length * Reps) / Secs / 1000.0));
      Put ("[lcd] pclk: set=");
      Put (Set_Khz);
      Put (" kHz measured=");
      Put (Meas);
      Put (" kHz  ");
      --  +/-5 %: the wall-clock timing has some jitter at MHz rates.
      Put_Line (if Ok and then abs (Meas - Set_Khz) <= Set_Khz / 20 then "PASS" else "FAIL");
   end;

   Put_Line ("[lcd] done.");

   loop
      delay until Clock + Idle_Interval;
   end loop;
end Main;
