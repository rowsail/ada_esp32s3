package body ESP32S3.TWAI.Math
  with SPARK_Mode => On
is

   ---------------
   -- Prescaler --
   ---------------

   function Prescaler (Bit_Rate : Positive) return Natural is
      --  t_q = 2*(BAUD_PRESC+1) / f_apb, so the effective divisor is BRP =
      --  2*(BAUD_PRESC+1); clamp to the field's [2 .. 128] and make it even.
      BRP : Integer := Integer (Src_Hz / (Bit_Rate * Tq_Per_Bit));
   begin
      if BRP < 2 then
         BRP := 2;
      elsif BRP > 128 then
         BRP := 128;
      end if;
      BRP := (BRP / 2) * 2;                            --  make it even
      return BRP;
   end Prescaler;

end ESP32S3.TWAI.Math;
