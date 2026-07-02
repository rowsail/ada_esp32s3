with Interfaces; use Interfaces;

package body ESP32S3.Ext4 is

   function Get_U8 (B : Byte_Array; Off : Natural) return U8
   is (B (B'First + Off));

   function Get_U16 (B : Byte_Array; Off : Natural) return U16
   is (U16 (B (B'First + Off)) or Shift_Left (U16 (B (B'First + Off + 1)), 8));

   function Get_U32 (B : Byte_Array; Off : Natural) return U32
   is (U32 (B (B'First + Off))
       or Shift_Left (U32 (B (B'First + Off + 1)), 8)
       or Shift_Left (U32 (B (B'First + Off + 2)), 16)
       or Shift_Left (U32 (B (B'First + Off + 3)), 24));

   function Get_U64 (B : Byte_Array; Off : Natural) return U64
   is (U64 (Get_U32 (B, Off)) or Shift_Left (U64 (Get_U32 (B, Off + 4)), 32));

   procedure Put_U8 (B : in out Byte_Array; Off : Natural; V : U8) is
   begin
      B (B'First + Off) := V;
   end Put_U8;

   procedure Put_U16 (B : in out Byte_Array; Off : Natural; V : U16) is
   begin
      B (B'First + Off) := U8 (V and 16#FF#);
      B (B'First + Off + 1) := U8 (Shift_Right (V, 8) and 16#FF#);
   end Put_U16;

   procedure Put_U32 (B : in out Byte_Array; Off : Natural; V : U32) is
   begin
      for I in 0 .. 3 loop
         B (B'First + Off + I) := U8 (Shift_Right (V, 8 * I) and 16#FF#);
      end loop;
   end Put_U32;

   procedure Put_U64 (B : in out Byte_Array; Off : Natural; V : U64) is
   begin
      for I in 0 .. 7 loop
         B (B'First + Off + I) := U8 (Shift_Right (V, 8 * I) and 16#FF#);
      end loop;
   end Put_U64;

   function Get_U32_BE (B : Byte_Array; Off : Natural) return U32
   is (Shift_Left (U32 (B (B'First + Off)), 24)
       or Shift_Left (U32 (B (B'First + Off + 1)), 16)
       or Shift_Left (U32 (B (B'First + Off + 2)), 8)
       or U32 (B (B'First + Off + 3)));

   procedure Put_U32_BE (B : in out Byte_Array; Off : Natural; V : U32) is
   begin
      for I in 0 .. 3 loop
         B (B'First + Off + I) := U8 (Shift_Right (V, 8 * (3 - I)) and 16#FF#);
      end loop;
   end Put_U32_BE;

end ESP32S3.Ext4;
