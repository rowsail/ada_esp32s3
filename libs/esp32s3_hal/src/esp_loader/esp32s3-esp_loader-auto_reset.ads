--  The auto-reset circuit every ESP development board has, in software.
--
--  When a board sits between a PC and a target as a USB-serial bridge, esptool
--  on the PC expects to reach the target's ROM loader by wiggling DTR and RTS.
--  It does not know it is talking to us, so we have to behave like the
--  two-transistor circuit it thinks is there.
--
--  ------------------------------------------------------------------------
--  What esptool means by the lines
--  ------------------------------------------------------------------------
--  From esptool's own reset.py: an ASSERTED line pulls its pin LOW.
--
--     DTR asserted  ->  target IO0 = LOW   (boot requested)
--     RTS asserted  ->  target EN  = LOW   (held in reset)
--
--  and it drives them in one of two sequences.  ClassicReset sets the lines
--  one at a time and is what Windows always gets; UnixTightReset sets both at
--  once and is tried first on Unix.  Both walk through the same states:
--
--     DTR=0 RTS=1   IO0 high, EN low    held in reset
--     (100 ms)
--     DTR=1 RTS=0   IO0 low,  EN high   released, so the ROM samples IO0 low
--     (50 ms)
--     DTR=0 RTS=0   IO0 high            done
--
--  ------------------------------------------------------------------------
--  Why this is not just two wires
--  ------------------------------------------------------------------------
--  The real circuit is CROSS-COUPLED: EN goes low only when RTS is asserted
--  AND DTR is not, and IO0 only when DTR is asserted AND RTS is not.  That is
--  deliberate.  Terminal programs -- screen, minicom, PuTTY -- assert both
--  lines when they open a port, and without the cross-coupling every one of
--  them would reset the board.  So we reproduce it: with both lines asserted,
--  nothing happens.
--
--  But the cross-coupling has a cost, and it is why the real circuit needs its
--  capacitor.  Under ClassicReset the two lines move separately, so between
--  "DTR asserted" and "RTS released" the state is briefly (1,1) -- which the
--  cross-coupling reads as "release EN" while IO0 is still high.  The chip
--  would leave reset a moment too early and boot the application instead of
--  the loader.  Real boards survive this only because of the RC on EN (about
--  10k and 1uF, so ~10 ms) holding it down across the gap.
--
--  That capacitor is on the TARGET, and a bridge cannot count on it.  So this
--  emulates it: asserting reset is immediate, RELEASING it waits
--  Release_Delay_Ms, and a release still pending when reset is wanted again is
--  simply cancelled.  ClassicReset then works regardless of what the target
--  board has on its EN pin, and UnixTightReset -- whose line changes arrive
--  together, so the (1,1) state never appears -- is unaffected.

with Ada.Real_Time;

package ESP32S3.Esp_Loader.Auto_Reset is

   --  Long enough to cover the gap between two of ClassicReset's line changes
   --  (two ioctls and a USB control transfer apart, so well under a
   --  millisecond), short enough to be invisible against its 100 ms hold.
   Default_Release_Delay_Ms : constant := 10;

   type Circuit is limited private;

   --  Bind the circuit to the target's control lines.  Over needs only its
   --  Assert_Reset and Assert_Boot members -- this never touches the wire.
   procedure Configure
     (C                : out Circuit;
      Over             : Link;
      Release_Delay_Ms : Natural := Default_Release_Delay_Ms);

   --  Feed in the host's current control lines and drive the target's.  Call
   --  this from the pass-through loop on EVERY pass, not only when the lines
   --  change: it is what makes the delayed release happen.
   procedure Update (C : in out Circuit; DTR : Boolean; RTS : Boolean);

   --  What the target is currently being told, for a diagnostic or an LED.
   function Reset_Asserted (C : Circuit) return Boolean;
   function Boot_Asserted (C : Circuit) return Boolean;

   --  True while a release is waiting out the emulated capacitor.
   function Releasing (C : Circuit) return Boolean;

private

   type Circuit is limited record
      Over    : Link;
      Hold    : Ada.Real_Time.Time_Span :=
        Ada.Real_Time.Milliseconds (Default_Release_Delay_Ms);
      Started : Boolean := False;

      --  What the target is being driven to right now.
      Reset_Out : Boolean := False;
      Boot_Out  : Boolean := False;

      --  A release of reset that is waiting out the emulated capacitor.
      Release_Pending : Boolean := False;
      Release_At      : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
   end record;

   function Reset_Asserted (C : Circuit) return Boolean
   is (C.Reset_Out);
   function Boot_Asserted (C : Circuit) return Boolean
   is (C.Boot_Out);
   function Releasing (C : Circuit) return Boolean
   is (C.Release_Pending);

end ESP32S3.Esp_Loader.Auto_Reset;

