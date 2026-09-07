with Interfaces;
with GNAT.Sockets;

--  A tiny, portable SNTP/NTP time client.  Like DNS_Client, it is written entirely
--  against GNAT.Sockets (a UDP query to an NTP server, reading the transmit
--  timestamp out of the reply), so the same source compiles and runs on desktop
--  GNAT.Sockets and on the bare-metal W5500 facade alike -- nothing here is
--  chip-specific.
--
--  Use it with one `with NTP_Client;`.  GNAT.Sockets must already be usable (on the
--  W5500, call GNAT.Sockets.Initialize (Device) once during bring-up).
--
--  Concurrency: Query rotates a benign package-global source-port counter --
--  concurrent queries from several tasks corrupt nothing, but may briefly
--  share a port and fail a reply check; serialise or accept the retry.

package NTP_Client with SPARK_Mode => On is

   use type Interfaces.Integer_64;   --  the calendar contracts do 64-bit arithmetic

   --  Query the NTP server at Server (UDP port 123) for the current UTC time.
   --  True with Unix_Time set (seconds since 1970-01-01 UTC) on success; False if
   --  the server does not answer within Timeout or the reply is unusable.
   --
   --  Timeout caps the wait for the reply (via the Receive_Timeout socket option);
   --  0.0, the default, blocks indefinitely.  Local_Port is the UDP source port;
   --  0, the default, picks a fresh dynamic-range port per query -- a fixed
   --  source port lets a soured NAT flow blackhole every retry (see the note
   --  on DNS_Client.Resolve, where this was measured on cellular).
   function Query
     (Server     : GNAT.Sockets.Inet_Addr_Type;
      Unix_Time  : out Interfaces.Integer_64;
      Timeout    : Duration := 0.0;
      Local_Port : GNAT.Sockets.Port_Type := 0) return Boolean
   with SPARK_Mode => Off;

   --  The inverse of the calendar break-down below: days since 1970-01-01 for a
   --  civil date (Hinnant's days_from_civil).  Ghost -- it exists only to say
   --  what To_UTC MEANS, and is compiled out of the real program.
   --
   --  Stating the meaning this way, rather than bounding the output fields, is
   --  what separates "the conversion cannot raise" from "the conversion is
   --  right": a field-range postcondition is satisfied by a routine that
   --  returns 1970-01-01 for every input, and it also happily admits February
   --  31st.  The round-trip below admits exactly one answer per Unix_Time.
   --  Written as named pieces rather than one declare expression: the HAL
   --  builds at the default language version, and these are Ghost, so the
   --  repetition costs nothing in the object code.
   --
   --  Hinnant's algorithm shifts the year to start in March, which is what
   --  makes the leap day the LAST day of the year and lets the month-length
   --  pattern collapse into the (153 * m + 2) / 5 term below.
   function Shifted_Year (Year, Month : Integer) return Interfaces.Integer_64
   is (Interfaces.Integer_64 (Year) - (if Month <= 2 then 1 else 0))
   with Ghost;

   function Era_Of (Year, Month : Integer) return Interfaces.Integer_64
   is (Shifted_Year (Year, Month) / 400)                --  400-year cycle
   with Ghost;

   function Year_Of_Era (Year, Month : Integer) return Interfaces.Integer_64
   is (Shifted_Year (Year, Month) - Era_Of (Year, Month) * 400)
   with Ghost;

   function Day_Of_Year (Month, Day : Integer) return Interfaces.Integer_64
   is ((153 * (Interfaces.Integer_64 (Month)
               + (if Month > 2 then -3 else 9)) + 2) / 5
       + Interfaces.Integer_64 (Day) - 1)
   with Ghost, Pre => Month in 1 .. 12;

   function Days_From_Civil (Year, Month, Day : Integer) return Interfaces.Integer_64
   is (Era_Of (Year, Month) * 146_097                   --  days in a 400-year era
       + (Year_Of_Era (Year, Month) * 365
          + Year_Of_Era (Year, Month) / 4
          - Year_Of_Era (Year, Month) / 100
          + Day_Of_Year (Month, Day))                   --  day of era
       - 719_468)                                       --  shift 0000-03-01 -> 1970-01-01
   with Ghost,
        Pre => Year in 1970 .. 2107
               and then Month in 1 .. 12
               and then Day in 1 .. 31;

   --  Length of a Gregorian month.  Ghost, and needed for uniqueness: the
   --  round-trip below on its own does NOT pin the answer, because
   --  Days_From_Civil maps the non-date 1970-02-30 to the same day number as
   --  1970-03-02.  "Day in 1 .. 31" lets that through; "Day <= Days_In_Month"
   --  does not, and with it exactly one (Year, Month, Day) satisfies the
   --  round-trip.
   function Days_In_Month (Year, Month : Integer) return Integer
   is (case Month is
          when 1 | 3 | 5 | 7 | 8 | 10 | 12 => 31,
          when 4 | 6 | 9 | 11               => 30,
          when others                       =>
            (if Year mod 4 = 0 and then (Year mod 100 /= 0 or else Year mod 400 = 0)
             then 29 else 28))
   with Ghost, Pre => Month in 1 .. 12;

   --  Break a Unix time (seconds since 1970-01-01 UTC) into UTC calendar fields
   --  (Howard Hinnant's civil-from-days algorithm; valid for any Gregorian date).
   procedure To_UTC
     (Unix_Time : Interfaces.Integer_64;
      Year      : out Integer;
      Month     : out Integer;
      Day       : out Integer;
      Hour      : out Integer;
      Minute    : out Integer;
      Second    : out Integer)
   with Pre  => Unix_Time in 0 .. 16#FFFF_FFFF#,   --  the 32-bit NTP second domain
        Post =>
        Year in 1970 .. 2107
        and then Month in 1 .. 12
        and then Day in 1 .. Days_In_Month (Year, Month)
        and then Hour in 0 .. 23
        and then Minute in 0 .. 59
        and then Second in 0 .. 59
        --  ... and the fields denote exactly the instant they were made from.
        and then Days_From_Civil (Year, Month, Day) * 86_400
                 + Interfaces.Integer_64 (Hour) * 3_600
                 + Interfaces.Integer_64 (Minute) * 60
                 + Interfaces.Integer_64 (Second) = Unix_Time;

end NTP_Client;
