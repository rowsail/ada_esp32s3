--  CRC32C (Castagnoli, polynomial 0x1EDC6F41, reflected) -- the checksum ext4
--  uses for the metadata_csum feature (superblock, group descriptors, inodes,
--  directory tails, extent blocks, bitmaps, and the journal).
--
--  `Update` is the raw building block (continue from a seed); ext4 callers seed
--  it with feature-specific values.  `Checksum` is the standard one-shot form
--  (init ~0, final xor ~0) -- self-test: Checksum ("123456789") = 16#E306_9283#.

package ESP32S3.Ext4.CRC32C is

   --  Continue a CRC32C over Data starting from Seed; returns the running CRC.
   function Update (Seed : U32; Data : Byte_Array) return U32;

   --  Standard CRC32C of Data (init = all-ones, final xor = all-ones).
   function Checksum (Data : Byte_Array) return U32;

end ESP32S3.Ext4.CRC32C;
