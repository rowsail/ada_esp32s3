with Interfaces;

--  ECDSA on the NIST P-256 curve (secp256r1 / prime256v1), in pure Ada -- no chip
--  dependency.  Verification and ECDH operate entirely on public values, so
--  ordinary variable-time code is fine there.  Signing (below) is deterministic
--  per RFC 6979, so it needs no per-signature randomness and is reproducible.
--
--  256-bit integers are held as eight little-endian 32-bit limbs; the field and
--  order arithmetic is Montgomery (CIOS), with all Montgomery constants derived on
--  the fly from the hard-coded curve parameters.  Point arithmetic is Jacobian.

package P256 is

   subtype Byte is Interfaces.Unsigned_8;
   type Bytes is array (Natural range <>) of Byte;
   subtype Bytes_32 is Bytes (0 .. 31);

   --  Verify an ECDSA signature (r, s) of the message digest Hash under the public
   --  key (Pub_X, Pub_Y).  All five inputs are 32-byte big-endian integers.  Hash
   --  is the message digest reduced to 256 bits: for ECDSA-with-SHA-256 it is the
   --  32-byte digest; for SHA-384/512 the caller passes the leftmost 32 bytes.
   --  Returns True iff the signature verifies.
   function Verify (Pub_X, Pub_Y : Bytes_32; Hash : Bytes_32; R, S : Bytes_32) return Boolean;

   --  ECDH key exchange on P-256 (for TLS ECDHE with secp256r1).  Public_Key sets
   --  (Pub_X, Pub_Y) = Priv*G -- the uncompressed public key to put in a key_share.
   --  ECDH sets Shared_X = the X-coordinate of Priv*Peer -- the shared secret.  Both
   --  take/return 32-byte big-endian values and return False on invalid input (Priv
   --  not in [1, n-1], or Peer not a valid curve point).
   --
   --  NOTE: the scalar multiplication here is variable-time.  TLS ECDHE uses a fresh
   --  ephemeral scalar per handshake, which limits exposure, but a constant-time
   --  ladder is the proper hardening and is left as a follow-up.
   function Public_Key (Priv : Bytes_32; Pub_X, Pub_Y : out Bytes_32) return Boolean;
   function ECDH
     (Priv : Bytes_32; Peer_X, Peer_Y : Bytes_32; Shared_X : out Bytes_32) return Boolean;

   --  Produce an ECDSA signature (R, S) over the 32-byte message digest Hash with
   --  the private key Priv (a 32-byte big-endian scalar in [1, n-1]).  The nonce is
   --  derived deterministically from Priv and Hash (RFC 6979, HMAC-SHA-256), so the
   --  same inputs always yield the same signature and no RNG is required -- which
   --  also removes the catastrophic nonce-reuse failure mode.  R and S are 32-byte
   --  big-endian.  Returns False only if Priv is out of range.
   function Sign (Priv, Hash : Bytes_32; R, S : out Bytes_32) return Boolean;

end P256;
