pragma Warnings (Off);
with System;
with Ada.Real_Time; use Ada.Real_Time;

--  Reusable driver from the shared HAL (libs/esp32s3_hal); this example
--  no longer pokes registers directly -- it drives GPIO0 through ESP32S3.GPIO.
with ESP32S3.GPIO;
with ESP32S3.Log; use ESP32S3.Log;

package body GPIO is

   Pin : constant ESP32S3.GPIO.Pin_Id := 0;

   --  Library-level task: toggle GPIO0 every 250 ms (2 Hz square wave) on core 0,
   --  logging each transition over the USB-Serial-JTAG console.
   task Blinker
     with Priority => System.Priority'Last - 1, CPU => 1;
   task body Blinker is
      Period : constant Time_Span := Milliseconds (250);
      Next   : Time;
      High   : Boolean := False;
   begin
      ESP32S3.GPIO.Configure (Pin, ESP32S3.GPIO.Output, Drive => ESP32S3.GPIO.Drive_Strong);
      Next := Clock + Period;
      loop
         delay until Next;
         High := not High;
         ESP32S3.GPIO.Write (Pin, High);
         Put_Line ("[gpio0] " & (if High then "HIGH" else "low "));
         Next := Next + Period;
      end loop;
   end Blinker;

end GPIO;
