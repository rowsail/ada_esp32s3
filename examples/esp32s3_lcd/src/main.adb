with Ada.Real_Time; use Ada.Real_Time;
with System;        use type System.Address;
with ESP32S3.CH422G;
with ESP32S3.LCD;
with FB;

--  PSRAM d-bus re-map (bare_board_init) -- pull it into the link closure so the
--  .ext_ram.bss framebuffers are backed by real PSRAM.
with Lcd_Board;
pragma Unreferenced (Lcd_Board);

--  Waveshare ESP32-S3-Touch-LCD-7 (800x480 RGB565) -- TEAR-FREE double buffering.
--
--  Two framebuffers ping-pong: the app draws into the hidden one, then Flip shows
--  it whole at a frame boundary, so a frame is never seen mid-draw.  The panel is
--  refreshed from small internal-SRAM bounce buffers that a GDMA ISR refills from
--  the shown framebuffer, so scan-out is immune to the app's PSRAM drawing.
--
--  KEY: draw only what CHANGED.  A full-frame redraw (768 KB) every flip saturates
--  the single PSRAM bus against the refill and the picture slips; touching just the
--  moving box (a few KB) leaves the refill plenty of bus and the frame stays locked.
--  A white box hops the four corners once every 2 s; the frame is rock-steady
--  between hops and never tears.
procedure Main is
   use ESP32S3;
   use type CH422G.Status;

   Expander : CH422G.Device;
   Cs       : CH422G.Session;
   St       : CH422G.Status;

   Panel : LCD.Session;

   Timing : constant LCD.RGB_Config :=
     (H_Res => 800, V_Res => 480,
      H_Sync => 4, H_Back => 8, H_Front => 8,
      V_Sync => 4, V_Back => 8, V_Front => 8,
      Pclk_Hz => 16_000_000, Two_Byte => True,
      HSync_Idle_High => True, VSync_Idle_High => True,
      DE_Idle_High => False, Pclk_Falling => True);

   Panel_Pins : constant LCD.RGB_Pins :=
     (Data => (0 => 14, 1 => 38, 2 => 18, 3 => 17, 4 => 10,
               5 => 39, 6 => 0, 7 => 45, 8 => 48, 9 => 47, 10 => 21,
               11 => 1, 12 => 2, 13 => 42, 14 => 41, 15 => 40),
      Pclk => 7, HSync => 46, VSync => 3, DE => 5);

   --  Four box positions, one per screen corner (inside the border).
   Xs : constant array (0 .. 3) of Natural := (60, 660, 660, 60);
   Ys : constant array (0 .. 3) of Natural := (60, 60, 340, 340);
   I  : Natural := 0;   --  next corner to light up
begin
   CH422G.Setup (Expander, Sda => 8, Scl => 9);
   CH422G.Acquire (Cs, Expander);
   CH422G.Configure (Cs, IO_Dir => CH422G.Outputs, Result => St);
   CH422G.Write_IO (Cs, 16#1E#, St);
   CH422G.Release (Cs);

   --  Seed BOTH buffers with the static background (bars + border) once, before
   --  scan-out starts.  The per-frame loop then only touches the moving box.
   FB.Draw_Bars (FB.FB0'Address);
   FB.Draw_Border (FB.FB0'Address);
   FB.Draw_Bars (FB.FB1'Address);
   FB.Draw_Border (FB.FB1'Address);

   LCD.Acquire_RGB (Panel, Timing, Panel_Pins);
   --  Start_RGB returns only once the refill phase lock has self-calibrated, so
   --  it is safe to draw into the back buffer immediately.
   LCD.Start_RGB (Panel, FB.FB0'Address, FB.FB1'Address, FB.FB0'Length);

   loop
      declare
         Back : constant System.Address := LCD.Back_Buffer (Panel);
      begin
         --  The back buffer was last drawn two flips ago, so it still shows the
         --  box from corner (I-2) mod 4 = (I+2) mod 4.  Erase just that cell
         --  (restore the bars) and paint the new one -- a few KB, not 768 KB.
         FB.Paint_Box (Back, Xs ((I + 2) mod 4), Ys ((I + 2) mod 4), White => False);
         FB.Paint_Box (Back, Xs (I), Ys (I), White => True);
         LCD.Flip (Panel);   --  tear-free swap at the next frame boundary
      end;
      I := (I + 1) mod 4;
      delay until Clock + Seconds (2);
   end loop;
end Main;
