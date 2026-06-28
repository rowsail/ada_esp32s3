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

   -----------
   -- Paint --
   -----------

   procedure Paint (Low, High : System.Address) is
      A  : Integer_Address := To_Integer (Low);
      Hi : constant Integer_Address := To_Integer (High);
   begin
      while A < Hi loop
         To_Ptr (To_Address (A)).all := Sentinel;
         A := A + 4;
      end loop;
   end Paint;

   ----------------
   -- High_Water --
   ----------------

   function High_Water (Low, High : System.Address) return Natural is
      A  : Integer_Address := To_Integer (Low);
      Hi : constant Integer_Address := To_Integer (High);
   begin
      --  Scan up from the bottom; the first non-sentinel word is the deepest the
      --  stack ever reached.  Everything from there to High counts as used.
      while A < Hi loop
         if To_Ptr (To_Address (A)).all /= Sentinel then
            return Natural (Hi - A);
         end if;
         A := A + 4;
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
      --  Paint [__stack_start, here - guard): the still-unused region below us.
      if To_Integer (Limit) > To_Integer (Env_Low) then
         Paint (Env_Low, Limit);
      end if;
   end Paint_Env_Stack;

   --------------------------------
   -- Env_Used / Env_Free / Total --
   --------------------------------

   function Env_Total return Natural is (Natural (Env_High - Env_Low));
   function Env_Used  return Natural is (High_Water (Env_Low, Env_High));
   function Env_Free  return Natural is (Env_Total - Env_Used);

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
