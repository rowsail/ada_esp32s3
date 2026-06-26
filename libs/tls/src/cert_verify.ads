with X509;

--  Certificate signature verification: ties the X.509 parser to the hardware RSA
--  accelerator, SPARKNaCl's SHA-2 + Ed25519, and the pure-Ada P-256.  Covers
--  RSASSA-PKCS1-v1.5 (SHA-256/384/512), RSASSA-PSS (SHA-256), ECDSA/P-256
--  (SHA-256/384) and Ed25519 -- the signature schemes seen in real certificate
--  chains and TLS 1.3 CertificateVerify.
package Cert_Verify is

   --  True iff Signature is a valid RSASSA-PKCS1-v1.5 signature over TBS under the
   --  RSA public key (Modulus, Exponent) -- each a big-endian byte string as it
   --  appears in a certificate (the modulus may carry a leading 0x00 sign byte).
   --  Uses the "encode and compare" check (RFC 8017): hash TBS, RSA-recover the
   --  padded block with the public exponent, and compare it byte-for-byte to a
   --  freshly built PKCS#1 block -- so there is no padding to mis-parse.  One
   --  entry per digest used by real CA signatures.
   function RSA_PKCS1_SHA256
     (TBS, Signature, Modulus, Exponent : X509.Byte_Array) return Boolean;
   function RSA_PKCS1_SHA384
     (TBS, Signature, Modulus, Exponent : X509.Byte_Array) return Boolean;
   function RSA_PKCS1_SHA512
     (TBS, Signature, Modulus, Exponent : X509.Byte_Array) return Boolean;

   --  Verify an RSASSA-PSS signature (MGF1 with SHA-256, salt length 32) over
   --  Message under the RSA public key (Modulus, Exponent).  This is the scheme
   --  TLS 1.3 uses for a CertificateVerify made with an RSA key (rsa_pss_rsae_*);
   --  PKCS#1 v1.5 is not allowed there.  True iff the signature verifies.
   function RSA_PSS_SHA256
     (Message, Signature, Modulus, Exponent : X509.Byte_Array) return Boolean;

   --  Verify an ECDSA/P-256 signature over Message.  Sig_DER is the DER
   --  ECDSA-Sig-Value SEQUENCE { r INTEGER, s INTEGER } as it appears in a
   --  certificate or a TLS CertificateVerify; Pub_X, Pub_Y are the 32-byte
   --  big-endian affine public-key coordinates.  The *_SHA256 / *_SHA384 variants
   --  hash Message with that digest first (SHA-384 is left-truncated to 256 bits,
   --  as ECDSA requires).  True iff the signature verifies (pure-Ada P256).
   function ECDSA_P256_SHA256
     (Message, Sig_DER, Pub_X, Pub_Y : X509.Byte_Array) return Boolean;
   function ECDSA_P256_SHA384
     (Message, Sig_DER, Pub_X, Pub_Y : X509.Byte_Array) return Boolean;

   --  Verify an Ed25519 (RFC 8032 / PureEdDSA) signature over Message.  Signature
   --  is the 64-byte detached signature, Pub_Key the 32-byte raw public key as it
   --  appears in an Ed25519 certificate.  True iff the signature verifies.
   function Ed25519_Verify
     (Message, Signature, Pub_Key : X509.Byte_Array) return Boolean;

end Cert_Verify;
