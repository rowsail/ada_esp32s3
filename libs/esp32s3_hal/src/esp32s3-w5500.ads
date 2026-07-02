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
     (Dev                 : in out Device;
      MAC                 : MAC_Address;
      IP, Subnet, Gateway : IPv4_Address);

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
   --  Low-level transport -- one VDM frame per call, the SPI host serialised for
   --  its duration.  These are what the socket layer builds on; Addr is the 16-bit
   --  offset within the selected Block and auto-increments across the data.
   --  Scalars are big-endian on the wire (the W5500 register convention).
   ---------------------------------------------------------------------------
   procedure Write
     (Dev  : Device;
      Blk  : Block;
      Addr : Interfaces.Unsigned_16;
      Data : Byte_Array);
   procedure Read
     (Dev  : Device;
      Blk  : Block;
      Addr : Interfaces.Unsigned_16;
      Data : out Byte_Array);

   procedure Write_U8
     (Dev : Device; Blk : Block; Addr : Interfaces.Unsigned_16; V : Byte);
   function Read_U8
     (Dev : Device; Blk : Block; Addr : Interfaces.Unsigned_16) return Byte;
   procedure Write_U16
     (Dev  : Device;
      Blk  : Block;
      Addr : Interfaces.Unsigned_16;
      V    : Interfaces.Unsigned_16);
   function Read_U16
     (Dev : Device; Blk : Block; Addr : Interfaces.Unsigned_16)
      return Interfaces.Unsigned_16;

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
