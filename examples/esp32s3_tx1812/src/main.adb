--  Drive a string of TX1812 addressable RGB LEDs on IO48 via the RMT peripheral
--  ===========================================================================
--  What it demonstrates:  the reusable HAL driver ESP32S3.TX1812 clocking a
--    WS2812/"NeoPixel"-compatible single-wire string.  The string (64 LEDs) is
--    declared once at library level in LED_Panel, so its ~6.4 KiB of buffers are
--    reserved at elaboration (see LED_Panel).  Each frame here sets ALL 64 pixels
--    to one colour and Shows it; the full 1536-symbol frame is streamed out IO48
--    by the RMT wrap re-fill (Phase 2), since it far exceeds the 48-symbol RMT RAM.
--
--  Build & run:  ./x run esp32s3_tx1812
--    Drivers need finalization, so this runs on the embedded profile
--    (build.sh sets ESP32S3_RTS_PROFILE=embedded), not the default light-tasking.
--  Output:  a banner, an "acquire RMT TX channel: OK" line, then one colour name
--    per frame cycling forever:  red -> green -> blue -> white -> off (~0.6 s each).
--  Hardware:  TX1812 string data-in (DIN) on IO48.  With no physical string
--    attached, the board's on-board LED on IO48 is just pixel 1 of the chain -- so
--    it cycles the same colours, confirming the stream actually transmits.  Wire a
--    real 64-LED string into IO48 (with a 5 V supply / level shift) and all 64
--    light up.
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.GPIO;
with ESP32S3.TX1812;
with ESP32S3.Log; use ESP32S3.Log;
with LED_Panel;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   package LED renames ESP32S3.TX1812;

   --  Data-in (DIN) pin of the string -- on many ESP32-S3 boards this is the
   --  on-board RGB LED, which is then pixel 1 of the chain.
   Data_Pin : constant ESP32S3.GPIO.Pin_Id := 48;

   --  Per-channel level used for the lit colours (0 .. 255).  Held well below
   --  full scale so the on-board LED / a bench string is comfortable to watch.
   Brightness : constant := 48;

   --  Console settle delay before the first banner, and how long each colour is
   --  held on the string before advancing to the next.
   Startup_Delay : constant Time_Span := Milliseconds (200);
   Frame_Hold    : constant Time_Span := Milliseconds (600);

   --  The colour cycle, in display order.  Index doubles as the case selector
   --  in Name below, so name each step rather than using a bare literal.
   Red   : constant := 0;
   Green : constant := 1;
   Blue  : constant := 2;
   White : constant := 3;
   Off   : constant := 4;

   Colors : constant array (0 .. 4) of LED.Color :=
     (Red   => (R => Brightness, G => 0, B => 0),
      Green => (R => 0, G => Brightness, B => 0),
      Blue  => (R => 0, G => 0, B => Brightness),
      White => (R => Brightness, G => Brightness, B => Brightness),
      Off   => LED.Off);

   procedure Name (Color_Index : Integer) is
   begin
      Put ("[led] ");
      case Color_Index is
         when Red    =>
            Put_Line ("red");

         when Green  =>
            Put_Line ("green");

         when Blue   =>
            Put_Line ("blue");

         when White  =>
            Put_Line ("white");

         when Off    =>
            Put_Line ("off");

         when others =>
            Put_Line ("?");
      end case;
   end Name;
begin
   delay until Clock + Startup_Delay;
   Put_Line
     ("[led] TX1812 string of 64 LEDs on IO48 via RMT "
      & "(wrap-streamed; on-board LED = pixel 1)");

   --  Acquire the channel BEFORE driving the string.  Channel 0, default 1 RMT
   --  block (the wrap path handles all 64 LEDs); pass Blocks => 4 to push up to
   --  ~7 LEDs out in one shot without wrap.
   LED.Acquire (LED_Panel.Panel, Pin => Data_Pin, Channel => 0);
   Put ("[led] acquire RMT TX channel: ");
   Put_Line (if LED.Is_Valid (LED_Panel.Panel) then "OK" else "FAILED (channel busy?)");
   if not LED.Is_Valid (LED_Panel.Panel) then
      --  Channel busy / unroutable: nothing to drive, so idle forever.
      loop
         delay until Clock + Seconds (3600);
      end loop;
   end if;

   loop
      for I in Colors'Range loop
         LED.Set_All (LED_Panel.Panel, Colors (I));   --  all 64 pixels
         LED.Show (LED_Panel.Panel);                  --  stream the whole frame
         Name (I);
         delay until Clock + Frame_Hold;
      end loop;
   end loop;
end Main;
