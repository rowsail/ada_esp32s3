--  Weather forecast for a latitude / longitude, from Open-Meteo (open-meteo.com).
--  ============================================================================
--
--  What it demonstrates
--  --------------------
--  A full plaintext-HTTP client over the W5500 Ethernet HAL: resolve a host by
--  name (DNS_Client), open a TCP socket (GNAT.Sockets), send an HTTP/1.0 GET, and
--  scrape the JSON reply.  Open-Meteo's forecast API answers over plain HTTP on
--  port 80 (no TLS, which the W5500 cannot do), so this is a straight TCP-client
--  GET followed by a small scrape of the JSON it returns:
--
--     GET /v1/forecast?latitude=..&longitude=..&current_weather=true HTTP/1.0
--
--  The "argument" is the Latitude / Longitude pair below -- edit them for the place
--  you want (decimal degrees, as written; negative = south / west).  We print the
--  current temperature, wind, and a word for the WMO weather code.
--
--  The server's address is resolved by name with the portable DNS_Client module
--  (a DNS A-record query over GNAT.Sockets): api.open-meteo.com becomes an IP at
--  run time -- nothing is hard-coded.
--
--  Build & run
--  -----------
--  ./x run esp32s3_w5500_weather
--  Needs the embedded profile; build.sh sets ESP32S3_RTS_PROFILE=embedded.
--
--  How to read the output
--  ----------------------
--  Every line is tagged "[wx]" (or "[w5500]" from the bring-up).  A good run
--  prints the link coming up, the resolved IP, then the parsed forecast:
--     [wx]   temperature : 28.4 C
--     [wx]   wind        : 9.7 km/h from 210 deg
--     [wx]   conditions  : partly cloudy
--  If the link does not come up, the DNS query gets no reply, or the JSON cannot
--  be parsed, the corresponding "[wx] ..." failure line is printed instead (the
--  raw response is dumped when parsing fails).
--
--  Hardware / wiring
--  -----------------
--  A WIZnet W5500 Ethernet module on SPI2, plus a live LAN with internet access.
--  SPI pinout (see w5500_dev.adb): SCLK=GPIO1, MOSI=GPIO4, MISO=GPIO45, CS=GPIO39,
--  RST=GPIO11, INT=GPIO3, at 10 MHz.  The board takes a static IP 192.168.1.50 on
--  a 192.168.1.0/24 LAN with gateway .254 -- edit those in w5500_dev.adb for your
--  network.  DNS goes to 8.8.8.8 (Google's public resolver; see below).
with Ada.Real_Time; use Ada.Real_Time;
with Ada.Streams;   use Ada.Streams;
with GNAT.Sockets;  use GNAT.Sockets;
with ESP32S3.Log;   use ESP32S3.Log;
with DNS_Client;
with W5500_Dev;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   --  ---- the location to forecast (edit these) --------------------------------
   Latitude  : constant String := "33.749";    --  Atlanta, GA, USA
   Longitude : constant String := "-84.388";
   --  ---------------------------------------------------------------------------

   --  Open-Meteo's forecast host.  Resolved by name at run time (see DNS below);
   --  also sent verbatim in the HTTP "Host:" header.
   Host_Name : constant String := "api.open-meteo.com";

   --  DNS resolver to query for Host_Name's A record.  8.8.8.8 is Google's public
   --  resolver -- reachable from any internet-connected LAN; change it to your own
   --  resolver if 8.8.8.8 is blocked.
   DNS_Server : constant Inet_Addr_Type := Inet_Addr ("8.8.8.8");

   --  TCP port for plain HTTP (the API has no TLS endpoint the W5500 could use).
   Server_Port : constant Port_Type := 80;

   Quote : constant String := (1 => '"');                     --  one double-quote

   Sock      : Socket_Type;             --  the client TCP socket
   Server_IP : Inet_Addr_Type;          --  Host_Name resolved to an IPv4 address

   --  Receive scratch: one read of the socket lands here, up to 512 bytes at a time.
   Buf   : Stream_Element_Array (1 .. 512);
   Last  : Stream_Element_Offset;   --  last byte filled by Receive_Socket
   SLast : Stream_Element_Offset;   --  last byte accepted by Send_Socket

   --  Accumulated HTTP response (headers + JSON body).  4 KB is ample for the
   --  small current_weather reply; bytes past this cap are dropped (see the loop).
   Resp     : String (1 .. 4096);
   Resp_Len : Natural := 0;            --  bytes of Resp actually filled

   function To_SEA (S : String) return Stream_Element_Array is
      Result : Stream_Element_Array (1 .. S'Length);
   begin
      for I in S'Range loop
         Result (Stream_Element_Offset (I - S'First) + 1) := Character'Pos (S (I));
      end loop;
      return Result;
   end To_SEA;

   --  Plain substring search (independent of the runtime's Ada.Strings).  Returns
   --  the 1-based index of Pat in S at or after From, or 0 if absent.
   function Find (S : String; Pat : String; From : Positive := 1) return Natural is
   begin
      if Pat'Length = 0 or else Pat'Length > S'Length then
         return 0;
      end if;
      for I in From .. S'Last - Pat'Length + 1 loop
         if S (I .. I + Pat'Length - 1) = Pat then
            return I;
         end if;
      end loop;
      return 0;
   end Find;

   --  Return the JSON value written after Key (e.g. """temperature"":"), searching
   --  the response from From.  Numbers are returned verbatim; a quoted string is
   --  returned without its quotes.  "" if the key is not found.
   function Field (Key : String; From : Positive) return String is
      Pos, Index, Start : Natural;
   begin
      Pos := Find (Resp (1 .. Resp_Len), Key, From);
      if Pos = 0 then
         return "";
      end if;
      Index := Pos + Key'Length;
      if Index <= Resp_Len and then Resp (Index) = '"' then
         --  quoted string value
         Index := Index + 1;
         Start := Index;
         while Index <= Resp_Len and then Resp (Index) /= '"' loop
            Index := Index + 1;
         end loop;
      else
         --  bare number
         Start := Index;
         while Index <= Resp_Len and then Resp (Index) /= ',' and then Resp (Index) /= '}' loop
            Index := Index + 1;
         end loop;
      end if;
      return Resp (Start .. Index - 1);
   end Field;

   --  WMO weather interpretation code -> a short description.
   function Weather (Code : String) return String is
   begin
      if Code = "0" then
         return "clear sky";
      elsif Code = "1" then
         return "mainly clear";
      elsif Code = "2" then
         return "partly cloudy";
      elsif Code = "3" then
         return "overcast";
      elsif Code = "45" or else Code = "48" then
         return "fog";
      elsif Code = "51" or else Code = "53" or else Code = "55" then
         return "drizzle";
      elsif Code = "56" or else Code = "57" then
         return "freezing drizzle";
      elsif Code = "61" or else Code = "63" or else Code = "65" then
         return "rain";
      elsif Code = "66" or else Code = "67" then
         return "freezing rain";
      elsif Code = "71" or else Code = "73" or else Code = "75" then
         return "snow";
      elsif Code = "77" then
         return "snow grains";
      elsif Code = "80" or else Code = "81" or else Code = "82" then
         return "rain showers";
      elsif Code = "85" or else Code = "86" then
         return "snow showers";
      elsif Code = "95" then
         return "thunderstorm";
      elsif Code = "96" or else Code = "99" then
         return "thunderstorm with hail";
      else
         return "code " & Code;
      end if;
   end Weather;

   --  Seconds to wait for the resolver's reply before giving up on DNS.
   DNS_Timeout : constant Duration := 5.0;

   Request : constant String :=
     "GET /v1/forecast?latitude="
     & Latitude
     & "&longitude="
     & Longitude
     & "&current_weather=true HTTP/1.0"
     & ASCII.CR
     & ASCII.LF
     & "Host: "
     & Host_Name
     & ASCII.CR
     & ASCII.LF
     & "Connection: close"
     & ASCII.CR
     & ASCII.LF
     & ASCII.CR
     & ASCII.LF;
begin
   --  Let the console / USB-serial settle before the first line so it is not lost.
   delay until Clock + Milliseconds (200);
   Put_Line ("[wx] W5500 weather forecast (Open-Meteo, GNAT.Sockets, TCP)");
   if not W5500_Dev.Bring_Up then
      loop
         --  fatal: nothing to do, park forever
         delay until Clock + Seconds (3600);
      end loop;
   end if;

   --  Resolve the API host by name (portable DNS_Client over GNAT.Sockets).
   Put_Line ("[wx] resolving " & Host_Name & " ...");
   if not DNS_Client.Resolve (DNS_Server, Host_Name, Server_IP, Timeout => DNS_Timeout) then
      Put_Line ("[wx] DNS resolution failed (no resolver reply)");
      loop
         --  fatal: park forever
         delay until Clock + Seconds (3600);
      end loop;
   end if;
   Put_Line ("[wx] " & Host_Name & " = " & Image (Server_IP));

   --  Fetch the forecast.
   Create_Socket (Sock, Family_Inet, Socket_Stream);
   Put_Line ("[wx] GET " & Host_Name & " for " & Latitude & ", " & Longitude & " ...");
   Connect_Socket (Sock, (Family_Inet, Server_IP, Server_Port));
   Send_Socket (Sock, To_SEA (Request), SLast);

   loop
      Receive_Socket (Sock, Buf, Last);
      exit when Last < Buf'First;                --  server closed the connection
      for E of Buf (Buf'First .. Last) loop
         if Resp_Len < Resp'Last then
            --  drop anything past the cap
            Resp_Len := Resp_Len + 1;
            Resp (Resp_Len) := Character'Val (Integer (E));
         end if;
      end loop;
   end loop;
   Close_Socket (Sock);

   --  Scrape the current_weather object.  Anchor at it first: the JSON also carries
   --  a current_weather_units object whose "temperature" etc. are unit *strings*.
   declare
      Weather_Pos : constant Natural :=
        Find (Resp (1 .. Resp_Len), Quote & "current_weather" & Quote & ":");
      Anchor      : constant Positive := (if Weather_Pos = 0 then 1 else Weather_Pos);

      Temp : constant String := Field (Quote & "temperature" & Quote & ":", Anchor);
      Wind : constant String := Field (Quote & "windspeed" & Quote & ":", Anchor);
      Dir  : constant String := Field (Quote & "winddirection" & Quote & ":", Anchor);
      Code : constant String := Field (Quote & "weathercode" & Quote & ":", Anchor);
      Tim  : constant String := Field (Quote & "time" & Quote & ":", Anchor);
   begin
      if Weather_Pos = 0 or else Temp = "" then
         Put_Line ("[wx] could not parse the forecast (response below)");
         Put_Line (Resp (1 .. Resp_Len));
      else
         Put_Line ("[wx] forecast for " & Latitude & ", " & Longitude & "  (" & Tim & " UTC)");
         Put_Line ("[wx]   temperature : " & Temp & " C");
         Put_Line ("[wx]   wind        : " & Wind & " km/h from " & Dir & " deg");
         Put_Line ("[wx]   conditions  : " & Weather (Code));
      end if;
   end;

   loop
      --  done: park forever
      delay until Clock + Seconds (3600);
   end loop;
end Main;
