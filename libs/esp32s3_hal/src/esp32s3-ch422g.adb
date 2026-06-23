package body ESP32S3.CH422G is

   use type ESP32S3.I2C.Byte;

   --  Fixed command addresses (7-bit; the chip's "byte 1" with the R/W bit
   --  shifted out): WR-SET 0x48->0x24, WR-OC 0x46->0x23, WR-IO 0x70->0x38,
   --  RD-IO 0x4D->0x26.
   Addr_Set : constant ESP32S3.I2C.Slave_Address := 16#24#;
   Addr_OC  : constant ESP32S3.I2C.Slave_Address := 16#23#;
   Addr_IO  : constant ESP32S3.I2C.Slave_Address := 16#38#;
   Addr_RD  : constant ESP32S3.I2C.Slave_Address := 16#26#;

   --  Config byte bits: [SLEEP]00[OD_EN]0[A_SCAN]0[IO_OE].
   Bit_IO_OE : constant ESP32S3.I2C.Byte := 16#01#;   --  1 = IO0..7 outputs
   Bit_OD_EN : constant ESP32S3.I2C.Byte := 16#10#;   --  1 = OC open-drain
   Bit_SLEEP : constant ESP32S3.I2C.Byte := 16#80#;
   --  (A_SCAN bit 0x04 held 0 -> I/O-expansion mode, not LED scan.)

   --  Per-device guard keyed by host (one CH422G per bus) -- no protected object
   --  in a Device.  Same shape as ESP32S3.I2C's guards.
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

   Guards : array (ESP32S3.I2C.I2C_Host) of Device_Guard;

   --  WR-SET / WR-OC / WR-IO are write-only, so shadow them (power-on defaults:
   --  IO inputs => Cfg 0, IO outputs 0, OC high => 0x0F).
   type Shadow is record
      Cfg    : ESP32S3.I2C.Byte := 0;
      IO_Out : ESP32S3.I2C.Byte := 0;
      OC_Out : ESP32S3.I2C.Byte := 16#0F#;
   end record;
   Shadows : array (ESP32S3.I2C.I2C_Host) of Shadow;

   procedure Check_Owned (S : Session) is
   begin
      if not S.Active then
         raise Not_Owned with "CH422G used without holding it -- Acquire first";
      end if;
   end Check_Owned;

   --  One-byte write to a command address, opening a SHORT-LIVED I2C Session
   --  (the host lock) that is released when Bus finalises at scope exit.
   procedure Cmd
     (S : Session; Addr : ESP32S3.I2C.Slave_Address;
      Value : ESP32S3.I2C.Byte; Result : out Status)
   is
      Bus   : ESP32S3.I2C.Session;
      Acked : Boolean;
   begin
      Check_Owned (S);
      ESP32S3.I2C.Acquire (Bus, S.Host);
      ESP32S3.I2C.Write (Bus, Addr, (1 => Value), Acked);
      Result := (if Acked then OK else Bus_Error);
   end Cmd;

   -----------
   -- Setup --
   -----------

   procedure Setup
     (Dev      : out Device;
      Sda      : ESP32S3.GPIO.Pin_Id;
      Scl      : ESP32S3.GPIO.Pin_Id;
      Host     : ESP32S3.I2C.I2C_Host := ESP32S3.I2C.I2C0;
      Clock_Hz : Positive             := 400_000) is
   begin
      Dev := (Host => Host, Configured => True);
      ESP32S3.I2C.Setup (Host, Clock_Hz => Clock_Hz);
      ESP32S3.I2C.Configure_Pins (Host, Scl => Scl, Sda => Sda);
      Shadows (Host) := (Cfg => 0, IO_Out => 0, OC_Out => 16#0F#);  --  power-on
   end Setup;

   -------------------------
   -- Acquire / Release   --
   -------------------------

   procedure Acquire (S : in out Session; Dev : Device) is
   begin
      if not Dev.Configured then
         raise Not_Initialized with "CH422G Setup not called";
      end if;
      Guards (Dev.Host).Acquire;   --  suspends until the chip is free
      S.Active := True;
      S.Host   := Dev.Host;
   end Acquire;

   procedure Release (S : in out Session) is
   begin
      if S.Active then
         S.Active := False;
         Guards (S.Host).Release;
      end if;
   end Release;

   overriding procedure Finalize (S : in out Session) is
   begin
      Release (S);
   end Finalize;

   -------------
   -- Present --
   -------------

   function Present (S : Session) return Boolean is
      Bus   : ESP32S3.I2C.Session;
      Acked : Boolean;
      Empty : constant ESP32S3.I2C.Byte_Array (1 .. 0) := (others => 0);
   begin
      Check_Owned (S);
      ESP32S3.I2C.Acquire (Bus, S.Host);
      ESP32S3.I2C.Write (Bus, Addr_Set, Empty, Acked);  --  address-only probe
      return Acked;
   end Present;

   ---------------
   -- Configure --
   ---------------

   procedure Configure
     (S       : Session;
      IO_Dir  : IO_Direction := Inputs;
      OC_Mode : OC_Drive     := Push_Pull;
      Result  : out Status)
   is
      Cfg : ESP32S3.I2C.Byte;
   begin
      Check_Owned (S);
      Cfg := Shadows (S.Host).Cfg and Bit_SLEEP;        --  keep only SLEEP
      if IO_Dir = Outputs then
         Cfg := Cfg or Bit_IO_OE;
      end if;
      if OC_Mode = Open_Drain then
         Cfg := Cfg or Bit_OD_EN;
      end if;
      Shadows (S.Host).Cfg := Cfg;
      Cmd (S, Addr_Set, Cfg, Result);
   end Configure;

   -----------
   -- Sleep --
   -----------

   procedure Sleep (S : Session; On : Boolean; Result : out Status) is
      Cfg : ESP32S3.I2C.Byte;
   begin
      Check_Owned (S);
      if On then
         Cfg := Shadows (S.Host).Cfg or Bit_SLEEP;
      else
         Cfg := Shadows (S.Host).Cfg and (not Bit_SLEEP);
      end if;
      Shadows (S.Host).Cfg := Cfg;
      Cmd (S, Addr_Set, Cfg, Result);
   end Sleep;

   --------------
   -- Write_IO --
   --------------

   procedure Write_IO (S : Session; Value : IO_Value; Result : out Status) is
   begin
      Check_Owned (S);
      Shadows (S.Host).IO_Out := ESP32S3.I2C.Byte (Value);
      Cmd (S, Addr_IO, ESP32S3.I2C.Byte (Value), Result);
   end Write_IO;

   procedure Write_IO_Pin
     (S : Session; Pin : IO_Pin; State : Pin_State; Result : out Status)
   is
      M : constant ESP32S3.I2C.Byte := 2 ** Natural (Pin);
      B : ESP32S3.I2C.Byte;
   begin
      Check_Owned (S);
      B := Shadows (S.Host).IO_Out;
      if State = High then
         B := B or M;
      else
         B := B and (not M);
      end if;
      Shadows (S.Host).IO_Out := B;
      Cmd (S, Addr_IO, B, Result);
   end Write_IO_Pin;

   -------------
   -- Read_IO --
   -------------

   procedure Read_IO (S : Session; Value : out IO_Value; Result : out Status) is
      Bus   : ESP32S3.I2C.Session;
      Data  : ESP32S3.I2C.Byte_Array (1 .. 1);
      Acked : Boolean;
   begin
      Check_Owned (S);
      Value := 0;
      ESP32S3.I2C.Acquire (Bus, S.Host);
      ESP32S3.I2C.Read (Bus, Addr_RD, Data, Acked);
      if Acked then
         Value  := IO_Value (Data (1));
         Result := OK;
      else
         Result := Bus_Error;
      end if;
   end Read_IO;

   procedure Read_IO_Pin
     (S : Session; Pin : IO_Pin; State : out Pin_State; Result : out Status)
   is
      V : IO_Value;
   begin
      Read_IO (S, V, Result);
      State := (if (V and IO_Value (2 ** Natural (Pin))) /= 0 then High else Low);
   end Read_IO_Pin;

   --------------
   -- Write_OC --
   --------------

   procedure Write_OC (S : Session; Value : OC_Value; Result : out Status) is
   begin
      Check_Owned (S);
      Shadows (S.Host).OC_Out := ESP32S3.I2C.Byte (Value);
      Cmd (S, Addr_OC, ESP32S3.I2C.Byte (Value), Result);
   end Write_OC;

   procedure Write_OC_Pin
     (S : Session; Pin : OC_Pin; State : Pin_State; Result : out Status)
   is
      M : constant ESP32S3.I2C.Byte := 2 ** Natural (Pin);
      B : ESP32S3.I2C.Byte;
   begin
      Check_Owned (S);
      B := Shadows (S.Host).OC_Out;
      if State = High then
         B := B or M;
      else
         B := B and (not M);
      end if;
      B := B and 16#0F#;          --  only OC0..OC3
      Shadows (S.Host).OC_Out := B;
      Cmd (S, Addr_OC, B, Result);
   end Write_OC_Pin;

end ESP32S3.CH422G;
