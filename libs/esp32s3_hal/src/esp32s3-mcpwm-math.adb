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

end ESP32S3.MCPWM.Math;
