with Ada.Unchecked_Conversion;

package body ESP32S3.QMI8658C is

   use ESP32S3.I2C;   --  Byte, Byte_Array, Session, Slave_Address, Acquire/Write/Read
   use type Interfaces.Unsigned_16;   --  "*" / "+" on the byte-pair combine

   ---------------------------------------------------------------------------
   --  Register map (QMI8658C datasheet rev 0.9, section 5).
   ---------------------------------------------------------------------------

   Reg_Who_Am_I  : constant Byte := 16#00#;
   Reg_Ctrl1     : constant Byte := 16#02#;   --  serial interface + sensor disable
   Reg_Ctrl2     : constant Byte := 16#03#;   --  accel: aST / aFS / aODR
   Reg_Ctrl3     : constant Byte := 16#04#;   --  gyro:  gST / gFS / gODR
   Reg_Ctrl7     : constant Byte := 16#08#;   --  enable: aEN / gEN
   Reg_Status0   : constant Byte := 16#2E#;   --  aDA / gDA data-ready
   Reg_Temp_L    : constant Byte := 16#33#;   --  .. 0x34  (TEMP_L, TEMP_H)
   Reg_Accel_X_L : constant Byte := 16#35#;   --  .. 0x3A  (AX_L .. AZ_H)
   Reg_Gyro_X_L  : constant Byte := 16#3B#;   --  .. 0x40  (GX_L .. GZ_H)
   Reg_Reset     : constant Byte := 16#60#;   --  soft reset

   --  CTRL1: ADDR_AI (bit6) auto-increments the register pointer on burst reads;
   --  BE (bit5) left 0 => little-endian.  Both sensors run off the 2 MHz osc.
   Ctrl1_Init    : constant Byte := 16#40#;   --  ADDR_AI = 1, BE = 0

   --  CTRL7: enable accelerometer (aEN, bit0) + gyroscope (gEN, bit1) = 6DOF.
   Ctrl7_Enable  : constant Byte := 16#03#;

   --  RESET register command that triggers the soft reset.
   Reset_Command : constant Byte := 16#B0#;

   --  STATUS0 data-ready bits.
   Status_Accel_Ready : constant Byte := 16#01#;   --  aDA
   Status_Gyro_Ready  : constant Byte := 16#02#;   --  gDA

   ---------------------------------------------------------------------------
   --  Little-endian byte pair -> 16-bit signed (two's complement).
   ---------------------------------------------------------------------------

   function To_I16 is
     new Ada.Unchecked_Conversion (Interfaces.Unsigned_16, Interfaces.Integer_16);

   function Signed (Lo, Hi : Byte) return Interfaces.Integer_16 is
     (To_I16 (Interfaces.Unsigned_16 (Hi) * 256 + Interfaces.Unsigned_16 (Lo)));

   ---------------------------------------------------------------------------
   --  Register access on an already-acquired Session (Addr = the device's I2C
   --  address).  The public operations open one Session and drive these.
   ---------------------------------------------------------------------------

   --  Set the address pointer (1-byte write), then stream Data'Length bytes from
   --  it (CTRL1.ADDR_AI auto-increments the pointer across the read).
   procedure Read_Regs
     (S : Session; Addr : Slave_Address; Reg : Byte;
      Data : out Byte_Array; Result : out Status)
   is
      Acked : Boolean;
   begin
      Write (S, Addr, (1 => Reg), Acked);
      if Acked then
         Read (S, Addr, Data, Acked);
      end if;
      Result := (if Acked then OK else Bus_Error);
   end Read_Regs;

   --  Write Reg followed by Data in one transaction.
   procedure Write_Regs
     (S : Session; Addr : Slave_Address; Reg : Byte;
      Data : Byte_Array; Result : out Status)
   is
      Acked : Boolean;
      Buf   : Byte_Array (0 .. Data'Length);
   begin
      Buf (0) := Reg;
      if Data'Length > 0 then
         Buf (1 .. Buf'Last) := Data;
      end if;
      Write (S, Addr, Buf, Acked);
      Result := (if Acked then OK else Bus_Error);
   end Write_Regs;

   --  Read the 3 axes that start at Reg (6 bytes, little-endian L/H pairs).
   procedure Read_Axes
     (Dev : Device; Reg : Byte; V : out Axes; Result : out Status)
   is
      S : Session;
      R : Byte_Array (0 .. 5);
   begin
      V := (0, 0, 0);
      Acquire (S, Dev.Host);
      Read_Regs (S, Dev.Address, Reg, R, Result);
      if Result = OK then
         V.X := Signed (R (0), R (1));
         V.Y := Signed (R (2), R (3));
         V.Z := Signed (R (4), R (5));
      end if;
   end Read_Axes;

   -----------
   -- Setup --
   -----------

   procedure Setup
     (Dev      : out Device;
      Sda      : ESP32S3.GPIO.Pin_Id;
      Scl      : ESP32S3.GPIO.Pin_Id;
      Int_Pin  : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Address  : ESP32S3.I2C.Slave_Address := Address_SA0_Low;
      Host     : ESP32S3.I2C.I2C_Host      := ESP32S3.I2C.I2C0;
      Clock_Hz : Positive                  := 400_000) is
   begin
      Dev := (Host => Host, Address => Address, Sda => Sda, Scl => Scl,
              Int_Pin => Int_Pin, others => <>);
      ESP32S3.I2C.Setup (Host, Clock_Hz => Clock_Hz);
      ESP32S3.I2C.Configure_Pins (Host, Scl => Scl, Sda => Sda);
   end Setup;

   -------------------
   -- Interrupt_Pin --
   -------------------

   function Interrupt_Pin (Dev : Device) return ESP32S3.GPIO.Optional_Pin is
     (Dev.Int_Pin);

   ------------------
   -- Read_Who_Am_I --
   ------------------

   procedure Read_Who_Am_I
     (Dev : Device; Id : out Interfaces.Unsigned_8; Result : out Status)
   is
      S : Session;
      V : Byte_Array (0 .. 0);
   begin
      Id := 0;
      Acquire (S, Dev.Host);
      Read_Regs (S, Dev.Address, Reg_Who_Am_I, V, Result);
      if Result = OK then
         Id := Interfaces.Unsigned_8 (V (0));
      end if;
   end Read_Who_Am_I;

   -----------
   -- Reset --
   -----------

   procedure Reset (Dev : Device; Result : out Status) is
      S : Session;
   begin
      Acquire (S, Dev.Host);
      Write_Regs (S, Dev.Address, Reg_Reset, (1 => Reset_Command), Result);
   end Reset;

   ---------------
   -- Configure --
   ---------------

   procedure Configure
     (Dev    : in out Device;
      Accel  : Accel_Range := Range_8G;
      Gyro   : Gyro_Range  := Range_512DPS;
      Rate   : Output_Rate := ODR_235_Hz;
      Result : out Status)
   is
      S   : Session;
      ODR : constant Byte := Byte (Output_Rate'Pos (Rate));
   begin
      Dev.Accel_Rng := Accel;
      Dev.Gyro_Rng  := Gyro;

      Acquire (S, Dev.Host);

      --  Auto-increment + little-endian, so the burst reads below work.
      Write_Regs (S, Dev.Address, Reg_Ctrl1, (1 => Ctrl1_Init), Result);
      if Result /= OK then
         return;
      end if;

      --  Accelerometer full scale (aFS<6:4>) + output rate (aODR<3:0>).
      Write_Regs (S, Dev.Address, Reg_Ctrl2,
                  (1 => Byte (Accel_Range'Pos (Accel)) * 16 or ODR), Result);
      if Result /= OK then
         return;
      end if;

      --  Gyroscope full scale (gFS<6:4>) + output rate (gODR<3:0>).
      Write_Regs (S, Dev.Address, Reg_Ctrl3,
                  (1 => Byte (Gyro_Range'Pos (Gyro)) * 16 or ODR), Result);
      if Result /= OK then
         return;
      end if;

      --  Enable both sensors (6DOF).
      Write_Regs (S, Dev.Address, Reg_Ctrl7, (1 => Ctrl7_Enable), Result);
   end Configure;

   -----------------------
   -- Read_Accelerometer --
   -----------------------

   procedure Read_Accelerometer
     (Dev : Device; A : out Axes; Result : out Status) is
   begin
      Read_Axes (Dev, Reg_Accel_X_L, A, Result);
   end Read_Accelerometer;

   --------------------
   -- Read_Gyroscope --
   --------------------

   procedure Read_Gyroscope
     (Dev : Device; G : out Axes; Result : out Status) is
   begin
      Read_Axes (Dev, Reg_Gyro_X_L, G, Result);
   end Read_Gyroscope;

   ----------------------
   -- Read_Temperature --
   ----------------------

   procedure Read_Temperature
     (Dev : Device; Raw : out Interfaces.Integer_16; Result : out Status)
   is
      S : Session;
      R : Byte_Array (0 .. 1);
   begin
      Raw := 0;
      Acquire (S, Dev.Host);
      Read_Regs (S, Dev.Address, Reg_Temp_L, R, Result);
      if Result = OK then
         Raw := Signed (R (0), R (1));
      end if;
   end Read_Temperature;

   ----------------
   -- Data_Ready --
   ----------------

   procedure Data_Ready
     (Dev : Device; Accel, Gyro : out Boolean; Result : out Status)
   is
      S : Session;
      V : Byte_Array (0 .. 0);
   begin
      Accel := False;
      Gyro  := False;
      Acquire (S, Dev.Host);
      Read_Regs (S, Dev.Address, Reg_Status0, V, Result);
      if Result = OK then
         Accel := (V (0) and Status_Accel_Ready) /= 0;
         Gyro  := (V (0) and Status_Gyro_Ready)  /= 0;
      end if;
   end Data_Ready;

   ---------------------------------
   -- Accel_LSB_Per_G / Gyro_LSB --
   ---------------------------------

   --  Accel: 16384 / 8192 / 4096 / 2048 LSB/g for 2 / 4 / 8 / 16 g.
   function Accel_LSB_Per_G (Dev : Device) return Positive is
     (2 ** (14 - Accel_Range'Pos (Dev.Accel_Rng)));

   --  Gyro: 2048 .. 16 LSB/dps for 16 .. 2048 dps.
   function Gyro_LSB_Per_DPS (Dev : Device) return Positive is
     (2 ** (11 - Gyro_Range'Pos (Dev.Gyro_Rng)));

end ESP32S3.QMI8658C;
