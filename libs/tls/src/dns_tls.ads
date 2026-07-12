with GNAT.Sockets;
with TLS_Client;

--  The encrypted DNS transports: DNS-over-TLS (RFC 7858, port 853) and
--  DNS-over-HTTPS (RFC 8484, port 443), over the pure-Ada TLS 1.3 stack.
--  The message bytes are the same proven ones every transport shares
--  (DNS_Client.Wire builds them, DNS_Client.Parse walks the reply); this
--  package only supplies the carriage -- RFC 7766's two-byte framing inside
--  TLS for DoT, a minimal HTTP/1.1 POST of application/dns-message for DoH.
--
--  Trust stays with the application, exactly as in the HTTPS examples and
--  MQTT's TLS transport: the caller establishes the TCP connection and the
--  TLS session itself -- handshake, chain validation against ITS pinned
--  anchor, time from ITS source -- and hands the finished session in.  A DNS
--  library deciding which roots to trust would be the wrong layer deciding.
--
--     --  TCP connect to 1.1.1.1:853, TLS_Client.Hello, Chain_Verify ...
--     DNS_TLS.Resolve_DoT (Session, Sock, "api.example.com", Addr, Ok);
--
--  Why bother, beyond privacy: port-53 UDP is the most interfered-with
--  traffic class on the internet, and these transports were designed to be
--  indistinguishable from ordinary TLS/HTTPS -- the interceptor that has
--  been eating this project's cellular DNS cannot even see them.
--
--  Like TLS_Client itself, this builds for the target only (the TLS stack
--  uses the chip's crypto); the shared message layer underneath is what the
--  native tests and proofs cover.
package DNS_TLS is

   --  Resolve Name via DNS-over-TLS on an established session.  One query
   --  per call; the session may be reused for several.  Ok is False (and
   --  Addr Any_Inet_Addr) when the name is malformed, the peer misbehaves,
   --  or the answer holds no A record.
   procedure Resolve_DoT
     (Session : in out TLS_Client.Session;
      Sock    : GNAT.Sockets.Socket_Type;
      Name    : String;
      Addr    : out GNAT.Sockets.Inet_Addr_Type;
      Ok      : out Boolean)
   with Pre => Name'Length > 0;

   --  Resolve Name via DNS-over-HTTPS: POST /dns-query with the raw message
   --  (RFC 8484's application/dns-message form) over HTTP/1.1.  Host_Header
   --  is the server name for the Host: line (e.g. "cloudflare-dns.com" or
   --  "dns.google" -- public DoH servers require it).
   procedure Resolve_DoH
     (Session     : in out TLS_Client.Session;
      Sock        : GNAT.Sockets.Socket_Type;
      Host_Header : String;
      Name        : String;
      Addr        : out GNAT.Sockets.Inet_Addr_Type;
      Ok          : out Boolean)
   with Pre => Name'Length > 0 and then Host_Header'Length > 0;

end DNS_TLS;
