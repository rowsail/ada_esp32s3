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
   --  END: halt the command FSM without releasing the bus (SCL stays low, no
   --  STOP).  Raises END_DETECT; reloading COMD and re-triggering TRANS_START
   --  resumes the SAME transaction.  This is what lets a payload outrun the FIFO.
   Op_END    : constant := 4;

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
      Pad_Index : constant Natural := Natural (Pad);
      Mux_Cfg   : MX.GPIO_Register :=                --  the pad's IO-MUX config
        MX.IO_MUX_Periph.GPIO (Pad_Index);
      Out_Cfg   : GR.FUNC_OUT_SEL_CFG_Register :=    --  the pad's output-select config
        GR.GPIO_Periph.FUNC_OUT_SEL_CFG (Pad_Index);
   begin
      Mux_Cfg.MCU_SEL := 1;                 --  route through the GPIO matrix
      Mux_Cfg.FUN_IE := True;               --  input buffer on (read-back)
      Mux_Cfg.FUN_WPU := True;              --  internal pull-up (line idles high)
      Mux_Cfg.FUN_WPD := False;
      Mux_Cfg.FUN_DRV := 2;                 --  ~20 mA, fine for open-drain
      MX.IO_MUX_Periph.GPIO (Pad_Index) := Mux_Cfg;

      GR.GPIO_Periph.PIN (Pad_Index).PAD_DRIVER := True;   --  open-drain

      Out_Cfg.OUT_SEL := GR.FUNC_OUT_SEL_CFG_OUT_SEL_Field (Out_Sig);
      Out_Cfg.OEN_SEL := False;             --  use the peripheral's output-enable
      GR.GPIO_Periph.FUNC_OUT_SEL_CFG (Pad_Index) := Out_Cfg;

      if Pad_Index <= 31 then
         GR.GPIO_Periph.ENABLE_W1TS := UInt32 (2)**Pad_Index;
      else
         GR.GPIO_Periph.ENABLE1_W1TS.ENABLE1_W1TS := UInt22 (2)**(Pad_Index - 32);
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
      Value  : Natural := N;   --  shrinks toward 0 as we count bits
      Length : Natural := 0;   --  number of bits seen so far
   begin
      while Value > 0 loop
         Length := Length + 1;
         Value := Value / 2;
      end loop;
      return Length;
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
      Host_Sigs : constant Sig := Signals (B.Host);   --  GPIO-matrix signal ids for this host
   begin
      if not B.Valid then
         return;
      end if;
      Route_Line (Scl, Host_Sigs.Scl);
      Route_Line (Sda, Host_Sigs.Sda);
   end Configure_Pins;

   --  How a loaded command sequence ended.  Paused = it hit an END opcode: the
   --  bus is still held and the transaction resumes on the next TRANS_START.
   type Seq_Outcome is (Completed, Paused, Failed);

   --  Clear stale interrupts, kick off the loaded command sequence and spin until
   --  it completes, pauses at an END, or fails (NACK / timeout / lost arbitration).
   procedure Run_Sequence (Regs : Periph_Ref; Outcome : out Seq_Outcome) is
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
               Ints : constant INT_RAW_Register := Regs.INT_RAW;   --  latched interrupts
            begin
               exit when
                 Ints.TRANS_COMPLETE_INT_RAW
                 or else Ints.END_DETECT_INT_RAW
                 or else Ints.NACK_INT_RAW
                 or else Ints.TIME_OUT_INT_RAW
                 or else Ints.ARBITRATION_LOST_INT_RAW;
            end;
            exit when Guard = 0;
            Guard := Guard - 1;
         end loop;

         if Guard = 0 then
            Outcome := Failed;      --  FSM never started / never finished
            return;
         end if;

         declare
            Ints : constant INT_RAW_Register := Regs.INT_RAW;
         begin
            if Ints.NACK_INT_RAW
              or else Ints.TIME_OUT_INT_RAW
              or else Ints.ARBITRATION_LOST_INT_RAW
            then
               Outcome := Failed;
            elsif Ints.TRANS_COMPLETE_INT_RAW then
               Outcome := Completed;
            else
               Outcome := Paused;   --  END_DETECT: bus held, awaiting a refill
            end if;
         end;
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

   ---------------------------------------------------------------------------
   --  Phases.
   --
   --  A transaction is a START, one or more addressed phases, and a STOP.  Each
   --  phase moves an arbitrary number of bytes in FIFO-sized bursts joined by the
   --  END opcode: the FSM parks with the bus still held, we refill (or drain) the
   --  FIFO, and TRANS_START resumes the SAME transaction.  A phase that is not
   --  the last leaves the FSM parked, so the next phase simply opens with another
   --  RSTART -- which on the wire IS the repeated START.  Hence:
   --
   --     Write       = Write_Phase (closing with STOP)
   --     Read        = Read_Phase
   --     Write_Read  = Write_Phase (closing with END) then Read_Phase
   --
   --  A read burst tops out at Max_Transfer-1 (= 31), not 32: the FIFO RAM is
   --  shared with the address byte the phase begins by writing.  Measured -- a
   --  32-byte read NACKs, and the aborted transfer leaves the slave driving SDA
   --  low, wedging the bus until it is power-cycled.
   ---------------------------------------------------------------------------

   Max_Read_Burst : constant := Max_Transfer - 1;

   --  A write phase's wire stream is the address byte followed by the payload;
   --  Stream_Byte indexes it as one sequence so the burst loop needn't
   --  special-case the head.  (The address byte's R/W bit is 0: a write.)
   function Stream_Byte (Addr : Slave_Address; Data : Byte_Array; I : Natural) return Byte
   is (if I = 0 then Byte (Addr * 2) else Data (Data'First + I - 1));

   --  START, (Addr<<1 | W), Data.  Closes with STOP if Close is set, else parks
   --  the FSM on an END for the next phase (Outcome = Paused).
   --
   --  Check_Ack drives per-byte ACK checking: on a real bus leave it True so a
   --  missing/!ACK device aborts the write; the single-pad write self-test turns
   --  it off (the slave's ACK can't reach the master when both only read one pad).
   procedure Write_Phase
     (Regs      : Periph_Ref;
      Addr      : Slave_Address;
      Data      : Byte_Array;
      Check_Ack : Boolean;
      Close     : Boolean;
      Outcome   : out Seq_Outcome)
   is
      Total : constant Natural := 1 + Data'Length;   --  address byte + payload
      Sent  : Natural := 0;                          --  stream bytes the FSM has taken
      First : Boolean := True;                       --  the burst that carries the START
   begin
      loop
         declare
            Burst : constant Natural := Natural'Min (Max_Transfer, Total - Sent);
            Last  : constant Boolean := Sent + Burst = Total;
            Slot  : Natural := 0;                    --  next free COMD register
         begin
            for I in 0 .. Burst - 1 loop
               Push (Regs, Stream_Byte (Addr, Data, Sent + I));
            end loop;

            if First then
               Regs.COMD (Slot).COMMAND := Cmd (Op_RSTART);
               Slot := Slot + 1;
            end if;
            Regs.COMD (Slot).COMMAND := Cmd (Op_WRITE, Bytes => Burst, Ack_Check => Check_Ack);
            Slot := Slot + 1;
            Regs.COMD (Slot).COMMAND := Cmd (if Last and then Close then Op_STOP else Op_END);

            Run_Sequence (Regs, Outcome);

            if Last then
               return;                       --  Completed (STOP), Paused (END) or Failed
            elsif Outcome /= Paused then
               return;                       --  NACKed / wedged part-way
            end if;

            Sent := Sent + Burst;
            First := False;
         end;
      end loop;
   end Write_Phase;

   --  (Repeated) START, (Addr<<1 | R), Data'Length bytes -- ACK all but the very
   --  last, NACK that one -- STOP.  Data is filled only on Completed.
   procedure Read_Phase
     (Regs : Periph_Ref; Addr : Slave_Address; Data : out Byte_Array; Outcome : out Seq_Outcome)
   is
      Len   : constant Natural := Data'Length;   --  >= 1, checked by the callers
      Got   : Natural := 0;                      --  bytes already drained into Data
      First : Boolean := True;                   --  the burst that addresses the slave
   begin
      loop
         declare
            Burst : constant Natural := Natural'Min (Max_Read_Burst, Len - Got);
            Last  : constant Boolean := Got + Burst = Len;
            Slot  : Natural := 0;
         begin
            if First then
               Regs.COMD (Slot).COMMAND := Cmd (Op_RSTART);
               Slot := Slot + 1;
               Push (Regs, Byte (Addr * 2 + 1));   --  address byte, R/W = 1
               Regs.COMD (Slot).COMMAND := Cmd (Op_WRITE, Bytes => 1, Ack_Check => True);
               Slot := Slot + 1;
            end if;

            if Last then
               --  Only the final byte of the whole phase is NACKed -- that is what
               --  tells the slave to stop driving.
               if Burst > 1 then
                  Regs.COMD (Slot).COMMAND :=
                    Cmd (Op_READ, Bytes => Burst - 1, Ack_Val => False);
                  Slot := Slot + 1;
               end if;
               Regs.COMD (Slot).COMMAND := Cmd (Op_READ, Bytes => 1, Ack_Val => True);
               Slot := Slot + 1;
               Regs.COMD (Slot).COMMAND := Cmd (Op_STOP);
            else
               Regs.COMD (Slot).COMMAND := Cmd (Op_READ, Bytes => Burst, Ack_Val => False);
               Slot := Slot + 1;
               Regs.COMD (Slot).COMMAND := Cmd (Op_END);
            end if;

            Run_Sequence (Regs, Outcome);

            --  A burst must end exactly as its command sequence asked: STOP ->
            --  Completed, END -> Paused.  Anything else is a fault.
            if Outcome /= (if Last then Completed else Paused) then
               Outcome := Failed;
               return;
            end if;

            --  Drain this burst's bytes before resuming: the FIFO must be empty
            --  before the FSM refills it.
            for I in 0 .. Burst - 1 loop
               Data (Data'First + Got + I) := Byte (Regs.DATA.FIFO_RDATA);
            end loop;
            Got := Got + Burst;

            exit when Last;
            First := False;
         end;
      end loop;
   end Read_Phase;

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
      Regs    : constant Periph_Ref := B.Regs;
      Outcome : Seq_Outcome;
   begin
      Success := False;
      if not B.Valid then
         return;
      end if;

      Reset_FIFOs (Regs);
      Write_Phase (Regs, Addr, Data, Check_Ack, Close => True, Outcome => Outcome);
      Success := Outcome = Completed;
   end Write;

   ----------
   -- Read --
   ----------

   procedure Read (B : Bus; Addr : Slave_Address; Data : out Byte_Array; Success : out Boolean) is
      Regs    : constant Periph_Ref := B.Regs;
      Outcome : Seq_Outcome;
   begin
      Success := False;
      if not B.Valid or else Data'Length = 0 then
         return;
      end if;

      Reset_FIFOs (Regs);
      Read_Phase (Regs, Addr, Data, Outcome);
      Success := Outcome = Completed;
   end Read;

   ----------------
   -- Write_Read --
   ----------------

   procedure Write_Read
     (B       : Bus;
      Addr    : Slave_Address;
      Tx      : Byte_Array;
      Rx      : out Byte_Array;
      Success : out Boolean)
   is
      Regs    : constant Periph_Ref := B.Regs;
      Outcome : Seq_Outcome;
   begin
      Success := False;
      if not B.Valid or else Rx'Length = 0 then
         return;
      end if;

      Reset_FIFOs (Regs);

      --  Write phase closes on an END, NOT a STOP: the bus stays held, so the
      --  read phase's RSTART is a repeated START.  The slave never sees the
      --  transaction end, which is what a register-then-data device requires.
      Write_Phase (Regs, Addr, Tx, Check_Ack => True, Close => False, Outcome => Outcome);
      if Outcome /= Paused then
         return;
      end if;

      Read_Phase (Regs, Addr, Rx, Outcome);
      Success := Outcome = Completed;
   end Write_Read;

   procedure Close (B : in out Bus) is
   begin
      B.Valid := False;
   end Close;

end ESP32S3.I2C.Engine;
