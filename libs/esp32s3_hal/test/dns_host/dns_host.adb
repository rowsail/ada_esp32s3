--  Native host test for DNS_Client's transports against the local mini
--  server (dns_server.py, UDP + TCP on the port in the first argument):
--  plain resolution both ways, the truncation fall-back case, the
--  anti-spoofing id check, and the name validation Wire added.
with Ada.Command_Line; use Ada.Command_Line;
with Ada.Text_IO;      use Ada.Text_IO;
with GNAT.Sockets;     use GNAT.Sockets;
with DNS_Client;

procedure DNS_Host is

   Server : constant Inet_Addr_Type := Inet_Addr ("127.0.0.1");
   Port   : constant Port_Type := Port_Type'Value (Argument (1));

   Passed, Failed : Natural := 0;

   procedure Check (Label : String; Ok : Boolean) is
   begin
      if Ok then
         Passed := Passed + 1;
         Put_Line ("  ok   " & Label);
      else
         Failed := Failed + 1;
         Put_Line ("  FAIL " & Label);
      end if;
   end Check;

   Addr     : Inet_Addr_Type;
   Expected : constant Inet_Addr_Type := Inet_Addr ("10.11.12.13");

begin
   --  Plain lookups, one per transport.
   Check ("UDP resolves",
          DNS_Client.Resolve
            (Server, "test.example", Addr,
             Timeout => 3.0, Server_Port => Port)
          and then Addr = Expected);

   Check ("TCP resolves",
          DNS_Client.Resolve_TCP
            (Server, "test.example", Addr,
             Timeout => 3.0, Server_Port => Port)
          and then Addr = Expected);

   --  Truncation: the server answers UDP with TC and no records -- the UDP
   --  client must report failure (no silent half-answer), and the SAME name
   --  must then resolve over TCP: the RFC 7766 fall-back path, end to end.
   Check ("truncated UDP refuses",
          not DNS_Client.Resolve
            (Server, "big.tconly.example", Addr,
             Timeout => 3.0, Server_Port => Port));
   Check ("same name over TCP resolves",
          DNS_Client.Resolve_TCP
            (Server, "big.tconly.example", Addr,
             Timeout => 3.0, Server_Port => Port)
          and then Addr = Expected);

   --  Anti-spoofing: a reply with the wrong transaction id is not an answer.
   Check ("wrong-id reply refused (UDP)",
          not DNS_Client.Resolve
            (Server, "x.badid.example", Addr,
             Timeout => 3.0, Server_Port => Port));
   Check ("wrong-id reply refused (TCP)",
          not DNS_Client.Resolve_TCP
            (Server, "x.badid.example", Addr,
             Timeout => 3.0, Server_Port => Port));

   --  Name validation (DNS_Client.Wire): refused before anything is sent.
   declare
      Long_Label : constant String := (1 .. 64 => 'a') & ".example";
      Long_Name  : constant String := (1 .. 254 => 'x');
   begin
      Check ("64-byte label refused",
             not DNS_Client.Resolve
               (Server, Long_Label, Addr,
                Timeout => 1.0, Server_Port => Port));
      Check ("254-byte name refused",
             not DNS_Client.Resolve_TCP
               (Server, Long_Name, Addr,
                Timeout => 1.0, Server_Port => Port));
      Check ("empty label refused",
             not DNS_Client.Resolve
               (Server, "a..b", Addr,
                Timeout => 1.0, Server_Port => Port));
   end;

   Put_Line ("DNS_Client:" & Natural'Image (Passed) & " passed,"
             & Natural'Image (Failed) & " failed");
   if Failed > 0 then
      raise Program_Error;
   end if;
end DNS_Host;
