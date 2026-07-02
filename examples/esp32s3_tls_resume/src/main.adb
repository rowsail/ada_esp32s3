--  TLS 1.3 session resumption (PSK) over the W5500 (Ethernet)
--  =========================================================
--  What it demonstrates: the resumption half of the pure-Ada TLS 1.3 client.
--  Connection 1 does a full handshake and, while draining the response, captures
--  the server's NewSessionTicket and derives its resumption PSK.  Connection 2
--  then calls TLS_Client.Resume, which offers that ticket as a pre_shared_key
--  (PSK-with-(EC)DHE: a fresh key_share is still sent) with the binder; if the
--  server accepts, the second handshake is resumed -- no Certificate flight.
--
--  Build & run: `./x run esp32s3_tls_resume` (embedded profile, set by build.sh).
--
--  Output: "[resume]" lines.  A PASS run shows the full handshake OK, the ticket
--  captured (yes), the resumed handshake OK, and "server accepted PSK ... yes".
--
--  Hardware: the W5500 Ethernet module (board takes static IP 192.168.1.50), on a
--  LAN with a TLS 1.3 server that issues + accepts tickets, e.g.:
--    openssl s_server -tls1_3 -accept 4433 -cert c.pem -key k.pem -www
--  No certificate pinning here (the focus is resumption), so any cert works.
with Ada.Real_Time; use Ada.Real_Time;
with Interfaces;
with GNAT.Sockets;  use GNAT.Sockets;
with TLS_Client;
with W5500_Dev;
with ESP32S3.RNG;
with ESP32S3.Log;   use ESP32S3.Log;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   Server_IP         : constant String := "192.168.1.100";
   Server_Port       : constant Port_Type := 4433;
   Host              : constant String := "test.example.com";
   Max_Connect_Tries : constant := 20;
   Connect_Retry     : constant Time_Span := Milliseconds (700);

   S1, S2 : TLS_Client.Session;   --  connection 1 (full) and 2 (resumed)

   --  Open a TCP socket to the server, retrying while the link/server come up.
   procedure Connect (Sock : out Socket_Type; Connected : out Boolean) is
   begin
      Connected := False;
      for Try in 1 .. Max_Connect_Tries loop
         begin
            Create_Socket (Sock, Family_Inet, Socket_Stream);
            Connect_Socket (Sock, (Family_Inet, Inet_Addr (Server_IP), Server_Port));
            Connected := True;
            return;
         exception
            when others =>
               begin
                  Close_Socket (Sock);
               exception
                  when others =>
                     null;
               end;
               delay until Clock + Connect_Retry;
         end;
      end loop;
   end Connect;

   --  Send a GET and read until the server closes.  Draining the channel lets
   --  Recv capture any NewSessionTicket the server sends after its Finished.
   procedure Exchange (S : in out TLS_Client.Session; Sock : Socket_Type) is
      Req       : constant String :=
        "GET / HTTP/1.0"
        & ASCII.CR
        & ASCII.LF
        & "Host: "
        & Host
        & ASCII.CR
        & ASCII.LF
        & "Connection: close"
        & ASCII.CR
        & ASCII.LF
        & ASCII.CR
        & ASCII.LF;
      Req_Bytes : TLS_Client.Byte_Array (0 .. Req'Length - 1);
      Buf       : TLS_Client.Byte_Array (0 .. 1023);
      Last      : Natural;
      Recv_Ok   : Boolean;
   begin
      for I in 0 .. Req'Length - 1 loop
         Req_Bytes (I) := Interfaces.Unsigned_8 (Character'Pos (Req (Req'First + I)));
      end loop;
      TLS_Client.Send (S, Sock, Req_Bytes);
      loop
         TLS_Client.Recv (S, Sock, Buf, Last, Recv_Ok);
         exit when not Recv_Ok;
      end loop;
   end Exchange;

   Sock1, Sock2 : Socket_Type;
   C1, C2, H1   : Boolean := False;
   R2           : Boolean := False;
   Resumed      : Boolean := False;
begin
   delay until Clock + Milliseconds (200);
   ESP32S3.RNG.Enable_Entropy_Source;          --  randomness for the ephemeral keys
   Put_Line ("[resume] TLS 1.3 session resumption (PSK) over the W5500");
   if not W5500_Dev.Bring_Up then
      loop
         delay until Clock + Seconds (3600);
      end loop;
   end if;

   --  Connection 1: full handshake, then drain (captures the ticket).
   Connect (Sock1, C1);
   if not C1 then
      Put_Line ("[resume] could not connect (1)");
      loop
         delay until Clock + Seconds (3600);
      end loop;
   end if;
   TLS_Client.Hello (S1, Sock1, Host, H1);
   Put_Line
     ("[resume] full handshake: " & (if H1 and then TLS_Client.Ready (S1) then "OK" else "FAIL"));
   if H1 and then TLS_Client.Ready (S1) then
      Exchange (S1, Sock1);
   end if;
   begin
      Close_Socket (Sock1);
   exception
      when others =>
         null;
   end;
   Put_Line
     ("[resume] resumption ticket captured: "
      & (if TLS_Client.Has_Ticket (S1) then "yes" else "no"));

   --  Connection 2: resume using the ticket from connection 1.
   if TLS_Client.Has_Ticket (S1) then
      Connect (Sock2, C2);
      if C2 then
         TLS_Client.Resume (S2, Sock2, Host, S1, R2, Resumed);
         Put_Line
           ("[resume] resumed handshake: "
            & (if R2 and then TLS_Client.Ready (S2) then "OK" else "FAIL")
            & " (no Certificate flight when resumed)");
         Put_Line ("[resume] server accepted PSK (resumed): " & (if Resumed then "yes" else "no"));
         if R2 and then TLS_Client.Ready (S2) then
            Exchange (S2, Sock2);
            Put_Line ("[resume] second (resumed) exchange done");
         end if;
         begin
            Close_Socket (Sock2);
         exception
            when others =>
               null;
         end;
      else
         Put_Line ("[resume] could not connect (2)");
      end if;
   end if;

   Put_Line
     ("[resume] result: "
      & (if TLS_Client.Has_Ticket (S1) and then Resumed then "PASS" else "FAIL"));
   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
