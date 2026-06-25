--  Weather forecast for a latitude / longitude, from Open-Meteo (open-meteo.com).
--
--  Open-Meteo's forecast API answers over plain HTTP on port 80 (no TLS, which the
--  W5500 cannot do), so this is a straight TCP-client GET (GNAT.Sockets) followed
--  by a small scrape of the JSON it returns:
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
with Ada.Real_Time;       use Ada.Real_Time;
with Ada.Streams;         use Ada.Streams;
with GNAT.Sockets;        use GNAT.Sockets;
with ESP32S3.Log;         use ESP32S3.Log;
with DNS_Client;
with W5500_Dev;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   --  ---- the location to forecast (edit these) --------------------------------
   Latitude  : constant String := "33.749";    --  Atlanta, GA, USA
   Longitude : constant String := "-84.388";
   --  ---------------------------------------------------------------------------

   Host_Name   : constant String         := "api.open-meteo.com";
   DNS_Server  : constant Inet_Addr_Type  := Inet_Addr ("8.8.8.8");   --  resolver
   Server_Port : constant Port_Type       := 80;

   DQ : constant String := (1 => '"');                     --  one double-quote

   Sock      : Socket_Type;
   Server_IP : Inet_Addr_Type;
   Buf       : Stream_Element_Array (1 .. 512);
   Last      : Stream_Element_Offset;
   SLast     : Stream_Element_Offset;
   Resp      : String (1 .. 4096);
   Resp_Len  : Natural := 0;

   function To_SEA (S : String) return Stream_Element_Array is
      R : Stream_Element_Array (1 .. S'Length);
   begin
      for I in S'Range loop
         R (Stream_Element_Offset (I - S'First) + 1) := Character'Pos (S (I));
      end loop;
      return R;
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
      P, I, Start : Natural;
   begin
      P := Find (Resp (1 .. Resp_Len), Key, From);
      if P = 0 then
         return "";
      end if;
      I := P + Key'Length;
      if I <= Resp_Len and then Resp (I) = '"' then       --  quoted string value
         I := I + 1;
         Start := I;
         while I <= Resp_Len and then Resp (I) /= '"' loop
            I := I + 1;
         end loop;
      else                                                --  bare number
         Start := I;
         while I <= Resp_Len
           and then Resp (I) /= ',' and then Resp (I) /= '}'
         loop
            I := I + 1;
         end loop;
      end if;
      return Resp (Start .. I - 1);
   end Field;

   --  WMO weather interpretation code -> a short description.
   function Weather (Code : String) return String is
   begin
      if    Code = "0"  then return "clear sky";
      elsif Code = "1"  then return "mainly clear";
      elsif Code = "2"  then return "partly cloudy";
      elsif Code = "3"  then return "overcast";
      elsif Code = "45" or else Code = "48" then return "fog";
      elsif Code = "51" or else Code = "53" or else Code = "55" then
         return "drizzle";
      elsif Code = "56" or else Code = "57" then return "freezing drizzle";
      elsif Code = "61" or else Code = "63" or else Code = "65" then return "rain";
      elsif Code = "66" or else Code = "67" then return "freezing rain";
      elsif Code = "71" or else Code = "73" or else Code = "75" then return "snow";
      elsif Code = "77" then return "snow grains";
      elsif Code = "80" or else Code = "81" or else Code = "82" then
         return "rain showers";
      elsif Code = "85" or else Code = "86" then return "snow showers";
      elsif Code = "95" then return "thunderstorm";
      elsif Code = "96" or else Code = "99" then return "thunderstorm with hail";
      else return "code " & Code;
      end if;
   end Weather;

   Request : constant String :=
     "GET /v1/forecast?latitude=" & Latitude
       & "&longitude=" & Longitude
       & "&current_weather=true HTTP/1.0" & ASCII.CR & ASCII.LF
       & "Host: " & Host_Name & ASCII.CR & ASCII.LF
       & "Connection: close" & ASCII.CR & ASCII.LF
       & ASCII.CR & ASCII.LF;
begin
   delay until Clock + Milliseconds (200);
   Put_Line ("[wx] W5500 weather forecast (Open-Meteo, GNAT.Sockets, TCP)");
   if not W5500_Dev.Bring_Up then
      loop delay until Clock + Seconds (3600); end loop;
   end if;

   --  Resolve the API host by name (portable DNS_Client over GNAT.Sockets).
   Put_Line ("[wx] resolving " & Host_Name & " ...");
   if not DNS_Client.Resolve (DNS_Server, Host_Name, Server_IP, Timeout => 5.0) then
      Put_Line ("[wx] DNS resolution failed (no resolver reply)");
      loop delay until Clock + Seconds (3600); end loop;
   end if;
   Put_Line ("[wx] " & Host_Name & " = " & Image (Server_IP));

   --  Fetch the forecast.
   Create_Socket  (Sock, Family_Inet, Socket_Stream);
   Put_Line ("[wx] GET " & Host_Name & " for " & Latitude & ", " & Longitude & " ...");
   Connect_Socket (Sock, (Family_Inet, Server_IP, Server_Port));
   Send_Socket    (Sock, To_SEA (Request), SLast);

   loop
      Receive_Socket (Sock, Buf, Last);
      exit when Last < Buf'First;                --  server closed the connection
      for E of Buf (Buf'First .. Last) loop
         if Resp_Len < Resp'Last then
            Resp_Len := Resp_Len + 1;
            Resp (Resp_Len) := Character'Val (Integer (E));
         end if;
      end loop;
   end loop;
   Close_Socket (Sock);

   --  Scrape the current_weather object.  Anchor at it first: the JSON also carries
   --  a current_weather_units object whose "temperature" etc. are unit *strings*.
   declare
      CW : constant Natural := Find (Resp (1 .. Resp_Len),
                                     DQ & "current_weather" & DQ & ":");
      At_CW : constant Positive := (if CW = 0 then 1 else CW);

      Temp : constant String := Field (DQ & "temperature"   & DQ & ":", At_CW);
      Wind : constant String := Field (DQ & "windspeed"     & DQ & ":", At_CW);
      Dir  : constant String := Field (DQ & "winddirection" & DQ & ":", At_CW);
      Code : constant String := Field (DQ & "weathercode"   & DQ & ":", At_CW);
      Tim  : constant String := Field (DQ & "time"          & DQ & ":", At_CW);
   begin
      if CW = 0 or else Temp = "" then
         Put_Line ("[wx] could not parse the forecast (response below)");
         Put_Line (Resp (1 .. Resp_Len));
      else
         Put_Line ("[wx] forecast for " & Latitude & ", " & Longitude
                   & "  (" & Tim & " UTC)");
         Put_Line ("[wx]   temperature : " & Temp & " C");
         Put_Line ("[wx]   wind        : " & Wind & " km/h from " & Dir & " deg");
         Put_Line ("[wx]   conditions  : " & Weather (Code));
      end if;
   end;

   loop delay until Clock + Seconds (3600); end loop;
end Main;
