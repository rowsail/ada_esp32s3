package body ESP32S3.GT911.Interrupts is

   use type ESP32S3.GPIO.Pad_Number;   --  "=" against No_Pin

   ------------
   -- Attach --
   ------------

   procedure Attach
     (Dev    : Device;
      Action : Callback;
      On     : Trigger := ESP32S3.GPIO.Interrupts.Rising_Edge) is
   begin
      if Dev.Int_Pin = ESP32S3.GPIO.No_Pin then
         return;   --  no INT line wired -- nothing to arm
      end if;

      --  Dev.Int_Pin is a real pin here; convert away the No_Pin possibility
      --  (a dynamic value, so this is a run-time predicate check, not static).
      declare
         Pin : constant ESP32S3.GPIO.Pin_Id := ESP32S3.GPIO.Pin_Id (Dev.Int_Pin);
      begin
         --  Floating input: the chip drives INT push-pull, and the line
         --  doubles as its address strap -- no pull from this side.
         ESP32S3.GPIO.Configure (Pin, Mode => ESP32S3.GPIO.Input, Pull => ESP32S3.GPIO.Floating);
         ESP32S3.GPIO.Interrupts.Enable (Pin, On => On, Action => Action);
      end;
   end Attach;

   ------------
   -- Detach --
   ------------

   procedure Detach (Dev : Device) is
   begin
      if Dev.Int_Pin = ESP32S3.GPIO.No_Pin then
         return;
      end if;
      ESP32S3.GPIO.Interrupts.Disable (ESP32S3.GPIO.Pin_Id (Dev.Int_Pin));
   end Detach;

end ESP32S3.GT911.Interrupts;
