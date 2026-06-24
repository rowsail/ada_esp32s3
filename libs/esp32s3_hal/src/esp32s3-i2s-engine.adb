with ESP32S3.GPIO;
with ESP32S3_Registers;         use ESP32S3_Registers;
with ESP32S3_Registers.I2S;     use ESP32S3_Registers.I2S;
with ESP32S3_Registers.I2S1;
with ESP32S3_Registers.GPIO;
with ESP32S3_Registers.SYSTEM;

package body ESP32S3.I2S.Engine is

   package GD renames ESP32S3.GDMA;            --  the DMA engine we consume
   package GR renames ESP32S3_Registers.GPIO;  --  GPIO matrix register layer

   Src_Hz : constant := 160_000_000;           --  CLK160 (PLL) I2S source clock

   --  I2S1 register block overlaid with the I2S0 layout (the two svd peripheral
   --  types are distinct but bit-identical), so one Periph_Ref drives either.
   I2S1_As0 : aliased ESP32S3_Registers.I2S.I2S0_Peripheral
     with Import, Volatile,
          Address => ESP32S3_Registers.I2S1.I2S1_Periph'Address;

   function Regs_Of (Port : I2S_Port) return Periph_Ref is
     (case Port is when I2S0 => I2S0_Periph'Access,
                   when I2S1 => I2S1_As0'Access);

   function GDMA_Periph (Port : I2S_Port) return GD.Peripheral is
     (case Port is when I2S0 => GD.I2S0, when I2S1 => GD.I2S1);

   --  GPIO-matrix signal indices (gpio_sig_map, ESP32-S3).  Output and input
   --  share an index space, so SD_OUT and SD_IN are the same number.
   type Sig is record
      Bck_Out, Ws_Out, Sd_Out, Bck_In, Ws_In, Sd_In : Natural;
      Mck_Out : Natural;          --  I2S master-clock output (0 => unsupported)
   end record;

   --  ESP32-S3 GPIO-matrix signal indices (gpio_sig_map.h).  I2S0_MCLK_OUT = 23
   --  (sits between BCK_OUT=22 and WS_OUT=24); the I2S1 MCLK index is not used
   --  here, so it is left 0 (Configure_Pins then skips routing it).
   function Signals (Port : I2S_Port) return Sig is
     (case Port is
         when I2S0 => (Bck_Out => 22, Ws_Out => 24, Sd_Out => 25,
                       Bck_In  => 26, Ws_In  => 27, Sd_In  => 25, Mck_Out => 23),
         when I2S1 => (Bck_Out => 28, Ws_Out => 29, Sd_Out => 30,
                       Bck_In  => 31, Ws_In  => 32, Sd_In  => 30, Mck_Out => 0));

   function Data_Bits (Bits : Sample_Bits) return Natural is
     (case Bits is when Bits_8  =>  8, when Bits_16 => 16,
                   when Bits_24 => 24, when Bits_32 => 32);

   procedure Drive_Out (Pad : ESP32S3.GPIO.Pin_Id; Signal : Natural) is
      Ix : constant Natural := Natural (Pad);
      O  : GR.FUNC_OUT_SEL_CFG_Register := GR.GPIO_Periph.FUNC_OUT_SEL_CFG (Ix);
   begin
      ESP32S3.GPIO.Configure (Pad, Mode => ESP32S3.GPIO.Output,
                              Drive => ESP32S3.GPIO.Drive_Strong);
      O.OUT_SEL := GR.FUNC_OUT_SEL_CFG_OUT_SEL_Field (Signal);
      GR.GPIO_Periph.FUNC_OUT_SEL_CFG (Ix) := O;
   end Drive_Out;

   procedure Route_In (Signal : Natural; Pad : ESP32S3.GPIO.Pin_Id;
                       As_Input : Boolean) is
   begin
      if As_Input then
         ESP32S3.GPIO.Configure (Pad, Mode => ESP32S3.GPIO.Input);
      end if;
      GR.GPIO_Periph.FUNC_IN_SEL_CFG (Signal) :=
        (IN_SEL => GR.FUNC_IN_SEL_CFG_IN_SEL_Field (Natural (Pad)),
         SEL    => True, others => <>);
   end Route_In;

   ----------
   -- Open --
   ----------

   procedure Open (B           : in out Bus;
                   Port        : I2S_Port;
                   Sample_Rate : Positive;
                   Bits        : Sample_Bits;
                   Mode        : I2S_Mode)
   is
      use ESP32S3_Registers.SYSTEM;
      R     : constant Periph_Ref := Regs_Of (Port);
      DB    : constant Natural := Data_Bits (Bits);
      Is_PDM : constant Boolean := Mode = ESP32S3.I2S.PDM;
      --  Bit-clocks per audio-sample period.  Standard TDM: Bits per slot x two
      --  slots (stereo).  PDM: the serial stream runs at 64x the sample rate (the
      --  sigma-delta OSR) times the 2x ratio between the TX up-sampler (fp/fs =
      --  960/480) and the RX decimator (DSR = 128); locked to one shared clock,
      --  TX up and RX down net to unity.
      Frame : constant Natural := (if Is_PDM then 128 else DB * 2);
      Bclk  : constant Natural := Sample_Rate * Frame;        --  serial bit clock
      M     : constant Natural := 8;                          --  BCK divider
      N     : constant Natural :=                             --  CLKM divider
        Natural'Max (2, Natural'Min (255, (Src_Hz + (Bclk * M) / 2) / (Bclk * M)));
   begin
      --  Module clock-gate + reset pulse.
      case Port is
         when I2S0 =>
            SYSTEM_Periph.PERIP_CLK_EN0.I2S0_CLK_EN := True;
            SYSTEM_Periph.PERIP_RST_EN0.I2S0_RST    := True;
            SYSTEM_Periph.PERIP_RST_EN0.I2S0_RST    := False;
         when I2S1 =>
            SYSTEM_Periph.PERIP_CLK_EN0.I2S1_CLK_EN := True;
            SYSTEM_Periph.PERIP_RST_EN0.I2S1_RST    := True;
            SYSTEM_Periph.PERIP_RST_EN0.I2S1_RST    := False;
      end case;

      --  Clock module: source = CLK160 (sel 2), integer divide by N, gate on.
      R.TX_CLKM_DIV_CONF := (TX_CLKM_DIV_X => 0, TX_CLKM_DIV_Y => 0,
                             TX_CLKM_DIV_Z => 0, TX_CLKM_DIV_YN1 => False,
                             others => <>);
      R.RX_CLKM_DIV_CONF := (RX_CLKM_DIV_X => 0, RX_CLKM_DIV_Y => 0,
                             RX_CLKM_DIV_Z => 0, RX_CLKM_DIV_YN1 => False,
                             others => <>);
      R.TX_CLKM_CONF := (TX_CLKM_DIV_NUM => TX_CLKM_CONF_TX_CLKM_DIV_NUM_Field (N),
                         TX_CLK_SEL => 2, TX_CLK_ACTIVE => True, CLK_EN => True,
                         others => <>);
      R.RX_CLKM_CONF := (RX_CLKM_DIV_NUM => RX_CLKM_CONF_RX_CLKM_DIV_NUM_Field (N),
                         RX_CLK_SEL => 2, RX_CLK_ACTIVE => True,
                         others => <>);

      --  Slot format: stereo TDM, BCK divider M, Philips (1-bit MSB shift).
      R.TX_CONF1 :=
        (TX_BCK_DIV_NUM      => TX_CONF1_TX_BCK_DIV_NUM_Field (M - 1),
         TX_BITS_MOD         => TX_CONF1_TX_BITS_MOD_Field (DB - 1),
         TX_TDM_CHAN_BITS    => TX_CONF1_TX_TDM_CHAN_BITS_Field (DB - 1),
         TX_TDM_WS_WIDTH     => TX_CONF1_TX_TDM_WS_WIDTH_Field (DB - 1),
         TX_HALF_SAMPLE_BITS => TX_CONF1_TX_HALF_SAMPLE_BITS_Field (DB - 1),
         TX_MSB_SHIFT        => True, TX_BCK_NO_DLY => False, others => <>);
      R.RX_CONF1 :=
        (RX_BCK_DIV_NUM      => RX_CONF1_RX_BCK_DIV_NUM_Field (M - 1),
         RX_BITS_MOD         => RX_CONF1_RX_BITS_MOD_Field (DB - 1),
         RX_TDM_CHAN_BITS    => RX_CONF1_RX_TDM_CHAN_BITS_Field (DB - 1),
         RX_TDM_WS_WIDTH     => RX_CONF1_RX_TDM_WS_WIDTH_Field (DB - 1),
         RX_HALF_SAMPLE_BITS => RX_CONF1_RX_HALF_SAMPLE_BITS_Field (DB - 1),
         RX_MSB_SHIFT        => True, others => <>);

      --  Two TDM slots, both active.
      R.TX_TDM_CTRL := (TX_TDM_TOT_CHAN_NUM => 1,
                        TX_TDM_CHAN0_EN => True, TX_TDM_CHAN1_EN => True,
                        others => <>);
      R.RX_TDM_CTRL := (RX_TDM_TOT_CHAN_NUM => 1,
                        RX_TDM_PDM_CHAN0_EN => True, RX_TDM_PDM_CHAN1_EN => True,
                        others => <>);

      --  TX = master, RX = slave.  SIG_LOOPBACK makes TX and RX share WS+BCK
      --  internally (full-duplex master / self-test).
      if Is_PDM then
         --  PCM -> PDM up-converter on TX (sigma-delta); the record defaults
         --  (OSR2 = 2, dither on, unity shifts) are the usual settings, and
         --  TX_PCM2PDM_CONF1's reset fp/fs = 960/480 give the 2x up-sample.
         R.TX_PCM2PDM_CONF := (PCM2PDM_CONV_EN => True, others => <>);
         --  PDM is used with real external devices, so NO SIG_LOOPBACK -- the
         --  receiver must read the actual data pad, not the TX side internally.
         --  In PDM the RECEIVER owns the clock (it clocks the mic), so RX masters
         --  and TX follows -- the reverse of the TDM roles, where TX masters.
         R.TX_CONF := (TX_PDM_EN => True, TX_TDM_EN => False,
                       TX_SLAVE_MOD => True, TX_MONO => False, TX_STOP_EN => True,
                       TX_PCM_BYPASS => True, SIG_LOOPBACK => False, others => <>);
         --  PDM -> PCM down-converter on RX; DSR_16_EN selects the 128 (2x)
         --  decimation that matches the TX up-sample.
         R.RX_CONF := (RX_PDM_EN => True, RX_PDM2PCM_EN => True,
                       RX_PDM_SINC_DSR_16_EN => True, RX_TDM_EN => False,
                       RX_SLAVE_MOD => False, RX_MONO => False,
                       RX_PCM_BYPASS => True, others => <>);
      else
         --  Both TDM (standard I2S), no PDM.
         R.TX_CONF := (TX_TDM_EN => True, TX_PDM_EN => False,
                       TX_SLAVE_MOD => False, TX_MONO => False, TX_STOP_EN => True,
                       TX_PCM_BYPASS => True, SIG_LOOPBACK => True, others => <>);
         R.RX_CONF := (RX_TDM_EN => True, RX_PDM_EN => False, RX_SLAVE_MOD => True,
                       RX_MONO => False, RX_PCM_BYPASS => True, others => <>);
      end if;

      --  Claim the DMA channel bound to this port (OUT=TX, IN=RX).
      GD.Claim (B.Chan, GDMA_Periph (Port));

      --  Reset both data paths, then latch the config.
      R.TX_CONF.TX_RESET := True;  R.TX_CONF.TX_RESET := False;
      R.TX_CONF.TX_FIFO_RESET := True;  R.TX_CONF.TX_FIFO_RESET := False;
      R.RX_CONF.RX_RESET := True;  R.RX_CONF.RX_RESET := False;
      R.RX_CONF.RX_FIFO_RESET := True;  R.RX_CONF.RX_FIFO_RESET := False;
      R.TX_CONF.TX_UPDATE := True;  while R.TX_CONF.TX_UPDATE loop null; end loop;
      R.RX_CONF.RX_UPDATE := True;  while R.RX_CONF.RX_UPDATE loop null; end loop;

      B.Regs  := R;
      B.Port  := Port;
      B.Valid := GD.Is_Valid (B.Chan);
   end Open;

   function Is_Open (B : Bus) return Boolean is (B.Valid);

   --------------------
   -- Configure_Pins --
   --------------------

   procedure Configure_Pins (B : Bus;
                             Bclk : ESP32S3.GPIO.Optional_Pin;
                             Ws   : ESP32S3.GPIO.Optional_Pin;
                             Dout : ESP32S3.GPIO.Optional_Pin := No_Pin;
                             Din  : ESP32S3.GPIO.Optional_Pin := No_Pin;
                             Mclk : ESP32S3.GPIO.Optional_Pin := No_Pin)
   is
      use type ESP32S3.GPIO.Pad_Number;
      S : constant Sig := Signals (B.Port);
   begin
      if not B.Valid then
         return;
      end if;
      if Mclk /= No_Pin and then S.Mck_Out /= 0 then
         Drive_Out (ESP32S3.GPIO.Pin_Id (Mclk), S.Mck_Out);   --  master clock out
      end if;
      if Bclk /= No_Pin then
         Drive_Out (ESP32S3.GPIO.Pin_Id (Bclk), S.Bck_Out);
      end if;
      if Ws /= No_Pin then
         Drive_Out (ESP32S3.GPIO.Pin_Id (Ws), S.Ws_Out);
      end if;
      if Dout /= No_Pin then
         Drive_Out (ESP32S3.GPIO.Pin_Id (Dout), S.Sd_Out);
      end if;
      if Din /= No_Pin then
         Route_In (S.Sd_In, ESP32S3.GPIO.Pin_Id (Din), As_Input => True);
      end if;
   end Configure_Pins;

   ---------------------
   -- Enable_Loopback --
   ---------------------

   procedure Enable_Loopback (B : Bus; Pad : ESP32S3.GPIO.Pin_Id) is
      S : constant Sig := Signals (B.Port);
   begin
      if not B.Valid then
         return;
      end if;
      --  Data-out on Pad, fed back into data-in (SIG_LOOPBACK already shares the
      --  clock/WS internally, so no clock pad is needed).
      Drive_Out (Pad, S.Sd_Out);
      Route_In (S.Sd_In, Pad, As_Input => False);
   end Enable_Loopback;

   ---------
   -- Run --
   ---------

   --  Shared TX/RX engine.  Arms whichever directions are requested, kicks the
   --  module, and blocks on the DMA EOF (RX if reading, else TX).
   procedure Run (B : Bus; Tx, Rx : System.Address; Length : Natural;
                  Do_Tx, Do_Rx : Boolean)
   is
      R : constant Periph_Ref := B.Regs;
   begin
      if not B.Valid or else Length = 0 or else Length > 4095 then
         return;
      end if;

      if Do_Tx then
         R.TX_CONF.TX_FIFO_RESET := True;  R.TX_CONF.TX_FIFO_RESET := False;
         GD.Start (B.Chan, GD.Mem_To_Periph, Tx, Length);
      end if;
      if Do_Rx then
         R.RX_CONF.RX_FIFO_RESET := True;  R.RX_CONF.RX_FIFO_RESET := False;
         R.RXEOF_NUM.RX_EOF_NUM := RXEOF_NUM_RX_EOF_NUM_Field (Length);
         GD.Start (B.Chan, GD.Periph_To_Mem, Rx, Length);
      end if;

      R.TX_CONF.TX_UPDATE := True;  while R.TX_CONF.TX_UPDATE loop null; end loop;
      R.RX_CONF.RX_UPDATE := True;  while R.RX_CONF.RX_UPDATE loop null; end loop;

      if Do_Rx then
         R.RX_CONF.RX_START := True;
      end if;
      if Do_Tx then
         R.TX_CONF.TX_START := True;
      end if;

      if Do_Rx then
         GD.Wait (B.Chan, GD.Periph_To_Mem);
      else
         GD.Wait (B.Chan, GD.Mem_To_Periph);
      end if;

      R.TX_CONF.TX_START := False;
      R.RX_CONF.RX_START := False;
   end Run;

   procedure Write (B : Bus; Tx : System.Address; Length : Natural) is
   begin
      Run (B, Tx, System.Null_Address, Length, Do_Tx => True, Do_Rx => False);
   end Write;

   procedure Read (B : Bus; Rx : System.Address; Length : Natural) is
   begin
      Run (B, System.Null_Address, Rx, Length, Do_Tx => False, Do_Rx => True);
   end Read;

   procedure Transfer (B : Bus; Tx, Rx : System.Address; Length : Natural) is
   begin
      Run (B, Tx, Rx, Length, Do_Tx => True, Do_Rx => True);
   end Transfer;

   ----------------------
   -- Start_Continuous --
   ----------------------

   procedure Start_Continuous (B : Bus; Tx : System.Address; Length : Natural) is
      R : constant Periph_Ref := B.Regs;
   begin
      if not B.Valid or else Length = 0 or else Length > 4095 then
         return;
      end if;

      --  Clear TX_STOP_EN so a momentary FIFO underrun can never latch TX off;
      --  with the self-looping DMA the FIFO stays fed, so the clock runs
      --  continuously and the waveform repeats with no gap.
      R.TX_CONF.TX_STOP_EN := False;
      R.TX_CONF.TX_FIFO_RESET := True;  R.TX_CONF.TX_FIFO_RESET := False;
      GD.Start_Loop (B.Chan, Tx, Length);
      R.TX_CONF.TX_UPDATE := True;  while R.TX_CONF.TX_UPDATE loop null; end loop;
      R.TX_CONF.TX_START := True;
   end Start_Continuous;

   ----------
   -- Stop --
   ----------

   procedure Stop (B : Bus) is
   begin
      if B.Valid then
         B.Regs.TX_CONF.TX_START := False;
      end if;
   end Stop;

   -------------
   -- Capture --
   -------------

   --  RX-only blocking transfer.  Deliberately touches ONLY the RX path (no
   --  TX_UPDATE / TX_START), so a continuous transmit driving the shared master
   --  clock keeps running while we sample the data-in line.
   procedure Capture (B : Bus; Rx : System.Address; Length : Natural) is
      R : constant Periph_Ref := B.Regs;
   begin
      if not B.Valid or else Length = 0 or else Length > 4095 then
         return;
      end if;

      R.RX_CONF.RX_FIFO_RESET := True;  R.RX_CONF.RX_FIFO_RESET := False;
      R.RXEOF_NUM.RX_EOF_NUM := RXEOF_NUM_RX_EOF_NUM_Field (Length);
      GD.Start (B.Chan, GD.Periph_To_Mem, Rx, Length);
      --  Latch RX config.  Bounded: while a continuous TX is driving the shared
      --  clock, RX_UPDATE does not always self-clear, so never spin on it.
      R.RX_CONF.RX_UPDATE := True;
      declare
         Guard : Natural := 0;
      begin
         while R.RX_CONF.RX_UPDATE and then Guard < 100_000 loop
            Guard := Guard + 1;
         end loop;
      end;
      R.RX_CONF.RX_START := True;
      --  Wait for the RX success-EOF.  A capture is clock-paced: Length bytes
      --  take Length/(rate*frame_bytes) seconds (tens of ms), far longer than
      --  GD.Wait's short guard -- which would return early on a half-filled
      --  buffer.  Spin on Done with a generous bound so the buffer is complete.
      declare
         Guard : Natural := 0;
      begin
         while not GD.Done (B.Chan, GD.Periph_To_Mem)
           and then Guard < 50_000_000
         loop
            Guard := Guard + 1;
         end loop;
      end;
      R.RX_CONF.RX_START := False;
   end Capture;

   -----------
   -- Close --
   -----------

   procedure Close (B : in out Bus) is
   begin
      if B.Valid then
         B.Regs.TX_CONF.TX_START := False;
         B.Regs.RX_CONF.RX_START := False;
         GD.Release (B.Chan);
         B.Valid := False;
      end if;
   end Close;

end ESP32S3.I2S.Engine;
