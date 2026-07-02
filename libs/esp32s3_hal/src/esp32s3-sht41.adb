with Ada.Real_Time; use Ada.Real_Time;
with Interfaces;    use Interfaces;

package body ESP32S3.SHT41 is

   use ESP32S3.I2C;   --  Byte, Byte_Array, Session, Slave_Address, Acquire/Write/Read

   subtype LLI is Long_Long_Integer;

   ---------------------------------------------------------------------------
   --  Commands (Sensirion SHT4x datasheet) and their conversion times.
   ---------------------------------------------------------------------------

   Cmd_Measure_High : constant Byte := 16#FD#;
   Cmd_Measure_Med  : constant Byte := 16#F6#;
   Cmd_Measure_Low  : constant Byte := 16#E0#;
   Cmd_Serial       : constant Byte := 16#89#;
   Cmd_Reset        : constant Byte := 16#94#;

   ---------------------------------------------------------------------------
   --  CRC-8 (polynomial 0x31, init 0xFF) over the two data bytes of a word.
   ---------------------------------------------------------------------------

   function CRC8 (Hi, Lo : Byte) return Byte is
      Crc : Unsigned_8 := 16#FF#;

      procedure Add (Data_Byte : Unsigned_8) is
      begin
         Crc := Crc xor Data_Byte;
         for I in 1 .. 8 loop
            if (Crc and 16#80#) /= 0 then
               Crc := Shift_Left (Crc, 1) xor 16#31#;
            else
               Crc := Shift_Left (Crc, 1);
            end if;
         end loop;
      end Add;

   begin
      Add (Unsigned_8 (Hi));
      Add (Unsigned_8 (Lo));
      return Byte (Crc);
   end CRC8;

   ---------------------------------------------------------------------------
   --  Conversions (datasheet: T = -45 + 175*S/65535 ; RH = -6 + 125*S/65535).
   ---------------------------------------------------------------------------

   function Ticks (Hi, Lo : Byte) return LLI
   is (LLI (Hi) * 256 + LLI (Lo));

   function To_Temp_MC (Hi, Lo : Byte) return Integer
   is (Integer (-45_000 + (175_000 * Ticks (Hi, Lo)) / 65_535));

   function To_Hum_MRH (Hi, Lo : Byte) return Integer is
      Milli_RH : LLI := -6_000 + (125_000 * Ticks (Hi, Lo)) / 65_535;
   begin
      if Milli_RH < 0 then
         Milli_RH := 0;
      elsif Milli_RH > 100_000 then
         Milli_RH := 100_000;
      end if;
      return Integer (Milli_RH);
   end To_Hum_MRH;

   ---------------------------------------------------------------------------
   --  Command + wait + read, holding the bus across the whole exchange.  Reads
   --  Data'Length bytes (a multiple of 3: 16-bit words each followed by a CRC).
   ---------------------------------------------------------------------------

   procedure Transact
     (Dev : Device; Cmd : Byte; Wait : Time_Span; Data : out Byte_Array; Result : out Status)
   is
      S     : Session;
      Acked : Boolean;
   begin
      Acquire (S, Dev.Host);
      Write (S, Dev.Address, (1 => Cmd), Acked);
      if not Acked then
         Result := Bus_Error;
         return;
      end if;
      delay until Clock + Wait;                 --  conversion time
      Read (S, Dev.Address, Data, Acked);
      Result := (if Acked then OK else Bus_Error);
   end Transact;

   --  True iff every 3-byte (word + CRC) group in Data checks out.
   function CRC_Good (Data : Byte_Array) return Boolean is
      I : Natural := Data'First;
   begin
      while I + 2 <= Data'Last loop
         if CRC8 (Data (I), Data (I + 1)) /= Data (I + 2) then
            return False;
         end if;
         I := I + 3;
      end loop;
      return True;
   end CRC_Good;

   -----------
   -- Setup --
   -----------

   procedure Setup
     (Dev      : out Device;
      Sda      : ESP32S3.GPIO.Pin_Id;
      Scl      : ESP32S3.GPIO.Pin_Id;
      Address  : ESP32S3.I2C.Slave_Address := Default_Address;
      Host     : ESP32S3.I2C.I2C_Host := ESP32S3.I2C.I2C0;
      Clock_Hz : Positive := 400_000) is
   begin
      Dev := (Host => Host, Address => Address);
      ESP32S3.I2C.Setup (Host, Clock_Hz => Clock_Hz);
      ESP32S3.I2C.Configure_Pins (Host, Scl => Scl, Sda => Sda);
   end Setup;

   -------------
   -- Measure --
   -------------

   procedure Measure
     (Dev           : Device;
      Value         : out Measurement;
      Result        : out Status;
      Repeatability : Precision := High)
   is
      Cmd   : constant Byte :=
        (case Repeatability is
           when High   => Cmd_Measure_High,
           when Medium => Cmd_Measure_Med,
           when Low    => Cmd_Measure_Low);
      Wait  : constant Time_Span :=
        (case Repeatability is
           when High   => Milliseconds (10),
           when Medium => Milliseconds (5),
           when Low    => Milliseconds (2));
      Reply : Byte_Array (0 .. 5);   --  T_hi T_lo T_crc  RH_hi RH_lo RH_crc
   begin
      Value := (others => <>);
      Transact (Dev, Cmd, Wait, Reply, Result);
      if Result /= OK then
         return;
      end if;
      if not CRC_Good (Reply) then
         Result := CRC_Error;
         return;
      end if;
      Value.Temperature := To_Temp_MC (Reply (0), Reply (1));
      Value.Humidity := To_Hum_MRH (Reply (3), Reply (4));
   end Measure;

   ------------------------
   -- Read_Serial_Number --
   ------------------------

   procedure Read_Serial_Number
     (Dev : Device; Serial : out Interfaces.Unsigned_32; Result : out Status)
   is
      R : Byte_Array (0 .. 5);
   begin
      Serial := 0;
      Transact (Dev, Cmd_Serial, Milliseconds (1), R, Result);
      if Result /= OK then
         return;
      end if;
      if not CRC_Good (R) then
         Result := CRC_Error;
         return;
      end if;
      Serial :=
        Unsigned_32 (R (0))
        * 2**24
        + Unsigned_32 (R (1)) * 2**16
        + Unsigned_32 (R (3)) * 2**8
        + Unsigned_32 (R (4));
   end Read_Serial_Number;

   -----------
   -- Reset --
   -----------

   procedure Reset (Dev : Device; Result : out Status) is
      S     : Session;
      Acked : Boolean;
   begin
      Acquire (S, Dev.Host);
      Write (S, Dev.Address, (1 => Cmd_Reset), Acked);
      delay until Clock + Milliseconds (1);     --  soft-reset settle time
      Result := (if Acked then OK else Bus_Error);
   end Reset;

end ESP32S3.SHT41;
