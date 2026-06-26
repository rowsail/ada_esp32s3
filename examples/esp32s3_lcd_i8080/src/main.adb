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
with Interfaces;   use Interfaces;
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.LCD;  use ESP32S3.LCD;
with ESP32S3.GPIO;
with ESP32S3.Log;  use ESP32S3.Log;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   --  i80 bus pads.  Pixel clock (PCLK) on GPIO 13; the eight data lines
   --  D0..D7 on GPIO 4..11 (in that order).
   Pclk_Pin : constant ESP32S3.GPIO.Pin_Id := 13;
   Data_Bus_Pins : constant Data_Pins := (4, 5, 6, 7, 8, 9, 10, 11);

   --  Pixel-clock rate the test asks the divider for.  200 kHz divides the
   --  20 MHz LCD source clock exactly (20 MHz / 100), so set == measured.
   Set_Khz : constant := 200;

   --  One byte is clocked out per PCLK, so the transfer takes Length / PCLK
   --  seconds.  4000 bytes at 200 kHz is ~20 ms -- long enough to time off the
   --  runtime wall clock without the measurement being dominated by jitter.
   type Buffer is array (0 .. 3_999) of Unsigned_8;
   Buf : Buffer;

   --  Settle the console before the first line is printed.
   Console_Settle : constant Time_Span := Milliseconds (200);

   --  Fill pattern: a cheap non-constant ramp so the byte stream is not all
   --  zeros (any deterministic pattern would do -- the bytes are not checked).
   Ramp_Step  : constant := 3;
   Ramp_Start : constant := 1;
   Byte_Modulus : constant := 256;

   --  Convert the kHz setting to the Hz the driver wants.
   Hz_Per_Khz : constant := 1000;

   --  Accept a measured rate within this many kHz of the set rate; the slack
   --  covers wall-clock granularity and interrupt latency in the ~20 ms window.
   Pclk_Tolerance_Khz : constant := 20;

   --  Park forever once the report is printed (re-arm the long idle each pass).
   Idle_Interval : constant Time_Span := Seconds (3600);
begin
   delay until Clock + Console_Settle;
   Put_Line ("[lcd] bare-metal LCD i80 8-bit parallel DMA-TX self-test "
             & "(no wiring)");

   for I in Buffer'Range loop
      Buf (I) := Unsigned_8 ((I * Ramp_Step + Ramp_Start) mod Byte_Modulus);
   end loop;

   Setup (Pclk_Hz => Set_Khz * Hz_Per_Khz);

   declare
      S             : Session;
      Ok            : Boolean;
      Start         : Time;
      Elapsed_Secs  : Float;
      Measured_Khz  : Integer;
   begin
      Acquire (S);

      --  Route the bus to its pads on the held controller (no panel attached).
      Configure_Pins (S, Data_Bus_Pins, Pclk => Pclk_Pin);

      Start := Clock;
      Transmit (S, Buf'Address, Buffer'Length, Ok);   --  blocks until done
      Elapsed_Secs := Float (To_Duration (Clock - Start));
      Release (S);

      --  trans-done proves the DMA -> LCD data path; one byte per PCLK, so the
      --  byte rate IS the pixel-clock rate.
      Put ("[lcd] dma transmit (");
      Put (Buffer'Length);
      Put (" bytes): trans-done=");
      Put (if Ok then 1 else 0);
      Put ("  ");
      Put_Line (if Ok then "PASS" else "FAIL");

      --  bytes / seconds = bytes-per-second = PCLK in Hz; / Hz_Per_Khz -> kHz.
      Measured_Khz :=
        (if Elapsed_Secs = 0.0 then 0
         else Integer (Float (Buffer'Length) / Elapsed_Secs
                       / Float (Hz_Per_Khz)));
      Put ("[lcd] pclk: set=");
      Put (Set_Khz);
      Put (" kHz measured=");
      Put (Measured_Khz);
      Put (" kHz  ");
      Put_Line
        (if Ok and then abs (Measured_Khz - Set_Khz) <= Pclk_Tolerance_Khz
         then "PASS"
         else "FAIL");
   end;

   Put_Line ("[lcd] done.");

   loop
      delay until Clock + Idle_Interval;
   end loop;
end Main;
