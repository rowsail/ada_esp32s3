with Ada.Streams;  use Ada.Streams;
with GNAT.Sockets; use GNAT.Sockets;
with Interfaces;   use Interfaces;
with DNS_Client.Parse;
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

   function Resolve
     (Server      : Inet_Addr_Type;
      Name        : String;
      Addr        : out Inet_Addr_Type;
      Timeout     : Duration := 0.0;
      Local_Port  : Port_Type := 0;
      Server_Port : Port_Type := 53) return Boolean
   is
      Sock  : Socket_Type;
      Query : Stream_Element_Array (0 .. 511);
      QLen  : Stream_Element_Offset := 0;
      Resp  : Stream_Element_Array (0 .. 511);
      RLast : Stream_Element_Offset;
      SLast : Stream_Element_Offset;
      To    : aliased Sock_Addr_Type := (Family_Inet, Server, Server_Port);
      From  : aliased Sock_Addr_Type;
      Q_Id  : constant Unsigned_16 := Next_Id;

      --  Decimal image of a byte with no leading blank ("84", not " 84").
      function Img (Octet : Unsigned_8) return String
      is (ESP32S3.Strings.Image (Natural (Octet)));

      --  Build a standard recursive A-record query for Name into Query.
      procedure Build_Query is
         Pos   : Stream_Element_Offset := Query'First;
         Start : Natural;
         procedure B (Value : Integer) is
         begin
            Query (Pos) := Stream_Element (Value);
            Pos := Pos + 1;
         end B;
      begin
         B (Integer (Shift_Right (Q_Id, 8)));
         B (Integer (Q_Id and 16#FF#));   --  ID (this query's)
         B (16#01#);
         B (16#00#);          --  flags: standard query, recursion desired
         B (0);
         B (1);                    --  QDCOUNT = 1
         B (0);
         B (0);
         B (0);
         B (0);
         B (0);
         B (0);   --  AN/NS/AR = 0
         Start := Name'First;             --  QNAME as length-prefixed labels
         for I in Name'First .. Name'Last + 1 loop
            if I > Name'Last or else Name (I) = '.' then
               B (I - Start);
               for J in Start .. I - 1 loop
                  B (Character'Pos (Name (J)));
               end loop;
               Start := I + 1;
            end if;
         end loop;
         B (0);                           --  end of name
         B (0);
         B (1);                    --  QTYPE  = A
         B (0);
         B (1);                    --  QCLASS = IN
         QLen := Pos - Query'First;
      end Build_Query;

   begin
      Addr := Any_Inet_Addr;
      Next_Id := Next_Id + 1;             --  advance for the next caller
      Build_Query;
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
         Send_Socket (Sock, Query (Query'First .. QLen - 1), SLast, To => To'Access);
         Receive_Socket (Sock, Resp, RLast, From => From'Access);
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
            Received : DNS_Client.Parse.Byte_Array (0 .. Natural (RLast));
            Result   : DNS_Client.Parse.A_Record;
         begin
            for I in Received'Range loop
               Received (I) := Unsigned_8 (Resp (Stream_Element_Offset (I)));
            end loop;
            Result := DNS_Client.Parse.Find_A_Record (Received, Q_Id);
            if Result.Found then
               Addr :=
                 Inet_Addr
                   (Img (Result.B0)
                    & "."
                    & Img (Result.B1)
                    & "."
                    & Img (Result.B2)
                    & "."
                    & Img (Result.B3));
               Found := True;
            end if;
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

end DNS_Client;
