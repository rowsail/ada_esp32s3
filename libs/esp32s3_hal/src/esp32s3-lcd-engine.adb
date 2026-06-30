with ESP32S3_Registers;          use ESP32S3_Registers;
with ESP32S3_Registers.LCD_CAM; use ESP32S3_Registers.LCD_CAM;
with ESP32S3_Registers.GPIO;
with ESP32S3_Registers.SYSTEM;

package body ESP32S3.LCD.Engine is

   package GD renames ESP32S3.GDMA;
   package GR renames ESP32S3_Registers.GPIO;
   package G  renames ESP32S3.GPIO;

   Src_Hz : constant := 160_000_000;            --  LCD_CLK_SEL = 3 source clock

   procedure Drive_Out (Pad : G.Pin_Id; Sig : Natural) is
      O : GR.FUNC_OUT_SEL_CFG_Register :=
            GR.GPIO_Periph.FUNC_OUT_SEL_CFG (Natural (Pad));
   begin
      G.Configure (Pad, Mode => G.Output, Drive => G.Drive_Strong);
      O.OUT_SEL := GR.FUNC_OUT_SEL_CFG_OUT_SEL_Field (Sig);
      O.OEN_SEL := False;
      GR.GPIO_Periph.FUNC_OUT_SEL_CFG (Natural (Pad)) := O;
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
      Total : constant Natural := Natural'Max (2, Src_Hz / Pclk_Hz);
      --  Module divider: just large enough to keep the prescale within its 64 max.
      Nm    : constant Natural :=
        Natural'Max (2, Natural'Min (255, (Total + 63) / 64));
      --  Prescale carries the rest of the division (clamped to its 1 .. 64 range).
      P     : constant Natural := Natural'Max (1, Natural'Min (64, Total / Nm));
      --  CLKCNT_N can't be 0; the divide-by-1 case is expressed via EQU_SYSCLK.
      Equ_Sysclk : constant Boolean := P = 1;
      Clk_Cnt    : constant Natural := (if P = 1 then 1 else P - 1);
   begin
      SYSTEM_Periph.PERIP_CLK_EN1.LCD_CAM_CLK_EN := True;
      SYSTEM_Periph.PERIP_RST_EN1.LCD_CAM_RST    := True;     --  default set; pulse
      SYSTEM_Periph.PERIP_RST_EN1.LCD_CAM_RST    := False;

      --  Clock: source sel 3, module = src/Nm, pixel = module/P.
      LCD_CAM_Periph.LCD_CLOCK :=
        (LCD_CLK_SEL => 3, LCD_CLKM_DIV_NUM => LCD_CLOCK_LCD_CLKM_DIV_NUM_Field (Nm),
         LCD_CLKM_DIV_A => 1, LCD_CLKM_DIV_B => 0,
         LCD_CLKCNT_N => LCD_CLOCK_LCD_CLKCNT_N_Field (Clk_Cnt),
         LCD_CLK_EQU_SYSCLK => Equ_Sysclk, LCD_CK_OUT_EDGE => False,
         CLK_EN => True, others => <>);

      --  8-bit data-out mode (no command/dummy phases).
      LCD_CAM_Periph.LCD_USER :=
        (LCD_DOUT => True, LCD_2BYTE_EN => False, LCD_CMD => False,
         LCD_DUMMY => False, LCD_ALWAYS_OUT_EN => False, others => <>);
      LCD_CAM_Periph.LCD_MISC.LCD_AFIFO_RESET := True;        --  self-clearing

      --  No DMA channel is claimed here: Transmit claims one transiently, so an
      --  idle open controller ties up none of the five-channel pool.
      B.Valid := True;
   end Open;

   function Is_Valid (B : Bus) return Boolean is (B.Valid);

   --------------------
   -- Configure_Pins --
   --------------------

   procedure Configure_Pins (B    : Bus;
                             Data : Data_Pins;
                             Pclk : ESP32S3.GPIO.Optional_Pin)
   is
      use type ESP32S3.GPIO.Pad_Number;
   begin
      if not B.Valid then
         return;
      end if;
      for I in Data'Range loop
         if Data (I) /= G.No_Pin then
            Drive_Out (ESP32S3.GPIO.Pin_Id (Data (I)), 133 + I);  --  LCD_DATA_OUTi
         end if;
      end loop;
      if Pclk /= G.No_Pin then
         Drive_Out (ESP32S3.GPIO.Pin_Id (Pclk), 154);            --  LCD_PCLK
      end if;
   end Configure_Pins;

   ----------------------
   -- Enable_Clock_Out --
   ----------------------

   procedure Enable_Clock_Out (B : Bus; Pclk_Pad : ESP32S3.GPIO.Pin_Id) is
   begin
      if not B.Valid then
         return;
      end if;
      Drive_Out (Pclk_Pad, 154);
      --  Continuous output: the transaction never ends, so PCLK free-runs.
      LCD_CAM_Periph.LCD_USER.LCD_ALWAYS_OUT_EN  := True;
      LCD_CAM_Periph.LCD_USER.LCD_DOUT           := True;
      LCD_CAM_Periph.LCD_USER.LCD_DOUT_CYCLELEN  := 8_191;
      LCD_CAM_Periph.LCD_USER.LCD_UPDATE         := True;
      LCD_CAM_Periph.LCD_USER.LCD_START          := True;
   end Enable_Clock_Out;

   --------------
   -- Transmit --
   --------------

   procedure Transmit (B : Bus; Tx : System.Address; Length : Natural;
                       Ok : out Boolean)
   is
      Wait : Natural := 5_000_000;
      Chan : GD.Channel;          --  claimed transiently; released on return
   begin
      Ok := False;
      if not B.Valid or else Length = 0 or else Length > 4095 then
         return;
      end if;
      GD.Claim (Chan, GD.LCD_CAM);
      if not GD.Is_Valid (Chan) then     --  pool momentarily exhausted
         return;
      end if;

      --  One byte per PCLK; arm the GDMA OUT path with the buffer.
      LCD_CAM_Periph.LCD_USER.LCD_ALWAYS_OUT_EN := False;
      LCD_CAM_Periph.LCD_USER.LCD_DOUT          := True;
      LCD_CAM_Periph.LCD_USER.LCD_DOUT_CYCLELEN :=
        LCD_USER_LCD_DOUT_CYCLELEN_Field (Length - 1);
      LCD_CAM_Periph.LCD_MISC.LCD_AFIFO_RESET := True;

      GD.Start (Chan, GD.Mem_To_Periph, Tx, Length);

      LCD_CAM_Periph.LC_DMA_INT_CLR.LCD_TRANS_DONE_INT_CLR := True;
      LCD_CAM_Periph.LCD_USER.LCD_UPDATE := True;
      LCD_CAM_Periph.LCD_USER.LCD_START  := True;

      while not LCD_CAM_Periph.LC_DMA_INT_RAW.LCD_TRANS_DONE_INT_RAW
        and then Wait > 0
      loop
         Wait := Wait - 1;
      end loop;
      Ok := LCD_CAM_Periph.LC_DMA_INT_RAW.LCD_TRANS_DONE_INT_RAW;
      LCD_CAM_Periph.LC_DMA_INT_CLR.LCD_TRANS_DONE_INT_CLR := True;
   end Transmit;

end ESP32S3.LCD.Engine;
