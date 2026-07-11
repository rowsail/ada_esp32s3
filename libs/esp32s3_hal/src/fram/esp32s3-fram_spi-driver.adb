with Interfaces; use Interfaces;
with ESP32S3.GDMA;

package body ESP32S3.FRAM_SPI.Driver is

   package SPI renames ESP32S3.SPI;
   subtype DMA_Buffer is ESP32S3.GDMA.DMA_Buffer;

   --  Standard SPI-memory opcodes.
   Cmd_WREN  : constant Unsigned_8 := 16#06#;   --  write enable (before each WRITE)
   Cmd_Write : constant Unsigned_8 := 16#02#;
   Cmd_Read  : constant Unsigned_8 := 16#03#;
   Cmd_RDID  : constant Unsigned_8 := 16#9F#;   --  read device ID (JEDEC style)

   --  Largest data run per SPI transfer; the header is opcode + up to 3 address
   --  bytes.  Everything moves through DMA-reachable internal-SRAM scratch (a
   --  caller buffer may be on the stack or in PSRAM, which GDMA cannot reach).
   Chunk_Max  : constant := 256;
   Header_Max : constant := 4;
   Scratch_Length : constant :=
     ((Chunk_Max + ESP32S3.GDMA.DMA_Alignment - 1)
      / ESP32S3.GDMA.DMA_Alignment) * ESP32S3.GDMA.DMA_Alignment;

   --  Per-host scratch so two FRAMs on different hosts do not race the buffers;
   --  same-host use is serialised by the held SPI Session.
   type Scratch_Set is array (SPI.SPI_Host) of DMA_Buffer (0 .. Scratch_Length - 1);
   Scratch_Tx : Scratch_Set := (others => (others => 0));
   Scratch_Rx : Scratch_Set := (others => (others => 0));

   --  All-zeros source for read clocking (read-only, so it may be shared).
   Zero_Source : DMA_Buffer (0 .. Chunk_Max - 1) := (others => 0);

   ---------------------------------------------------------------------------
   --  Framing helpers.
   ---------------------------------------------------------------------------

   --  Write opcode + big-endian address into Header, return the header length.  For a
   --  4 Kbit part the ninth address bit (A8) rides in bit 3 of the opcode.
   procedure Put_Header
     (Header      : in out DMA_Buffer;
      Base_Opcode : Unsigned_8;
      Location    : Memory_Address;
      Length      : out Natural) is
   begin
      if Part.Opcode_High_Bit then
         Header (0) := Base_Opcode or (if Location >= 256 then 16#08# else 0);
         Header (1) := Unsigned_8 (Location mod 256);
         Length := 2;
      else
         Header (0) := Base_Opcode;
         case Address_Bytes is
            when 1 =>
               Header (1) := Unsigned_8 (Location);
               Length := 2;
            when 2 =>
               Header (1) := Unsigned_8 (Location / 256);
               Header (2) := Unsigned_8 (Location mod 256);
               Length := 3;
            when others =>
               Header (1) := Unsigned_8 (Location / 65_536);
               Header (2) := Unsigned_8 ((Location / 256) mod 256);
               Header (3) := Unsigned_8 (Location mod 256);
               Length := 4;
         end case;
      end if;
   end Put_Header;

   procedure Acquire (Session : in out SPI.Session; Dev : Device) is
   begin
      SPI.Acquire
        (Session, Dev.Host,
         Mode      => 0,
         Clock_Hz  => Dev.Clock_Hz,
         CS_Pin    => Dev.CS_Pin,
         Select_CB => Dev.CS_CB,
         Ctx       => Dev.Ctx);
   end Acquire;

   -----------
   -- Setup --
   -----------

   procedure Setup
     (Dev              : out Device;
      Sclk, Mosi, Miso : ESP32S3.GPIO.Pin_Id;
      CS_Pin           : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      CS_CB            : ESP32S3.SPI.CS_Select := null;
      Ctx              : System.Address := System.Null_Address;
      Host             : ESP32S3.SPI.SPI_Host := ESP32S3.SPI.SPI2;
      Clock_Hz         : Positive := Max_Clock) is
   begin
      Dev := (Host => Host, CS_Pin => CS_Pin, CS_CB => CS_CB,
              Ctx => Ctx, Clock_Hz => Clock_Hz);
      SPI.Setup (Host);
      SPI.Configure_Pins (Host, Sclk => Sclk, Mosi => Mosi, Miso => Miso);
   end Setup;

   --------------------
   -- Read_Device_ID --
   --------------------

   procedure Read_Device_ID (Dev : Device; ID : out Device_ID) is
      Session : SPI.Session;
   begin
      Scratch_Tx (Dev.Host) (0 .. 4) := (Cmd_RDID, 0, 0, 0, 0);
      Acquire (Session, Dev);
      SPI.Select_Device (Session, On => True);
      SPI.Transfer (Session, Scratch_Tx (Dev.Host), Scratch_Rx (Dev.Host), 5);
      SPI.Select_Device (Session, On => False);
      SPI.Release (Session);
      --  Bytes 1..4 follow the opcode.
      ID := (Scratch_Rx (Dev.Host) (1), Scratch_Rx (Dev.Host) (2),
             Scratch_Rx (Dev.Host) (3), Scratch_Rx (Dev.Host) (4));
   end Read_Device_ID;

   ----------------
   -- Is_Present --
   ----------------

   function Is_Present (Dev : Device) return Boolean is
      ID : Device_ID;
   begin
      Read_Device_ID (Dev, ID);
      return ID /= (0, 0, 0, 0) and then ID /= (16#FF#, 16#FF#, 16#FF#, 16#FF#);
   end Is_Present;

   --------------
   -- Identify --
   --------------

   function Identify (Dev : Device) return Vendor is
      ID : Device_ID;
   begin
      Read_Device_ID (Dev, ID);
      --  The manufacturer byte may sit behind 0x7F continuation codes, so scan.
      for ID_Byte of ID loop
         if ID_Byte = Fujitsu_Manufacturer then
            return Fujitsu;
         elsif ID_Byte = Cypress_Manufacturer then
            return Cypress;
         end if;
      end loop;
      return Unknown;
   end Identify;


   ----------
   -- Read --
   ----------

   procedure Read (Dev : Device; From : Memory_Address; Data : out Byte_Array) is
      Session     : SPI.Session;
      Header_Length  : Natural;
      Position   : Natural := Data'First;
      Chunk : Natural;
   begin
      if Data'Length = 0 then
         return;
      end if;
      Put_Header (Scratch_Tx (Dev.Host), Cmd_Read, From, Header_Length);
      Acquire (Session, Dev);
      SPI.Select_Device (Session, On => True);
      SPI.Transfer (Session, Scratch_Tx (Dev.Host), Scratch_Rx (Dev.Host), Header_Length);
      --  CS stays asserted: the chip auto-increments, so successive transfers
      --  keep reading sequential bytes.
      while Position <= Data'Last loop
         Chunk := Natural'Min (Chunk_Max, Data'Last - Position + 1);
         SPI.Transfer (Session, Zero_Source, Scratch_Rx (Dev.Host), Chunk);
         Data (Position .. Position + Chunk - 1) :=
           Byte_Array (Scratch_Rx (Dev.Host) (0 .. Chunk - 1));
         Position := Position + Chunk;
      end loop;
      SPI.Select_Device (Session, On => False);
      SPI.Release (Session);
   end Read;

   -----------
   -- Write --
   -----------

   procedure Write (Dev : Device; To : Memory_Address; Data : Byte_Array) is
      Session     : SPI.Session;
      Header_Length  : Natural;
      Position   : Natural := Data'First;
      Chunk : Natural;
   begin
      if Data'Length = 0 then
         return;
      end if;
      Acquire (Session, Dev);

      --  WREN: a self-contained frame, its own CS pulse.
      Scratch_Tx (Dev.Host) (0) := Cmd_WREN;
      SPI.Select_Device (Session, On => True);
      SPI.Transfer (Session, Scratch_Tx (Dev.Host), Scratch_Rx (Dev.Host), 1);
      SPI.Select_Device (Session, On => False);

      --  WRITE opcode + address, then stream the payload with CS held (the chip
      --  auto-increments; FRAM commits each byte as it is clocked in -- no BUSY
      --  poll afterwards).
      Put_Header (Scratch_Tx (Dev.Host), Cmd_Write, To, Header_Length);
      SPI.Select_Device (Session, On => True);
      SPI.Transfer (Session, Scratch_Tx (Dev.Host), Scratch_Rx (Dev.Host), Header_Length);
      while Position <= Data'Last loop
         Chunk := Natural'Min (Chunk_Max, Data'Last - Position + 1);
         Scratch_Tx (Dev.Host) (0 .. Chunk - 1) :=
           DMA_Buffer (Data (Position .. Position + Chunk - 1));
         SPI.Transfer (Session, Scratch_Tx (Dev.Host), Scratch_Rx (Dev.Host), Chunk);
         Position := Position + Chunk;
      end loop;
      SPI.Select_Device (Session, On => False);
      SPI.Release (Session);
   end Write;

   ---------------
   -- Read_Byte --
   ---------------

   function Read_Byte (Dev : Device; From : Memory_Address) return Interfaces.Unsigned_8 is
      One_Byte : Byte_Array (0 .. 0);
   begin
      Read (Dev, From, One_Byte);
      return One_Byte (0);
   end Read_Byte;

   ----------------
   -- Write_Byte --
   ----------------

   procedure Write_Byte (Dev : Device; To : Memory_Address; Value : Interfaces.Unsigned_8) is
   begin
      Write (Dev, To, Byte_Array'(0 => Value));
   end Write_Byte;

begin
   pragma Assert (Address_Bytes in 1 .. 3, "SPI FRAM takes one to three address bytes");
   pragma Assert
     (Capacity <= (2 ** (8 * Address_Bytes)) * (if Part.Opcode_High_Bit then 2 else 1),
      "address width too small for the capacity");
end ESP32S3.FRAM_SPI.Driver;
