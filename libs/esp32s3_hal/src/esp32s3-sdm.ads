with Ada.Finalization;
with ESP32S3.GPIO;

--  ESP32-S3 SDM (sigma-delta modulator) -- eight 1-bit density-modulated outputs.
--
--  Each channel emits a high-frequency pulse stream whose average density is set
--  by a signed 8-bit value; pass it through an external RC low-pass filter and
--  you get a cheap analog output (LED dimming, bias voltage, simple audio).  The
--  block lives in the GPIO sigma-delta unit (GPIO_SD).
--
--  Ownership: a channel is a shared resource handed out as a CLAIMED handle,
--  LIMITED (non-copyable) and CONTROLLED (released automatically on scope exit).
--  Uses finalization, so it targets the embedded/full profile.

package ESP32S3.SDM is

   type Channel_Index is range 0 .. 7;        --  the eight SDM channels

   subtype Density_Percent is Float range 0.0 .. 100.0;

   --  Non-copyable handle to a claimed channel (check Is_Valid after Claim).
   type Channel is limited private;

   procedure Claim (C : in out Channel; Index : Channel_Index);
   function Is_Valid (C : Channel) return Boolean;
   procedure Release (C : in out Channel);

   --  Route C's output to Pin and start it at 0 % density.  Carrier_Hz is the
   --  desired pulse-stream (sigma-delta carrier) frequency: the modulator runs at
   --  the APB clock (~80 MHz) divided by an integer 1 .. 256, so the achieved rate
   --  is the nearest APB/N -- roughly 312_500 Hz .. 80_000_000 Hz.  A higher
   --  carrier is easier to smooth with an RC low-pass; the exact value rarely
   --  matters, so it is rounded to the nearest available divider.
   procedure Configure
     (C          : in out Channel;
      Pin        : ESP32S3.GPIO.Pin_Id;
      Carrier_Hz : Positive := 1_000_000);

   --  Set the average output density (0 .. 100 %).  Single register write.
   procedure Set_Density (C : Channel; Percent : Density_Percent);

private
   type Channel is new Ada.Finalization.Limited_Controlled with record
      Idx  : Channel_Index := 0;
      Held : Boolean := False;
   end record;
   overriding
   procedure Finalize (C : in out Channel);
end ESP32S3.SDM;
