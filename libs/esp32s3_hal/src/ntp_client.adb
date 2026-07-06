with Ada.Streams;  use Ada.Streams;
with GNAT.Sockets; use GNAT.Sockets;
with Interfaces;   use Interfaces;
with ESP32S3.Endian;

package body NTP_Client with SPARK_Mode => On is

   NTP_Unix : constant := 2_208_988_800;   --  seconds from 1900-01-01 to 1970-01-01

   function Query
     (Server     : Inet_Addr_Type;
      Unix_Time  : out Interfaces.Integer_64;
      Timeout    : Duration := 0.0;
      Local_Port : Port_Type := 12_300) return Boolean
   with SPARK_Mode => Off
   is
      Sock : Socket_Type;
      --  48-byte SNTP request: LI=0, VN=3, Mode=3 (client) in the first byte.
      Req  : constant Stream_Element_Array (0 .. 47) := (0 => 16#1B#, others => 0);
      Resp : Stream_Element_Array (0 .. 47);
      Last : Stream_Element_Offset;
      To   : aliased Sock_Addr_Type := (Family_Inet, Server, 123);
      From : aliased Sock_Addr_Type;
      Secs : Unsigned_32;
   begin
      Unix_Time := 0;
      Create_Socket (Sock, Family_Inet, Socket_Datagram);
      Bind_Socket (Sock, (Family_Inet, Any_Inet_Addr, Local_Port));
      if Timeout > 0.0 then
         Set_Socket_Option (Sock, Socket_Level, (Receive_Timeout, Timeout => Timeout));
      end if;
      begin
         --  Send inside the handler too: Send_Socket can raise (e.g. an ARP
         --  timeout to the server) and a leaked datagram socket would drain the
         --  8-slot pool over repeated failures.
         Send_Socket (Sock, Req, Last, To => To'Access);
         Receive_Socket (Sock, Resp, Last, From => From'Access);
      exception
         when Socket_Error =>
            --  no reply within Timeout (or send failed)
            Close_Socket (Sock);
            return False;
      end;
      Close_Socket (Sock);

      --  Only trust a genuine server reply for THIS query, not a stray or spoofed
      --  datagram that happened to arrive on Local_Port within the timeout: it
      --  must come from the queried server, be Mode 4 (server), and carry a sane
      --  stratum (1 .. 15; 0 = kiss-o'-death / unsynchronised, > 15 = reserved).
      if Last < 43                                     --  txstamp is bytes 40..43
        or else From.Addr /= Server
        or else (Resp (0) and 2#0000_0111#) /= 4       --  Mode = server
        or else Resp (1) = 0
        or else Resp (1) > 15     --  Stratum
      then
         return False;
      end if;
      Secs :=
        ESP32S3.Endian.Join_BE32
          (Unsigned_8 (Resp (40)),
           Unsigned_8 (Resp (41)),
           Unsigned_8 (Resp (42)),
           Unsigned_8 (Resp (43)));
      if Secs = 0 then
         --  unsynchronised / kiss-o'-death
         return False;
      end if;
      Unix_Time := Integer_64 (Secs) - NTP_Unix;
      return True;
   end Query;

   procedure To_UTC
     (Unix_Time : Interfaces.Integer_64;
      Year      : out Integer;
      Month     : out Integer;
      Day       : out Integer;
      Hour      : out Integer;
      Minute    : out Integer;
      Second    : out Integer)
   is
      Epoch_Days   : constant Integer_64 := Unix_Time / 86_400;
      Secs_Of_Day  : constant Integer_64 := Unix_Time mod 86_400;
      Shifted_Days : constant Integer_64 := Epoch_Days + 719_468;
      Era          : constant Integer_64 := Shifted_Days / 146_097;
      Day_Of_Era   : constant Integer_64 := Shifted_Days - Era * 146_097;
      Year_Of_Era  : constant Integer_64 :=
        (Day_Of_Era - Day_Of_Era / 1460 + Day_Of_Era / 36524 - Day_Of_Era / 146096) / 365;
      Shifted_Year : constant Integer_64 := Year_Of_Era + Era * 400;
      Day_Of_Year  : constant Integer_64 :=
        Day_Of_Era - (365 * Year_Of_Era + Year_Of_Era / 4 - Year_Of_Era / 100);
      Month_Index  : constant Integer_64 := (5 * Day_Of_Year + 2) / 153;
   begin
      Day := Integer (Day_Of_Year - (153 * Month_Index + 2) / 5 + 1);
      Month := Integer (if Month_Index < 10 then Month_Index + 3 else Month_Index - 9);
      Year := Integer (if Month <= 2 then Shifted_Year + 1 else Shifted_Year);
      Hour := Integer (Secs_Of_Day / 3600);
      Minute := Integer ((Secs_Of_Day mod 3600) / 60);
      Second := Integer (Secs_Of_Day mod 60);
   end To_UTC;

end NTP_Client;
