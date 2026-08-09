with Interfaces;

--  MD5 (RFC 1321), streaming, pure Ada: no heap, no tasking, safe on the
--  light runtime.
--
--  MD5 is long broken as a cryptographic hash and nothing here pretends
--  otherwise.  It earns its place because the ESP32 ROM loader's
--  SPI_FLASH_MD5 command speaks it: after an image is written, the target
--  hashes what its flash actually holds and this computes what the flash
--  SHOULD hold, and the comparison is what lets "programmed OK" mean
--  something (see ESP32S3.Esp_Loader.Read_Md5).  An integrity check against
--  accident, not an adversary.
package ESP32S3.MD5 is

   type Byte_Array is array (Positive range <>) of Interfaces.Unsigned_8;

   type Context is private;
   --  Starts ready for a fresh message; Reset returns a used one to that
   --  state.  Feed any number of Update calls, in any sized pieces.

   procedure Reset (C : out Context);

   procedure Update (C : in out Context; Data : Byte_Array);

   --  The digest of everything fed so far, as 32 lowercase hex characters --
   --  the same layout the ROM loader returns, so the two compare with "=".
   --  Works on a copy of the state: the context itself is not finalised, so
   --  a caller may take an interim digest and keep feeding.
   subtype Digest_Text is String (1 .. 32);

   function Hex_Digest (C : Context) return Digest_Text;

private

   type State_Words is array (0 .. 3) of Interfaces.Unsigned_32;
   type Block_Bytes is array (0 .. 63) of Interfaces.Unsigned_8;

   type Context is record
      State : State_Words :=
        (16#6745_2301#, 16#EFCD_AB89#, 16#98BA_DCFE#, 16#1032_5476#);
      Buf   : Block_Bytes := (others => 0);   --  a part-filled block
      Fill  : Natural := 0;                   --  bytes staged in Buf
      Total : Interfaces.Unsigned_64 := 0;    --  message length in bytes
   end record;

end ESP32S3.MD5;
