with Ada.Real_Time; use Ada.Real_Time;

package body ESP32S3.ES8311 is

   use type ESP32S3.I2C.Byte;
   subtype Byte is ESP32S3.I2C.Byte;

   --  Configuration captured by Setup (single-threaded), used by Set_Volume and
   --  the Output session.
   Cfg_I2C   : ESP32S3.I2C.I2C_Host;
   Cfg_Port  : ESP32S3.I2S.I2S_Port;
   Cfg_Addr  : Address := Default_Address;
   Cfg_Ready : Boolean := False;

   --  DAC volume register value for a 0..100 % level (ref: vol*256/100 - 1).
   function Vol_Reg (Percent : Natural) return Byte is
     (if Percent = 0 then 0
      else Byte (Integer'Min (255, (Integer'Min (100, Percent) * 256) / 100 - 1)));

   ---------------------------------------------------------------------------
   --  Small I2C register helpers (all carry an Ok accumulator so a failed ACK
   --  aborts the rest of the sequence).
   ---------------------------------------------------------------------------

   procedure Write_Reg (S : ESP32S3.I2C.Session; Reg, Val : Byte;
                        Ok : in out Boolean) is
      Success : Boolean;
   begin
      if Ok then
         ESP32S3.I2C.Write (S, Cfg_Addr, (Reg, Val), Success);
         Ok := Success;
      end if;
   end Write_Reg;

   procedure Read_Reg (S : ESP32S3.I2C.Session; Reg : Byte; Val : out Byte;
                       Ok : in out Boolean) is
      D       : ESP32S3.I2C.Byte_Array (0 .. 0);
      Success : Boolean;
   begin
      Val := 0;
      if Ok then
         ESP32S3.I2C.Write (S, Cfg_Addr, (0 => Reg), Success);  --  set reg pointer
         if Success then
            ESP32S3.I2C.Read (S, Cfg_Addr, D, Success);
            Val := D (0);
         end if;
         Ok := Success;
      end if;
   end Read_Reg;

   --  Read-modify-write: new = (old and Keep) or Bits.
   procedure Modify_Reg (S : ESP32S3.I2C.Session; Reg, Keep, Bits : Byte;
                         Ok : in out Boolean) is
      Cur : Byte;
   begin
      Read_Reg (S, Reg, Cur, Ok);
      Write_Reg (S, Reg, (Cur and Keep) or Bits, Ok);
   end Modify_Reg;

   -----------
   -- Setup --
   -----------

   procedure Setup
     (I2C_Bus      : ESP32S3.I2C.I2C_Host;
      Sda          : ESP32S3.GPIO.Pin_Id;
      Scl          : ESP32S3.GPIO.Pin_Id;
      Port         : ESP32S3.I2S.I2S_Port;
      Mclk         : ESP32S3.GPIO.Pin_Id;
      Sclk         : ESP32S3.GPIO.Pin_Id;
      Lrck         : ESP32S3.GPIO.Pin_Id;
      Dsdin        : ESP32S3.GPIO.Pin_Id;
      Asdout       : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Sample_Rate  : Positive := 16_000;
      Volume       : Natural  := 70;
      Mic_Gain_Db  : Natural  := 24;
      I2C_Clock_Hz : Positive := 100_000;
      Addr         : Address  := Default_Address;
      Ok           : out Boolean)
   is
      use ESP32S3.GPIO;
      use type ESP32S3.GPIO.Pad_Number;
      Capture_In : constant Boolean := Asdout /= ESP32S3.GPIO.No_Pin;
      --  ADC PGA gain register (reg 0x16) = gain in 6 dB steps, 0 .. 7.
      Mic_Step   : constant Byte :=
        Byte (Natural'Min (7, Mic_Gain_Db / 6));
   begin
      Cfg_I2C  := I2C_Bus;
      Cfg_Port := Port;
      Cfg_Addr := Addr;
      Cfg_Ready := False;

      --  0. Bring up the I2C control bus.
      ESP32S3.I2C.Setup (I2C_Bus, Clock_Hz => I2C_Clock_Hz);
      ESP32S3.I2C.Configure_Pins (I2C_Bus, Scl => Scl, Sda => Sda);

      --  1. I2S master first, so MCLK (= 256 x Sample_Rate, 16-bit stereo) is
      --     running on the codec's MCLK pin before the codec's clock state
      --     machine comes up.  TX-only: route MCLK/SCLK(BCLK)/LRCK(WS)/DSDIN
      --     (Dout); the codec's ASDOUT (our Din) is unused for output.
      ESP32S3.I2S.Setup (Port, Sample_Rate => Sample_Rate,
                         Bits => ESP32S3.I2S.Bits_16,
                         Mode => ESP32S3.I2S.Standard);
      ESP32S3.I2S.Configure_Pins
        (Port,
         Bclk => Optional_Pin (Sclk),
         Ws   => Optional_Pin (Lrck),
         Dout => Optional_Pin (Dsdin),
         Din  => (if Capture_In then Asdout else ESP32S3.GPIO.No_Pin),
         Mclk => Optional_Pin (Mclk));

      --  2. I2C control: run the codec register-init sequence.
      Ok := True;
      declare
         S : ESP32S3.I2C.Session;
      begin
         ESP32S3.I2C.Acquire (S, I2C_Bus);

         --  Reset, then power on the chip state machine (slave mode).
         Write_Reg (S, 16#00#, 16#1F#, Ok);
         delay until Clock + Milliseconds (20);
         Write_Reg (S, 16#00#, 16#00#, Ok);
         Write_Reg (S, 16#00#, 16#80#, Ok);

         --  Clock manager: enable the clock paths, MCLK from the MCLK pin
         --  (bit 7 = 0).  Then the sample-frequency coefficients for MCLK =
         --  256 x fs, 16-bit (rate-independent divider values).
         Write_Reg (S, 16#01#, 16#3F#, Ok);
         Modify_Reg (S, 16#02#, Keep => 16#07#, Bits => 16#00#, Ok => Ok);  --  pre_div 1, pre_multi 1
         Write_Reg (S, 16#03#, 16#10#, Ok);                                 --  fs_mode 0, adc_osr 0x10
         Write_Reg (S, 16#04#, 16#10#, Ok);                                 --  dac_osr 0x10
         Write_Reg (S, 16#05#, 16#00#, Ok);                                 --  adc_div/dac_div 1
         Modify_Reg (S, 16#06#, Keep => 16#E0#, Bits => 16#03#, Ok => Ok);  --  bclk_div 4 -> 4-1
         Modify_Reg (S, 16#07#, Keep => 16#C0#, Bits => 16#00#, Ok => Ok);  --  lrck_h
         Write_Reg (S, 16#08#, 16#FF#, Ok);                                 --  lrck_l

         --  Serial data port: 16-bit I2S (Philips), in and out.
         Write_Reg (S, 16#09#, 16#0C#, Ok);
         Write_Reg (S, 16#0A#, 16#0C#, Ok);

         --  Power up the analog + DAC path and the output (HP) driver.
         Write_Reg (S, 16#0D#, 16#01#, Ok);
         Write_Reg (S, 16#0E#, 16#02#, Ok);
         Write_Reg (S, 16#12#, 16#00#, Ok);
         Write_Reg (S, 16#13#, 16#10#, Ok);
         Write_Reg (S, 16#1C#, 16#6A#, Ok);   --  ADC settings (harmless for TX-only)
         Write_Reg (S, 16#37#, 16#08#, Ok);   --  bypass DAC equalizer

         --  DAC volume.
         Write_Reg (S, 16#32#, Vol_Reg (Volume), Ok);

         --  ADC / microphone path (only when an Asdout pin was given).  The
         --  analog power (REG0D/0E), ADC settings (REG1C) and the ADC serial-out
         --  format (REG0A) are already set above; here we enable the analog mic
         --  input + PGA and set the ADC gain.
         if Capture_In then
            Write_Reg (S, 16#14#, 16#1A#, Ok);      --  analog MIC on + PGA
            Write_Reg (S, 16#16#, Mic_Step, Ok);    --  ADC PGA gain (6 dB steps)
            Write_Reg (S, 16#17#, 16#C8#, Ok);      --  ADC volume
         end if;

         ESP32S3.I2C.Release (S);
      end;

      Cfg_Ready := Ok;
   end Setup;

   ----------------
   -- Set_Volume --
   ----------------

   procedure Set_Volume (Percent : Natural; Ok : out Boolean) is
      S : ESP32S3.I2C.Session;
   begin
      Ok := Cfg_Ready;
      if not Cfg_Ready then
         return;
      end if;
      ESP32S3.I2C.Acquire (S, Cfg_I2C);
      Write_Reg (S, 16#32#, Vol_Reg (Percent), Ok);
      ESP32S3.I2C.Release (S);
   end Set_Volume;

   -------------
   -- Acquire --
   -------------

   procedure Acquire (O : in out Output) is
   begin
      if not Cfg_Ready then
         raise Not_Ready with "ES8311.Setup not run";
      end if;
      ESP32S3.I2S.Acquire (O.Audio, Cfg_Port);
   end Acquire;

   ----------
   -- Play --
   ----------

   procedure Play (O : Output; Samples : System.Address; Length : Natural) is
   begin
      ESP32S3.I2S.Write (O.Audio, Samples, Length);
   end Play;

   ---------------------
   -- Play_Continuous --
   ---------------------

   procedure Play_Continuous (O : Output; Samples : System.Address;
                              Length : Natural) is
   begin
      ESP32S3.I2S.Start_Continuous (O.Audio, Samples, Length);
   end Play_Continuous;

   ----------
   -- Stop --
   ----------

   procedure Stop (O : Output) is
   begin
      ESP32S3.I2S.Stop (O.Audio);
   end Stop;

   -------------
   -- Capture --
   -------------

   procedure Capture (O : Output; Samples : System.Address; Length : Natural) is
   begin
      ESP32S3.I2S.Capture (O.Audio, Samples, Length);
   end Capture;

   -------------
   -- Release --
   -------------

   procedure Release (O : in out Output) is
   begin
      ESP32S3.I2S.Release (O.Audio);
   end Release;

end ESP32S3.ES8311;
