with ESP32S3.GPIO;
with ESP32S3.ADC;
with Lisp;       use Lisp;
with Lisp.Eval;

package body Lisp_HAL is

   package GPIO renames ESP32S3.GPIO;
   package ADC  renames ESP32S3.ADC;

   ADC1 : ADC.Reader;                       --  claimed once in Register

   function Pin_Of (Args : Ref) return GPIO.Pin_Id is
     (GPIO.Pin_Id (Int_Value (Car (Args))));

   --  (gpio-out PIN VAL): configure output, drive, return VAL.
   function Prim_Gpio_Out (Args : Ref) return Ref is
      Pin : constant GPIO.Pin_Id := Pin_Of (Args);
      Val : constant Ref         := Car (Cdr (Args));
   begin
      GPIO.Configure (Pin, GPIO.Output);
      GPIO.Write (Pin, Is_Truthy (Val));
      return Val;
   end Prim_Gpio_Out;

   --  (gpio-toggle PIN): flip an output pin.
   function Prim_Gpio_Toggle (Args : Ref) return Ref is
   begin
      GPIO.Toggle (Pin_Of (Args));
      return Nil;
   end Prim_Gpio_Toggle;

   --  (gpio-in PIN): configure input, return the level.
   function Prim_Gpio_In (Args : Ref) return Ref is
      Pin : constant GPIO.Pin_Id := Pin_Of (Args);
   begin
      GPIO.Configure (Pin, GPIO.Input);
      return Make_Bool (GPIO.Read (Pin));
   end Prim_Gpio_In;

   --  (adc-read CH): one ADC1 sample, 0 .. 4095.
   function Prim_Adc_Read (Args : Ref) return Ref is
      Ch : constant ADC.Channel_Index :=
             ADC.Channel_Index (Int_Value (Car (Args)));
   begin
      return Make_Int (Long_Long_Integer (ADC.Read (ADC1, Ch)));
   end Prim_Adc_Read;

   procedure Register is
   begin
      ADC.Claim (ADC1, ADC.ADC1);
      Lisp.Eval.Register_Primitive ("gpio-out",    Prim_Gpio_Out'Access);
      Lisp.Eval.Register_Primitive ("gpio-toggle", Prim_Gpio_Toggle'Access);
      Lisp.Eval.Register_Primitive ("gpio-in",     Prim_Gpio_In'Access);
      Lisp.Eval.Register_Primitive ("adc-read",    Prim_Adc_Read'Access);
   end Register;

end Lisp_HAL;
