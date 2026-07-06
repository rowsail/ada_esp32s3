with Interfaces;

--  Modbus TCP -- shared types and wire helpers for the master (client,
--  Modbus.Master) and slave (server, Modbus.Slave).  Modbus is big-endian on the
--  wire.  Its data model is four tables -- coils (1-bit RW), discrete inputs
--  (1-bit RO), holding registers (16-bit RW), input registers (16-bit RO) -- but
--  THIS library never stores them: the application owns the data (the master fills
--  caller buffers; the slave overrides Modbus.Slave.Server).
--
--  Written against the GNAT.Sockets facade, so the same source runs on a desktop
--  (host-tested against a Python peer) and on the bare-metal W5500.

package Modbus is

   subtype Byte is Interfaces.Unsigned_8;
   type Byte_Array is array (Natural range <>) of Byte;

   subtype Word is Interfaces.Unsigned_16;       --  one 16-bit register
   type Word_Array is array (Natural range <>) of Word;
   type Bit_Array is array (Natural range <>) of Boolean;

   subtype Address is Interfaces.Unsigned_16;    --  0 .. 65535
   subtype Unit_Id is Interfaces.Unsigned_8;     --  slave / unit identifier

   Default_Port : constant := 502;

   --  Per-spec maximum quantity in one request.
   Max_Read_Bits       : constant := 2000;       --  FC 01 / 02
   Max_Read_Registers  : constant := 125;        --  FC 03 / 04
   Max_Write_Bits      : constant := 1968;       --  FC 0F
   Max_Write_Registers : constant := 123;        --  FC 10

   --  An ADU is at most MBAP (7) + PDU (253) bytes.
   MBAP_Size : constant := 7;
   Max_PDU   : constant := 253;
   Max_ADU   : constant := MBAP_Size + Max_PDU;  --  260

   --  Function codes.
   type Function_Code is new Interfaces.Unsigned_8;
   FC_Read_Coils               : constant Function_Code := 16#01#;
   FC_Read_Discrete_Inputs     : constant Function_Code := 16#02#;
   FC_Read_Holding_Registers   : constant Function_Code := 16#03#;
   FC_Read_Input_Registers     : constant Function_Code := 16#04#;
   FC_Write_Single_Coil        : constant Function_Code := 16#05#;
   FC_Write_Single_Register    : constant Function_Code := 16#06#;
   FC_Write_Multiple_Coils     : constant Function_Code := 16#0F#;
   FC_Write_Multiple_Registers : constant Function_Code := 16#10#;
   Exception_Flag              : constant Function_Code := 16#80#;  --  OR'd in an error reply

   --  Modbus exception codes; None means "no exception / success".
   type Exception_Code is
     (None,
      Illegal_Function,
      Illegal_Data_Address,
      Illegal_Data_Value,
      Slave_Device_Failure,
      Acknowledge,
      Slave_Device_Busy,
      Memory_Parity_Error,
      Gateway_Path_Unavailable,
      Gateway_Target_Failed_To_Respond);

   function To_Byte (E : Exception_Code) return Byte;
   function To_Exception (B : Byte) return Exception_Code;   --  unknown -> Slave_Device_Failure

   ---------------------------------------------------------------------------
   --  Wire helpers (big-endian).  Pos is the index of the high byte.
   ---------------------------------------------------------------------------
   function Get_U16 (B : Byte_Array; Pos : Natural) return Word
   with Pre => Pos >= B'First and then Pos < B'Last;
   procedure Put_U16 (B : in out Byte_Array; Pos : Natural; V : Word)
   with Pre => Pos >= B'First and then Pos < B'Last;

   --  MBAP header: Transaction Id, Protocol Id (0), Length, Unit Id.  PDU_Len is
   --  the count of PDU bytes that follow; the Length field is PDU_Len + 1 (it
   --  covers the Unit byte too).  B must have room for MBAP_Size bytes from B'First.
   procedure Put_MBAP (B : in out Byte_Array; TID : Word; Unit : Unit_Id; PDU_Len : Natural)
   with Pre => B'Length >= MBAP_Size;

   --  Parse an MBAP header.  Length is the raw Length field (Unit + PDU bytes), so
   --  the PDU is Length - 1 bytes.
   procedure Get_MBAP (B : Byte_Array; TID : out Word; Unit : out Unit_Id; Length : out Natural)
   with Pre => B'Length >= MBAP_Size;

end Modbus;
