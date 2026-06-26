--  ST7789 SPI display driver demo on the bare-metal ESP32-S3 (no FreeRTOS, no
--  IDF)
--  ==========================================================================
--  What it demonstrates
--    The reusable HAL driver (ESP32S3.ST7789) against a real 240x240 panel: a
--    4-wire, write-only SPI display controller (ST77xx family), 16-bit RGB565
--    pixels.  It holds ONE Session for the whole demo -- so the display is
--    protected against other tasks the entire time -- while each Fill /
--    Fill_Rect below locks the SPI host only for its own transfer and frees it
--    again (the two-level locking this driver is built around).
--
--  Build & run
--    ./x run esp32s3_st7789        (embedded profile -- build.sh sets
--                                   ESP32S3_RTS_PROFILE=embedded; the controlled
--                                   Session rules out light-tasking)
--
--  Output
--    The panel is the real output; the console only narrates the steps (SPI is
--    write-only -- there is nothing to read back).  Each step prints one
--    "[lcd] <step>" line, ending with "[lcd] done -- check the panel.".  The
--    panel paints solid red -> green -> blue, eight vertical colour bars, a
--    centred white box with an orange box inside it, then a text screen.
--
--  Hardware (wiring)
--    SPI2 clock  SCLK     = IO12
--    SPI2 data   MOSI/SDA = IO13   (write-only -- no MISO)
--    control     DC       = IO16   (data/command select, driven by the driver)
--    control     CS       = IO10   (chip select, driven by the driver as GPIO)
--    reset       RST      = not wired -> software reset (SWRESET)
--    backlight   BLK      = IO6     (driven HERE by the example, NOT the driver)
--    Panel: ST7789 240x240, RGB565, 40 MHz SPI.
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.GPIO;
with ESP32S3.Log;       use ESP32S3.Log;
with ESP32S3.ST7789;
with ESP32S3.ST7789.Text;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   package Display_Driver renames ESP32S3.ST7789;

   --  One step line, e.g. "[lcd] init".
   procedure Step (Name : String) is
   begin
      Put ("[lcd] ");
      Put_Line (Name);
   end Step;

   --  SPI2 wiring: clock, data, and the two control lines the driver toggles.
   Serial_Clock_Pin   : constant ESP32S3.GPIO.Pin_Id := 12;   --  SCLK
   Data_Out_Pin       : constant ESP32S3.GPIO.Pin_Id := 13;   --  MOSI / SDA
   Data_Command_Pin   : constant ESP32S3.GPIO.Pin_Id := 16;   --  DC select
   Chip_Select_Pin    : constant ESP32S3.GPIO.Pin_Id := 10;   --  CS

   --  Backlight enable -- the example's job, not the driver's.
   Backlight_Pin      : constant ESP32S3.GPIO.Pin_Id := 6;

   --  Panel geometry (also the Setup defaults, so 30 px per bar tiles 240).
   Panel_Width        : constant := 240;
   Panel_Height       : constant := 240;

   Display         : Display_Driver.Device;
   Display_Session : Display_Driver.Session;

   --  Pause long enough to see each painted screen.
   procedure Hold is
   begin
      delay until Clock + Milliseconds (800);
   end Hold;

begin
   delay until Clock + Milliseconds (200);   --  let the console settle
   Put_Line ("[lcd] ST7789 240x240 SPI display demo "
             & "(SPI2 sclk=12 mosi=13 dc=16 cs=10, bl=6)");

   --  Backlight is the example's job, not the driver's: drive IO6 high.
   ESP32S3.GPIO.Configure (Backlight_Pin, Mode => ESP32S3.GPIO.Output);
   ESP32S3.GPIO.Set (Backlight_Pin);

   --  Record wiring + geometry and bring SPI2 up (defaults: 40 MHz, mode 0).
   Display_Driver.Setup (Display,
                         Sclk => Serial_Clock_Pin,
                         Mosi => Data_Out_Pin,
                         DC   => Data_Command_Pin,
                         CS   => Chip_Select_Pin);
   Step ("backlight + setup");

   Display_Driver.Acquire (Display_Session, Display);  --  protect display: whole demo
   Display_Driver.Init (Display_Session);
   Step ("init");

   --  Full-screen colour fills (each locks the SPI host only for its transfer).
   Display_Driver.Fill (Display_Session, Display_Driver.Red);
   Step ("fill red");
   Hold;
   Display_Driver.Fill (Display_Session, Display_Driver.Green);
   Step ("fill green");
   Hold;
   Display_Driver.Fill (Display_Session, Display_Driver.Blue);
   Step ("fill blue");
   Hold;

   --  Eight vertical colour bars, each Bar_Width px across the 240-wide panel.
   declare
      Bar_Count : constant := 8;
      Bar_Width : constant := Panel_Width / Bar_Count;   --  30 px per bar

      --  Yellow / cyan / magenta filled out from the named primaries.
      Yellow  : constant Display_Driver.Color := Display_Driver.RGB (255, 255, 0);
      Cyan    : constant Display_Driver.Color := Display_Driver.RGB (0, 255, 255);
      Magenta : constant Display_Driver.Color := Display_Driver.RGB (255, 0, 255);

      Bars : constant array (0 .. Bar_Count - 1) of Display_Driver.Color :=
        (Display_Driver.Red, Display_Driver.Green, Display_Driver.Blue,
         Display_Driver.White, Yellow, Cyan, Magenta, Display_Driver.Black);
   begin
      for I in Bars'Range loop
         Display_Driver.Fill_Rect (Display_Session,
                                   X => I * Bar_Width, Y => 0,
                                   W => Bar_Width,     H => Panel_Height,
                                   C => Bars (I));
      end loop;
   end;
   Step ("colour bars");
   Hold;

   --  A centred white box on a dark-blue background, with an orange box inside.
   declare
      Background  : constant Display_Driver.Color := Display_Driver.RGB (16, 16, 32);
      Orange      : constant Display_Driver.Color := Display_Driver.RGB (255, 128, 0);

      White_Box_Origin : constant := 70;    --  100x100 box centred on 240
      White_Box_Side   : constant := 100;
      Inner_Box_Origin : constant := 90;    --  60x60 box centred inside it
      Inner_Box_Side   : constant := 60;
   begin
      Display_Driver.Fill (Display_Session, Background);
      Display_Driver.Fill_Rect (Display_Session,
                                X => White_Box_Origin, Y => White_Box_Origin,
                                W => White_Box_Side,   H => White_Box_Side,
                                C => Display_Driver.White);
      Display_Driver.Fill_Rect (Display_Session,
                                X => Inner_Box_Origin, Y => Inner_Box_Origin,
                                W => Inner_Box_Side,   H => Inner_Box_Side,
                                C => Orange);
   end;
   Step ("centre box");
   Hold;

   --  Text: 5x7 font at three scales on a dark background (.Text child layer).
   declare
      Text_Background : constant Display_Driver.Color := Display_Driver.RGB (0, 0, 32);
      Title_Green     : constant Display_Driver.Color := Display_Driver.RGB (0, 255, 0);
      Caption_Amber   : constant Display_Driver.Color := Display_Driver.RGB (255, 200, 0);

      Line_Feed : constant Character := Character'Val (10);   --  ASCII LF wraps a line
   begin
      Display_Driver.Fill (Display_Session, Text_Background);
      Display_Driver.Text.Draw_Text (Display_Session,
                                     X  => 6, Y => 16,
                                     Str => "ESP32-S3 + Ada",
                                     FG => Display_Driver.White,
                                     BG => Text_Background);
      Display_Driver.Text.Draw_Text (Display_Session,
                                     X  => 6, Y => 60,
                                     Str => "ST7789",
                                     FG => Title_Green,
                                     BG => Text_Background,
                                     Scale => 3);
      Display_Driver.Text.Draw_Text (Display_Session,
                                     X  => 6, Y => 120,
                                     Str => "40 MHz SPI" & Line_Feed
                                            & "240x240" & Line_Feed
                                            & "write-only",
                                     FG => Caption_Amber,
                                     BG => Text_Background,
                                     Scale => 2);
   end;
   Step ("text");
   Hold;

   Display_Driver.Release (Display_Session);
   Put_Line ("[lcd] done -- check the panel.");

   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
