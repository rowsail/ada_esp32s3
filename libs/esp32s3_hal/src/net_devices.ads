with Interfaces;
with Ada.Streams;

--  The chip-neutral contract a network interface must satisfy to back the
--  GNAT.Sockets facade.  Each interface chip provides one concrete implementation
--  of Net_Devices.Device; the facade keeps a registry of them and dispatches, so
--  a board can carry more than one NIC -- potentially of different types -- in a
--  single binary.
--
--  Sockets are addressed by an index 0 .. Socket_Count-1 that the device maps to
--  its own per-socket state (the W5500, for instance, has eight hardware sockets).
--  This is the offloaded-stack model: the device provides TCP/UDP sockets directly.
--  A raw-MAC chip would need a software TCP/IP stack implementing this interface.
package Net_Devices is

   subtype Octet is Interfaces.Unsigned_8;
   type IPv4_Address is array (0 .. 3) of Octet;
   type MAC_Address  is array (0 .. 5) of Octet;
   subtype Port_Number is Interfaces.Unsigned_16;

   --  How many interfaces a board may carry, and the id that names one in the
   --  registry / routing table.  Bump Max_Interfaces if a board needs more.
   Max_Interfaces : constant := 4;
   type Interface_Id is range 0 .. Max_Interfaces - 1;

   --  Mirrors ESP32S3.W5500.Sockets.Status literal-for-literal (so a backend over
   --  that engine can convert by position).
   type Status is
     (OK, Not_Open, Closed_By_Peer, Timed_Out, Refused, No_Space, Error);

   type Transport is (TCP, UDP);

   --  A network interface.  Limited (it owns hardware/socket state); dispatched on.
   type Device is limited interface;
   type Device_Access is access all Device'Class;

   --  How many sockets this interface offers, and its current IPv4 configuration
   --  (used for routing a destination to the right interface).
   function Socket_Count (Self : Device) return Positive is abstract;
   function Local_IP     (Self : Device) return IPv4_Address is abstract;
   function Subnet_Mask  (Self : Device) return IPv4_Address is abstract;

   --  Is this interface usable right now -- physically up and with an address?
   --  Routing consults this so traffic only goes out a live interface and can fail
   --  over when one drops; a pinned socket uses it to fail closed when its
   --  interface is down.  (For the W5500: PHY link up and a non-zero IP.)
   function Is_Up (Self : Device) return Boolean is abstract;

   --  Open socket Index for TCP or UDP on Local_Port (0 = unbound/ephemeral).
   procedure Open (Self       : in out Device;
                   Index      : Natural;
                   Mode       : Transport;
                   Local_Port : Port_Number;
                   Result     : out Status) is abstract;

   procedure Close (Self : in out Device; Index : Natural) is abstract;

   --  TCP server: move to LISTEN; block until a client connects; report the peer.
   procedure Listen (Self : in out Device; Index : Natural;
                     Result : out Status) is abstract;
   procedure Wait_Connected (Self : in out Device; Index : Natural;
                            Result : out Status) is abstract;
   procedure Peer (Self : in out Device; Index : Natural;
                  Addr : out IPv4_Address; Port : out Port_Number) is abstract;

   --  TCP client: connect to Host:Port.
   procedure Connect (Self : in out Device; Index : Natural;
                     Host : IPv4_Address; Port : Port_Number;
                     Result : out Status) is abstract;

   --  TCP data transfer.  Wait_Data blocks until data is ready, the peer closes,
   --  or the receive timeout elapses (Timed_Out).
   procedure Wait_Data (Self : in out Device; Index : Natural;
                       Result : out Status) is abstract;
   procedure Send (Self : in out Device; Index : Natural;
                  Data : Ada.Streams.Stream_Element_Array;
                  Sent : out Natural; Result : out Status) is abstract;
   procedure Receive (Self : in out Device; Index : Natural;
                     Into : out Ada.Streams.Stream_Element_Array;
                     Count : out Natural; Result : out Status) is abstract;

   --  UDP datagrams.
   procedure Send_To (Self : in out Device; Index : Natural;
                     Host : IPv4_Address; Port : Port_Number;
                     Data : Ada.Streams.Stream_Element_Array;
                     Result : out Status) is abstract;
   procedure Receive_From (Self : in out Device; Index : Natural;
                          From : out IPv4_Address; From_Port : out Port_Number;
                          Into : out Ada.Streams.Stream_Element_Array;
                          Count : out Natural; Result : out Status) is abstract;

   procedure Set_Receive_Timeout (Self : in out Device; Index : Natural;
                                 To : Duration) is abstract;

end Net_Devices;
