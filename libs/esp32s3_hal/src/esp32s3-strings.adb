package body ESP32S3.Strings is

   function Image (Value : Natural) return String is
      Text : constant String := Natural'Image (Value);
   begin
      return Text (Text'First + 1 .. Text'Last);
   end Image;

   function Image_Signed (Value : Integer) return String is
      Text : constant String := Integer'Image (Value);
   begin
      if Text (Text'First) = ' ' then
         return Text (Text'First + 1 .. Text'Last);
      end if;
      return Text;
   end Image_Signed;

end ESP32S3.Strings;
