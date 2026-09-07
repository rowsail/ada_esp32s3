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
--  order arithmetic is Montgomery (CIOS); point arithmetic is Jacobian.  Not
--  merely "the same construction as P256, widened" -- literally the same
--  source: both instantiate the generics ECC_Bignum and ECC_Curve, this one at
--  twelve limbs and P256 at eight.  What is left in this package is P-384's
--  curve constants, its big-endian byte conversion, and Verify.
--
--  SPARK.  Proved free of run-time errors, 0 unproved (libs/tls/p384_prove.gpr).
--  It needs its own project because GNATprove proves generic INSTANCES, not
--  generics: P256's run discharges the eight-limb instantiation and says nothing
--  about this one.  That run is slow enough to sit outside book/prove/prove.sh's
--  fast pass -- see the note there.
package P384 with SPARK_Mode => On is

   subtype Byte is Interfaces.Unsigned_8;
   type Bytes is array (Natural range <>) of Byte;
   subtype Bytes_48 is Bytes (0 .. 47);

   --  An EC point and an ECDSA signature, as the PAIRS they actually are.
   --  Verify used to take five Bytes_48 in a row and every caller passed them
   --  positionally, so a transposition -- x for y, r for s, the hash into a
   --  coordinate -- compiled silently.  It fails CLOSED, so it cannot forge a
   --  signature, but it turns authentication off in the rejecting direction,
   --  which is a hard bug to find in a certificate chain.  Wrapped this way,
   --  Verify takes three parameters of three DISTINCT types and the
   --  transposition is a compile error instead.  (P256 has the same pair.)
   type Public_Point is record
      X, Y : Bytes_48;
   end record;

   type Signature is record
      R, S : Bytes_48;
   end record;

   --  Verify the ECDSA signature Sig of the message digest Hash under the
   --  public key Key.  Every component is a 48-byte big-endian integer.  Hash
   --  is the message digest reduced to 384 bits: for ECDSA-with-SHA-384 it is
   --  the 48-byte digest; for SHA-512 the caller passes the leftmost 48 bytes.
   --  Returns True iff the signature verifies.
   function Verify
     (Key : Public_Point; Sig : Signature; Hash : Bytes_48) return Boolean
     with Global => null;

end P384;
