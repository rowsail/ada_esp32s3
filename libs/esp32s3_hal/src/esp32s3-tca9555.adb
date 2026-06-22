package body ESP32S3.TCA9555 is

   use ESP32S3.I2C;   --  Byte, Byte_Array, Slave_Address (our Session/Acquire
                      --  hide I2C's homographs; the I2C ones are qualified below)

   ---------------------------------------------------------------------------
   --  Register map (TCA9555).  Each command auto-increments across its port
   --  pair, so a 2-byte access starting at port 0 covers port 0 then port 1.
   ---------------------------------------------------------------------------

   Reg_Input    : constant Byte := 16#00#;   --  .. 16#01#
   Reg_Output   : constant Byte := 16#02#;   --  .. 16#03#
   Reg_Polarity : constant Byte := 16#04#;   --  .. 16#05#
   Reg_Config   : constant Byte := 16#06#;   --  .. 16#07#

   ---------------------------------------------------------------------------
   --  Per-device locks: one guard per (host, strap value), library-level (so no
   --  protected object lives in a Device).  Same shape as ESP32S3.I2C's guards.
   ---------------------------------------------------------------------------

   protected type Device_Guard is
      entry    Acquire;
      procedure Release;
   private
      Held : Boolean := False;
   end Device_Guard;

   protected body Device_Guard is
      entry Acquire when not Held is
      begin
         Held := True;
      end Acquire;
      procedure Release is
      begin
         Held := False;
      end Release;
   end Device_Guard;

   Guards : array (ESP32S3.I2C.I2C_Host, Hardware_Address) of Device_Guard;

   ---------------------------------------------------------------------------
   --  Pin helpers.
   ---------------------------------------------------------------------------

   --  Which register of a pair the pin lives in (0 = port 0, 1 = port 1).
   function Port_Of (Pin : Pin_Number) return Byte is (Byte (Pin / 8));

   --  Single-bit mask for the pin within its port.
   function Mask_Of (Pin : Pin_Number) return Byte is
     (Byte (2 ** Natural (Pin mod 8)));

   procedure Check_Owned (S : Session) is
   begin
      if not S.Active then
         raise Not_Owned with "TCA9555 used without holding it -- Acquire first";
      end if;
   end Check_Owned;

   ---------------------------------------------------------------------------
   --  Register access: each opens a SHORT-LIVED I2C Session (the host lock),
   --  transacts, and releases it on return -- so the bus is free between calls
   --  even while the caller still holds this device's Session.
   ---------------------------------------------------------------------------

   procedure Read_Reg
     (S : Session; Reg : Byte; Data : out Byte_Array; Result : out Status)
   is
      Bus   : ESP32S3.I2C.Session;
      Acked : Boolean;
   begin
      Check_Owned (S);
      ESP32S3.I2C.Acquire (Bus, S.Host);
      ESP32S3.I2C.Write (Bus, S.Address, (1 => Reg), Acked);   --  set pointer
      if Acked then
         ESP32S3.I2C.Read (Bus, S.Address, Data, Acked);
      end if;
      Result := (if Acked then OK else Bus_Error);
   end Read_Reg;                                               --  Bus released here

   procedure Write_Reg
     (S : Session; Reg : Byte; Data : Byte_Array; Result : out Status)
   is
      Bus   : ESP32S3.I2C.Session;
      Acked : Boolean;
      Buf   : Byte_Array (0 .. Data'Length);
   begin
      Check_Owned (S);
      Buf (0) := Reg;
      if Data'Length > 0 then
         Buf (1 .. Buf'Last) := Data;
      end if;
      ESP32S3.I2C.Acquire (Bus, S.Host);
      ESP32S3.I2C.Write (Bus, S.Address, Buf, Acked);
      Result := (if Acked then OK else Bus_Error);
   end Write_Reg;

   --  Read-modify-write one bit of register Reg.
   procedure Update_Bit
     (S : Session; Reg : Byte; Mask : Byte; Set : Boolean; Result : out Status)
   is
      B : Byte_Array (0 .. 0);
   begin
      Read_Reg (S, Reg, B, Result);
      if Result /= OK then
         return;
      end if;
      B (0) := (if Set then B (0) or Mask else B (0) and not Mask);
      Write_Reg (S, Reg, B, Result);
   end Update_Bit;

   --  Split a 16-bit value into the two port bytes (port 0 low, port 1 high).
   function Pair (V : Port_Value) return Byte_Array is
     (0 => Byte (V and 16#FF#), 1 => Byte (V / 256));

   -----------
   -- Setup --
   -----------

   procedure Setup
     (Dev      : out Device;
      Addr     : Hardware_Address;
      Sda      : ESP32S3.GPIO.Pin_Id;
      Scl      : ESP32S3.GPIO.Pin_Id;
      Int_Pin  : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Host     : ESP32S3.I2C.I2C_Host      := ESP32S3.I2C.I2C0;
      Clock_Hz : Positive                  := 400_000) is
   begin
      Dev := (Host       => Host,
              Addr       => Addr,
              Address    => Base_Address + Slave_Address (Addr),
              Int_Pin    => Int_Pin,
              Configured => True);
      ESP32S3.I2C.Setup (Host, Clock_Hz => Clock_Hz);
      ESP32S3.I2C.Configure_Pins (Host, Scl => Scl, Sda => Sda);
   end Setup;

   function Interrupt_Pin (Dev : Device) return ESP32S3.GPIO.Optional_Pin is
     (Dev.Int_Pin);

   -------------------------
   -- Acquire / Release --
   -------------------------

   procedure Acquire (S : in out Session; Dev : Device) is
   begin
      if not Dev.Configured then
         raise Not_Initialized with "TCA9555 acquired before Setup";
      end if;
      Guards (Dev.Host, Dev.Addr).Acquire;   --  suspends until this chip is free
      S.Active  := True;
      S.Host    := Dev.Host;
      S.Addr    := Dev.Addr;
      S.Address := Dev.Address;
   end Acquire;

   procedure Release (S : in out Session) is
   begin
      if S.Active then
         S.Active := False;
         Guards (S.Host, S.Addr).Release;
      end if;
   end Release;

   overriding procedure Finalize (S : in out Session) is
   begin
      Release (S);
   end Finalize;

   --------------------
   -- Direction --
   --------------------

   procedure Set_Directions
     (S : Session; Inputs : Port_Value; Result : out Status) is
   begin
      Write_Reg (S, Reg_Config, Pair (Inputs), Result);
   end Set_Directions;

   procedure Set_Direction
     (S : Session; Pin : Pin_Number; Dir : Direction; Result : out Status) is
   begin
      --  Config bit 1 = input, 0 = output.
      Update_Bit (S, Reg_Config + Port_Of (Pin), Mask_Of (Pin),
                  Set => Dir = Input, Result => Result);
   end Set_Direction;

   ------------
   -- Output --
   ------------

   procedure Write_Port (S : Session; Value : Port_Value; Result : out Status) is
   begin
      Write_Reg (S, Reg_Output, Pair (Value), Result);
   end Write_Port;

   procedure Write_Pin
     (S : Session; Pin : Pin_Number; State : Pin_State; Result : out Status) is
   begin
      Update_Bit (S, Reg_Output + Port_Of (Pin), Mask_Of (Pin),
                  Set => State = High, Result => Result);
   end Write_Pin;

   -----------
   -- Input --
   -----------

   --  Read a 16-bit register pair starting at Reg into Value.
   procedure Read_Pair
     (S : Session; Reg : Byte; Value : out Port_Value; Result : out Status)
   is
      B : Byte_Array (0 .. 1);
   begin
      Value := 0;
      Read_Reg (S, Reg, B, Result);
      if Result = OK then
         Value := Port_Value (B (0)) + Port_Value (B (1)) * 256;
      end if;
   end Read_Pair;

   procedure Read_Port (S : Session; Value : out Port_Value; Result : out Status)
   is
   begin
      Read_Pair (S, Reg_Input, Value, Result);
   end Read_Port;

   procedure Read_Directions
     (S : Session; Inputs : out Port_Value; Result : out Status) is
   begin
      Read_Pair (S, Reg_Config, Inputs, Result);
   end Read_Directions;

   procedure Read_Outputs
     (S : Session; Value : out Port_Value; Result : out Status) is
   begin
      Read_Pair (S, Reg_Output, Value, Result);
   end Read_Outputs;

   procedure Read_Polarity
     (S : Session; Inverted : out Port_Value; Result : out Status) is
   begin
      Read_Pair (S, Reg_Polarity, Inverted, Result);
   end Read_Polarity;

   procedure Read_Pin
     (S : Session; Pin : Pin_Number; State : out Pin_State; Result : out Status)
   is
      B : Byte_Array (0 .. 0);
   begin
      State := Low;
      Read_Reg (S, Reg_Input + Port_Of (Pin), B, Result);
      if Result = OK then
         State := (if (B (0) and Mask_Of (Pin)) /= 0 then High else Low);
      end if;
   end Read_Pin;

   --------------
   -- Polarity --
   --------------

   procedure Set_Polarity
     (S : Session; Inverted : Port_Value; Result : out Status) is
   begin
      Write_Reg (S, Reg_Polarity, Pair (Inverted), Result);
   end Set_Polarity;

end ESP32S3.TCA9555;
