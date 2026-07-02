with Interfaces;                 use Interfaces;
with ESP32S3.GPIO;
with ESP32S3_Registers;          use ESP32S3_Registers;
with ESP32S3_Registers.RTC_CNTL; use ESP32S3_Registers.RTC_CNTL;
with ESP32S3_Registers.SENS;     use ESP32S3_Registers.SENS;
with ESP32S3_Registers.RTC_IO;

package body ESP32S3.Touch is

   function Pad (Ch : Channel) return ESP32S3.GPIO.Pin_Id
   is (ESP32S3.GPIO.Pin_Id (Natural (Ch)));

   --  Per-channel raw counts: SAR_TOUCH_STATUS1 .. 14 are consecutive (stride 4).
   type Status_Array is array (Channel) of UInt32 with Volatile;
   Status : Status_Array
   with Volatile, Import, Address => SENS_Periph.SAR_TOUCH_STATUS1'Address;

   --  The per-pad RTC_IO config registers (GPIO n at TOUCH_PAD0 + 4*n).
   type Pad_Array is array (Natural range 0 .. 21) of UInt32 with Volatile;
   Pads : Pad_Array
   with
     Volatile,
     Import,
     Address => ESP32S3_Registers.RTC_IO.RTC_IO_Periph.TOUCH_PAD0'Address;

   --  Charge/discharge slope (DAC) -- 3 bits per pad, pad n at bit 29 - 3*n in
   --  TOUCH_DAC (pads 0..9) or TOUCH_DAC1 (pads 10..14).  MUST be non-zero or the
   --  counter stays at 0.
   Touch_DAC  : UInt32
   with Volatile, Import, Address => RTC_CNTL_Periph.TOUCH_DAC'Address;
   Touch_DAC1 : UInt32
   with Volatile, Import, Address => RTC_CNTL_Periph.TOUCH_DAC1'Address;

   Mux_Sel : constant UInt32 := 2**19;
   Fun_IE  : constant UInt32 := 2**13;
   Pulls   : constant UInt32 := 2**27 or 2**28;

   -----------
   -- Setup --
   -----------

   procedure Setup is
   begin
      --  Charge/discharge voltage + measurement timing; enable bias + clock.
      RTC_CNTL_Periph.TOUCH_CTRL1 :=
        (TOUCH_MEAS_NUM     => 16#1000#,
         TOUCH_SLEEP_CYCLES => 16#100#,
         others             => <>);
      RTC_CNTL_Periph.TOUCH_CTRL2 :=
        (TOUCH_DREFH        => 3,
         TOUCH_DREFL        => 0,
         TOUCH_DRANGE       => 3,
         TOUCH_XPD_WAIT     => 16#FF#,
         TOUCH_XPD_BIAS     => True,
         TOUCH_START_FSM_EN => True,
         TOUCH_START_FORCE  => False,
         --  timer mode
         TOUCH_CLKGATE_EN   => True,
         others             => <>);

      --  Reset the FSM, clear all channel benchmarks, then start the scan timer.
      RTC_CNTL_Periph.TOUCH_CTRL2.TOUCH_RESET := False;
      RTC_CNTL_Periph.TOUCH_CTRL2.TOUCH_RESET := True;
      SENS_Periph.SAR_TOUCH_CHN_ST.SAR_TOUCH_CHANNEL_CLR :=
        2#111_1111_1111_1111#;
      RTC_CNTL_Periph.TOUCH_CTRL2.TOUCH_TIMER_FORCE_DONE := 3;
      RTC_CNTL_Periph.TOUCH_CTRL2.TOUCH_TIMER_FORCE_DONE := 0;
      RTC_CNTL_Periph.TOUCH_CTRL2.TOUCH_SLP_TIMER_EN := True;
   end Setup;

   ------------
   -- Enable --
   ------------

   procedure Enable (Ch : Channel) is
      N     : constant Natural := Natural (Ch);
      Slope : constant := 7;            --  fastest charge slope
   begin
      --  Charge slope for this pad (3 bits at 29 - 3*n).
      if N < 10 then
         declare
            Shift : constant Natural := 29 - 3 * N;
         begin
            Touch_DAC :=
              (Touch_DAC and not Shift_Left (UInt32 (7), Shift))
              or Shift_Left (UInt32 (Slope), Shift);
         end;
      else
         declare
            Shift : constant Natural := 29 - 3 * (N - 10);
         begin
            Touch_DAC1 :=
              (Touch_DAC1 and not Shift_Left (UInt32 (7), Shift))
              or Shift_Left (UInt32 (Slope), Shift);
         end;
      end if;

      --  Route the pad into the RTC/touch domain (no digital input, no pulls).
      Pads (N) := (Pads (N) or Mux_Sel) and not (Fun_IE or Pulls);

      --  Add the channel to the scan set.
      RTC_CNTL_Periph.TOUCH_SCAN_CTRL.TOUCH_SCAN_PAD_MAP :=
        TOUCH_SCAN_CTRL_TOUCH_SCAN_PAD_MAP_Field
          (UInt32 (RTC_CNTL_Periph.TOUCH_SCAN_CTRL.TOUCH_SCAN_PAD_MAP)
           or Shift_Left (UInt32 (1), N));
      SENS_Periph.SAR_TOUCH_CONF.SAR_TOUCH_OUTEN :=
        SAR_TOUCH_CONF_SAR_TOUCH_OUTEN_Field
          (UInt32 (SENS_Periph.SAR_TOUCH_CONF.SAR_TOUCH_OUTEN)
           or Shift_Left (UInt32 (1), N));
   end Enable;

   ----------
   -- Read --
   ----------

   function Read (Ch : Channel) return Natural is
   begin
      SENS_Periph.SAR_TOUCH_CONF.SAR_TOUCH_DATA_SEL := 0;    --  raw count
      return Natural (Status (Ch) and 16#3F_FFFF#);           --  22-bit count
   end Read;

   -------------
   -- Touched --
   -------------

   function Touched
     (Ch : Channel; Reference : Natural; Margin : Natural := 20_000)
      return Boolean
   is
      Now : constant Natural := Read (Ch);
   begin
      return abs (Now - Reference) > Margin;
   end Touched;

end ESP32S3.Touch;
