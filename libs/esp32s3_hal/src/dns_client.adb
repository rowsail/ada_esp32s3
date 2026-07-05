with Ada.Streams;  use Ada.Streams;
with GNAT.Sockets; use GNAT.Sockets;
with Interfaces;   use Interfaces;
with ESP32S3.Endian;

package body DNS_Client is

   --  Varies the transaction id from one query to the next so a reply is bound
   --  to the query that asked for it (checked below).  Not cryptographic, but
   --  combined with the source-address/port checks it defeats the trivial
   --  "accept any datagram on the port" cache-poisoning the old fixed id allowed.
   Next_Id : Unsigned_16 := 16#1234#;

   function Resolve
     (Server     : Inet_Addr_Type;
      Name       : String;
      Addr       : out Inet_Addr_Type;
      Timeout    : Duration := 0.0;
      Local_Port : Port_Type := 13_001) return Boolean
   is
      Sock  : Socket_Type;
      Query : Stream_Element_Array (0 .. 511);
      QLen  : Stream_Element_Offset := 0;
      Resp  : Stream_Element_Array (0 .. 511);
      RLast : Stream_Element_Offset;
      SLast : Stream_Element_Offset;
      To    : aliased Sock_Addr_Type := (Family_Inet, Server, 53);
      From  : aliased Sock_Addr_Type;
      Q_Id  : constant Unsigned_16 := Next_Id;

      --  Decimal image of E with no leading blank ("84", not " 84").
      function Img (Element : Stream_Element) return String is
         Image_Str : constant String := Integer'Image (Integer (Element));
      begin
         return Image_Str (Image_Str'First + 1 .. Image_Str'Last);
      end Img;

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

      --  Advance Pos past a DNS name (labels, or a 0xC0 compression pointer).
      procedure Skip_Name (Pos : in out Stream_Element_Offset) is
         Len : Integer;
      begin
         loop
            exit when Pos > RLast;   --  truncated / malformed: stop here rather
            --  than read stale bytes or walk off Resp
            Len := Integer (Resp (Pos));
            if Len = 0 then
               Pos := Pos + 1;
               exit;
            elsif Len >= 16#C0# then
               --  pointer: 2 bytes, name ends here
               Pos := Pos + 2;
               exit;
            else
               Pos := Pos + 1 + Stream_Element_Offset (Len);
            end if;
         end loop;
      end Skip_Name;

      function U16 (Pos : Stream_Element_Offset) return Integer
      is (Integer
            (ESP32S3.Endian.Join_BE16 (Unsigned_8 (Resp (Pos)), Unsigned_8 (Resp (Pos + 1)))));
   begin
      Addr := Any_Inet_Addr;
      Next_Id := Next_Id + 1;             --  advance for the next caller
      Build_Query;
      Create_Socket (Sock, Family_Inet, Socket_Datagram);
      Bind_Socket (Sock, (Family_Inet, Any_Inet_Addr, Local_Port));
      if Timeout > 0.0 then
         Set_Socket_Option (Sock, Socket_Level, (Receive_Timeout, Timeout => Timeout));
      end if;
      Send_Socket (Sock, Query (Query'First .. QLen - 1), SLast, To => To'Access);
      begin
         Receive_Socket (Sock, Resp, RLast, From => From'Access);
      exception
         when Socket_Error =>
            --  no reply within Timeout
            Close_Socket (Sock);
            return False;
      end;

      --  Everything from here closes Sock on the way out (normal, reject, or an
      --  exception from a malformed reply) so the datagram socket never leaks.
      declare
         Found : Boolean := False;
      begin
         --  Reject a datagram that isn't from the server we asked, on port 53,
         --  echoing our transaction id, and long enough to hold a DNS header.
         if From.Addr /= Server
           or else From.Port /= 53
           or else RLast < Resp'First + 11
           or else U16 (Resp'First) /= Integer (Q_Id)
         then
            Close_Socket (Sock);
            return False;
         end if;

         declare
            AnCount : constant Integer := U16 (Resp'First + 6);   --  answer count
            Pos     : Stream_Element_Offset := Resp'First + 12;   --  past the header
         begin
            Skip_Name (Pos);              --  skip the question's QNAME
            Pos := Pos + 4;               --   + QTYPE + QCLASS
            for A in 1 .. AnCount loop
               Skip_Name (Pos);           --  answer NAME (usually a pointer)
               --  Bound AFTER Skip_Name: it can advance Pos past RLast, and the
               --  fixed 10-byte RR header (type/class/ttl/rdlength) plus its
               --  RDATA must all lie within the received bytes before we index.
               exit when Pos + 10 > RLast;
               declare
                  RRType : constant Integer := U16 (Pos);
                  RDLen  : constant Integer := U16 (Pos + 8);
                  RData  : constant Stream_Element_Offset := Pos + 10;
               begin
                  exit when RData + Stream_Element_Offset (RDLen) - 1 > RLast;
                  if RRType = 1 and then RDLen = 4 then
                     --  an A record
                     Addr :=
                       Inet_Addr
                         (Img (Resp (RData))
                          & "."
                          & Img (Resp (RData + 1))
                          & "."
                          & Img (Resp (RData + 2))
                          & "."
                          & Img (Resp (RData + 3)));
                     Found := True;
                     exit;
                  end if;
                  Pos := RData + Stream_Element_Offset (RDLen);
               end;
            end loop;
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
