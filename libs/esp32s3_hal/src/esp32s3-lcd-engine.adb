with System;
with System.Machine_Code;            use System.Machine_Code;
with System.Storage_Elements;        use System.Storage_Elements;
with Ada.Interrupts.Names;
with Ada.Synchronous_Task_Control;   use Ada.Synchronous_Task_Control;
with Interfaces;                     use Interfaces;
with ESP32S3_Registers;         use ESP32S3_Registers;
with ESP32S3_Registers.LCD_CAM; use ESP32S3_Registers.LCD_CAM;
with ESP32S3_Registers.GPIO;
with ESP32S3_Registers.SYSTEM;
with ESP32S3_Registers.INTERRUPT_CORE0;
with ESP32S3.GPIO_Signals;

package body ESP32S3.LCD.Engine is

   package GD renames ESP32S3.GDMA;
   package GR renames ESP32S3_Registers.GPIO;
   package G renames ESP32S3.GPIO;
   package Sigs renames ESP32S3.GPIO_Signals;

   Src_Hz : constant := 160_000_000;            --  LCD_CLK_SEL = 3 source clock

   --  Panel geometry captured by Open_RGB, used to size the bounce halves.
   RGB_Line_Bytes : Natural := 0 with Volatile;    --  bytes per scan line
   RGB_Px_Bytes   : Natural := 1 with Volatile;    --  bytes per pixel (1 or 2)
   RGB_V_Res      : Natural := 0 with Volatile;    --  active lines per frame

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
      RGB_Line_Bytes := Config.H_Res * (if Config.Two_Byte then 2 else 1);
      RGB_Px_Bytes   := (if Config.Two_Byte then 2 else 1);
      RGB_V_Res      := Config.V_Res;

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
            --  Route line I from its mapped LCD_DATA_OUT signal (default I); a
            --  fan-out map lets one signal drive several lines (8-bit -> RGB565).
            Drive_Out (ESP32S3.GPIO.Pin_Id (Pins.Data (I)),
                       Sigs.LCD_DATA_OUT0 + Pins.Signals (I));
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

   --  Two bounce halves in internal SRAM (the array below is statically the 64 KB
   --  worst case).  Each half spans several DMA descriptors (GDMA.Start_Bounce)
   --  but fires ONE interrupt (4064-byte single-descriptor halves needed
   --  192/frame and could not keep up, which rolled the picture).  40-line halves
   --  double the per-half refill budget over the earlier 20: the copy has thin
   --  margin against PSRAM contention plus ISR start-latency (handlers dispatch
   --  at EXCM_LEVEL and do not preempt each other), and a late refill paints a
   --  band of stale bytes; the wider halves also halve the interrupt rate.  A
   --  16-bit panel exceeds Max_Half at 40 lines and falls back automatically to
   --  the largest dividing height that fits (Start_Bounce sizing loop below).
   Max_Half     : constant := 32768;             --  cap on one half, in bytes
   Bounce_Lines : constant := 40;                --  target bounce height, in lines
   Bounce_Buf   : array (0 .. 2 * Max_Half - 1) of aliased Unsigned_8
     with Alignment => 32;

   RGB_Chan     : GD.Channel;                      --  held for the whole refresh
   FB_Len     : Natural := 0;
   Half_Bytes : Natural := 0 with Volatile;        --  bytes per bounce half
   Cur_Off    : Natural := 0 with Volatile;        --  next framebuffer byte to copy

   --  Desync recovery, ported from esp-idf's esp_lcd_panel_rgb.c.  The LCD_CAM
   --  scan and the GDMA bounce ring can drift apart -- a missed refill, a
   --  merged EOF interrupt, or the peripheral's own "permanent desync" failure
   --  mode -- and once adrift they never re-converge on their own.  esp-idf's
   --  driver counts DMA EOFs per frame and, at every VSYNC (during vertical
   --  blanking), restarts the DMA at the frame start whenever the count falls
   --  short of a frame's worth -- or unconditionally, its
   --  CONFIG_LCD_RGB_RESTART_IN_VSYNC.  The restart enters the ring through a
   --  descriptor that skips FIFO-depth + 1 pixels: the LCD_CAM async FIFO
   --  preserves that many across a DMA reset, and re-sending them shifts the
   --  picture (verbatim esp-idf: "the single-frame desync this leads to is
   --  preferable to the permanent desync that could otherwise happen").
   Fifo_Preserve_Px : constant := 17;   --  LCD_LL_FIFO_DEPTH (16) + 1

   Boot_Restart : Boolean := False with Volatile;
   --  One forced restart on the second VSYNC after Start: pins the ring/scan
   --  alignment to the restart geometry deterministically on every boot
   --  (without it the priming-vs-LCD_START race can latch a per-boot offset).

   BB_EOF_Count : Natural := 0 with Volatile;
   --  Refill EOFs seen since the last VSYNC; a full frame yields
   --  FB_Len / Half_Bytes of them.  Counted in Refill_Hook (real DMA EOFs
   --  only -- priming calls to Fill_Half do not count).

   Locked : Boolean := False with Volatile;
   --  The pipeline has produced its first VSYNC (Calib_Done released)

   Calib_Done  : Suspension_Object;             --  released once the phase is latched

   --  Double buffering, ESP-IDF's model: the refill copies from BB_Fb (Shown);
   --  the app draws BB_Fb (1 - Shown) and calls Flip, which just toggles Shown at
   --  the next FRAME boundary (below) -- tear-free, and NO cache flush needed (the
   --  refill reads the framebuffer through the coherent CPU cache).  A single-
   --  buffer Start_RGB points both entries at the same framebuffer.
   BB_Fb        : array (0 .. 1) of System.Address :=
                    (others => System.Null_Address);
   Shown        : Natural := 0 with Volatile;
   Flip_Req     : Boolean := False with Volatile;
   BB_Flip_Done : Suspension_Object;

   --  Which refresh mode is live (dispatches Flip / Back_Buffer / Sync).
   type RGB_Mode_Kind is (Mode_Off, Mode_Bounce, Mode_Direct);
   RGB_Mode : RGB_Mode_Kind := Mode_Off with Volatile;

   --  Direct-mode state (see Start_RGB_Direct far below).
   DB_Relock_CPU_Int : constant := 23;   --  Device_L3_0 (L3, above the L2 TWAI)
   DB_Front  : System.Address := System.Null_Address with Volatile;
   DB_Back   : System.Address := System.Null_Address with Volatile;
   DB_Locked : Boolean := False with Volatile;    --  direct startup phase pinned?
   Sync_Sig  : Suspension_Object;                  --  pulsed at each VSYNC

   --  Copy the next Half_Bytes of the shown framebuffer into bounce half H, then
   --  advance (wrapping at the frame end -- Half_Bytes divides FB_Len, so the wrap
   --  always lands on a half boundary, i.e. on frame pixel 0).  The VSYNC phase
   --  lock keeps Cur_Off a multiple of Half_Bytes, so a whole half always fits
   --  before the frame end (no wrap-straddle to split).  Runs in the GDMA
   --  completion ISR (the stream-refill hook), so it must stay a plain copy -- no
   --  blocking, no allocation.  Inline 32-bit-wide copy (buffers 4-aligned): fast
   --  enough to sustain the refill, where the runtime byte memcpy was not.
   --  Temporary JTAG-read refill-timing diagnostics (volatile, no I/O).
   --  One 40-line bounce half at 16 MHz pclk is ~490_000 CPU cycles; the
   --  20-line vertical blank pauses EOFs for ~245_000 more, so a healthy
   --  Gap_Max is ~735_000.
   Fill_Prev_CC : Unsigned_32 := 0 with Volatile;
   Fill_Gap_Max : Unsigned_32 := 0 with Volatile;   --  max entry-to-entry gap
   Fill_Dur_Max : Unsigned_32 := 0 with Volatile;   --  max copy duration
   Fill_Late    : Unsigned_32 := 0 with Volatile;   --  gaps past healthy max

   procedure Fill_Half (H : GD.Ring_Half) is
      Count : constant Natural := Half_Bytes;
      Dst   : constant System.Address := Bounce_Buf (H * Count)'Address;
      type WA is array (0 .. Count / 4 - 1) of Unsigned_32;
      D : WA with Import, Address => Dst;
      S : WA with Import, Address => BB_Fb (Shown) + Storage_Offset (Cur_Off);
      CC0, CC1 : Unsigned_32;
   begin
      Asm ("rsr.ccount %0",
           Outputs => Unsigned_32'Asm_Output ("=r", CC0), Volatile => True);
      if Fill_Prev_CC /= 0 then
         if CC0 - Fill_Prev_CC > Fill_Gap_Max then
            Fill_Gap_Max := CC0 - Fill_Prev_CC;
         end if;
         if CC0 - Fill_Prev_CC > 900_000 then
            Fill_Late := Fill_Late + 1;
         end if;
      end if;
      Fill_Prev_CC := CC0;
      for I in D'Range loop
         D (I) := S (I);
      end loop;
      Asm ("rsr.ccount %0",
           Outputs => Unsigned_32'Asm_Output ("=r", CC1), Volatile => True);
      if CC1 - CC0 > Fill_Dur_Max then
         Fill_Dur_Max := CC1 - CC0;
      end if;
      Cur_Off := Cur_Off + Count;
      if Cur_Off >= FB_Len then
         Cur_Off := 0;
         --  Frame boundary: apply a pending flip (switch source buffer) here, as
         --  esp-idf does in its bounce EOF handler.
         if Flip_Req then
            Shown    := 1 - Shown;
            Flip_Req := False;
            Set_True (BB_Flip_Done);
         end if;
      end if;
   end Fill_Half;

   --  The DMA-EOF refill hook: count the EOF for the per-frame desync check
   --  (priming calls to Fill_Half, e.g. from the VSYNC restart, do not
   --  count), then refill the drained half.  Library level (the GDMA hook
   --  contract; No_Implicit_Dynamic_Code).
   procedure Refill_Hook (H : GD.Ring_Half);

   procedure Refill_Hook (H : GD.Ring_Half) is
   begin
      BB_EOF_Count := BB_EOF_Count + 1;
      Fill_Half (H);
   end Refill_Hook;

   --------------------------------------------------------------------------
   --  LCD_CAM VSYNC interrupt (LCD_CAM source -> CPU_INT 21 = Device_L2_2).
   --
   --  BOUNCE mode re-locks the stream to the frame here EVERY VSYNC: reset the
   --  refill to frame start, re-prime both bounce halves from the shown buffer,
   --  reset the async FIFO and restart the DMA.  Without this the refill slips a
   --  little against the LCD frame every frame and the whole picture rolls
   --  vertically.  A pending Flip is applied here too, at the frame boundary.
   --  (This is esp-idf's CONFIG_LCD_RGB_RESTART_IN_VSYNC.)
   --
   --  DIRECT mode instead pins the startup phase once and pulses Sync each frame.
   --------------------------------------------------------------------------

   protected Vsync
     with Interrupt_Priority => Ada.Interrupts.Names.Device_L3_Priority
   is
      procedure Route;   --  map LCD_CAM int -> CPU_INT 23, enable the VSYNC cause
   private
      procedure Handler
      with Attach_Handler => Ada.Interrupts.Names.Device_L3_0;
   end Vsync;

   protected body Vsync is

      procedure Route is
         use ESP32S3_Registers.INTERRUPT_CORE0;
      begin
         INTERRUPT_CORE0_Periph.LCD_CAM_INT_MAP.LCD_CAM_INT_MAP :=
           DB_Relock_CPU_Int;
         LCD_CAM_Periph.LC_DMA_INT_CLR.LCD_VSYNC_INT_CLR := True;
         LCD_CAM_Periph.LC_DMA_INT_ENA.LCD_VSYNC_INT_ENA := True;
      end Route;

      procedure Handler is
      begin
         if not LCD_CAM_Periph.LC_DMA_INT_ST.LCD_VSYNC_INT_ST then
            return;
         end if;
         LCD_CAM_Periph.LC_DMA_INT_CLR.LCD_VSYNC_INT_CLR := True;

         case RGB_Mode is
            when Mode_Bounce =>
               --  Desync check, esp-idf's default mode: on a HEALTHY frame
               --  touch nothing at all.  A frame delivers FB_Len / Half_Bytes
               --  refill EOFs; the frame-boundary EOF is near-coincident with
               --  this interrupt, so an as-yet-unserviced EOF (visible in the
               --  raw status) counts too -- that makes the check deterministic
               --  rather than a service-order race.  A shortfall means EOFs
               --  were lost or merged (the refill fell behind the ring) or the
               --  LCD/DMA pair desynced: recover O(1), with NO copying here --
               --  reset the FIFO, restart the DMA at the frame start (ring
               --  node 0, FIFO-preserve bytes skipped) and declare the refill
               --  phase (both halves re-send their current content: one
               --  glitched frame, then clean; esp-idf accepts the same trade).
               declare
                  Expected  : constant Natural :=
                    (if Half_Bytes > 0 then FB_Len / Half_Bytes else 0);
                  Effective : constant Natural :=
                    BB_EOF_Count
                      + (if GD.Out_EOF_Pending (RGB_Chan) then 1 else 0);
                  Restart   : Boolean := Effective < Expected;
               begin
                  BB_EOF_Count := 0;
                  if Boot_Restart then
                     --  One-shot startup normalization (see Boot_Restart)
                     Boot_Restart := False;
                     Restart      := True;
                  end if;
                  if Restart then
                     LCD_CAM_Periph.LCD_MISC.LCD_AFIFO_RESET := True;
                     GD.Restart_Bounce (RGB_Chan);
                     Cur_Off := (2 * Half_Bytes) mod Natural'Max (FB_Len, 1);
                  end if;
               end;

               if not Locked then
                  Locked       := True;
                  Boot_Restart := True;    --  normalize on the NEXT VSYNC
                  Set_True (Calib_Done);   --  pipeline running; release Start
               end if;

            when Mode_Direct =>
               if not DB_Locked then
                  --  One-shot: pin the startup phase in this vertical blank.
                  LCD_CAM_Periph.LCD_MISC.LCD_AFIFO_RESET := True;
                  GD.Restart_Loop_Chain (RGB_Chan);
                  DB_Locked := True;
               end if;
               Set_True (Sync_Sig);   --  wake a task waiting on Sync

            when Mode_Off =>
               null;
         end case;
      end Handler;

   end Vsync;

   ------------------
   -- Start_Bounce --
   ------------------

   --  Common bounce bring-up.  Fb0/Fb1 are the two framebuffers (equal for the
   --  single-buffer Start_RGB); the stream starts on Fb0 (Shown = 0).
   procedure Start_Bounce (B : Bus; Fb0, Fb1 : System.Address; Length : Natural) is
   begin
      if not B.Valid or else Length = 0 then
         return;
      end if;
      if RGB_Line_Bytes = 0 or else RGB_V_Res = 0 then
         return;   --  Open_RGB must run first
      end if;
      BB_Fb (0) := Fb0;
      BB_Fb (1) := Fb1;
      Shown     := 0;
      Flip_Req  := False;
      Set_False (BB_Flip_Done);
      FB_Len    := Length;

      --  Bounce half = as many whole lines as divide the frame, up to Bounce_Lines
      --  and the buffer cap.  Whole lines keep each half a frame-dividing size, so
      --  the two-half ring stays frame-aligned.
      declare
         L : Natural := Natural'Min (Bounce_Lines, RGB_V_Res);
      begin
         while L > 1
           and then (RGB_V_Res mod L /= 0 or else L * RGB_Line_Bytes > Max_Half)
         loop
            L := L - 1;
         end loop;
         Half_Bytes := L * RGB_Line_Bytes;
      end;
      Cur_Off  := 0;

      --  Re-arm the desync recovery (see the note above Fifo_Preserve_Px).
      Locked       := False;
      Boot_Restart := False;
      BB_EOF_Count := 0;
      Set_False (Calib_Done);

      GD.Claim (RGB_Chan, GD.LCD_CAM);
      if not GD.Is_Valid (RGB_Chan) then
         return;
      end if;
      --  Prime both halves so the DMA has real pixels from the first clock;
      --  register the in-ISR refill hook; then start the multi-descriptor
      --  bounce, telling it how many bytes a VSYNC restart must skip (the
      --  LCD FIFO preserves that many across a DMA reset).
      Fill_Half (0);
      Fill_Half (1);
      LCD_CAM_Periph.LCD_MISC.LCD_AFIFO_RESET := True;
      GD.Set_Stream_Refill (RGB_Chan, Refill_Hook'Access);
      GD.Start_Bounce
        (RGB_Chan, Bounce_Buf'Address, Half_Bytes,
         Restart_Skip => Fifo_Preserve_Px * RGB_Px_Bytes);

      --  Let the async FIFO fill from the (fast, internal-SRAM) bounce stream
      --  before the timing generator starts, then run the LCD sequence.
      for I in 1 .. 4_000 loop
         Asm ("nop", Volatile => True);
      end loop;
      LCD_CAM_Periph.LCD_USER.LCD_UPDATE := True;
      LCD_CAM_Periph.LCD_USER.LCD_START := True;
      RGB_Mode := Mode_Bounce;

      --  Enable the VSYNC interrupt: it self-calibrates the refill phase over the
      --  first few frames, then re-locks it every frame (see the handler).
      Vsync.Route;

      --  Block until the phase lock has calibrated, so the caller can draw into
      --  the back buffer straight away without latching a slipped phase.
      Suspend_Until_True (Calib_Done);
   end Start_Bounce;

   ---------------
   -- Start_RGB --
   ---------------

   procedure Start_RGB (B : Bus; Framebuffer : System.Address; Length : Natural) is
   begin
      Start_Bounce (B, Framebuffer, Framebuffer, Length);
   end Start_RGB;

   procedure Start_RGB_DB
     (B : Bus; Fb0, Fb1 : System.Address; Length : Natural) is
   begin
      Start_Bounce (B, Fb0, Fb1, Length);
   end Start_RGB_DB;

   --  Write the CPU's drawing back to PSRAM.  ESSENTIAL for DIRECT mode (the DMA
   --  reads PSRAM, so it must see the new pixels); a harmless extra write-back for
   --  bounce mode (there the refill hook reads through the coherent cache anyway).
   procedure Flush_RGB (Framebuffer : System.Address; Length : Natural) is
   begin
      GD.Flush (Framebuffer, Length);
   end Flush_RGB;

   procedure Stop_RGB is
   begin
      RGB_Mode := Mode_Off;
      LCD_CAM_Periph.LC_DMA_INT_ENA.LCD_VSYNC_INT_ENA := False;   --  direct VSYNC
      LCD_CAM_Periph.LCD_USER.LCD_START := False;
      GD.Stop (RGB_Chan, GD.Mem_To_Periph);   --  also clears the refill hook
      GD.Release (RGB_Chan);
   end Stop_RGB;

   --------------------------------------------------------------------------
   --  DIRECT double-buffered mode.  The GDMA reads a PSRAM framebuffer STRAIGHT
   --  to LCD_CAM (near-zero CPU -- no per-frame copy, unlike bounce mode).  Two
   --  framebuffers: the DMA scans the front while the app prepares the back.
   --
   --  The catch: the scan-out DMA reads the front buffer from PSRAM continuously,
   --  so ANY CPU PSRAM traffic during the active region (drawing into the back
   --  buffer or writing it back) contends for the one PSRAM bus and starves the
   --  scan-out -> a moving noise band.  The fix is to do all of it during VERTICAL
   --  BLANKING, when the DMA is idle: Sync blocks until blanking starts, and the
   --  app then draws + Flush_RGB + Flip inside that ~one-line-times-VBlank window.
   --  Flip is a plain Repoint_Chain (the DMA is idle at the ring boundary here, so
   --  the swap is tear-free).  The startup phase is pinned once, on the first
   --  VSYNC, by a FIFO-reset + ring restart (else the stream lands at a random
   --  horizontal offset each boot).  Best for LIGHT/incremental updates that fit
   --  the blanking window; heavy full-frame redraws want bounce mode.  (State and
   --  the shared VSYNC handler are declared up near the bounce state above.)
   --------------------------------------------------------------------------

   ---------------------
   -- Start_RGB_Direct --
   ---------------------

   procedure Start_RGB_Direct
     (B : Bus; Fb0, Fb1 : System.Address; Length : Natural) is
   begin
      if not B.Valid or else Length = 0 then
         return;
      end if;
      DB_Front  := Fb0;
      DB_Back   := Fb1;
      DB_Locked := False;
      Set_False (Sync_Sig);

      GD.Claim (RGB_Chan, GD.LCD_CAM);
      if not GD.Is_Valid (RGB_Chan) then
         return;
      end if;

      LCD_CAM_Periph.LCD_MISC.LCD_AFIFO_RESET := True;
      GD.Start_Loop_Chain (RGB_Chan, Fb0, Length);   --  stream the front buffer
      for I in 1 .. 4_000 loop                       --  settle before LCD_START
         Asm ("nop", Volatile => True);
      end loop;
      LCD_CAM_Periph.LCD_USER.LCD_UPDATE := True;
      LCD_CAM_Periph.LCD_USER.LCD_START := True;

      Vsync.Route;   --  first VSYNC pins alignment; every VSYNC pulses Sync
      RGB_Mode := Mode_Direct;
   end Start_RGB_Direct;

   ----------
   -- Sync --
   ----------

   procedure Sync (B : Bus) is
   begin
      if not B.Valid or else RGB_Mode /= Mode_Direct then
         return;   --  only direct mode drives the VSYNC pulse
      end if;
      Set_False (Sync_Sig);
      Suspend_Until_True (Sync_Sig);   --  returns at the start of vertical blank
   end Sync;

   ----------
   -- Flip --
   ----------

   procedure Flip (B : Bus) is
      Tmp : System.Address;
   begin
      if not B.Valid then
         return;
      end if;
      case RGB_Mode is
         when Mode_Bounce =>
            --  Show the buffer the app just drew: request the refill to switch
            --  source at the next FRAME boundary, and block until it does (so the
            --  old front is then free to draw).  Tear-free; no flush needed.
            Set_False (BB_Flip_Done);
            Flip_Req := True;
            Suspend_Until_True (BB_Flip_Done);
         when Mode_Direct =>
            --  Retarget the scan-out ring at the (drawn + flushed) back buffer.
            --  MUST be called inside blanking (right after Sync), where the DMA is
            --  idle at the ring boundary, so the swap is tear-free.
            GD.Repoint_Chain (RGB_Chan, DB_Back);
            Tmp := DB_Front; DB_Front := DB_Back; DB_Back := Tmp;
         when Mode_Off =>
            null;
      end case;
   end Flip;

   function Back_Buffer return System.Address
   is (case RGB_Mode is
         when Mode_Bounce => BB_Fb (1 - Shown),   --  the buffer NOT being scanned
         when Mode_Direct => DB_Back,
         when Mode_Off    => System.Null_Address);

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
