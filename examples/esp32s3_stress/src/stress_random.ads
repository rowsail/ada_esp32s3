--  Minimal xorshift PRNG, one independent stream per task, all derived from
--  a single boot-time CCOUNT seed (published in Stress_State.Seed so runs
--  are reproducible).

with Interfaces;

package Stress_Random is

   type Stream is limited private;

   procedure Reset (S : out Stream; Stream_Id : Interfaces.Unsigned_32);
   --  Derive this stream from the global seed and the caller's id

   function Next (S : access Stream) return Interfaces.Unsigned_32;
   --  Uniform 32-bit pseudo-random value

   function Ccount return Interfaces.Unsigned_32;
   --  The CPU cycle counter (also used for busy-spins)

private

   type Stream is limited record
      State : Interfaces.Unsigned_32 := 0;
   end record;

end Stress_Random;
