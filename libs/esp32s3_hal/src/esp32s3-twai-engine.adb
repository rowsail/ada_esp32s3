with Interfaces;             use Interfaces;
with Ada.Unchecked_Conversion;
with ESP32S3.GPIO;
with ESP32S3.GPIO_Signals;
with ESP32S3_Registers;      use ESP32S3_Registers;
with ESP32S3_Registers.TWAI; use ESP32S3_Registers.TWAI;
with ESP32S3_Registers.GPIO;
with ESP32S3_Registers.IO_MUX;
with ESP32S3_Registers.SYSTEM;

package body ESP32S3.TWAI.Engine is

   --  The CAN frame-information byte as its documented bit fields, so the layout
   --  is named and compiler-placed rather than hand-masked.  Reserved (bits 4..5)
   --  is defined so no undefined padding leaks onto the wire.  (Both directions
   --  are verified against the previous arithmetic in test/repclause_host.)
   type DLC_Field is mod 2**4;
   type Rsvd_2 is mod 2**2;
   type Frame_Info is record
      Length   : DLC_Field;   --  DLC: 0..8 used (9..15 legal on the wire = 8)
      Reserved : Rsvd_2;      --  bits 4..5, always 0
      Remote   : Boolean;     --  RTR
      Extended : Boolean;     --  FF (extended id)
   end record;
   for Frame_Info use
     record
       Length at 0 range 0 .. 3;
       Reserved at 0 range 4 .. 5;
       Remote at 0 range 6 .. 6;
       Extended at 0 range 7 .. 7;
     end record;
   for Frame_Info'Size use 8;
   function To_Byte is new Ada.Unchecked_Conversion (Frame_Info, Unsigned_8);
   function To_Info is new Ada.Unchecked_Conversion (Unsigned_8, Frame_Info);

   package GR renames ESP32S3_Registers.GPIO;
   package MX renames ESP32S3_Registers.IO_MUX;
   package G renames ESP32S3.GPIO;
   package Sigs renames ESP32S3.GPIO_Signals;

   Src_Hz : constant := 80_000_000;             --  APB clock feeds the TWAI

   --  The 13 data/accept registers (offsets 0x40..0x70) as a byte-addressable
   --  array (each register exposes the byte in its low 8 bits).
   type Data_Array is array (0 .. 12) of DATA_0_Register with Volatile;
   Buf : Data_Array
   with Import, Volatile, Address => TWAI0_Periph.DATA_0'Address;

   procedure Put (N : Natural; V : Unsigned_8) is
   begin
      Buf (N) := (TX_BYTE_0 => DATA_0_TX_BYTE_0_Field (V), others => <>);
   end Put;

   function Get (N : Natural) return Unsigned_8
   is (Unsigned_8 (Buf (N).TX_BYTE_0));

   procedure Drive_Out (Pad : G.Pin_Id; Sig : Natural) is
      O : GR.FUNC_OUT_SEL_CFG_Register := GR.GPIO_Periph.FUNC_OUT_SEL_CFG (Natural (Pad));
   begin
      G.Configure (Pad, Mode => G.Output, Drive => G.Drive_Strong);
      O.OUT_SEL := GR.FUNC_OUT_SEL_CFG_OUT_SEL_Field (Sig);
      O.OEN_SEL := False;
      GR.GPIO_Periph.FUNC_OUT_SEL_CFG (Natural (Pad)) := O;
   end Drive_Out;

   --  Enable the pad's input buffer and route it to matrix input Sig.  Works
   --  whether the pad is an external input or one TX is driving (loopback).
   procedure Route_In (Sig : Natural; Pad : G.Pin_Id) is
      Ix : constant Natural := Natural (Pad);
      P  : MX.GPIO_Register := MX.IO_MUX_Periph.GPIO (Ix);
   begin
      P.MCU_SEL := 1;
      P.FUN_IE := True;
      MX.IO_MUX_Periph.GPIO (Ix) := P;
      GR.GPIO_Periph.FUNC_IN_SEL_CFG (Sig) :=
        (IN_SEL => GR.FUNC_IN_SEL_CFG_IN_SEL_Field (Ix), SEL => True, others => <>);
   end Route_In;

   ----------
   -- Open --
   ----------

   function Open (Mode : Bus_Mode; Bit_Rate : Positive) return Bus is
      use ESP32S3_Registers.SYSTEM;
      --  bit = (1 + (TSEG1+1) + (TSEG2+1)) time-quanta; the hardware prescaler is
      --  t_q = 2*(BAUD_PRESC+1) / f_apb, so the effective divisor BRP below is
      --  2*(BAUD_PRESC+1) and must be even.  Use 20 Tq/bit (not 16): with f_apb =
      --  80 MHz that makes BRP = 80e6/(rate*20) come out EVEN for every standard
      --  rate -- 1M/500k/250k/125k -> BRP 4/8/16/32 -> exact.  (16 Tq/bit gave an
      --  ODD BRP=5 for 1 Mbit, which the even-rounding turned into 1.25 Mbit/s, a
      --  25% error that will not communicate on a real bus.)
      Tq_Per_Bit : constant := 20;
      BRP        : Integer := Integer (Src_Hz / (Bit_Rate * Tq_Per_Bit));   --  ~ even prescaler
   begin
      if BRP < 2 then
         BRP := 2;
      elsif BRP > 128 then
         BRP := 128;
      end if;
      BRP := (BRP / 2) * 2;                            --  make it even

      SYSTEM_Periph.PERIP_CLK_EN0.TWAI_CLK_EN := True;
      SYSTEM_Periph.PERIP_RST_EN0.TWAI_RST := True;
      SYSTEM_Periph.PERIP_RST_EN0.TWAI_RST := False;

      --  Enter reset mode to configure.
      TWAI0_Periph.MODE := (RESET_MODE => True, others => <>);

      --  Bit timing: BAUD_PRESC=BRP/2-1, SJW=3, TSEG1=16, TSEG2=3 (1+16+3 = 20 Tq;
      --  sample point 17/20 = 85%).  Register fields hold length-1.
      TWAI0_Periph.BUS_TIMING_0 :=
        (BAUD_PRESC      => BUS_TIMING_0_BAUD_PRESC_Field (BRP / 2 - 1),
         SYNC_JUMP_WIDTH => 2,
         others          => <>);
      TWAI0_Periph.BUS_TIMING_1 :=
        (TIME_SEG1 => 15, TIME_SEG2 => 2, TIME_SAMP => False, others => <>);
      TWAI0_Periph.CLOCK_DIVIDER := (CD => 0, CLOCK_OFF => False, others => <>);

      --  Acceptance filter: accept everything (mask = all "don't care").  In
      --  reset mode the data registers are the ACR (0..3) / AMR (4..7) filter.
      for I in 0 .. 3 loop
         Put (I, 0);                   --  acceptance code (don't care anyway)
      end loop;
      for I in 4 .. 7 loop
         Put (I, 16#FF#);              --  acceptance mask: all bits don't-care
      end loop;

      --  Leave reset mode in the requested operating mode.
      TWAI0_Periph.MODE :=
        (RESET_MODE       => False,
         LISTEN_ONLY_MODE => (Mode = Listen_Only),
         SELF_TEST_MODE   => (Mode = Self_Test),
         others           => <>);

      return (Self_Mode => (Mode = Self_Test), Valid => True);
   end Open;

   --------------------
   -- Configure_Pins --
   --------------------

   procedure Configure_Pins
     (B : Bus; Tx : ESP32S3.GPIO.Optional_Pin; Rx : ESP32S3.GPIO.Optional_Pin)
   is
      use type ESP32S3.GPIO.Pad_Number;
   begin
      if not B.Valid then
         return;
      end if;
      if Tx /= G.No_Pin then
         Drive_Out (ESP32S3.GPIO.Pin_Id (Tx), Sigs.TWAI_TX);
      end if;
      if Rx /= G.No_Pin then
         Route_In (Sigs.TWAI_RX, ESP32S3.GPIO.Pin_Id (Rx));
      end if;
   end Configure_Pins;

   ---------------------
   -- Enable_Loopback --
   ---------------------

   procedure Enable_Loopback (B : Bus; Pad : ESP32S3.GPIO.Pin_Id) is
   begin
      if not B.Valid then
         return;
      end if;
      --  TX out and RX in share the matrix index; drive the pad and read it back.
      Drive_Out (Pad, Sigs.TWAI_TX);
      Route_In (Sigs.TWAI_RX, Pad);
   end Enable_Loopback;

   ----------
   -- Send --
   ----------

   procedure Send
     (B                : Bus;
      Extended, Remote : Boolean;
      Id               : Unsigned_32;
      Length           : Data_Length;
      Data             : Data_Bytes)
   is
      --  frame-info byte: FF (bit 7) = extended, RTR (bit 6) = remote, DLC = low 4.
      Info : constant Unsigned_8 :=
        To_Byte
          ((Length => DLC_Field (Length), Reserved => 0, Remote => Remote, Extended => Extended));
      Off  : Natural;                   --  first data byte (after the id bytes)
   begin
      if not B.Valid then
         return;
      end if;
      Put (0, Info);
      if Extended then
         --  29-bit id, big-endian across bytes 1..4 (low 5 bits in byte4[7:3]).
         Put (1, Unsigned_8 (Shift_Right (Id, 21) and 16#FF#));
         Put (2, Unsigned_8 (Shift_Right (Id, 13) and 16#FF#));
         Put (3, Unsigned_8 (Shift_Right (Id, 5) and 16#FF#));
         Put (4, Unsigned_8 (Shift_Left (Id and 16#1F#, 3)));
         Off := 5;
      else
         --  11-bit id in byte1[7:0] + byte2[7:5].
         Put (1, Unsigned_8 (Shift_Right (Id, 3) and 16#FF#));
         Put (2, Unsigned_8 (Shift_Left (Id and 16#7#, 5)));
         Off := 3;
      end if;
      --  A remote frame carries DLC but NO data field on the wire.
      if not Remote then
         for I in 0 .. Length - 1 loop
            Put (Off + I, Data (I));
         end loop;
      end if;

      --  Self-test mode self-receives; normal mode just transmits.
      if B.Self_Mode then
         TWAI0_Periph.CMD := (SELF_RX_REQ => True, others => <>);
      else
         TWAI0_Periph.CMD := (TX_REQ => True, others => <>);
      end if;

      declare
         Wait : Natural := 5_000_000;
      begin
         while not TWAI0_Periph.STATUS.TX_COMPLETE and then Wait > 0 loop
            Wait := Wait - 1;
         end loop;
      end;
   end Send;

   ----------------
   -- RX_Pending --
   ----------------

   function RX_Pending (B : Bus) return Boolean is
      Wait : Natural := 100_000;
   begin
      if not B.Valid then
         return False;
      end if;
      while not TWAI0_Periph.STATUS.RX_BUF_ST and then Wait > 0 loop
         Wait := Wait - 1;
      end loop;
      return TWAI0_Periph.STATUS.RX_BUF_ST;
   end RX_Pending;

   -----------------
   -- RX_Extended --
   -----------------

   function RX_Extended (B : Bus) return Boolean is
   begin
      if not B.Valid or else not TWAI0_Periph.STATUS.RX_BUF_ST then
         return False;
      end if;
      return (Get (0) and 16#80#) /= 0;   --  frame-info FF bit
   end RX_Extended;

   -------------
   -- Receive --
   -------------

   procedure Receive
     (B             : Bus;
      Want_Extended : Boolean;
      Id            : out Unsigned_32;
      Remote        : out Boolean;
      Length        : out Data_Length;
      Data          : out Data_Bytes;
      Got           : out Boolean)
   is
      Wait : Natural := 5_000_000;
      Off  : Natural;
   begin
      Id := 0;
      Remote := False;
      Length := 0;
      Data := (others => 0);
      Got := False;
      if not B.Valid then
         return;
      end if;
      while not TWAI0_Periph.STATUS.RX_BUF_ST and then Wait > 0 loop
         Wait := Wait - 1;
      end loop;
      if not TWAI0_Periph.STATUS.RX_BUF_ST then
         return;                        --  nothing arrived

      end if;

      declare
         FI : constant Frame_Info := To_Info (Get (0));
      begin
         if FI.Extended /= Want_Extended then
            return;                     --  other width: leave it for the matching

         end if;                        --  overload, Got stays False

         Remote := FI.Remote;           --  RTR bit
         --  A CAN DLC of 9 .. 15 is legal on the wire (all mean 8 data bytes);
         --  clamp before the Data_Length (0 .. 8) conversion so a remote node
         --  sending a high DLC does not raise Constraint_Error on receive.
         Length := Data_Length (Natural'Min (8, Natural (FI.Length)));
      end;
      if Want_Extended then
         Id :=
           Shift_Left (Unsigned_32 (Get (1)), 21)
           or Shift_Left (Unsigned_32 (Get (2)), 13)
           or Shift_Left (Unsigned_32 (Get (3)), 5)
           or Shift_Right (Unsigned_32 (Get (4)), 3);
         Off := 5;
      else
         Id := Shift_Left (Unsigned_32 (Get (1)), 3) or Shift_Right (Unsigned_32 (Get (2)), 5);
         Off := 3;
      end if;
      --  A remote frame has no data field; leave Data zeroed.
      if not Remote then
         for I in 0 .. Length - 1 loop
            Data (I) := Get (Off + I);
         end loop;
      end if;
      Got := True;

      TWAI0_Periph.CMD := (RELEASE_BUF => True, others => <>);
   end Receive;

end ESP32S3.TWAI.Engine;
