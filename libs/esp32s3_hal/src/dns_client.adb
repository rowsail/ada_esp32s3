with Ada.Streams;  use Ada.Streams;
with GNAT.Sockets; use GNAT.Sockets;
with Interfaces;   use Interfaces;
with ESP32S3.Endian;

package body DNS_Client is

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

      --  Decimal image of E with no leading blank ("84", not " 84").
      function Img (E : Stream_Element) return String is
         S : constant String := Integer'Image (Integer (E));
      begin
         return S (S'First + 1 .. S'Last);
      end Img;

      --  Build a standard recursive A-record query for Name into Query.
      procedure Build_Query is
         P     : Stream_Element_Offset := Query'First;
         Start : Natural;
         procedure B (V : Integer) is
         begin
            Query (P) := Stream_Element (V);
            P := P + 1;
         end B;
      begin
         B (16#12#);
         B (16#34#);          --  ID
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
         QLen := P - Query'First;
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

      declare
         AnCount : constant Integer := U16 (Resp'First + 6);   --  answer count
         Pos     : Stream_Element_Offset := Resp'First + 12;   --  past the header
         Found   : Boolean := False;
      begin
         Skip_Name (Pos);                 --  skip the question's QNAME
         Pos := Pos + 4;                  --   + QTYPE + QCLASS
         for A in 1 .. AnCount loop
            exit when Pos + 10 > RLast;
            Skip_Name (Pos);              --  answer NAME (usually a pointer)
            declare
               RRType : constant Integer := U16 (Pos);
               RDLen  : constant Integer := U16 (Pos + 8);
               RData  : constant Stream_Element_Offset := Pos + 10;
            begin
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
         Close_Socket (Sock);
         return Found;
      end;
   end Resolve;

end DNS_Client;
