with Ada.Real_Time; use Ada.Real_Time;
with GNAT.Sockets;

package body ESP32S3.WiFi.Net_Device is

   package Net renames ESP32S3.WiFi.IP;
   use all type Net_Devices.Status;
   use all type Net_Devices.Transport;

   --  IP.IPv4 and Net_Devices.IPv4_Address are both array (0..3) of the same
   --  octet type -- convert by position.
   function To_N (A : Net.IPv4) return Net_Devices.IPv4_Address is
     (Net_Devices.IPv4_Address (A));
   function To_IP (A : Net_Devices.IPv4_Address) return Net.IPv4 is
     (Net.IPv4 (A));

   --  ------------------------------------------------------------------ query
   overriding function Socket_Count (Self : Instance) return Positive is
     (Natural (Net.Socket_Id'Last) + 1);

   overriding function Local_IP (Self : Instance) return Net_Devices.IPv4_Address
   is (To_N (Net.Local_Address));

   overriding function Subnet_Mask (Self : Instance) return Net_Devices.IPv4_Address
   is (To_N (Net.Subnet_Mask));

   overriding function Is_Up (Self : Instance) return Boolean is
     (ESP32S3.WiFi.Connected and then Net.Configured);

   --  --------------------------------------------------------------- sockets
   overriding procedure Open
     (Self : in out Instance; Index : Natural; Mode : Net_Devices.Transport;
      Local_Port : Net_Devices.Port_Number; Result : out Net_Devices.Status)
   is
      Success : Boolean;
   begin
      case Mode is
         when UDP =>
            Net.Open (Net.Socket_Id (Index), Net.U16 (Local_Port), Success);
         when TCP =>
            Net.TCP_Open (Net.Socket_Id (Index), Net.U16 (Local_Port), Success);
      end case;
      Result := (if Success then OK else Error);
   end Open;

   overriding procedure Close (Self : in out Instance; Index : Natural) is
      Id : constant Net.Socket_Id := Net.Socket_Id (Index);
   begin
      Net.TCP_Close (Id);   --  sends a FIN if a TCP connection is open
      Net.Close (Id);       --  releases the UDP socket (no-op if it was TCP)
   end Close;

   --  ---------------------------------------------------------- TCP (client)
   --  Server-side accept is not implemented (this NIC is a client stack).
   overriding procedure Listen
     (Self : in out Instance; Index : Natural; Result : out Net_Devices.Status)
   is
   begin
      Result := Error;
   end Listen;

   overriding procedure Wait_Connected
     (Self : in out Instance; Index : Natural; Result : out Net_Devices.Status)
   is
   begin
      Result := Error;
   end Wait_Connected;

   overriding procedure Peer
     (Self : in out Instance; Index : Natural;
      Addr : out Net_Devices.IPv4_Address; Port : out Net_Devices.Port_Number)
   is
      A : Net.IPv4;
      P : Net.U16;
   begin
      Net.TCP_Peer (Net.Socket_Id (Index), A, P);
      Addr := To_N (A);
      Port := Net_Devices.Port_Number (P);
   end Peer;

   Connect_Timeout : constant Duration := 10.0;

   overriding procedure Connect
     (Self : in out Instance; Index : Natural; Host : Net_Devices.IPv4_Address;
      Port : Net_Devices.Port_Number; Result : out Net_Devices.Status)
   is
      Id       : constant Net.Socket_Id := Net.Socket_Id (Index);
      Deadline : constant Time := Clock + To_Time_Span (Connect_Timeout);
      Started  : Boolean;
   begin
      Net.TCP_Connect (Id, To_IP (Host), Net.U16 (Port), Started);
      if not Started then
         Result := Error;                --  no route / ARP failure
         return;
      end if;
      loop
         Net.Poll;
         if Net.TCP_Connected (Id) then
            Result := OK;
            return;
         elsif Net.TCP_Failed (Id) then
            Result := Refused;
            return;
         end if;
         exit when Clock >= Deadline;
         delay until Clock + Milliseconds (5);
      end loop;
      Result := Timed_Out;
   end Connect;

   overriding procedure Wait_Data
     (Self : in out Instance; Index : Natural; Result : out Net_Devices.Status)
   is
      Id       : constant Net.Socket_Id := Net.Socket_Id (Index);
      Timeout  : constant Duration := Self.Timeouts (Id);
      Deadline : constant Time := Clock + To_Time_Span (Timeout);
   begin
      --  The facade calls Wait_Data before EVERY receive, UDP included.  A UDP
      --  socket has no TCP state to wait on, so return Error and let the
      --  facade fall through to Receive_From (its own poll loop).
      if not Net.TCP_Is_Open (Id) then
         Result := Error;
         return;
      end if;
      loop
         Net.Poll;
         if Net.TCP_Available (Id) > 0 then
            Result := OK;                --  data ready (drain it before EOF)
            return;
         elsif Net.TCP_Peer_Closed (Id) then
            Result := Closed_By_Peer;
            return;
         elsif Net.TCP_Failed (Id) then
            Result := Error;
            return;
         end if;
         exit when Timeout > 0.0 and then Clock >= Deadline;
         delay until Clock + Milliseconds (5);
      end loop;
      Result := Timed_Out;
   end Wait_Data;

   overriding function Available (Self : Instance; Index : Natural) return Natural
   is (Net.TCP_Available (Net.Socket_Id (Index)));

   overriding procedure Send
     (Self : in out Instance; Index : Natural;
      Data : Ada.Streams.Stream_Element_Array;
      Sent : out Natural; Result : out Net_Devices.Status)
   is
      Id      : constant Net.Socket_Id := Net.Socket_Id (Index);
      Payload : Net.Byte_Array (0 .. Natural (Data'Length) - 1)
        with Import, Address => Data'Address;
      Offset  : Natural := 0;
      Took    : Natural;
   begin
      --  Push the whole buffer, one stop-and-wait segment at a time.  There is
      --  no timeout on Send in the interface; bail only if the connection dies.
      while Offset < Payload'Length loop
         Net.Poll;
         if Net.TCP_Failed (Id) then
            Sent := Offset;
            Result := Error;
            return;
         end if;
         Net.TCP_Send (Id, Payload (Offset .. Payload'Last), Took);
         Offset := Offset + Took;
         if Took = 0 then
            delay until Clock + Milliseconds (2);
         end if;
      end loop;
      Sent := Offset;
      Result := OK;
   end Send;

   overriding procedure Receive
     (Self : in out Instance; Index : Natural;
      Into : out Ada.Streams.Stream_Element_Array;
      Count : out Natural; Result : out Net_Devices.Status)
   is
      Id  : constant Net.Socket_Id := Net.Socket_Id (Index);
      Buf : Net.Byte_Array (0 .. Natural (Into'Length) - 1)
        with Import, Address => Into'Address;
   begin
      Net.Poll;
      Net.TCP_Receive (Id, Buf, Count);
      if Count > 0 then
         Result := OK;
      elsif Net.TCP_Peer_Closed (Id) then
         Result := Closed_By_Peer;
      else
         Result := OK;                    --  nothing yet; caller re-waits
      end if;
   end Receive;

   --  ------------------------------------------------------------------- UDP
   overriding procedure Send_To
     (Self : in out Instance; Index : Natural; Host : Net_Devices.IPv4_Address;
      Port : Net_Devices.Port_Number; Data : Ada.Streams.Stream_Element_Array;
      Result : out Net_Devices.Status)
   is
      Payload : Net.Byte_Array (0 .. Natural (Data'Length) - 1)
        with Import, Address => Data'Address;
      Success : Boolean;
   begin
      Net.Send_To (Net.Socket_Id (Index), To_IP (Host), Net.U16 (Port), Payload, Success);
      Result := (if Success then OK else Error);
   end Send_To;

   overriding procedure Receive_From
     (Self : in out Instance; Index : Natural;
      From : out Net_Devices.IPv4_Address; From_Port : out Net_Devices.Port_Number;
      Into : out Ada.Streams.Stream_Element_Array;
      Count : out Natural; Result : out Net_Devices.Status)
   is
      Id       : constant Net.Socket_Id := Net.Socket_Id (Index);
      Timeout  : constant Duration := Self.Timeouts (Id);
      Deadline : constant Time := Clock + To_Time_Span (Timeout);
      Buf      : Net.Byte_Array (0 .. Natural (Into'Length) - 1)
        with Import, Address => Into'Address;
      F        : Net.IPv4;
      FP       : Net.U16;
      N        : Natural;
   begin
      loop
         Net.Poll;
         Net.Receive_From (Id, F, FP, Buf, N);
         if N > 0 then
            From := To_N (F);
            From_Port := Net_Devices.Port_Number (FP);
            Count := N;
            Result := OK;
            return;
         end if;
         exit when Timeout > 0.0 and then Clock >= Deadline;
         delay until Clock + Milliseconds (5);
      end loop;
      From := (0, 0, 0, 0);
      From_Port := 0;
      Count := 0;
      Result := Timed_Out;
   end Receive_From;

   overriding procedure Set_Receive_Timeout
     (Self : in out Instance; Index : Natural; To : Duration)
   is
   begin
      Self.Timeouts (Net.Socket_Id (Index)) := To;
   end Set_Receive_Timeout;

   --  --------------------------------------------------------------- registry
   --  The instance must outlive Main (the facade registry holds a reference),
   --  so it lives at library level here.
   Default : aliased Instance;

   procedure Register_Default is
   begin
      GNAT.Sockets.Initialize (Default'Access);
   end Register_Default;

end ESP32S3.WiFi.Net_Device;
