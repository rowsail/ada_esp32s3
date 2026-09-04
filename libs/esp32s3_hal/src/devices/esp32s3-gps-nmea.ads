--  NMEA-0183 sentence decoding for ESP32S3.GPS -- pure logic, no UART, no
--  tasking, no storage, so it is directly testable (mirrors the
--  ESP32S3.<bus> / .Engine split).  Recognises GGA (fix + position + altitude +
--  satellites), RMC (position + validity + velocity + date/time), ZDA (UTC time
--  + date, available even before a position fix), GLL (position + time), VTG
--  (velocity), GSV (satellites in view + C/N0), and GSA (2D/3D mode + DOP).
--
--  Parse validates the XOR checksum first; on a bad checksum or an unrecognised
--  talker it reports Recognised = False and the Has_* flags stay clear.  Each
--  Has_* flag says whether that field was present and decoded, so the caller
--  publishes only what actually arrived.

private package ESP32S3.GPS.NMEA with SPARK_Mode => On is

   --  Everything one GGA or RMC sentence can yield.  Only the fields whose Has_*
   --  flag is set are meaningful.
   type Parsed is record
      Recognised : Boolean := False;   --  checksum OK and a GGA/RMC sentence

      Has_Position : Boolean := False;
      Pos          : Position;

      Fix_Valid    : Boolean := False;   --  RMC status 'A' / GGA quality > 0
      Has_Quality  : Boolean := False;
      Quality      : Fix_Quality := No_Fix;
      Has_Sats     : Boolean := False;
      Satellites   : Natural := 0;
      Has_Altitude : Boolean := False;
      Altitude_MM  : Integer := 0;

      Has_Time : Boolean := False;
      Time     : UTC_Time;
      Has_Date : Boolean := False;
      Day      : Date;

      Has_Velocity : Boolean := False;
      Speed_MMS    : Natural := 0;
      Course_CDeg  : Natural := 0;

      Has_Sky   : Boolean := False;   --  GSV
      In_View   : Natural := 0;
      Max_SNR   : Natural := 0;
      Sat_Count : Natural := 0;       --  satellites in THIS GSV message (0..4)
      Sats      : Satellite_List (1 .. 4) := (others => <>);

      Has_DOP : Boolean := False;   --  GSA
      Used    : Natural := 0;
      Mode    : Fix_Type := Fix_None;
      PDOP_C  : Natural := 0;
      HDOP_C  : Natural := 0;
      VDOP_C  : Natural := 0;
   end record;

   --  Decode one framed sentence (leading '$' through the trailing '*HH').
   --  The bound on Sentence'Last is trivially met by any real line buffer and
   --  lets the fixed-offset index arithmetic below stay provably in range.
   procedure Parse (Sentence : String; Result : out Parsed)
   with Pre => Sentence'Last <= Integer'Last - 16;

end ESP32S3.GPS.NMEA;
