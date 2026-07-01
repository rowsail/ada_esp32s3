package body ESP32S3.Endian is

   use Interfaces;

   function Join_LE (B0, B1, B2, B3 : U8) return U32 is
     (U32 (B0)
      or Shift_Left (U32 (B1), 8)
      or Shift_Left (U32 (B2), 16)
      or Shift_Left (U32 (B3), 24));

   procedure Split_LE (W : U32; B0, B1, B2, B3 : out U8) is
   begin
      B0 := U8 (W and 16#FF#);
      B1 := U8 (Shift_Right (W, 8)  and 16#FF#);
      B2 := U8 (Shift_Right (W, 16) and 16#FF#);
      B3 := U8 (Shift_Right (W, 24) and 16#FF#);
   end Split_LE;

   function Join_BE16 (Hi, Lo : U8) return U16 is
     (Shift_Left (U16 (Hi), 8) or U16 (Lo));

   function Join_BE32 (B0, B1, B2, B3 : U8) return U32 is
     (Shift_Left (U32 (B0), 24)
      or Shift_Left (U32 (B1), 16)
      or Shift_Left (U32 (B2), 8)
      or U32 (B3));

   procedure Split_BE16 (V : U16; Hi, Lo : out U8) is
   begin
      Hi := U8 (Shift_Right (V, 8) and 16#FF#);
      Lo := U8 (V and 16#FF#);
   end Split_BE16;

   procedure Split_BE32 (V : U32; B0, B1, B2, B3 : out U8) is
   begin
      B0 := U8 (Shift_Right (V, 24) and 16#FF#);
      B1 := U8 (Shift_Right (V, 16) and 16#FF#);
      B2 := U8 (Shift_Right (V, 8)  and 16#FF#);
      B3 := U8 (V and 16#FF#);
   end Split_BE32;

end ESP32S3.Endian;
