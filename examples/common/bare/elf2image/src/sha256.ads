--  Minimal SHA-256 (FIPS 180-4) over an in-memory byte array.  Used to append
--  the image digest esptool emits.  No deps beyond Interfaces.
with Interfaces;  use Interfaces;
with Ada.Streams; use Ada.Streams;

package SHA256 is
   type Digest is array (0 .. 31) of Unsigned_8;
   function Hash (Data : Stream_Element_Array) return Digest;
end SHA256;
