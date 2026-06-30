with Ada.Streams;  use Ada.Streams;
with GNAT.Sockets; use GNAT.Sockets;

package body DNS_Client is

   --  Resolve may run in several tasks at once.  Each in-flight lookup needs a
   --  transaction ID and a UDP source port distinct from every other (the W5500
   --  demultiplexes replies by local port, and the reply ID is checked), so a
   --  protected object vends both atomically.  A monotonic counter suffices --
   --  no RNG is available on bare metal; the reply ID + port guard the rest.
   Ephemeral_Base : constant := 50_000;          --  auto source ports live in
   Ephemeral_Span : constant := 2_000;           --  50_000 .. 51_999

   protected Allocator is
      procedure Take (ID : out Integer; Port : out Port_Type);
   private
      Seq : Integer := 0;
   end Allocator;

   protected body Allocator is
      procedure Take (ID : out Integer; Port : out Port_Type) is
      begin
         Seq  := (Seq + 1) mod 16#1_0000#;
         ID   := Seq;
         Port := Port_Type (Ephemeral_Base + Seq mod Ephemeral_Span);
      end Take;
   end Allocator;

   function Resolve
     (Server     : Inet_Addr_Type;
      Name       : String;
      Addr       : out Inet_Addr_Type;
      Timeout    : Duration  := 0.0;
      Local_Port : Port_Type := 0) return Boolean
   is
      Sock  : Socket_Type;
      Query : Stream_Element_Array (0 .. 511);
      QLen  : Stream_Element_Offset := 0;
      Resp  : Stream_Element_Array (0 .. 511);
      RLast : Stream_Element_Offset;
      SLast : Stream_Element_Offset;
      To    : aliased Sock_Addr_Type := (Family_Inet, Server, 53);
      From  : aliased Sock_Addr_Type;
      QID   : Integer;                  --  this call's transaction ID (set below)
      Bind_Port : Port_Type;            --  source port actually bound (set below)
      Auto_Port : Port_Type;            --  unique port vended for this call

      --  Decimal image of E with no leading blank ("84", not " 84").
      function Img (E : Stream_Element) return String is
         S : constant String := Integer'Image (Integer (E));
      begin
         return S (S'First + 1 .. S'Last);
      end Img;

      --  Build a standard recursive A-record query for Name into Query.  Returns
      --  False (encoding nothing usable) if Name has a label longer than the DNS
      --  63-byte limit, whose length byte would collide with the reserved range.
      function Build_Query return Boolean is
         P     : Stream_Element_Offset := Query'First;
         Start : Natural;
         procedure B (V : Integer) is
         begin
            Query (P) := Stream_Element (V);  P := P + 1;
         end B;
      begin
         B (QID / 256); B (QID mod 256);  --  ID (varies per call)
         B (16#01#); B (16#00#);          --  flags: standard query, recursion desired
         B (0); B (1);                    --  QDCOUNT = 1
         B (0); B (0);  B (0); B (0);  B (0); B (0);   --  AN/NS/AR = 0
         Start := Name'First;             --  QNAME as length-prefixed labels
         for I in Name'First .. Name'Last + 1 loop
            if I > Name'Last or else Name (I) = '.' then
               if I - Start > 63 then     --  label exceeds the DNS limit
                  return False;
               end if;
               B (I - Start);
               for J in Start .. I - 1 loop
                  B (Character'Pos (Name (J)));
               end loop;
               Start := I + 1;
            end if;
         end loop;
         B (0);                           --  end of name
         B (0); B (1);                    --  QTYPE  = A
         B (0); B (1);                    --  QCLASS = IN
         QLen := P - Query'First;
         return True;
      end Build_Query;

      --  Advance Pos past a DNS name (labels, or a 0xC0 compression pointer).
      procedure Skip_Name (Pos : in out Stream_Element_Offset) is
         Len : Integer;
      begin
         loop
            Len := Integer (Resp (Pos));
            if Len = 0 then
               Pos := Pos + 1;  exit;
            elsif Len >= 16#C0# then            --  pointer: 2 bytes, name ends here
               Pos := Pos + 2;  exit;
            else
               Pos := Pos + 1 + Stream_Element_Offset (Len);
            end if;
         end loop;
      end Skip_Name;

      function U16 (Pos : Stream_Element_Offset) return Integer is
        (Integer (Resp (Pos)) * 256 + Integer (Resp (Pos + 1)));
   begin
      Addr := Any_Inet_Addr;

      --  Take a unique transaction ID + source port for this call, then encode the
      --  query.  Reject a name too long to fit (with header + overhead, valid names
      --  are <= 253 bytes) or with an unencodable label -- before opening any socket.
      Allocator.Take (QID, Auto_Port);
      Bind_Port := (if Local_Port = 0 then Auto_Port else Local_Port);
      if Name'Length > 253 or else not Build_Query then
         return False;
      end if;

      Create_Socket (Sock, Family_Inet, Socket_Datagram);

      --  From here on every path must release Sock and report failure as False
      --  (never an exception): the response is untrusted network input, so a
      --  malformed/truncated reply can drive an out-of-bounds index, and a leaked
      --  socket exhausts the tiny W5500 socket pool.  One catch-all does both.
      begin
         Bind_Socket (Sock, (Family_Inet, Any_Inet_Addr, Bind_Port));
         if Timeout > 0.0 then
            Set_Socket_Option (Sock, Socket_Level, (Receive_Timeout, Timeout => Timeout));
         end if;
         Send_Socket (Sock, Query (Query'First .. QLen - 1), SLast, To => To'Access);
         Receive_Socket (Sock, Resp, RLast, From => From'Access);

         --  Accept only a well-formed response to OUR query: enough bytes for the
         --  header, matching transaction ID, and the QR (response) bit set.  This
         --  rejects a stray/late datagram that happened to land on Local_Port.
         if RLast < Resp'First + 11
           or else U16 (Resp'First) /= QID                  --  matching transaction ID
           or else (Resp (Resp'First + 2) and 16#80#) = 0   --  QR bit (Stream_Element is modular)
           or else (Resp (Resp'First + 3) and 16#0F#) /= 0  --  RCODE: 0 means no error
           or else U16 (Resp'First + 4) /= 1                --  exactly the one question we asked
         then
            Close_Socket (Sock);
            return False;
         end if;

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
               exit when Pos + 10 > RLast;   --  re-check: Skip_Name advanced Pos
               declare
                  RRType : constant Integer := U16 (Pos);
                  RDLen  : constant Integer := U16 (Pos + 8);
                  RData  : constant Stream_Element_Offset := Pos + 10;
               begin
                  exit when RData + Stream_Element_Offset (RDLen) - 1 > RLast;
                  if RRType = 1 and then RDLen = 4 then           --  an A record
                     Addr := Inet_Addr
                       (Img (Resp (RData))     & "." &
                        Img (Resp (RData + 1)) & "." &
                        Img (Resp (RData + 2)) & "." &
                        Img (Resp (RData + 3)));
                     Found := True;  exit;
                  end if;
                  Pos := RData + Stream_Element_Offset (RDLen);
               end;
            end loop;
            Close_Socket (Sock);
            return Found;
         end;
      exception
         when others =>           --  timeout, truncated/malformed reply, parse fault
            begin
               Close_Socket (Sock);
            exception
               when others => null;
            end;
            return False;
      end;
   end Resolve;

end DNS_Client;
