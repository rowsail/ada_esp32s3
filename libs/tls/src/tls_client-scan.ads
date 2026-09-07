--  Walking the server's reassembled handshake flight.
--
--  This is the first thing a hostile server reaches.  The bytes are whatever
--  it chose to send, the lengths inside them are its numbers, and every offset
--  this walk computes comes from those numbers -- so the walk is where a
--  malformed flight either gets refused or gets to index something it should
--  not.  It lives apart from TLS_Client's body for that reason: with nothing
--  here but the buffer and the record it fills, SPARK can prove the whole of
--  it, for every input rather than for the malformed ones anyone thought to
--  write down (see libs/tls/tls_scan_prove.gpr).
--
--  It reports what it found; applying that to a Session is the caller's job.
package TLS_Client.Scan with SPARK_Mode => On is

   --  How many certificates a chain may hold before the rest are ignored.
   --  Its own constant, not the parent's: the parent keeps that one private,
   --  and a walk that reports what it found has no business reaching into the
   --  Session type it does not touch.
   Max_Chain : constant := 6;                    --  leaf + a few issuers

   type Cert_Span is record
      First, Last : Natural;                     --  First > Last = empty
   end record;
   type Cert_Span_Array is array (1 .. Max_Chain) of Cert_Span;

   --  What one pass over the flight found.  The offsets are into the same
   --  buffer that was scanned, and are empty (First > Last) when the message
   --  they describe was absent or malformed.
   type Flight_Info is record
      Saw_Finished  : Boolean := False;
      Chain         : Cert_Span_Array := (others => (1, 0));
      Chain_Count   : Natural := 0;
      Have_Cert     : Boolean := False;
      Cert_First    : Natural := 1;
      Cert_Last     : Natural := 0;
      Cert_End      : Natural := 0;    --  transcript point for CertificateVerify
      CV_Alg        : U16 := 0;
      CV_Sig_First  : Natural := 1;
      CV_Sig_Last   : Natural := 0;
      CV_End        : Natural := 0;    --  transcript point for Finished
      Fin_First     : Natural := 1;
      Fin_Last      : Natural := 0;
      Cert_Req_Seen : Boolean := False;
   end record;

   --  A key share, either curve: 32 bytes for X25519, or the two 32-byte
   --  coordinates of an uncompressed P-256 point.  Its own type, like
   --  Cert_Span above, so the walk depends on nothing private to the parent.
   subtype Share32 is Byte_Array (0 .. 31);

   --  What the ServerHello said.  Suite = 0 means it was not a ServerHello, or
   --  not one this client can use.
   type Hello_Info is record
      Suite       : U16 := 0;
      Group       : U16 := 0;      --  0x001D x25519, 0x0017 P-256
      Have_Share  : Boolean := False;
      Resumed_PSK : Boolean := False;
      X25519      : Share32 := (others => 0);
      P256_X      : Share32 := (others => 0);
      P256_Y      : Share32 := (others => 0);
   end record;

   --  Parse a ServerHello out of Buf (Buf'First .. Buf'First + Len - 1).  This
   --  is the FIRST thing the server sends that this client reads, before any
   --  key is agreed and so before anything is authenticated -- every byte of it
   --  is attacker-chosen even on a connection that will later be fine.
   procedure Parse_Hello (Buf : Byte_Array; Len : Natural; Info : out Hello_Info)
   with
     Pre => Buf'First = 0
            and then Buf'Last < Natural'Last / 2
            and then Len <= Buf'Last + 1;

   --  Walk Buf (Buf'First .. Buf'First + Len - 1) as a sequence of handshake
   --  messages.  Nothing is trusted: a message that does not fit, or that is
   --  too short for the fields it claims, ends the walk or is passed over.
   procedure Walk (Buf : Byte_Array; Len : Natural; Info : out Flight_Info)
   with
     --  Stated without 'Length: this array is Natural-indexed, so its 'Length
     --  does not fit Integer and nothing built on it can be discharged.
     Pre  => Buf'First = 0
             and then Buf'Last < Natural'Last / 2
             and then Len <= Buf'Last + 1,
     Post =>
       --  Every offset reported is inside what was scanned, so a caller can
       --  slice on it without a check of its own.
       Info.Chain_Count <= Max_Chain
       and then (if Info.Have_Cert
                 then Info.Cert_First <= Info.Cert_Last
                      and then Info.Cert_Last < Len)
       and then (for all K in 1 .. Info.Chain_Count =>
                   Info.Chain (K).First <= Info.Chain (K).Last
                   and then Info.Chain (K).Last < Len)
       and then (if Info.CV_Sig_First <= Info.CV_Sig_Last
                 then Info.CV_Sig_Last < Len)
       and then (if Info.Fin_First <= Info.Fin_Last
                 then Info.Fin_Last < Len);

end TLS_Client.Scan;
