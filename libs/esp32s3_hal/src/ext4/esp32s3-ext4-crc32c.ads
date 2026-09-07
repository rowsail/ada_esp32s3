--  CRC32C (Castagnoli, polynomial 0x1EDC6F41, reflected) -- the checksum ext4
--  uses for the metadata_csum feature (superblock, group descriptors, inodes,
--  directory tails, extent blocks, bitmaps, and the journal).
--
--  `Update` is the raw building block (continue from a seed); ext4 callers seed
--  it with feature-specific values.  `Checksum` is the standard one-shot form
--  (init ~0, final xor ~0).
--
--  Both are specified, not merely bounded: the implementation is a 256-entry
--  table walk, and the contracts say it computes exactly what the bit-at-a-time
--  polynomial definition below computes, for every seed and every input.  That
--  is the whole correctness claim for this unit -- the table, the table's
--  construction, and the per-byte index arithmetic are all proved against a
--  reference that is short enough to read and check against the standard by
--  eye.  What used to stand behind them was a single known-answer vector
--  (Checksum ("123456789") = 16#E306_9283#); a table typo outside that one
--  input's path would have passed it and then silently mis-checksummed a
--  filesystem.

package ESP32S3.Ext4.CRC32C with SPARK_Mode => On is

   use type Interfaces.Unsigned_32;

   ---------------------------------------------------------------------------
   --  The reference definition.  This is the specification of the two
   --  operations below, and it is deliberately the naive one: shift the CRC
   --  right one bit at a time and xor the reflected polynomial back in
   --  whenever a one bit falls off the bottom.  It is also what builds the
   --  lookup table in the body, so there is exactly one definition of CRC32C
   --  here rather than a fast one and a slow one that have to be kept in step.
   ---------------------------------------------------------------------------

   Poly : constant U32 := 16#82F6_3B78#;   --  0x1EDC6F41, bit-reflected

   --  One bit of the division.
   function Step (C : U32) return U32
   is (if (C and 1) /= 0
       then Interfaces.Shift_Right (C, 1) xor Poly
       else Interfaces.Shift_Right (C, 1));

   --  One byte: fold B into the running CRC, then eight bit steps.
   function Byte_Reference (C : U32; B : U8) return U32
   is (Step (Step (Step (Step (Step (Step (Step (Step (C xor U32 (B))))))))));

   --  The reference CRC over the first N bytes of Data, starting from Seed.
   --  Recursion peels the LAST byte rather than the first, so it lines up with
   --  the way Update's loop accumulates and needs no induction lemma to
   --  connect the two.
   function Ref_Update (Seed : U32; Data : Byte_Array; N : Natural) return U32
   is (if N = 0 then Seed
       else Byte_Reference (Ref_Update (Seed, Data, N - 1),
                            Data (Data'First + N - 1)))
   with Ghost,
        Pre                => N <= Data'Length,
        Subprogram_Variant => (Decreases => N);

   ---------------------------------------------------------------------------
   --  The operations.
   ---------------------------------------------------------------------------

   --  Continue a CRC32C over Data starting from Seed; returns the running CRC.
   function Update (Seed : U32; Data : Byte_Array) return U32
     with Post => Update'Result = Ref_Update (Seed, Data, Data'Length);

   --  Standard CRC32C of Data (init = all-ones, final xor = all-ones).
   function Checksum (Data : Byte_Array) return U32
     with Post => Checksum'Result =
                    (Ref_Update (16#FFFF_FFFF#, Data, Data'Length)
                     xor 16#FFFF_FFFF#);

end ESP32S3.Ext4.CRC32C;
