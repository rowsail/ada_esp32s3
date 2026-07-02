with System;
with ESP32S3.GPIO;
with ESP32S3.GPIO_Signals;
with ESP32S3_Registers;     use ESP32S3_Registers;
with ESP32S3_Registers.RMT; use ESP32S3_Registers.RMT;
with ESP32S3_Registers.GPIO;
with ESP32S3_Registers.IO_MUX;
with ESP32S3_Registers.SYSTEM;

package body ESP32S3.RMT is

   package GR renames ESP32S3_Registers.GPIO;
   package MX renames ESP32S3_Registers.IO_MUX;
   package G renames ESP32S3.GPIO;
   package Sigs renames ESP32S3.GPIO_Signals;

   Src_Hz : constant := 80_000_000;             --  APB clock feeds the RMT

   ---------------------------------------------------------------------------
   --  RMT symbol RAM: eight 48-symbol blocks at RMT_Base + 0x400.  TX channel n
   --  uses block n; RX channel r (registers 0..3) is physical channel 4+r and
   --  uses block 4+r.
   ---------------------------------------------------------------------------

   Block_Symbols : constant := 48;

   type Mem_Block is array (0 .. Block_Symbols - 1) of RMT_Symbol;
   type Mem_Array is array (0 .. 7) of Mem_Block with Volatile;
   RMTMEM : Mem_Array
   with Import, Volatile, Address => System'To_Address (16#6001_6800#);

   --  Flat view of the same 8 x 48 = 384-symbol RAM, so a multi-block channel
   --  (and the wrap re-fill) can index across block boundaries: channel n's
   --  symbol J lives at flat slot n*48 + J.
   type Flat_Mem is array (0 .. 8 * Block_Symbols - 1) of RMT_Symbol
   with Volatile;
   Mem_Flat : Flat_Mem
   with Import, Volatile, Address => RMTMEM'Address;

   --  RX config registers, re-imposed as an array (CONF0 + CONF1, stride 8).
   type RX_Regs is record
      CONF0 : CH_RX_CONF_Register;
      CONF1 : CH_RX_CONF_Register_1;
   end record
   with Volatile;
   for RX_Regs use
     record
       CONF0 at 0 range 0 .. 31;
       CONF1 at 4 range 0 .. 31;
     end record;
   for RX_Regs'Size use 8 * 8;
   for RX_Regs'Object_Size use 8 * 8;
   type RX_Array is array (RX_Index) of RX_Regs;
   RX_Conf : RX_Array
   with Import, Volatile, Address => RMT_Periph.CH_RX_CONF00'Address;

   function Div_Of (Resolution_Hz : Positive) return Byte
   is (Byte (Natural'Max (1, Natural'Min (255, Src_Hz / Resolution_Hz))));

   procedure Drive_Out (Pin : G.Pin_Id; Sig : Natural) is
      O : GR.FUNC_OUT_SEL_CFG_Register :=
        GR.GPIO_Periph.FUNC_OUT_SEL_CFG (Natural (Pin));
   begin
      G.Configure (Pin, Mode => G.Output, Drive => G.Drive_Strong);
      O.OUT_SEL := GR.FUNC_OUT_SEL_CFG_OUT_SEL_Field (Sig);
      O.OEN_SEL := False;
      GR.GPIO_Periph.FUNC_OUT_SEL_CFG (Natural (Pin)) := O;
   end Drive_Out;

   --  Route Pin into matrix input Sig WITHOUT disabling its output driver, so a
   --  TX channel driving the pad can be read back by an RX channel (loopback).
   procedure Route_In (Sig : Natural; Pin : G.Pin_Id) is
      Ix : constant Natural := Natural (Pin);
      P  : MX.GPIO_Register := MX.IO_MUX_Periph.GPIO (Ix);
   begin
      P.MCU_SEL := 1;          --  pad driven via the GPIO matrix
      P.FUN_IE :=
        True;       --  enable the input buffer so RX can read the pad
      MX.IO_MUX_Periph.GPIO (Ix) := P;
      GR.GPIO_Periph.FUNC_IN_SEL_CFG (Sig) :=
        (IN_SEL => GR.FUNC_IN_SEL_CFG_IN_SEL_Field (Ix),
         SEL    => True,
         others => <>);
   end Route_In;

   --------------------------------------------------------------------------
   --  Module bring-up (once) + channel-ownership pools.
   --------------------------------------------------------------------------

   type TX_Map is array (TX_Index) of Boolean;
   type RX_Map is array (RX_Index) of Boolean;

   protected Pool is
      procedure Claim_TX (Index : TX_Index; Ok : out Boolean);
      procedure Release_TX (Index : TX_Index);
      procedure Claim_RX (Index : RX_Index; Ok : out Boolean);
      procedure Release_RX (Index : RX_Index);
   private
      TX_Used : TX_Map := (others => False);
      RX_Used : RX_Map := (others => False);
      Inited  : Boolean := False;
   end Pool;

   protected body Pool is

      procedure Init is
         use ESP32S3_Registers.SYSTEM;
      begin
         if Inited then
            return;
         end if;
         SYSTEM_Periph.PERIP_CLK_EN0.RMT_CLK_EN := True;
         SYSTEM_Periph.PERIP_RST_EN0.RMT_RST := True;
         SYSTEM_Periph.PERIP_RST_EN0.RMT_RST := False;
         --  Module clock = APB (sel 1), no group divide; keep the symbol RAM on;
         --  APB_FIFO_MASK = direct (non-FIFO) access to the symbol RAM so we can
         --  read/write RMTMEM memory-mapped.
         RMT_Periph.SYS_CONF :=
           (SCLK_SEL         => 1,
            SCLK_DIV_NUM     => 0,
            SCLK_ACTIVE      => True,
            MEM_CLK_FORCE_ON => True,
            APB_FIFO_MASK    => True,
            CLK_EN           => True,
            others           => <>);
         Inited := True;
      end Init;

      procedure Claim_TX (Index : TX_Index; Ok : out Boolean) is
      begin
         Init;
         Ok := not TX_Used (Index);
         if Ok then
            TX_Used (Index) := True;
         end if;
      end Claim_TX;

      procedure Release_TX (Index : TX_Index) is
      begin
         TX_Used (Index) := False;
      end Release_TX;

      procedure Claim_RX (Index : RX_Index; Ok : out Boolean) is
      begin
         Init;
         Ok := not RX_Used (Index);
         if Ok then
            RX_Used (Index) := True;
         end if;
      end Claim_RX;

      procedure Release_RX (Index : RX_Index) is
      begin
         RX_Used (Index) := False;
      end Release_RX;

   end Pool;

   --  Per-channel TX-END / RX-END interrupt-raw bit (named fields -> case).
   function TX_Done (Idx : TX_Index) return Boolean
   is (case Idx is
         when 0 => RMT_Periph.INT_RAW.CH0_TX_END,
         when 1 => RMT_Periph.INT_RAW.CH1_TX_END,
         when 2 => RMT_Periph.INT_RAW.CH2_TX_END,
         when 3 => RMT_Periph.INT_RAW.CH3_TX_END);

   procedure Clear_TX_Done (Idx : TX_Index) is
   begin
      case Idx is
         when 0 =>
            RMT_Periph.INT_CLR.CH0_TX_END := True;

         when 1 =>
            RMT_Periph.INT_CLR.CH1_TX_END := True;

         when 2 =>
            RMT_Periph.INT_CLR.CH2_TX_END := True;

         when 3 =>
            RMT_Periph.INT_CLR.CH3_TX_END := True;
      end case;
   end Clear_TX_Done;

   --  Per-channel TX threshold-reached interrupt-raw bit (wrap re-fill trigger).
   function TX_Thr (Idx : TX_Index) return Boolean
   is (case Idx is
         when 0 => RMT_Periph.INT_RAW.CH0_TX_THR_EVENT,
         when 1 => RMT_Periph.INT_RAW.CH1_TX_THR_EVENT,
         when 2 => RMT_Periph.INT_RAW.CH2_TX_THR_EVENT,
         when 3 => RMT_Periph.INT_RAW.CH3_TX_THR_EVENT);

   procedure Clear_TX_Thr (Idx : TX_Index) is
   begin
      case Idx is
         when 0 =>
            RMT_Periph.INT_CLR.CH0_TX_THR_EVENT := True;

         when 1 =>
            RMT_Periph.INT_CLR.CH1_TX_THR_EVENT := True;

         when 2 =>
            RMT_Periph.INT_CLR.CH2_TX_THR_EVENT := True;

         when 3 =>
            RMT_Periph.INT_CLR.CH3_TX_THR_EVENT := True;
      end case;
   end Clear_TX_Thr;

   function RX_Done (Idx : RX_Index) return Boolean
   is (case Idx is
         when 0 => RMT_Periph.INT_RAW.CH4_RX_END,
         when 1 => RMT_Periph.INT_RAW.CH5_RX_END,
         when 2 => RMT_Periph.INT_RAW.CH6_RX_END,
         when 3 => RMT_Periph.INT_RAW.CH7_RX_END);

   procedure Clear_RX_Done (Idx : RX_Index) is
   begin
      case Idx is
         when 0 =>
            RMT_Periph.INT_CLR.CH4_RX_END := True;

         when 1 =>
            RMT_Periph.INT_CLR.CH5_RX_END := True;

         when 2 =>
            RMT_Periph.INT_CLR.CH6_RX_END := True;

         when 3 =>
            RMT_Periph.INT_CLR.CH7_RX_END := True;
      end case;
   end Clear_RX_Done;

   ----------------------------------------------------------------------------
   --  TX channel.
   ----------------------------------------------------------------------------

   procedure Claim (C : in out TX_Channel; Index : TX_Index) is
      Ok : Boolean;
   begin
      Release (C);
      Pool.Claim_TX (Index, Ok);
      if Ok then
         C.Idx := Index;
         C.Held := True;
      end if;
   end Claim;

   function Is_Valid (C : TX_Channel) return Boolean
   is (C.Held);

   procedure Release (C : in out TX_Channel) is
   begin
      if C.Held then
         RMT_Periph.CH_TX_CONF0 (Integer (C.Idx)).TX_STOP := True;
         Pool.Release_TX (C.Idx);
         C.Held := False;
      end if;
   end Release;

   overriding
   procedure Finalize (C : in out TX_Channel) is
   begin
      Release (C);
   end Finalize;

   procedure Configure
     (C             : in out TX_Channel;
      Resolution_Hz : Positive;
      Pin           : ESP32S3.GPIO.Pin_Id;
      Blocks        : Positive := 1) is
   begin
      if not C.Held then
         return;
      end if;
      C.Blocks := Positive'Min (Blocks, 4 - Natural (C.Idx));   --  fit in 0..3
      RMT_Periph.CH_TX_CONF0 (Integer (C.Idx)) :=
        (DIV_CNT        => Div_Of (Resolution_Hz),
         MEM_SIZE       => CH_TX_CONF0_MEM_SIZE_Field (C.Blocks),
         IDLE_OUT_EN    => True,
         IDLE_OUT_LV    => False,
         CARRIER_EN     => False,
         CARRIER_EFF_EN => False,
         others         => <>);
      Drive_Out (Pin, Sigs.RMT_SIG_OUT0 + Natural (C.Idx));
   end Configure;

   procedure Transmit (C : TX_Channel; Symbols : Symbol_Array) is
      Blk  : constant Integer := Integer (C.Idx);
      Base : constant Natural :=
        Blk * Block_Symbols;     --  flat slot of block
      Cap  : constant Natural := C.Blocks * Block_Symbols - 1;
      N    : constant Natural := Symbols'Length;
      F    : constant Natural := Symbols'First;

      --  Reset the read pointer, latch the config, and start the channel.
      procedure Kick is
      begin
         Clear_TX_Done (C.Idx);
         Clear_TX_Thr (C.Idx);
         RMT_Periph.CH_TX_CONF0 (Blk).MEM_RD_RST := True;
         RMT_Periph.CH_TX_CONF0 (Blk).MEM_RD_RST := False;
         RMT_Periph.CH_TX_CONF0 (Blk).APB_MEM_RST := True;
         RMT_Periph.CH_TX_CONF0 (Blk).APB_MEM_RST := False;
         RMT_Periph.CH_TX_CONF0 (Blk).CONF_UPDATE := True;
         RMT_Periph.CH_TX_CONF0 (Blk).TX_START := True;
      end Kick;
   begin
      if not C.Held then
         return;
      end if;

      if N <= Cap then
         --  One shot: the whole burst fits the channel's RAM.
         RMT_Periph.CH_TX_CONF0 (Blk).MEM_TX_WRAP_EN := False;
         for J in 0 .. N - 1 loop
            Mem_Flat (Base + J) := Symbols (F + J);
         end loop;
         Mem_Flat (Base + N) := (others => <>);           --  end marker
         Kick;
         declare
            Guard : Natural := 5_000_000;
         begin
            while not TX_Done (C.Idx) and then Guard > 0 loop
               Guard := Guard - 1;
            end loop;
         end;
         Clear_TX_Done (C.Idx);
         return;
      end if;

      --  Wrap streaming: use one 48-symbol block as two 24-symbol halves and,
      --  on each threshold event, re-fill the half that just played -- so an
      --  arbitrarily long burst streams through 48 symbols of RAM.  A short
      --  final half is padded with {0,0} end markers, which stops the channel.
      declare
         Half   : constant Natural := Block_Symbols / 2;  --  24
         Cursor : Natural :=
           F;                           --  next source symbol
         Which  : Natural := 0;                           --  half to re-fill

         procedure Fill_Half (H : Natural) is
            HBase : constant Natural := Base + H * Half;
         begin
            for K in 0 .. Half - 1 loop
               if Cursor < F + N then
                  Mem_Flat (HBase + K) := Symbols (Cursor);
                  Cursor := Cursor + 1;
               else
                  Mem_Flat (HBase + K) := (others => <>); --  end marker / pad
               end if;
            end loop;
         end Fill_Half;
      begin
         RMT_Periph.CH_TX_CONF0 (Blk).MEM_SIZE := 1;   --  wrap at 48
         RMT_Periph.CH_TX_CONF0 (Blk).MEM_TX_WRAP_EN := True;
         RMT_Periph.CH_TX_LIM (Blk).TX_LIM := CH_TX_LIM_TX_LIM_Field (Half);

         Fill_Half (0);                                   --  prime both halves
         Fill_Half (1);
         Kick;

         declare
            Guard : Natural := 50_000_000;
         begin
            loop
               exit when TX_Done (C.Idx) or else Guard = 0;
               Guard := Guard - 1;
               if TX_Thr (C.Idx) then
                  Clear_TX_Thr (C.Idx);
                  Fill_Half
                    (Which);          --  re-fill the half just consumed
                  Which := 1 - Which;
               end if;
            end loop;
         end;

         RMT_Periph.CH_TX_CONF0 (Blk).MEM_TX_WRAP_EN := False;
         RMT_Periph.CH_TX_CONF0 (Blk).MEM_SIZE :=
           CH_TX_CONF0_MEM_SIZE_Field (C.Blocks);
         Clear_TX_Done (C.Idx);
         Clear_TX_Thr (C.Idx);
      end;
   end Transmit;

   ----------------------------------------------------------------------------
   --  RX channel.
   ----------------------------------------------------------------------------

   procedure Claim (C : in out RX_Channel; Index : RX_Index) is
      Ok : Boolean;
   begin
      Release (C);
      Pool.Claim_RX (Index, Ok);
      if Ok then
         C.Idx := Index;
         C.Held := True;
      end if;
   end Claim;

   function Is_Valid (C : RX_Channel) return Boolean
   is (C.Held);

   procedure Release (C : in out RX_Channel) is
   begin
      if C.Held then
         RX_Conf (C.Idx).CONF1.RX_EN := False;
         Pool.Release_RX (C.Idx);
         C.Held := False;
      end if;
   end Release;

   overriding
   procedure Finalize (C : in out RX_Channel) is
   begin
      Release (C);
   end Finalize;

   procedure Configure
     (C             : in out RX_Channel;
      Resolution_Hz : Positive;
      Pin           : ESP32S3.GPIO.Pin_Id;
      Idle_Ticks    : Tick_Count := 2_000) is
   begin
      if not C.Held then
         return;
      end if;
      RX_Conf (C.Idx).CONF0 :=
        (DIV_CNT    => Div_Of (Resolution_Hz),
         IDLE_THRES => CH_RX_CONF_IDLE_THRES_Field (Idle_Ticks),
         MEM_SIZE   => 1,
         CARRIER_EN => False,
         others     => <>);
      RX_Conf (C.Idx).CONF1 :=
        (MEM_OWNER       => True,
         RX_FILTER_EN    => True,
         RX_FILTER_THRES => 10,
         RX_EN           => False,
         others          => <>);
      --  RMT exposes four matrix signal slots (81 .. 84); RMT_SIG_OUTn drives a
      --  TX channel and RMT_SIG_INn feeds RX channel n -- same index, opposite
      --  direction.  So RX register index r reads input signal 81 + r.
      Route_In (Sigs.RMT_SIG_IN0 + Natural (C.Idx), Pin);
   end Configure;

   procedure Start (C : RX_Channel) is
   begin
      if not C.Held then
         return;
      end if;
      Clear_RX_Done (C.Idx);
      RX_Conf (C.Idx).CONF1.MEM_WR_RST := True;
      RX_Conf (C.Idx).CONF1.MEM_WR_RST := False;
      RX_Conf (C.Idx).CONF1.APB_MEM_RST := True;
      RX_Conf (C.Idx).CONF1.APB_MEM_RST := False;
      RX_Conf (C.Idx).CONF1.RX_EN := True;
      RX_Conf (C.Idx).CONF1.CONF_UPDATE := True;
   end Start;

   procedure Receive
     (C : RX_Channel; Into : out Symbol_Array; Count : out Natural)
   is
      Blk : constant Integer := 4 + Integer (C.Idx);
      J   : Natural := 0;
   begin
      Count := 0;
      if not C.Held then
         return;
      end if;
      declare
         Guard : Natural := 20_000_000;
      begin
         while not RX_Done (C.Idx) and then Guard > 0 loop
            Guard := Guard - 1;
         end loop;
         if Guard = 0 then
            --  timed out: nothing received
            return;
         end if;
      end;

      --  Hand the RAM back to the CPU and read symbols.  Reception ends either
      --  at an empty entry (Duration0 = 0) or after the symbol whose second
      --  pulse the idle period truncated (Duration1 = 0 marks the last symbol).
      RX_Conf (C.Idx).CONF1.MEM_OWNER := False;
      while J <= Block_Symbols - 1 and then J <= Into'Length - 1 loop
         declare
            S : constant RMT_Symbol := RMTMEM (Blk) (J);
         begin
            exit when S.Duration0 = 0;        --  empty entry: nothing more
            Into (Into'First + J) := S;
            J := J + 1;
            exit when
              S.Duration1 = 0;        --  idle truncated this last symbol
         end;
      end loop;
      Count := J;

      Clear_RX_Done (C.Idx);
      RX_Conf (C.Idx).CONF1.RX_EN := False;
   end Receive;

end ESP32S3.RMT;
