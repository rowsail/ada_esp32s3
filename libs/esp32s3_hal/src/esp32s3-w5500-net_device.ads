with Net_Devices;
with ESP32S3.W5500.Sockets;
with Ada.Streams;

--  The W5500 as a concrete Net_Devices.Device, so it can back the GNAT.Sockets
--  facade through the chip-neutral interface (the first such backend).  An Instance
--  wraps one W5500 chip and owns that chip's eight hardware sockets.
package ESP32S3.W5500.Net_Device is

   type Instance is limited new Net_Devices.Device with private;

   --  Bind this interface object to a W5500 that is already Setup / Reset /
   --  Configured.  Call once before registering it with GNAT.Sockets.
   procedure Attach (Self : in out Instance; Dev : access ESP32S3.W5500.Device);

   --  Convenience for the common single-NIC board: attach a built-in interface
   --  object to Dev and register it with GNAT.Sockets as the default interface.
   --  For multiple NICs, declare your own aliased Instance objects, Attach each,
   --  and register them with GNAT.Sockets.Add_Interface.
   procedure Register_Default (Dev : access ESP32S3.W5500.Device);

private
   package WS renames ESP32S3.W5500.Sockets;

   type Socket_Array is array (Socket_Id) of WS.Socket;

   type Instance is limited new Net_Devices.Device with record
      Dev   : access ESP32S3.W5500.Device := null;
      Socks : Socket_Array;
   end record;

   overriding function Socket_Count (Self : Instance) return Positive;
   overriding function Local_IP     (Self : Instance) return Net_Devices.IPv4_Address;
   overriding function Subnet_Mask  (Self : Instance) return Net_Devices.IPv4_Address;
   overriding function Is_Up        (Self : Instance) return Boolean;

   overriding procedure Open (Self : in out Instance; Index : Natural;
                              Mode : Net_Devices.Transport;
                              Local_Port : Net_Devices.Port_Number;
                              Result : out Net_Devices.Status);
   overriding procedure Close (Self : in out Instance; Index : Natural);
   overriding procedure Listen (Self : in out Instance; Index : Natural;
                                Result : out Net_Devices.Status);
   overriding procedure Wait_Connected (Self : in out Instance; Index : Natural;
                                        Result : out Net_Devices.Status);
   overriding procedure Peer (Self : in out Instance; Index : Natural;
                              Addr : out Net_Devices.IPv4_Address;
                              Port : out Net_Devices.Port_Number);
   overriding procedure Connect (Self : in out Instance; Index : Natural;
                                 Host : Net_Devices.IPv4_Address;
                                 Port : Net_Devices.Port_Number;
                                 Result : out Net_Devices.Status);
   overriding procedure Wait_Data (Self : in out Instance; Index : Natural;
                                   Result : out Net_Devices.Status);
   overriding procedure Send (Self : in out Instance; Index : Natural;
                              Data : Ada.Streams.Stream_Element_Array;
                              Sent : out Natural; Result : out Net_Devices.Status);
   overriding procedure Receive (Self : in out Instance; Index : Natural;
                                 Into : out Ada.Streams.Stream_Element_Array;
                                 Count : out Natural; Result : out Net_Devices.Status);
   overriding procedure Send_To (Self : in out Instance; Index : Natural;
                                 Host : Net_Devices.IPv4_Address;
                                 Port : Net_Devices.Port_Number;
                                 Data : Ada.Streams.Stream_Element_Array;
                                 Result : out Net_Devices.Status);
   overriding procedure Receive_From (Self : in out Instance; Index : Natural;
                                      From : out Net_Devices.IPv4_Address;
                                      From_Port : out Net_Devices.Port_Number;
                                      Into : out Ada.Streams.Stream_Element_Array;
                                      Count : out Natural;
                                      Result : out Net_Devices.Status);
   overriding procedure Set_Receive_Timeout (Self : in out Instance; Index : Natural;
                                             To : Duration);
end ESP32S3.W5500.Net_Device;
