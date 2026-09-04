with Interfaces;
with ESP32S3.I2C;
with ESP32S3.GPIO;

--  Sensirion SHT41 (SHT4x family) I2C temperature + humidity sensor driver.
--
--  Same shape as ESP32S3.PCF85063A: the driver hard-codes no board wiring -- you
--  tell Setup which host and which SDA / SCL pins the part is wired to (plus the
--  I2C address), and the Device remembers them.  Each operation then opens a
--  short-lived I2C Session (a controlled type) for one complete exchange and
--  lets it release the host automatically on scope exit -- so the sensor shares
--  the bus safely with the other I2C devices.  No interrupt: it is read on
--  request.  Needs the controlled Session => embedded / full profiles only.
--
--  The SHT4x is command-based (no registers): a measurement is "write a 1-byte
--  command, wait the conversion time, read 6 bytes" -- two CRC-8-protected
--  16-bit words (temperature then humidity).  Measure blocks for the conversion
--  while holding the bus.
--
--  Typical use:
--     declare
--        Sensor : ESP32S3.SHT41.Device;
--        M      : ESP32S3.SHT41.Measurement;
--        St     : ESP32S3.SHT41.Status;
--     begin
--        ESP32S3.SHT41.Setup (Sensor, Sda => 8, Scl => 7);   --  state the wiring
--        ESP32S3.SHT41.Measure (Sensor, M, St);              --  one reading
--        --  M.Temperature in mÃÂ°C, M.Humidity in m%RH (St = OK).
--     end;

package ESP32S3.SHT41 is

   --  7-bit I2C address.  The SHT41-AD1B answers at 0x44; other SHT4x variants
   --  use 0x45 / 0x46.
   Default_Address : constant ESP32S3.I2C.Slave_Address := 16#44#;

   --  One reading, in integer milli-units (so no float library is needed):
   --     Temperature 23_456  =  23.456 ÃÂ°C
   --     Humidity    45_678  =  45.678 %RH  (clamped to 0 .. 100_000)
   type Measurement is record
      Temperature : Integer := 0;   --  milli-degrees Celsius
      Humidity    : Integer := 0;   --  milli-percent relative humidity
   end record;

   --  Measurement repeatability: higher precision = lower noise but a longer
   --  conversion (High ~8 ms, Medium ~4 ms, Low ~2 ms).
   type Precision is (Low, Medium, High);

   --  Result of an operation.  Bus_Error: the sensor did not ACK (absent / wrong
   --  address / stuck bus).  CRC_Error: data arrived but failed its checksum.
   type Status is (OK, Bus_Error, CRC_Error);

   --  A single SHT41 on one I2C host.  Limited (non-copyable: it names the host
   --  and address the sensor is wired to).
   type Device is limited private;

   ----------------------------------------------------------------------------
   --  One-time configuration -- call once at startup (single-threaded).
   ----------------------------------------------------------------------------

   --  Record the wiring + address and bring the bus up: store Host / Address in
   --  Dev, set the I2C host to a master at Clock_Hz, and route SDA/SCL.  No pin
   --  defaults -- the caller states the board wiring.
   procedure Setup
     (Dev      : out Device;
      Sda      : ESP32S3.GPIO.Pin_Id;
      Scl      : ESP32S3.GPIO.Pin_Id;
      Address  : ESP32S3.I2C.Slave_Address := Default_Address;
      Host     : ESP32S3.I2C.I2C_Host := ESP32S3.I2C.I2C0;
      Clock_Hz : Positive := 400_000);

   ----------------------------------------------------------------------------
   --  Operations.
   ----------------------------------------------------------------------------

   --  Trigger a single-shot measurement and read it back.  Blocks for the
   --  conversion time (per Repeatability) while holding the bus.  Both 16-bit
   --  words are CRC-checked; on CRC_Error the value is left at its defaults.
   procedure Measure
     (Dev           : Device;
      Value         : out Measurement;
      Result        : out Status;
      Repeatability : Precision := High);

   --  Read the sensor's 32-bit unique serial number (CRC-checked).  Useful as a
   --  presence / comms check.
   procedure Read_Serial_Number
     (Dev : Device; Serial : out Interfaces.Unsigned_32; Result : out Status);

   --  Soft reset to the power-on state.
   procedure Reset (Dev : Device; Result : out Status);

private
   type Device is record
      Host    : ESP32S3.I2C.I2C_Host := ESP32S3.I2C.I2C0;
      Address : ESP32S3.I2C.Slave_Address := Default_Address;
   end record;
end ESP32S3.SHT41;
