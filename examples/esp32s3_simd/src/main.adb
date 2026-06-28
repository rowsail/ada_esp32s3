--  What it demonstrates
--  ---------------------
--  The ESP32S3.SIMD library (libs/esp32s3_simd) running on real silicon: a few
--  representative vector kernels whose inner loops are GNAT inline assembly over
--  the Xtensa LX7 PIE SIMD unit (the q-registers).  For each op we check the SIMD
--  result against a plain scalar Ada reference, then time both with the cycle
--  counter and print the speed-up.
--
--  Two ESP32-S3 specifics make this run (see the assembly-in-Ada book chapter):
--    * the PIE `ee.*` opcodes assemble via the repo's S3 dynconfig overlay, and
--    * start.S enables the PIE coprocessor (CPENABLE bit 3, "cop_ai").
--
--  Build & run
--  -----------
--    ./x run esp32s3_simd
--  then watch the serial console (e.g. picocom -b 115200 /dev/ttyACM0).
with Interfaces;          use Interfaces;
with System.Machine_Code; use System.Machine_Code;
with ESP32S3.Log;         use ESP32S3.Log;
with ESP32S3.SIMD;        use ESP32S3.SIMD;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is

   N     : constant := 1024;   --  elements per vector
   Iters : constant := 64;     --  repetitions, to average out timing noise
   CPU_MHz : constant := 240;  --  start.S selects the 240 MHz PLL

   subtype Idx is Natural range 0 .. N - 1;

   --  16-byte-aligned vectors (the SIMD types guarantee the alignment the
   --  ee.vld/ee.vst 128-bit load/store instructions need).
   A32, B32, R32, Ref32 : SIMD_I32_Vector (Idx);
   Af,  Bf,  Rf,  Reff  : SIMD_F32_Vector (Idx);

   --  Read the Xtensa cycle counter (CCOUNT) with a one-instruction asm insert --
   --  the smallest possible taste of the same System.Machine_Code mechanism the
   --  SIMD kernels use.  CCOUNT is a free-running 32-bit counter at the CPU clock.
   function Cycles return Unsigned_32 is
      V : Unsigned_32;
   begin
      Asm ("rsr.ccount %0",
           Outputs  => Unsigned_32'Asm_Output ("=r", V),
           Volatile => True);
      return V;
   end Cycles;

   --  Saturating scalar reference for Integer_32 add (the SIMD Add saturates).
   function Sat_Add (X, Y : Integer_32) return Integer_32 is
      S : constant Integer_64 := Integer_64 (X) + Integer_64 (Y);
   begin
      if    S > Integer_64 (Integer_32'Last)  then return Integer_32'Last;
      elsif S < Integer_64 (Integer_32'First) then return Integer_32'First;
      else  return Integer_32 (S);
      end if;
   end Sat_Add;

   --  Print "<label>: <simd> vs <scalar> cycles  (NN.Nx)  PASS/FAIL".
   procedure Report (Label : String; Simd_C, Scalar_C : Unsigned_32; Ok : Boolean) is
   begin
      Put (Label);
      Put (" SIMD=");   Put_Unsigned (Simd_C);
      Put (" scalar="); Put_Unsigned (Scalar_C);
      Put (" speedup=");
      if Simd_C = 0 then Put ("inf");
      else Put_Fixed (Integer (Scalar_C), Positive (Simd_C), Decimals => 1); Put ("x");
      end if;
      Put_Line (if Ok then "  PASS" else "  *** FAIL ***");
   end Report;

   T0, T1, Sc0, Sc1 : Unsigned_32;
   Ok : Boolean;

begin
   Put_Line ("");
   Put_Line ("=== ESP32-S3 PIE SIMD on bare-metal Ada ===");
   Put (CPU_MHz, 0); Put_Line (" MHz, vectors of 1024 elements, 64 iterations");
   Put_Line ("");

   ---------------------------------------------------------------------------
   --  1. Add, Integer_32 (element-wise, saturating)
   ---------------------------------------------------------------------------
   for I in Idx loop
      A32 (I) := Integer_32 (I) - 500;
      B32 (I) := Integer_32 (I) * 3;
   end loop;

   T0 := Cycles;
   for K in 1 .. Iters loop Add (A32, B32, R32); end loop;
   T1 := Cycles;

   Sc0 := Cycles;
   for K in 1 .. Iters loop
      for I in Idx loop Ref32 (I) := Sat_Add (A32 (I), B32 (I)); end loop;
   end loop;
   Sc1 := Cycles;

   Ok := (for all I in Idx => R32 (I) = Ref32 (I));
   Report ("Add  i32 ", T1 - T0, Sc1 - Sc0, Ok);

   ---------------------------------------------------------------------------
   --  2. Dot_Product, Integer_32 (reduction) -- small values so it fits i32
   ---------------------------------------------------------------------------
   for I in Idx loop
      A32 (I) := Integer_32 (I mod 5) - 2;     --  -2 .. 2
      B32 (I) := Integer_32 (I mod 3) - 1;     --  -1 .. 1
   end loop;

   declare
      SD, RD : Integer_32 := 0;
   begin
      T0 := Cycles;
      for K in 1 .. Iters loop SD := Dot_Product (A32, B32); end loop;
      T1 := Cycles;

      Sc0 := Cycles;
      for K in 1 .. Iters loop
         RD := 0;
         for I in Idx loop RD := RD + A32 (I) * B32 (I); end loop;
      end loop;
      Sc1 := Cycles;

      Report ("Dot  i32 ", T1 - T0, Sc1 - Sc0, SD = RD);
   end;

   ---------------------------------------------------------------------------
   --  3. Add, IEEE_Float_32 (element-wise, bit-exact IEEE add)
   ---------------------------------------------------------------------------
   for I in Idx loop
      Af (I) := IEEE_Float_32 (I) * 0.5;
      Bf (I) := IEEE_Float_32 (N - I);
   end loop;

   T0 := Cycles;
   for K in 1 .. Iters loop Add (Af, Bf, Rf); end loop;
   T1 := Cycles;

   Sc0 := Cycles;
   for K in 1 .. Iters loop
      for I in Idx loop Reff (I) := Af (I) + Bf (I); end loop;
   end loop;
   Sc1 := Cycles;

   Ok := (for all I in Idx => Rf (I) = Reff (I));
   Report ("Add  f32 ", T1 - T0, Sc1 - Sc0, Ok);

   ---------------------------------------------------------------------------
   --  4. Copy, Integer_32 (bulk move)
   ---------------------------------------------------------------------------
   for I in Idx loop A32 (I) := Integer_32 (I) * 7 - 11; end loop;

   T0 := Cycles;
   for K in 1 .. Iters loop Copy (A32, R32); end loop;
   T1 := Cycles;

   Sc0 := Cycles;
   for K in 1 .. Iters loop
      for I in Idx loop Ref32 (I) := A32 (I); end loop;
   end loop;
   Sc1 := Cycles;

   Ok := (for all I in Idx => R32 (I) = Ref32 (I));
   Report ("Copy i32 ", T1 - T0, Sc1 - Sc0, Ok);

   ---------------------------------------------------------------------------
   --  5. Compare_GT, Integer_32 (mask: -1 where A > B, else 0)
   ---------------------------------------------------------------------------
   for I in Idx loop
      A32 (I) := Integer_32 (I mod 7) - 3;
      B32 (I) := Integer_32 (I mod 5) - 2;
   end loop;

   T0 := Cycles;
   for K in 1 .. Iters loop Compare_GT (A32, B32, R32); end loop;
   T1 := Cycles;

   Sc0 := Cycles;
   for K in 1 .. Iters loop
      for I in Idx loop
         Ref32 (I) := (if A32 (I) > B32 (I) then -1 else 0);
      end loop;
   end loop;
   Sc1 := Cycles;

   Ok := (for all I in Idx => R32 (I) = Ref32 (I));
   Report ("Cmp> i32 ", T1 - T0, Sc1 - Sc0, Ok);

   Put_Line ("");
   Put_Line ("done.");
   loop null; end loop;
end Main;
