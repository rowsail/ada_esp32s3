--  What it demonstrates
--  ---------------------
--  An SNTP / NTP time client over a Wiznet W5500 Ethernet module.  It queries a
--  public time server and prints the UTC date and time.  The work is done by the
--  reusable NTP_Client module, which is written entirely against GNAT.Sockets / UDP,
--  so it is portable -- the same source runs on desktop GNAT.Sockets too.
--
--  Build & run
--  -----------
--      ./x run esp32s3_w5500_ntp
--  This example uses the embedded runtime profile (build.sh sets
--  ESP32S3_RTS_PROFILE=embedded), not the default light-tasking profile.
--
--  How to read the output
--  ----------------------
--  Expect, in order:
--      [ntp] W5500 NTP time client (NTP_Client over GNAT.Sockets)
--      [w5500] link up, IP 192.168.1.50
--      [ntp] querying 216.239.35.0 ...
--      [ntp] time = 2026-06-26 14:03:21 UTC
--  Success is the final "[ntp] time = ... UTC" line.  If the chip is not found
--  the bring-up prints "[w5500] not found ..." and the program parks; "[w5500]
--  link DOWN ..." means the cable / switch did not come up; "[ntp] no response
--  from the time server" means the query timed out (server unreachable / blocked).
--
--  Hardware / wiring
--  -----------------
--  A Wiznet W5500 SPI Ethernet module on SPI2, plugged into a LAN that can reach
--  the public Internet (the NTP server is on the Internet).  SPI pins, CS, RST,
--  INT and the static IP / gateway are set in w5500_dev.adb -- edit them and the
--  NTP_Server below for your own LAN.  Default wiring (see w5500_dev.adb):
--      SCLK = GPIO1, MOSI = GPIO4, MISO = GPIO45,
--      CS   = GPIO39, RST  = GPIO11, INT  = GPIO3.
with Interfaces;    use Interfaces;
with Ada.Real_Time; use Ada.Real_Time;
with GNAT.Sockets;  use GNAT.Sockets;
with ESP32S3.Log;   use ESP32S3.Log;
with NTP_Client;
with W5500_Dev;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   --  The time server to query.  216.239.35.0 is one of Google's public NTP
   --  servers (time.google.com); a numeric address avoids needing DNS here.
   NTP_Server : constant Inet_Addr_Type := Inet_Addr ("216.239.35.0");

   --  How long NTP_Client.Query waits for a reply before giving up, in seconds.
   NTP_Timeout : constant Duration := 5.0;

   --  After the one-shot query the program has nothing left to do; it parks by
   --  sleeping in a loop.  This is the per-iteration sleep (one hour).
   Park_Interval : constant := 3600;   --  seconds

   --  Decoded NTP time: seconds since the Unix epoch, then the calendar fields.
   Unix_Seconds : Integer_64;
   Year         : Integer;
   Month        : Integer;
   Day          : Integer;
   Hour         : Integer;
   Minute       : Integer;
   Second       : Integer;

   --  Print a calendar field as a zero-padded two-digit number (e.g. 6 -> "06").
   procedure Put_Two_Digits (Value : Integer) is
   begin
      if Value < 10 then
         Put ("0");
      end if;
      Put (Value);
   end Put_Two_Digits;
begin
   delay until Clock + Milliseconds (200);
   Put_Line ("[ntp] W5500 NTP time client (NTP_Client over GNAT.Sockets)");
   if not W5500_Dev.Bring_Up then
      --  No chip / no link: nothing to query, so park forever.
      loop
         delay until Clock + Seconds (Park_Interval);
      end loop;
   end if;

   Put_Line ("[ntp] querying " & Image (NTP_Server) & " ...");
   if NTP_Client.Query (NTP_Server, Unix_Seconds, Timeout => NTP_Timeout) then
      NTP_Client.To_UTC (Unix_Seconds, Year, Month, Day, Hour, Minute, Second);
      Put ("[ntp] time = ");
      Put (Year);
      Put ("-");
      Put_Two_Digits (Month);
      Put ("-");
      Put_Two_Digits (Day);
      Put (" ");
      Put_Two_Digits (Hour);
      Put (":");
      Put_Two_Digits (Minute);
      Put (":");
      Put_Two_Digits (Second);
      Put_Line (" UTC");
   else
      Put_Line ("[ntp] no response from the time server");
   end if;

   --  Done: park forever (one query per boot).
   loop
      delay until Clock + Seconds (Park_Interval);
   end loop;
end Main;
