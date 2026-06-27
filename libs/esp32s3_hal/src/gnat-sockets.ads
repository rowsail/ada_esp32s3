with Ada.Streams;
with Net_Devices;

--  A bare-metal subset of GNAT.Sockets, backed by one or more registered network
--  interfaces (Net_Devices.Device) -- the WIZnet W5500 being the first such chip.
--  Networking code written against the standard GNAT.Sockets API -- Create_Socket /
--  Bind / Listen / Accept / Connect / Send / Receive / Close, the Stream over a
--  socket -- compiles and runs here unchanged, within the subset below.
--
--  Differences from desktop GNAT.Sockets, by necessity:
--    * IPv4 only (Family_Inet); the backends here have no IPv6 yet.
--    * Bare-metal init: register at least one interface (Initialize, or
--      Add_Interface for more than one) before any socket op -- desktop
--      GNAT.Sockets' Initialize takes no argument; here we must say which chip(s).
--    * A finite number of sockets (the sum the interfaces provide); Create_Socket
--      past that raises Socket_Error.
--    * Accept_Socket returns the listening socket itself as the connected socket
--      (the W5500 listener *becomes* the connection); to accept again, re-Listen.
--
--  Multiple interfaces: register each with Add_Interface (the first registered is
--  the default).  Per-destination routing across interfaces is not wired yet --
--  for now every socket uses the default interface.
--
--  Requires the embedded or full profile (the socket engine uses controlled
--  handles + Ada.Real_Time).
package GNAT.Sockets is

   --  Identifies a registered interface (0 = the first / default).  Shared with
   --  Net_Devices / Net_Routes so the registry and the routing table agree.
   subtype Interface_Id is Net_Devices.Interface_Id;

   --  Register a network interface; the first one registered is the default.
   --  Returns its id.  (A Net_Devices.Device is provided by a chip driver, e.g.
   --  ESP32S3.W5500.Net_Device.)
   function Add_Interface (Device : Net_Devices.Device_Access) return Interface_Id;

   --  Convenience for a single-interface board: register Device as the default.
   procedure Initialize (Device : Net_Devices.Device_Access);

   type Port_Type is range 0 .. 65535;

   type Family_Type is (Family_Inet);                  --  IPv4 only
   type Mode_Type   is (Socket_Stream, Socket_Datagram);

   type Inet_Addr_Type is private;
   function Inet_Addr (Image : String) return Inet_Addr_Type;   --  "a.b.c.d"
   function Image (Value : Inet_Addr_Type) return String;        --  -> "a.b.c.d"
   Any_Inet_Addr : constant Inet_Addr_Type;                      --  0.0.0.0

   type Sock_Addr_Type is record
      Family : Family_Type   := Family_Inet;
      Addr   : Inet_Addr_Type;
      Port   : Port_Type     := 0;
   end record;

   type Socket_Type is private;
   No_Socket : constant Socket_Type;

   Socket_Error : exception;

   procedure Create_Socket (Socket : out Socket_Type;
                            Family  : Family_Type := Family_Inet;
                            Mode    : Mode_Type   := Socket_Stream);

   --  Set the local port for a server (TCP) or the bound port (UDP).  Binding to a
   --  specific interface's own address (rather than Any_Inet_Addr) also PINS the
   --  socket to that interface (see Set_Interface).
   procedure Bind_Socket (Socket : in out Socket_Type; Address : Sock_Addr_Type);

   --  Pin Socket to exactly one interface: it uses only Iface, and Connect FAILS
   --  (Socket_Error) rather than re-routing if that interface is down -- a hard
   --  "this traffic must never leave this link" for isolation/billing/compliance.
   --  Unpinned sockets (the default) route by destination via the routing table.
   procedure Set_Interface (Socket : in out Socket_Type; Iface : Interface_Id);

   procedure Listen_Socket (Socket : in out Socket_Type; Length : Natural := 15);

   --  Block until a client connects; Socket is the connection, Address the peer.
   procedure Accept_Socket (Server  : Socket_Type;
                            Socket  : out Socket_Type;
                            Address : out Sock_Addr_Type);

   --  The local address bound to Socket: the interface's own IP (the chip's
   --  configured source address, set at bring-up be it static or DHCP) and the
   --  socket's local port.  PASV, for one, advertises this so a client knows where
   --  to open the data connection.  Mirrors desktop GNAT.Sockets' Get_Socket_Name.
   function Get_Socket_Name (Socket : Socket_Type) return Sock_Addr_Type;

   procedure Connect_Socket (Socket : in out Socket_Type; Server : Sock_Addr_Type);

   --  Send Item; Last is the index of the last element sent (Item'First - 1 if
   --  none).  To /= null sends a UDP datagram to that address.
   procedure Send_Socket (Socket : Socket_Type;
                         Item   : Ada.Streams.Stream_Element_Array;
                         Last   : out Ada.Streams.Stream_Element_Offset;
                         To     : access Sock_Addr_Type := null);

   --  Block until data arrives, then fill Item; Last is the last index written
   --  (Item'First - 1 when the TCP peer has closed -- end of stream).  From /=
   --  null receives a UDP datagram and reports the sender.
   procedure Receive_Socket (Socket : Socket_Type;
                            Item   : out Ada.Streams.Stream_Element_Array;
                            Last   : out Ada.Streams.Stream_Element_Offset;
                            From   : access Sock_Addr_Type := null);

   procedure Close_Socket (Socket : in out Socket_Type);

   --  Socket options (a minimal subset).  Receive_Timeout caps how long a
   --  Receive_Socket blocks; when it elapses with no data, Receive_Socket raises
   --  Socket_Error (as on desktop GNAT.Sockets).  A timeout of 0.0 means block
   --  indefinitely (the default).
   type Level_Type  is (Socket_Level);
   type Option_Name is (Receive_Timeout);
   subtype Timeval_Duration is Duration range 0.0 .. Duration'Last;
   type Option_Type (Name : Option_Name := Receive_Timeout) is record
      case Name is
         when Receive_Timeout =>
            Timeout : Timeval_Duration := 0.0;
      end case;
   end record;
   procedure Set_Socket_Option (Socket : Socket_Type;
                               Level   : Level_Type := Socket_Level;
                               Option  : Option_Type);

   --  A stream over a connected socket, for 'Read / 'Write / 'Input / 'Output.
   type Stream_Access is access all Ada.Streams.Root_Stream_Type'Class;
   function Stream (Socket : Socket_Type) return Stream_Access;

private
   type Inet_Addr_Type is record
      B : Net_Devices.IPv4_Address := (0, 0, 0, 0);
   end record;
   Any_Inet_Addr : constant Inet_Addr_Type := (B => (0, 0, 0, 0));

   --  A socket names a registered interface and one of its sockets (-1 = none).
   --  Pin is the interface it is pinned to, or -1 to route freely by destination.
   type Socket_Type is record
      Iface : Integer := -1;
      Index : Integer := -1;
      Pin   : Integer := -1;
   end record;
   No_Socket : constant Socket_Type := (Iface => -1, Index => -1, Pin => -1);
end GNAT.Sockets;
