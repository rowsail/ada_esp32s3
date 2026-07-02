--  Ada RTC-IO pad-hold self-test (ESP32-S3, no FreeRTOS, no IDF)
--  ===========================================================
--  What it demonstrates
--    The reusable HAL RTC-IO driver (ESP32S3.RTC_IO): an RTC-capable pad is
--    driven high and then HELD.  Hold latches the pad at its current level so it
--    keeps driving even while the digital core is powered down in deep sleep and
--    across the reset that a wake causes -- the mechanism used to keep a load
--    enabled / a reset line asserted through sleep.  Here we show that latch while
--    awake (no sleep cycle needed): while held, a GPIO write to clear the pad is
--    ignored (it stays high); after Release the same write takes effect (it goes
--    low).  A second check exercises the RTC-domain pulls.  The pad is read back
--    with ESP32S3.GPIO.Read, so no wiring is required.
--
--  Build & run
--    ./x run esp32s3_rtcio_hold       (build + flash + monitor)
--    Built as the embedded profile -- build.sh sets ESP32S3_RTS_PROFILE=embedded.
--
--  Output (over the USB-Serial-JTAG console)
--    [rtcio] bare-metal RTC-IO pad-hold self-test (no wiring)
--    [rtcio] GPIO5: set=1  cleared-while-held=1  cleared-after-release=0  PASS
--    [rtcio] GPIO6 RTC pull: pull-up reads=1  pull-down reads=0  PASS
--    [rtcio] done.
--    Each line ends in PASS when the held/released and pull-up/pull-down levels
--    read back as expected.
--
--  Hardware / wiring
--    None required -- the test reads the pads back internally with GPIO.Read.  To
--    observe the held level physically, put an LED (with a series resistor) on the
--    hold pad GPIO5: it lights when the pad is driven high and stays lit through
--    the held Clear, then goes dark once the pad is released and cleared.  GPIO5
--    and GPIO6 are RTC-capable pads (RTC_Pin covers GPIO0..21).
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.RTC_IO; use ESP32S3.RTC_IO;
with ESP32S3.GPIO;
with ESP32S3.Log;    use ESP32S3.Log;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   --  GPIO5 carries the hold test, GPIO6 the RTC-pull test.  Both are RTC-capable
   --  pads (RTC_Pin = GPIO0..21); the choice is arbitrary among those.
   Hold_Pin : constant ESP32S3.GPIO.Pin_Id := 5;
   Pull_Pin : constant ESP32S3.GPIO.Pin_Id := 6;

   --  Let a level settle on the pad before we read it back.  1 ms is ample for
   --  the digital pad; the RTC pulls are weaker, so give them 5 ms.
   Pad_Settle  : constant Time_Span := Milliseconds (1);
   Pull_Settle : constant Time_Span := Milliseconds (5);

   --  Wait for the console / runtime to come up before the first line, then park
   --  the test forever once it is done (nothing else runs on this core).
   Startup_Delay : constant Time_Span := Milliseconds (200);
   Park_Forever  : constant Time_Span := Seconds (3600);

   function Read return Boolean
   is (ESP32S3.GPIO.Read (Hold_Pin));
begin
   delay until Clock + Startup_Delay;
   Put_Line ("[rtcio] bare-metal RTC-IO pad-hold self-test (no wiring)");

   ESP32S3.GPIO.Configure (Hold_Pin, ESP32S3.GPIO.Output);
   ESP32S3.GPIO.Set (Hold_Pin);                    --  drive high
   delay until Clock + Pad_Settle;

   declare
      After_Set : constant Boolean := Read;        --  expect high

      Held_Level     : Boolean;
      Released_Level : Boolean;
      Ok             : Boolean;
   begin
      Hold (Hold_Pin);                             --  latch it high
      ESP32S3.GPIO.Clear (Hold_Pin);               --  try to drive low -- ignored
      delay until Clock + Pad_Settle;
      Held_Level := Read;                          --  expect STILL high

      Release (Hold_Pin);                          --  unlatch
      ESP32S3.GPIO.Clear (Hold_Pin);               --  now this takes effect
      delay until Clock + Pad_Settle;
      Released_Level := Read;                       --  expect low

      --  PASS: high after set, still high while held despite the clear, low once
      --  released and cleared.
      Ok := After_Set and then Held_Level and then not Released_Level;
      Put ("[rtcio] GPIO5: set=");
      Put (Boolean'Pos (After_Set));
      Put ("  cleared-while-held=");
      Put (Boolean'Pos (Held_Level));
      Put ("  cleared-after-release=");
      Put (Boolean'Pos (Released_Level));
      Put ("  ");
      Put_Line (if Ok then "PASS" else "FAIL");
   end;

   --  RTC pull test: route a high-Z pad into the RTC domain, then watch it follow
   --  its RTC pull-up (high) and pull-down (low), read back with GPIO.Read.
   declare
      Up_Level   : Boolean;
      Down_Level : Boolean;
   begin
      ESP32S3.GPIO.Configure (Pull_Pin, ESP32S3.GPIO.Input);   --  high-Z input buffer on
      Enable_RTC_Input (Pull_Pin);                             --  connect the RTC pull

      Set_Pull (Pull_Pin, Up);
      delay until Clock + Pull_Settle;
      Up_Level := ESP32S3.GPIO.Read (Pull_Pin);               --  expect high

      Set_Pull (Pull_Pin, Down);
      delay until Clock + Pull_Settle;
      Down_Level := ESP32S3.GPIO.Read (Pull_Pin);             --  expect low

      Set_Pull (Pull_Pin, No_Pull);
      Put ("[rtcio] GPIO6 RTC pull: pull-up reads=");
      Put (Boolean'Pos (Up_Level));
      Put ("  pull-down reads=");
      Put (Boolean'Pos (Down_Level));
      Put ("  ");
      Put_Line (if Up_Level and then not Down_Level then "PASS" else "FAIL");
   end;

   Put_Line ("[rtcio] done.");

   loop
      delay until Clock + Park_Forever;
   end loop;
end Main;
