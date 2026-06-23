with Ada.Unchecked_Conversion;
with Interfaces; use Interfaces;

package body ESP32S3.Fonts is

   --  Fixed-size views overlaid on the imported atlas arrays (only valid spans
   --  are indexed: metrics < Count, offsets/bytes within the real data).
   type U8_View  is array (Natural range 0 .. 262_143) of Unsigned_8;
   type I8_View  is array (Natural range 0 .. 1_023)   of Integer_8;
   type U16_View is array (Natural range 0 .. 1_023)   of Unsigned_16;
   type U8_Ptr  is access all U8_View;
   type I8_Ptr  is access all I8_View;
   type U16_Ptr is access all U16_View;
   function To_U8  is new Ada.Unchecked_Conversion (System.Address, U8_Ptr);
   function To_I8  is new Ada.Unchecked_Conversion (System.Address, I8_Ptr);
   function To_U16 is new Ada.Unchecked_Conversion (System.Address, U16_Ptr);

   function Glyph_Adv (F : Font; G : Natural) return Natural is
     (Natural (To_U8 (F.Adv) (G)));
   function Glyph_W (F : Font; G : Natural) return Natural is
     (Natural (To_U8 (F.W) (G)));
   function Glyph_H (F : Font; G : Natural) return Natural is
     (Natural (To_U8 (F.H) (G)));
   function Glyph_XOff (F : Font; G : Natural) return Integer is
     (Integer (To_I8 (F.XOff) (G)));
   function Glyph_YOff (F : Font; G : Natural) return Integer is
     (Integer (To_I8 (F.YOff) (G)));

   --------------
   -- Coverage --
   --------------

   function Coverage (F : Font; G : Natural; Index : Natural) return Natural is
      Off  : constant Natural    := Natural (To_U16 (F.Off) (G));
      Bits : constant U8_Ptr     := To_U8 (F.Bits);
      Byte : Unsigned_8;
   begin
      if F.Bpp = 1 then                       --  1-bit, 8 px/byte, MSB first
         Byte := Bits (Off + Index / 8);
         return (if (Natural (Byte) / 2 ** (7 - Index mod 8)) mod 2 = 1
                 then 15 else 0);
      else                                    --  4-bit, 2 px/byte
         Byte := Bits (Off + Index / 2);
         return (if Index mod 2 = 0
                 then Natural (Byte) / 16 else Natural (Byte) mod 16);
      end if;
   end Coverage;

   ----------------
   -- Text_Width --
   ----------------

   function Text_Width (F : Font; Str : String) return Natural is
      W : Natural := 0;
   begin
      for Ch of Str loop
         declare
            Code : constant Natural := Character'Pos (Ch);
         begin
            if Has_Glyph (F, Code) then
               W := W + Glyph_Adv (F, Code - F.First);
            end if;
         end;
      end loop;
      return W;
   end Text_Width;

end ESP32S3.Fonts;
