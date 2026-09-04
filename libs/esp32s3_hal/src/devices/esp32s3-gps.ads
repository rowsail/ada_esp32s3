with Interfaces;
with Ada.Real_Time;
with ESP32S3.UART;
with ESP32S3.GPIO;

--  Generic NMEA-0183 GPS receiver driver (UART), task-driven.
--
--  Unlike the passive I2C device drivers (ESP32S3.PCF85063A / .QMI8658C, which
--  you poll through a Device handle), this is a SINGLETON background SERVICE: a
--  library-level task owns one UART for its lifetime, continuously reads the
--  receiver's NMEA stream, decodes it, and publishes the results into a PROTECTED
--  store.  The application just reads that store -- there is no Device handle.
--
--  Wiring (all three pins optional; Rx is the only one needed to receive):
--     Rx   <- the receiver's TXD  (data IN from the GPS)
--     Tx   -> the receiver's RXD  (data OUT to the GPS; for config -- see below)
--     Pps  <- the receiver's 1PPS (a GPIO interrupt, for time alignment)
--
--  Concurrency / tearing:  every published value is written and read under the
--  protected store's lock, so a reader never sees a half-updated value.  In
--  particular Latitude and Longitude are ONE record (Position), updated by a
--  single protected action, so a fix is always a consistent pair.
--
--  Staleness:  each value group carries the Ada.Real_Time.Time at which it was
--  last refreshed.  The driver only refreshes a group from a VALID sentence (a
--  lost fix is not written), so a stale group keeps its old timestamp -- compare
--  Age (R.Updated_At) against your tolerance to decide whether to trust it.
--
--  Uses the controlled UART Session + a task + protected objects => embedded /
--  full profiles only (excluded from light-tasking, like the other Session
--  drivers).  Call Setup once at startup.

package ESP32S3.GPS is

   ----------------------------------------------------------------------------
   --  Decoded quantities.
   ----------------------------------------------------------------------------

   --  Latitude / longitude in 1e-7 degrees (the u-blox convention): exact,
   --  integer, and atomically paired.  +N / -S, +E / -W.
   type Position is record
      Latitude  : Interfaces.Integer_32 := 0;
      Longitude : Interfaces.Integer_32 := 0;
   end record;

   type Fix_Quality is (No_Fix, GPS_Fix, DGPS_Fix);

   --  GSA solution mode (2D / 3D).
   type Fix_Type is (Fix_None, Fix_2D, Fix_3D);

   --  GNSS constellation, from a GSV sentence's talker (PRNs overlap across
   --  systems, so a satellite is identified by System + PRN).
   type GNSS_System is (GPS, GLONASS, Galileo, BeiDou, QZSS, Other);

   --  One satellite in view (from GSV).  SNR is C/N0 in dB-Hz; 0 means in view
   --  but not currently tracked.
   type Satellite is record
      System    : GNSS_System := Other;
      PRN       : Natural := 0;   --  id within its constellation
      Elevation : Natural := 0;   --  degrees above the horizon, 0 .. 90
      Azimuth   : Natural := 0;   --  degrees from true north, 0 .. 359
      SNR       : Natural := 0;   --  C/N0, dB-Hz
   end record;

   --  Most satellites the driver tracks at once (across all constellations).
   Max_Satellites : constant := 32;

   type Satellite_List is array (Positive range <>) of Satellite;

   type UTC_Time is record
      Hour   : Natural := 0;   --  0 .. 23
      Minute : Natural := 0;   --  0 .. 59
      Second : Natural := 0;   --  0 .. 59
      Centi  : Natural := 0;   --  hundredths of a second, 0 .. 99
   end record;

   type Date is record
      Year  : Natural := 0;    --  full year, e.g. 2026
      Month : Natural := 0;    --  1 .. 12
      Day   : Natural := 0;    --  1 .. 31
   end record;

   ----------------------------------------------------------------------------
   --  Published readings: value + when it was last refreshed + whether it has
   --  ever been set.  Valid = False means "no sentence has filled this yet".
   ----------------------------------------------------------------------------

   type Position_Reading is record
      Value      : Position;
      Updated_At : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
      Valid      : Boolean := False;
   end record;

   type Fix_Reading is record
      Quality     : Fix_Quality := No_Fix;
      Satellites  : Natural := 0;
      Altitude_MM : Integer := 0;        --  metres above MSL, in millimetres
      Updated_At  : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
      Valid       : Boolean := False;
   end record;

   type Time_Reading is record
      Value      : UTC_Time;
      Updated_At : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
      Valid      : Boolean := False;
   end record;

   type Date_Reading is record
      Value      : Date;
      Updated_At : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
      Valid      : Boolean := False;
   end record;

   type Velocity_Reading is record
      Speed_MMS   : Natural := 0;        --  ground speed, millimetres / second
      Course_CDeg : Natural := 0;        --  course over ground, centi-degrees true
      Updated_At  : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
      Valid       : Boolean := False;
   end record;

   --  Sky / signal view from GSV (satellites in view + strongest C/N0) and GSA
   --  (solution mode + dilution of precision).  Useful for watching acquisition
   --  even before a position fix.  In_View / Max_SNR are from the latest GSV
   --  message (one constellation, on a multi-GNSS receiver).
   type Signal_Reading is record
      In_View    : Natural := 0;       --  satellites in view (latest GSV)
      Used       : Natural := 0;       --  satellites in the solution (GSA)
      Max_SNR    : Natural := 0;       --  strongest C/N0, dB-Hz (latest GSV)
      Mode       : Fix_Type := Fix_None;
      PDOP_C     : Natural := 0;       --  dilution of precision * 100 (centi)
      HDOP_C     : Natural := 0;
      VDOP_C     : Natural := 0;
      Updated_At : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
      Valid      : Boolean := False;
   end record;

   type PPS_Reading is record
      Last  : Ada.Real_Time.Time := Ada.Real_Time.Time_First;  --  edge time
      Count : Natural := 0;         --  pulses seen since startup
      Valid : Boolean := False;
   end record;

   ----------------------------------------------------------------------------
   --  One-time configuration -- call once at startup (single-threaded).  Records
   --  the wiring, brings the UART up, arms the optional PPS interrupt, and
   --  releases the reader task to start decoding.  No pin defaults for Rx (the
   --  one line you must wire); Tx / Pps default to No_Pin.
   ----------------------------------------------------------------------------

   procedure Setup
     (Port : ESP32S3.UART.UART_Port;
      Rx   : ESP32S3.GPIO.Optional_Pin;
      Tx   : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Pps  : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Baud : ESP32S3.UART.Baud_Rate := 9600);

   ----------------------------------------------------------------------------
   --  Read the latest published values (each a consistent snapshot).
   ----------------------------------------------------------------------------

   function Current_Position return Position_Reading;
   function Current_Fix return Fix_Reading;
   function Current_Time return Time_Reading;
   function Current_Date return Date_Reading;
   function Current_Velocity return Velocity_Reading;
   function Current_Signal return Signal_Reading;
   function Current_PPS return PPS_Reading;

   --  Copy the satellites currently in view (seen via GSV within Max_Age) into
   --  List; Count is how many were written, clipped to List'Length.  Satellites
   --  are accumulated across GSV messages and constellations and aged out, so a
   --  satellite that drops out of the GSV stream disappears after Max_Age.
   procedure Satellites_In_View
     (List    : out Satellite_List;
      Count   : out Natural;
      Max_Age : Ada.Real_Time.Time_Span := Ada.Real_Time.Milliseconds (3000))
   with Post => Count <= List'Length;

   --  Time elapsed since a reading's Updated_At -- compare against your tolerance
   --  to decide whether the value is stale.
   function Age (Updated_At : Ada.Real_Time.Time) return Ada.Real_Time.Time_Span;

   --  Send a raw command string to the receiver (e.g. a vendor configuration
   --  sentence).  The bytes are sent VERBATIM -- the caller frames and checksums
   --  them; see the ESP32S3.GPS.L76K child for the L76K's PCAS commands.  Queued
   --  and transmitted by the reader task on its UART, so it needs Setup and a
   --  routed Tx pin.  Silently dropped if the small outbox is full.
   procedure Send (Command : String);

   --  Copy the most recently received raw sentence (as framed: '$' .. before the
   --  CR/LF, including any '*HH') into Buffer; Length is how many characters were
   --  copied (0 if none yet), clipped to Buffer'Length.  Captured for EVERY
   --  framed line -- recognised or not -- so it is handy for diagnosing a quiet
   --  or unlocked receiver (e.g. is it sending empty, no-fix sentences?).
   procedure Last_Sentence (Buffer : out String; Length : out Natural)
   with Post => Length <= Buffer'Length;

   ----------------------------------------------------------------------------
   --  Test / advanced hook: feed one already-framed NMEA sentence (between, and
   --  including, '$' and the '*HH' checksum) straight into the decoder, exactly
   --  as the reader task would on receiving it.  Updates the store on a valid,
   --  recognised sentence and returns whether it was accepted.  Lets a host /
   --  on-target self-test exercise decoding + storage + timestamps with no live
   --  receiver.
   procedure Inject (Sentence : String; Accepted : out Boolean);

end ESP32S3.GPS;
