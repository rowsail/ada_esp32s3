with System.Storage_Elements; use System.Storage_Elements;
with Interfaces;              use Interfaces;

--  Pure size-class + bit math of the TLSF allocator (Tlsf_Core), split out with
--  SPARK contracts so gnatprove can machine-check it.  The allocator body proper
--  manipulates raw addresses / access-via-Unchecked_Conversion (outside SPARK's
--  memory model), but THIS -- the O(1)-locate arithmetic that decides which
--  segregated-list bucket a size maps to -- is pure integer/bit logic, and its
--  correctness is what keeps the bucket indices in range (a wrong FL/SL would
--  index Heads / SL_Bitmap out of bounds).  Same constants Tlsf_Core uses; the
--  allocator body calls these instead of carrying its own copies.
package Tlsf_Math with SPARK_Mode => On is

   --  ---- geometry (must match Tlsf_Core's block/bucket layout) -------------
   Align       : constant Storage_Count := 16;
   SL_Log2     : constant := 5;
   SL_Count    : constant := 2 ** SL_Log2;        --  32 second-level lists
   FL_Shift    : constant := SL_Log2 + 4;          --  align-log2 = 4  -> 9
   Small_Block : constant Storage_Count := 2 ** FL_Shift;   --  512
   FL_Count    : constant := 25;                   --  first-level classes

   --  Largest request Mapping accepts: keeps the first-level class FL below
   --  FL_Count.  FL = FLS(size) - (FL_Shift - 1); FL <= FL_Count - 1 needs
   --  FLS(size) <= 32, i.e. size < 2**33 -- far above any real heap (and above
   --  Storage_Count'Last on a 32-bit target, so it never actually binds there).
   --  Named numbers (universal_integer), so they are exact regardless of the
   --  target's Storage_Count width.  The preconditions promote Size to
   --  Long_Long_Integer before comparing: on a 32-bit target Storage_Count'Last
   --  (2**31-1) is below both, so the bounds are vacuously true there, and
   --  crucially the 2**32 / 2**33 literals never have to fit in Storage_Count
   --  (which would be a compile-time constraint error).
   Max_Size   : constant := 2 ** 33 - 1;   --  Mapping's ceiling (keeps FL < FL_Count)
   Max_Search : constant := 2 ** 32;       --  Mapping_Search input ceiling

   --  find-last-set: index (0-based) of the highest set bit, -1 for zero.
   function FLS (X : Unsigned_64) return Integer
     with Post =>
       (if X = 0 then FLS'Result = -1
        else FLS'Result in 0 .. 63
             and then 2 ** FLS'Result <= X
             --  guard Result = 63: 2 ** 64 wraps to 0 in Unsigned_64, and the
             --  bound X < 2 ** 64 is trivially true there anyway.
             and then (FLS'Result = 63 or else X < 2 ** (FLS'Result + 1)));

   --  find-first-set: index (0-based) of the lowest set bit, -1 for zero.
   function FFS (X : Unsigned_32) return Integer
     with Post => (if X = 0 then FFS'Result = -1 else FFS'Result in 0 .. 31);

   --  round X up to the alignment.
   function Round_Up (X : Storage_Count) return Storage_Count
     with Pre  => X <= Storage_Count'Last - (Align - 1),
          Post => Round_Up'Result mod Align = 0
                  and then Round_Up'Result >= X
                  and then Round_Up'Result <= X + (Align - 1);

   --  map a (block-payload) size to its (FL, SL) bucket.  The core safety
   --  property: the returned indices are always valid subscripts.
   procedure Mapping (Size : Storage_Count; FL, SL : out Integer)
     with Pre  => Size >= 0 and then Long_Long_Integer (Size) <= Max_Size,
          Post => FL in 0 .. FL_Count - 1 and then SL in 0 .. SL_Count - 1;

   --  round a request up so ANY block in the chosen bucket fits, then map.
   procedure Mapping_Search (Size : in out Storage_Count; FL, SL : out Integer)
     with Pre  => Size >= 0 and then Long_Long_Integer (Size) <= Max_Search,
          Post => FL in 0 .. FL_Count - 1 and then SL in 0 .. SL_Count - 1
                  and then Size >= Size'Old;

end Tlsf_Math;
