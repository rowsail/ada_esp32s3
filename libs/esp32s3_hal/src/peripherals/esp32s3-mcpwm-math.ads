--  Pure timer/prescaler/dead-time arithmetic extracted from ESP32S3.MCPWM
--  (Configure_Channel).  No registers: just the period / divider / dead-time
--  integer math, split out so it can be formally proved (see
--  libs/esp32s3_hal/test/mcpwm_math_prove).  Configure_Channel calls these and
--  keeps every register write to itself -- behaviour-neutral relocation of the
--  exact expressions.

package ESP32S3.MCPWM.Math
  with SPARK_Mode => On
is

   Src_Hz   : constant := 160_000_000;   --  PWM_clk with CLK_PRESCALE = 0
   Max_Peak : constant := 65_536;        --  timer period field is 16-bit

   --  CLK_CFG.CLK_PRESCALE and TIMERn_CFG0.TIMERn_PRESCALE are both 8-bit
   --  fields holding "divider - 1", so each divides by 1 .. 256.
   Max_Clock_Divider : constant := 256;
   Max_Timer_Divider : constant := 256;

   --  The longest period one timer can measure on its own: the timer prescale
   --  at its slowest, counting a full 16-bit period.  A PWM period longer than
   --  this is out of the timer's reach and needs the unit clock divided down.
   Max_Timer_Ticks : constant := Max_Timer_Divider * Max_Peak;   --  16 777 216

   --  Smallest unit clock divider (1 .. 256) that brings one period of Freq
   --  within Max_Timer_Ticks, i.e. within the timer's own reach.
   --
   --  It is 1 -- the 160 MHz clock, untouched -- for every Freq at or above
   --  Src_Hz / Max_Timer_Ticks, which is 9.54 Hz.  So nothing at 10 Hz or
   --  above is affected by this at all; only a sub-10 Hz channel divides the
   --  unit clock, and Period_Total below then works from the divided clock.
   function Clock_Divider (Freq : Positive) return Natural
     with Post => Clock_Divider'Result in 1 .. Max_Clock_Divider;

   --  Total timer ticks per PWM period with the unit clock divided by
   --  Clock_Div (>= 1).  Clock_Div = 1 is the full 160 MHz clock.
   function Period_Total (Freq : Positive; Clock_Div : Positive := 1) return Natural
     with Pre  => Clock_Div <= Max_Clock_Divider,
          Post => Period_Total'Result in 1 .. Src_Hz;

   --  Smallest timer prescale (1 .. 256) so Total ticks fit the 16-bit period.
   function Prescale_Divider (Total : Natural) return Natural
     with Pre  => Total in 1 .. Src_Hz,
          Post => Prescale_Divider'Result in 1 .. Max_Timer_Divider;

   --  Timer period in ticks (= TIMER_PERIOD + 1), clamped to 2 .. Max_Peak.
   function Period_Ticks (Total, Divider : Natural) return Natural
     with Pre  => Total in 1 .. Src_Hz and then Divider in 1 .. Max_Timer_Divider,
          Post => Period_Ticks'Result in 2 .. Max_Peak;

   --  Dead-time in PWM-clock (160 MHz) ticks = ns * 0.16, clamped to 16 bits.
   --  The Pre bounds Dead_Time_Ns to its real domain (a 16-bit dead-time tops
   --  out near 410 us) so Dead_Time_Ns * 160 cannot overflow Integer.
   function Dead_Time_Ticks (Dead_Time_Ns : Natural) return Natural
     with Pre  => Dead_Time_Ns <= 13_000_000,
          Post => Dead_Time_Ticks'Result <= 65_535;

   --  Comparator value for Percent duty: Period * Percent / 100, clamped so it
   --  can never exceed the period nor the 16-bit comparator field (65_535).
   --  The Pre bounds Period to its real domain (Configure stores Period_Ticks,
   --  <= Max_Peak) so the Float scaling has no range error.  Set_Duty writes the
   --  result to the comparator register.
   function Duty_Compare (Period : Natural; Percent : Duty_Percent) return Natural
     with Pre  => Period <= Max_Peak,
          Post => Duty_Compare'Result <= 65_535;

end ESP32S3.MCPWM.Math;
