with Ada.Streams;  use Ada.Streams;
with GNAT.Sockets; use GNAT.Sockets;
with Interfaces;   use Interfaces;

package body Modbus.Slave is

   use type Function_Code;

   ---------------------------------------------------------------------------
   --  Default handlers: a device that doesn't override one doesn't support it.
   ---------------------------------------------------------------------------

   procedure On_Read_Coils
     (Self : in out Server; Unit : Unit_Id; Addr : Address; Qty : Positive;
      Into : out Bit_Array; Status : out Exception_Code) is
   begin
      Into := (Into'Range => False);  Status := Illegal_Function;
   end On_Read_Coils;

   procedure On_Read_Discrete_Inputs
     (Self : in out Server; Unit : Unit_Id; Addr : Address; Qty : Positive;
      Into : out Bit_Array; Status : out Exception_Code) is
   begin
      Into := (Into'Range => False);  Status := Illegal_Function;
   end On_Read_Discrete_Inputs;

   procedure On_Read_Holding_Registers
     (Self : in out Server; Unit : Unit_Id; Addr : Address; Qty : Positive;
      Into : out Word_Array; Status : out Exception_Code) is
   begin
      Into := (Into'Range => 0);  Status := Illegal_Function;
   end On_Read_Holding_Registers;

   procedure On_Read_Input_Registers
     (Self : in out Server; Unit : Unit_Id; Addr : Address; Qty : Positive;
      Into : out Word_Array; Status : out Exception_Code) is
   begin
      Into := (Into'Range => 0);  Status := Illegal_Function;
   end On_Read_Input_Registers;

   procedure On_Write_Single_Coil
     (Self : in out Server; Unit : Unit_Id; Addr : Address; Value : Boolean;
      Status : out Exception_Code) is
   begin
      Status := Illegal_Function;
   end On_Write_Single_Coil;

   procedure On_Write_Single_Register
     (Self : in out Server; Unit : Unit_Id; Addr : Address; Value : Word;
      Status : out Exception_Code) is
   begin
      Status := Illegal_Function;
   end On_Write_Single_Register;

   procedure On_Write_Multiple_Coils
     (Self : in out Server; Unit : Unit_Id; Addr : Address; Values : Bit_Array;
      Status : out Exception_Code) is
   begin
      Status := Illegal_Function;
   end On_Write_Multiple_Coils;

   procedure On_Write_Multiple_Registers
     (Self : in out Server; Unit : Unit_Id; Addr : Address; Values : Word_Array;
      Status : out Exception_Code) is
   begin
      Status := Illegal_Function;
   end On_Write_Multiple_Registers;

   ---------------------------------------------------------------------------
   --  Process one request ADU -> reply ADU (socket-free).
   ---------------------------------------------------------------------------

   procedure Process (Self      : in out Server'Class;
                      Buf       : in out Byte_Array;
                      Req_Len   : Natural;
                      Reply_Len : out Natural)
   is
      TID     : Word;
      Unit    : Unit_Id;
      Length  : Natural;
      FC      : Function_Code;
      PDU_Len : Natural := 0;
      Exc     : Exception_Code := None;
   begin
      Reply_Len := 0;
      if Req_Len < MBAP_Size + 1 then
         return;                                   --  too short -- drop
      end if;
      Get_MBAP (Buf, TID, Unit, Length);
      FC := Function_Code (Buf (MBAP_Size));

      case FC is
         when FC_Read_Coils | FC_Read_Discrete_Inputs =>
            declare
               A   : constant Address := Address (Get_U16 (Buf, 8));
               Qty : constant Natural := Natural (Get_U16 (Buf, 10));
               Bc  : constant Natural := (Qty + 7) / 8;
               B   : Bit_Array (0 .. Natural'Max (Qty, 1) - 1) := (others => False);
            begin
               if Qty not in 1 .. Max_Read_Bits then
                  Exc := Illegal_Data_Value;
               else
                  if FC = FC_Read_Coils then
                     On_Read_Coils (Self, Unit, A, Qty, B, Exc);
                  else
                     On_Read_Discrete_Inputs (Self, Unit, A, Qty, B, Exc);
                  end if;
                  if Exc = None then
                     Buf (MBAP_Size) := Byte (FC);
                     Buf (8) := Byte (Bc);
                     for I in 9 .. 9 + Bc - 1 loop Buf (I) := 0; end loop;
                     for I in 0 .. Qty - 1 loop
                        if B (I) then
                           Buf (9 + I / 8) :=
                             Buf (9 + I / 8) or Byte (2 ** (I mod 8));
                        end if;
                     end loop;
                     PDU_Len := 2 + Bc;
                  end if;
               end if;
            end;

         when FC_Read_Holding_Registers | FC_Read_Input_Registers =>
            declare
               A   : constant Address := Address (Get_U16 (Buf, 8));
               Qty : constant Natural := Natural (Get_U16 (Buf, 10));
               W   : Word_Array (0 .. Natural'Max (Qty, 1) - 1) := (others => 0);
            begin
               if Qty not in 1 .. Max_Read_Registers then
                  Exc := Illegal_Data_Value;
               else
                  if FC = FC_Read_Holding_Registers then
                     On_Read_Holding_Registers (Self, Unit, A, Qty, W, Exc);
                  else
                     On_Read_Input_Registers (Self, Unit, A, Qty, W, Exc);
                  end if;
                  if Exc = None then
                     Buf (MBAP_Size) := Byte (FC);
                     Buf (8) := Byte (2 * Qty);
                     for I in 0 .. Qty - 1 loop Put_U16 (Buf, 9 + 2 * I, W (I)); end loop;
                     PDU_Len := 2 + 2 * Qty;
                  end if;
               end if;
            end;

         when FC_Write_Single_Coil =>
            declare
               A : constant Address := Address (Get_U16 (Buf, 8));
               V : constant Word    := Get_U16 (Buf, 10);
            begin
               if V /= 16#FF00# and then V /= 16#0000# then
                  Exc := Illegal_Data_Value;
               else
                  On_Write_Single_Coil (Self, Unit, A, V = 16#FF00#, Exc);
                  if Exc = None then PDU_Len := 5; end if;   --  echo FC+addr+value
               end if;
            end;

         when FC_Write_Single_Register =>
            declare
               A : constant Address := Address (Get_U16 (Buf, 8));
               V : constant Word    := Get_U16 (Buf, 10);
            begin
               On_Write_Single_Register (Self, Unit, A, V, Exc);
               if Exc = None then PDU_Len := 5; end if;       --  echo FC+addr+value
            end;

         when FC_Write_Multiple_Coils =>
            declare
               A   : constant Address := Address (Get_U16 (Buf, 8));
               Qty : constant Natural := Natural (Get_U16 (Buf, 10));
               Bc  : constant Natural := Natural (Buf (12));
               V   : Bit_Array (0 .. Natural'Max (Qty, 1) - 1) := (others => False);
            begin
               if Qty not in 1 .. Max_Write_Bits or else Bc /= (Qty + 7) / 8 then
                  Exc := Illegal_Data_Value;
               else
                  for I in 0 .. Qty - 1 loop
                     V (I) := (Buf (13 + I / 8) and Byte (2 ** (I mod 8))) /= 0;
                  end loop;
                  On_Write_Multiple_Coils (Self, Unit, A, V, Exc);
                  if Exc = None then PDU_Len := 5; end if;    --  echo FC+addr+qty
               end if;
            end;

         when FC_Write_Multiple_Registers =>
            declare
               A   : constant Address := Address (Get_U16 (Buf, 8));
               Qty : constant Natural := Natural (Get_U16 (Buf, 10));
               Bc  : constant Natural := Natural (Buf (12));
               V   : Word_Array (0 .. Natural'Max (Qty, 1) - 1) := (others => 0);
            begin
               if Qty not in 1 .. Max_Write_Registers or else Bc /= 2 * Qty then
                  Exc := Illegal_Data_Value;
               else
                  for I in 0 .. Qty - 1 loop V (I) := Get_U16 (Buf, 13 + 2 * I); end loop;
                  On_Write_Multiple_Registers (Self, Unit, A, V, Exc);
                  if Exc = None then PDU_Len := 5; end if;    --  echo FC+addr+qty
               end if;
            end;

         when others =>
            Exc := Illegal_Function;
      end case;

      if Exc /= None then
         Buf (MBAP_Size)     := Byte (FC or Exception_Flag);
         Buf (MBAP_Size + 1) := To_Byte (Exc);
         PDU_Len := 2;
      end if;

      Put_MBAP (Buf, TID, Unit, PDU_Len);
      Reply_Len := MBAP_Size + PDU_Len;
   end Process;

   ---------------------------------------------------------------------------
   --  Socket helpers + the serve loop
   ---------------------------------------------------------------------------

   --  Read exactly Count bytes into Buf at Offset.  False on close/error.
   function Recv_Exact (Conn : Socket_Type; Buf : in out Byte_Array;
                        Offset, Count : Natural) return Boolean is
      Got : Natural := 0;
   begin
      while Got < Count loop
         declare
            Chunk : Stream_Element_Array
                      (0 .. Stream_Element_Offset (Count - Got) - 1);
            Last  : Stream_Element_Offset;
         begin
            Receive_Socket (Conn, Chunk, Last);
            if Last < Chunk'First then return False; end if;
            for I in Chunk'First .. Last loop
               Buf (Offset + Got) := Byte (Chunk (I));
               Got := Got + 1;
            end loop;
         end;
      end loop;
      return True;
   exception
      when Socket_Error => return False;
   end Recv_Exact;

   function Send_All (Conn : Socket_Type; Buf : Byte_Array; Count : Natural)
                      return Boolean is
      Data : Stream_Element_Array (0 .. Stream_Element_Offset (Count) - 1);
      Last : Stream_Element_Offset;
      Pos  : Stream_Element_Offset := 0;
   begin
      for I in 0 .. Count - 1 loop
         Data (Stream_Element_Offset (I)) := Stream_Element (Buf (I));
      end loop;
      while Pos <= Data'Last loop
         Send_Socket (Conn, Data (Pos .. Data'Last), Last);
         exit when Last < Pos;
         Pos := Last + 1;
      end loop;
      return Pos > Data'Last;
   exception
      when Socket_Error => return False;
   end Send_All;

   --  Serve requests on one connection until the client closes.
   procedure Serve (Self : in out Server'Class; Conn : Socket_Type) is
      Buf  : Byte_Array (0 .. Max_ADU - 1);
      RLen : Natural;
   begin
      loop
         exit when not Recv_Exact (Conn, Buf, 0, MBAP_Size);
         declare
            Length : constant Natural := Natural (Get_U16 (Buf, 4));
         begin
            exit when Length < 1 or else Length - 1 > Max_PDU;
            exit when not Recv_Exact (Conn, Buf, MBAP_Size, Length - 1);
            Process (Self, Buf, MBAP_Size + (Length - 1), RLen);
            if RLen > 0 then
               exit when not Send_All (Conn, Buf, RLen);
            end if;
         end;
      end loop;
   end Serve;

   procedure Run (Self      : in out Server'Class;
                  Port      : GNAT.Sockets.Port_Type := Default_Port;
                  Configure : Socket_Hook := null)
   is
      Listener, Conn : Socket_Type;
      Peer           : Sock_Addr_Type;
   begin
      loop
         Create_Socket (Listener);
         if Configure /= null then
            Configure (Listener);                  --  e.g. bind/pin to an interface
         end if;
         Bind_Socket (Listener, (Family => Family_Inet,
                                 Addr => Any_Inet_Addr, Port => Port));
         Listen_Socket (Listener);
         Accept_Socket (Listener, Conn, Peer);      --  listener becomes the connection
         begin
            Serve (Self, Conn);
         exception
            when others => null;                    --  one bad client never kills us
         end;
         begin Close_Socket (Conn); exception when others => null; end;
      end loop;
   end Run;

end Modbus.Slave;
