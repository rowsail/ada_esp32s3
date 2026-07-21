with System;
with System.Machine_Code;            use System.Machine_Code;
with System.Storage_Elements;        use System.Storage_Elements;
with Interfaces;                     use Interfaces;
with ESP32S3_Registers;         use ESP32S3_Registers;
with ESP32S3_Registers.LCD_CAM; use ESP32S3_Registers.LCD_CAM;
with ESP32S3_Registers.GPIO;
with ESP32S3_Registers.SYSTEM;
with ESP32S3.GPIO_Signals;

package body ESP32S3.LCD.Engine is

   package GD renames ESP32S3.GDMA;
   package GR renames ESP32S3_Registers.GPIO;
   package G renames ESP32S3.GPIO;
   package Sigs renames ESP32S3.GPIO_Signals;

   Src_Hz : constant := 160_000_000;            --  LCD_CLK_SEL = 3 source clock

   procedure Drive_Out (Pad : G.Pin_Id; Sig : Natural) is
      Out_Cfg : GR.FUNC_OUT_SEL_CFG_Register :=   --  the pad's output-select config
        GR.GPIO_Periph.FUNC_OUT_SEL_CFG (Natural (Pad));
   begin
      G.Configure (Pad, Mode => G.Output, Drive => G.Drive_Strong);
      Out_Cfg.OUT_SEL := GR.FUNC_OUT_SEL_CFG_OUT_SEL_Field (Sig);
      Out_Cfg.OEN_SEL := False;
      GR.GPIO_Periph.FUNC_OUT_SEL_CFG (Natural (Pad)) := Out_Cfg;
   end Drive_Out;

   ----------
   -- Open --
   ----------

   procedure Open (B : in out Bus; Pclk_Hz : Positive) is
      use ESP32S3_Registers.SYSTEM;
      --  pclk = Src / (CLKM_DIV_NUM * (CLKCNT_N + 1)).  Two-stage divider: the
      --  module divider (Nm, 2 .. 255) makes LCD_CLK, the pixel prescale
      --  (P = CLKCNT_N + 1, 1 .. 64) divides that down to the pixel clock.
      --
      --  The pixel division MUST go in the prescale, not the module divider.  The
      --  data bus is updated at LCD_CLK and has to be stable before each pixel-clock
      --  edge; a prescale > 1 is what provides that setup margin.  Folding the whole
      --  divider into the module stage and leaving CLKCNT_N = 0 (with EQU_SYSCLK
      --  off) clocks data out with no setup time, so the attached device samples it
      --  mid-transition -- e.g. an i80 e-paper source driver latches garbled
      --  columns.  This matches esp-idf's lcd_ll, which documents that the prescale
      --  "can't be zero" and that the divide-by-1 case must set LCD_CLK_EQU_SYSCLK.
      --  (The old code put the division in Nm and set CLKCNT_N = 0 for any
      --  pclk above ~625 kHz -- i.e. every realistic display clock.)
      Total      : constant Natural := Natural'Max (2, Src_Hz / Pclk_Hz);
      --  Module divider: just large enough to keep the prescale within its 64 max.
      Nm         : constant Natural := Natural'Max (2, Natural'Min (255, (Total + 63) / 64));
      --  Prescale carries the rest of the division (clamped to its 1 .. 64 range).
      P          : constant Natural := Natural'Max (1, Natural'Min (64, Total / Nm));
      --  CLKCNT_N can't be 0; the divide-by-1 case is expressed via EQU_SYSCLK.
      Equ_Sysclk : constant Boolean := P = 1;
      Clk_Cnt    : constant Natural := (if P = 1 then 1 else P - 1);
   begin
      SYSTEM_Periph.PERIP_CLK_EN1.LCD_CAM_CLK_EN := True;
      SYSTEM_Periph.PERIP_RST_EN1.LCD_CAM_RST := True;     --  default set; pulse
      SYSTEM_Periph.PERIP_RST_EN1.LCD_CAM_RST := False;

      --  Clock: source sel 3, module = src/Nm, pixel = module/P.
      LCD_CAM_Periph.LCD_CLOCK :=
        (LCD_CLK_SEL        => 3,
         LCD_CLKM_DIV_NUM   => LCD_CLOCK_LCD_CLKM_DIV_NUM_Field (Nm),
         LCD_CLKM_DIV_A     => 1,
         LCD_CLKM_DIV_B     => 0,
         LCD_CLKCNT_N       => LCD_CLOCK_LCD_CLKCNT_N_Field (Clk_Cnt),
         LCD_CLK_EQU_SYSCLK => Equ_Sysclk,
         LCD_CK_OUT_EDGE    => False,
         CLK_EN             => True,
         others             => <>);

      --  8-bit data-out mode (no command/dummy phases).
      LCD_CAM_Periph.LCD_USER :=
        (LCD_DOUT          => True,
         LCD_2BYTE_EN      => False,
         LCD_CMD           => False,
         LCD_DUMMY         => False,
         LCD_ALWAYS_OUT_EN => False,
         others            => <>);
      LCD_CAM_Periph.LCD_MISC.LCD_AFIFO_RESET := True;        --  self-clearing

      --  No DMA channel is claimed here: Transmit claims one transiently, so an
      --  idle open controller ties up none of the five-channel pool.
      B.Valid := True;
   end Open;

   function Is_Valid (B : Bus) return Boolean
   is (B.Valid);

   --------------------
   -- Configure_Pins --
   --------------------

   procedure Configure_Pins (B : Bus; Data : Data_Pins; Pclk : ESP32S3.GPIO.Optional_Pin) is
      use type ESP32S3.GPIO.Pad_Number;
   begin
      if not B.Valid then
         return;
      end if;
      for I in Data'Range loop
         if Data (I) /= G.No_Pin then
            Drive_Out (ESP32S3.GPIO.Pin_Id (Data (I)), Sigs.LCD_DATA_OUT0 + I);
         end if;
      end loop;
      if Pclk /= G.No_Pin then
         Drive_Out (ESP32S3.GPIO.Pin_Id (Pclk), Sigs.LCD_PCLK);
      end if;
   end Configure_Pins;

   --------------
   -- Open_RGB --
   --------------

   procedure Open_RGB (B : in out Bus; Config : RGB_Config) is
      use ESP32S3_Registers.SYSTEM;
      --  Same two-stage pixel-clock divider as the i8080 Open (see there).
      Total      : constant Natural := Natural'Max (2, Src_Hz / Config.Pclk_Hz);
      Nm         : constant Natural :=
        Natural'Max (2, Natural'Min (255, (Total + 63) / 64));
      P          : constant Natural := Natural'Max (1, Natural'Min (64, Total / Nm));
      Equ_Sysclk : constant Boolean := P = 1;
      Clk_Cnt    : constant Natural := (if P = 1 then 1 else P - 1);
      --  Full line / frame periods (active + sync + both porches).
      H_Total    : constant Natural :=
        Config.H_Sync + Config.H_Back + Config.H_Res + Config.H_Front;
      V_Total    : constant Natural :=
        Config.V_Sync + Config.V_Back + Config.V_Res + Config.V_Front;
   begin
      SYSTEM_Periph.PERIP_CLK_EN1.LCD_CAM_CLK_EN := True;
      SYSTEM_Periph.PERIP_RST_EN1.LCD_CAM_RST := True;   --  default set; pulse
      SYSTEM_Periph.PERIP_RST_EN1.LCD_CAM_RST := False;

      --  Clock: source sel 3 (160 MHz), module = src/Nm, pixel = module/P.
      LCD_CAM_Periph.LCD_CLOCK :=
        (LCD_CLK_SEL        => 3,
         LCD_CLKM_DIV_NUM   => LCD_CLOCK_LCD_CLKM_DIV_NUM_Field (Nm),
         LCD_CLKM_DIV_A     => 1,
         LCD_CLKM_DIV_B     => 0,
         LCD_CLKCNT_N       => LCD_CLOCK_LCD_CLKCNT_N_Field (Clk_Cnt),
         LCD_CLK_EQU_SYSCLK => Equ_Sysclk,
         LCD_CK_OUT_EDGE    => Config.Pclk_Falling,
         CLK_EN             => True,
         others             => <>);

      --  Continuous data-out at the panel's colour depth.
      LCD_CAM_Periph.LCD_USER :=
        (LCD_DOUT          => True,
         LCD_ALWAYS_OUT_EN => True,           --  RGB streams forever, not one shot
         LCD_2BYTE_EN      => Config.Two_Byte,
         LCD_CMD           => False,
         LCD_DUMMY         => False,
         others            => <>);

      --  Panel timing.  Register mapping per esp-idf lcd_ll:
      --    HB_FRONT  = H_Back + H_Sync - 1     HA_WIDTH  = H_Res - 1
      --    HT_WIDTH  = H_Total - 1             VB_FRONT  = V_Back + V_Sync - 1
      --    VA_HEIGHT = V_Res - 1               VT_HEIGHT = V_Total - 1
      LCD_CAM_Periph.LCD_CTRL :=
        (LCD_HB_FRONT    =>
           LCD_CTRL_LCD_HB_FRONT_Field (Config.H_Back + Config.H_Sync - 1),
         LCD_VA_HEIGHT   => LCD_CTRL_LCD_VA_HEIGHT_Field (Config.V_Res - 1),
         LCD_VT_HEIGHT   => LCD_CTRL_LCD_VT_HEIGHT_Field (V_Total - 1),
         LCD_RGB_MODE_EN => True,
         others          => <>);
      LCD_CAM_Periph.LCD_CTRL1 :=
        (LCD_VB_FRONT =>
           LCD_CTRL1_LCD_VB_FRONT_Field (Config.V_Back + Config.V_Sync - 1),
         LCD_HA_WIDTH => LCD_CTRL1_LCD_HA_WIDTH_Field (Config.H_Res - 1),
         LCD_HT_WIDTH => LCD_CTRL1_LCD_HT_WIDTH_Field (H_Total - 1),
         others       => <>);
      LCD_CAM_Periph.LCD_CTRL2 :=
        (LCD_VSYNC_WIDTH    =>
           LCD_CTRL2_LCD_VSYNC_WIDTH_Field (Config.V_Sync - 1),
         LCD_HSYNC_WIDTH    =>
           LCD_CTRL2_LCD_HSYNC_WIDTH_Field (Config.H_Sync - 1),
         LCD_VSYNC_IDLE_POL => Config.VSync_Idle_High,
         LCD_HSYNC_IDLE_POL => Config.HSync_Idle_High,
         LCD_DE_IDLE_POL    => Config.DE_Idle_High,
         LCD_HS_BLANK_EN    => True,        --  HSYNC pulses through the blank lines
         LCD_HSYNC_POSITION => 0,
         others             => <>);

      --  Enable the blank region, auto-restart every frame, and reset the async
      --  FIFO.  LCD_NEXT_FRAME_EN is essential for RGB: without it the controller
      --  runs exactly ONE frame, clears LCD_START and stops (panel goes blank);
      --  with it the timing generator re-triggers each frame so the display
      --  free-runs.  The AFIFO threshold keeps its reset default (matching esp-idf,
      --  which leaves it alone) -- with the bounce-buffer feed below the FIFO stays
      --  full, so there is no data-vs-DE skew to trim out.  Starting the refresh
      --  (DMA + LCD_START) is the next step, not part of init.
      LCD_CAM_Periph.LCD_MISC :=
        (LCD_BK_EN         => True,
         LCD_NEXT_FRAME_EN => True,
         LCD_AFIFO_RESET   => True,
         others            => <>);

      B.Valid := True;
   end Open_RGB;

   -----------------------
   -- Configure_RGB_Pins --
   -----------------------

   procedure Configure_RGB_Pins (B : Bus; Pins : RGB_Pins) is
      use type ESP32S3.GPIO.Pad_Number;
   begin
      if not B.Valid then
         return;
      end if;
      for I in Pins.Data'Range loop
         if Pins.Data (I) /= G.No_Pin then
            Drive_Out (ESP32S3.GPIO.Pin_Id (Pins.Data (I)), Sigs.LCD_DATA_OUT0 + I);
         end if;
      end loop;
      if Pins.Pclk /= G.No_Pin then
         Drive_Out (ESP32S3.GPIO.Pin_Id (Pins.Pclk), Sigs.LCD_PCLK);
      end if;
      if Pins.HSync /= G.No_Pin then
         Drive_Out (ESP32S3.GPIO.Pin_Id (Pins.HSync), Sigs.LCD_H_SYNC);
      end if;
      if Pins.VSync /= G.No_Pin then
         Drive_Out (ESP32S3.GPIO.Pin_Id (Pins.VSync), Sigs.LCD_V_SYNC);
      end if;
      if Pins.DE /= G.No_Pin then
         Drive_Out (ESP32S3.GPIO.Pin_Id (Pins.DE), Sigs.LCD_H_ENABLE);
      end if;
   end Configure_RGB_Pins;

   --------------------------------------------------------------------------
   --  Bounce-buffer streaming (matches esp-idf's esp_lcd_rgb_panel bounce mode).
   --
   --  The GDMA does NOT read the PSRAM framebuffer directly -- that path latches
   --  a random startup phase (the image lands at a different offset each boot)
   --  and can glitch under PSRAM contention.  Instead the DMA ping-pongs two
   --  small INTERNAL-SRAM "bounce" buffers to LCD_CAM, and the DMA's own per-half
   --  completion INTERRUPT (the Fill_Half hook) refills the half just drained by
   --  copying the next chunk of the framebuffer into it -- paced by the DMA, and
   --  in-ISR so a short half period (~125 us) is always met (a task would refill
   --  a few us late, letting the DMA lap it and re-send stale bytes -> flicker).
   --  A single descriptor per half caps a half at 4095 bytes, so the chunk is
   --  the largest 32-byte multiple <= 4064 that DIVIDES the frame -- keeping the
   --  two-half ring frame-aligned, which is what pins the image in place.
   --------------------------------------------------------------------------

   Max_Half   : constant := 4064;                 --  <= 4095 (UInt12), 32-aligned
   Bounce_Buf : array (0 .. 2 * Max_Half - 1) of aliased Unsigned_8
     with Alignment => 32;                        --  two halves, internal SRAM

   RGB_Chan   : GD.Channel;                        --  held for the whole refresh
   FB_Base    : System.Address := System.Null_Address;
   FB_Len     : Natural := 0;
   Half_Bytes : Natural := 0 with Volatile;        --  chunk per half (divides FB_Len)
   Cur_Off    : Natural := 0 with Volatile;        --  next framebuffer byte to copy

   --  Copy the next Half_Bytes of the framebuffer into bounce half H, then
   --  advance (wrapping at the frame end -- Half_Bytes divides FB_Len, so the
   --  wrap always lands on a half boundary, i.e. on frame pixel 0).  Runs in the
   --  GDMA completion ISR (registered as the stream-refill hook), so it must stay
   --  a plain copy -- no blocking, no allocation.
   procedure Fill_Half (H : GD.Ring_Half) is
      Count : constant Natural := Half_Bytes;
      Dst   : constant System.Address := Bounce_Buf (H * Count)'Address;
      Src   : constant System.Address := FB_Base + Storage_Offset (Cur_Off);
      subtype Blk is Storage_Array (1 .. Storage_Offset (Count));
      D : Blk with Import, Address => Dst;
      S : Blk with Import, Address => Src;
   begin
      D := S;
      Cur_Off := Cur_Off + Count;
      if Cur_Off >= FB_Len then
         Cur_Off := 0;
      end if;
   end Fill_Half;

   ---------------
   -- Start_RGB --
   ---------------

   procedure Start_RGB (B : Bus; Framebuffer : System.Address; Length : Natural) is
   begin
      if not B.Valid or else Length = 0 then
         return;
      end if;
      FB_Base := Framebuffer;
      FB_Len  := Length;

      --  Largest 32-byte-multiple bounce chunk (<= 4064) that divides the frame.
      Half_Bytes := 32;
      declare
         HB : Natural := Max_Half;
      begin
         while HB >= 32 loop
            if FB_Len mod HB = 0 then
               Half_Bytes := HB;
               exit;
            end if;
            HB := HB - 32;
         end loop;
      end;
      Cur_Off := 0;

      GD.Claim (RGB_Chan, GD.LCD_CAM);
      if not GD.Is_Valid (RGB_Chan) then
         return;
      end if;

      --  Prime both halves (framebuffer bytes 0 .. 2*Half_Bytes-1) so the DMA has
      --  real pixels from the first clock; register the in-ISR refill hook; then
      --  start the ping-pong stream.
      Fill_Half (0);
      Fill_Half (1);
      LCD_CAM_Periph.LCD_MISC.LCD_AFIFO_RESET := True;
      GD.Set_Stream_Refill (RGB_Chan, Fill_Half'Access);
      GD.Start_Stream (RGB_Chan, Bounce_Buf'Address, Half_Bytes);

      --  Let the async FIFO fill from the (fast, internal-SRAM) bounce stream
      --  before the timing generator starts, then run the LCD sequence.
      for I in 1 .. 4_000 loop
         Asm ("nop", Volatile => True);
      end loop;
      LCD_CAM_Periph.LCD_USER.LCD_UPDATE := True;
      LCD_CAM_Periph.LCD_USER.LCD_START := True;
   end Start_RGB;

   --  With bounce buffers the DMA never reads PSRAM: the refill hook copies the
   --  framebuffer through the cache, coherent with the CPU's drawing, so there is
   --  nothing to write back.  Kept for API symmetry with the i8080 path.
   procedure Flush_RGB (Framebuffer : System.Address; Length : Natural) is
      pragma Unreferenced (Framebuffer, Length);
   begin
      null;
   end Flush_RGB;

   procedure Stop_RGB is
   begin
      LCD_CAM_Periph.LCD_USER.LCD_START := False;
      GD.Stop (RGB_Chan, GD.Mem_To_Periph);   --  also clears the refill hook
      GD.Release (RGB_Chan);
   end Stop_RGB;

   ----------------------
   -- Enable_Clock_Out --
   ----------------------

   procedure Enable_Clock_Out (B : Bus; Pclk_Pad : ESP32S3.GPIO.Pin_Id) is
   begin
      if not B.Valid then
         return;
      end if;
      Drive_Out (Pclk_Pad, Sigs.LCD_PCLK);
      --  Continuous output: the transaction never ends, so PCLK free-runs.
      LCD_CAM_Periph.LCD_USER.LCD_ALWAYS_OUT_EN := True;
      LCD_CAM_Periph.LCD_USER.LCD_DOUT := True;
      LCD_CAM_Periph.LCD_USER.LCD_DOUT_CYCLELEN := 8_191;
      LCD_CAM_Periph.LCD_USER.LCD_UPDATE := True;
      LCD_CAM_Periph.LCD_USER.LCD_START := True;
   end Enable_Clock_Out;

   --------------
   -- Transmit --
   --------------

   procedure Transmit (B : Bus; Tx : System.Address; Length : Natural; Ok : out Boolean) is
      Wait : Natural := 5_000_000;
      Chan : GD.Channel;          --  claimed transiently; released on return
   begin
      Ok := False;
      if not B.Valid or else Length = 0 or else Length > 4095 then
         return;
      end if;
      GD.Claim (Chan, GD.LCD_CAM);
      if not GD.Is_Valid (Chan) then
         --  pool momentarily exhausted
         return;
      end if;

      --  One byte per PCLK; arm the GDMA OUT path with the buffer.
      LCD_CAM_Periph.LCD_USER.LCD_ALWAYS_OUT_EN := False;
      LCD_CAM_Periph.LCD_USER.LCD_DOUT := True;
      LCD_CAM_Periph.LCD_USER.LCD_DOUT_CYCLELEN := LCD_USER_LCD_DOUT_CYCLELEN_Field (Length - 1);
      LCD_CAM_Periph.LCD_MISC.LCD_AFIFO_RESET := True;

      GD.Start (Chan, GD.Mem_To_Periph, Tx, Length);

      LCD_CAM_Periph.LC_DMA_INT_CLR.LCD_TRANS_DONE_INT_CLR := True;
      LCD_CAM_Periph.LCD_USER.LCD_UPDATE := True;
      LCD_CAM_Periph.LCD_USER.LCD_START := True;

      while not LCD_CAM_Periph.LC_DMA_INT_RAW.LCD_TRANS_DONE_INT_RAW and then Wait > 0 loop
         Wait := Wait - 1;
      end loop;
      Ok := LCD_CAM_Periph.LC_DMA_INT_RAW.LCD_TRANS_DONE_INT_RAW;
      LCD_CAM_Periph.LC_DMA_INT_CLR.LCD_TRANS_DONE_INT_CLR := True;
   end Transmit;

end ESP32S3.LCD.Engine;
