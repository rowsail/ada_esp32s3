--  Quectel L76K proprietary PCAS commands (NMEA-framed vendor messages).
--
--  These configure the receiver by SENDING sentences to it (via the parent's
--  ESP32S3.GPS.Send, so a Tx pin must be routed in Setup).  They are SPECIFIC TO
--  THE L76K: only `with` and call this package when the module on the bus is an
--  L76K (the package itself is the "L76K only" gate).  Reference: Quectel L76K
--  GNSS Protocol Specification V1.1, section 2.3.
--
--  Status: every PCAS command is implemented, but only Set_Constellation
--  (PCAS04) has been exercised on hardware -- the others are provided for
--  completeness and are UNTESTED.

package ESP32S3.GPS.L76K is

   ----------------------------------------------------------------------------
   --  PCAS04 -- GNSS constellation selection (TESTED).  QZSS is always on.
   ----------------------------------------------------------------------------

   type Constellation is
     (GPS_Only,        --  mode 1
      BeiDou_Only,     --  mode 2
      GPS_BeiDou,      --  mode 3 (the L76K default)
      GLONASS_Only,    --  mode 4
      GPS_GLONASS,     --  mode 5
      BeiDou_GLONASS,  --  mode 6
      GPS_BeiDou_GLONASS);  --  mode 7

   --  $PCAS04,<mode> -- choose which constellations the receiver searches.
   procedure Set_Constellation (Config : Constellation);

   ----------------------------------------------------------------------------
   --  The remaining PCAS commands are implemented but UNTESTED.
   ----------------------------------------------------------------------------

   --  PCAS01 -- NMEA port baud rate.  NOTE: after this takes effect the receiver
   --  talks at the new rate; reconfigure the host UART (ESP32S3.GPS only sets
   --  the rate at Setup) to keep receiving.
   type Baud_Setting is
     (B_4800, B_9600, B_19200, B_38400, B_57600, B_115200);  --  modes 0..5
   procedure Set_Baud_Rate (Rate : Baud_Setting);   --  $PCAS01,<n>  UNTESTED

   --  PCAS02 -- positioning (fix) rate.  Rates above 1 Hz require single NMEA
   --  output and 115200 baud (datasheet note).
   type Update_Rate is (Rate_1Hz, Rate_2Hz, Rate_5Hz);
   procedure Set_Update_Rate (Rate : Update_Rate); --  $PCAS02,<ms>  UNTESTED

   --  PCAS03 -- per-sentence output rate: 0 = off, 1 .. 9 = once every N fixes.
   subtype Output_Rate is Natural range 0 .. 9;
   procedure Set_NMEA_Output                       --  $PCAS03,...   UNTESTED
     (GGA, GLL, GSA, GSV, RMC, VTG, ZDA, ANT : Output_Rate := 1);

   --  PCAS10 -- restart the receiver.
   type Restart_Mode is (Hot, Warm, Cold, Cold_Factory);  --  flags 0..3
   procedure Restart (Mode : Restart_Mode);        --  $PCAS10,<n>  UNTESTED

end ESP32S3.GPS.L76K;
