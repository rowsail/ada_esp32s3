with Interfaces;
with Ada.Finalization;
with ESP32S3.GPIO;

--  ESP32-S3 MCPWM (Motor-Control PWM) -- edge-aligned PWM output.
--
--  Two units (MCPWM0 / MCPWM1), each with three independent generator channels
--  and three capture channels.  A generator channel is one timer + one operator
--  producing a single edge-aligned PWM on output A, routed to a GPIO: high at the
--  start of each period, low when the up-counting timer reaches the duty
--  comparator (duty = compare / period).
--
--  A channel can also drive a COMPLEMENTARY pair (the half-bridge / H-bridge
--  motor-drive mode): the A output and an inverted B output, both from the same
--  PWM, with programmable dead-time inserted between their edges so the two are
--  never high together.  Carrier (chopper) modulation, fault/trip-zone shutdown
--  and edge capture are also provided.
--
--  Ownership / task-safety: a generator channel and a capture channel are shared
--  hardware resources, so each is handed out as a CLAIMED handle (Channel /
--  Capture).  A handle is LIMITED (non-copyable -- two tasks can't alias one
--  channel, nor reuse one through a stale copy) and CONTROLLED (it releases its
--  channel automatically on scope exit, including on an exception, stopping the
--  generator's timer so a leaked handle can't keep driving a pad).  Because you
--  exclusively own a claimed channel, its operations (including Set_Duty) need no
--  further locking.  Using finalization, this driver targets the embedded/full
--  profile (excluded from the light-tasking build).

package ESP32S3.MCPWM is

   type MCPWM_Unit is (MCPWM0, MCPWM1);
   type Channel_Index is (Ch0, Ch1, Ch2);    --  which generator channel of a unit

   subtype Duty_Percent is Float range 0.0 .. 100.0;

   --  Opaque, non-copyable handle to a claimed generator channel.  Default-
   --  initialised invalid (check Is_Valid); auto-releases on scope exit.
   type Channel is limited private;

   ----------------------------------------------------------------------------
   --  Channel ownership.  Claim/Release may run from any task -- a protected
   --  pool serialises them.  The unit's clock (PWM clock = 160 MHz) is brought
   --  up lazily on the first Claim of any of its channels, once per unit, so
   --  claiming a second channel never resets a sibling already running.  There
   --  is no separate unit-setup call to run beforehand.
   ----------------------------------------------------------------------------

   --  Claim generator channel Index of Unit into C.  If it is already claimed,
   --  C is left invalid (Is_Valid False).  (If C already holds a channel it is
   --  released first.)  The unit's clock comes up on the first Claim.  C releases
   --  its channel automatically on scope exit -- call Release only to hand it
   --  back early.
   procedure Claim (C : in out Channel; Unit : MCPWM_Unit; Index : Channel_Index);

   --  True when Claim succeeded (a real channel is held).
   function Is_Valid (C : Channel) return Boolean;

   --  Return the channel to the free pool (stopping its timer first).  Harmless
   --  on an invalid handle.
   procedure Release (C : in out Channel);

   ----------------------------------------------------------------------------
   --  Per-channel configuration + run-time control (you must hold C).
   ----------------------------------------------------------------------------

   --  Configure C for edge-aligned PWM at Freq Hz (roughly 10 Hz .. 10 MHz; the
   --  divider is chosen automatically) and route its A output to Pin.  Duty
   --  starts at 0 %; the timer is left stopped -- call Start.
   --
   --  Complement_Pin (optional): also drive a complementary B output on that pad
   --  -- the inverse of A, with Dead_Time_Ns of dead-time inserted on each edge
   --  so A and B are never high simultaneously (half-bridge motor drive).
   procedure Configure_Channel
     (C              : Channel;
      Freq           : Positive;
      Pin            : ESP32S3.GPIO.Pin_Id;
      Complement_Pin : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Dead_Time_Ns   : Natural := 0)
   with Pre => Is_Valid (C);

   --  Start / stop the channel's timer (the output halts in its current state).
   procedure Start (C : Channel)
   with Pre => Is_Valid (C);
   procedure Stop (C : Channel)
   with Pre => Is_Valid (C);

   --  Set the channel's duty cycle (0 .. 100 %).  Single atomic register write;
   --  the new value is loaded glitch-free at the next period boundary.  Safe
   --  without a lock because you exclusively own C.
   procedure Set_Duty (C : Channel; Percent : Duty_Percent)
   with Pre => Is_Valid (C);

   ----------------------------------------------------------------------------
   --  Carrier (chopper) modulation -- chops the output with a high-frequency
   --  carrier (for transformer-coupled / isolated gate drives).  Carrier
   --  frequency = 160 MHz / (8 * (Prescale + 1)); Duty_Eighths is the carrier's
   --  own duty in 1/8ths; First_Pulse widens the first chop pulse (in carrier
   --  periods, 0 = same as the rest).
   ----------------------------------------------------------------------------
   subtype Carrier_Prescale is Natural range 0 .. 15;
   subtype Carrier_Duty is Natural range 1 .. 7;
   subtype Carrier_Pulse is Natural range 0 .. 15;

   procedure Set_Carrier
     (C            : Channel;
      Enable       : Boolean := True;
      Prescale     : Carrier_Prescale := 0;
      Duty_Eighths : Carrier_Duty := 4;
      First_Pulse  : Carrier_Pulse := 1)
   with Pre => Is_Valid (C);

   ----------------------------------------------------------------------------
   --  Fault / trip-zone -- a fault input pin forces the outputs to a safe state
   --  (e.g. over-current shutdown).  Configure_Fault enables an input unit-wide
   --  (call after Setup); Protect_Channel makes a claimed channel react to it.
   ----------------------------------------------------------------------------
   type Fault_Input is (Fault0, Fault1, Fault2);
   type Fault_Mode is (One_Shot, Cycle_By_Cycle);
   type Trip_Action is (No_Change, Force_Low, Force_High);

   --  Route Pin to a fault input and enable it (Active_High: a high level is the
   --  fault; else low).
   procedure Configure_Fault
     (Unit        : MCPWM_Unit;
      Input       : Fault_Input;
      Pin         : ESP32S3.GPIO.Pin_Id;
      Active_High : Boolean := True);

   --  When Input faults, force channel C's A and B outputs to Action.  One_Shot
   --  latches until Clear_Fault; Cycle_By_Cycle holds only while the fault is
   --  asserted (re-evaluated each period).
   procedure Protect_Channel
     (C      : Channel;
      Input  : Fault_Input;
      Mode   : Fault_Mode := One_Shot;
      Action : Trip_Action := Force_Low)
   with Pre => Is_Valid (C);

   --  Clear a latched one-shot trip (re-enables the outputs if the fault is gone).
   procedure Clear_Fault (C : Channel)
   with Pre => Is_Valid (C);

   --  True while the channel is tripped (one-shot latched or cycle-by-cycle on).
   function Faulted (C : Channel) return Boolean
   with Pre => Is_Valid (C);

   ----------------------------------------------------------------------------
   --  Capture -- timestamp edges on an input pin (measure an external signal's
   --  period / duty).  The capture timer runs on the APB clock.  A capture
   --  channel is claimed just like a generator channel.
   ----------------------------------------------------------------------------
   type Cap_Index is (Cap0, Cap1, Cap2);
   type Cap_Edge is (Rising, Falling, Both_Edges);

   Capture_Clock_Hz : constant := 80_000_000;   --  APB clock the cap timer counts

   --  Opaque, non-copyable handle to a claimed capture channel.
   type Capture is limited private;

   --  Claim capture channel Index of Unit into Cap (see Claim for a Channel).
   --  The unit's clock comes up on the first Claim of any of its channels.
   procedure Claim (Cap : in out Capture; Unit : MCPWM_Unit; Index : Cap_Index);
   function Is_Valid (Cap : Capture) return Boolean;
   procedure Release (Cap : in out Capture);

   --  Route Pin to the claimed capture channel and start timestamping the given
   --  edges.
   procedure Configure_Capture
     (Cap : Capture; Pin : ESP32S3.GPIO.Pin_Id; Edge : Cap_Edge := Both_Edges)
   with Pre => Is_Valid (Cap);

   --  True once a new edge has been captured (and not yet read).
   function Capture_Pending (Cap : Capture) return Boolean
   with Pre => Is_Valid (Cap);

   --  Read the latest capture timestamp (in Capture_Clock_Hz ticks) and which
   --  edge it was, and clear the pending flag.
   procedure Read_Capture
     (Cap : Capture; Value : out Interfaces.Unsigned_32; Falling : out Boolean)
   with Pre => Is_Valid (Cap);

private

   type Channel is new Ada.Finalization.Limited_Controlled with record
      U    : MCPWM_Unit := MCPWM0;
      Idx  : Channel_Index := Ch0;
      Held : Boolean := False;
   end record;
   overriding
   procedure Finalize (C : in out Channel);   --  auto-release on scope exit

   type Capture is new Ada.Finalization.Limited_Controlled with record
      U    : MCPWM_Unit := MCPWM0;
      Idx  : Cap_Index := Cap0;
      Held : Boolean := False;
   end record;
   overriding
   procedure Finalize (Cap : in out Capture);

end ESP32S3.MCPWM;
