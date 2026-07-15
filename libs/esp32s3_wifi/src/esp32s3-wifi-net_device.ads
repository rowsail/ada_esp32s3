--  Presents the Wi-Fi link as a Net_Devices.Device so the chip-neutral stack
--  (GNAT.Sockets, DNS_Client, NTP_Client, TLS_Client) runs over Wi-Fi.
--
--  Phase 1-2: the UDP primitives are backed by the pure-Ada ESP32S3.WiFi.IP
--  engine (which must be Started + addressed, e.g. by DHCP, first).  The TCP
--  primitives are not implemented yet and report Net_Devices.Error.
--
--  Concurrency: single-owner, like the underlying engine -- one task drives the
--  sockets.  Received frames are enqueued by the Wi-Fi task; Send_To / Receive_
--  From / the blocking waits all pump ESP32S3.WiFi.IP.Poll on the caller's task.
with Ada.Streams;
with Net_Devices;
with ESP32S3.WiFi.IP;

package ESP32S3.WiFi.Net_Device is

   type Instance is limited new Net_Devices.Device with private;

   --  Register the single Wi-Fi NIC with the GNAT.Sockets facade.  Call once
   --  the link is associated and the interface has an address (after DHCP).
   procedure Register_Default;

private

   type Timeout_Array is array (ESP32S3.WiFi.IP.Socket_Id) of Duration;

   type Instance is limited new Net_Devices.Device with record
      Timeouts : Timeout_Array := (others => 0.0);
   end record;

   overriding function Socket_Count (Self : Instance) return Positive;
   overriding function Local_IP     (Self : Instance) return Net_Devices.IPv4_Address;
   overriding function Subnet_Mask  (Self : Instance) return Net_Devices.IPv4_Address;
   overriding function Is_Up        (Self : Instance) return Boolean;

   overriding procedure Open
     (Self : in out Instance; Index : Natural; Mode : Net_Devices.Transport;
      Local_Port : Net_Devices.Port_Number; Result : out Net_Devices.Status);
   overriding procedure Close (Self : in out Instance; Index : Natural);

   overriding procedure Listen
     (Self : in out Instance; Index : Natural; Result : out Net_Devices.Status);
   overriding procedure Wait_Connected
     (Self : in out Instance; Index : Natural; Result : out Net_Devices.Status);
   overriding procedure Peer
     (Self : in out Instance; Index : Natural;
      Addr : out Net_Devices.IPv4_Address; Port : out Net_Devices.Port_Number);

   overriding procedure Connect
     (Self : in out Instance; Index : Natural; Host : Net_Devices.IPv4_Address;
      Port : Net_Devices.Port_Number; Result : out Net_Devices.Status);
   overriding procedure Wait_Data
     (Self : in out Instance; Index : Natural; Result : out Net_Devices.Status);
   overriding function Available (Self : Instance; Index : Natural) return Natural;
   overriding procedure Send
     (Self : in out Instance; Index : Natural;
      Data : Ada.Streams.Stream_Element_Array;
      Sent : out Natural; Result : out Net_Devices.Status);
   overriding procedure Receive
     (Self : in out Instance; Index : Natural;
      Into : out Ada.Streams.Stream_Element_Array;
      Count : out Natural; Result : out Net_Devices.Status);

   overriding procedure Send_To
     (Self : in out Instance; Index : Natural; Host : Net_Devices.IPv4_Address;
      Port : Net_Devices.Port_Number; Data : Ada.Streams.Stream_Element_Array;
      Result : out Net_Devices.Status);
   overriding procedure Receive_From
     (Self : in out Instance; Index : Natural;
      From : out Net_Devices.IPv4_Address; From_Port : out Net_Devices.Port_Number;
      Into : out Ada.Streams.Stream_Element_Array;
      Count : out Natural; Result : out Net_Devices.Status);

   overriding procedure Set_Receive_Timeout
     (Self : in out Instance; Index : Natural; To : Duration);

end ESP32S3.WiFi.Net_Device;
