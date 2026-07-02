with Interfaces;
with Ada.Unchecked_Conversion;
with ESP32S3.GPIO;
with ESP32S3.GPIO_Signals;
with ESP32S3_Registers;     use ESP32S3_Registers;
with ESP32S3_Registers.I2C; use ESP32S3_Registers.I2C;
with ESP32S3_Registers.GPIO;
with ESP32S3_Registers.IO_MUX;
with ESP32S3_Registers.SYSTEM;

package body ESP32S3.I2C.Engine is

   package Sigs renames ESP32S3.GPIO_Signals;
   package GR renames ESP32S3_Registers.GPIO;    --  GPIO matrix register layer
   package MX renames ESP32S3_Registers.IO_MUX;  --  IO_MUX (per-pad config)
   package G renames ESP32S3.GPIO;              --  Pin_Id (valid-pad subtype)

   Src_Hz : constant := 40_000_000;              --  XTAL clock feeding the I2C

   --  COMD op_codes for the ESP32-S3 command FSM (NOT the legacy ESP32 values
   --  in the SVD comment -- those are wrong for the S3).
   Op_RSTART : constant := 6;
   Op_WRITE  : constant := 1;
   Op_READ   : constant := 3;
   Op_STOP   : constant := 2;

   --  GPIO-matrix signal indices, per host (gpio_sig_map.h).  In and out share
   --  the same index for each line (the matrix is bidirectional per pad).
   type Sig is record
      Scl, Sda : Natural;
   end record;

   function Signals (Host : I2C_Host) return Sig
   is (case Host is
         when I2C0 =>
           (Scl => Sigs.I2CEXT0_SCL_OUT,
            Sda => Sigs.I2CEXT0_SDA_OUT),    --  I2CEXT0_SCL/SDA (gpio_sig_map)
         when I2C1 =>
           (Scl => Sigs.I2CEXT1_SCL_OUT, Sda => Sigs.I2CEXT1_SDA_OUT));   --  I2CEXT1_SCL/SDA

   --  A COMD command word as its documented bit fields, so the layout is named
   --  and compiler-placed instead of hand-shifted.  (The bit positions are
   --  verified bit-for-bit against the previous arithmetic in the host test
   --  test/repclause_host.)  Op_Field is 3 bits: RSTART/WRITE/READ/STOP all fit.
   type Op_Field is mod 2**3;
   type Cmd_Word is record
      Byte_Num  : Interfaces.Unsigned_8;   --  bytes to move for this step
      Ack_Check : Boolean;                 --  check the ACK bit (writes)
      Ack_Exp   : Boolean;                 --  expected ACK level
      Ack_Val   : Boolean;                 --  ACK value we drive (reads)
      Op        : Op_Field;                --  RSTART / WRITE / READ / STOP
   end record;
   for Cmd_Word use
     record
       Byte_Num at 0 range 0 .. 7;
       Ack_Check at 0 range 8 .. 8;
       Ack_Exp at 0 range 9 .. 9;
       Ack_Val at 0 range 10 .. 10;
       Op at 0 range 11 .. 13;
     end record;
   for Cmd_Word'Size use 14;
   function To_Field is new Ada.Unchecked_Conversion (Cmd_Word, COMD_COMMAND_Field);

   function Cmd
     (Op        : Natural;
      Bytes     : Natural := 0;
      Ack_Check : Boolean := False;
      Ack_Exp   : Boolean := False;
      Ack_Val   : Boolean := False) return COMD_COMMAND_Field
   is (To_Field
         ((Byte_Num  => Interfaces.Unsigned_8 (Bytes),
           Ack_Check => Ack_Check,
           Ack_Exp   => Ack_Exp,
           Ack_Val   => Ack_Val,
           Op        => Op_Field (Op))));

   function Regs_Of (Host : I2C_Host) return Periph_Ref
   is (case Host is
         when I2C0 => I2C0_Periph'Access,
         when I2C1 => I2C1_Periph'Access);

   --  Configure Pad as an open-drain output through the GPIO matrix, driven by
   --  the peripheral output signal Out_Sig: internal pull-up, input buffer on,
   --  pad in open-drain mode (controller only ever pulls low), output-enable
   --  taken from the peripheral.
   procedure Pad_Open_Drain (Pad : G.Pin_Id; Out_Sig : Natural) is
      Ix : constant Natural := Natural (Pad);
      P  : MX.GPIO_Register := MX.IO_MUX_Periph.GPIO (Ix);
      O  : GR.FUNC_OUT_SEL_CFG_Register := GR.GPIO_Periph.FUNC_OUT_SEL_CFG (Ix);
   begin
      P.MCU_SEL := 1;                       --  route through the GPIO matrix
      P.FUN_IE := True;                    --  input buffer on (read-back)
      P.FUN_WPU := True;                    --  internal pull-up (line idles high)
      P.FUN_WPD := False;
      P.FUN_DRV := 2;                       --  ~20 mA, fine for open-drain
      MX.IO_MUX_Periph.GPIO (Ix) := P;

      GR.GPIO_Periph.PIN (Ix).PAD_DRIVER := True;   --  open-drain

      O.OUT_SEL := GR.FUNC_OUT_SEL_CFG_OUT_SEL_Field (Out_Sig);
      O.OEN_SEL := False;                   --  use the peripheral's output-enable
      GR.GPIO_Periph.FUNC_OUT_SEL_CFG (Ix) := O;

      if Ix <= 31 then
         GR.GPIO_Periph.ENABLE_W1TS := UInt32 (2)**Ix;
      else
         GR.GPIO_Periph.ENABLE1_W1TS.ENABLE1_W1TS := UInt22 (2)**(Ix - 32);
      end if;
   end Pad_Open_Drain;

   --  Matrix input: route the peripheral input signal In_Sig to read Pad.
   procedure Route_Input (In_Sig : Natural; Pad : G.Pin_Id) is
   begin
      GR.GPIO_Periph.FUNC_IN_SEL_CFG (In_Sig) :=
        (IN_SEL => GR.FUNC_IN_SEL_CFG_IN_SEL_Field (Natural (Pad)), SEL => True, others => <>);
   end Route_Input;

   --  One pad reads back into the same controller that drives it (real bus).
   procedure Route_Line (Pad : G.Pin_Id; Signal : Natural) is
   begin
      Pad_Open_Drain (Pad, Signal);
      Route_Input (Signal, Pad);
   end Route_Line;

   --  Bit length of N (0 -> 0, 45 -> 6, ...), for the timeout knob.
   function Bit_Length (N : Natural) return Natural is
      V : Natural := N;
      L : Natural := 0;
   begin
      while V > 0 loop
         L := L + 1;
         V := V / 2;
      end loop;
      return L;
   end Bit_Length;

   procedure Set_Timing (Regs : Periph_Ref; Hz : Positive) is
      Freq      : constant Natural := Natural'Max (1_000, Natural'Min (Hz, 1_000_000));
      --  Match esp-idf i2c_ll_master_cal_bus_clk: the *1024 keeps the module
      --  clock high (clkm_div small) and half_cycle ~ source/(freq*1024*2),
      --  i.e. just under the 9-bit period fields.  Counting filter / sample /
      --  hold in these (fast) module-clock cycles is what makes them line up
      --  with real bus edges.
      Clkm_Div  : constant Natural := Src_Hz / (Freq * 1024) + 1;
      Sclk_Freq : constant Natural := Src_Hz / Clkm_Div;
      Half      : constant Natural := Natural'Min (511, Natural'Max (4, Sclk_Freq / Freq / 2));
      Wait_High : constant Natural :=
        Natural'Min (127, (if Freq >= 80_000 then Natural'Max (1, Half / 2 - 2) else Half / 4));
      High      : constant Natural := Natural'Max (1, Half - Wait_High);
      Hold_SDA  : constant Natural := Natural'Max (1, Half / 4);
      Sample    : constant Natural := Natural'Max (1, Half / 2);
      Setup     : constant Natural := Half;
      Hold      : constant Natural := Half;
      Tout      : constant Natural := Natural'Min (31, Bit_Length (5 * Half) + 2);
   begin
      Regs.CLK_CONF :=
        (SCLK_DIV_NUM => CLK_CONF_SCLK_DIV_NUM_Field (Clkm_Div - 1),
         SCLK_SEL     => False,
         --  XTAL source
         SCLK_ACTIVE  => True,
         others       => <>);

      Regs.SCL_LOW_PERIOD.SCL_LOW_PERIOD := SCL_LOW_PERIOD_SCL_LOW_PERIOD_Field (Half - 1);
      Regs.SCL_HIGH_PERIOD :=
        (SCL_HIGH_PERIOD      => SCL_HIGH_PERIOD_SCL_HIGH_PERIOD_Field (High - 1),
         SCL_WAIT_HIGH_PERIOD => SCL_HIGH_PERIOD_SCL_WAIT_HIGH_PERIOD_Field (Wait_High),
         others               => <>);
      Regs.SDA_HOLD.TIME := SDA_HOLD_TIME_Field (Hold_SDA - 1);
      Regs.SDA_SAMPLE.TIME := SDA_SAMPLE_TIME_Field (Sample - 1);
      Regs.SCL_RSTART_SETUP.TIME := SCL_RSTART_SETUP_TIME_Field (Setup - 1);
      Regs.SCL_STOP_SETUP.TIME := SCL_STOP_SETUP_TIME_Field (Setup - 1);
      Regs.SCL_START_HOLD.TIME := SCL_START_HOLD_TIME_Field (Hold - 1);
      Regs.SCL_STOP_HOLD.TIME := SCL_STOP_HOLD_TIME_Field (Hold - 1);
      Regs.TO :=
        (TIME_OUT_VALUE => TO_TIME_OUT_VALUE_Field (Tout), TIME_OUT_EN => True, others => <>);
   end Set_Timing;

   ----------
   -- Open --
   ----------

   --  Clock-gate the controller, then PULSE its reset (1 -> 0) to clear any
   --  stuck FSM state -- mirrors esp-idf i2c_ll_enable_bus_clock +
   --  i2c_ll_reset_register.
   procedure Enable_Clock (Host : I2C_Host) is
      use ESP32S3_Registers.SYSTEM;
   begin
      case Host is
         when I2C0 =>
            SYSTEM_Periph.PERIP_CLK_EN0.I2C_EXT0_CLK_EN := True;
            SYSTEM_Periph.PERIP_RST_EN0.I2C_EXT0_RST := True;
            SYSTEM_Periph.PERIP_RST_EN0.I2C_EXT0_RST := False;

         when I2C1 =>
            SYSTEM_Periph.PERIP_CLK_EN0.I2C_EXT1_CLK_EN := True;
            SYSTEM_Periph.PERIP_RST_EN0.I2C_EXT1_RST := True;
            SYSTEM_Periph.PERIP_RST_EN0.I2C_EXT1_RST := False;
      end case;
   end Enable_Clock;

   function Open (Host : I2C_Host; Clock_Hz : Positive) return Bus is
      Regs : constant Periph_Ref := Regs_Of (Host);
   begin
      Enable_Clock (Host);

      --  Master mode, open-drain SDA/SCL outputs.  (CLK_EN is reserved on the
      --  S3 and esp-idf never sets it; ARBITRATION off matches the IDF master.)
      Regs.CTR :=
        (MS_MODE           => True,
         SDA_FORCE_OUT     => True,
         --  open-drain
         SCL_FORCE_OUT     => True,
         --  open-drain
         ARBITRATION_EN    => False,
         RX_FULL_ACK_LEVEL => False,
         others            => <>);

      --  FIFO (not non-fifo / RAM) access mode; flush both FIFOs.
      Regs.FIFO_CONF :=
        (NONFIFO_EN  => False,
         FIFO_PRT_EN => True,
         TX_FIFO_RST => True,
         RX_FIFO_RST => True,
         others      => <>);
      Regs.FIFO_CONF.TX_FIFO_RST := False;
      Regs.FIFO_CONF.RX_FIFO_RST := False;

      --  Light glitch filtering on both lines.
      Regs.FILTER_CFG :=
        (SCL_FILTER_EN    => True,
         SDA_FILTER_EN    => True,
         SCL_FILTER_THRES => 7,
         SDA_FILTER_THRES => 7,
         others           => <>);

      Set_Timing (Regs, Clock_Hz);

      --  Latch the configuration into the controller.
      Regs.CTR.CONF_UPGATE := True;

      return (Regs => Regs, Host => Host, Valid => True);
   end Open;

   function Is_Open (B : Bus) return Boolean
   is (B.Valid);

   --------------------
   -- Configure_Pins --
   --------------------

   procedure Configure_Pins (B : Bus; Scl : G.Pin_Id; Sda : G.Pin_Id) is
      S : constant Sig := Signals (B.Host);
   begin
      if not B.Valid then
         return;
      end if;
      Route_Line (Scl, S.Scl);
      Route_Line (Sda, S.Sda);
   end Configure_Pins;

   --  Reset both FIFOs, clear stale interrupts, kick off the loaded command
   --  sequence and spin until it completes (or times out / loses arbitration).
   --  Returns True if the slave ACKed everything expected.
   procedure Run_Sequence (Regs : Periph_Ref; Acked : out Boolean) is
   begin
      --  Clear all latched interrupt status.
      Regs.INT_CLR :=
        (TRANS_COMPLETE_INT_CLR   => True,
         END_DETECT_INT_CLR       => True,
         NACK_INT_CLR             => True,
         TIME_OUT_INT_CLR         => True,
         ARBITRATION_LOST_INT_CLR => True,
         TRANS_START_INT_CLR      => True,
         others                   => <>);

      Regs.CTR.CONF_UPGATE := True;
      Regs.CTR.TRANS_START := True;

      --  Poll for completion.  The hardware timeout (TIME_OUT_EN) covers a
      --  stalled bus, but bound the spin too so a misconfigured controller that
      --  never starts the FSM can't wedge a caller during bring-up.
      Done :
      declare
         Guard : Natural := 2_000_000;
      begin
         loop
            declare
               R : constant INT_RAW_Register := Regs.INT_RAW;
            begin
               exit when
                 R.TRANS_COMPLETE_INT_RAW
                 or else R.NACK_INT_RAW
                 or else R.TIME_OUT_INT_RAW
                 or else R.ARBITRATION_LOST_INT_RAW;
            end;
            exit when Guard = 0;
            Guard := Guard - 1;
         end loop;

         Acked :=
           Guard > 0
           and then not (Regs.INT_RAW.NACK_INT_RAW
                         or else Regs.INT_RAW.TIME_OUT_INT_RAW
                         or else Regs.INT_RAW.ARBITRATION_LOST_INT_RAW);
      end Done;
   end Run_Sequence;

   procedure Reset_FIFOs (Regs : Periph_Ref) is
   begin
      Regs.FIFO_CONF.TX_FIFO_RST := True;
      Regs.FIFO_CONF.TX_FIFO_RST := False;
      Regs.FIFO_CONF.RX_FIFO_RST := True;
      Regs.FIFO_CONF.RX_FIFO_RST := False;
   end Reset_FIFOs;

   procedure Push (Regs : Periph_Ref; Value : Byte) is
   begin
      Regs.DATA := (FIFO_RDATA => ESP32S3_Registers.Byte (Value), others => <>);
   end Push;

   -----------
   -- Write --
   -----------

   procedure Write
     (B         : Bus;
      Addr      : Slave_Address;
      Data      : Byte_Array;
      Success   : out Boolean;
      Check_Ack : Boolean := True)
   is
      Regs : constant Periph_Ref := B.Regs;
      Len  : constant Natural := Data'Length;
   begin
      Success := False;
      --  A write shares the TX FIFO between the address byte and the payload, so
      --  the payload tops out at Max_Transfer-1 (= 31); accepting Max_Transfer
      --  would push 1+32 = 33 bytes into the 32-deep FIFO and silently drop the
      --  last data byte (FIFO_PRT_EN) while still reporting Success.
      if not B.Valid or else Len > Max_Transfer - 1 then
         return;
      end if;

      Reset_FIFOs (Regs);

      --  TX FIFO: address byte (R/W = 0) followed by the payload.
      Push (Regs, Byte (Addr * 2));
      for D of Data loop
         Push (Regs, D);
      end loop;

      --  Command sequence: START, WRITE(addr + data), STOP.  Check_Ack drives
      --  per-byte ACK checking: on a real bus leave it True so a missing/!ACK
      --  device aborts the write; the single-pad write self-test turns it off
      --  (the slave's ACK can't reach the master when both only read one pad).
      Regs.COMD (0).COMMAND := Cmd (Op_RSTART);
      Regs.COMD (1).COMMAND := Cmd (Op_WRITE, Bytes => 1 + Len, Ack_Check => Check_Ack);
      Regs.COMD (2).COMMAND := Cmd (Op_STOP);

      Run_Sequence (Regs, Success);
   end Write;

   ----------
   -- Read --
   ----------

   procedure Read (B : Bus; Addr : Slave_Address; Data : out Byte_Array; Success : out Boolean) is
      Regs : constant Periph_Ref := B.Regs;
      Len  : constant Natural := Data'Length;
   begin
      Success := False;
      if not B.Valid or else Len = 0 or else Len > Max_Transfer then
         return;
      end if;

      Reset_FIFOs (Regs);

      --  TX FIFO: address byte with R/W = 1.
      Push (Regs, Byte (Addr * 2 + 1));

      --  Command sequence: START, WRITE(addr, ACK-checked),
      --  [READ(len-1, ACK)], READ(1, NACK), STOP.
      Regs.COMD (0).COMMAND := Cmd (Op_RSTART);
      Regs.COMD (1).COMMAND := Cmd (Op_WRITE, Bytes => 1, Ack_Check => True);
      if Len > 1 then
         Regs.COMD (2).COMMAND := Cmd (Op_READ, Bytes => Len - 1, Ack_Val => False);
         Regs.COMD (3).COMMAND := Cmd (Op_READ, Bytes => 1, Ack_Val => True);
         Regs.COMD (4).COMMAND := Cmd (Op_STOP);
      else
         Regs.COMD (2).COMMAND := Cmd (Op_READ, Bytes => 1, Ack_Val => True);
         Regs.COMD (3).COMMAND := Cmd (Op_STOP);
      end if;

      Run_Sequence (Regs, Success);

      if Success then
         for I in Data'Range loop
            Data (I) := Byte (Regs.DATA.FIFO_RDATA);
         end loop;
      end if;
   end Read;

   procedure Close (B : in out Bus) is
   begin
      B.Valid := False;
   end Close;

end ESP32S3.I2C.Engine;
