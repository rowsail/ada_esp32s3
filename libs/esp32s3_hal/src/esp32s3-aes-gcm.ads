with Interfaces;

--  AES-GCM authenticated encryption (the TLS bulk AEAD), built on the single-block
--  AES hardware: the accelerator does each AES block (counter-mode keystream and
--  the hash subkey), while CTR-XOR and the GHASH GF(2^128) authenticator are done
--  here in software.  AES-128 and AES-256 (16- or 32-byte keys), a 12-byte nonce
--  and a 16-byte tag -- the shapes TLS uses.  Lock-free / ZFP-safe.

package ESP32S3.AES.GCM is

   subtype U8 is Interfaces.Unsigned_8;
   type Byte_Array is array (Natural range <>) of U8;
   subtype Nonce is Byte_Array (0 .. 11);    --  96-bit IV (TLS)
   subtype Auth_Tag is Byte_Array (0 .. 15);    --  128-bit tag

   --  AEAD seal: Cipher := Enc(Plain) (same length), Tag authenticates AAD+Cipher.
   procedure Encrypt
     (Key    : Key_Bytes;
      IV     : Nonce;
      AAD    : Byte_Array;
      Plain  : Byte_Array;
      Cipher : out Byte_Array;
      Tag    : out Auth_Tag)
   with Pre => Supported_Key (Key) and then Cipher'Length = Plain'Length;

   --  AEAD open: verify Tag over AAD+Cipher (constant-time), then decrypt.  Ok is
   --  False on tag mismatch -- Plain is then left zeroed and must be discarded.
   procedure Decrypt
     (Key    : Key_Bytes;
      IV     : Nonce;
      AAD    : Byte_Array;
      Cipher : Byte_Array;
      Tag    : Auth_Tag;
      Plain  : out Byte_Array;
      Ok     : out Boolean)
   with Pre => Supported_Key (Key) and then Plain'Length = Cipher'Length;

end ESP32S3.AES.GCM;
