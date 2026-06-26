--  Ada LCD (i80 8-bit parallel) self-test on the bare-metal ESP32-S3 (no IDF)
--  =========================================================================
--  Exercises the reusable HAL LCD driver (ESP32S3.LCD), the LCD half of the
--  LCD_CAM controller, driving an 8-bit Intel-8080 parallel bus over GDMA:
--    * DMA-transmit a byte buffer and confirm the transfer completes;
--    * free-run the pixel clock and GPIO-sample it to verify its frequency.
--  No wiring (the pixel-clock pad is just sampled by GPIO.Read).
with Interfaces;   use Interfaces;
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.LCD;  use ESP32S3.LCD;
with ESP32S3.GPIO;
with ESP32S3.Log;  use ESP32S3.Log;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   --  Data bus D0..D7 on GPIO 4..11; pixel clock on GPIO 13.
   Pclk_Pin : constant ESP32S3.GPIO.Pin_Id := 13;
   D_Pins   : constant Data_Pins := (4, 5, 6, 7, 8, 9, 10, 11);

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
begin
   delay until Clock + Milliseconds (200);
   Put_Line ("[lcd] bare-metal LCD i80 8-bit parallel DMA-TX self-test "
             & "(no wiring)");

   for I in Buffer'Range loop
      Buf (I) := Unsigned_8 ((I * 3 + 1) mod 256);
   end loop;

   Setup (Pclk_Hz => Set_Khz * 1000);

   declare
      S    : Session;
      Ok   : Boolean;
      T0   : Time;
      Secs : Float;
      Meas : Integer;
   begin
      Acquire (S);
      Configure_Pins (S, D_Pins, Pclk => Pclk_Pin);   --  route pads on held ctrl
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

      Meas := (if Secs = 0.0 then 0
               else Integer (Float (Buffer'Length * Reps) / Secs / 1000.0));
      Put ("[lcd] pclk: set=");
      Put (Set_Khz);
      Put (" kHz measured=");
      Put (Meas);
      Put (" kHz  ");
      --  +/-5 %: the wall-clock timing has some jitter at MHz rates.
      Put_Line (if Ok and then abs (Meas - Set_Khz) <= Set_Khz / 20 then "PASS"
                else "FAIL");
   end;

   Put_Line ("[lcd] done.");

   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
