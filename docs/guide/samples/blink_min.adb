--  Guide step 06 -- "A minimal application".
--
--  This file IS the code the page shows: build.py inlines it at generation
--  time, and check_samples.sh compiles it.  Edit it here, not in the HTML.
with Ada.Real_Time; use Ada.Real_Time;
with ESP32S3.GPIO;

procedure Blink_Min is
   Led : constant ESP32S3.GPIO.Pin_Id := 2;
begin
   ESP32S3.GPIO.Configure (Led, Mode => ESP32S3.GPIO.Output);
   loop
      ESP32S3.GPIO.Toggle (Led);
      delay until Clock + Milliseconds (250);
   end loop;
end Blink_Min;
