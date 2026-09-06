with Ada.Streams;  use Ada.Streams;
with GNAT.Sockets; use GNAT.Sockets;
with Interfaces;   use Interfaces;

package body Modbus.Slave with SPARK_Mode => On is


   ---------------------------------------------------------------------------
   --  Default handlers: a device that doesn't override one doesn't support it.
   ---------------------------------------------------------------------------

   procedure On_Read_Coils
     (Self   : in out Server;
      Unit   : Unit_Id;
      Addr   : Address;
      Qty    : Positive;
      Into   : out Bit_Array;
      Status : out Exception_Code) is
   begin
      Into := (Into'Range => False);
      Status := Illegal_Function;
   end On_Read_Coils;

   procedure On_Read_Discrete_Inputs
     (Self   : in out Server;
      Unit   : Unit_Id;
      Addr   : Address;
      Qty    : Positive;
      Into   : out Bit_Array;
      Status : out Exception_Code) is
   begin
      Into := (Into'Range => False);
      Status := Illegal_Function;
   end On_Read_Discrete_Inputs;

   procedure On_Read_Holding_Registers
     (Self   : in out Server;
      Unit   : Unit_Id;
      Addr   : Address;
      Qty    : Positive;
      Into   : out Word_Array;
      Status : out Exception_Code) is
   begin
      Into := (Into'Range => 0);
      Status := Illegal_Function;
   end On_Read_Holding_Registers;

   procedure On_Read_Input_Registers
     (Self   : in out Server;
      Unit   : Unit_Id;
      Addr   : Address;
      Qty    : Positive;
      Into   : out Word_Array;
      Status : out Exception_Code) is
   begin
      Into := (Into'Range => 0);
      Status := Illegal_Function;
   end On_Read_Input_Registers;

   procedure On_Write_Single_Coil
     (Self   : in out Server;
      Unit   : Unit_Id;
      Addr   : Address;
      Value  : Boolean;
      Status : out Exception_Code) is
   begin
      Status := Illegal_Function;
   end On_Write_Single_Coil;

   procedure On_Write_Single_Register
     (Self   : in out Server;
      Unit   : Unit_Id;
      Addr   : Address;
      Value  : Word;
      Status : out Exception_Code) is
   begin
      Status := Illegal_Function;
   end On_Write_Single_Register;

   procedure On_Write_Multiple_Coils
     (Self   : in out Server;
      Unit   : Unit_Id;
      Addr   : Address;
      Values : Bit_Array;
      Status : out Exception_Code) is
   begin
      Status := Illegal_Function;
   end On_Write_Multiple_Coils;

   procedure On_Write_Multiple_Registers
     (Self   : in out Server;
      Unit   : Unit_Id;
      Addr   : Address;
      Values : Word_Array;
      Status : out Exception_Code) is
   begin
      Status := Illegal_Function;
   end On_Write_Multiple_Registers;

   --  The request fields every handler needs, decoded once from the MBAP header.
   --  They travel as one record so a handler takes five parameters instead of
   --  seven -- Self, Buf, Req, PDU_Len, Exc -- and so a positional call cannot
   --  transpose Unit and FC.
   type Request is record
      Unit    : Unit_Id;
      FC      : Function_Code;
      Req_Len : Natural;
   end record;


   --  FC 01/02 -- read coils / discrete inputs into a Bit_Array.
   procedure Do_Read_Bits
     (Self    : in out Server'Class;
      Buf     : in out Byte_Array;
      Req     : Request;
      PDU_Len : out Natural;
      Exc     : in out Exception_Code)
   with Pre  => Buf'First = 0 and then Buf'Last = Max_ADU - 1
                and then Req.Req_Len <= Buf'Length,
        --  Every path through a handler sets PDU_Len, so it is `out` rather
        --  than `in out`.  The bound its own Qty check already caps has to be
        --  SAID now that it crosses a call boundary.
        Post => PDU_Len <= Max_PDU
   is
         Addr : constant Address := Address (Get_U16 (Buf, 8));
         --  Read Qty ONLY once the fields are present, and VALIDATE its range
         --  before it is used to size any array -- an attacker-supplied (or
         --  stale, on a short frame) Qty up to 65535 would otherwise allocate
         --  a 65535-element array on the stack and overflow it (a remote DoS
         --  that killed the whole server).
         Qty  : constant Natural :=
           (if Req.Req_Len >= 12 then Natural (Get_U16 (Buf, 10)) else 0);
   begin
      PDU_Len := 0;                 --  no reply unless this handler builds one
      if Req.Req_Len < 12 or else Qty not in 1 .. Max_Read_Bits then
         Exc := Illegal_Data_Value;                --  short frame or bad Qty
         --  A guard clause, not an else: the else this replaces put the
         --  whole decode one level deeper for no gain.
         return;
      end if;

      declare
         Bc   : constant Natural := (Qty + 7) / 8;   --  byte count; Qty bounded now
         Bits : Bit_Array (0 .. Qty - 1) := (others => False);
      begin
         if Req.FC = FC_Read_Coils then
            On_Read_Coils (Self, Req.Unit, Addr, Qty, Bits, Exc);
         else
            On_Read_Discrete_Inputs (Self, Req.Unit, Addr, Qty, Bits, Exc);
         end if;
         if Exc = None then
            Buf (MBAP_Size) := Byte (Req.FC);
            Buf (8) := Byte (Bc);
            for I in 9 .. 9 + Bc - 1 loop
               Buf (I) := 0;
            end loop;
            for I in 0 .. Qty - 1 loop
               if Bits (I) then
                  Buf (9 + I / 8) :=
                    Buf (9 + I / 8) or Shift_Left (Byte'(1), I mod 8);
               end if;
            end loop;
            PDU_Len := 2 + Bc;
         end if;
      end;
   end Do_Read_Bits;

   --  FC 03/04 -- read holding / input registers into a Word_Array.
   procedure Do_Read_Registers
     (Self    : in out Server'Class;
      Buf     : in out Byte_Array;
      Req     : Request;
      PDU_Len : out Natural;
      Exc     : in out Exception_Code)
   with Pre  => Buf'First = 0 and then Buf'Last = Max_ADU - 1
                and then Req.Req_Len <= Buf'Length,
        --  Every path through a handler sets PDU_Len, so it is `out` rather
        --  than `in out`.  The bound its own Qty check already caps has to be
        --  SAID now that it crosses a call boundary.
        Post => PDU_Len <= Max_PDU
   is
         Addr : constant Address := Address (Get_U16 (Buf, 8));
         Qty  : constant Natural :=            --  validate before sizing (see above)
           (if Req.Req_Len >= 12 then Natural (Get_U16 (Buf, 10)) else 0);
   begin
      PDU_Len := 0;                 --  no reply unless this handler builds one
      if Req.Req_Len < 12 or else Qty not in 1 .. Max_Read_Registers then
         Exc := Illegal_Data_Value;                --  short frame or bad Qty
         --  A guard clause, not an else: the else this replaces put the
         --  whole decode one level deeper for no gain.
         return;
      end if;

      declare
         Words : Word_Array (0 .. Qty - 1) := (others => 0);   --  Qty bounded
      begin
         if Req.FC = FC_Read_Holding_Registers then
            On_Read_Holding_Registers (Self, Req.Unit, Addr, Qty, Words, Exc);
         else
            On_Read_Input_Registers (Self, Req.Unit, Addr, Qty, Words, Exc);
         end if;
         if Exc = None then
            Buf (MBAP_Size) := Byte (Req.FC);
            Buf (8) := Byte (2 * Qty);
            for I in 0 .. Qty - 1 loop
               Put_U16 (Buf, 9 + 2 * I, Words (I));
            end loop;
            PDU_Len := 2 + 2 * Qty;
         end if;
      end;
   end Do_Read_Registers;

   --  FC 05 -- write one coil; the reply echoes the request.
   procedure Do_Write_Single_Coil
     (Self    : in out Server'Class;
      --  Read-only: a write request's reply is the request echoed back, so
      --  these handlers never touch Buf -- only the read handlers build a
      --  payload into it.
      Buf     : Byte_Array;
      Req     : Request;
      PDU_Len : out Natural;
      Exc     : in out Exception_Code)
   with Pre  => Buf'First = 0 and then Buf'Last = Max_ADU - 1
                and then Req.Req_Len <= Buf'Length,
        --  Every path through a handler sets PDU_Len, so it is `out` rather
        --  than `in out`.  The bound its own Qty check already caps has to be
        --  SAID now that it crosses a call boundary.
        Post => PDU_Len <= Max_PDU
   is
         Addr  : constant Address := Address (Get_U16 (Buf, 8));
         Value : constant Word := Get_U16 (Buf, 10);
   begin
      PDU_Len := 0;                 --  no reply unless this handler builds one
         if Req.Req_Len < 12 or else (Value /= 16#FF00# and then Value /= 16#0000#) then
            Exc := Illegal_Data_Value;                --  short frame or bad value

         else
            On_Write_Single_Coil (Self, Req.Unit, Addr, Value = 16#FF00#, Exc);
            if Exc = None then
               PDU_Len := 5;
            end if;   --  echo Req.FC+addr+value
         end if;
   end Do_Write_Single_Coil;

   --  FC 06 -- write one register; the reply echoes the request.
   procedure Do_Write_Single_Register
     (Self    : in out Server'Class;
      --  Read-only: a write request's reply is the request echoed back, so
      --  these handlers never touch Buf -- only the read handlers build a
      --  payload into it.
      Buf     : Byte_Array;
      Req     : Request;
      PDU_Len : out Natural;
      Exc     : in out Exception_Code)
   with Pre  => Buf'First = 0 and then Buf'Last = Max_ADU - 1
                and then Req.Req_Len <= Buf'Length,
        --  Every path through a handler sets PDU_Len, so it is `out` rather
        --  than `in out`.  The bound its own Qty check already caps has to be
        --  SAID now that it crosses a call boundary.
        Post => PDU_Len <= Max_PDU
   is
         Addr  : constant Address := Address (Get_U16 (Buf, 8));
         Value : constant Word := Get_U16 (Buf, 10);
   begin
      PDU_Len := 0;                 --  no reply unless this handler builds one
         if Req.Req_Len < 12 then
            Exc := Illegal_Data_Value;                --  short frame

         else
            On_Write_Single_Register (Self, Req.Unit, Addr, Value, Exc);
            if Exc = None then
               PDU_Len := 5;
            end if;    --  echo Req.FC+addr+value
         end if;
   end Do_Write_Single_Register;

   --  FC 15 -- write a run of coils.
   procedure Do_Write_Multiple_Coils
     (Self    : in out Server'Class;
      --  Read-only: a write request's reply is the request echoed back, so
      --  these handlers never touch Buf -- only the read handlers build a
      --  payload into it.
      Buf     : Byte_Array;
      Req     : Request;
      PDU_Len : out Natural;
      Exc     : in out Exception_Code)
   with Pre  => Buf'First = 0 and then Buf'Last = Max_ADU - 1
                and then Req.Req_Len <= Buf'Length,
        --  Every path through a handler sets PDU_Len, so it is `out` rather
        --  than `in out`.  The bound its own Qty check already caps has to be
        --  SAID now that it crosses a call boundary.
        Post => PDU_Len <= Max_PDU
   is
         Addr : constant Address := Address (Get_U16 (Buf, 8));
         Qty  : constant Natural :=            --  guard reads; validate before sizing
           (if Req.Req_Len >= 12 then Natural (Get_U16 (Buf, 10)) else 0);
         Bc   : constant Natural :=            --  byte count
           (if Req.Req_Len >= 13 then Natural (Buf (12)) else 0);
   begin
      PDU_Len := 0;                 --  no reply unless this handler builds one
         if Req.Req_Len < 13 + Bc                          --  header+byte-count+data
           or else Qty not in 1 .. Max_Write_Bits
           or else Bc /= (Qty + 7) / 8
         then
            Exc := Illegal_Data_Value;
         else
            declare
               Values : Bit_Array (0 .. Qty - 1) := (others => False);
            begin
               for I in 0 .. Qty - 1 loop
                  Values (I) := (Buf (13 + I / 8) and Shift_Left (Byte'(1), I mod 8)) /= 0;
               end loop;
               On_Write_Multiple_Coils (Self, Req.Unit, Addr, Values, Exc);
               if Exc = None then
                  PDU_Len := 5;
               end if;    --  echo Req.FC+addr+qty
            end;
         end if;
   end Do_Write_Multiple_Coils;

   --  FC 16 -- write a run of registers.
   procedure Do_Write_Multiple_Registers
     (Self    : in out Server'Class;
      --  Read-only: a write request's reply is the request echoed back, so
      --  these handlers never touch Buf -- only the read handlers build a
      --  payload into it.
      Buf     : Byte_Array;
      Req     : Request;
      PDU_Len : out Natural;
      Exc     : in out Exception_Code)
   with Pre  => Buf'First = 0 and then Buf'Last = Max_ADU - 1
                and then Req.Req_Len <= Buf'Length,
        --  Every path through a handler sets PDU_Len, so it is `out` rather
        --  than `in out`.  The bound its own Qty check already caps has to be
        --  SAID now that it crosses a call boundary.
        Post => PDU_Len <= Max_PDU
   is
         Addr : constant Address := Address (Get_U16 (Buf, 8));
         Qty  : constant Natural :=            --  guard reads; validate before sizing
           (if Req.Req_Len >= 12 then Natural (Get_U16 (Buf, 10)) else 0);
         Bc   : constant Natural :=            --  byte count
           (if Req.Req_Len >= 13 then Natural (Buf (12)) else 0);
   begin
      PDU_Len := 0;                 --  no reply unless this handler builds one
         if Req.Req_Len < 13 + Bc                          --  header+byte-count+data
           or else Qty not in 1 .. Max_Write_Registers
           or else Bc /= 2 * Qty
         then
            Exc := Illegal_Data_Value;
         else
            declare
               Values : Word_Array (0 .. Qty - 1) := (others => 0);
            begin
               for I in 0 .. Qty - 1 loop
                  Values (I) := Get_U16 (Buf, 13 + 2 * I);
               end loop;
               On_Write_Multiple_Registers (Self, Req.Unit, Addr, Values, Exc);
               if Exc = None then
                  PDU_Len := 5;
               end if;    --  echo Req.FC+addr+qty
            end;
         end if;
   end Do_Write_Multiple_Registers;

   ---------------------------------------------------------------------------
   --  Process one request ADU -> reply ADU (socket-free).
   ---------------------------------------------------------------------------

   procedure Process
     (Self      : in out Server'Class;
      Buf       : in out Byte_Array;
      Req_Len   : Natural;
      Reply_Len : out Natural)
   is
      TID     : Word;                 --  MBAP transaction id (protocol field)
      Unit    : Unit_Id;
      Length  : Natural;
      FC      : Function_Code;        --  request function code (protocol field)
      PDU_Len : Natural := 0;
      Exc     : Exception_Code := None;
   begin
      Reply_Len := 0;
      if Req_Len < MBAP_Size + 1 then
         return;                                   --  too short -- drop

      end if;
      Get_MBAP (Buf, TID, Unit, Length);
      FC := Function_Code (Buf (MBAP_Size));

      declare
         Req : constant Request := (Unit => Unit, FC => FC, Req_Len => Req_Len);
      begin
         case FC is
            when FC_Read_Coils | FC_Read_Discrete_Inputs             =>
               Do_Read_Bits (Self, Buf, Req, PDU_Len, Exc);
            when FC_Read_Holding_Registers | FC_Read_Input_Registers =>
               Do_Read_Registers (Self, Buf, Req, PDU_Len, Exc);
            when FC_Write_Single_Coil                                =>
               Do_Write_Single_Coil (Self, Buf, Req, PDU_Len, Exc);
            when FC_Write_Single_Register                            =>
               Do_Write_Single_Register (Self, Buf, Req, PDU_Len, Exc);
            when FC_Write_Multiple_Coils                             =>
               Do_Write_Multiple_Coils (Self, Buf, Req, PDU_Len, Exc);
            when FC_Write_Multiple_Registers                         =>
               Do_Write_Multiple_Registers (Self, Buf, Req, PDU_Len, Exc);
            when others                                              =>
               Exc := Illegal_Function;
         end case;
      end;

      if Exc /= None then
         Buf (MBAP_Size) := Byte (FC or Exception_Flag);
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
   --  Off at the declaration: a function with an "in out" parameter is not legal
   --  SPARK, so it must sit entirely outside the analysed subset.
   function Recv_Exact
     (Conn : Socket_Type; Buf : in out Byte_Array; Offset, Count : Natural) return Boolean
   with SPARK_Mode => Off;

   function Recv_Exact
     (Conn : Socket_Type; Buf : in out Byte_Array; Offset, Count : Natural) return Boolean
   with SPARK_Mode => Off
   is
      Got : Natural := 0;
   begin
      while Got < Count loop
         declare
            Chunk : Stream_Element_Array (0 .. Stream_Element_Offset (Count - Got) - 1);
            Last  : Stream_Element_Offset;
         begin
            Receive_Socket (Conn, Chunk, Last);
            if Last < Chunk'First then
               return False;
            end if;
            for I in Chunk'First .. Last loop
               Buf (Offset + Got) := Byte (Chunk (I));
               Got := Got + 1;
            end loop;
         end;
      end loop;
      return True;
   exception
      when Socket_Error =>
         return False;
   end Recv_Exact;

   function Send_All (Conn : Socket_Type; Buf : Byte_Array; Count : Natural) return Boolean is
      pragma SPARK_Mode (Off);   --  Send_Socket + address overlay
      --  View the first Count bytes of Buf as a Stream_Element_Array with no
      --  copy: Byte and Stream_Element are both 8-bit, so the layout matches
      --  (same overlay idiom as ESP32S3.W5500.Net_Device).
      Data : Stream_Element_Array (0 .. Stream_Element_Offset (Count) - 1)
      with Import, Address => Buf'Address;
      Last : Stream_Element_Offset;
      Pos  : Stream_Element_Offset := 0;
   begin
      while Pos <= Data'Last loop
         Send_Socket (Conn, Data (Pos .. Data'Last), Last);
         exit when Last < Pos;
         Pos := Last + 1;
      end loop;
      return Pos > Data'Last;
   exception
      when Socket_Error =>
         return False;
   end Send_All;

   --  Serve requests on one connection until the client closes.
   procedure Serve (Self : in out Server'Class; Conn : Socket_Type) is
      pragma SPARK_Mode (Off);   --  socket recv/send loop
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

   procedure Run
     (Self      : in out Server'Class;
      Port      : GNAT.Sockets.Port_Type := Default_Port;
      Configure : Socket_Hook := null)
   is
      pragma SPARK_Mode (Off);   --  create/bind/listen/accept
      Listener, Conn : Socket_Type;
      Peer           : Sock_Addr_Type;
   begin
      loop
         Create_Socket (Listener);
         if Configure /= null then
            Configure (Listener);                  --  e.g. bind/pin to an interface

         end if;
         Bind_Socket (Listener, (Family => Family_Inet, Addr => Any_Inet_Addr, Port => Port));
         Listen_Socket (Listener);
         Accept_Socket (Listener, Conn, Peer);      --  listener becomes the connection
         begin
            Serve (Self, Conn);
         exception
            when others =>
               null;                    --  one bad client never kills us
         end;
         begin
            Close_Socket (Conn);
         exception
            when others =>
               null;
         end;
      end loop;
   end Run;

end Modbus.Slave;
