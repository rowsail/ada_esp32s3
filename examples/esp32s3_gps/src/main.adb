--  What it demonstrates
--  ---------------------
--  The reusable HAL GPS driver (ESP32S3.GPS): a task-driven UART NMEA receiver
--  on the bare-metal ESP32-S3 (no FreeRTOS, no IDF).  The driver is a singleton
--  background service -- a library-level reader task owns the UART, decodes the
--  receiver's NMEA stream, and publishes results into a protected store the
--  application reads.  Runs in two phases:
--
--    self-test  Inject canned GGA/RMC/ZDA/GLL/VTG/GSV/GSA sentences (and one
--               with a bad checksum) BEFORE Setup -- so the reader task is still
--               suspended and the protected store is quiescent -- and check that
--               decoding, storage, and the paired Position record are correct.
--               This proves the decoder on silicon with no live receiver.
--
--    live       Setup UART0 and release the reader task, then once a second
--               print the latest fix + its age.  With no antenna lock the
--               position stays invalid/stale while sentences still arrive (the
--               fix group's rx-age advancing shows reception is live).
--
--  Build & run
--  -----------
--    ./x run esp32s3_gps      (build.sh sets ESP32S3_RTS_PROFILE=embedded --
--                               needs the controlled UART Session + task +
--                               protected objects, so not light-tasking)
--
--  Output
--  ------
--  The self-test prints one "[gps] <name> : PASS" line per check (all PASS is a
--  good run); then "[gps] live (UART0 @ 9600)..." and, once a second, a UTC +
--  fix line plus the raw sentence echo.  Every 10 s it dumps the satellite list.
--  Report goes through the ROM printf glue; the Ada driver does all the UART +
--  NMEA work.
--
--  Hardware / wiring
--  -----------------
--  A 9600-baud NMEA GPS module (e.g. Quectel L76K) on UART0.  Its pads are free
--  here because the console runs over USB-Serial-JTAG.
--    GPS TXD -> U0RXD = GPIO44  (data in from the GPS -- the one line you must wire)
--    GPS RXD <- U0TXD = GPIO43  (config commands out to the GPS)
--    VCC/GND -> 3V3/GND
with System;
with Interfaces;    use Interfaces;
use type Interfaces.Integer_32;
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.UART;
with ESP32S3.GPS;
with ESP32S3.GPS.L76K;   --  L76K-specific PCAS commands
with ESP32S3.Log; use ESP32S3.Log;

--  Pull the SMP slave-start entry into the link closure (glue.c calls it after
--  elaboration); core 1 just idles -- the demo runs on core 0.
with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   package GPS renames ESP32S3.GPS;
   package L76K renames ESP32S3.GPS.L76K;
   use type GPS.Fix_Quality;

   --  Live UART wiring: the GPS module's NMEA stream on UART0.  The console is
   --  USB-Serial-JTAG, so UART0's pads are free for the receiver.
   GPS_Rx_Pin : constant := 44;       --  U0RXD <- GPS TXD (data in)
   GPS_Tx_Pin : constant := 43;       --  U0TXD -> GPS RXD (config commands out)
   GPS_Baud   : constant := 9_600;    --  most NMEA modules default to 9600, 1 Hz

   --  The bare ROM-printf console FIFO is 64 bytes and non-blocking; space
   --  back-to-back lines by this much so it drains between them.
   Fifo_Drain : constant Time_Span := Milliseconds (40);

   --  Self-test check label column: pad each name out to this width before " : ".
   Label_Width : constant := 11;

   --  Raw-echo clip: print at most this many chars of a sentence, then "..".
   Raw_Clip : constant := 52;

   --  Live-phase pacing (one loop tick = 1 s).
   Live_Ticks        : constant := 70;   --  how long the live phase runs (s)
   Sat_Dump_Interval : constant := 10;  --  dump the satellite list every N ticks
   PCAS_Tick         : constant := 5;    --  tick at which the PCAS04 test fires

   --  PCAS04 mode number (1 .. 7) for a constellation selection.
   function Config_Mode (Selection : L76K.Constellation) return Integer
   is (L76K.Constellation'Pos (Selection) + 1);

   --  Two-digit zero-padded field, matching the glue's put2 ((v/10)%10, v%10).
   procedure Put2 (Value : Integer) is
   begin
      Put (Character'Val (Character'Pos ('0') + (Value / 10) mod 10));
      Put (Character'Val (Character'Pos ('0') + Value mod 10));
   end Put2;

   --  A coordinate in 1e-7 degrees -> "[-]D.DDDDDDD" (7 fractional digits),
   --  like the glue's put_deg.  GPS lat/lon are stored as integer 1e-7 degrees.
   Degree_Scale : constant := 10_000_000;   --  1 degree == 1e7 in 1e-7-deg units

   procedure Put_Deg (Degrees_E7 : Integer) is
      Magnitude : constant Integer := abs Degrees_E7;
      Place     : Integer := Degree_Scale / 10;   --  start at the first fractional digit
   begin
      if Degrees_E7 < 0 then
         Put ("-");
      end if;
      Put (Magnitude / Degree_Scale);   --  whole degrees
      Put (".");
      while Place >= 1 loop
         Put (Character'Val (Character'Pos ('0') + (Magnitude / Place) mod 10));
         Place := Place / 10;
      end loop;
   end Put_Deg;

   --  One self-test check line: "[gps] %-11s : %s" with the name selected by Code.
   procedure Check (Code : Integer; Ok : Boolean) is
      function Name return String
      is (case Code is
            when 0      => "gga accept",
            when 1      => "position",
            when 2      => "fix info",
            when 3      => "utc time",
            when 4      => "rmc accept",
            when 5      => "date",
            when 6      => "velocity",
            when 7      => "bad-cks rej",
            when 8      => "zda t/date",
            when 9      => "gll pos",
            when 10     => "vtg vel",
            when 11     => "gsv view",
            when 12     => "gsa dop",
            when 13     => "gsv sats",
            when others => "?");
      Label : constant String := Name;
   begin
      Put ("[gps] ");
      Put (Label);
      for Col in Label'Length + 1 .. Label_Width loop
         Put (" ");
      end loop;
      Put (" : ");
      Put_Line (if Ok then "PASS" else "FAIL");
   end Check;

   --  One live status line; see the glue's native_gps_live.
   procedure Live
     (Time_Valid                 : Boolean;
      HH, MM, SS                 : Integer;
      Pos_Fresh                  : Boolean;
      Lat_E7, Lon_E7             : Integer;
      In_View, Max_SNR, Fix_Type : Integer) is
   begin
      Put ("[gps] UTC=");
      if Time_Valid then
         Put2 (HH);
         Put (":");
         Put2 (MM);
         Put (":");
         Put2 (SS);
      else
         Put ("--:--:--");
      end if;
      if Pos_Fresh then
         Put (" lat=");
         Put_Deg (Lat_E7);
         Put (" lon=");
         Put_Deg (Lon_E7);
      else
         --  No position fix yet: report the acquisition view instead.
         --  Fix_Type 0/1/2 = no-fix / 2D / 3D (GPS.Fix_Type'Pos order).
         Put (" view=");
         Put (In_View);
         Put (" snr=");
         Put (Max_SNR);
         Put (" ");
         Put (if Fix_Type = 2 then "3D" elsif Fix_Type = 1 then "2D" else "no-fix");
      end if;
      New_Line;
   end Live;

   --  Echo a raw NMEA sentence (clipped to Raw_Clip chars; ".." marks truncation).
   procedure Raw (Sentence : System.Address; Length : Integer) is
      Clipped : constant Integer := (if Length > Raw_Clip then Raw_Clip else Length);
      Bytes   : array (0 .. Integer'Max (Clipped - 1, 0)) of Character
      with Import, Address => Sentence;
   begin
      Put ("[gps] raw: ");
      for I in 0 .. Clipped - 1 loop
         Put ((1 => Bytes (I)));
      end loop;
      if Length > Clipped then
         Put ("..");
      end if;
      New_Line;
   end Raw;

   --  One satellite line; System 0..5 = GP/GL/GA/BD/QZ/Other
   --  (GNSS_System'Pos order: GPS/GLONASS/Galileo/BeiDou/QZSS/Other).
   procedure Sat (GNSS, PRN, Elevation, Azimuth, SNR : Integer) is
      function Sys_Name return String
      is (case GNSS is
            when 0      => "GP",   --  GPS
            when 1      => "GL",   --  GLONASS
            when 2      => "GA",   --  Galileo
            when 3      => "BD",   --  BeiDou
            when 4      => "QZ",   --  QZSS
            when 5      => "??",   --  Other
            when others => "??");
   begin
      Put ("[gps]   ");
      Put (Sys_Name);
      Put (PRN);
      Put (" el=");
      Put (Elevation);
      Put (" az=");
      Put (Azimuth);
      Put (" snr=");
      Put (SNR);
      New_Line;
   end Sat;

   --  Announce an L76K PCAS04 constellation change (mode 1..7).
   procedure Cfg (Mode : Integer) is
      function Mode_Name return String
      is (case Mode is
            when 1      => "GPS",
            when 2      => "BeiDou",
            when 3      => "GPS+BeiDou",
            when 4      => "GLONASS",
            when 5      => "GPS+GLONASS",
            when 6      => "BeiDou+GLONASS",
            when 7      => "GPS+BeiDou+GLONASS",
            when others => "?");
   begin
      Put ("[gps] >> PCAS04: set GNSS = ");
      Put_Line (Mode_Name);
   end Cfg;

   --  Canonical NMEA examples (checksums verified): 48 07.038' N, 011 31.000' E.
   GGA : constant String := "$GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47";
   RMC : constant String := "$GPRMC,123519,A,4807.038,N,01131.000,E,022.4,084.4,230394,003.1,W*6A";
   ZDA : constant String :=   --  UTC 19:27:39, 22/06/2026 (time + date, no fix)
     "$GNZDA,192739.000,22,06,2026,00,00*4F";
   GLL : constant String :=   --  51 30.000' N, 000 07.500' W
     "$GPGLL,5130.000,N,00007.500,W,123519,A,A*5D";
   VTG : constant String :=   --  course 123.4 true, 54.7 kn
     "$GPVTG,123.4,T,,M,054.7,N,101.3,K,A*0C";
   GSV : constant String :=   --  11 in view, strongest C/N0 = 35
     "$GPGSV,3,1,11,04,40,083,30,05,28,290,25,09,15,180,20,12,60,000,35*75";
   GSA : constant String :=   --  3D fix, 5 used, HDOP 1.30
     "$GPGSA,A,3,04,05,09,12,24,,,,,,,,2.50,1.30,2.10*09";
   Bad : constant String :=   --  same GGA, deliberately wrong checksum
     "$GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*00";

   Ok : Boolean;

   --  Space the back-to-back self-test lines so the console FIFO drains.
   procedure Report (Code : Integer; Pass : Boolean) is
   begin
      delay until Clock + Fifo_Drain;
      Check (Code, Pass);
   end Report;

begin
   delay until Clock + Milliseconds (200);   --  let the console settle
   Put_Line ("[gps] NMEA GPS driver demo (UART0 rx=44 tx=43)");
   Put_Line ("[gps] self-test: inject canned NMEA, check store");

   --------------------------------------------------------------------------
   --  Self-test (reader task still suspended -> deterministic store).
   --------------------------------------------------------------------------
   GPS.Inject (GGA, Ok);
   Report (0, Ok);
   declare
      Position : constant GPS.Position_Reading := GPS.Current_Position;
      Fix      : constant GPS.Fix_Reading := GPS.Current_Fix;
      Time     : constant GPS.Time_Reading := GPS.Current_Time;
   begin
      Report
        (1,
         Position.Valid
         and then Position.Value.Latitude = 481_173_000
         and then Position.Value.Longitude = 115_166_666);
      Report
        (2,
         Fix.Quality = GPS.GPS_Fix and then Fix.Satellites = 8 and then Fix.Altitude_MM = 545_400);
      Report
        (3,
         Time.Valid
         and then Time.Value.Hour = 12
         and then Time.Value.Minute = 35
         and then Time.Value.Second = 19);
   end;

   GPS.Inject (RMC, Ok);
   Report (4, Ok);
   declare
      Date     : constant GPS.Date_Reading := GPS.Current_Date;
      Velocity : constant GPS.Velocity_Reading := GPS.Current_Velocity;
   begin
      Report
        (5,
         Date.Valid
         and then Date.Value.Day = 23
         and then Date.Value.Month = 3
         and then Date.Value.Year = 2094);
      Report
        (6,
         Velocity.Valid
         and then Velocity.Speed_MMS = 11_523
         and then Velocity.Course_CDeg = 8_440);
   end;

   --  ZDA: UTC time + date, NOT gated on a fix (updates the clock before lock).
   GPS.Inject (ZDA, Ok);
   declare
      Time : constant GPS.Time_Reading := GPS.Current_Time;
      Date : constant GPS.Date_Reading := GPS.Current_Date;
   begin
      Report
        (8,
         Ok
         and then Time.Valid
         and then Time.Value.Hour = 19
         and then Time.Value.Minute = 27
         and then Time.Value.Second = 39
         and then Date.Valid
         and then Date.Value.Day = 22
         and then Date.Value.Month = 6
         and then Date.Value.Year = 2026);
   end;

   --  GLL: position (distinct coordinate, so this proves GLL field decoding).
   GPS.Inject (GLL, Ok);
   declare
      Position : constant GPS.Position_Reading := GPS.Current_Position;
   begin
      Report
        (9,
         Ok
         and then Position.Valid
         and then Position.Value.Latitude = 515_000_000
         and then Position.Value.Longitude = -1_250_000);
   end;

   --  VTG: velocity (distinct from RMC's, so this proves VTG field decoding).
   GPS.Inject (VTG, Ok);
   declare
      Velocity : constant GPS.Velocity_Reading := GPS.Current_Velocity;
   begin
      Report
        (10,
         Ok
         and then Velocity.Valid
         and then Velocity.Speed_MMS = 28_140
         and then Velocity.Course_CDeg = 12_340);
   end;

   --  GSV: satellites in view + strongest C/N0 (acquisition, no fix needed).
   GPS.Inject (GSV, Ok);
   declare
      Signal : constant GPS.Signal_Reading := GPS.Current_Signal;
   begin
      Report
        (11, Ok and then Signal.Valid and then Signal.In_View = 11 and then Signal.Max_SNR = 35);
   end;

   --  GSV satellite list: the 4 satellites in that message, decoded into entries.
   declare
      Satellites : GPS.Satellite_List (1 .. GPS.Max_Satellites);
      Sat_Count  : Natural;
      use type GPS.GNSS_System;
   begin
      GPS.Satellites_In_View (Satellites, Sat_Count);
      Report
        (13,
         Sat_Count = 4
         and then Satellites (1).System = GPS.GPS
         and then Satellites (1).PRN = 4
         and then Satellites (1).SNR = 30
         and then Satellites (4).PRN = 12
         and then Satellites (4).SNR = 35);
   end;

   --  GSA: solution mode (3D) + dilution of precision.
   GPS.Inject (GSA, Ok);
   declare
      Signal : constant GPS.Signal_Reading := GPS.Current_Signal;
      use type GPS.Fix_Type;
   begin
      Report
        (12,
         Ok
         and then Signal.Valid
         and then Signal.Mode = GPS.Fix_3D
         and then Signal.Used = 5
         and then Signal.HDOP_C = 130);
   end;

   GPS.Inject (Bad, Ok);
   Report (7, not Ok);            --  a bad checksum must be rejected

   --------------------------------------------------------------------------
   --  Live: bring up UART0 on the GPS pins and release the reader task.
   --------------------------------------------------------------------------
   delay until Clock + Fifo_Drain;
   Put_Line ("[gps] live (UART0 @ 9600) -- waiting for sentences...");
   GPS.Setup (Port => ESP32S3.UART.UART0, Rx => GPS_Rx_Pin, Tx => GPS_Tx_Pin, Baud => GPS_Baud);

   --  Live phase: Live_Ticks one-second ticks of fix/sat reporting, then idle.
   for Tick in 1 .. Live_Ticks loop
      delay until Clock + Seconds (1);
      declare
         Position     : constant GPS.Position_Reading := GPS.Current_Position;
         Time         : constant GPS.Time_Reading := GPS.Current_Time;
         Signal       : constant GPS.Signal_Reading := GPS.Current_Signal;
         Satellites   : GPS.Satellite_List (1 .. GPS.Max_Satellites);
         Sat_Count    : Natural;
         --  A live fix updates ~1 Hz; tolerate a few missed updates before
         --  calling the position stale (and aging the self-test fix out).
         Pos_Stale_S  : constant := 3.0;
         --  UTC arrives via ZDA/RMC even before lock, but less reliably; allow
         --  a bit more slack before declaring the clock stale.
         Time_Stale_S : constant := 5.0;
         Pos_Fresh    : constant Boolean :=
           Position.Valid and then To_Duration (GPS.Age (Position.Updated_At)) < Pos_Stale_S;
         Time_Fresh   : constant Boolean :=
           Time.Valid and then To_Duration (GPS.Age (Time.Updated_At)) < Time_Stale_S;
      begin
         GPS.Satellites_In_View (Satellites, Sat_Count);   --  table count (all systems)
         Live
           (Time_Valid => Time_Fresh,
            HH         => Integer (Time.Value.Hour),
            MM         => Integer (Time.Value.Minute),
            SS         => Integer (Time.Value.Second),
            Pos_Fresh  => Pos_Fresh,
            Lat_E7     => Integer (Position.Value.Latitude),
            Lon_E7     => Integer (Position.Value.Longitude),
            In_View    => Integer (Sat_Count),
            Max_SNR    => Integer (Signal.Max_SNR),
            Fix_Type   => GPS.Fix_Type'Pos (Signal.Mode));

         --  Echo the actual raw sentence (spaced so the FIFO drains; long
         --  sentences are split into two lines to stay under the console FIFO).
         delay until Clock + Fifo_Drain;
         declare
            --  A standard NMEA sentence is at most 82 chars; 90 leaves margin.
            Sentence    : String (1 .. 90);
            Length      : Natural;
            --  Split point: echo the first Split_Point chars, then the rest, so
            --  each printed line stays under the 64-byte console FIFO.
            Split_Point : constant := 45;
         begin
            GPS.Last_Sentence (Sentence, Length);
            Raw (Sentence'Address, Natural'Min (Length, Split_Point));
            if Length > Split_Point then
               delay until Clock + Fifo_Drain;
               Raw (Sentence (Sentence'First + Split_Point)'Address, Length - Split_Point);
            end if;
         end;

         --  Every Sat_Dump_Interval ticks (one tick = 1 s), dump the full
         --  satellite-in-view list, one per line.
         if Tick mod Sat_Dump_Interval = 0 then
            delay until Clock + Fifo_Drain;
            Put ("[gps] satellites in view: ");
            Put (Integer (Sat_Count));
            New_Line;
            for I in 1 .. Sat_Count loop
               delay until Clock + Fifo_Drain;
               Sat
                 (GNSS      => GPS.GNSS_System'Pos (Satellites (I).System),
                  PRN       => Integer (Satellites (I).PRN),
                  Elevation => Integer (Satellites (I).Elevation),
                  Azimuth   => Integer (Satellites (I).Azimuth),
                  SNR       => Integer (Satellites (I).SNR));
            end loop;
         end if;

         --  L76K PCAS04 test: at PCAS_Tick (after the default GPS+BeiDou
         --  baseline) enable ALL constellations.  Disabling a constellation is
         --  instant, but ENABLING GLONASS means acquiring those satellites from
         --  scratch, so GLONASS (GL) appears in the dumps a while later.
         if Tick = PCAS_Tick then
            delay until Clock + Fifo_Drain;
            Cfg (Config_Mode (L76K.GPS_BeiDou_GLONASS));
            L76K.Set_Constellation (L76K.GPS_BeiDou_GLONASS);
         end if;
      end;
   end loop;

   delay until Clock + Fifo_Drain;
   Put_Line ("[gps] done.");

   --  Hold the demo here so the final output stays on screen; wake hourly.
   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
