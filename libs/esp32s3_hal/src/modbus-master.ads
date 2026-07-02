with GNAT.Sockets;

--  Modbus TCP master (client).  Synchronous: each call sends a request and waits
--  for the reply, returning data into a caller buffer plus a Status (and, for a
--  Modbus exception reply, an Exception_Code).  A Modbus exception is a normal
--  outcome reported through Status -- not an Ada exception; Ada exceptions are
--  reserved for caller bugs (the Pre contracts on quantity / buffer size).

package Modbus.Master is

   type Session is limited private;

   type Status is
     (OK,                  --  reply received, no Modbus exception
      Exception_Response,  --  slave returned a Modbus exception (see Exc)
      Timed_Out,           --  no reply within the timeout
      Disconnected,        --  connection closed or failed
      Malformed_Reply,     --  unparseable / TID mismatch / wrong function code
      Not_Connected);      --  the session is not open

   --  Optional hook called on the freshly-created socket, before connect -- e.g.
   --  to PIN it to an interface (GNAT.Sockets.Set_Interface) or set other options.
   --  Must be library-level and closure-free (bare-metal callback rules).  Left
   --  null, the socket routes normally.  Keeping the pin out here (rather than a
   --  facade-only parameter) lets the same source be host-tested; the board example
   --  esp32s3_modbus_master shows a one-line pin hook.
   type Socket_Hook is access procedure (Socket : in out GNAT.Sockets.Socket_Type);

   --  Open a TCP connection to a slave at dotted-decimal Host:Port.  Timeout caps
   --  how long each transaction waits for a reply.  Result is OK or Disconnected.
   procedure Connect
     (S         : in out Session;
      Host      : String;
      Port      : GNAT.Sockets.Port_Type := Default_Port;
      Configure : Socket_Hook := null;
      Timeout   : Duration := 1.0;
      Result    : out Status);

   procedure Close (S : in out Session);
   function Is_Open (S : Session) return Boolean;

   ---------------------------------------------------------------------------
   --  Reads -- Into must hold at least Qty elements; on Result = OK the first
   --  Qty are filled.
   ---------------------------------------------------------------------------
   procedure Read_Coils
     (S      : in out Session;
      Unit   : Unit_Id;
      Addr   : Address;
      Qty    : Positive;
      Into   : out Bit_Array;
      Result : out Status;
      Exc    : out Exception_Code)
   with Pre => Qty <= Max_Read_Bits and then Into'Length >= Qty;

   procedure Read_Discrete_Inputs
     (S      : in out Session;
      Unit   : Unit_Id;
      Addr   : Address;
      Qty    : Positive;
      Into   : out Bit_Array;
      Result : out Status;
      Exc    : out Exception_Code)
   with Pre => Qty <= Max_Read_Bits and then Into'Length >= Qty;

   procedure Read_Holding_Registers
     (S      : in out Session;
      Unit   : Unit_Id;
      Addr   : Address;
      Qty    : Positive;
      Into   : out Word_Array;
      Result : out Status;
      Exc    : out Exception_Code)
   with Pre => Qty <= Max_Read_Registers and then Into'Length >= Qty;

   procedure Read_Input_Registers
     (S      : in out Session;
      Unit   : Unit_Id;
      Addr   : Address;
      Qty    : Positive;
      Into   : out Word_Array;
      Result : out Status;
      Exc    : out Exception_Code)
   with Pre => Qty <= Max_Read_Registers and then Into'Length >= Qty;

   ---------------------------------------------------------------------------
   --  Writes.
   ---------------------------------------------------------------------------
   procedure Write_Single_Coil
     (S      : in out Session;
      Unit   : Unit_Id;
      Addr   : Address;
      Value  : Boolean;
      Result : out Status;
      Exc    : out Exception_Code);

   procedure Write_Single_Register
     (S      : in out Session;
      Unit   : Unit_Id;
      Addr   : Address;
      Value  : Word;
      Result : out Status;
      Exc    : out Exception_Code);

   procedure Write_Multiple_Coils
     (S      : in out Session;
      Unit   : Unit_Id;
      Addr   : Address;
      Values : Bit_Array;
      Result : out Status;
      Exc    : out Exception_Code)
   with Pre => Values'Length in 1 .. Max_Write_Bits;

   procedure Write_Multiple_Registers
     (S      : in out Session;
      Unit   : Unit_Id;
      Addr   : Address;
      Values : Word_Array;
      Result : out Status;
      Exc    : out Exception_Code)
   with Pre => Values'Length in 1 .. Max_Write_Registers;

private
   type Session is limited record
      Sock : GNAT.Sockets.Socket_Type;
      Open : Boolean := False;
      TID  : Word := 0;                          --  bumped per request
      Buf  : Byte_Array (0 .. Max_ADU - 1) := (others => 0);
   end record;
end Modbus.Master;
