with Interfaces;

--  ESP32-S3 AES accelerator -- single-block AES ECB (the building block).
--
--  The accelerator is a single shared resource, so a protected object serialises
--  the key/text load, trigger and read, making concurrent calls from different
--  tasks safe.  This exposes one-block ECB encrypt and decrypt for 128- and
--  256-bit keys (the hardware also does chaining modes).  Register pokes, no
--  finalization -- works under every runtime profile.
--
--  NOTE: the ESP32-S3 AES hardware supports only 128- and 256-bit keys -- there
--  is no 192-bit support on this silicon (selecting "AES-192" makes the engine
--  silently fall back to AES-128 on the first 16 key bytes).  192-bit keys exist
--  only on the original ESP32.  The Supported_Key precondition below makes any
--  unsupported key length a contract violation instead of a silent fallback.

package ESP32S3.AES is

   type Block is array (0 .. 15) of Interfaces.Unsigned_8;   --  128-bit block

   --  Keys of the two hardware-supported sizes (packed big to little internally).
   type Key_Bytes is array (Natural range <>) of Interfaces.Unsigned_8;
   subtype Key_128 is Key_Bytes (0 .. 15);   --  128-bit key
   subtype Key_256 is Key_Bytes (0 .. 31);   --  256-bit key

   --  The only key lengths the S3 AES engine actually implements (in bytes).
   --  Use this in the operation contracts so a wrong-sized key (e.g. a 24-byte
   --  "AES-192" key, which the hardware cannot do) is rejected rather than
   --  silently degraded.  Callers that pass the Key_128 / Key_256 subtypes
   --  satisfy it statically, so there is no run-time cost for correct code.
   function Supported_Key (Key : Key_Bytes) return Boolean
   is (Key'Length = 16 or else Key'Length = 32);

   --  Key length selects the cipher: 16 bytes => AES-128, 32 => AES-256 (use the
   --  Key_128 / Key_256 subtypes).
   function Encrypt_ECB (Key : Key_Bytes; Plain : Block) return Block
   with Pre => Supported_Key (Key);
   function Decrypt_ECB (Key : Key_Bytes; Cipher : Block) return Block
   with Pre => Supported_Key (Key);

end ESP32S3.AES;
