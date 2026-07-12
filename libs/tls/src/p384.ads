with Interfaces;

--  ECDSA signature VERIFICATION on the NIST P-384 curve (secp384r1), in pure
--  Ada -- the sibling of P256, built for the same reason X509/Chain_Verify
--  exist: to authenticate a certificate whose signature is ECDSA/P-384.  The
--  public DoT/DoH roots (SSL.com ECC, Google GTS R4) are P-384, so verifying
--  a chain up to a pinned P-384 root needs this.
--
--  Verification operates only on public values, so ordinary variable-time
--  code is fine.  Only Verify is provided: signing and ECDH on P-384 are not
--  needed (the TLS handshake uses P-256 / x25519), and leaving them out keeps
--  the surface small.
--
--  384-bit integers are held as twelve little-endian 32-bit limbs; field and
--  order arithmetic is Montgomery (CIOS); point arithmetic is Jacobian --
--  the same construction as P256, widened to twelve limbs.
package P384 is

   subtype Byte is Interfaces.Unsigned_8;
   type Bytes is array (Natural range <>) of Byte;
   subtype Bytes_48 is Bytes (0 .. 47);

   --  Verify an ECDSA signature (R, S) of the message digest Hash under the
   --  public key (Pub_X, Pub_Y).  All five inputs are 48-byte big-endian
   --  integers.  Hash is the message digest reduced to 384 bits: for
   --  ECDSA-with-SHA-384 it is the 48-byte digest; for SHA-512 the caller
   --  passes the leftmost 48 bytes.  Returns True iff the signature verifies.
   function Verify
     (Pub_X, Pub_Y : Bytes_48; Hash : Bytes_48; R, S : Bytes_48) return Boolean;

end P384;
