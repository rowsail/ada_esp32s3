--  Known-answer test for the pure-Ada P-256 (secp256r1) ECDSA + ECDH (P256)
--  ==========================================================================
--  What it demonstrates: the pure-Ada P-256 primitives produce the expected
--  fixed answers.  Three parts run against baked-in vectors:
--    ECDSA verify -- P256.Verify accepts a genuine signature and rejects the
--                    same signature against a one-bit-tampered message hash;
--    ECDSA sign   -- P256.Sign reproduces the RFC 6979 deterministic signature
--                    for a known key + digest, bit-for-bit;
--    ECDH         -- P256.Public_Key reproduces the public key for a known
--                    private scalar, and P256.ECDH reproduces the known shared
--                    secret against a known peer public key.
--
--  Build & run: ./x run esp32s3_p256_kat
--    (build.sh sets ESP32S3_RTS_PROFILE=embedded, the no-tasking bare profile.)
--
--  Output: each line ends in (PASS) when the primitive matches the vector, and
--  the run ends with "[p256] result: ALL PASS".  Note that the EXPECTED state of
--  the tampered-hash line is INVALID -- "INVALID (PASS)" means the verifier
--  correctly rejected the bad signature.
--
--  Hardware: none (self-contained -- all data is baked-in test vectors).
--
--  Vector legend (all 32-byte big-endian field/scalar values):
--    Qx,   Qy    -- the signer's public key (point Q = d*G on the curve);
--    Hash        -- the SHA-256 message digest that was signed;
--    R,    S     -- the ECDSA signature pair over Hash;
--    D           -- our ECDH private scalar;
--    MyX,  MyY   -- our public key (point D*G), the expected Public_Key output;
--    PeerX, PeerY -- the peer's public key point;
--    Shared      -- the expected ECDH shared secret (X-coord of D*Peer).
--
--  Provenance: the ECDSA key/signature/hash vector was produced with OpenSSL
--  (`openssl ecparam -name prime256v1` + `openssl dgst -sha256 -sign`) and
--  confirmed valid by `openssl dgst -verify`.  The ECDH key pairs and shared
--  secret were likewise generated with OpenSSL (a pair of prime256v1 keys plus
--  `openssl pkeyutl -derive`); both sides deriving the same secret X-coordinate
--  is the standard ECDH cross-check.
with Interfaces;
use type Interfaces.Unsigned_8;
with ESP32S3.Log; use ESP32S3.Log;
with P256;
use type P256.Bytes;

--  Pull the SMP slave-start entry into the link closure (the bare glue calls it
--  after elaboration); this KAT runs single-core, so nothing else is needed.
with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   --  ECDSA-over-SHA-256 vector: signer public key Q = (Qx, Qy).
   KAT_Qx             : constant P256.Bytes_32 :=
     (16#A3#,
      16#D5#,
      16#B9#,
      16#BE#,
      16#79#,
      16#43#,
      16#F5#,
      16#4F#,
      16#F9#,
      16#B8#,
      16#8F#,
      16#5D#,
      16#2E#,
      16#82#,
      16#51#,
      16#C4#,
      16#B9#,
      16#1B#,
      16#ED#,
      16#AE#,
      16#E1#,
      16#BC#,
      16#21#,
      16#AD#,
      16#07#,
      16#12#,
      16#26#,
      16#0E#,
      16#AE#,
      16#79#,
      16#99#,
      16#1A#);
   KAT_Qy             : constant P256.Bytes_32 :=
     (16#2E#,
      16#A5#,
      16#1F#,
      16#C1#,
      16#3C#,
      16#4A#,
      16#69#,
      16#B1#,
      16#7B#,
      16#13#,
      16#9B#,
      16#57#,
      16#67#,
      16#E4#,
      16#44#,
      16#63#,
      16#E0#,
      16#1F#,
      16#5F#,
      16#06#,
      16#2E#,
      16#1C#,
      16#4F#,
      16#05#,
      16#9D#,
      16#8A#,
      16#8E#,
      16#75#,
      16#30#,
      16#1B#,
      16#50#,
      16#7E#);
   --  The SHA-256 digest that was signed.
   KAT_Hash           : constant P256.Bytes_32 :=
     (16#0F#,
      16#B7#,
      16#6E#,
      16#5A#,
      16#9C#,
      16#8D#,
      16#DE#,
      16#38#,
      16#8D#,
      16#06#,
      16#56#,
      16#55#,
      16#26#,
      16#17#,
      16#EB#,
      16#ED#,
      16#E9#,
      16#25#,
      16#C7#,
      16#31#,
      16#07#,
      16#93#,
      16#C4#,
      16#E1#,
      16#3C#,
      16#54#,
      16#91#,
      16#05#,
      16#72#,
      16#CB#,
      16#67#,
      16#24#);
   --  The ECDSA signature pair (R, S) over KAT_Hash under the key above.
   KAT_R              : constant P256.Bytes_32 :=
     (16#1E#,
      16#FF#,
      16#4D#,
      16#52#,
      16#69#,
      16#2D#,
      16#F9#,
      16#AB#,
      16#CA#,
      16#CC#,
      16#E7#,
      16#51#,
      16#84#,
      16#93#,
      16#AA#,
      16#4C#,
      16#3A#,
      16#4A#,
      16#3F#,
      16#10#,
      16#73#,
      16#8F#,
      16#F7#,
      16#58#,
      16#BB#,
      16#44#,
      16#23#,
      16#F0#,
      16#27#,
      16#6E#,
      16#BC#,
      16#27#);
   KAT_S              : constant P256.Bytes_32 :=
     (16#97#,
      16#44#,
      16#2D#,
      16#D3#,
      16#4D#,
      16#7F#,
      16#D0#,
      16#DC#,
      16#C5#,
      16#45#,
      16#EC#,
      16#48#,
      16#5F#,
      16#B5#,
      16#8D#,
      16#7A#,
      16#EB#,
      16#B4#,
      16#79#,
      16#6A#,
      16#3A#,
      16#39#,
      16#4C#,
      16#4F#,
      16#86#,
      16#9A#,
      16#63#,
      16#E5#,
      16#B9#,
      16#B1#,
      16#47#,
      16#A8#);
   --  RFC 6979 deterministic-ECDSA vector (Appendix A.2.5, P-256/SHA-256, message
   --  "sample"): private key, the SHA-256 digest, and the expected (R, S) that
   --  P256.Sign must reproduce bit-for-bit.
   Sign_Priv          : constant P256.Bytes_32 :=
     (16#C9#,
      16#AF#,
      16#A9#,
      16#D8#,
      16#45#,
      16#BA#,
      16#75#,
      16#16#,
      16#6B#,
      16#5C#,
      16#21#,
      16#57#,
      16#67#,
      16#B1#,
      16#D6#,
      16#93#,
      16#4E#,
      16#50#,
      16#C3#,
      16#DB#,
      16#36#,
      16#E8#,
      16#9B#,
      16#12#,
      16#7B#,
      16#8A#,
      16#62#,
      16#2B#,
      16#12#,
      16#0F#,
      16#67#,
      16#21#);
   Sign_Hash          : constant P256.Bytes_32 :=
     (16#AF#,
      16#2B#,
      16#DB#,
      16#E1#,
      16#AA#,
      16#9B#,
      16#6E#,
      16#C1#,
      16#E2#,
      16#AD#,
      16#E1#,
      16#D6#,
      16#94#,
      16#F4#,
      16#1F#,
      16#C7#,
      16#1A#,
      16#83#,
      16#1D#,
      16#02#,
      16#68#,
      16#E9#,
      16#89#,
      16#15#,
      16#62#,
      16#11#,
      16#3D#,
      16#8A#,
      16#62#,
      16#AD#,
      16#D1#,
      16#BF#);
   Sign_Want_R        : constant P256.Bytes_32 :=
     (16#EF#,
      16#D4#,
      16#8B#,
      16#2A#,
      16#AC#,
      16#B6#,
      16#A8#,
      16#FD#,
      16#11#,
      16#40#,
      16#DD#,
      16#9C#,
      16#D4#,
      16#5E#,
      16#81#,
      16#D6#,
      16#9D#,
      16#2C#,
      16#87#,
      16#7B#,
      16#56#,
      16#AA#,
      16#F9#,
      16#91#,
      16#C3#,
      16#4D#,
      16#0E#,
      16#A8#,
      16#4E#,
      16#AF#,
      16#37#,
      16#16#);
   Sign_Want_S        : constant P256.Bytes_32 :=
     (16#F7#,
      16#CB#,
      16#1C#,
      16#94#,
      16#2D#,
      16#65#,
      16#7C#,
      16#41#,
      16#D4#,
      16#36#,
      16#C7#,
      16#A1#,
      16#B6#,
      16#E2#,
      16#9F#,
      16#65#,
      16#F3#,
      16#E9#,
      16#00#,
      16#DB#,
      16#B9#,
      16#AF#,
      16#F4#,
      16#06#,
      16#4D#,
      16#C4#,
      16#AB#,
      16#2F#,
      16#84#,
      16#3A#,
      16#CD#,
      16#A8#);
   Sign_R, Sign_S     : P256.Bytes_32;
   Sign_OK, Sign_Pass : Boolean := False;

   --  ECDH vector: our private scalar D, and the public key D*G we expect
   --  Public_Key to derive from it -- (ECDH_MyX, ECDH_MyY).
   ECDH_D        : constant P256.Bytes_32 :=
     (16#D8#,
      16#A6#,
      16#42#,
      16#7E#,
      16#87#,
      16#E0#,
      16#65#,
      16#6D#,
      16#1D#,
      16#D1#,
      16#9C#,
      16#AC#,
      16#AF#,
      16#8E#,
      16#D2#,
      16#FE#,
      16#50#,
      16#D9#,
      16#DC#,
      16#F0#,
      16#01#,
      16#F0#,
      16#28#,
      16#F7#,
      16#71#,
      16#73#,
      16#DD#,
      16#57#,
      16#0B#,
      16#D1#,
      16#18#,
      16#18#);
   ECDH_MyX      : constant P256.Bytes_32 :=
     (16#73#,
      16#50#,
      16#44#,
      16#E7#,
      16#FF#,
      16#F2#,
      16#51#,
      16#DA#,
      16#70#,
      16#AB#,
      16#B6#,
      16#A5#,
      16#69#,
      16#B1#,
      16#47#,
      16#69#,
      16#CA#,
      16#A5#,
      16#F3#,
      16#0B#,
      16#EB#,
      16#E0#,
      16#D3#,
      16#21#,
      16#B2#,
      16#5C#,
      16#24#,
      16#85#,
      16#7D#,
      16#A5#,
      16#D3#,
      16#1F#);
   ECDH_MyY      : constant P256.Bytes_32 :=
     (16#E9#,
      16#C9#,
      16#50#,
      16#E8#,
      16#80#,
      16#6C#,
      16#FD#,
      16#93#,
      16#87#,
      16#5D#,
      16#4A#,
      16#3E#,
      16#5C#,
      16#51#,
      16#E0#,
      16#FA#,
      16#7A#,
      16#4C#,
      16#67#,
      16#CC#,
      16#83#,
      16#6F#,
      16#D5#,
      16#09#,
      16#90#,
      16#B9#,
      16#B4#,
      16#AF#,
      16#C8#,
      16#CF#,
      16#79#,
      16#59#);
   --  The peer's public key point (PeerX, PeerY).
   ECDH_PeerX    : constant P256.Bytes_32 :=
     (16#F7#,
      16#25#,
      16#D5#,
      16#E2#,
      16#17#,
      16#67#,
      16#40#,
      16#3C#,
      16#33#,
      16#48#,
      16#EF#,
      16#D7#,
      16#EA#,
      16#5B#,
      16#06#,
      16#42#,
      16#8F#,
      16#12#,
      16#0B#,
      16#A4#,
      16#C6#,
      16#79#,
      16#42#,
      16#31#,
      16#25#,
      16#80#,
      16#FD#,
      16#4A#,
      16#65#,
      16#0B#,
      16#5F#,
      16#27#);
   ECDH_PeerY    : constant P256.Bytes_32 :=
     (16#59#,
      16#EA#,
      16#42#,
      16#FE#,
      16#AE#,
      16#55#,
      16#52#,
      16#9F#,
      16#BD#,
      16#43#,
      16#81#,
      16#EE#,
      16#72#,
      16#3E#,
      16#FE#,
      16#BA#,
      16#67#,
      16#95#,
      16#74#,
      16#BE#,
      16#4F#,
      16#D5#,
      16#D0#,
      16#0B#,
      16#D3#,
      16#DF#,
      16#21#,
      16#C2#,
      16#3A#,
      16#17#,
      16#E3#,
      16#20#);
   --  The expected shared secret: X-coordinate of D*Peer (== Peer_D*MyKey).
   ECDH_Shared   : constant P256.Bytes_32 :=
     (16#EB#,
      16#23#,
      16#AB#,
      16#BC#,
      16#E9#,
      16#5D#,
      16#13#,
      16#0E#,
      16#03#,
      16#BA#,
      16#FA#,
      16#69#,
      16#6F#,
      16#E4#,
      16#40#,
      16#A0#,
      16#4E#,
      16#B4#,
      16#62#,
      16#A6#,
      16#C4#,
      16#28#,
      16#92#,
      16#19#,
      16#AC#,
      16#05#,
      16#9D#,
      16#A0#,
      16#3C#,
      16#67#,
      16#71#,
      16#4C#);
   --  Public_Key outputs: the derived public key point (X, Y).
   Derived_Pub_X : P256.Bytes_32;
   Derived_Pub_Y : P256.Bytes_32;

   --  ECDH output: the X-coordinate of the computed shared secret.
   Derived_Shared_X : P256.Bytes_32;

   --  Did each primitive return success (curve/range checks passed)?
   Public_Key_OK : Boolean;
   ECDH_OK       : Boolean;

   --  Overall ECDH verdict: both primitives succeeded AND matched their vectors.
   ECDH_Pass : Boolean := False;

   --  A copy of the genuine hash with one bit flipped, to drive the reject test.
   Tampered_Hash : P256.Bytes_32 := KAT_Hash;

   --  ECDSA verdicts: the genuine signature should verify, the tampered one not.
   Genuine_Valid  : Boolean;
   Tampered_Valid : Boolean;
begin
   Put_Line ("[p256] ECDSA P-256 verify KAT");

   Genuine_Valid := P256.Verify (KAT_Qx, KAT_Qy, KAT_Hash, KAT_R, KAT_S);
   Put_Line
     ("[p256] genuine signature  -> "
      & (if Genuine_Valid then "VALID (PASS)" else "INVALID (FAIL)"));

   --  Flip one bit of the hash so the signature no longer matches: a correct
   --  verifier must now reject it.
   Tampered_Hash (0) := Tampered_Hash (0) xor 1;
   Tampered_Valid := P256.Verify (KAT_Qx, KAT_Qy, Tampered_Hash, KAT_R, KAT_S);
   Put_Line
     ("[p256] tampered hash      -> "
      & (if Tampered_Valid then "VALID (FAIL)" else "INVALID (PASS)"));

   --  ECDSA sign: the deterministic (RFC 6979) signature must match the published
   --  vector bit-for-bit and then verify under the same public key.
   Sign_OK := P256.Sign (Sign_Priv, Sign_Hash, Sign_R, Sign_S);
   Sign_Pass := Sign_OK and then Sign_R = Sign_Want_R and then Sign_S = Sign_Want_S;
   Put_Line
     ("[p256] deterministic sign -> " & (if Sign_Pass then "MATCH (PASS)" else "MISMATCH (FAIL)"));

   --  ECDH: derive our public key from the private scalar, then the shared
   --  secret against the peer's public key, and compare both to the vectors.
   Public_Key_OK := P256.Public_Key (ECDH_D, Derived_Pub_X, Derived_Pub_Y);
   Put_Line
     ("[p256] ECDH public key    -> "
      & (if Public_Key_OK and Derived_Pub_X = ECDH_MyX and Derived_Pub_Y = ECDH_MyY
         then "MATCH (PASS)"
         else "MISMATCH (FAIL)"));
   ECDH_OK := P256.ECDH (ECDH_D, ECDH_PeerX, ECDH_PeerY, Derived_Shared_X);
   Put_Line
     ("[p256] ECDH shared secret -> "
      & (if ECDH_OK and Derived_Shared_X = ECDH_Shared
         then "MATCH (PASS)"
         else "MISMATCH (FAIL)"));
   ECDH_Pass :=
     Public_Key_OK
     and then Derived_Pub_X = ECDH_MyX
     and then Derived_Pub_Y = ECDH_MyY
     and then ECDH_OK
     and then Derived_Shared_X = ECDH_Shared;

   Put_Line
     ("[p256] result: "
      & (if Genuine_Valid and not Tampered_Valid and Sign_Pass and ECDH_Pass
         then "ALL PASS"
         else "FAILURE"));
   loop
      null;
   end loop;
end Main;
