with Ada.Streams; use Ada.Streams;
with GNAT.Sockets;

package body ESP32S3.W5500.Net_Device is

   --  ESP32S3.W5500.Sockets.Status and Net_Devices.Status share their literals in
   --  the same order, so convert by position.
   function N (St : WS.Status) return Net_Devices.Status is
     (Net_Devices.Status'Val (WS.Status'Pos (St)));

   function To_W (A : Net_Devices.IPv4_Address) return IPv4_Address is
     (IPv4 (Byte (A (0)), Byte (A (1)), Byte (A (2)), Byte (A (3))));

   function To_N (A : IPv4_Address) return Net_Devices.IPv4_Address is
     (0 => Net_Devices.Octet (A (0)), 1 => Net_Devices.Octet (A (1)),
      2 => Net_Devices.Octet (A (2)), 3 => Net_Devices.Octet (A (3)));

   function Dev_Acc (Self : Instance) return WS.Device_Access is
     (WS.Device_Access (Self.Dev));

   procedure Attach (Self : in out Instance; Dev : access ESP32S3.W5500.Device) is
   begin
      Self.Dev := Dev;
   end Attach;

   overriding function Socket_Count (Self : Instance) return Positive is
      pragma Unreferenced (Self);
   begin
      return Positive (Socket_Id'Last) + 1;       --  eight hardware sockets
   end Socket_Count;

   overriding function Local_IP (Self : Instance) return Net_Devices.IPv4_Address is
     (To_N (Get_IP (Self.Dev.all)));

   overriding function Subnet_Mask (Self : Instance)
                                    return Net_Devices.IPv4_Address is
      Tmp : IPv4_Address;
   begin
      Read (Self.Dev.all, Common_Regs, 16#05#, Tmp);     --  SUBR
      return To_N (Tmp);
   end Subnet_Mask;

   --  Usable now = a chip is attached, the PHY link is up, and an address is set.
   overriding function Is_Up (Self : Instance) return Boolean is
   begin
      return Self.Dev /= null
        and then Link (Self.Dev.all) = Up
        and then Get_IP (Self.Dev.all) /= IPv4_Address'(0, 0, 0, 0);
   end Is_Up;

   overriding procedure Open (Self : in out Instance; Index : Natural;
                              Mode : Net_Devices.Transport;
                              Local_Port : Net_Devices.Port_Number;
                              Result : out Net_Devices.Status) is
      use all type Net_Devices.Transport;
      I  : constant Socket_Id := Socket_Id (Index);
      St : WS.Status;
   begin
      case Mode is
         when TCP =>
            WS.Open_TCP (Dev_Acc (Self), Self.Socks (I), I,
                         WS.Port_Number (Local_Port), St);
         when UDP =>
            WS.Open_UDP (Dev_Acc (Self), Self.Socks (I), I,
                         WS.Port_Number (Local_Port), St);
      end case;
      Result := N (St);
   end Open;

   overriding procedure Close (Self : in out Instance; Index : Natural) is
   begin
      WS.Close (Self.Socks (Socket_Id (Index)));
   end Close;

   overriding procedure Listen (Self : in out Instance; Index : Natural;
                                Result : out Net_Devices.Status) is
      St : WS.Status;
   begin
      WS.Listen (Self.Socks (Socket_Id (Index)), St);
      Result := N (St);
   end Listen;

   overriding procedure Wait_Connected (Self : in out Instance; Index : Natural;
                                        Result : out Net_Devices.Status) is
      St : WS.Status;
   begin
      WS.Wait_Connected (Self.Socks (Socket_Id (Index)), St);
      Result := N (St);
   end Wait_Connected;

   overriding procedure Peer (Self : in out Instance; Index : Natural;
                              Addr : out Net_Devices.IPv4_Address;
                              Port : out Net_Devices.Port_Number) is
      I : constant Socket_Id := Socket_Id (Index);
      P : IPv4_Address;
   begin
      Read (Self.Dev.all, Socket_Regs (I), 16#0C#, P);              --  Sn_DIPR
      Addr := To_N (P);
      Port := Net_Devices.Port_Number
                (Read_U16 (Self.Dev.all, Socket_Regs (I), 16#10#));  --  Sn_DPORT
   end Peer;

   overriding procedure Connect (Self : in out Instance; Index : Natural;
                                 Host : Net_Devices.IPv4_Address;
                                 Port : Net_Devices.Port_Number;
                                 Result : out Net_Devices.Status) is
      St : WS.Status;
   begin
      WS.Connect (Self.Socks (Socket_Id (Index)), To_W (Host),
                  WS.Port_Number (Port), St);
      Result := N (St);
   end Connect;

   overriding procedure Wait_Data (Self : in out Instance; Index : Natural;
                                   Result : out Net_Devices.Status) is
      St : WS.Status;
   begin
      WS.Wait_Data (Self.Socks (Socket_Id (Index)), St);
      Result := N (St);
   end Wait_Data;

   overriding procedure Send (Self : in out Instance; Index : Natural;
                              Data : Stream_Element_Array;
                              Sent : out Natural;
                              Result : out Net_Devices.Status) is
      St  : WS.Status;
      Src : Byte_Array (0 .. Natural (Data'Length) - 1)
              with Import, Address => Data'Address;
   begin
      WS.Send (Self.Socks (Socket_Id (Index)), Src, Sent, St);
      Result := N (St);
   end Send;

   overriding procedure Receive (Self : in out Instance; Index : Natural;
                                 Into : out Stream_Element_Array;
                                 Count : out Natural;
                                 Result : out Net_Devices.Status) is
      St  : WS.Status;
      Dst : Byte_Array (0 .. Natural (Into'Length) - 1)
              with Import, Address => Into'Address;
   begin
      WS.Receive (Self.Socks (Socket_Id (Index)), Dst, Count, St);
      Result := N (St);
   end Receive;

   overriding procedure Send_To (Self : in out Instance; Index : Natural;
                                 Host : Net_Devices.IPv4_Address;
                                 Port : Net_Devices.Port_Number;
                                 Data : Stream_Element_Array;
                                 Result : out Net_Devices.Status) is
      St  : WS.Status;
      Src : Byte_Array (0 .. Natural (Data'Length) - 1)
              with Import, Address => Data'Address;
   begin
      WS.Send_To (Self.Socks (Socket_Id (Index)), To_W (Host),
                  WS.Port_Number (Port), Src, St);
      Result := N (St);
   end Send_To;

   overriding procedure Receive_From (Self : in out Instance; Index : Natural;
                                      From : out Net_Devices.IPv4_Address;
                                      From_Port : out Net_Devices.Port_Number;
                                      Into : out Stream_Element_Array;
                                      Count : out Natural;
                                      Result : out Net_Devices.Status) is
      St  : WS.Status;
      FA  : IPv4_Address;
      FP  : WS.Port_Number;
      Dst : Byte_Array (0 .. Natural (Into'Length) - 1)
              with Import, Address => Into'Address;
   begin
      WS.Receive_From (Self.Socks (Socket_Id (Index)), FA, FP, Dst, Count, St);
      From      := To_N (FA);
      From_Port := Net_Devices.Port_Number (FP);
      Result    := N (St);
   end Receive_From;

   overriding procedure Set_Receive_Timeout (Self : in out Instance; Index : Natural;
                                             To : Duration) is
   begin
      WS.Set_Receive_Timeout (Self.Socks (Socket_Id (Index)), To);
   end Set_Receive_Timeout;

   --  Single-NIC convenience: one built-in interface object, registered as default.
   Default_Eth : aliased Instance;
   Default_Ref : constant Net_Devices.Device_Access := Default_Eth'Access;

   procedure Register_Default (Dev : access ESP32S3.W5500.Device) is
   begin
      Attach (Default_Eth, Dev);
      GNAT.Sockets.Initialize (Default_Ref);
   end Register_Default;

end ESP32S3.W5500.Net_Device;
