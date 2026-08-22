with System.Storage_Elements; use System.Storage_Elements;
with Ada.Unchecked_Conversion;
with ESP32S3.Log;

package body ESP32S3.Stack_Usage is

   Sentinel : constant := 16#A5A5_A5A5#;

   --  The env-task stack bounds, straight from the linker (start.S loads
   --  __stack_end into the SP, which then grows down towards __stack_start).
   Stack_Start_Sym : constant Character
   with Import, Convention => Asm, External_Name => "__stack_start";
   Stack_End_Sym   : constant Character
   with Import, Convention => Asm, External_Name => "__stack_end";

   Env_Low  : constant System.Address := Stack_Start_Sym'Address;
   Env_High : constant System.Address := Stack_End_Sym'Address;

   type U32 is mod 2**32 with Size => 32;
   type U32_Ptr is access all U32;
   function To_Ptr is new Ada.Unchecked_Conversion (System.Address, U32_Ptr);

   --  Keep this many bytes below the caller's frame UNpainted, so painting can
   --  never reach into a live frame (this body's own, or a callee's).
   Guard : constant Storage_Offset := 256;

   --  ...and keep this many bytes ABOVE the stack's limit unpainted.  The
   --  recoverable stack-overflow guard (Bare_Glue.Stack_Ovf_Redzone) arms a
   --  STORE data-watchpoint that far above the limit, and painting is a store:
   --  painting from the limit up therefore trips the watchpoint on its very
   --  first word and raises Storage_Error before the stack has overflowed at
   --  all.  Keep this in step with Stack_Ovf_Redzone in the bare boot glue.
   --
   --  Nothing is lost by not painting it: a stack that ever reached the redzone
   --  would have fired the guard for real, so there is no high-water mark to
   --  recover from down there.
   Overflow_Redzone : constant Storage_Offset := 2048;

   --  Width of the data-watchpoint the guard arms.  Bare_Glue does
   --
   --     DBREAKA1 := (limit + Stack_Ovf_Redzone) and not 63;
   --     DBREAKC1 := StoreBreak or 16#3F#;
   --
   --  so the address is rounded DOWN to 64 and the break then covers 64 bytes
   --  UPWARD from there.  Skipping exactly Overflow_Redzone therefore lands on
   --  the first word of the watched window rather than clear of it.
   Watch_Window : constant Storage_Offset := 64;

   --  The bottom of the painted region: the first 64-byte boundary ABOVE the
   --  watched window.  Paint_Env_Stack and High_Water must use exactly the
   --  same base, or the unpainted redzone reads as "used" and the high-water
   --  mark comes back as the whole stack.
   --
   --  This was Env_Low + Overflow_Redzone until 2026-08-22, which is the
   --  bottom of the watched window, not past it.  Painting then tripped the
   --  guard on its first store and raised Storage_Error in the ENVIRONMENT
   --  task, where there is no handler -- so it reached the last-chance
   --  handler and reset the board.  It only showed up sometimes because
   --  DBREAKA1 is per-CORE and re-armed on every Enter_Task: if a task
   --  pinned to the same core had already entered and re-armed the register
   --  to its own redzone, the env watchpoint was no longer there to trip.
   --  That race turns on code layout, so unrelated changes moved it.
   --  Mirror the glue's own arithmetic, then step past the window it watches.
   --  Rounding UP from Env_Low + Overflow_Redzone is NOT enough: that address
   --  is already 64-aligned here, so rounding up leaves it exactly on the
   --  window's first word.
   Watch_Addr : constant Integer_Address :=
     (To_Integer (Env_Low) + Integer_Address (Overflow_Redzone))
     and not (Integer_Address (Watch_Window) - 1);

   Paint_Base : constant System.Address :=
     To_Address (Watch_Addr + Integer_Address (Watch_Window));

   -----------
   -- Paint --
   -----------

   procedure Paint (Low, High : System.Address) is
      Addr : Integer_Address := To_Integer (Low);
      Top  : constant Integer_Address := To_Integer (High);
   begin
      while Addr < Top loop
         To_Ptr (To_Address (Addr)).all := Sentinel;
         Addr := Addr + 4;
      end loop;
   end Paint;

   ----------------
   -- High_Water --
   ----------------

   function High_Water (Low, High : System.Address) return Natural is
      Addr : Integer_Address := To_Integer (Low);
      Top  : constant Integer_Address := To_Integer (High);
   begin
      --  Scan up from the bottom; the first non-sentinel word is the deepest the
      --  stack ever reached.  Everything from there to High counts as used.
      while Addr < Top loop
         if To_Ptr (To_Address (Addr)).all /= Sentinel then
            return Natural (Top - Addr);
         end if;
         Addr := Addr + 4;
      end loop;
      return 0;   --  whole region still pristine -> never used
   end High_Water;

   ---------------------
   -- Paint_Env_Stack --
   ---------------------

   procedure Paint_Env_Stack is
      Here  : aliased Integer := 0;   --  lives in THIS frame, near the current SP
      Limit : constant System.Address := Here'Address - Guard;
   begin
      --  Paint [__stack_start + redzone, here - guard): the still-unused region
      --  below us, stopping clear of the overflow guard's watchpoint.
      if To_Integer (Limit) > To_Integer (Paint_Base) then
         Paint (Paint_Base, Limit);
      end if;
   end Paint_Env_Stack;

   --------------------------------
   -- Env_Used / Env_Free / Total --
   --------------------------------

   function Env_Total return Natural
   is (Natural (Env_High - Env_Low));
   function Env_Used return Natural
   is (High_Water (Paint_Base, Env_High));
   function Env_Free return Natural
   is (Env_Total - Env_Used);

   ------------
   -- Report --
   ------------

   procedure Report is
      use ESP32S3.Log;
      Used : constant Natural := Env_Used;
      Tot  : constant Natural := Env_Total;
      Pct  : constant Natural := (if Tot = 0 then 0 else (Used * 100) / Tot);
   begin
      Put ("stack: env used=");
      Put (Used);
      Put (" free=");
      Put (Tot - Used);
      Put (" total=");
      Put (Tot);
      Put (" (");
      Put (Pct);
      Put_Line ("%)");
   end Report;

end ESP32S3.Stack_Usage;
