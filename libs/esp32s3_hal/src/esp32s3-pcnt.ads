with Ada.Finalization;
with ESP32S3.GPIO;

--  ESP32-S3 PCNT (pulse counter) -- count edges on an input signal.
--
--  The S3 has four counter units; each counts up (or up/down) as edges arrive on
--  its input pin, into a signed 16-bit counter.  The classic use is a quadrature
--  / tachometer / flow-meter input.  This driver exposes the common "count edges
--  on a pin" case (the per-unit direction-control input and the threshold-event
--  comparators are left at their pass-through defaults).
--
--  Ownership: a unit is a shared resource handed out as a CLAIMED handle, LIMITED
--  (non-copyable) and CONTROLLED (released automatically on scope exit).  Uses
--  finalization, so it targets the embedded/full profile.

package ESP32S3.PCNT is

   type Unit_Index is range 0 .. 3;           --  the four counter units

   --  Non-copyable handle to a claimed unit (check Is_Valid after Claim).
   type Unit is limited private;

   procedure Claim (U : in out Unit; Index : Unit_Index);
   function Is_Valid (U : Unit) return Boolean;
   procedure Release (U : in out Unit);

   --  Route Pin to U's input and start counting.  By default each rising edge
   --  increments; set Both_Edges to count rising and falling edges.  The counter
   --  is cleared to 0.
   procedure Configure (U : in out Unit; Pin : ESP32S3.GPIO.Pin_Id; Both_Edges : Boolean := False);

   --  Current counter value (signed; wraps at +/- 32768).
   function Count (U : Unit) return Integer;

   --  Reset the counter to 0.
   procedure Clear (U : Unit);

   --  Pause / resume counting (the count is retained while paused).
   procedure Pause (U : Unit);
   procedure Resume (U : Unit);

private
   type Unit is new Ada.Finalization.Limited_Controlled with record
      Idx  : Unit_Index := 0;
      Held : Boolean := False;
   end record;
   overriding
   procedure Finalize (U : in out Unit);
end ESP32S3.PCNT;
