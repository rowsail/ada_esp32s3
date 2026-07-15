--  A minimal pure-Ada IPv4 / ARP / UDP stack riding on the raw 802.3 frames the
--  Wi-Fi driver exposes (ESP32S3.WiFi.Send_Frame / Set_Frame_Handler).  It is
--  the substrate under the DHCP client and ESP32S3.WiFi.Net_Device (the
--  GNAT.Sockets NIC).
--
--  Concurrency: received frames are enqueued by the Wi-Fi task (the frame sink
--  only copies into a protected ring); EVERYTHING ELSE -- Poll, ARP, the UDP
--  sockets, Send_To/Receive_From -- runs on the single owning task (typically
--  the environment task).  Do not drive the sockets from two tasks at once.
with Interfaces;

package ESP32S3.WiFi.IP is

   subtype Octet is Interfaces.Unsigned_8;
   subtype U16   is Interfaces.Unsigned_16;

   type IPv4       is array (0 .. 3) of Octet;
   type MAC        is array (0 .. 5) of Octet;
   type Byte_Array is array (Natural range <>) of Octet;

   Any_IP       : constant IPv4 := (0, 0, 0, 0);
   Broadcast_IP : constant IPv4 := (255, 255, 255, 255);

   --  Attach the stack to the Wi-Fi driver's frame path (registers the RX sink
   --  and reads our station MAC).  Call once, after ESP32S3.WiFi.Initialize.
   procedure Start;

   --  Interface address.  DHCP (or a static setup) fills these in; until then
   --  the local address is 0.0.0.0 and Configured is False.
   procedure Configure (Addr, Mask, Gateway, DNS : IPv4);
   function Local_Address return IPv4;
   function Subnet_Mask   return IPv4;
   function Gateway       return IPv4;
   function DNS_Server    return IPv4;
   function Own_MAC       return MAC;
   function Configured    return Boolean;

   --  Process any queued received frames (ARP, UDP demux).  Cheap when the ring
   --  is empty; call it from the owning task's wait loops.
   procedure Poll;

   --  Diagnostics (frames the sink has enqueued / we have transmitted).
   function Rx_Frames return Natural;
   function Tx_Frames return Natural;
   function Drop_Frames return Natural;   --  frames dropped by a Dispatch check

   --  --- UDP sockets, named by index 0 .. Max_Sockets - 1 ------------------
   Max_Sockets : constant := 6;
   type Socket_Id is range 0 .. Max_Sockets - 1;

   --  Bind a socket to a local port (0 => pick an ephemeral port).
   procedure Open  (Id : Socket_Id; Local_Port : U16; Ok : out Boolean);
   procedure Close (Id : Socket_Id);
   function  Bound_Port (Id : Socket_Id) return U16;   --  0 if closed

   --  Send one datagram.  Dest = Broadcast_IP goes to the broadcast MAC;
   --  otherwise the next hop is Dest if on-subnet, else the gateway -- its MAC
   --  is resolved by ARP (this call blocks briefly for the reply).
   procedure Send_To (Id : Socket_Id; Dest : IPv4; Dest_Port : U16;
                      Data : Byte_Array; Ok : out Boolean);

   --  Non-blocking receive: Count = 0 if nothing is queued (call Poll first).
   procedure Receive_From (Id : Socket_Id; From : out IPv4; From_Port : out U16;
                           Into : out Byte_Array; Count : out Natural);

   --  --- TCP client sockets (same index space as the UDP sockets) -----------
   --
   --  Reactive API: the calls below never block.  They post segments and read
   --  connection state; the owning task drives progress by calling Poll in a
   --  wait loop (Poll processes received segments and runs the retransmit
   --  timers).  ESP32S3.WiFi.Net_Device wraps these in the blocking, timeout-
   --  bounded operations the GNAT.Sockets facade expects.

   --  Open a TCP socket bound to Local_Port (0 => pick an ephemeral port).
   procedure TCP_Open (Id : Socket_Id; Local_Port : U16; Ok : out Boolean);
   function TCP_Is_Open (Id : Socket_Id) return Boolean;   --  Id is a TCP socket

   --  Begin an active open to Dest:Dest_Port (sends the SYN).  Ok is False only
   --  if the SYN could not be sent (no route / ARP failure).  Poll, then read
   --  TCP_Connected / TCP_Failed for the outcome.
   procedure TCP_Connect (Id : Socket_Id; Dest : IPv4; Dest_Port : U16;
                          Ok : out Boolean);
   function TCP_Connected (Id : Socket_Id) return Boolean;
   function TCP_Failed (Id : Socket_Id) return Boolean;   --  RST / aborted

   --  Hand up to Data'Length bytes to the connection.  Sent is how many it
   --  took; 0 while a previous segment is still unacknowledged (stop and wait).
   procedure TCP_Send (Id : Socket_Id; Data : Byte_Array; Sent : out Natural);
   function TCP_Send_Idle (Id : Socket_Id) return Boolean;  --  nothing unacked

   --  Received stream bytes waiting for the app, and a non-blocking read.
   function TCP_Available (Id : Socket_Id) return Natural;
   procedure TCP_Receive (Id : Socket_Id; Into : out Byte_Array;
                          Count : out Natural);
   function TCP_Peer_Closed (Id : Socket_Id) return Boolean;   --  FIN received
   procedure TCP_Peer (Id : Socket_Id; Addr : out IPv4; Port : out U16);

   --  Active close: send a FIN once all queued data is acknowledged.
   procedure TCP_Close (Id : Socket_Id);

end ESP32S3.WiFi.IP;
