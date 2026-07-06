with Interfaces;
with GNAT.Sockets;
with X509;

--  A TLS 1.3 client handshake over GNAT.Sockets (work in progress).  This first
--  slice does the unencrypted opening: it builds and sends a ClientHello offering
--  X25519 + AES-GCM, then receives and parses the ServerHello, recovering the
--  negotiated cipher suite and the server's X25519 key share (from which the shared
--  secret and traffic keys will be derived in the next slice).

package TLS_Client is

   subtype U8 is Interfaces.Unsigned_8;
   subtype U16 is Interfaces.Unsigned_16;
   type Byte_Array is array (Natural range <>) of U8;

   type Session is limited private;

   --  Cipher suites we offer / understand.
   TLS_AES_128_GCM_SHA256 : constant U16 := 16#1301#;
   TLS_AES_256_GCM_SHA384 : constant U16 := 16#1302#;

   --  Send ClientHello (SNI = Host), then read records until the ServerHello and
   --  parse it.  Ok is False on I/O error, a TLS alert, or an unsupported response.
   procedure Hello
     (S : in out Session; Sock : GNAT.Sockets.Socket_Type; Host : String; Ok : out Boolean);

   --  Results available after a successful Hello.  After the ServerHello is parsed,
   --  Hello also runs the TLS 1.3 key schedule (X25519 ECDHE -> Handshake Secret ->
   --  traffic secrets), so the handshake traffic secrets and keys are available too.
   function Cipher_Suite (S : Session) return U16;
   function Server_Key_Share (S : Session) return Byte_Array;   --  32-byte X25519

   function Client_Random (S : Session) return Byte_Array; --  32 (keylog match)
   function Server_HS_Secret (S : Session) return Byte_Array; --  32 (server hs traffic secret)
   function Client_HS_Secret (S : Session) return Byte_Array; --  32
   function Keys_Ready (S : Session) return Boolean;

   --  Hello also reads + decrypts the server's encrypted handshake flight
   --  (EncryptedExtensions, Certificate, CertificateVerify, Finished) under the
   --  handshake keys.  Flight_OK means every record's AES-GCM tag authenticated and
   --  a Finished was seen -- which on its own proves the keys are right.
   function Flight_OK (S : Session) return Boolean;
   function Have_Server_Cert (S : Session) return Boolean;
   function Server_Cert (S : Session) return Byte_Array --  leaf cert DER
   with Pre => Have_Server_Cert (S);

   --  The full certificate chain the server sent (leaf first, then its issuers),
   --  so the caller can anchor it to a pinned root via Chain_Verify.  The DER is
   --  returned as X509.Byte_Array (ready to reference by access for Chain_Verify).
   function Server_Cert_Count (S : Session) return Natural;
   function Server_Chain_Cert (S : Session; Index : Positive) return X509.Byte_Array
   with Pre => Index <= Server_Cert_Count (S);

   --  The server's Finished verified: its HMAC over the handshake transcript
   --  matches, proving the transcript, keys and decryption are all consistent.
   function Server_Finished_OK (S : Session) return Boolean;

   --  The server's CertificateVerify verified: it signed the transcript with the
   --  certificate's private key (RSA-PSS), proving it holds that key.
   function Server_Cert_Verify_OK (S : Session) return Boolean;

   --  After Hello, the handshake is complete (our Finished sent, application keys
   --  derived) and the encrypted application channel is open.
   function Ready (S : Session) return Boolean;

   --  Send application data over the channel (encrypted).
   procedure Send (S : in out Session; Sock : GNAT.Sockets.Socket_Type; Data : Byte_Array)
   with Pre => Ready (S) and then Data'Length > 0;

   --  Receive one application-data record and decrypt it.  Last is the index of the
   --  last byte written to Buf (Buf'First-1 if none); Ok is False on a closed
   --  connection, an alert, or a bad tag.  A NewSessionTicket arriving on this
   --  channel is captured (see Has_Ticket) and skipped, not returned.
   procedure Recv
     (S    : in out Session;
      Sock : GNAT.Sockets.Socket_Type;
      Buf  : out Byte_Array;
      Last : out Natural;
      Ok   : out Boolean)
   with Pre => Ready (S);

   --  Session resumption (RFC 8446 2.2 / 4.6.1).  After a full handshake the server
   --  usually sends one or more NewSessionTicket messages; Recv captures the first
   --  one and derives its resumption PSK.  Has_Ticket then reports a ticket is held.
   function Has_Ticket (S : Session) return Boolean;

   --  Did the server's ServerHello carry a pre_shared_key (accepting our PSK)?
   function Server_Accepted_PSK (S : Session) return Boolean;

   --  Begin a NEW handshake on Sock that attempts to resume the session held in
   --  Prior, offering its ticket as a pre_shared_key (PSK-with-(EC)DHE: a fresh
   --  key_share is still sent, so forward secrecy holds and a non-accepting server
   --  falls back to a full handshake).  On return Ok is the usual handshake success;
   --  Resumed is True iff the server accepted the PSK (so it sent no Certificate and
   --  the round-trip was shorter).  Prior must Has_Ticket.
   procedure Resume
     (S       : in out Session;
      Sock    : GNAT.Sockets.Socket_Type;
      Host    : String;
      Prior   : Session;
      Ok      : out Boolean;
      Resumed : out Boolean)
   with Pre => Has_Ticket (Prior);

private
   subtype Key32 is Byte_Array (0 .. 31);

   Max_Chain  : constant := 6;                   --  leaf + a few issuers
   Max_Ticket : constant := 512;                 --  resumption ticket identity cap
   type Cert_Bounds is record
      First, Last : Natural;
   end record;
   type Cert_Bounds_Array is array (1 .. Max_Chain) of Cert_Bounds;

   type Session is limited record
      Priv, Pub      : Key32 := (others => 0);   --  our X25519 key pair
      Client_Random  : Key32 := (others => 0);   --  our ClientHello random
      Server_Pub     : Key32 := (others => 0);   --  server's X25519 key share
      --  We also offer secp256r1 (P-256) ECDHE; the server picks one group.
      P256_Priv      : Key32 := (others => 0);   --  our P-256 ephemeral private
      P256_Pub_X     : Key32 := (others => 0);   --  our P-256 public key (X, Y)
      P256_Pub_Y     : Key32 := (others => 0);
      Server_P256_X  : Key32 := (others => 0);   --  server's P-256 key share (X, Y)
      Server_P256_Y  : Key32 := (others => 0);
      Group          : U16 := 0;               --  negotiated group: 0x001D x25519, 0x0017 P-256
      Suite          : U16 := 0;
      Have_Share     : Boolean := False;
      --  Key schedule outputs (handshake phase).
      S_HS_Secret    : Key32 := (others => 0);   --  server_handshake_traffic_secret
      C_HS_Secret    : Key32 := (others => 0);   --  client_handshake_traffic_secret
      Server_Key     : Byte_Array (0 .. 15) := (others => 0);  --  AES-128 key
      Server_IV      : Byte_Array (0 .. 11) := (others => 0);
      Have_Keys      : Boolean := False;
      --  Decrypted server flight + the message boundaries we need for the
      --  transcript hashes (offsets into the reassembled handshake buffer).
      Cert_First     : Natural := 1;
      Cert_Last      : Natural := 0;
      Have_Cert      : Boolean := False;
      --  All certs in the server's Certificate message (offsets into the same
      --  reassembled handshake buffer); Chain (1) is the leaf.
      Chain          : Cert_Bounds_Array := (others => (1, 0));
      Chain_Count    : Natural := 0;
      Cert_End       : Natural := 0;       --  end of Certificate message
      CV_End         : Natural := 0;       --  end of CertificateVerify message
      CV_Alg         : U16 := 0;       --  CertificateVerify signature scheme
      CV_Sig_First   : Natural := 1;       --  CertificateVerify signature bytes
      CV_Sig_Last    : Natural := 0;
      Fin_First      : Natural := 1;       --  server Finished verify_data
      Fin_Last       : Natural := 0;
      Flight         : Boolean := False;
      Fin_OK         : Boolean := False;   --  server Finished verified
      CV_OK          : Boolean := False;   --  server CertificateVerify verified
      --  Client side: handshake + application traffic keys.
      HS_Secret      : Key32 := (others => 0);   --  Handshake Secret (-> Master)
      Client_Key     : Byte_Array (0 .. 15) := (others => 0);  --  client handshake key
      Client_IV      : Byte_Array (0 .. 11) := (others => 0);
      C_App_Key      : Byte_Array (0 .. 15) := (others => 0);  --  client application key
      C_App_IV       : Byte_Array (0 .. 11) := (others => 0);
      S_App_Key      : Byte_Array (0 .. 15) := (others => 0);  --  server application key
      S_App_IV       : Byte_Array (0 .. 11) := (others => 0);
      C_App_Seq      : Interfaces.Unsigned_64 := 0;
      S_App_Seq      : Interfaces.Unsigned_64 := 0;
      Open           : Boolean := False;
      --  Resumption: the resumption_master_secret (derived at handshake end), and
      --  the first NewSessionTicket captured on the channel + its resumption PSK.
      Res_Master     : Key32 := (others => 0);
      Have_Res       : Boolean := False;
      Ticket         : Byte_Array (0 .. Max_Ticket - 1) := (others => 0);
      Ticket_Len     : Natural := 0;
      Ticket_Age_Add : Interfaces.Unsigned_32 := 0;
      Ticket_PSK     : Key32 := (others => 0);   --  the PSK this ticket resumes with
      Has_Tick       : Boolean := False;
      --  When this session is itself a resumption attempt, the PSK + age we offer.
      Offered_PSK    : Key32 := (others => 0);
      Offered_Age    : Interfaces.Unsigned_32 := 0;
      Resumed_PSK    : Boolean := False;         --  server accepted our offered PSK
   end record;
end TLS_Client;
