with Ada.Streams;  use Ada.Streams;
with GNAT.Sockets; use GNAT.Sockets;
with Interfaces;   use Interfaces;

package body Modbus.Master with SPARK_Mode => On is

   use type Function_Code;

   ---------------------------------------------------------------------------
   --  Pure PDU builders / parsers (SPARK-proven; no session or socket state).
   --  Buf is the ADU scratch buffer, based at 0 and exactly Max_ADU bytes, so
   --  every fixed field offset is in range and 'Length is a static constant --
   --  the base Modbus Byte_Array is array (Natural range <>), whose 'Length is
   --  otherwise unbounded.  The PDU starts at MBAP_Size (= 7).  Each request
   --  builder / reply parser used to be inlined in the socket op below; pulling
   --  it out lets the byte-offset and bit-packing arithmetic be proven free of
   --  overflow and buffer overrun (the Transact/Read_*/Write_* wrappers keep
   --  the socket I/O, outside SPARK).
   ---------------------------------------------------------------------------

   subtype ADU_Buffer is Byte_Array (0 .. Max_ADU - 1);

   --  FC + address + 16-bit quantity/value (the fixed 5-byte read/single-write
   --  request body).
   procedure Build_Read
     (Buf : in out ADU_Buffer; FC : Function_Code; Addr : Address; Qty : Word) is
   begin
      Buf (7) := Byte (FC);
      Put_U16 (Buf, 8, Word (Addr));
      Put_U16 (Buf, 10, Qty);
   end Build_Read;

   procedure Build_Write_Single
     (Buf : in out ADU_Buffer; FC : Function_Code; Addr : Address; Value : Word) is
   begin
      Buf (7) := Byte (FC);
      Put_U16 (Buf, 8, Word (Addr));
      Put_U16 (Buf, 10, Value);
   end Build_Write_Single;

   --  FC 0F write-multiple-coils request body: header + byte count + packed bits.
   procedure Build_Write_Coils
     (Buf : in out ADU_Buffer; Addr : Address; Values : Bit_Array)
   with Pre => Values'Length in 1 .. Max_Write_Bits
   is
      Qty : constant Natural := Values'Length;
      Bc  : constant Natural := (Qty + 7) / 8;   --  <= 246
   begin
      Buf (7) := Byte (FC_Write_Multiple_Coils);
      Put_U16 (Buf, 8, Word (Addr));
      Put_U16 (Buf, 10, Word (Qty));
      Buf (12) := Byte (Bc);
      for I in 0 .. Bc - 1 loop
         Buf (13 + I) := 0;
      end loop;
      for I in 0 .. Qty - 1 loop
         pragma Loop_Invariant (I / 8 <= Bc - 1);
         if Values (Values'First + I) then
            Buf (13 + I / 8) := Buf (13 + I / 8) or Shift_Left (Byte'(1), I mod 8);
         end if;
      end loop;
   end Build_Write_Coils;

   --  FC 10 write-multiple-registers request body: header + byte count + words.
   procedure Build_Write_Regs
     (Buf : in out ADU_Buffer; Addr : Address; Values : Word_Array)
   with Pre => Values'Length in 1 .. Max_Write_Registers
   is
      Qty : constant Natural := Values'Length;
      Bc  : constant Natural := 2 * Qty;   --  <= 246
   begin
      Buf (7) := Byte (FC_Write_Multiple_Registers);
      Put_U16 (Buf, 8, Word (Addr));
      Put_U16 (Buf, 10, Word (Qty));
      Buf (12) := Byte (Bc);
      for I in 0 .. Qty - 1 loop
         Put_U16 (Buf, 13 + 2 * I, Values (Values'First + I));
      end loop;
   end Build_Write_Regs;

   --  Unpack a bit-packed reply (data at offset 9) into the whole of Into, whose
   --  length is the requested Qty (the caller passes the exact destination slice).
   --  Bounding 'Length by membership keeps the unbounded Bit_Array 'Length from
   --  overflowing Integer (the same idiom the Build_* preconditions use), and
   --  looping over Into'Range gives full-initialization coverage.
   procedure Parse_Bits (Buf : ADU_Buffer; Into : out Bit_Array)
   with Pre => Into'Length in 1 .. Max_Read_Bits
   is
   begin
      for J in Into'Range loop
         Into (J) := (Buf (9 + (J - Into'First) / 8)
                      and Shift_Left (Byte'(1), (J - Into'First) mod 8)) /= 0;
      end loop;
   end Parse_Bits;

   --  Unpack a register reply (data at offset 9) into the whole of Into (see
   --  Parse_Bits); Into is the exact Qty-element destination slice.
   procedure Parse_Regs (Buf : ADU_Buffer; Into : out Word_Array)
   with Pre => Into'Length in 1 .. Max_Read_Registers
   is
   begin
      for J in Into'Range loop
         Into (J) := Get_U16 (Buf, 9 + 2 * (J - Into'First));
      end loop;
   end Parse_Regs;

   function Is_Open (S : Session) return Boolean
   is (S.Open);

   procedure Close (S : in out Session) is
      pragma SPARK_Mode (Off);   --  Close_Socket
   begin
      if S.Open then
         begin
            Close_Socket (S.Sock);
         exception
            when others =>
               null;
         end;
         S.Open := False;
      end if;
   end Close;

   ---------------------------------------------------------------------------
   --  Connect
   ---------------------------------------------------------------------------

   procedure Connect
     (S         : in out Session;
      Host      : String;
      Port      : GNAT.Sockets.Port_Type := Default_Port;
      Configure : Socket_Hook := null;
      Timeout   : Duration := 1.0;
      Result    : out Status)
   is
      pragma SPARK_Mode (Off);   --  create/connect socket
   begin
      Create_Socket (S.Sock);
      if Configure /= null then
         Configure (S.Sock);                          --  e.g. pin to an interface

      end if;
      Set_Socket_Option (S.Sock, Socket_Level, (Name => Receive_Timeout, Timeout => Timeout));
      --  Named components: real GNAT.Sockets orders Sock_Addr_Type differently
      --  from our facade, so a positional aggregate would not be portable.
      Connect_Socket (S.Sock, (Family => Family_Inet, Addr => Inet_Addr (Host), Port => Port));
      S.Open := True;
      S.TID := 0;
      Result := OK;
   exception
      when Socket_Error =>
         begin
            Close_Socket (S.Sock);
         exception
            when others =>
               null;
         end;
         S.Open := False;
         Result := Disconnected;
   end Connect;

   ---------------------------------------------------------------------------
   --  Low-level send / receive over S.Buf
   ---------------------------------------------------------------------------

   --  Send Count bytes of S.Buf.  False on a socket error.
   --  Off at the declaration: a function with an "in out" parameter is not legal
   --  SPARK, so it sits entirely outside the analysed subset.
   function Send_All (S : in out Session; Count : Natural) return Boolean
   with SPARK_Mode => Off;

   function Send_All (S : in out Session; Count : Natural) return Boolean
   with SPARK_Mode => Off
   is
      --  View the first Count bytes of S.Buf as a Stream_Element_Array with no
      --  copy: Byte and Stream_Element are both 8-bit, so the layout matches
      --  (same overlay idiom as ESP32S3.W5500.Net_Device).
      Data : Stream_Element_Array (0 .. Stream_Element_Offset (Count) - 1)
      with Import, Address => S.Buf'Address;
      Last : Stream_Element_Offset;
      Pos  : Stream_Element_Offset := 0;
   begin
      while Pos <= Data'Last loop
         Send_Socket (S.Sock, Data (Pos .. Data'Last), Last);
         exit when Last < Pos;
         Pos := Last + 1;
      end loop;
      return Pos > Data'Last;
   exception
      when Socket_Error =>
         return False;
   end Send_All;

   type Recv_Result is (Recv_OK, Recv_Timeout, Recv_Closed);

   --  Read exactly Count bytes into S.Buf starting at Offset.
   --  Off at the declaration for the same "in out" function reason as Send_All.
   function Recv_Exact (S : in out Session; Offset, Count : Natural) return Recv_Result
   with SPARK_Mode => Off;

   function Recv_Exact (S : in out Session; Offset, Count : Natural) return Recv_Result
   with SPARK_Mode => Off
   is
      Got : Natural := 0;
   begin
      while Got < Count loop
         declare
            Chunk : Stream_Element_Array (0 .. Stream_Element_Offset (Count - Got) - 1);
            Last  : Stream_Element_Offset;
         begin
            begin
               Receive_Socket (S.Sock, Chunk, Last);
            exception
               when Socket_Error =>
                  return Recv_Timeout;   --  timeout or error
            end;
            if Last < Chunk'First then
               return Recv_Closed;                          --  peer closed

            end if;
            for I in Chunk'First .. Last loop
               S.Buf (Offset + Got) := Byte (Chunk (I));
               Got := Got + 1;
            end loop;
         end;
      end loop;
      return Recv_OK;
   end Recv_Exact;

   ---------------------------------------------------------------------------
   --  One request/response transaction.  The PDU is already in S.Buf at
   --  MBAP_Size .. MBAP_Size + PDU_Len - 1.  On Result = OK the reply PDU is in
   --  S.Buf from MBAP_Size, Reply_Len bytes; Exc is set on Exception_Response.
   ---------------------------------------------------------------------------
   procedure Transact
     (S         : in out Session;
      Unit      : Unit_Id;
      PDU_Len   : Natural;
      Req_FC    : Function_Code;
      Reply_Len : out Natural;
      Result    : out Status;
      Exc       : out Exception_Code)
   is
      pragma SPARK_Mode (Off);   --  socket send/receive
      Want_TID, Reply_TID : Word;
      Reply_Unit          : Unit_Id;
      Length              : Natural;
   begin
      Exc := None;
      Reply_Len := 0;
      if not S.Open then
         Result := Not_Connected;
         return;
      end if;

      S.TID := S.TID + 1;
      Want_TID := S.TID;
      Put_MBAP (S.Buf, Want_TID, Unit, PDU_Len);

      if not Send_All (S, MBAP_Size + PDU_Len) then
         Close (S);
         Result := Disconnected;
         return;
      end if;

      case Recv_Exact (S, 0, MBAP_Size) is
         --  the reply MBAP

         when Recv_OK      =>
            null;

         when Recv_Timeout =>
            Result := Timed_Out;
            return;

         when Recv_Closed  =>
            Close (S);
            Result := Disconnected;
            return;
      end case;
      Get_MBAP (S.Buf, Reply_TID, Reply_Unit, Length);
      if Length < 1 or else Length - 1 > Max_PDU then
         Result := Malformed_Reply;
         return;
      end if;

      case Recv_Exact (S, MBAP_Size, Length - 1) is
         --  the reply PDU

         when Recv_OK      =>
            null;

         when Recv_Timeout =>
            Result := Timed_Out;
            return;

         when Recv_Closed  =>
            Close (S);
            Result := Disconnected;
            return;
      end case;
      Reply_Len := Length - 1;

      if Reply_TID /= Want_TID then
         Result := Malformed_Reply;
         return;
      end if;

      declare
         Reply_FC : constant Function_Code := Function_Code (S.Buf (MBAP_Size));
      begin
         if Reply_FC = (Req_FC or Exception_Flag) and then Reply_Len >= 2 then
            Exc := To_Exception (S.Buf (MBAP_Size + 1));
            Result := Exception_Response;
         elsif Reply_FC = Req_FC then
            Result := OK;
         else
            Result := Malformed_Reply;
         end if;
      end;
   end Transact;

   ---------------------------------------------------------------------------
   --  Reads
   ---------------------------------------------------------------------------

   --  Shared body for Read_Coils / Read_Discrete_Inputs (bit-packed reply).
   procedure Read_Bits
     (S      : in out Session;
      FC     : Function_Code;
      Unit   : Unit_Id;
      Addr   : Address;
      Qty    : Positive;
      Into   : out Bit_Array;
      Result : out Status;
      Exc    : out Exception_Code)
   is
      pragma SPARK_Mode (Off);   --  wraps the socket Transact
      RLen : Natural;
      Bc   : constant Natural := (Qty + 7) / 8;
   begin
      Build_Read (S.Buf, FC, Addr, Word (Qty));
      Transact (S, Unit, 5, FC, RLen, Result, Exc);
      if Result /= OK then
         return;
      end if;
      if RLen < 2 + Bc or else Natural (S.Buf (8)) /= Bc then
         Result := Malformed_Reply;
         return;
      end if;
      Parse_Bits (S.Buf, Into (Into'First .. Into'First + Qty - 1));
   end Read_Bits;

   --  Shared body for Read_Holding_Registers / Read_Input_Registers.
   procedure Read_Regs
     (S      : in out Session;
      FC     : Function_Code;
      Unit   : Unit_Id;
      Addr   : Address;
      Qty    : Positive;
      Into   : out Word_Array;
      Result : out Status;
      Exc    : out Exception_Code)
   is
      pragma SPARK_Mode (Off);   --  wraps the socket Transact
      RLen : Natural;
      Bc   : constant Natural := 2 * Qty;
   begin
      Build_Read (S.Buf, FC, Addr, Word (Qty));
      Transact (S, Unit, 5, FC, RLen, Result, Exc);
      if Result /= OK then
         return;
      end if;
      if RLen < 2 + Bc or else Natural (S.Buf (8)) /= Bc then
         Result := Malformed_Reply;
         return;
      end if;
      Parse_Regs (S.Buf, Into (Into'First .. Into'First + Qty - 1));
   end Read_Regs;

   procedure Read_Coils
     (S      : in out Session;
      Unit   : Unit_Id;
      Addr   : Address;
      Qty    : Positive;
      Into   : out Bit_Array;
      Result : out Status;
      Exc    : out Exception_Code)
   is
      pragma SPARK_Mode (Off);
   begin
      Read_Bits (S, FC_Read_Coils, Unit, Addr, Qty, Into, Result, Exc);
   end Read_Coils;

   procedure Read_Discrete_Inputs
     (S      : in out Session;
      Unit   : Unit_Id;
      Addr   : Address;
      Qty    : Positive;
      Into   : out Bit_Array;
      Result : out Status;
      Exc    : out Exception_Code)
   is
      pragma SPARK_Mode (Off);
   begin
      Read_Bits (S, FC_Read_Discrete_Inputs, Unit, Addr, Qty, Into, Result, Exc);
   end Read_Discrete_Inputs;

   procedure Read_Holding_Registers
     (S      : in out Session;
      Unit   : Unit_Id;
      Addr   : Address;
      Qty    : Positive;
      Into   : out Word_Array;
      Result : out Status;
      Exc    : out Exception_Code)
   is
      pragma SPARK_Mode (Off);
   begin
      Read_Regs (S, FC_Read_Holding_Registers, Unit, Addr, Qty, Into, Result, Exc);
   end Read_Holding_Registers;

   procedure Read_Input_Registers
     (S      : in out Session;
      Unit   : Unit_Id;
      Addr   : Address;
      Qty    : Positive;
      Into   : out Word_Array;
      Result : out Status;
      Exc    : out Exception_Code)
   is
      pragma SPARK_Mode (Off);
   begin
      Read_Regs (S, FC_Read_Input_Registers, Unit, Addr, Qty, Into, Result, Exc);
   end Read_Input_Registers;

   ---------------------------------------------------------------------------
   --  Writes
   ---------------------------------------------------------------------------

   procedure Write_Single_Coil
     (S      : in out Session;
      Unit   : Unit_Id;
      Addr   : Address;
      Value  : Boolean;
      Result : out Status;
      Exc    : out Exception_Code)
   is
      pragma SPARK_Mode (Off);   --  wraps the socket Transact
      RLen : Natural;
   begin
      Build_Write_Single
        (S.Buf, FC_Write_Single_Coil, Addr,
         (if Value then 16#FF00# else 16#0000#));
      Transact (S, Unit, 5, FC_Write_Single_Coil, RLen, Result, Exc);
   end Write_Single_Coil;

   procedure Write_Single_Register
     (S      : in out Session;
      Unit   : Unit_Id;
      Addr   : Address;
      Value  : Word;
      Result : out Status;
      Exc    : out Exception_Code)
   is
      pragma SPARK_Mode (Off);   --  wraps the socket Transact
      RLen : Natural;
   begin
      Build_Write_Single (S.Buf, FC_Write_Single_Register, Addr, Value);
      Transact (S, Unit, 5, FC_Write_Single_Register, RLen, Result, Exc);
   end Write_Single_Register;

   procedure Write_Multiple_Coils
     (S      : in out Session;
      Unit   : Unit_Id;
      Addr   : Address;
      Values : Bit_Array;
      Result : out Status;
      Exc    : out Exception_Code)
   is
      pragma SPARK_Mode (Off);   --  wraps the socket Transact
      Bc   : constant Natural := (Values'Length + 7) / 8;
      RLen : Natural;
   begin
      Build_Write_Coils (S.Buf, Addr, Values);
      Transact (S, Unit, 6 + Bc, FC_Write_Multiple_Coils, RLen, Result, Exc);
   end Write_Multiple_Coils;

   procedure Write_Multiple_Registers
     (S      : in out Session;
      Unit   : Unit_Id;
      Addr   : Address;
      Values : Word_Array;
      Result : out Status;
      Exc    : out Exception_Code)
   is
      pragma SPARK_Mode (Off);   --  wraps the socket Transact
      Bc   : constant Natural := 2 * Values'Length;
      RLen : Natural;
   begin
      Build_Write_Regs (S.Buf, Addr, Values);
      Transact (S, Unit, 6 + Bc, FC_Write_Multiple_Registers, RLen, Result, Exc);
   end Write_Multiple_Registers;

end Modbus.Master;
