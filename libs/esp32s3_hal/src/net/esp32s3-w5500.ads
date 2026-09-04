with Interfaces;
with ESP32S3.SPI;
with ESP32S3.GPIO;

--  WIZnet W5500 hardwired-TCP/IP Ethernet controller -- SPI transport + bring-up.
--
--  The W5500 is an SPI slave with an on-chip 10/100 PHY, MAC, and a hardwired
--  TCP/IP stack exposing eight independent hardware sockets.  This package is the
--  foundation layer: the SPI frame transport, hardware/software reset, the common
--  registers (identity / network config), and PHY link status.  The socket engine
--  and a GNAT.Sockets-shaped API are built ON this layer in child units.
--
--  SPI frame (Variable Length Data Mode, VDM):  every access is one frame of a
--  16-bit address, an 8-bit control byte (Block-Select<<3 | RWB<<2 | OM=00), then
--  N data bytes, with the chip select held low for the whole frame.  VDM keeps the
--  bus shareable; the offset auto-increments within a frame.  CS is driven here as
--  a plain GPIO (NOT routed to the SPI peripheral), exactly like ESP32S3.SD_SPI,
--  so it can be held across the three phases.  The W5500 runs in SPI mode 0.
--
--  Concurrency:  each frame takes the SPI host's Session for its own transfer and
--  releases it (the "lock the bus only as long as necessary" idiom shared with the
--  other SPI drivers), so every W5500 access is atomic against any other task or
--  device on that bus.  The socket layer adds PER-SOCKET ownership on top: the
--  eight sockets are independent, so different tasks drive different sockets, with
--  this transport serialising the shared bus underneath.
--
--  Profiles:  uses a controlled SPI Session and Ada.Real_Time delays => embedded
--  or full only.
--
--  This first layer is POLLING-based.  INTn (if wired) is configured as a pulled-up
--  input for a later ESP32S3.W5500.Interrupts child; it is not used here.

package ESP32S3.W5500 is

   type Byte is new Interfaces.Unsigned_8;
   type Byte_Array is array (Natural range <>) of Byte;

   --  A 6-byte MAC and a 4-byte IPv4 address, most-significant byte first (the
   --  order the W5500 registers use).
   subtype MAC_Address is Byte_Array (0 .. 5);
   subtype IPv4_Address is Byte_Array (0 .. 3);
   function IPv4 (A, B, C, D : Byte) return IPv4_Address
   is ((A, B, C, D));

   subtype Socket_Id is Natural range 0 .. 7;

   --  The 5-bit Block-Select (BSB) field of a frame's control byte.  The transport
   --  is exposed so the socket layer can reach a socket's register / TX / RX block.
   type Block is mod 2**5;
   Common_Regs : constant Block := 2#00000#;
   function Socket_Regs (S : Socket_Id) return Block
   is (Block (S * 4 + 1));
   function Socket_TX (S : Socket_Id) return Block
   is (Block (S * 4 + 2));
   function Socket_RX (S : Socket_Id) return Block
   is (Block (S * 4 + 3));

   type Device is limited private;

   --  Raised by an operation on a Device that was never Setup.
   Not_Initialized : exception;

   ---------------------------------------------------------------------------
   --  One-time wiring + SPI bring-up.  Sclk/Mosi/Miso route to the SPI host;
   --  Cs is driven as a GPIO (held low per frame).  Rst (active-low) and Int
   --  (active-low, pulled up) are optional.  Start at a conservative clock; the
   --  W5500 SPI tolerates up to 80 MHz once wiring is proven.
   ---------------------------------------------------------------------------
   procedure Setup
     (Dev                  : out Device;
      Sclk, Mosi, Miso, Cs : ESP32S3.GPIO.Pin_Id;
      Rst                  : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Int                  : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Host                 : ESP32S3.SPI.SPI_Host := ESP32S3.SPI.SPI2;
      Clock_Hz             : Positive := 10_000_000);

   ---------------------------------------------------------------------------
   --  Reset + identity
   ---------------------------------------------------------------------------

   --  Reset the chip: pulse RSTn low (>= 500 us) if wired, else a software reset
   --  via MR.RST (polled until it self-clears).  Settles, then Ok := Present.
   procedure Reset (Dev : in out Device; Ok : out Boolean);

   --  VERSIONR -- always 0x04 on a healthy W5500; a cheap presence/wiring check.
   function Version (Dev : Device) return Byte;
   function Present (Dev : Device) return Boolean;   --  Version = 0x04

   --  Program the source MAC and the static IPv4 identity (IP, subnet, gateway).
   procedure Configure
     (Dev : in out Device; MAC : MAC_Address; IP, Subnet, Gateway : IPv4_Address);

   function Get_MAC (Dev : Device) return MAC_Address;
   function Get_IP (Dev : Device) return IPv4_Address;

   ---------------------------------------------------------------------------
   --  PHY / link status (read from PHYCFGR)
   ---------------------------------------------------------------------------
   type Link_State is (Down, Up);
   type Phy_Speed is (Mbps_10, Mbps_100);
   type Phy_Duplex is (Half, Full);
   type Phy_Status is record
      Link   : Link_State := Down;
      Speed  : Phy_Speed := Mbps_10;
      Duplex : Phy_Duplex := Half;
   end record;

   function Link (Dev : Device) return Link_State;
   function Phy (Dev : Device) return Phy_Status;

   ---------------------------------------------------------------------------
   --  Low power (PHY power-down)
   --
   --  The W5500's power saving is at the Ethernet PHY.  In Power_Down the PHY is
   --  off -- the link drops and no frames move -- and that PHY (the 100BASE-TX
   --  line driver) is the bulk of the chip's current, so this is the meaningful
   --  low-power state.  The host interface, MAC, registers and the 32 KiB socket
   --  buffers stay powered and intact: configuration and any buffered data
   --  survive, only the wire goes quiet.
   --
   --  Set_Power (Normal) brings the PHY back with all-capable auto-negotiation;
   --  the link then re-negotiates, so give it a moment and poll Link before using
   --  the network.  Both directions apply the change by pulsing the PHY reset, as
   --  the datasheet requires.
   --
   --  This is a LINK-LAYER sleep, not a chip reset: the socket REGISTERS survive,
   --  but an open TCP connection does not survive the link dropping -- so
   --  re-establish connections after waking.
   --
   --  Power is entirely the APPLICATION's to manage.  After Setup/Reset the PHY is
   --  powered and running (the default), and the driver never changes that on its
   --  own: call Set_Power (Dev, Power_Down) when you know you will not use the wire
   --  for a while, and Set_Power (Dev, Normal) before you next need it (then wait
   --  for Link to come Up).  Note a Reset re-wakes the PHY, so re-apply Power_Down
   --  after any reset if you want it to stay down.
   ---------------------------------------------------------------------------
   type Power_Mode is (Normal, Power_Down);

   procedure Set_Power (Dev : in out Device; Mode : Power_Mode);
   function Power (Dev : Device) return Power_Mode;   --  read back from PHYCFGR

   ---------------------------------------------------------------------------
   --  Link mode
   --
   --  By default the PHY auto-negotiates (Auto).  You can pin it: to 10BASE-T for
   --  lower PHY current (the companion to Power_Down when you must stay reachable),
   --  or to a fixed speed/duplex when a stubborn switch will not negotiate.
   --  Applied by pulsing the PHY reset like Set_Power, so the link re-establishes
   --  -- wait for Link afterwards.  Set_Link_Mode (Auto) is the same as
   --  Set_Power (Normal).
   ---------------------------------------------------------------------------
   type Link_Mode is (Auto, M10_Half, M10_Full, M100_Half, M100_Full);
   procedure Set_Link_Mode (Dev : in out Device; Mode : Link_Mode);

   ---------------------------------------------------------------------------
   --  Mode-register options (each off by default after Reset).
   ---------------------------------------------------------------------------

   --  Wake-on-LAN: the chip raises its Magic_Packet interrupt on receiving a WoL
   --  magic packet addressed to it (the PHY must be up to hear it).  Route it to
   --  the INTn pin with Set_Common_Interrupts if you want it to wake the host.
   procedure Set_Wake_On_LAN (Dev : in out Device; On : Boolean);
   function  Magic_Packet_Pending (Dev : Device) return Boolean;
   procedure Clear_Magic_Packet (Dev : in out Device);

   --  Ping block: stop the chip auto-replying to ICMP echo (a quieter presence on
   --  the LAN; it still answers ARP, so it stays reachable).
   procedure Set_Ping_Block (Dev : in out Device; Blocked : Boolean);

   --  Force-ARP: send an ARP request on every SEND rather than trusting the ARP
   --  cache -- announces/refreshes the chip's MAC on switches that age entries.
   procedure Set_Force_ARP (Dev : in out Device; On : Boolean);

   ---------------------------------------------------------------------------
   --  Retransmission (governs TCP and ARP): the time per try and the number of
   --  tries before an operation gives up as Timed_Out.  Defaults are 200 ms x 8.
   --  Shorter/fewer => fail fast on a dead peer (a snappier Connect timeout);
   --  longer/more => tolerate a lossy link.  Timeout is quantised to 100 us.
   ---------------------------------------------------------------------------
   procedure Set_Retransmission
     (Dev : in out Device; Timeout : Duration; Retries : Natural);
   procedure Get_Retransmission
     (Dev : Device; Timeout : out Duration; Retries : out Natural);

   ---------------------------------------------------------------------------
   --  Diagnostics from the common interrupt register (IR).
   ---------------------------------------------------------------------------
   type Fault_Report is record
      IP_Conflict      : Boolean := False;   --  a duplicate of our IP is on the LAN
      Dest_Unreachable : Boolean := False;   --  a UDP send bounced (ICMP unreachable)
      Unreach_IP       : IPv4_Address := (others => 0);   --  the unreachable host ...
      Unreach_Port     : Interfaces.Unsigned_16 := 0;     --  ... and its port
   end record;

   --  Read (and by default clear) the pending faults.  Leaves the Magic_Packet
   --  bit alone -- read that with Magic_Packet_Pending.
   procedure Read_Faults
     (Dev : in out Device; Report : out Fault_Report; Clear : Boolean := True);

   --  Choose which common interrupts drive the INTn pin (all masked off by
   --  default).  Enabling Magic_Packet here is what makes Wake-on-LAN wake the host.
   procedure Set_Common_Interrupts
     (Dev              : in out Device;
      IP_Conflict      : Boolean := False;
      Dest_Unreachable : Boolean := False;
      Magic_Packet     : Boolean := False);

   ---------------------------------------------------------------------------
   --  Low-level transport -- one VDM frame per call, the SPI host serialised for
   --  its duration.  These are what the socket layer builds on; Addr is the 16-bit
   --  offset within the selected Block and auto-increments across the data.
   --  Scalars are big-endian on the wire (the W5500 register convention).
   ---------------------------------------------------------------------------
   procedure Write (Dev : Device; Blk : Block; Addr : Interfaces.Unsigned_16; Data : Byte_Array);
   procedure Read
     (Dev : Device; Blk : Block; Addr : Interfaces.Unsigned_16; Data : out Byte_Array);

   procedure Write_U8 (Dev : Device; Blk : Block; Addr : Interfaces.Unsigned_16; V : Byte);
   function Read_U8 (Dev : Device; Blk : Block; Addr : Interfaces.Unsigned_16) return Byte;
   procedure Write_U16
     (Dev : Device; Blk : Block; Addr : Interfaces.Unsigned_16; V : Interfaces.Unsigned_16);
   function Read_U16
     (Dev : Device; Blk : Block; Addr : Interfaces.Unsigned_16) return Interfaces.Unsigned_16;

private
   type Device is record
      Host       : ESP32S3.SPI.SPI_Host := ESP32S3.SPI.SPI2;
      Clock_Hz   : Positive := 10_000_000;   --  this device's clock
      Cs         : ESP32S3.GPIO.Pin_Id := 0;
      Rst        : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Int        : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Configured : Boolean := False;
   end record;
end ESP32S3.W5500;
