with ESP32S3_Registers.RNG;
with ESP32S3_Registers.RTC_CNTL;
with ESP32S3_Registers.SYSTEM;
with ESP32S3_Registers.APB_SARADC;
with ESP32S3_Registers.SENS;

package body ESP32S3.RNG is

   function Read return Word is
   begin
      return ESP32S3_Registers.RNG.RNG_Periph.DATA;
   end Read;

   procedure Fill (Buffer : out Byte_Array) is
      use ESP32S3_Registers;                         --  brings UInt32 + its ops
      I : Natural := Buffer'First;
   begin
      while I <= Buffer'Last loop
         declare
            W : constant Word := Read;            --  one fresh random word
            N : constant Natural := Natural'Min (4, Buffer'Last - I + 1);
         begin
            for J in 0 .. N - 1 loop
               --  little-endian byte slice
               Buffer (I + J) := Byte ((W / (UInt32'(2)**(8 * J))) mod 256);
            end loop;
            I := I + N;
         end;
      end loop;
   end Fill;

   --  Short busy-wait for a clock to settle (~tens of us at 240 MHz); avoids a
   --  dependency on Ada.Real_Time so RNG stays ZFP-safe.
   procedure Settle is
      Spin : Integer := 0
      with Volatile;
   begin
      for K in 1 .. 20_000 loop
         Spin := Spin + 1;
      end loop;
   end Settle;

   ---------------------------------------------------------------------------
   --  Entropy source (mirrors esp-idf bootloader_random_enable for the S3).
   ---------------------------------------------------------------------------

   procedure Enable_Entropy_Source is
      ADC    : ESP32S3_Registers.APB_SARADC.APB_SARADC_Peripheral renames
        ESP32S3_Registers.APB_SARADC.APB_SARADC_Periph;
      Sensor : ESP32S3_Registers.SENS.SENS_Peripheral renames ESP32S3_Registers.SENS.SENS_Periph;
      Sys    : ESP32S3_Registers.SYSTEM.SYSTEM_Peripheral renames
        ESP32S3_Registers.SYSTEM.SYSTEM_Periph;
      RTC    : ESP32S3_Registers.RTC_CNTL.RTC_CNTL_Peripheral renames
        ESP32S3_Registers.RTC_CNTL.RTC_CNTL_Periph;
   begin
      --  Primary entropy source: the internal 8 MHz RC clock that feeds the RNG.
      --  (Espressif: this alone produces strong output; the SAR ADC adds insurance.)
      RTC.CLK_CONF.DIG_CLK8M_EN := True;
      Settle;

      --  SAR ADC continuously sampling a disconnected input, for extra entropy.
      --  Enable the ADC digital-controller's APB clock and LEAVE it on: the register
      --  writes below target the APB_SARADC peripheral, and accessing an unclocked
      --  peripheral stalls the CPU bus.  Reset the block via its own reset bit (a
      --  True->False pulse), not by gating its clock.
      Sys.PERIP_CLK_EN0.APB_SARADC_CLK_EN := True;
      Sys.PERIP_RST_EN0.APB_SARADC_RST := True;
      Sys.PERIP_RST_EN0.APB_SARADC_RST := False;

      --  ADC digital-controller clock = APB, enabled, divided down.
      ADC.CLKM_CONF.CLK_SEL := 2;
      ADC.CTRL.SARADC_SAR_CLK_GATED := True;
      ADC.CLKM_CONF.CLK_EN := True;
      ADC.CLKM_CONF.CLKM_DIV_NUM := 3;
      ADC.CTRL.SARADC_SAR_CLK_DIV := 3;       --  SAR clock divider (>= 2)
      ADC.CTRL2.SARADC_TIMER_TARGET := 70;      --  read freq well below sample freq

      ADC.CTRL.SARADC_START_FORCE := False;
      Sensor.SAR_POWER_XPD_SAR.FORCE_XPD_SAR := 3; --  power up the SAR analog block
      ADC.CTRL2.SARADC_MEAS_NUM_LIMIT := False;
      ADC.CTRL.SARADC_WORK_MODE := 1; --  digital controller, continuous

      --  One-entry pattern tables: channel info 0xA selects an internal voltage.
      ADC.CTRL.SARADC_SAR2_PATT_LEN := 0;
      ADC.SAR2_PATT_TAB1.SARADC_SAR2_PATT_TAB1 := 16#AF_FFFF#;
      ADC.CTRL.SARADC_SAR1_PATT_LEN := 0;
      ADC.SAR1_PATT_TAB1.SARADC_SAR1_PATT_TAB1 := 16#AF_FFFF#;

      Sensor.SAR_MEAS1_MUX.SAR1_DIG_FORCE := True;  --  ADC1 driven by the dig controller
      Sensor.SAR_MEAS2_MUX.SAR2_RTC_FORCE := False;
      ADC.ARB_CTRL.ADC_ARB_GRANT_FORCE := False;
      ADC.ARB_CTRL.ADC_ARB_FIX_PRIORITY := False;

      ADC.FILTER_CTRL0.FILTER_CHANNEL0 := 16#D#;
      ADC.FILTER_CTRL0.FILTER_CHANNEL1 := 16#D#;

      --  Start timer-driven sampling.
      ADC.CTRL2.SARADC_TIMER_SEL := True;
      ADC.CTRL2.SARADC_TIMER_EN := True;

   --  esp-idf additionally issues four REGI2C writes to select the exact
   --  internal reference voltage the ADC digitises; those go over the RTC I2C
   --  analog bus (not memory-mapped) and are omitted -- the ADC is powered and
   --  sampling, and the 8 MHz primary entropy source is on.
   end Enable_Entropy_Source;

   procedure Disable_Entropy_Source is
      ADC    : ESP32S3_Registers.APB_SARADC.APB_SARADC_Peripheral renames
        ESP32S3_Registers.APB_SARADC.APB_SARADC_Periph;
      Sensor : ESP32S3_Registers.SENS.SENS_Peripheral renames ESP32S3_Registers.SENS.SENS_Periph;
   begin
      Sensor.SAR_POWER_XPD_SAR.FORCE_XPD_SAR := 0;     --  power off the SAR
      Sensor.SAR_MEAS1_MUX.SAR1_DIG_FORCE := False;
      ADC.CTRL2.SARADC_TIMER_EN := False; --  stop sampling
      ESP32S3_Registers.SYSTEM.SYSTEM_Periph.PERIP_CLK_EN0.APB_SARADC_CLK_EN := False;
   --  (the 8 MHz clock entropy source is left running)
   end Disable_Entropy_Source;

end ESP32S3.RNG;
