package body ESP32S3.PCF85063A is

   use ESP32S3.I2C;   --  Byte, Byte_Array, Session, Acquire/Write/Read

   ---------------------------------------------------------------------------
   --  Register map (NXP PCF85063A datasheet, Rev. 6, section 8.2).
   ---------------------------------------------------------------------------

   Reg_Control_1    : constant Byte := 16#00#;
   Reg_Control_2    : constant Byte := 16#01#;
   Reg_Seconds      : constant Byte := 16#04#;   --  .. 16#0A# = Years
   Reg_Second_Alarm : constant Byte := 16#0B#;   --  .. 16#0F# = Weekday_Alarm

   --  Control_1 bits.
   Stop_Bit       : constant Byte := 16#20#;   --  1 = time counters halted
   Software_Reset : constant Byte := 16#58#;   --  datasheet reset code

   --  Control_2 bits.
   Alarm_Int_Enable : constant Byte := 16#80#;   --  AIE
   Alarm_Flag       : constant Byte := 16#40#;   --  AF (write 0 to clear)

   --  Seconds register bit 7 = OS (oscillator stopped since last set).
   OS_Flag : constant Byte := 16#80#;

   --  Alarm registers bit 7 = AEN_x: 1 disables that field's match.
   Alarm_Disable : constant Byte := 16#80#;

   ---------------------------------------------------------------------------
   --  BCD <-> binary (the chip stores two packed decimal digits per byte).
   ---------------------------------------------------------------------------

   function To_BCD (V : Natural) return Byte
   is (Byte ((V / 10) * 16 + (V mod 10)));

   function From_BCD (B : Byte) return Natural
   is (Natural (B / 16) * 10 + Natural (B mod 16));

   ---------------------------------------------------------------------------
   --  Register access on an already-acquired Session.  The public operations
   --  open one Session and drive these, so a whole operation (e.g. Set_Time's
   --  stop / write / start) runs as one uninterrupted hold of the host.
   ---------------------------------------------------------------------------

   --  Set the address pointer (1-byte write), then stream Data'Length bytes from
   --  it.  The pointer auto-increments and survives the STOP between the two.
   procedure Read_Regs (S : Session; Reg : Byte; Data : out Byte_Array; Result : out Status) is
      Acked : Boolean;
   begin
      Write (S, Bus_Address, (1 => Reg), Acked);
      if Acked then
         Read (S, Bus_Address, Data, Acked);
      end if;
      Result := (if Acked then OK else Bus_Error);
   end Read_Regs;

   --  Write Reg followed by Data in one transaction (the pointer auto-increments
   --  across the data bytes).
   procedure Write_Regs (S : Session; Reg : Byte; Data : Byte_Array; Result : out Status) is
      Acked : Boolean;
      Buf   : Byte_Array (0 .. Data'Length);
   begin
      Buf (0) := Reg;
      if Data'Length > 0 then
         Buf (1 .. Buf'Last) := Data;
      end if;
      Write (S, Bus_Address, Buf, Acked);
      Result := (if Acked then OK else Bus_Error);
   end Write_Regs;

   --  Read-modify-write one register: keep the bits outside Mask, set the bits
   --  inside Mask to Bits.
   procedure Update_Reg (S : Session; Reg, Mask, Bits : Byte; Result : out Status) is
      Reg_Value : Byte_Array (0 .. 0);
   begin
      Read_Regs (S, Reg, Reg_Value, Result);
      if Result /= OK then
         return;
      end if;
      Reg_Value (0) := (Reg_Value (0) and not Mask) or (Bits and Mask);
      Write_Regs (S, Reg, Reg_Value, Result);
   end Update_Reg;

   --  An alarm register byte: the BCD value, or the "disabled" sentinel.
   function Alarm_Field (Use_It : Boolean; Value : Byte) return Byte
   is (if Use_It then Value else Alarm_Disable);

   -----------
   -- Setup --
   -----------

   procedure Setup
     (Dev      : out Device;
      Sda      : ESP32S3.GPIO.Pin_Id;
      Scl      : ESP32S3.GPIO.Pin_Id;
      Int_Pin  : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Host     : ESP32S3.I2C.I2C_Host := ESP32S3.I2C.I2C0;
      Clock_Hz : Positive := 400_000) is
   begin
      Dev := (Host => Host, Sda => Sda, Scl => Scl, Int_Pin => Int_Pin);
      ESP32S3.I2C.Setup (Host, Clock_Hz => Clock_Hz);
      ESP32S3.I2C.Configure_Pins (Host, Scl => Scl, Sda => Sda);
   end Setup;

   -------------------
   -- Interrupt_Pin --
   -------------------

   function Interrupt_Pin (Dev : Device) return ESP32S3.GPIO.Optional_Pin
   is (Dev.Int_Pin);

   --------------
   -- Get_Time --
   --------------

   procedure Get_Time (Dev : Device; T : out Time; Valid : out Boolean; Result : out Status) is
      S    : Session;              --  released by finalization on return
      Regs : Byte_Array (0 .. 6);  --  Seconds (0x04) .. Years (0x0A)

      --  Decode into UNCONSTRAINED locals first.  A chip that lost power (dead
      --  VBAT) or was never set can hold out-of-range BCD (e.g. an hour byte of
      --  0x30 -> 30) or a 7 in the 3-bit weekday field; assigning those straight
      --  into the constrained Time subtypes would raise Constraint_Error out of
      --  the very routine whose job is to REPORT untrustworthy time, not crash on
      --  it -- and that fires exactly when the time is not valid (power lost).
      --  Se/Mi/Ho/Da/Mo/Yr = Second, Minute, Hour, Day, Month, Year; Wd = weekday.
      Se, Mi, Ho, Da, Mo, Yr : Natural;
      Wd                     : Natural;
   begin
      Valid := False;
      Acquire (S, Dev.Host);
      Read_Regs (S, Reg_Seconds, Regs, Result);
      if Result /= OK then
         return;   --  T keeps its default value

      end if;

      Se := From_BCD (Regs (0) and 16#7F#);
      Mi := From_BCD (Regs (1) and 16#7F#);
      Ho := From_BCD (Regs (2) and 16#3F#);   --  24-hour mode
      Da := From_BCD (Regs (3) and 16#3F#);
      Wd := Natural (Regs (4) and 16#07#);
      Mo := From_BCD (Regs (5) and 16#1F#);
      Yr := 2000 + From_BCD (Regs (6));

      --  Only publish the reading if every field is in range (so the subtype
      --  assignment is safe); otherwise leave T at its defaults.  A bus read
      --  that returns garbage is never trustworthy, so Valid stays False --
      --  Result stays OK because the transaction itself succeeded.
      if Se in Second_Number
        and then Mi in Minute_Number
        and then Ho in Hour_Number
        and then Da in Day_Number
        and then Wd <= Weekday'Pos (Weekday'Last)
        and then Mo in Month_Number
        and then Yr in Year_Number
      then
         T :=
           (Year        => Yr,
            Month       => Mo,
            Day         => Da,
            Day_Of_Week => Weekday'Val (Wd),
            Hour        => Ho,
            Minute      => Mi,
            Second      => Se);
         --  Trust it only if the oscillator never stopped since the last set.
         Valid := (Regs (0) and OS_Flag) = 0;
      end if;
   end Get_Time;

   --------------
   -- Set_Time --
   --------------

   procedure Set_Time (Dev : Device; T : Time; Result : out Status) is
      S    : Session;
      Regs : Byte_Array (0 .. 6);
   begin
      Acquire (S, Dev.Host);

      --  Halt the counters while the registers are loaded (avoids a rollover
      --  landing between byte writes); all three steps share this one session.
      Update_Reg (S, Reg_Control_1, Stop_Bit, Stop_Bit, Result);
      if Result /= OK then
         return;
      end if;

      Regs (0) := To_BCD (T.Second);   --  bit 7 = 0 here clears the OS flag
      Regs (1) := To_BCD (T.Minute);
      Regs (2) := To_BCD (T.Hour);
      Regs (3) := To_BCD (T.Day);
      Regs (4) := Byte (Weekday'Pos (T.Day_Of_Week));
      Regs (5) := To_BCD (T.Month);
      Regs (6) := To_BCD (T.Year - 2000);
      Write_Regs (S, Reg_Seconds, Regs, Result);
      if Result /= OK then
         return;
      end if;

      --  Restart the clock.
      Update_Reg (S, Reg_Control_1, Stop_Bit, 0, Result);
   end Set_Time;

   -----------
   -- Reset --
   -----------

   procedure Reset (Dev : Device; Result : out Status) is
      S : Session;
   begin
      Acquire (S, Dev.Host);
      Write_Regs (S, Reg_Control_1, (1 => Software_Reset), Result);
   end Reset;

   ----------------------------
   -- Stop_Clock/Start_Clock --
   ----------------------------

   procedure Stop_Clock (Dev : Device; Result : out Status) is
      S : Session;
   begin
      Acquire (S, Dev.Host);
      Update_Reg (S, Reg_Control_1, Stop_Bit, Stop_Bit, Result);
   end Stop_Clock;

   procedure Start_Clock (Dev : Device; Result : out Status) is
      S : Session;
   begin
      Acquire (S, Dev.Host);
      Update_Reg (S, Reg_Control_1, Stop_Bit, 0, Result);
   end Start_Clock;

   ---------------
   -- Set_Alarm --
   ---------------

   procedure Set_Alarm (Dev : Device; A : Alarm; Result : out Status) is
      S    : Session;
      Regs : Byte_Array (0 .. 4);   --  Second .. Weekday alarm (0x0B .. 0x0F)
   begin
      Acquire (S, Dev.Host);

      Regs (0) := Alarm_Field (A.Use_Second, To_BCD (A.Second));
      Regs (1) := Alarm_Field (A.Use_Minute, To_BCD (A.Minute));
      Regs (2) := Alarm_Field (A.Use_Hour, To_BCD (A.Hour));
      Regs (3) := Alarm_Field (A.Use_Day, To_BCD (A.Day));
      Regs (4) := Alarm_Field (A.Use_Weekday, Byte (Weekday'Pos (A.Day_Of_Week)));
      Write_Regs (S, Reg_Second_Alarm, Regs, Result);
      if Result /= OK then
         return;
      end if;

      --  Enable the alarm interrupt and clear any stale flag in one write.
      Update_Reg
        (S,
         Reg_Control_2,
         Mask   => Alarm_Int_Enable or Alarm_Flag,
         Bits   => Alarm_Int_Enable,
         Result => Result);
   end Set_Alarm;

   ---------------------
   -- Alarm_Triggered --
   ---------------------

   procedure Alarm_Triggered (Dev : Device; Fired : out Boolean; Result : out Status) is
      S         : Session;
      Reg_Value : Byte_Array (0 .. 0);
   begin
      Fired := False;
      Acquire (S, Dev.Host);
      Read_Regs (S, Reg_Control_2, Reg_Value, Result);
      if Result = OK then
         Fired := (Reg_Value (0) and Alarm_Flag) /= 0;
      end if;
   end Alarm_Triggered;

   -----------------------
   -- Acknowledge_Alarm --
   -----------------------

   procedure Acknowledge_Alarm (Dev : Device; Result : out Status) is
      S : Session;
   begin
      Acquire (S, Dev.Host);
      Update_Reg (S, Reg_Control_2, Mask => Alarm_Flag, Bits => 0, Result => Result);
   end Acknowledge_Alarm;

   -----------------
   -- Clear_Alarm --
   -----------------

   procedure Clear_Alarm (Dev : Device; Result : out Status) is
      S : Session;
   begin
      Acquire (S, Dev.Host);

      --  Disable the interrupt and clear the flag ...
      Update_Reg
        (S, Reg_Control_2, Mask => Alarm_Int_Enable or Alarm_Flag, Bits => 0, Result => Result);
      if Result /= OK then
         return;
      end if;
      --  ... then disable every match field.
      Write_Regs
        (S,
         Reg_Second_Alarm,
         (Alarm_Disable, Alarm_Disable, Alarm_Disable, Alarm_Disable, Alarm_Disable),
         Result);
   end Clear_Alarm;

end ESP32S3.PCF85063A;
