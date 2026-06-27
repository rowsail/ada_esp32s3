with GNAT.Sockets;

--  Modbus TCP slave (server).  This library owns NO register storage: you derive
--  from Server, keep your data in your own type, and override the operations you
--  support.  The ones you don't override default to returning Illegal_Function, so
--  a device implements only what it offers.  Each handler returns None on success
--  or a Modbus Exception_Code (e.g. Illegal_Data_Address); the server turns that
--  into the proper exception reply.  Serves one client at a time.
package Modbus.Slave is

   type Server is tagged limited private;

   ---------------------------------------------------------------------------
   --  Override the handlers your device supports.  Self carries your storage.
   --  For reads, fill the first Qty elements of Into.  For writes, apply Values.
   ---------------------------------------------------------------------------
   procedure On_Read_Coils
     (Self : in out Server; Unit : Unit_Id; Addr : Address; Qty : Positive;
      Into : out Bit_Array; Status : out Exception_Code);
   procedure On_Read_Discrete_Inputs
     (Self : in out Server; Unit : Unit_Id; Addr : Address; Qty : Positive;
      Into : out Bit_Array; Status : out Exception_Code);
   procedure On_Read_Holding_Registers
     (Self : in out Server; Unit : Unit_Id; Addr : Address; Qty : Positive;
      Into : out Word_Array; Status : out Exception_Code);
   procedure On_Read_Input_Registers
     (Self : in out Server; Unit : Unit_Id; Addr : Address; Qty : Positive;
      Into : out Word_Array; Status : out Exception_Code);

   procedure On_Write_Single_Coil
     (Self : in out Server; Unit : Unit_Id; Addr : Address; Value : Boolean;
      Status : out Exception_Code);
   procedure On_Write_Single_Register
     (Self : in out Server; Unit : Unit_Id; Addr : Address; Value : Word;
      Status : out Exception_Code);
   procedure On_Write_Multiple_Coils
     (Self : in out Server; Unit : Unit_Id; Addr : Address; Values : Bit_Array;
      Status : out Exception_Code);
   procedure On_Write_Multiple_Registers
     (Self : in out Server; Unit : Unit_Id; Addr : Address; Values : Word_Array;
      Status : out Exception_Code);

   ---------------------------------------------------------------------------
   --  Serve.  Optional Configure hook on the LISTENER (e.g. bind it to one
   --  interface's address to pin the slave).  Run blocks forever, one client at a
   --  time.  Needs the embedded/full profile.
   ---------------------------------------------------------------------------
   type Socket_Hook is access procedure
     (Socket : in out GNAT.Sockets.Socket_Type);

   procedure Run (Self      : in out Server'Class;
                  Port      : GNAT.Sockets.Port_Type := Default_Port;
                  Configure : Socket_Hook := null);

   --  Process ONE request ADU in Buf (0 .. Req_Len - 1), dispatching to Self, and
   --  build the reply ADU into Buf, returning its length (0 = drop, no reply).
   --  Socket-free, so the whole framing/dispatch/exception path is host-testable;
   --  Run is just a socket loop around this.
   procedure Process (Self      : in out Server'Class;
                      Buf       : in out Byte_Array;
                      Req_Len   : Natural;
                      Reply_Len : out Natural);

private
   type Server is tagged limited null record;
end Modbus.Slave;
