with System;
with Ada.Unchecked_Conversion;
with Interfaces;    use Interfaces;
with Ada.Real_Time; use Ada.Real_Time;

package body ESP32S3.W5500 is

   use type ESP32S3.GPIO.Pad_Number;   --  make "/=" visible for the No_Pin checks

   --  Common register offsets (BSB = Common_Regs).
   MR       : constant Unsigned_16 := 16#0000#;   --  Mode (bit7 = S/W reset)
   GAR      : constant Unsigned_16 := 16#0001#;   --  Gateway IP        (4)
   SUBR     : constant Unsigned_16 := 16#0005#;   --  Subnet mask       (4)
   SHAR     : constant Unsigned_16 := 16#0009#;   --  Source MAC        (6)
   SIPR     : constant Unsigned_16 := 16#000F#;   --  Source IP         (4)
   PHYCFGR  : constant Unsigned_16 := 16#002E#;   --  PHY config/status
   VERSIONR : constant Unsigned_16 := 16#0039#;   --  Chip version (= 0x04)

   MR_RST    : constant Byte := 16#80#;          --  MR software-reset bit
   W5500_VER : constant Byte := 16#04#;          --  VERSIONR constant value

   --  PHYCFGR status bits.
   PHY_LNK : constant Byte := 16#01#;             --  1 = link up
   PHY_SPD : constant Byte := 16#02#;             --  1 = 100 Mbps
   PHY_DPX : constant Byte := 16#04#;             --  1 = full duplex

   --  PHYCFGR config bits.  RST (bit 7) is active-low: pulsing it 1->0->1 applies
   --  an OPMD/OPMDC change.  OPMD (bit 6) = 1 means the PHY mode is taken from the
   --  OPMDC field (bits 5..3) rather than the hardware pins.  OPMDC 110 = power
   --  down; 111 = all-capable with auto-negotiation (the normal running mode).
   PHY_RST   : constant Byte := 16#80#;           --  bit 7: 0 = PHY in reset
   PHY_OPMD  : constant Byte := 16#40#;           --  bit 6: configure from OPMDC
   PHY_OPMDC : constant Byte := 16#38#;           --  bits 5..3: mode field mask
   PHY_PDOWN : constant Byte := 16#30#;           --  OPMDC = 110 : power down
   PHY_ALLA  : constant Byte := 16#38#;           --  OPMDC = 111 : all-capable ANeg

   --  One SPI frame's scratch (3-byte header + up to Chunk_Size data), one pair
   --  per host so the held Session serialises a host's use of its buffers.  As a
   --  library-level object it lands in .bss = internal SRAM, which GDMA can reach
   --  (a long transfer is split into Chunk_Size-byte frames at incrementing Addr).
   Chunk_Size : constant := 128;
   type Frame is array (0 .. 2 + Chunk_Size) of Byte;
   Scratch_Tx : array (ESP32S3.SPI.SPI_Host) of Frame := (others => (others => 0));
   Scratch_Rx : array (ESP32S3.SPI.SPI_Host) of Frame := (others => (others => 0));

   --  Control byte as its documented bit fields (BSB[3..7], RWB[2], OM[0..1]),
   --  so the layout is named and compiler-placed rather than hand-shifted.  We
   --  only ever use variable-length data mode, so OM = 00.  (Verified bit-for-bit
   --  against the previous "Blk*8 + 4" arithmetic in test/repclause_host.)
   type OM_Mode is mod 2**2;
   type Control_Byte is record
      OM  : OM_Mode;   --  operation mode (0 = VDM)
      RWB : Boolean;   --  read = False, write = True
      BSB : Block;     --  block-select (5 bits)
   end record;
   for Control_Byte use
     record
       OM at 0 range 0 .. 1;
       RWB at 0 range 2 .. 2;
       BSB at 0 range 3 .. 7;
     end record;
   for Control_Byte'Size use 8;
   function To_Byte is new Ada.Unchecked_Conversion (Control_Byte, Byte);

   function Control (Blk : Block; Write_Access : Boolean) return Byte
   is (To_Byte ((OM => 0, RWB => Write_Access, BSB => Blk)));

   ---------------------------------------------------------------------------
   --  Transport
   ---------------------------------------------------------------------------

   procedure Write (Dev : Device; Blk : Block; Addr : Interfaces.Unsigned_16; Data : Byte_Array) is
      Session   : ESP32S3.SPI.Session;
      Host      : constant ESP32S3.SPI.SPI_Host := Dev.Host;
      Ctrl_Byte : constant Byte := Control (Blk, Write_Access => True);
      Offset    : Natural := Data'First;
      Cur_Addr  : Unsigned_16 := Addr;
   begin
      if not Dev.Configured then
         raise Not_Initialized;
      end if;
      ESP32S3.SPI.Acquire (Session, Host, Clock_Hz => Dev.Clock_Hz);
      while Offset <= Data'Last loop
         declare
            Chunk_Len : constant Natural := Natural'Min (Chunk_Size, Data'Last - Offset + 1);
         begin
            Scratch_Tx (Host) (0) := Byte (Shift_Right (Cur_Addr, 8));
            Scratch_Tx (Host) (1) := Byte (Cur_Addr and 16#FF#);
            Scratch_Tx (Host) (2) := Ctrl_Byte;
            for I in 0 .. Chunk_Len - 1 loop
               Scratch_Tx (Host) (3 + I) := Data (Offset + I);
            end loop;
            ESP32S3.GPIO.Clear (Dev.Cs);                       --  assert CS (low)
            ESP32S3.SPI.Transfer
              (Session, Scratch_Tx (Host)'Address, Scratch_Rx (Host)'Address, 3 + Chunk_Len);
            ESP32S3.GPIO.Set (Dev.Cs);                         --  deassert CS
            Offset := Offset + Chunk_Len;
            Cur_Addr := Cur_Addr + Unsigned_16 (Chunk_Len);
         end;
      end loop;
      ESP32S3.SPI.Release (Session);
   end Write;

   procedure Read (Dev : Device; Blk : Block; Addr : Interfaces.Unsigned_16; Data : out Byte_Array)
   is
      Session   : ESP32S3.SPI.Session;
      Host      : constant ESP32S3.SPI.SPI_Host := Dev.Host;
      Ctrl_Byte : constant Byte := Control (Blk, Write_Access => False);
      Offset    : Natural := Data'First;
      Cur_Addr  : Unsigned_16 := Addr;
   begin
      if not Dev.Configured then
         raise Not_Initialized;
      end if;
      ESP32S3.SPI.Acquire (Session, Host, Clock_Hz => Dev.Clock_Hz);
      while Offset <= Data'Last loop
         declare
            Chunk_Len : constant Natural := Natural'Min (Chunk_Size, Data'Last - Offset + 1);
         begin
            Scratch_Tx (Host) (0) := Byte (Shift_Right (Cur_Addr, 8));
            Scratch_Tx (Host) (1) := Byte (Cur_Addr and 16#FF#);
            Scratch_Tx (Host) (2) := Ctrl_Byte;                --  data phase = don't care
            ESP32S3.GPIO.Clear (Dev.Cs);
            ESP32S3.SPI.Transfer
              (Session, Scratch_Tx (Host)'Address, Scratch_Rx (Host)'Address, 3 + Chunk_Len);
            ESP32S3.GPIO.Set (Dev.Cs);
            for I in 0 .. Chunk_Len - 1 loop
               --  skip the 3 header echoes
               Data (Offset + I) := Scratch_Rx (Host) (3 + I);
            end loop;
            Offset := Offset + Chunk_Len;
            Cur_Addr := Cur_Addr + Unsigned_16 (Chunk_Len);
         end;
      end loop;
      ESP32S3.SPI.Release (Session);
   end Read;

   procedure Write_U8 (Dev : Device; Blk : Block; Addr : Interfaces.Unsigned_16; V : Byte) is
   begin
      Write (Dev, Blk, Addr, (0 => V));
   end Write_U8;

   function Read_U8 (Dev : Device; Blk : Block; Addr : Interfaces.Unsigned_16) return Byte is
      Data : Byte_Array (0 .. 0);
   begin
      Read (Dev, Blk, Addr, Data);
      return Data (0);
   end Read_U8;

   procedure Write_U16
     (Dev : Device; Blk : Block; Addr : Interfaces.Unsigned_16; V : Interfaces.Unsigned_16) is
   begin
      Write (Dev, Blk, Addr, (Byte (Shift_Right (V, 8)), Byte (V and 16#FF#)));
   end Write_U16;

   function Read_U16
     (Dev : Device; Blk : Block; Addr : Interfaces.Unsigned_16) return Interfaces.Unsigned_16
   is
      Data : Byte_Array (0 .. 1);
   begin
      Read (Dev, Blk, Addr, Data);
      return Shift_Left (Unsigned_16 (Data (0)), 8) or Unsigned_16 (Data (1));
   end Read_U16;

   ---------------------------------------------------------------------------
   --  Setup / reset / identity
   ---------------------------------------------------------------------------

   procedure Setup
     (Dev                  : out Device;
      Sclk, Mosi, Miso, Cs : ESP32S3.GPIO.Pin_Id;
      Rst                  : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Int                  : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Host                 : ESP32S3.SPI.SPI_Host := ESP32S3.SPI.SPI2;
      Clock_Hz             : Positive := 10_000_000) is
   begin
      Dev.Host := Host;
      Dev.Clock_Hz := Clock_Hz;
      Dev.Cs := Cs;
      Dev.Rst := Rst;
      Dev.Int := Int;

      --  Route the shared bus pins; CS is driven here as a GPIO (not the
      --  peripheral CS0).  Mode 0 / this device's clock are applied at Acquire.
      ESP32S3.SPI.Setup (Host);
      ESP32S3.SPI.Configure_Pins (Host, Sclk => Sclk, Mosi => Mosi, Miso => Miso);

      ESP32S3.GPIO.Configure (Cs, Mode => ESP32S3.GPIO.Output, Pull => ESP32S3.GPIO.Pull_Up);
      ESP32S3.GPIO.Set (Cs);                               --  idle high (deselect)

      if Rst /= ESP32S3.GPIO.No_Pin then
         ESP32S3.GPIO.Configure
           (ESP32S3.GPIO.Pin_Id (Rst), Mode => ESP32S3.GPIO.Output, Pull => ESP32S3.GPIO.Pull_Up);
         ESP32S3.GPIO.Set (ESP32S3.GPIO.Pin_Id (Rst));     --  RSTn high = not reset

      end if;

      if Int /= ESP32S3.GPIO.No_Pin then
         --  for the future ISR child
         ESP32S3.GPIO.Configure
           (ESP32S3.GPIO.Pin_Id (Int), Mode => ESP32S3.GPIO.Input, Pull => ESP32S3.GPIO.Pull_Up);
      end if;

      Dev.Configured := True;
   end Setup;

   procedure Reset (Dev : in out Device; Ok : out Boolean) is
   begin
      if Dev.Rst /= ESP32S3.GPIO.No_Pin then
         ESP32S3.GPIO.Clear (ESP32S3.GPIO.Pin_Id (Dev.Rst));  --  RSTn low = reset
         delay until Clock + Microseconds (600);              --  hold >= 500 us
         ESP32S3.GPIO.Set (ESP32S3.GPIO.Pin_Id (Dev.Rst));
         delay until Clock + Milliseconds (2);                --  PLL lock / settle

      else
         Write_U8 (Dev, Common_Regs, MR, MR_RST);             --  software reset
         for Tries in 1 .. 100 loop
            --  self-clears when done
            exit when (Read_U8 (Dev, Common_Regs, MR) and MR_RST) = 0;
            delay until Clock + Microseconds (200);
         end loop;
      end if;
      Ok := Present (Dev);
   end Reset;

   function Version (Dev : Device) return Byte
   is (Read_U8 (Dev, Common_Regs, VERSIONR));

   function Present (Dev : Device) return Boolean
   is (Version (Dev) = W5500_VER);

   procedure Configure (Dev : in out Device; MAC : MAC_Address; IP, Subnet, Gateway : IPv4_Address)
   is
   begin
      Write (Dev, Common_Regs, GAR, Gateway);
      Write (Dev, Common_Regs, SUBR, Subnet);
      Write (Dev, Common_Regs, SHAR, MAC);
      Write (Dev, Common_Regs, SIPR, IP);
   end Configure;

   function Get_MAC (Dev : Device) return MAC_Address is
      Mac : MAC_Address;
   begin
      Read (Dev, Common_Regs, SHAR, Mac);
      return Mac;
   end Get_MAC;

   function Get_IP (Dev : Device) return IPv4_Address is
      IP : IPv4_Address;
   begin
      Read (Dev, Common_Regs, SIPR, IP);
      return IP;
   end Get_IP;

   ---------------------------------------------------------------------------
   --  PHY / link
   ---------------------------------------------------------------------------

   function Phy (Dev : Device) return Phy_Status is
      Regs : constant Byte := Read_U8 (Dev, Common_Regs, PHYCFGR);   --  PHYCFGR value
   begin
      return
        (Link   => (if (Regs and PHY_LNK) /= 0 then Up else Down),
         Speed  => (if (Regs and PHY_SPD) /= 0 then Mbps_100 else Mbps_10),
         Duplex => (if (Regs and PHY_DPX) /= 0 then Full else Half));
   end Phy;

   function Link (Dev : Device) return Link_State
   is (Phy (Dev).Link);

   ---------------------------------------------------------------------------
   --  Low power (PHY power-down)
   ---------------------------------------------------------------------------

   procedure Set_Power (Dev : in out Device; Mode : Power_Mode) is
      --  OPMD=1 so the PHY takes its mode from OPMDC; 110 = power down, 111 = the
      --  normal all-capable auto-negotiating mode.
      Cfg : constant Byte :=
        PHY_OPMD or (if Mode = Power_Down then PHY_PDOWN else PHY_ALLA);
   begin
      --  Latch the mode (RST high = out of reset), then pulse RST low->high so the
      --  PHY re-initialises into it, per the datasheet.
      Write_U8 (Dev, Common_Regs, PHYCFGR, Cfg or PHY_RST);
      Write_U8 (Dev, Common_Regs, PHYCFGR, Cfg);              --  RST=0: assert reset
      delay until Clock + Microseconds (600);                 --  hold the reset
      Write_U8 (Dev, Common_Regs, PHYCFGR, Cfg or PHY_RST);   --  RST=1: apply
      delay until Clock + Milliseconds (2);                   --  let the PHY settle
   end Set_Power;

   function Power (Dev : Device) return Power_Mode is
      Regs : constant Byte := Read_U8 (Dev, Common_Regs, PHYCFGR);
   begin
      return (if (Regs and PHY_OPMDC) = PHY_PDOWN then Power_Down else Normal);
   end Power;

end ESP32S3.W5500;
