with Ada.Real_Time; use Ada.Real_Time;
with ESP32S3.CH422G;
with ESP32S3.LCD;
with FB;

--  PSRAM d-bus re-map (bare_board_init) -- pull it into the link closure so the
--  .ext_ram.bss framebuffers are backed by real PSRAM.
with Lcd_Board;
pragma Unreferenced (Lcd_Board);

--  Waveshare ESP32-S3-Touch-LCD-7 (800x480 RGB565) -- light the panel with a
--  colour-bar test pattern.
--
--    1.  the CH422G I/O expander (I2C 0x24/0x38) releases LCD reset + turns the
--        backlight on -- without this the panel stays dark;
--    2.  a colour-bar pattern is drawn into a PSRAM framebuffer;
--    3.  the LCD_CAM RGB controller streams that framebuffer to the panel
--        continuously (GDMA circular chain).
--
--  Config (timing, pins, CH422G sequence) is from the board's own demo.
procedure Main is
   use ESP32S3;
   use type CH422G.Status;

   Expander : CH422G.Device;
   Cs       : CH422G.Session;
   St       : CH422G.Status;

   Panel : LCD.Session;

   --  RGB timing straight from waveshare_rgb_lcd_port.c.
   Timing : constant LCD.RGB_Config :=
     (H_Res => 800, V_Res => 480,
      H_Sync => 4, H_Back => 8, H_Front => 8,
      V_Sync => 4, V_Back => 8, V_Front => 8,
      Pclk_Hz => 16_000_000,
      Two_Byte        => True,     --  RGB565
      HSync_Idle_High => True,     --  hsync_idle_low = 0
      VSync_Idle_High => True,     --  vsync_idle_low = 0
      DE_Idle_High    => False,    --  DE active-high
      Pclk_Falling    => True);    --  pclk_active_neg = 1

   --  GPIO map straight from the demo (DATA0..15 = B0..4, G0..5, R0..4).
   Panel_Pins : constant LCD.RGB_Pins :=
     (Data => (0 => 14, 1 => 38, 2 => 18, 3 => 17, 4 => 10,
               5 => 39, 6 => 0, 7 => 45, 8 => 48, 9 => 47, 10 => 21,
               11 => 1, 12 => 2, 13 => 42, 14 => 41, 15 => 40),
      Pclk => 7, HSync => 46, VSync => 3, DE => 5);

   Idle : constant Time_Span := Seconds (3600);
begin
   --  1) CH422G: outputs mode, then IO1..IO4 high (0x1E) -- EXIO2 backlight ON
   --     and EXIO3 LCD-reset released (the board's own bring-up).
   CH422G.Setup (Expander, Sda => 8, Scl => 9);
   CH422G.Acquire (Cs, Expander);
   CH422G.Configure (Cs, IO_Dir => CH422G.Outputs, Result => St);
   CH422G.Write_IO (Cs, 16#1E#, St);
   CH422G.Release (Cs);

   --  2) Colour bars into FB0.
   FB.Test_Pattern;

   --  3) Bring up the RGB panel and stream FB0 to it forever.
   LCD.Acquire_RGB (Panel, Timing, Panel_Pins);
   LCD.Start_RGB (Panel, FB.FB0'Address, FB.FB0'Length);
   LCD.Flush (Panel, FB.FB0'Address, FB.FB0'Length);

   loop
      delay until Clock + Idle;   --  the panel keeps refreshing from FB0 via DMA
   end loop;
end Main;
