with Ada.Streams;  use Ada.Streams;
with GNAT.Sockets; use GNAT.Sockets;
with Interfaces;   use Interfaces;
with DNS_Client.Parse;
with DNS_Client.Wire;
with ESP32S3.Strings;

package body DNS_Client is

   --  Varies the transaction id from one query to the next so a reply is bound
   --  to the query that asked for it (checked below).  Not cryptographic, but
   --  combined with the source-address/port checks it defeats the trivial
   --  "accept any datagram on the port" cache-poisoning the old fixed id allowed.
   Next_Id : Unsigned_16 := 16#1234#;

   --  Rotates the default source port through the IANA dynamic range, one per
   --  query, for the reasons on the spec: spoofing resistance, and so a retry
   --  is a NEW network flow rather than a refresh of one a NAT has soured on.
   Port_Lo   : constant := 49_664;
   Port_Span : constant := 15_872;   --  49_664 .. 65_535 (NTP_Client rotates below)
   Next_Port : Natural := 0;

   --  A TCP answer may legitimately exceed UDP's practical sizes; accept up
   --  to this much (bounded -- a bigger reply is refused, not truncated).
   Max_TCP_Reply : constant := 2048;

   --  Decimal image of a byte with no leading blank ("84", not " 84").
   function Img (Octet : Unsigned_8) return String
   is (ESP32S3.Strings.Image (Natural (Octet)));

   --  The A record out of a raw reply, as an Inet_Addr_Type; Ok says whether
   --  a well-formed answer to OUR query (Id echo checked) was present.
   procedure Extract
     (Reply : Parse.Byte_Array;
      Id    : Unsigned_16;
      Addr  : out Inet_Addr_Type;
      Ok    : out Boolean)
   is
      Result : constant Parse.A_Record := Parse.Find_A_Record (Reply, Id);
   begin
      if Result.Found then
         Addr :=
           Inet_Addr
             (Img (Result.B0) & "." & Img (Result.B1) & "."
              & Img (Result.B2) & "." & Img (Result.B3));
         Ok := True;
      else
         Addr := Any_Inet_Addr;
         Ok := False;
      end if;
   end Extract;

   ---------------------------------------------------------------------------
   --  UDP: one datagram out, one in.
   ---------------------------------------------------------------------------

   function Resolve
     (Server      : Inet_Addr_Type;
      Name        : String;
      Addr        : out Inet_Addr_Type;
      Timeout     : Duration := 0.0;
      Local_Port  : Port_Type := 0;
      Server_Port : Port_Type := 53) return Boolean
   is
      Sock  : Socket_Type;
      Q_Buf : Wire.Query_Buffer;
      Q_Len : Natural;
      Built : Boolean;
      Resp  : Stream_Element_Array (0 .. 511);
      RLast : Stream_Element_Offset;
      SLast : Stream_Element_Offset;
      To    : aliased Sock_Addr_Type := (Family_Inet, Server, Server_Port);
      From  : Sock_Addr_Type;
      Q_Id  : constant Unsigned_16 := Next_Id;
   begin
      Addr := Any_Inet_Addr;
      Next_Id := Next_Id + 1;             --  advance for the next caller

      if Name'Length > Wire.Max_Name_Length then
         return False;
      end if;
      Wire.Build_A_Query (Name, Q_Id, Q_Buf, Q_Len, Built);
      if not Built then
         return False;
      end if;

      begin
         Create_Socket (Sock, Family_Inet, Socket_Datagram);
      exception
         when Socket_Error =>
            return False;                 --  pool exhausted / no interface
      end;
      begin
         --  Everything that touches the network sits inside the handler:
         --  Bind (opens the datagram socket) and Send (a dead route, an ARP
         --  timeout to the gateway) can raise, and an unhandled Socket_Error
         --  here is a crash, not a failed lookup.
         if Local_Port = 0 then
            Bind_Socket
              (Sock,
               (Family_Inet, Any_Inet_Addr, Port_Type (Port_Lo + Next_Port)));
            Next_Port := (Next_Port + 1) mod Port_Span;
         else
            Bind_Socket (Sock, (Family_Inet, Any_Inet_Addr, Local_Port));
         end if;
         if Timeout > 0.0 then
            Set_Socket_Option (Sock, Socket_Level, (Receive_Timeout, Timeout => Timeout));
         end if;
         declare
            Query : Stream_Element_Array
              (0 .. Stream_Element_Offset (Q_Len) - 1);
         begin
            for I in Query'Range loop
               Query (I) := Stream_Element (Q_Buf (Natural (I)));
            end loop;
            Send_Socket (Sock, Query, SLast, To => To'Access);
         end;
         Receive_Socket (Sock, Resp, RLast, From => From);
      exception
         when Socket_Error =>
            --  no reply within Timeout (or the bind/send itself failed)
            Close_Socket (Sock);
            return False;
      end;

      --  Everything from here closes Sock on the way out (normal, reject, or an
      --  exception from a malformed reply) so the datagram socket never leaks.
      declare
         Found : Boolean := False;
      begin
         --  Reject a datagram that isn't from the server (and port) we asked,
         --  and long enough to hold a DNS header.  (The transaction-id echo is
         --  checked inside the parser, against the untrusted header bytes.)
         if From.Addr /= Server
           or else From.Port /= Server_Port
           or else RLast < Resp'First + 11
         then
            Close_Socket (Sock);
            return False;
         end if;

         --  Copy exactly the received bytes into the parser's bounded buffer
         --  (index 0 .. RLast) and let the SPARK-proven Find_A_Record walk the
         --  answer section -- it cannot overrun or hang on any malformed reply.
         declare
            Received : Parse.Byte_Array (0 .. Natural (RLast));
         begin
            for I in Received'Range loop
               Received (I) := Unsigned_8 (Resp (Stream_Element_Offset (I)));
            end loop;
            Extract (Received, Q_Id, Addr, Found);
         end;

         Close_Socket (Sock);
         return Found;
      exception
         when others =>
            --  any malformed-reply error: don't leak the socket, report failure
            Close_Socket (Sock);
            return False;
      end;
   end Resolve;

   ---------------------------------------------------------------------------
   --  TCP (RFC 7766): the same message bytes behind a two-byte length prefix,
   --  on a connected stream.  Reads are looped -- TCP owes no message
   --  boundaries -- and everything network-facing sits inside handlers.
   ---------------------------------------------------------------------------

   function Resolve_TCP
     (Server      : Inet_Addr_Type;
      Name        : String;
      Addr        : out Inet_Addr_Type;
      Timeout     : Duration := 0.0;
      Server_Port : Port_Type := 53) return Boolean
   is
      Sock  : Socket_Type;
      Q_Buf : Wire.Query_Buffer;
      Q_Len : Natural;
      Built : Boolean;
      Q_Id  : constant Unsigned_16 := Next_Id;

      --  Read exactly Count bytes into Into (Into'First ..), looping over
      --  partial reads.  Ok is False on close or timeout.
      procedure Read_Exactly
        (Into  : out Stream_Element_Array;
         Count : Stream_Element_Offset;
         Ok    : out Boolean)
      is
         Got  : Stream_Element_Offset := 0;
         Last : Stream_Element_Offset;
      begin
         Into := (others => 0);
         Ok := False;
         while Got < Count loop
            Receive_Socket
              (Sock, Into (Into'First + Got .. Into'First + Count - 1), Last);
            exit when Last < Into'First + Got;      --  peer closed
            Got := Last - Into'First + 1;
         end loop;
         Ok := Got >= Count;
      end Read_Exactly;

   begin
      Addr := Any_Inet_Addr;
      Next_Id := Next_Id + 1;

      if Name'Length > Wire.Max_Name_Length then
         return False;
      end if;
      Wire.Build_A_Query (Name, Q_Id, Q_Buf, Q_Len, Built);
      if not Built then
         return False;
      end if;

      begin
         Create_Socket (Sock, Family_Inet, Socket_Stream);
      exception
         when Socket_Error =>
            return False;                 --  pool exhausted / no interface
      end;

      begin
         Connect_Socket (Sock, (Family_Inet, Server, Server_Port));
         if Timeout > 0.0 then
            Set_Socket_Option (Sock, Socket_Level, (Receive_Timeout, Timeout => Timeout));
         end if;

         --  The framed query: two length bytes, then the message.
         declare
            Framed : Stream_Element_Array
              (0 .. Stream_Element_Offset (Q_Len) + 1);
            SLast  : Stream_Element_Offset;
         begin
            Framed (0) := Stream_Element (Q_Len / 256);
            Framed (1) := Stream_Element (Q_Len mod 256);
            for I in 0 .. Q_Len - 1 loop
               Framed (Stream_Element_Offset (I) + 2) :=
                 Stream_Element (Q_Buf (I));
            end loop;
            Send_Socket (Sock, Framed, SLast);
            if SLast < Framed'Last then
               Close_Socket (Sock);
               return False;              --  short send: give up, don't spin
            end if;
         end;

         --  The framed reply: its length, then exactly that many bytes --
         --  bounded, and refused (never truncated) beyond the cap.
         declare
            Len_Bytes : Stream_Element_Array (0 .. 1);
            Reply_Len : Natural;
            Got       : Boolean;
         begin
            Read_Exactly (Len_Bytes, 2, Got);
            if not Got then
               Close_Socket (Sock);
               return False;
            end if;
            Reply_Len :=
              Natural (Len_Bytes (0)) * 256 + Natural (Len_Bytes (1));
            if Reply_Len < 12 or else Reply_Len > Max_TCP_Reply then
               Close_Socket (Sock);
               return False;
            end if;
            declare
               Reply : Stream_Element_Array
                 (0 .. Stream_Element_Offset (Reply_Len) - 1);
               Bytes : Parse.Byte_Array (0 .. Reply_Len - 1);
               Found : Boolean;
            begin
               Read_Exactly (Reply, Stream_Element_Offset (Reply_Len), Got);
               Close_Socket (Sock);
               if not Got then
                  return False;
               end if;
               for I in Bytes'Range loop
                  Bytes (I) := Unsigned_8 (Reply (Stream_Element_Offset (I)));
               end loop;
               Extract (Bytes, Q_Id, Addr, Found);
               return Found;
            end;
         end;
      exception
         when Socket_Error =>
            Close_Socket (Sock);
            return False;
         when others =>
            Close_Socket (Sock);
            return False;
      end;
   end Resolve_TCP;

end DNS_Client;
