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

   --  Total timer ticks per PWM period at the full 160 MHz clock (>= 1).
   function Period_Total (Freq : Positive) return Natural
     with Post => Period_Total'Result in 1 .. Src_Hz;

   --  Smallest timer prescale (1 .. 256) so Total ticks fit the 16-bit period.
   function Prescale_Divider (Total : Natural) return Natural
     with Pre  => Total in 1 .. Src_Hz,
          Post => Prescale_Divider'Result in 1 .. 256;

   --  Timer period in ticks (= TIMER_PERIOD + 1), clamped to 2 .. Max_Peak.
   function Period_Ticks (Total, Divider : Natural) return Natural
     with Pre  => Total in 1 .. Src_Hz and then Divider in 1 .. 256,
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
