with ESP32S3.GPIO;

package body ESP32S3.QMI8658C.Interrupts is

   use type ESP32S3.GPIO.Pad_Number;   --  "=" against No_Pin

   ------------
   -- Attach --
   ------------

   procedure Attach (Dev : Device; Action : Callback) is
   begin
      if Dev.Int_Pin = ESP32S3.GPIO.No_Pin then
         return;   --  no INT line wired -- nothing to arm
      end if;

      --  Dev.Int_Pin is a real pin here; convert away the No_Pin possibility
      --  (a dynamic value, so this is a run-time predicate check, not static).
      declare
         Pin : constant ESP32S3.GPIO.Pin_Id :=
           ESP32S3.GPIO.Pin_Id (Dev.Int_Pin);
      begin
         --  Input with a pull-down: INT idles low, the chip drives it high.
         ESP32S3.GPIO.Configure
           (Pin, Mode => ESP32S3.GPIO.Input, Pull => ESP32S3.GPIO.Pull_Down);
         ESP32S3.GPIO.Interrupts.Enable
           (Pin, On => ESP32S3.GPIO.Interrupts.Rising_Edge, Action => Action);
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

end ESP32S3.QMI8658C.Interrupts;
