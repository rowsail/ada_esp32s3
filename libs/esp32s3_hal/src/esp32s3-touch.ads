with ESP32S3.GPIO;

--  ESP32-S3 capacitive touch sensor (v2): 14 channels on GPIO1 .. GPIO14.
--
--  Each channel measures the self-capacitance of its pad by counting
--  charge/discharge cycles in a fixed window; a finger near the pad raises the
--  capacitance and changes the count.  The FSM scans the enabled channels
--  continuously on the RTC timer; Read returns the latest raw count.
--
--  No tasking is required (register pokes); it lives in the RTC/SENS domain.

package ESP32S3.Touch is

   --  Touch channel n is wired to GPIO n.
   type Channel is range 1 .. 14;

   --  The GPIO a channel uses.
   function Pad (Ch : Channel) return ESP32S3.GPIO.Pin_Id;

   --  Bring the touch controller up and start the scanning FSM.  Call once.
   procedure Setup;

   --  Route channel Ch's pad into touch mode and add it to the scan.
   procedure Enable (Ch : Channel);

   --  Latest raw capacitance count for Ch (0 .. ~4 million; higher = more
   --  capacitance).  A bare pad reads a stable non-zero baseline; a touch raises
   --  it.  0 means the channel has not produced a measurement yet.
   function Read (Ch : Channel) return Natural;

   --  Touch detection: True when Ch's current count deviates from Reference by
   --  more than Margin (either direction).  Capture Reference with Read while the
   --  pad is untouched; a finger then moves the count past the margin.  (This is
   --  a software comparison on the live Read value -- simple and deterministic.)
   function Touched (Ch : Channel; Reference : Natural; Margin : Natural := 20_000) return Boolean;

end ESP32S3.Touch;
