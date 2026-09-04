package body ESP32S3.LEDC.Math
  with SPARK_Mode => On
is

   -------------------
   -- Clock_Divider --
   -------------------

   function Clock_Divider (Freq : Positive; Bits : Resolution) return Natural is
      --  Max = 2**Bits, the duty step count (Bits in 1 .. 14 -> 2 .. 16384).
      --  Written closed-form so the divisor's bounds are visible to the prover
      --  (2**Bits defeats the nonlinear range check); value is identical.
      Max : constant Natural :=
        (case Bits is
           when 1 => 2, when 2 => 4, when 3 => 8, when 4 => 16,
           when 5 => 32, when 6 => 64, when 7 => 128, when 8 => 256,
           when 9 => 512, when 10 => 1024, when 11 => 2048, when 12 => 4096,
           when 13 => 8192, when 14 => 16384);
   begin
      return
        Natural'Max
          (256,
           Natural'Min
             (2**18 - 1,
              Natural
                ((Long_Long_Integer (Src_Hz) * 256)
                 / (Long_Long_Integer (Freq) * Long_Long_Integer (Max)))));
   end Clock_Divider;

   ----------------
   -- Duty_Count --
   ----------------

   function Duty_Count (Bits : Resolution; Percent : Duty_Percent) return Natural is
      --  Max = 2**Bits, the duty step count.  Closed-form (as in Clock_Divider)
      --  so the prover sees its bound without the nonlinear 2**Bits range check.
      Max : constant Natural :=
        (case Bits is
           when 1 => 2, when 2 => 4, when 3 => 8, when 4 => 16,
           when 5 => 32, when 6 => 64, when 7 => 128, when 8 => 256,
           when 9 => 512, when 10 => 1024, when 11 => 2048, when 12 => 4096,
           when 13 => 8192, when 14 => 16384);
      Raw : constant Float := Float (Max) * Percent / 100.0;
   begin
      --  Raw is in [0.0, Float (Max)] <= 16_384.0 (= 2**14) for every legal
      --  Percent (0 .. 100).  The two-sided guard against STATIC bounds hands the
      --  prover both Float->Natural conversion bounds directly (it derives
      --  neither from the nonlinear product, and will not carry Float (Max)'s
      --  bound through the conversion), and excludes a NaN -- all comparisons are
      --  False for NaN, so a NaN cannot enter the branch.  The guard holds for
      --  every legal input, so the else (saturate to Max) is unreachable:
      --  behaviour-neutral.
      if Raw >= 0.0 and then Raw <= 16_384.0 then
         return Natural'Min (Max, Natural (Raw));
      else
         return Max;
      end if;
   end Duty_Count;

end ESP32S3.LEDC.Math;
