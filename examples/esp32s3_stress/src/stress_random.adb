with System.Machine_Code;
with Stress_State;

package body Stress_Random is

   use Interfaces;

   function Ccount return Unsigned_32 is
      Count : Unsigned_32;
   begin
      System.Machine_Code.Asm
        ("rsr.ccount %0",
         Outputs  => Unsigned_32'Asm_Output ("=r", Count),
         Volatile => True);
      return Count;
   end Ccount;

   procedure Reset (S : out Stream; Stream_Id : Interfaces.Unsigned_32) is
   begin
      --  Latch the global seed once, first caller wins

      if Stress_State.Seed = 0 then
         Stress_State.Seed := Ccount or 1;
      end if;

      --  Split the seed per stream (SplitMix-style avalanche so streams
      --  from adjacent ids are uncorrelated)

      S.State := Stress_State.Seed xor (Stream_Id * 16#9E37_79B9#);
      if S.State = 0 then
         S.State := 16#DEAD_BEEF#;
      end if;
   end Reset;

   function Next (S : access Stream) return Unsigned_32 is
      X : Unsigned_32 := S.State;
   begin
      X := X xor Shift_Left (X, 13);
      X := X xor Shift_Right (X, 17);
      X := X xor Shift_Left (X, 5);
      S.State := X;
      return X;
   end Next;

end Stress_Random;
