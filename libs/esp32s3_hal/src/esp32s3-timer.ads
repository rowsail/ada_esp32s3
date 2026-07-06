with Interfaces;
with Ada.Finalization;

--  ESP32-S3 general-purpose timers (timer groups TIMG0 / TIMG1).
--
--  Each group has one 54-bit up/down counter clocked from the APB clock through a
--  16-bit prescaler, with a programmable alarm.  This driver exposes the two
--  general-purpose timers (the per-group watchdogs are separate and untouched).
--
--  Ownership: a timer is a shared resource handed out as a CLAIMED handle,
--  LIMITED (non-copyable) and CONTROLLED (released automatically on scope exit).
--  Uses finalization, so it targets the embedded/full profile.

package ESP32S3.Timer is

   type Timer_Index is range 0 .. 1;          --  0 = TIMG0, 1 = TIMG1

   type Ticks is new Interfaces.Unsigned_64;

   --  Non-copyable handle to a claimed timer (check Is_Valid after Claim).
   type Timer is limited private;

   procedure Claim (T : in out Timer; Index : Timer_Index);
   function Is_Valid (T : Timer) return Boolean;
   procedure Release (T : in out Timer);

   --  Configure T to count up at Tick_Hz ticks/second (default 1 MHz = 1 ÃÂµs per
   --  tick; max ~80 MHz / 1, min ~80 MHz / 65536).  The counter is stopped and
   --  reset to 0; call Start.
   procedure Configure (T : in out Timer; Tick_Hz : Positive := 1_000_000)
   with Pre => Is_Valid (T);

   procedure Start (T : Timer)
   with Pre => Is_Valid (T);
   procedure Stop (T : Timer)
   with Pre => Is_Valid (T);

   --  Reload the counter to 0 (whether running or stopped).
   procedure Reset (T : Timer)
   with Pre => Is_Valid (T);

   --  Current counter value (latched then read).
   function Value (T : Timer) return Ticks
   with Pre => Is_Valid (T);

   --  Raise the alarm interrupt-status flag when the counter reaches At_Ticks.
   procedure Set_Alarm (T : Timer; At_Ticks : Ticks)
   with Pre => Is_Valid (T);

   --  True once the alarm has fired (the flag stays set until Clear_Alarm).
   function Alarm_Fired (T : Timer) return Boolean
   with Pre => Is_Valid (T);

   procedure Clear_Alarm (T : Timer)
   with Pre => Is_Valid (T);

private
   type Timer is new Ada.Finalization.Limited_Controlled with record
      Idx  : Timer_Index := 0;
      Held : Boolean := False;
   end record;
   overriding
   procedure Finalize (T : in out Timer);
end ESP32S3.Timer;
