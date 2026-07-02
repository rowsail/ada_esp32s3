with ESP32S3.GPIO;
with ESP32S3.GPIO_Signals;
with ESP32S3_Registers;      use ESP32S3_Registers;
with ESP32S3_Registers.SPI2; use ESP32S3_Registers.SPI2;
with ESP32S3_Registers.GPIO;
with ESP32S3_Registers.SYSTEM;

package body ESP32S3.SPI.Engine is

   package Sigs renames ESP32S3.GPIO_Signals;
   package GD renames ESP32S3.GDMA;            --  the DMA engine we consume
   package GR renames ESP32S3_Registers.GPIO;  --  GPIO matrix register layer

   Src_Hz : constant := 80_000_000;            --  SPI master clock source

   --  GPIO-matrix signal indices, per host (gpio_sig_map.h).
   type Sig is record
      Clk, Mosi_Out, Miso_In, Cs : Natural;
   end record;

   function Signals (Host : SPI_Host) return Sig
   is (case Host is
         when SPI2 =>
           (Clk      => Sigs.FSPICLK_OUT,
            Mosi_Out => Sigs.FSPID_OUT,
            Miso_In  => Sigs.FSPIQ_IN,
            Cs       => Sigs.FSPICS0_OUT),
         when SPI3 =>
           (Clk      => Sigs.SPI3_CLK_OUT,
            Mosi_Out => Sigs.SPI3_D_OUT,
            Miso_In  => Sigs.SPI3_Q_IN,
            Cs       => Sigs.SPI3_CS0_OUT));

   function GDMA_Periph (Host : SPI_Host) return GD.Peripheral
   is (case Host is
         when SPI2 => GD.SPI2,
         when SPI3 => GD.SPI3);

   procedure Drive_Out (Pad : ESP32S3.GPIO.Pin_Id; Signal : Natural) is
      Pad_Index : constant Natural := Natural (Pad);
      Out_Cfg   : GR.FUNC_OUT_SEL_CFG_Register :=   --  the pad's output-select config
        GR.GPIO_Periph.FUNC_OUT_SEL_CFG (Pad_Index);
   begin
      ESP32S3.GPIO.Configure
        (Pad, Mode => ESP32S3.GPIO.Output, Drive => ESP32S3.GPIO.Drive_Strong);
      Out_Cfg.OUT_SEL := GR.FUNC_OUT_SEL_CFG_OUT_SEL_Field (Signal);
      GR.GPIO_Periph.FUNC_OUT_SEL_CFG (Pad_Index) := Out_Cfg;
   end Drive_Out;

   procedure Route_In (Signal : Natural; Pad : ESP32S3.GPIO.Pin_Id; As_Input : Boolean) is
   begin
      if As_Input then
         ESP32S3.GPIO.Configure (Pad, Mode => ESP32S3.GPIO.Input);
      end if;
      GR.GPIO_Periph.FUNC_IN_SEL_CFG (Signal) :=
        (IN_SEL => GR.FUNC_IN_SEL_CFG_IN_SEL_Field (Natural (Pad)),
         SEL    => True,
         --  use the matrix
         others => <>);
   end Route_In;

   procedure Set_Clock (Regs : Periph_Ref; Hz : Positive) is
   begin
      if Hz >= Src_Hz then
         Regs.CLOCK := (CLK_EQU_SYSCLK => True, others => <>);
         return;
      end if;

      --  Split the total divider into Prescaler x (Count+1), then set the toggle
      --  midpoint Half for a ~50% duty.  These map to the CLOCK register fields
      --  CLKDIV_PRE / CLKCNT_N / CLKCNT_H / CLKCNT_L.
      declare
         Total     : constant Natural := Natural'Max (2, Src_Hz / Hz);  --  total divider
         Prescaler : Natural := 0;   --  CLKDIV_PRE (front divider, 0..15)
         Count     : Natural;        --  CLKCNT_N/L: clock half-period count
         Half      : Natural;        --  CLKCNT_H: high-phase midpoint
      begin
         while Total / (Prescaler + 1) > 64 and then Prescaler < 15 loop
            Prescaler := Prescaler + 1;
         end loop;
         Count := Natural'Min (63, Natural'Max (1, Total / (Prescaler + 1) - 1));
         Half := (Count + 1) / 2;
         if Half > 0 then
            Half := Half - 1;
         end if;
         Regs.CLOCK :=
           (CLK_EQU_SYSCLK => False,
            CLKDIV_PRE     => CLOCK_CLKDIV_PRE_Field (Prescaler),
            CLKCNT_N       => CLOCK_CLKCNT_N_Field (Count),
            CLKCNT_H       => CLOCK_CLKCNT_H_Field (Half),
            CLKCNT_L       => CLOCK_CLKCNT_L_Field (Count),
            others         => <>);
      end;
   end Set_Clock;

   ----------
   -- Open --
   ----------

   procedure Open (B : in out Bus; Host : SPI_Host; Mode : SPI_Mode; Clock_Hz : Positive) is
      use ESP32S3_Registers.SYSTEM;
      Regs      : constant Periph_Ref :=
        (case Host is
           when SPI2 => SPI2_Periph'Access,
           when SPI3 => SPI3_Periph'Access);
      Out_Edge  : constant Boolean := (Mode = 1 or else Mode = 2);  --  CPHA map
      Idle_Edge : constant Boolean := (Mode >= 2);                  --  CPOL
   begin
      case Host is
         when SPI2 =>
            SYSTEM_Periph.PERIP_CLK_EN0.SPI2_CLK_EN := True;
            SYSTEM_Periph.PERIP_CLK_EN0.SPI2_DMA_CLK_EN := True;
            SYSTEM_Periph.PERIP_RST_EN0.SPI2_RST := False;
            SYSTEM_Periph.PERIP_RST_EN0.SPI2_DMA_RST := False;

         when SPI3 =>
            SYSTEM_Periph.PERIP_CLK_EN0.SPI3_CLK_EN := True;
            SYSTEM_Periph.PERIP_CLK_EN0.SPI3_DMA_CLK_EN := True;
            SYSTEM_Periph.PERIP_RST_EN0.SPI3_RST := False;
            SYSTEM_Periph.PERIP_RST_EN0.SPI3_DMA_RST := False;
      end case;

      Regs.CLK_GATE := (CLK_EN => True, MST_CLK_ACTIVE => True, MST_CLK_SEL => True, others => <>);
      Set_Clock (Regs, Clock_Hz);

      Regs.SLAVE.MODE := False;
      Regs.USER :=
        (DOUTDIN     => True,
         USR_MOSI    => True,
         USR_MISO    => True,
         CK_OUT_EDGE => Out_Edge,
         USR_COMMAND => False,
         others      => <>);
      Regs.MISC.CK_IDLE_EDGE := Idle_Edge;

      Regs.DMA_CONF.DMA_TX_ENA := True;
      Regs.DMA_CONF.DMA_RX_ENA := True;

      GD.Claim (B.Chan, GDMA_Periph (Host));   --  claim into the Bus in place

      Regs.CMD.UPDATE := True;
      while Regs.CMD.UPDATE loop
         null;
      end loop;

      B.Regs := Regs;
      B.Host := Host;
      B.Valid := GD.Is_Valid (B.Chan);
   end Open;

   function Is_Open (B : Bus) return Boolean
   is (B.Valid);

   procedure Set_Clock (B : Bus; Hz : Positive) is
   begin
      if B.Regs /= null then
         Set_Clock (B.Regs, Hz);              --  recompute the divider
         B.Regs.CMD.UPDATE := True;           --  latch into the shifter
         while B.Regs.CMD.UPDATE loop
            null;
         end loop;
      end if;
   end Set_Clock;

   procedure Set_Mode (B : Bus; Mode : SPI_Mode) is
      Out_Edge  : constant Boolean := (Mode = 1 or else Mode = 2);  --  CPHA map
      Idle_Edge : constant Boolean := (Mode >= 2);                  --  CPOL
   begin
      if B.Regs /= null then
         B.Regs.USER.CK_OUT_EDGE := Out_Edge;
         B.Regs.MISC.CK_IDLE_EDGE := Idle_Edge;
         B.Regs.CMD.UPDATE := True;           --  latch into the shifter
         while B.Regs.CMD.UPDATE loop
            null;
         end loop;
      end if;
   end Set_Mode;

   procedure Configure_Pins
     (B    : Bus;
      Sclk : ESP32S3.GPIO.Optional_Pin;
      Mosi : ESP32S3.GPIO.Optional_Pin;
      Miso : ESP32S3.GPIO.Optional_Pin;
      Cs   : ESP32S3.GPIO.Optional_Pin := No_Pin)
   is
      use type ESP32S3.GPIO.Pad_Number;
      Host_Sigs : constant Sig := Signals (B.Host);   --  GPIO-matrix signal ids for this host
   begin
      if not B.Valid then
         return;
      end if;
      --  Each Optional_Pin that is a real pin converts to Pin_Id here (the
      --  /= No_Pin guard guarantees the predicate holds).
      if Sclk /= No_Pin then
         Drive_Out (ESP32S3.GPIO.Pin_Id (Sclk), Host_Sigs.Clk);
      end if;
      if Mosi /= No_Pin then
         Drive_Out (ESP32S3.GPIO.Pin_Id (Mosi), Host_Sigs.Mosi_Out);
      end if;
      if Miso /= No_Pin then
         Route_In (Host_Sigs.Miso_In, ESP32S3.GPIO.Pin_Id (Miso), As_Input => True);
      end if;
      if Cs /= No_Pin then
         Drive_Out (ESP32S3.GPIO.Pin_Id (Cs), Host_Sigs.Cs);
      end if;
   end Configure_Pins;

   procedure Enable_Loopback (B : Bus; Pad : ESP32S3.GPIO.Pin_Id) is
      Host_Sigs : constant Sig := Signals (B.Host);   --  GPIO-matrix signal ids for this host
   begin
      if not B.Valid then
         return;
      end if;
      Drive_Out (Pad, Host_Sigs.Mosi_Out);
      Route_In (Host_Sigs.Miso_In, Pad, As_Input => False);
   end Enable_Loopback;

   procedure Set_Hardware_CS (B : Bus; Enabled : Boolean) is
   begin
      if B.Regs /= null then
         B.Regs.MISC.CS0_DIS := not Enabled;   --  CS0_DIS = 1 suppresses CS0
         B.Regs.CMD.UPDATE := True;            --  latch into the shifter
         declare
            Guard : Natural := 100_000;        --  config latch: completes in cycles
         begin
            while B.Regs.CMD.UPDATE and then Guard > 0 loop
               Guard := Guard - 1;
            end loop;
         end;
      end if;
   end Set_Hardware_CS;

   procedure Transfer (B : Bus; Tx, Rx : System.Address; Length : Natural) is
   begin
      if not B.Valid or else Length = 0 or else Length > 4095 then
         return;
      end if;

      B.Regs.DMA_CONF.DMA_AFIFO_RST := True;
      B.Regs.DMA_CONF.DMA_AFIFO_RST := False;
      B.Regs.DMA_CONF.RX_AFIFO_RST := True;
      B.Regs.DMA_CONF.RX_AFIFO_RST := False;

      GD.Start (B.Chan, GD.Mem_To_Periph, Tx, Length);
      GD.Start (B.Chan, GD.Periph_To_Mem, Rx, Length);

      B.Regs.MS_DLEN.MS_DATA_BITLEN := MS_DLEN_MS_DATA_BITLEN_Field (Length * 8 - 1);
      B.Regs.CMD.UPDATE := True;
      declare
         Guard : Natural := 100_000;          --  config latch: completes in cycles
      begin
         while B.Regs.CMD.UPDATE and then Guard > 0 loop
            Guard := Guard - 1;
         end loop;
      end;
      B.Regs.CMD.USR := True;

      --  Bound the transfer-complete spin so a misconfigured controller (no SCLK,
      --  stuck FSM) cannot wedge the caller forever, mirroring I2C Run_Sequence.
      --  On a stall, bail before GD.Wait -- whose EOF interrupt would also never
      --  arrive -- rather than block.
      declare
         Guard : Natural := 2_000_000;
      begin
         while B.Regs.CMD.USR and then Guard > 0 loop
            Guard := Guard - 1;
         end loop;
         if Guard = 0 then
            return;
         end if;
      end;
      GD.Wait (B.Chan, GD.Periph_To_Mem);
   end Transfer;

   procedure Close (B : in out Bus) is
   begin
      if B.Valid then
         GD.Release (B.Chan);
         B.Valid := False;
      end if;
   end Close;

end ESP32S3.SPI.Engine;
