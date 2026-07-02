with Interfaces;                 use Interfaces;
with ESP32S3.GPIO;
with ESP32S3_Registers;          use ESP32S3_Registers;
with ESP32S3_Registers.RTC_CNTL; use ESP32S3_Registers.RTC_CNTL;

package body ESP32S3.RTC is

   RTC_Slow_Hz : constant := 136_000;     --  nominal RC_SLOW (uncalibrated)

   --  Wake-source bits (RTC_CNTL_WAKEUP_ENA / WAKEUP_CAUSE): ext1 = bit1,
   --  timer = bit3 (the WAKEUP_ENA reset value 0xC is gpio+timer).
   Wake_Ext1  : constant Unsigned_32 := 2;
   Wake_Timer : constant := 8;

   Deepsleep_Reset : constant := 5;       --  RESET_CAUSE_PROCPU for a deep-sleep wake

   --------------------
   -- Word accessors --
   --------------------

   type Word_Array is array (Word_Index) of Interfaces.Unsigned_32 with Volatile;
   Words : Word_Array
   with Import, Volatile, Address => Slow_Memory;

   function Read (Index : Word_Index) return Interfaces.Unsigned_32
   is (Words (Index));

   procedure Write (Index : Word_Index; Value : Interfaces.Unsigned_32) is
   begin
      Words (Index) := Value;
   end Write;

   ---------------------
   -- Boot/wake cause --
   ---------------------

   function Raw_Reset_Cause return Natural
   is (Natural (RTC_CNTL_Periph.RESET_STATE.RESET_CAUSE_PROCPU));

   function Raw_Wake_Cause return Natural
   is (Natural (RTC_CNTL_Periph.SLP_WAKEUP_CAUSE.WAKEUP_CAUSE));

   function Raw_Reject_Cause return Natural
   is (Natural (RTC_CNTL_Periph.SLP_REJECT_CAUSE.REJECT_CAUSE));

   function Last_Wake return Wake_Cause is
      Reset : constant Natural := Raw_Reset_Cause;
      Wake  : constant Natural := Raw_Wake_Cause;
   begin
      if Reset = 1 then
         return Power_On;                 --  POWERON_RESET
      elsif Reset = Deepsleep_Reset then
         if (Unsigned_32 (Wake) and Wake_Ext1) /= 0 then
            return Deep_Sleep_GPIO;
         else
            return Deep_Sleep_Timer;
         end if;
      else
         return Other_Reset;
      end if;
   end Last_Wake;

   --------------------
   -- Sleep FSM kick --
   --------------------

   --  Common deep-sleep entry: power the digital core down and trigger the RTC
   --  sleep FSM (esp-idf rtc_sleep_start essentials).  We leave the analog
   --  regulators at their normal voltage -- this is a *functional* deep sleep
   --  (correct wake), not the lowest-power one (no dbias tuning).
   --  Trigger the sleep FSM.  On a true deep sleep the core powers off and this
   --  never returns; it returns only if the FSM REJECTED the sleep.
   procedure Enter_Deep_Sleep (Wake_Mask : Natural) is
   begin
      RTC_CNTL_Periph.WAKEUP_STATE.WAKEUP_ENA := WAKEUP_STATE_WAKEUP_ENA_Field (Wake_Mask);
      RTC_CNTL_Periph.DIG_PWC.DG_WRAP_PD_EN := True;     --  deep sleep: digital off
      RTC_CNTL_Periph.SLP_REJECT_CONF.SLEEP_REJECT_ENA := 0;
      RTC_CNTL_Periph.INT_CLR_RTC :=
        (SLP_WAKEUP_INT_CLR => True, SLP_REJECT_INT_CLR => True, others => <>);
      RTC_CNTL_Periph.STATE0.SLP_REJECT_CAUSE_CLR := True;
      RTC_CNTL_Periph.STATE0.SLEEP_EN := True;             --  trigger

      --  Wait for the FSM (esp-idf rtc_sleep_start).  The core dies here on a
      --  real deep sleep; if we fall through, the sleep was rejected.
      while not RTC_CNTL_Periph.INT_RAW_RTC.SLP_REJECT_INT_RAW
        and then not RTC_CNTL_Periph.INT_RAW_RTC.SLP_WAKEUP_INT_RAW
      loop
         null;
      end loop;
   end Enter_Deep_Sleep;

   --  Latch and read the running 48-bit RTC time.
   function Now return Unsigned_64 is
   begin
      RTC_CNTL_Periph.TIME_UPDATE.TIME_UPDATE := True;
      for I in 1 .. 10_000 loop
         --  let the latch settle (~a few RTC ticks)
         null;
      end loop;
      return
        Shift_Left (Unsigned_64 (RTC_CNTL_Periph.TIME_HIGH0.TIMER_VALUE0_HIGH), 32)
        or Unsigned_64 (RTC_CNTL_Periph.TIME_LOW0);
   end Now;

   -------------------
   -- Deep_Sleep_For --
   -------------------

   procedure Deep_Sleep_For (Wake_After : Duration) is
      Ticks  : constant Unsigned_64 := Unsigned_64 (Float (Wake_After) * Float (RTC_Slow_Hz));
      Target : constant Unsigned_64 := Now + Ticks;
   begin
      RTC_CNTL_Periph.SLP_TIMER0 := UInt32 (Target and 16#FFFF_FFFF#);
      RTC_CNTL_Periph.SLP_TIMER1 :=
        (SLP_VAL_HI          =>
           SLP_TIMER1_SLP_VAL_HI_Field (Shift_Right (Target, 32) and 16#FFFF#),
         MAIN_TIMER_ALARM_EN => True,
         others              => <>);
      Enter_Deep_Sleep (Wake_Timer);
   end Deep_Sleep_For;

   ----------------------
   -- Deep_Sleep_Until --
   ----------------------

   procedure Deep_Sleep_Until (Pin : ESP32S3.RTC_IO.RTC_Pin; High : Boolean := True) is
      Sel : constant UInt22 := 2**Natural (Pin);   --  Pin <= 21, no wrap
   begin
      --  EXT1: wake when any selected RTC pad reaches the chosen level.
      RTC_CNTL_Periph.EXT_WAKEUP1 :=
        (EXT_WAKEUP1_SEL => EXT_WAKEUP1_EXT_WAKEUP1_SEL_Field (Sel), others => <>);
      RTC_CNTL_Periph.EXT_WAKEUP_CONF.EXT_WAKEUP1_LV := High;
      Enter_Deep_Sleep (2);              --  EXT1 wake bit
   end Deep_Sleep_Until;

   ---------------------------
   -- Disable_Super_Watchdog --
   ---------------------------

   procedure Disable_Super_Watchdog is
   begin
      RTC_CNTL_Periph.SWD_WPROTECT := 16#8F1D_312A#;     --  unlock key
      RTC_CNTL_Periph.SWD_CONF.SWD_AUTO_FEED_EN := True; --  never times out
   end Disable_Super_Watchdog;

end ESP32S3.RTC;
