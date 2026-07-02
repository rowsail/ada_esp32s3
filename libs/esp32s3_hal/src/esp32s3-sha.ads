with Interfaces;

--  ESP32-S3 SHA accelerator -- hardware SHA-1 / SHA-224 / SHA-256 of a byte
--  message.
--
--  The accelerator is a single shared resource, so a protected object serialises
--  the message-load / start / read handshake, making concurrent Hash calls from
--  different tasks safe.  All three variants share the same 512-bit block and
--  padding; they differ only in the hardware MODE and the digest length.  (The
--  block hardware also does SHA-384/512, which use a 1024-bit block and are not
--  exposed here.)  Register pokes, no finalization -- works under every runtime
--  profile.

package ESP32S3.SHA is

   type Byte_Array is array (Natural range <>) of Interfaces.Unsigned_8;

   subtype SHA1_Digest is Byte_Array (0 .. 19);   --  20-byte (160-bit) digest
   subtype SHA224_Digest is Byte_Array (0 .. 27);   --  28-byte (224-bit) digest
   subtype SHA256_Digest is Byte_Array (0 .. 31);   --  32-byte (256-bit) digest

   --  Hardware hashes of Data (any length, padded internally).
   function Hash_1 (Data : Byte_Array) return SHA1_Digest;
   function Hash_224 (Data : Byte_Array) return SHA224_Digest;
   function Hash_256 (Data : Byte_Array) return SHA256_Digest;

end ESP32S3.SHA;
