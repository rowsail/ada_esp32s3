with Interfaces;

--  W5500 socket engine -- TCP and UDP over the chip's eight hardware sockets,
--  built on the ESP32S3.W5500 transport.  This layer is shaped toward the
--  GNAT.Sockets subset that will sit above it (a self-contained Socket handle,
--  Connect/Listen/Send/Receive, a Status error model).
--
--  Concurrency -- PER-SOCKET ownership: bind one Socket handle to one of the eight
--  hardware sockets and drive it from one task.  The transport underneath
--  serialises the shared SPI bus, so other tasks can drive other sockets
--  concurrently.  Two tasks must not share one Socket handle.
--
--  This pass is POLLING-based: the blocking operations (Connect, and Send's
--  wait-for-SEND_OK) spin on the chip status with short delays.  An
--  ESP32S3.W5500.Interrupts child will later replace those spins with a
--  Suspension_Object wait on INTn (the wait is funnelled through one private hook
--  so that change is localised).  Uses Ada.Real_Time => embedded / full only.

package ESP32S3.W5500.Sockets is

   subtype Port_Number is Interfaces.Unsigned_16;

   --  A pointer to the (library-level, aliased) W5500 the socket lives on, so a
   --  Socket handle is self-contained.  Declare the device as
   --  "Dev : aliased ESP32S3.W5500.Device;" and pass Dev'Access.
   type Device_Access is access all Device;

   --  A handle to one of the chip's eight hardware sockets.
   type Socket is limited private;

   --  Outcome of an operation (shaped toward GNAT.Sockets' error model).
   type Status is
     (OK,
      Not_Open,         --  the handle is not open
      Closed_By_Peer,   --  TCP peer sent FIN / the connection is closed
      Timed_Out,        --  ARP/TCP timeout (Sn_IR TIMEOUT)
      Refused,          --  connect failed (RST / no listener)
      No_Space,         --  TX buffer can't hold the data right now
      Error);

   --  The chip's socket status (Sn_SR), for polling a TCP connection's progress.
   type Socket_State is
     (Closed, Init, Listening, Established, Close_Wait, Udp, Macraw, Other);

   --  Interrupt integration (optional).  By default the blocking operations
   --  POLL.  An ESP32S3.W5500.Interrupts child can register a waiter here so the
   --  waits instead SLEEP on INTn; pass null to revert to polling.  If you never
   --  register one, everything stays polled -- no interrupt code is even linked.
   type Event_Waiter is access procedure (Index : Socket_Id);
   procedure Set_Event_Waiter (W : Event_Waiter);

   --  Is the handle currently open (bound to a hardware socket)?  Used by the
   --  contracts below and by callers before a data-transfer operation.
   function Is_Open (S : Socket) return Boolean;

   ---------------------------------------------------------------------------
   --  Open / close.  Index selects one of the eight hardware sockets.
   ---------------------------------------------------------------------------

   --  Open a TCP socket bound to Local_Port (=> SOCK_INIT); then Listen (server)
   --  or Connect (client).  No_Delay disables the chip's delayed-ACK (Nagle-ish
   --  batching), for latency-sensitive request/response traffic (e.g. Modbus).
   procedure Open_TCP
     (Dev        : Device_Access;
      S          : in out Socket;
      Index      : Socket_Id;
      Local_Port : Port_Number;
      Result     : out Status;
      No_Delay   : Boolean := False)
   with Pre  => Dev /= null,
        Post => (if Result = OK then Is_Open (S));

   --  Open a connectionless UDP socket bound to Local_Port (=> SOCK_UDP).
   procedure Open_UDP
     (Dev        : Device_Access;
      S          : in out Socket;
      Index      : Socket_Id;
      Local_Port : Port_Number;
      Result     : out Status)
   with Pre  => Dev /= null,
        Post => (if Result = OK then Is_Open (S));

   --  Open a UDP socket joined to a multicast Group (the chip derives the
   --  multicast MAC and filters to the group).  Receive_From then delivers
   --  datagrams sent to Group:Port; Send goes to the group.  Group must be a
   --  224.0.0.0/4 address.
   procedure Open_UDP_Multicast
     (Dev        : Device_Access;
      S          : in out Socket;
      Index      : Socket_Id;
      Group      : IPv4_Address;
      Port       : Port_Number;
      Result     : out Status)
   with Pre  => Dev /= null,
        Post => (if Result = OK then Is_Open (S));

   --  Close immediately (no TCP disconnect handshake).
   procedure Close (S : in out Socket)
   with Post => not Is_Open (S);

   ---------------------------------------------------------------------------
   --  Per-socket options.  Set on an open socket; buffer sizes and MSS are best
   --  set right after Open, before traffic.
   ---------------------------------------------------------------------------

   --  TCP keep-alive probe period (0 => off).  Open_TCP defaults it to 60 s;
   --  override here.  Quantised to 5 s.
   procedure Set_Keepalive (S : Socket; Period : Duration);

   --  IP time-to-live and type-of-service (DSCP/ToS) stamped on outgoing packets.
   procedure Set_TTL (S : Socket; TTL : Natural);
   procedure Set_Type_Of_Service (S : Socket; TOS : Natural);

   --  TCP maximum segment size to advertise (bytes).
   procedure Set_Max_Segment_Size (S : Socket; MSS : Natural);

   --  Re-allocate this socket's RX / TX buffers out of the chip's 16 KB-per-
   --  direction pool.  The eight sockets default to 2 KB each; give a bulk socket
   --  more and reclaim from unused ones.  The per-direction totals across all
   --  sockets must not exceed 16 KB.  Set immediately after Open.
   type Buffer_KB is (KB_0, KB_1, KB_2, KB_4, KB_8, KB_16);
   procedure Set_Buffer_Sizes (S : Socket; RX, TX : Buffer_KB);

   ---------------------------------------------------------------------------
   --  TCP connection setup
   ---------------------------------------------------------------------------

   --  Server: start listening for an incoming connection (=> SOCK_LISTEN).  Poll
   --  State / Is_Established until a client connects.
   procedure Listen (S : in out Socket; Result : out Status);

   --  Client: connect to Host:Port.  Blocks (polls) until established or it fails
   --  (Timed_Out / Refused), up to Timeout.
   procedure Connect
     (S       : in out Socket;
      Host    : IPv4_Address;
      Port    : Port_Number;
      Result  : out Status;
      Timeout : Duration := 10.0);

   function State (S : Socket) return Socket_State;
   function Is_Established (S : Socket) return Boolean;

   --  Server: block until a client connects (=> Established) or the socket
   --  closes.  Sleeps on INTn if an Event_Waiter is registered, else polls.
   procedure Wait_Connected (S : in out Socket; Result : out Status);

   --  TCP graceful disconnect (DISCON: FIN + handshake), then the handle is closed.
   procedure Disconnect (S : in out Socket)
   with Post => not Is_Open (S);

   ---------------------------------------------------------------------------
   --  TCP data transfer (non-blocking on receive; send waits for SEND_OK)
   ---------------------------------------------------------------------------

   --  Bytes waiting in the RX buffer (Sn_RX_RSR).
   function Available (S : Socket) return Natural;

   --  Block until data is available to Receive, or the peer closes.  Sleeps on
   --  INTn if an Event_Waiter is registered, else polls.  Result = OK when data
   --  is ready, Closed_By_Peer when the connection has closed, Timed_Out if no
   --  data arrived within the receive timeout (see Set_Receive_Timeout).
   procedure Wait_Data (S : in out Socket; Result : out Status);

   --  Cap how long Wait_Data blocks before returning Timed_Out.  Zero (the
   --  default) means block indefinitely.  Backs the GNAT.Sockets facade's
   --  Receive_Timeout socket option.
   procedure Set_Receive_Timeout (S : in out Socket; To : Duration);

   --  Send up to Data'Length bytes; Sent = how many were transmitted (may be less
   --  than Data'Length if the TX buffer was partly full).
   procedure Send (S : in out Socket; Data : Byte_Array; Sent : out Natural; Result : out Status)
   with Post => Sent <= Data'Length;

   --  Receive up to Into'Length bytes; Count = how many were read (0 if none
   --  waiting).  Result = Closed_By_Peer once the peer has half-closed and the
   --  buffer is drained.
   procedure Receive
     (S : in out Socket; Into : out Byte_Array; Count : out Natural; Result : out Status)
   with Post => Count <= Into'Length;

   ---------------------------------------------------------------------------
   --  UDP datagrams
   ---------------------------------------------------------------------------

   procedure Send_To
     (S      : in out Socket;
      Host   : IPv4_Address;
      Port   : Port_Number;
      Data   : Byte_Array;
      Result : out Status);

   --  Receive one datagram.  From / From_Port identify the sender; Count = payload
   --  bytes copied (0 if none waiting; a datagram longer than Into is truncated).
   procedure Receive_From
     (S         : in out Socket;
      From      : out IPv4_Address;
      From_Port : out Port_Number;
      Into      : out Byte_Array;
      Count     : out Natural;
      Result    : out Status)
   with Post => Count <= Into'Length;

   ---------------------------------------------------------------------------
   --  MACRAW -- raw layer-2 Ethernet, bypassing the offloaded stack.  This is
   --  the escape hatch for protocols the chip does not do natively (or a custom
   --  stack): the host sees whole Ethernet frames.  It is EXCLUSIVE to hardware
   --  socket 0 and puts the chip in raw mode, so use it alone, not alongside the
   --  TCP/UDP sockets above.
   ---------------------------------------------------------------------------

   --  Open socket 0 in MACRAW mode (Index is fixed at 0).
   procedure Open_MACRAW
     (Dev : Device_Access; S : in out Socket; Result : out Status)
   with Pre  => Dev /= null,
        Post => (if Result = OK then Is_Open (S));

   --  Transmit one complete Ethernet frame (dest MAC, src MAC, ethertype, payload
   --  -- no CRC; the chip appends it).
   procedure Send_Raw
     (S : in out Socket; Frame : Byte_Array; Sent : out Natural; Result : out Status)
   with Post => Sent <= Frame'Length;

   --  Receive one Ethernet frame; Count = bytes copied (0 if none waiting; a frame
   --  longer than Into is truncated but fully consumed).
   procedure Receive_Raw
     (S : in out Socket; Into : out Byte_Array; Count : out Natural; Result : out Status)
   with Post => Count <= Into'Length;

private
   type Protocol is (None, TCP_Proto, UDP_Proto, Raw_Proto);
   type Socket is limited record
      Dev          : Device_Access := null;
      Index        : Socket_Id := 0;
      Proto        : Protocol := None;
      Is_Open      : Boolean := False;
      Recv_Timeout : Duration := 0.0;   --  0 => Wait_Data blocks forever
   end record;

   function Is_Open (S : Socket) return Boolean is (S.Is_Open);
end ESP32S3.W5500.Sockets;
