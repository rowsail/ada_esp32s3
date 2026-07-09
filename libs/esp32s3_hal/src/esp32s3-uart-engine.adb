with ESP32S3_Registers;      use ESP32S3_Registers;
with ESP32S3_Registers.UART; use ESP32S3_Registers.UART;
with ESP32S3_Registers.GPIO;
with ESP32S3_Registers.IO_MUX;
with ESP32S3_Registers.SYSTEM;
with ESP32S3.GPIO_Signals;

package body ESP32S3.UART.Engine is

   package Sigs renames ESP32S3.GPIO_Signals;
   package GR renames ESP32S3_Registers.GPIO;    --  GPIO matrix register layer
   package MX renames ESP32S3_Registers.IO_MUX;  --  IO_MUX (per-pad config)
   package G renames ESP32S3.GPIO;              --  valid-pad subtype

   Src_Hz   : constant := 40_000_000;            --  XTAL clock (CLK_CONF SCLK_SEL=3)
   Fifo_Len : constant := 128;                   --  default per-port FIFO depth

   --  GPIO-matrix signal index per port (gpio_sig_map.h): TXD-out and RXD-in
   --  share one index per UART; RTS-out and CTS-in share another.
   function Signal (Port : UART_Port) return Natural
   is (case Port is
         when UART0 => Sigs.U0TXD_OUT,
         when UART1 => Sigs.U1TXD_OUT,
         when UART2 => Sigs.U2TXD_OUT);

   function Flow_Signal (Port : UART_Port) return Natural
   is (case Port is
         when UART0 => Sigs.U0RTS_OUT,
         when UART1 => Sigs.U1RTS_OUT,
         when UART2 => Sigs.U2RTS_OUT);

   function Regs_Of (Port : UART_Port) return Periph_Ref
   is (case Port is
         when UART0 => UART0_Periph'Access,
         when UART1 => UART1_Periph'Access,
         when UART2 => UART2_Periph'Access);

   --  Clock-gate + de-reset the controller (pulse reset to clear stuck state).
   procedure Enable_Clock (Port : UART_Port) is
      use ESP32S3_Registers.SYSTEM;
   begin
      SYSTEM_Periph.PERIP_CLK_EN0.UART_MEM_CLK_EN := True;   --  shared FIFO RAM
      case Port is
         when UART0 =>
            SYSTEM_Periph.PERIP_CLK_EN0.UART_CLK_EN := True;
            SYSTEM_Periph.PERIP_RST_EN0.UART_RST := True;
            SYSTEM_Periph.PERIP_RST_EN0.UART_RST := False;

         when UART1 =>
            SYSTEM_Periph.PERIP_CLK_EN0.UART1_CLK_EN := True;
            SYSTEM_Periph.PERIP_RST_EN0.UART1_RST := True;
            SYSTEM_Periph.PERIP_RST_EN0.UART1_RST := False;

         when UART2 =>
            SYSTEM_Periph.PERIP_CLK_EN1.UART2_CLK_EN := True;
            SYSTEM_Periph.PERIP_RST_EN1.UART2_RST := True;
            SYSTEM_Periph.PERIP_RST_EN1.UART2_RST := False;
      end case;
   end Enable_Clock;

   --  Program the baud divider (mirrors esp-idf uart_ll_set_baudrate): pick a
   --  core-clock pre-divider so the 12-bit CLKDIV integer fits, then split the
   --  remaining 1/16-resolution divisor into CLKDIV.integer + CLKDIV.frag.
   procedure Program_Baud (Regs : Periph_Ref; Baud : Baud_Rate) is
      Max_Div  : constant := 4095;                       --  CLKDIV is 12 bits
      --  64-bit intermediates: Max_Div * Baud overflows 32-bit Integer for any
      --  Baud above ~524 kBd, and Baud_Rate ranges to 5 MBd (921600/1M/2M/5M all
      --  fell in the overflow band before).
      B64      : constant Long_Long_Integer := Long_Long_Integer (Baud);
      S64      : constant Long_Long_Integer := Long_Long_Integer (Src_Hz);
      Sclk_Div : constant Natural :=
        Natural (Long_Long_Integer'Max
          (1, (S64 + (Max_Div * B64) - 1) / (Max_Div * B64)));
      Clk_Div  : constant Natural :=
        Natural ((S64 * 16) / (B64 * Long_Long_Integer (Sclk_Div)));
   begin
      Regs.CLK_CONF :=
        (SCLK_SEL     => 3,
         --  XTAL
         SCLK_DIV_NUM => CLK_CONF_SCLK_DIV_NUM_Field (Sclk_Div - 1),
         SCLK_DIV_A   => 0,
         SCLK_DIV_B   => 0,
         SCLK_EN      => True,
         TX_SCLK_EN   => True,
         RX_SCLK_EN   => True,
         others       => <>);
      Regs.CLKDIV :=
        (CLKDIV => CLKDIV_CLKDIV_Field (Clk_Div / 16),
         FRAG   => CLKDIV_FRAG_Field (Clk_Div mod 16),
         others => <>);
   end Program_Baud;

   ----------
   -- Open --
   ----------

   function Open
     (Port : UART_Port; Baud : Baud_Rate; Bits : Data_Bits; Parity : Parity_Mode; Stop : Stop_Bits)
      return Bus
   is
      Regs : constant Periph_Ref := Regs_Of (Port);
   begin
      Enable_Clock (Port);
      Program_Baud (Regs, Baud);

      Regs.CONF0 :=
        (BIT_NUM      => CONF0_BIT_NUM_Field (Natural (Bits) - 5),
         STOP_BIT_NUM =>
           (case Stop is
              when One => 1,
              when Two => 3),
         PARITY_EN    => Parity /= None,
         PARITY       => Parity = Odd,
         --  PARITY: 1 = odd, 0 = even
         RXFIFO_RST   => True,
         TXFIFO_RST   => True,
         others       => <>);                  --  MEM_CLK_EN default True
      Regs.CONF0.RXFIFO_RST := False;
      Regs.CONF0.TXFIFO_RST := False;

      --  HIGH_SPEED (ID register, default True) auto-syncs config into the UART
      --  core clock domain, so no explicit REG_UPDATE is needed.
      return (Regs => Regs, Port => Port, Valid => True);
   end Open;

   function Is_Open (B : Bus) return Boolean
   is (B.Valid);

   --------------------------------
   -- Independent frame attributes --
   --------------------------------

   procedure Set_Baud (B : Bus; Baud : Baud_Rate) is
   begin
      if B.Valid then
         Program_Baud (B.Regs, Baud);
      end if;
   end Set_Baud;

   procedure Set_Data_Bits (B : Bus; Bits : Data_Bits) is
   begin
      if B.Valid then
         B.Regs.CONF0.BIT_NUM := CONF0_BIT_NUM_Field (Natural (Bits) - 5);
      end if;
   end Set_Data_Bits;

   procedure Set_Parity (B : Bus; Parity : Parity_Mode) is
   begin
      if not B.Valid then
         return;
      end if;
      declare
         Conf0 : CONF0_Register := B.Regs.CONF0;
      begin
         Conf0.PARITY_EN := Parity /= None;
         Conf0.PARITY := Parity = Odd;          --  PARITY: 1 = odd, 0 = even
         B.Regs.CONF0 := Conf0;
      end;
   end Set_Parity;

   procedure Set_Stop_Bits (B : Bus; Stop : Stop_Bits) is
   begin
      if B.Valid then
         B.Regs.CONF0.STOP_BIT_NUM :=
           (case Stop is
              when One => 1,
              when Two => 3);
      end if;
   end Set_Stop_Bits;

   --------------------
   -- Configure_Pins --
   --------------------

   --  Drive Pad as a push-pull output sourced from the matrix signal Sig.
   procedure Drive_Out (Pad : G.Pin_Id; Sig : Natural) is
      Pad_Index : constant Natural := Natural (Pad);
      Out_Cfg   : GR.FUNC_OUT_SEL_CFG_Register := GR.GPIO_Periph.FUNC_OUT_SEL_CFG (Pad_Index);
   begin
      G.Configure (Pad, Mode => G.Output, Drive => G.Drive_Strong);
      Out_Cfg.OUT_SEL := GR.FUNC_OUT_SEL_CFG_OUT_SEL_Field (Sig);
      Out_Cfg.OEN_SEL := False;                       --  peripheral output-enable
      GR.GPIO_Periph.FUNC_OUT_SEL_CFG (Pad_Index) := Out_Cfg;
   end Drive_Out;

   --  Route Pad (input buffer on, pulled up) into the matrix input signal Sig.
   --  Pokes IO_MUX directly and leaves the OUTPUT driver untouched -- so a pad
   --  that is ALSO an output (a single-pad self-loopback of TXD->RXD or
   --  RTS->CTS) keeps driving while it is read back.  A pure input pad has its
   --  driver off by default, so this is input-only there.
   procedure Route_In (Sig : Natural; Pad : G.Pin_Id) is
      Pad_Index : constant Natural := Natural (Pad);
      Pad_Cfg   : MX.GPIO_Register := MX.IO_MUX_Periph.GPIO (Pad_Index);
   begin
      Pad_Cfg.MCU_SEL := 1;                           --  route through the GPIO matrix
      Pad_Cfg.FUN_IE := True;                        --  input buffer on
      Pad_Cfg.FUN_WPU := True;                        --  pull-up (idle/disconnect high)
      MX.IO_MUX_Periph.GPIO (Pad_Index) := Pad_Cfg;
      GR.GPIO_Periph.FUNC_IN_SEL_CFG (Sig) :=
        (IN_SEL => GR.FUNC_IN_SEL_CFG_IN_SEL_Field (Pad_Index),
         SEL    => True,
         --  use the matrix
         others => <>);
   end Route_In;

   --  Which pad each port's OUTPUT signals currently drive.  OUT_SEL is per PAD,
   --  not per signal, so pointing a second pad at TXD does not move TXD: it fans
   --  it out to both, and the old pad keeps transmitting forever.  (Inputs need no
   --  such table: FUNC_IN_SEL_CFG is per SIGNAL, so re-routing RX really moves it.)
   --  Startup/reconfigure only, single-threaded -- same contract as Configure_Pins.
   Driven_Tx  : array (UART_Port) of ESP32S3.GPIO.Optional_Pin := (others => G.No_Pin);
   Driven_Rts : array (UART_Port) of ESP32S3.GPIO.Optional_Pin := (others => G.No_Pin);

   --  Hand a pad back: point it at the plain-GPIO output (index 256), disable its
   --  driver, and leave it pulled up -- an idle UART line, and high-impedance to
   --  whatever else is on the net.
   procedure Release_Pad (Pad : ESP32S3.GPIO.Optional_Pin) is
      use type ESP32S3.GPIO.Pad_Number;
   begin
      if Pad /= G.No_Pin then
         G.Configure (G.Pin_Id (Pad), Mode => G.Input, Pull => G.Pull_Up);
      end if;
   end Release_Pad;

   procedure Configure_Pins
     (B                 : Bus;
      Tx                : ESP32S3.GPIO.Optional_Pin;
      Rx                : ESP32S3.GPIO.Optional_Pin;
      Rts               : ESP32S3.GPIO.Optional_Pin;
      Cts               : ESP32S3.GPIO.Optional_Pin;
      Rx_Flow_Threshold : Natural)
   is
      use type ESP32S3.GPIO.Pad_Number;
      Data_Sig : constant Natural := Signal (B.Port);
      Flow_Sig : constant Natural := Flow_Signal (B.Port);
   begin
      if not B.Valid then
         return;
      end if;
      --  A named line MOVES: release the pad it used to drive, then claim the new
      --  one.  Release first, so Tx and Rx on the SAME pad (the single-pad
      --  self-loopback below) still works.  No_Pin means "leave this line alone",
      --  which is what Acquire's defaults rely on.
      if Tx /= G.No_Pin then
         if Driven_Tx (B.Port) /= Tx then
            Release_Pad (Driven_Tx (B.Port));
         end if;
         Drive_Out (G.Pin_Id (Tx), Data_Sig);
         Driven_Tx (B.Port) := Tx;
      end if;
      if Rx /= G.No_Pin then
         Route_In (Data_Sig, G.Pin_Id (Rx));
      end if;
      --  RTS (we drive it): deassert when the RX FIFO reaches the threshold,
      --  telling the peer to pause.  CTS (we read it): the transmitter only
      --  sends while the peer asserts CTS.  Configure_Pins sets the FULL flow
      --  state, so a reconfigure without these pins also turns flow control off.
      if Rts /= G.No_Pin then
         if Driven_Rts (B.Port) /= Rts then
            Release_Pad (Driven_Rts (B.Port));
         end if;
         Drive_Out (G.Pin_Id (Rts), Flow_Sig);
         Driven_Rts (B.Port) := Rts;
         B.Regs.MEM_CONF.RX_FLOW_THRHD :=
           MEM_CONF_RX_FLOW_THRHD_Field (Natural'Min (127, Natural'Max (1, Rx_Flow_Threshold)));
      end if;
      B.Regs.CONF1.RX_FLOW_EN := Rts /= G.No_Pin;

      if Cts /= G.No_Pin then
         Route_In (Flow_Sig, G.Pin_Id (Cts));
      end if;
      B.Regs.CONF0.TX_FLOW_EN := Cts /= G.No_Pin;
   end Configure_Pins;

   ------------------
   -- Set_Loopback --
   ------------------

   procedure Set_Loopback (B : Bus; On : Boolean) is
   begin
      if B.Valid then
         B.Regs.CONF0.LOOPBACK := On;
      end if;
   end Set_Loopback;

   -------------------
   -- Set_Inversion --
   -------------------

   --  Set the four CONF0 line-invert bits in one read-modify-write (each line
   --  inverts independently).  HIGH_SPEED auto-syncs the change into the UART
   --  core clock domain, so it takes effect immediately -- usable after
   --  Configure_Pins to flip a line's polarity at run time.
   procedure Set_Inversion (B : Bus; Tx, Rx, Rts, Cts : Boolean) is
   begin
      if not B.Valid then
         return;
      end if;
      declare
         Conf0 : CONF0_Register := B.Regs.CONF0;
      begin
         Conf0.TXD_INV := Tx;
         Conf0.RXD_INV := Rx;
         Conf0.RTS_INV := Rts;
         Conf0.CTS_INV := Cts;
         B.Regs.CONF0 := Conf0;
      end;
   end Set_Inversion;

   -----------
   -- Write --
   -----------

   procedure Write (B : Bus; Data : Byte_Array) is
   begin
      if not B.Valid then
         return;
      end if;
      for Data_Byte of Data loop
         --  Wait (bounded) for TX FIFO room.
         declare
            Guard : Natural := 5_000_000;
         begin
            while Natural (B.Regs.STATUS.TXFIFO_CNT) >= Fifo_Len and then Guard > 0 loop
               Guard := Guard - 1;
            end loop;
            --  Timed out with the FIFO still full (e.g. CTS held low): stop rather
            --  than push into a full FIFO, where the byte -- and every byte after
            --  it -- would be silently dropped by the hardware.
            exit when Guard = 0;
         end;
         B.Regs.FIFO := (RXFIFO_RD_BYTE => ESP32S3_Registers.Byte (Data_Byte), others => <>);
      end loop;
   end Write;

   ------------------
   -- Rx_Available --
   ------------------

   function Rx_Available (B : Bus) return Natural
   is (if B.Valid then Natural (B.Regs.STATUS.RXFIFO_CNT) else 0);

   ----------
   -- Read --
   ----------

   procedure Read (B : Bus; Data : out Byte_Array; Count : out Natural) is
   begin
      Count := 0;
      if not B.Valid then
         return;
      end if;
      for I in Data'Range loop
         --  Wait (bounded) for a byte; short-read on timeout.
         declare
            Guard : Natural := 5_000_000;
         begin
            while Natural (B.Regs.STATUS.RXFIFO_CNT) = 0 and then Guard > 0 loop
               Guard := Guard - 1;
            end loop;
            exit when Natural (B.Regs.STATUS.RXFIFO_CNT) = 0;
         end;
         Data (I) := Byte (B.Regs.FIFO.RXFIFO_RD_BYTE);
         Count := Count + 1;
      end loop;
   end Read;

   procedure Close (B : in out Bus) is
   begin
      B.Valid := False;
   end Close;

end ESP32S3.UART.Engine;
