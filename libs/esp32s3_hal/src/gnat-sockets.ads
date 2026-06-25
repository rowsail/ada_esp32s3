with Ada.Streams;
with ESP32S3.W5500;
with ESP32S3.W5500.Sockets;

--  A bare-metal subset of GNAT.Sockets, backed by the WIZnet W5500's hardwired
--  TCP/IP stack (eight hardware sockets, IPv4).  Networking code written against
--  the standard GNAT.Sockets API -- Create_Socket / Bind / Listen / Accept /
--  Connect / Send / Receive / Close, the Stream over a socket -- compiles and runs
--  here unchanged, within the subset below.
--
--  Differences from desktop GNAT.Sockets, by necessity:
--    * IPv4 only (Family_Inet); the W5500 has no IPv6.
--    * One bare-metal init: Initialize (Device) binds the facade to a W5500
--      (desktop GNAT.Sockets' Initialize takes no argument -- here we must say
--      which chip).  Call it once before any socket op.
--    * Eight sockets total (the chip's hardware sockets); Create_Socket past that
--      raises Socket_Error.
--    * Accept_Socket returns the listening socket itself as the connected socket
--      (the W5500 listener *becomes* the connection); to accept again, re-Listen.
--
--  Requires the embedded or full profile (the socket engine uses controlled
--  handles + Ada.Real_Time).
package GNAT.Sockets is

   --  Bare-metal entry point: bind this facade to a W5500 (declared as a
   --  library-level "Dev : aliased ESP32S3.W5500.Device" and already Setup +
   --  Reset + Configured).  Call once, before any socket operation.
   procedure Initialize (Device : ESP32S3.W5500.Sockets.Device_Access);

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

   --  Set the local port for a server (TCP) or the bound port (UDP).
   procedure Bind_Socket (Socket : in out Socket_Type; Address : Sock_Addr_Type);

   procedure Listen_Socket (Socket : in out Socket_Type; Length : Natural := 15);

   --  Block until a client connects; Socket is the connection, Address the peer.
   procedure Accept_Socket (Server  : Socket_Type;
                            Socket  : out Socket_Type;
                            Address : out Sock_Addr_Type);

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
      B : ESP32S3.W5500.IPv4_Address := (0, 0, 0, 0);
   end record;
   Any_Inet_Addr : constant Inet_Addr_Type := (B => (0, 0, 0, 0));

   --  A socket is just an index into the chip's eight hardware sockets (-1 = none).
   type Socket_Type is record
      Index : Integer := -1;
   end record;
   No_Socket : constant Socket_Type := (Index => -1);
end GNAT.Sockets;
