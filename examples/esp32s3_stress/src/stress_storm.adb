with System;
with Ada.Real_Time; use Ada.Real_Time;
with Interfaces;    use Interfaces;
with Stress_Random;
with Stress_State;

package body Stress_Storm is

   procedure Qtrace_Watch_Self;
   pragma Import (C, Qtrace_Watch_Self, "__gnat_qtrace_watch_self");
   pragma Weak_External (Qtrace_Watch_Self);
   --  Focus the runtime's diagnostic event ring (instrumented packs only)
   --  on the historically first-wedging task, from inside that task

   --  One iteration: a randomized delay drawn from a distribution biased
   --  toward the nasty cases (already-expired deadlines, zero-length and
   --  sub-tick delays), then an optional busy-spin of up to ~200 us so
   --  the next tick lands mid-computation.

   procedure Iterate
     (Rng : access Stress_Random.Stream; Beat_Slot : Positive);

   procedure Iterate
     (Rng : access Stress_Random.Stream; Beat_Slot : Positive)
   is
      Draw : constant Unsigned_32 := Stress_Random.Next (Rng);
   begin
      case Draw mod 8 is
         when 0 =>
            --  Deadline already in the past: must release immediately
            delay until Clock - Microseconds (Integer (Draw mod 1000));
         when 1 =>
            --  Exactly "now"
            delay until Clock;
         when 2 | 3 | 4 =>
            --  Sub-millisecond: hammers alarm re-arming
            delay until Clock + Microseconds (Integer (Draw mod 1000));
         when 5 | 6 =>
            --  A few milliseconds: keeps the alarm queue populated
            delay until Clock + Microseconds (Integer (Draw mod 5000));
         when others =>
            --  Busy-spin up to ~200 us: let the tick preempt mid-spin
            declare
               Cycles : constant Unsigned_32 := Draw mod 48_000;
               Start  : constant Unsigned_32 := Stress_Random.Ccount;
            begin
               while Stress_Random.Ccount - Start < Cycles loop
                  null;
               end loop;
            end;
      end case;

      Stress_State.Beats (Beat_Slot) :=
        Stress_State.Beats (Beat_Slot) + 1;
   end Iterate;

   task body Storm_1 is
      use type System.Address;
      Rng : aliased Stress_Random.Stream;
   begin
      if Qtrace_Watch_Self'Address /= System.Null_Address then
         Qtrace_Watch_Self;
      end if;
      Stress_Random.Reset (Rng, Stream_Id => 1);
      loop
         Iterate (Rng'Access, Stress_State.Beat_Storm_1);
      end loop;
   end Storm_1;

   task body Storm_2 is
      Rng : aliased Stress_Random.Stream;
   begin
      Stress_Random.Reset (Rng, Stream_Id => 2);
      loop
         Iterate (Rng'Access, Stress_State.Beat_Storm_2);
      end loop;
   end Storm_2;

   task body Storm_3 is
      Rng : aliased Stress_Random.Stream;
   begin
      Stress_Random.Reset (Rng, Stream_Id => 3);
      loop
         Iterate (Rng'Access, Stress_State.Beat_Storm_3);
      end loop;
   end Storm_3;

   task body Storm_4 is
      Rng : aliased Stress_Random.Stream;
   begin
      Stress_Random.Reset (Rng, Stream_Id => 4);
      loop
         Iterate (Rng'Access, Stress_State.Beat_Storm_4);
      end loop;
   end Storm_4;

end Stress_Storm;
