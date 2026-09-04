package body ESP32S3.MCPWM.Math
  with SPARK_Mode => On
is

   ------------------
   -- Period_Total --
   ------------------

   function Period_Total (Freq : Positive) return Natural is
   begin
      return Natural'Max (1, Src_Hz / Freq);
   end Period_Total;

   ----------------------
   -- Prescale_Divider --
   ----------------------

   function Prescale_Divider (Total : Natural) return Natural is
   begin
      return Natural'Max (1, Natural'Min (256, (Total + Max_Peak - 1) / Max_Peak));
   end Prescale_Divider;

   ------------------
   -- Period_Ticks --
   ------------------

   function Period_Ticks (Total, Divider : Natural) return Natural is
   begin
      return Natural'Max (2, Natural'Min (Max_Peak, Total / Divider));
   end Period_Ticks;

   ---------------------
   -- Dead_Time_Ticks --
   ---------------------

   function Dead_Time_Ticks (Dead_Time_Ns : Natural) return Natural is
   begin
      return Natural'Min (65_535, (Dead_Time_Ns * (Src_Hz / 1_000_000)) / 1000);
   end Dead_Time_Ticks;

   ------------------
   -- Duty_Compare --
   ------------------

   function Duty_Compare (Period : Natural; Percent : Duty_Percent) return Natural is
      Raw : constant Float := Float (Period) * Percent / 100.0;
   begin
      --  Raw is in [0.0, Float (Period)] <= 65_536.0 (= Max_Peak, the Pre) for
      --  every legal Percent (0 .. 100).  The two-sided guard against STATIC
      --  bounds hands the prover both Float->Natural conversion bounds directly
      --  (it derives neither from the nonlinear product, and will not carry
      --  Float (Period)'s bound through the conversion), and excludes a NaN --
      --  all comparisons are False for NaN, so a NaN cannot enter the branch.
      --  The guard holds for every legal input, so the else (saturate to Period,
      --  capped) is unreachable: behaviour-neutral.
      if Raw >= 0.0 and then Raw <= 65_536.0 then
         return Natural'Min (65_535, Natural'Min (Period, Natural (Raw)));
      else
         return Natural'Min (65_535, Period);
      end if;
   end Duty_Compare;

end ESP32S3.MCPWM.Math;
