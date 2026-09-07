with X509;

--  Certificate signature verification: ties the X.509 parser to the hardware RSA
--  accelerator, SPARKNaCl's SHA-2 + Ed25519, and the pure-Ada P-256.  Covers
--  RSASSA-PKCS1-v1.5 (SHA-256/384/512), RSASSA-PSS (SHA-256), ECDSA/P-256
--  (SHA-256/384) and Ed25519 -- the signature schemes seen in real certificate
--  chains and TLS 1.3 CertificateVerify.

package Cert_Verify is

   --  One distinct type per ROLE an argument plays.  Every entry point below
   --  used to take three or four X509.Byte_Array in a row -- one type, one
   --  mode -- so a positional call could transpose the signature with the
   --  message, or x with y, and nothing would catch it: not the compiler, not
   --  SPARK.  It fails CLOSED (a swap makes verification return False, never
   --  True), so it cannot forge a signature, but it turns authentication off in
   --  the rejecting direction, which is a miserable bug to find in a chain.
   --
   --  These are DERIVED types, not subtypes: same representation, so a
   --  conversion is a view and not a copy, but distinct enough that no two
   --  arguments of any one call can be interchanged.  They do not stop a caller
   --  converting the WRONG slice -- nothing can -- but the conversion names the
   --  role at the call site, so a mismatch reads as wrong locally instead of
   --  being invisible.
   type Signed_Bytes    is new X509.Byte_Array;  --  the TBS / transcript signed
   type Signature_Bytes is new X509.Byte_Array;  --  signature: raw, PSS block, or DER
   type Modulus_Bytes   is new X509.Byte_Array;  --  RSA modulus (may carry a 0x00 sign byte)
   type Exponent_Bytes  is new X509.Byte_Array;  --  RSA public exponent
   type Coord_X_Bytes   is new X509.Byte_Array;  --  EC affine public-key X
   type Coord_Y_Bytes   is new X509.Byte_Array;  --  ... and Y
   type Ed_Key_Bytes    is new X509.Byte_Array;  --  Ed25519 raw 32-byte public key

   --  True iff Signature is a valid RSASSA-PKCS1-v1.5 signature over TBS under the
   --  RSA public key (Modulus, Exponent) -- each a big-endian byte string as it
   --  appears in a certificate (the modulus may carry a leading 0x00 sign byte).
   --  Uses the "encode and compare" check (RFC 8017): hash TBS, RSA-recover the
   --  padded block with the public exponent, and compare it byte-for-byte to a
   --  freshly built PKCS#1 block -- so there is no padding to mis-parse.  One
   --  entry per digest used by real CA signatures.
   function RSA_PKCS1_SHA256
     (TBS : Signed_Bytes; Signature : Signature_Bytes;
      Modulus : Modulus_Bytes; Exponent : Exponent_Bytes) return Boolean;
   function RSA_PKCS1_SHA384
     (TBS : Signed_Bytes; Signature : Signature_Bytes;
      Modulus : Modulus_Bytes; Exponent : Exponent_Bytes) return Boolean;
   function RSA_PKCS1_SHA512
     (TBS : Signed_Bytes; Signature : Signature_Bytes;
      Modulus : Modulus_Bytes; Exponent : Exponent_Bytes) return Boolean;

   --  Verify an RSASSA-PSS signature (MGF1 with SHA-256, salt length 32) over
   --  Message under the RSA public key (Modulus, Exponent).  This is the scheme
   --  TLS 1.3 uses for a CertificateVerify made with an RSA key (rsa_pss_rsae_*);
   --  PKCS#1 v1.5 is not allowed there.  True iff the signature verifies.
   function RSA_PSS_SHA256
     (Message : Signed_Bytes; Signature : Signature_Bytes;
      Modulus : Modulus_Bytes; Exponent : Exponent_Bytes) return Boolean;

   --  Verify an ECDSA/P-256 signature over Message.  Sig_DER is the DER
   --  ECDSA-Sig-Value SEQUENCE { r INTEGER, s INTEGER } as it appears in a
   --  certificate or a TLS CertificateVerify; Pub_X, Pub_Y are the 32-byte
   --  big-endian affine public-key coordinates.  The *_SHA256 / *_SHA384 variants
   --  hash Message with that digest first (SHA-384 is left-truncated to 256 bits,
   --  as ECDSA requires).  True iff the signature verifies (pure-Ada P256).
   function ECDSA_P256_SHA256
     (Message : Signed_Bytes; Sig_DER : Signature_Bytes;
      Pub_X : Coord_X_Bytes; Pub_Y : Coord_Y_Bytes) return Boolean;
   function ECDSA_P256_SHA384
     (Message : Signed_Bytes; Sig_DER : Signature_Bytes;
      Pub_X : Coord_X_Bytes; Pub_Y : Coord_Y_Bytes) return Boolean;

   --  Verify an ECDSA/P-384 signature over Message (Sig_DER the DER
   --  ECDSA-Sig-Value; Pub_X, Pub_Y the 48-byte big-endian coordinates).  The
   --  digest is the full 48-byte SHA-384 (qlen = hlen = 384, no truncation) --
   --  the scheme the public DoT/DoH roots sign with.  Pure-Ada P384.
   function ECDSA_P384_SHA384
     (Message : Signed_Bytes; Sig_DER : Signature_Bytes;
      Pub_X : Coord_X_Bytes; Pub_Y : Coord_Y_Bytes) return Boolean;

   --  Verify an Ed25519 (RFC 8032 / PureEdDSA) signature over Message.  Signature
   --  is the 64-byte detached signature, Pub_Key the 32-byte raw public key as it
   --  appears in an Ed25519 certificate.  True iff the signature verifies.
   function Ed25519_Verify
     (Message : Signed_Bytes; Signature : Signature_Bytes;
      Pub_Key : Ed_Key_Bytes) return Boolean;

end Cert_Verify;
