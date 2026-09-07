package body ESP32S3.Strings with SPARK_Mode => On is

   function Image (Value : Natural) return String is
      Text : constant String := Natural'Image (Value);
   begin
      --  RM 3.5(30): an integer 'Image is a leading blank (the sign position,
      --  blank when nonnegative) followed by decimal digits with no leading
      --  zeros.  For 0 .. 2147483647 that is 2 .. 11 characters.  The prover
      --  has no model of 'Image, so the language's guarantee is stated here.
      pragma Assume (Text'Length in 2 .. 11);
      return Text (Text'First + 1 .. Text'Last);
   end Image;

   function Image_Signed (Value : Integer) return String is
      Text : constant String := Integer'Image (Value);
   begin
      --  As above, plus the negative case: '-' then digits, so 2 .. 11 again.
      pragma Assume (Text'Length in 2 .. 11);
      if Text (Text'First) = ' ' then
         return Text (Text'First + 1 .. Text'Last);
      end if;
      return Text;
   end Image_Signed;

end ESP32S3.Strings;
