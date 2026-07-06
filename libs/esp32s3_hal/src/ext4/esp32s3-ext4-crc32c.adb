with Interfaces; use Interfaces;

package body ESP32S3.Ext4.CRC32C with SPARK_Mode => On is

   Poly : constant U32 := 16#82F6_3B78#;   --  Castagnoli polynomial, reflected

   type Table_T is array (U8) of U32;

   function Build_Table return Table_T is
      T : Table_T;
   begin
      for I in U8 loop
         declare
            C : U32 := U32 (I);
         begin
            for K in 1 .. 8 loop
               if (C and 1) /= 0 then
                  C := Shift_Right (C, 1) xor Poly;
               else
                  C := Shift_Right (C, 1);
               end if;
            end loop;
            T (I) := C;
         end;
      end loop;
      return T;
   end Build_Table;

   Tab : constant Table_T := Build_Table;

   function Update (Seed : U32; Data : Byte_Array) return U32 is
      C : U32 := Seed;
   begin
      for B of Data loop
         C := Shift_Right (C, 8) xor Tab (U8 ((C xor U32 (B)) and 16#FF#));
      end loop;
      return C;
   end Update;

   function Checksum (Data : Byte_Array) return U32 is
   begin
      return Update (16#FFFF_FFFF#, Data) xor 16#FFFF_FFFF#;
   end Checksum;

end ESP32S3.Ext4.CRC32C;
