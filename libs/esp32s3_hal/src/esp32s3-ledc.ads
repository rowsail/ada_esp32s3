with Ada.Finalization;
with ESP32S3.GPIO;

--  ESP32-S3 LEDC (LED PWM controller) -- up to eight independent PWM outputs.
--
--  The S3 LEDC has eight low-speed channels fed by four timers; a channel picks
--  a timer (which sets its frequency + duty resolution) and drives a GPIO with a
--  duty cycle you can change at run time.  Unlike MCPWM (motor control: dead-time,
--  fault, capture), LEDC is the simple "dim an LED / generate a clean PWM" block.
--
--  Ownership: a channel is a shared resource, so it is handed out as a CLAIMED
--  handle.  A Channel handle is LIMITED (non-copyable -- two tasks can't drive
--  the same channel, nor reuse one through a stale copy) and CONTROLLED (it stops
--  the output and releases the channel automatically on scope exit, including on
--  an exception).  Because you exclusively own a claimed channel, Set_Duty needs
--  no lock.  Uses finalization, so it targets the embedded/full profile.

package ESP32S3.LEDC is

   type Channel_Index is range 0 .. 7;        --  the eight LEDC channels

   subtype Resolution is Positive range 1 .. 14;   --  duty-cycle bits
   subtype Duty_Percent is Float range 0.0 .. 100.0;

   --  Opaque, non-copyable handle to a claimed channel.  Default-initialised
   --  invalid (check Is_Valid); auto-releases on scope exit.
   type Channel is limited private;

   --  Claim channel Index into C.  If it is already claimed, C is left invalid
   --  (Is_Valid False).  (If C already holds a channel it is released first.)
   procedure Claim (C : in out Channel; Index : Channel_Index);

   --  True when Claim succeeded (a real channel is held).
   function Is_Valid (C : Channel) return Boolean;

   --  Stop the output and return the channel to the free pool.  Harmless on an
   --  invalid handle.
   procedure Release (C : in out Channel);

   --  Configure C for PWM at Freq Hz with Bits of duty resolution, routed to Pin.
   --  Duty starts at 0 %.  NOTE: a channel uses timer (Index mod 4), so channels
   --  whose indices differ by 4 (e.g. 0 and 4) share a timer and therefore one
   --  frequency/resolution -- use channels 0 .. 3 for four independent frequencies.
   --  The achievable frequency depends on Bits: freq_max = 80 MHz / 2**Bits.
   procedure Configure
     (C : in out Channel; Freq : Positive; Pin : ESP32S3.GPIO.Pin_Id; Bits : Resolution := 10);

   --  Set C's duty cycle (0 .. 100 %).  Takes effect at the next period; safe
   --  without a lock because you exclusively own C.
   procedure Set_Duty (C : Channel; Percent : Duty_Percent);

   --  Force the output inactive (low) without releasing the channel.
   procedure Stop (C : Channel);

private
   type Channel is new Ada.Finalization.Limited_Controlled with record
      Idx  : Channel_Index := 0;
      Bits : Resolution := 10;   --  remembered for Set_Duty's scaling
      Held : Boolean := False;
   end record;
   overriding
   procedure Finalize (C : in out Channel);   --  stop + release on scope exit
end ESP32S3.LEDC;
