with Interfaces;
with ESP32S3.I2C;
with ESP32S3.GPIO;

--  QST QMI8658C 6-axis IMU (3-axis accelerometer + 3-axis gyroscope) I2C driver.
--
--  Same shape as ESP32S3.PCF85063A: the driver hard-codes no board wiring -- you
--  tell Setup which host and which SDA / SCL (and, optionally, which INT) pins
--  the part is wired to, plus the I2C address (SA0 selects 0x6A / 0x6B), and the
--  Device remembers them.  Each operation then opens a short-lived I2C Session (a
--  controlled type) for one complete transaction and lets it release the host
--  automatically on scope exit -- so concurrent callers serialise and a fault
--  between acquire and release can't leak the bus.  Needs the controlled Session
--  => embedded / full profiles only (excluded from light-tasking).
--
--  Register reads use the chip's auto-incrementing address pointer (CTRL1.ADDR_AI,
--  set by Configure): a 1-byte write sets the pointer, a following read streams
--  from it.  The driver runs the device little-endian (CTRL1.BE = 0).
--
--  Typical use:
--     declare
--        IMU : ESP32S3.QMI8658C.Device;
--        A   : ESP32S3.QMI8658C.Axes;
--        St  : ESP32S3.QMI8658C.Status;
--     begin
--        ESP32S3.QMI8658C.Setup (IMU, Sda => 8, Scl => 7);   --  state the wiring
--        ESP32S3.QMI8658C.Reset (IMU, St);                   --  (then wait ~15 ms)
--        ESP32S3.QMI8658C.Configure (IMU, St);               --  ranges + ODR + on
--        ESP32S3.QMI8658C.Read_Accelerometer (IMU, A, St);   --  raw counts
--        --  g = A.X / Float (ESP32S3.QMI8658C.Accel_LSB_Per_G (IMU))
--     end;
package ESP32S3.QMI8658C is

   --  7-bit I2C address, selected by the SA0 / SDO pin.  SA0 has an internal
   --  200 k pull-up, so a floating pin reads high => 0x6A is the power-on default.
   Address_SA0_High : constant ESP32S3.I2C.Slave_Address := 16#6A#;   --  SA0 = VDDIO
   Address_SA0_Low  : constant ESP32S3.I2C.Slave_Address := 16#6B#;   --  SA0 = GND

   --  WHO_AM_I (register 0x00) returns this for every QST QMI8658.
   Who_Am_I_Value : constant Interfaces.Unsigned_8 := 16#05#;

   ----------------------------------------------------------------------------
   --  Sensor configuration choices.
   ----------------------------------------------------------------------------

   --  Accelerometer full scale (CTRL2.aFS).
   type Accel_Range is (Range_2G, Range_4G, Range_8G, Range_16G);

   --  Gyroscope full scale (CTRL3.gFS), in degrees per second.
   type Gyro_Range is
     (Range_16DPS,  Range_32DPS,   Range_64DPS,  Range_128DPS,
      Range_256DPS, Range_512DPS, Range_1024DPS, Range_2048DPS);

   --  Output data rate (CTRL2.aODR / CTRL3.gODR).  These are the 6DOF /
   --  gyroscope rates -- the rates in effect when both sensors are enabled, as
   --  Configure does.  (Accelerometer-only mode uses a different rate table; not
   --  exposed here.)
   type Output_Rate is
     (ODR_7520_Hz, ODR_3760_Hz, ODR_1880_Hz, ODR_940_Hz, ODR_470_Hz,
      ODR_235_Hz,  ODR_118_Hz,  ODR_59_Hz,   ODR_29_Hz);

   ----------------------------------------------------------------------------
   --  Output data.
   ----------------------------------------------------------------------------

   --  One 3-axis reading, raw 16-bit signed counts (sensor frame, right-handed).
   --  Convert to physical units with the *_LSB_* sensitivity below.
   type Axes is record
      X, Y, Z : Interfaces.Integer_16 := 0;
   end record;

   --  Result of a bus operation.  Bus_Error means the chip did not ACK its
   --  address or a data byte (absent device, wrong address, or a stuck bus).
   type Status is (OK, Bus_Error);

   --  A single QMI8658C.  Limited (non-copyable: it owns the wiring + address it
   --  was set up with).  Holds no finalizable resource itself -- the short-lived
   --  I2C Session each operation opens does the locking and auto-release.
   type Device is limited private;

   ----------------------------------------------------------------------------
   --  One-time configuration -- call once at startup (single-threaded).
   ----------------------------------------------------------------------------

   --  Record the wiring + address and bring the bus up: store Host / Address /
   --  Sda / Scl / Int_Pin in Dev, set the I2C host to a master at Clock_Hz, and
   --  route SDA/SCL.  No pin defaults -- the caller states the board wiring.
   --  Int_Pin is the GPIO an INT line (INT1/INT2) is wired to, or No_Pin if none
   --  (arming it is the job of the ESP32S3.QMI8658C.Interrupts child).  Setup
   --  does not touch the chip -- call Reset then Configure.
   procedure Setup
     (Dev      : out Device;
      Sda      : ESP32S3.GPIO.Pin_Id;
      Scl      : ESP32S3.GPIO.Pin_Id;
      Int_Pin  : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Address  : ESP32S3.I2C.Slave_Address := Address_SA0_Low;
      Host     : ESP32S3.I2C.I2C_Host      := ESP32S3.I2C.I2C0;
      Clock_Hz : Positive                  := 400_000);

   --  The INT pin Dev was set up with (No_Pin if none).
   function Interrupt_Pin (Dev : Device) return ESP32S3.GPIO.Optional_Pin;

   ----------------------------------------------------------------------------
   --  Device control.
   ----------------------------------------------------------------------------

   --  Read WHO_AM_I (0x00).  Id = Who_Am_I_Value (0x05) confirms a QMI8658 is
   --  present and the address is right.  Works before Configure.
   procedure Read_Who_Am_I
     (Dev : Device; Id : out Interfaces.Unsigned_8; Result : out Status);

   --  Soft reset (write 0xB0 to the RESET register): returns every register to
   --  its power-on default.  Wait ~15 ms afterwards, then Configure.
   procedure Reset (Dev : Device; Result : out Status);

   --  Bring the sensors up: enable register auto-increment + little-endian
   --  (CTRL1), set the accelerometer (CTRL2) and gyroscope (CTRL3) full scale and
   --  output rate, and enable both sensors -- 6DOF (CTRL7).  Records the ranges in
   --  Dev so the sensitivity accessors and reads are consistent.  Must precede
   --  the Read_* operations (they rely on the auto-increment set here).
   procedure Configure
     (Dev    : in out Device;
      Accel  : Accel_Range := Range_8G;
      Gyro   : Gyro_Range  := Range_512DPS;
      Rate   : Output_Rate := ODR_235_Hz;
      Result : out Status);

   ----------------------------------------------------------------------------
   --  Output.
   ----------------------------------------------------------------------------

   --  Read the three accelerometer / gyroscope axes (raw signed counts).
   procedure Read_Accelerometer (Dev : Device; A : out Axes; Result : out Status);
   procedure Read_Gyroscope     (Dev : Device; G : out Axes; Result : out Status);

   --  Read the on-chip temperature, raw signed (two registers).  Degrees Celsius
   --  = Raw / 256.0.
   procedure Read_Temperature
     (Dev : Device; Raw : out Interfaces.Integer_16; Result : out Status);

   --  New-data flags from STATUS0 (set since the matching axes were last read).
   procedure Data_Ready
     (Dev : Device; Accel, Gyro : out Boolean; Result : out Status);

   --  Sensitivity of the configured ranges, used to scale the raw counts:
   --     g   = A.X / Float (Accel_LSB_Per_G (Dev))
   --     dps = G.X / Float (Gyro_LSB_Per_DPS (Dev))
   function Accel_LSB_Per_G   (Dev : Device) return Positive;
   function Gyro_LSB_Per_DPS  (Dev : Device) return Positive;

private
   type Device is record
      Host      : ESP32S3.I2C.I2C_Host      := ESP32S3.I2C.I2C0;
      Address   : ESP32S3.I2C.Slave_Address := Address_SA0_Low;
      Sda       : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Scl       : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Int_Pin   : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Accel_Rng : Accel_Range               := Range_8G;
      Gyro_Rng  : Gyro_Range                := Range_512DPS;
   end record;
end ESP32S3.QMI8658C;
