with Interfaces; use Interfaces;
with DNS_Client.Parse;
with DNS_Client.Wire;
with ESP32S3.Strings;

package body DNS_TLS is

   package Parse renames DNS_Client.Parse;
   package Wire renames DNS_Client.Wire;

   --  Bounded reassembly of the reply: a TLS Recv yields ONE record, which
   --  may carry part of a message or several; DoH adds HTTP headers around
   --  it.  This much always suffices for an A answer.
   Max_Reply : constant := 4096;

   --  Own the transaction-id sequence (DNS_Client keeps its private one).
   Next_Id : Unsigned_16 := 16#5A00#;

   --  The reply's A record as an Inet_Addr_Type, exactly as the other
   --  transports do it.
   procedure Extract
     (Reply : Parse.Byte_Array;
      Id    : Unsigned_16;
      Addr  : out GNAT.Sockets.Inet_Addr_Type;
      Ok    : out Boolean)
   is
      function Img (Octet : Unsigned_8) return String
      is (ESP32S3.Strings.Image (Natural (Octet)));
      Found : constant Parse.A_Record := Parse.Find_A_Record (Reply, Id);
   begin
      if Found.Found then
         Addr := GNAT.Sockets.Inet_Addr
           (Img (Found.B0) & "." & Img (Found.B1) & "."
            & Img (Found.B2) & "." & Img (Found.B3));
         Ok := True;
      else
         Addr := GNAT.Sockets.Any_Inet_Addr;
         Ok := False;
      end if;
   end Extract;

   --  Accumulate decrypted records into Buf until At_Least bytes are held,
   --  the peer stops, or the bound is hit.  Ok is False on a dead session.
   procedure Recv_At_Least
     (Session  : in out TLS_Client.Session;
      Sock     : GNAT.Sockets.Socket_Type;
      Buf      : in out TLS_Client.Byte_Array;
      Have     : in out Natural;
      At_Least : Natural;
      Ok       : out Boolean)
   is
      Chunk : TLS_Client.Byte_Array (0 .. 2047);
      Last  : Natural;
      Alive : Boolean;
   begin
      Ok := False;
      while Have < At_Least loop
         TLS_Client.Recv (Session, Sock, Chunk, Last, Alive);
         if not Alive then
            return;
         end if;
         exit when Last < Chunk'First;               --  empty record
         for I in Chunk'First .. Last loop
            exit when Have > Buf'Last;
            Buf (Buf'First + Have) := Chunk (I);
            Have := Have + 1;
         end loop;
         if Have >= Buf'Length then
            return;                                  --  bound hit: refuse
         end if;
      end loop;
      Ok := Have >= At_Least;
   end Recv_At_Least;

   ---------------------------------------------------------------------------
   --  DoT: RFC 7766 framing inside the TLS stream.
   ---------------------------------------------------------------------------

   procedure Resolve_DoT
     (Session : in out TLS_Client.Session;
      Sock    : GNAT.Sockets.Socket_Type;
      Name    : String;
      Addr    : out GNAT.Sockets.Inet_Addr_Type;
      Ok      : out Boolean)
   is
      Q_Buf : Wire.Query_Buffer;
      Q_Len : Natural;
      Built : Boolean;
      Q_Id  : constant Unsigned_16 := Next_Id;
   begin
      Addr := GNAT.Sockets.Any_Inet_Addr;
      Ok   := False;
      Next_Id := Next_Id + 1;

      if Name'Length > Wire.Max_Name_Length then
         return;
      end if;
      Wire.Build_A_Query (Name, Q_Id, Q_Buf, Q_Len, Built);
      if not Built then
         return;
      end if;

      --  Two length bytes, then the message, in one TLS write.
      declare
         Framed : TLS_Client.Byte_Array (0 .. Q_Len + 1);
      begin
         Framed (0) := Unsigned_8 (Q_Len / 256);
         Framed (1) := Unsigned_8 (Q_Len mod 256);
         for I in 0 .. Q_Len - 1 loop
            Framed (I + 2) := Q_Buf (I);
         end loop;
         TLS_Client.Send (Session, Sock, Framed);
      end;

      --  The framed reply: length, then exactly that many bytes.
      declare
         Buf   : TLS_Client.Byte_Array (0 .. Max_Reply - 1) := (others => 0);
         Have  : Natural := 0;
         Alive : Boolean;
         Reply_Len : Natural;
      begin
         Recv_At_Least (Session, Sock, Buf, Have, 2, Alive);
         if not Alive then
            return;
         end if;
         Reply_Len := Natural (Buf (0)) * 256 + Natural (Buf (1));
         if Reply_Len < 12 or else Reply_Len > Max_Reply - 2 then
            return;
         end if;
         Recv_At_Least (Session, Sock, Buf, Have, 2 + Reply_Len, Alive);
         if not Alive then
            return;
         end if;
         declare
            Bytes : Parse.Byte_Array (0 .. Reply_Len - 1);
         begin
            for I in Bytes'Range loop
               Bytes (I) := Buf (2 + I);
            end loop;
            Extract (Bytes, Q_Id, Addr, Ok);
         end;
      end;
   end Resolve_DoT;

   ---------------------------------------------------------------------------
   --  DoH: the same message as the body of an HTTP/1.1 POST.  The reply is
   --  located by finding the header/body split and Content-Length -- the
   --  minimal correct reading of an HTTP/1.1 response with a known-small
   --  entity, same approach as the HTTPS weather examples.
   ---------------------------------------------------------------------------

   procedure Resolve_DoH
     (Session     : in out TLS_Client.Session;
      Sock        : GNAT.Sockets.Socket_Type;
      Host_Header : String;
      Name        : String;
      Addr        : out GNAT.Sockets.Inet_Addr_Type;
      Ok          : out Boolean)
   is
      Q_Buf : Wire.Query_Buffer;
      Q_Len : Natural;
      Built : Boolean;
      Q_Id  : constant Unsigned_16 := Next_Id;
      CRLF  : constant String := (1 => ASCII.CR, 2 => ASCII.LF);
   begin
      Addr := GNAT.Sockets.Any_Inet_Addr;
      Ok   := False;
      Next_Id := Next_Id + 1;

      if Name'Length > Wire.Max_Name_Length then
         return;
      end if;
      Wire.Build_A_Query (Name, Q_Id, Q_Buf, Q_Len, Built);
      if not Built then
         return;
      end if;

      --  POST /dns-query: headers as text, then the raw message.
      declare
         Header : constant String :=
           "POST /dns-query HTTP/1.1" & CRLF
           & "Host: " & Host_Header & CRLF
           & "Content-Type: application/dns-message" & CRLF
           & "Accept: application/dns-message" & CRLF
           & "Content-Length: " & ESP32S3.Strings.Image (Q_Len) & CRLF
           & "Connection: close" & CRLF
           & CRLF;
         Request : TLS_Client.Byte_Array
           (0 .. Header'Length + Q_Len - 1);
      begin
         for I in 0 .. Header'Length - 1 loop
            Request (I) :=
              Unsigned_8 (Character'Pos (Header (Header'First + I)));
         end loop;
         for I in 0 .. Q_Len - 1 loop
            Request (Header'Length + I) := Q_Buf (I);
         end loop;
         TLS_Client.Send (Session, Sock, Request);
      end;

      --  Accumulate the whole response ("Connection: close" bounds it), then
      --  split headers from body and take Content-Length bytes.
      declare
         Buf   : TLS_Client.Byte_Array (0 .. Max_Reply - 1) := (others => 0);
         Have  : Natural := 0;
         Chunk : TLS_Client.Byte_Array (0 .. 2047);
         Last  : Natural;
         Alive : Boolean := True;
      begin
         while Alive loop
            TLS_Client.Recv (Session, Sock, Chunk, Last, Alive);
            exit when not Alive;
            for I in Chunk'First .. Last loop
               exit when Have > Buf'Last;
               Buf (Have) := Chunk (I);
               Have := Have + 1;
            end loop;
            exit when Have >= Buf'Length;            --  bound hit
         end loop;

         --  "HTTP/1.1 200" and the blank line, found over raw bytes.
         if Have < 20
           or else Buf (9) /= Character'Pos ('2')
           or else Buf (10) /= Character'Pos ('0')
           or else Buf (11) /= Character'Pos ('0')
         then
            return;
         end if;
         declare
            Body_First : Natural := 0;
         begin
            for I in 0 .. Have - 4 loop
               if Buf (I) = 13 and then Buf (I + 1) = 10
                 and then Buf (I + 2) = 13 and then Buf (I + 3) = 10
               then
                  Body_First := I + 4;
                  exit;
               end if;
            end loop;
            if Body_First = 0 or else Have - Body_First < 12 then
               return;
            end if;
            declare
               Bytes : Parse.Byte_Array (0 .. Have - Body_First - 1);
            begin
               for I in Bytes'Range loop
                  Bytes (I) := Buf (Body_First + I);
               end loop;
               Extract (Bytes, Q_Id, Addr, Ok);
            end;
         end;
      end;
   end Resolve_DoH;

end DNS_TLS;
