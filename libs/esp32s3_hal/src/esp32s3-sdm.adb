with ESP32S3.GPIO;
with ESP32S3.GPIO_Signals;
with ESP32S3_Registers;          use ESP32S3_Registers;
with ESP32S3_Registers.GPIOSD;   use ESP32S3_Registers.GPIOSD;
with ESP32S3_Registers.GPIO;

package body ESP32S3.SDM is

   package GR renames ESP32S3_Registers.GPIO;
   package G    renames ESP32S3.GPIO;
   package Sigs renames ESP32S3.GPIO_Signals;

   --  Output matrix signal for a channel (GPIO_SD0_OUT .. SD7_OUT).
   function Out_Signal (Idx : Channel_Index) return Natural is
     (Sigs.GPIO_SD0_OUT + Natural (Idx));

   procedure Drive_Out (Pin : G.Pin_Id; Sig : Natural) is
      O : GR.FUNC_OUT_SEL_CFG_Register :=
            GR.GPIO_Periph.FUNC_OUT_SEL_CFG (Natural (Pin));
   begin
      G.Configure (Pin, Mode => G.Output, Drive => G.Drive_Strong);
      O.OUT_SEL := GR.FUNC_OUT_SEL_CFG_OUT_SEL_Field (Sig);
      O.OEN_SEL := False;
      GR.GPIO_Periph.FUNC_OUT_SEL_CFG (Natural (Pin)) := O;
   end Drive_Out;

   --  Density 0..100 % -> the signed 8-bit SD_IN value, as a raw byte.  Density =
   --  (SD_IN + 128) / 256, so SD_IN = round(density*256) - 128, clamped -128..127.
   function Duty_Byte (Percent : Density_Percent) return Byte is
      S : Integer := Integer (Float (Percent) / 100.0 * 256.0) - 128;
   begin
      if S < -128 then
         S := -128;
      elsif S > 127 then
         S := 127;
      end if;
      return Byte (S mod 256);
   end Duty_Byte;

   --------------------------------------------------------------------------
   --  Channel-ownership pool (brings the modulator clock up once).
   --------------------------------------------------------------------------

   type Use_Map is array (Channel_Index) of Boolean;

   protected Pool is
      procedure Claim (Index : Channel_Index; Ok : out Boolean);
      procedure Release (Index : Channel_Index);
   private
      In_Use : Use_Map := (others => False);
      Inited : Boolean := False;
   end Pool;

   protected body Pool is
      procedure Claim (Index : Channel_Index; Ok : out Boolean) is
      begin
         if not Inited then
            GPIO_SD_Periph.SIGMADELTA_CG.CLK_EN          := True;
            GPIO_SD_Periph.SIGMADELTA_MISC.FUNCTION_CLK_EN := True;
            Inited := True;
         end if;
         Ok := not In_Use (Index);
         if Ok then
            In_Use (Index) := True;
         end if;
      end Claim;

      procedure Release (Index : Channel_Index) is
      begin
         In_Use (Index) := False;
      end Release;
   end Pool;

   -----------
   -- Claim --
   -----------

   procedure Claim (C : in out Channel; Index : Channel_Index) is
      Ok : Boolean;
   begin
      Release (C);
      Pool.Claim (Index, Ok);
      if Ok then
         C.Idx := Index;  C.Held := True;
      end if;
   end Claim;

   function Is_Valid (C : Channel) return Boolean is (C.Held);

   procedure Release (C : in out Channel) is
   begin
      if C.Held then
         GPIO_SD_Periph.SIGMADELTA (Integer (C.Idx)).SD_IN := 128;  --  0% (output low)
         Pool.Release (C.Idx);
         C.Held := False;
      end if;
   end Release;

   overriding procedure Finalize (C : in out Channel) is
   begin
      Release (C);
   end Finalize;

   ---------------
   -- Configure --
   ---------------

   procedure Configure (C          : in out Channel;
                        Pin        : ESP32S3.GPIO.Pin_Id;
                        Carrier_Hz : Positive := 1_000_000) is
      APB_Hz : constant := 80_000_000;                      --  modulator source clock
      --  Nearest integer divider N in 1 .. 256 for the requested carrier; the
      --  register field holds N-1 (the hardware divides APB by field+1).
      Div    : constant Natural :=
        Natural'Max (1, Natural'Min (256, (APB_Hz + Carrier_Hz / 2) / Carrier_Hz));
   begin
      if not C.Held then
         return;
      end if;
      GPIO_SD_Periph.SIGMADELTA (Integer (C.Idx)) :=
        (SD_IN       => 128,                                  --  0 % (= -128 signed)
         SD_PRESCALE => SIGMADELTA_SD_PRESCALE_Field (Div - 1),
         others => <>);
      Drive_Out (Pin, Out_Signal (C.Idx));
   end Configure;

   -----------------
   -- Set_Density --
   -----------------

   procedure Set_Density (C : Channel; Percent : Density_Percent) is
   begin
      if C.Held then
         GPIO_SD_Periph.SIGMADELTA (Integer (C.Idx)).SD_IN := Duty_Byte (Percent);
      end if;
   end Set_Density;

end ESP32S3.SDM;
