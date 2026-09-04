package body ESP32S3.RMT.Math
  with SPARK_Mode => On
is

   -------------
   -- Divider --
   -------------

   function Divider (Resolution_Hz : Positive) return Natural is
      Div : constant Natural := Src_Hz / Resolution_Hz;
   begin
      if Div > 255 then
         raise Constraint_Error
           with "RMT resolution too low (min ~314 kHz with the 8-bit divider)";
      end if;
      return Natural'Max (1, Div);
   end Divider;

end ESP32S3.RMT.Math;
