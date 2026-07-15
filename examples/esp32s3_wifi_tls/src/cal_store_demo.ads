--  Reference PHY RF-calibration store for the wifi_tls example.
--
--  Demonstrates ESP32S3.WiFi.Set_Cal_Store: on the first boot the radio runs a
--  FULL calibration and Store prints the resulting 1904-byte baseline; paste
--  that into Baseline below and set Present => True, and the next boot loads it
--  and runs a fast PARTIAL calibration instead ("RF cal PARTIAL (stored
--  baseline)").  The blob embeds this chip's MAC, so the driver ignores it on a
--  different board (it recalibrates).
--
--  The hooks are library-level and closure-free (No_Implicit_Dynamic_Code): main
--  registers them by 'Access.  A production store would persist Baseline in
--  non-volatile memory (a flash partition) instead of a source constant.
with ESP32S3.WiFi;

package Cal_Store_Demo is

   --  Load: hand the driver the stored baseline (True) or nothing (False).
   function Load (Blob : out ESP32S3.WiFi.Cal_Blob) return Boolean;

   --  Store: print a freshly-produced FULL-cal baseline for capture.
   procedure Store (Blob : ESP32S3.WiFi.Cal_Blob);

end Cal_Store_Demo;
