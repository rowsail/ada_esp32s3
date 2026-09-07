with Interfaces; use Interfaces;

package body ESP32S3.Ext4.CRC32C with SPARK_Mode => On is

   type Table_T is array (U8) of U32;

   --  Entry I is the reference CRC of the single byte I from a zero seed --
   --  which is what makes the byte-at-a-time table walk in Update equal to
   --  eight bit steps.  Stated as a postcondition, so the table is proved to
   --  hold that (all 256 entries), not assumed to.
   function Build_Table return Table_T
     with Post => (for all I in U8 => Build_Table'Result (I) = Byte_Reference (0, I));

   function Build_Table return Table_T is
      --  Initialised up front: SPARK's flow analysis tracks whole objects, so
      --  the loop invariant below may not read a partially assigned array.
      T : Table_T := (others => 0);
   begin
      for I in U8 loop
         T (I) := Byte_Reference (0, I);
         pragma Loop_Invariant
           (for all J in U8'First .. I => T (J) = Byte_Reference (0, J));
      end loop;
      return T;
   end Build_Table;

   Tab : constant Table_T := Build_Table;

   function Update (Seed : U32; Data : Byte_Array) return U32 is
      C : U32 := Seed;
   begin
      --  Indexed rather than `for B of Data` so the invariant can name how much
      --  of Data has been folded in so far.
      for K in 0 .. Data'Length - 1 loop
         C := Shift_Right (C, 8)
              xor Tab (U8 ((C xor U32 (Data (Data'First + K))) and 16#FF#));
         --  At the end of the body, so on exit (K = Data'Length - 1) this is
         --  exactly the postcondition.  Discharging it per iteration is the
         --  table identity itself: for any X, eight bit steps of X equal
         --  X >> 8 xor (eight bit steps of X's low byte).
         pragma Loop_Invariant (C = Ref_Update (Seed, Data, K + 1));
      end loop;
      return C;
   end Update;

   function Checksum (Data : Byte_Array) return U32 is
   begin
      return Update (16#FFFF_FFFF#, Data) xor 16#FFFF_FFFF#;
   end Checksum;

end ESP32S3.Ext4.CRC32C;
