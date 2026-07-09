with ESP32S3.GPIO;
with ESP32S3.I2C;

--  STMicroelectronics M24C64 64-Kbit (8 KiB) serial I2C EEPROM driver.
--
--  Addressing -- the part answers to device select code 1010 followed by the
--  levels strapped on its three chip-enable pins E2/E1/E0 (silkscreened A2/A1/A0
--  on most breakouts), so the 7-bit slave address is 0x50 + A2*4 + A1*2 + A0 and
--  up to eight parts share one bus.  Setup takes the three levels directly; see
--  Device_Address to compute the address without a Device (bus scans, logging).
--
--  The memory array is byte-addressable 0 .. 8191 with a 16-bit internal address
--  pointer.  Reads may span the whole array; WRITES may not cross a 32-byte page
--  boundary (the part wraps within the page instead of advancing), and each page
--  write starts a ~5 ms internal program cycle during which the chip NACKs
--  everything.  Both are handled here: Write splits its payload on page
--  boundaries and ACK-polls the part back to readiness after each page, so the
--  caller just writes a Byte_Array at an address.
--
--  A write therefore goes out one whole page per transaction -- ESP32S3.I2C.Write
--  refills the controller's FIFO mid-transaction, so the 2 address bytes and 32
--  data bytes arrive as the single START..STOP segment the part demands.  A read
--  of any length is likewise ONE transaction: ESP32S3.I2C.Write_Read sends the
--  address and turns the bus around on a repeated START, exactly as the
--  datasheet's random read prescribes, and the part's counter walks the array.
--
--  A Read holds the I2C host for the whole transfer; a Write holds it across every
--  page and its program cycle, so a multi-page Write is atomic w.r.t. other tasks
--  on the bus.
--
--  Uses the controlled I2C Session (finalization) => embedded / full profiles.
--
--  Typical use:
--     declare
--        Rom : ESP32S3.M24C64.Device;
--        St  : ESP32S3.M24C64.Status;
--        Buf : ESP32S3.I2C.Byte_Array (0 .. 63);
--     begin
--        ESP32S3.M24C64.Setup (Rom, Sda => 41, Scl => 40);   --  A2=A1=A0=Low
--        ESP32S3.M24C64.Write (Rom, 16#0100#, Buf, St);
--        ESP32S3.M24C64.Read  (Rom, 16#0100#, Buf, St);
--     end;

package ESP32S3.M24C64 is

   --  64 Kbit = 8192 bytes, programmed 32 bytes at a time.
   Capacity  : constant := 8_192;
   Page_Size : constant := 32;

   subtype Memory_Address is Natural range 0 .. Capacity - 1;

   --  Level strapped on a chip-enable pin (tied to VCC or VSS on the board).
   type Pin_State is (Low, High);

   Base_Address : constant ESP32S3.I2C.Slave_Address := 16#50#;

   --  The 7-bit slave address selected by the three chip-enable straps.
   function Device_Address
     (A0 : Pin_State; A1 : Pin_State; A2 : Pin_State) return ESP32S3.I2C.Slave_Address
   is (Base_Address
       + (if A0 = High then 1 else 0)
       + (if A1 = High then 2 else 0)
       + (if A2 = High then 4 else 0));

   --  Result of a memory operation.  Bus_Error: the part did not ACK (absent,
   --  mis-strapped, or write-protected via WC).  Write_Timeout: it never came
   --  back from an internal program cycle.
   type Status is (OK, Bus_Error, Write_Timeout);

   type Device is limited private;

   ----------------------------------------------------------------------------
   --  One-time configuration -- call once per device at startup.
   ----------------------------------------------------------------------------

   --  Record the wiring and the chip-enable straps, then bring the I2C host up.
   --  A0/A1/A2 must match how the pins are tied on the board; all-Low (address
   --  0x50) is the single-chip default.  No pin defaults for Sda/Scl.
   procedure Setup
     (Dev      : out Device;
      Sda      : ESP32S3.GPIO.Pin_Id;
      Scl      : ESP32S3.GPIO.Pin_Id;
      A0       : Pin_State := Low;
      A1       : Pin_State := Low;
      A2       : Pin_State := Low;
      Host     : ESP32S3.I2C.I2C_Host := ESP32S3.I2C.I2C0;
      Clock_Hz : Positive := 400_000);

   --  The 7-bit slave address Dev was set up with.
   function Address (Dev : Device) return ESP32S3.I2C.Slave_Address;

   --  True if the part ACKs an address-only probe: present, powered, strapped as
   --  configured, and not mid-program-cycle.
   function Is_Present (Dev : Device) return Boolean;

   ----------------------------------------------------------------------------
   --  Memory access.
   ----------------------------------------------------------------------------

   --  Read Data'Length bytes starting at From.  A zero-length read is a no-op.
   procedure Read
     (Dev : Device; From : Memory_Address; Data : out ESP32S3.I2C.Byte_Array; Result : out Status)
   with Pre => Data'Length <= Capacity - From;

   --  Write Data at To, splitting on page boundaries and waiting out each program
   --  cycle.  A zero-length write is a no-op.  On Bus_Error or Write_Timeout the
   --  pages before the failure are already committed.
   procedure Write
     (Dev : Device; To : Memory_Address; Data : ESP32S3.I2C.Byte_Array; Result : out Status)
   with Pre => Data'Length <= Capacity - To;

   procedure Read_Byte
     (Dev : Device; From : Memory_Address; Value : out ESP32S3.I2C.Byte; Result : out Status);

   procedure Write_Byte
     (Dev : Device; To : Memory_Address; Value : ESP32S3.I2C.Byte; Result : out Status);

private
   type Device is record
      Host    : ESP32S3.I2C.I2C_Host := ESP32S3.I2C.I2C0;
      Addr    : ESP32S3.I2C.Slave_Address := Base_Address;
   end record;

   function Address (Dev : Device) return ESP32S3.I2C.Slave_Address
   is (Dev.Addr);

end ESP32S3.M24C64;
