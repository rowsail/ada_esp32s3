--  TCA9555 16-bit I2C GPIO-expander driver demo on the bare-metal ESP32-S3 (no
--  FreeRTOS, no IDF).  Exercises the reusable HAL driver (ESP32S3.TCA9555)
--  against a real expander at 0x20 on the I2C bus (SDA = IO8, SCL = IO7).
--
--  It holds ONE Session for the whole test -- so the expander is protected
--  against other tasks the entire time -- while each register read / write
--  below locks the I2C host only for its own transaction and frees it again
--  (the two-level locking this driver is built around).
--
--  This board's expander pins are wired to external circuitry (the input port
--  reads a fixed pattern), so the demo deliberately NEVER drives a pin: it
--  leaves every pin an input and proves the driver another way --
--    probe     read the input port (comms check; shows the external levels).
--    out-reg   write the output REGISTER and read it back (it stores the value
--              even while the pins stay inputs, so nothing is driven).
--    pin       per-pin read-modify-write of the output register (the RMW path
--              the held Session protects).
--    pol-reg   write the polarity-inversion register and read it back.
--  To actually drive outputs (e.g. LEDs on free pins), call Set_Directions to
--  make them outputs and Write_Port / Write_Pin -- omitted here on purpose.
--  (Note: on this board's part the polarity register accepts writes but the chip
--  does not actually invert the input -- a quirk of the part, not the driver.)
--
--  Report goes through the ROM printf glue; the Ada driver does all the I2C work.
with Interfaces.C; use Interfaces.C;
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.TCA9555;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   package GPX renames ESP32S3.TCA9555;
   use type GPX.Status;
   use type GPX.Port_Value;

   procedure Banner;     pragma Import (C, Banner,    "native_tca_banner");
   procedure Probe (Inputs, Ok : int);
                         pragma Import (C, Probe,     "native_tca_probe");
   procedure No_Device;  pragma Import (C, No_Device, "native_tca_no_device");
   procedure Out_Reg (Wrote, Got, Ok : int);
                         pragma Import (C, Out_Reg,   "native_tca_outreg");
   procedure Pin_R (Pin, Wrote, Got, Ok : int);
                         pragma Import (C, Pin_R,     "native_tca_pin");
   procedure Pol_Reg (Wrote, Got, Ok : int);
                         pragma Import (C, Pol_Reg,   "native_tca_polreg");
   procedure Done;       pragma Import (C, Done,      "native_tca_done");

   Dev  : GPX.Device;
   S    : GPX.Session;
   St   : GPX.Status;
   V    : GPX.Port_Value;
   Orig : GPX.Port_Value;

   Bit5 : constant GPX.Port_Value := 2 ** 5;
   Patterns : constant array (1 .. 2) of GPX.Port_Value :=
     (16#A55A#, 16#5AA5#);

   procedure Gap is
   begin
      delay until Clock + Milliseconds (30);   --  let the console FIFO drain
   end Gap;

begin
   delay until Clock + Milliseconds (200);
   Banner;

   GPX.Setup (Dev, Addr => 0, Sda => 8, Scl => 7);
   GPX.Acquire (S, Dev);                    --  hold the expander for the test

   --  Force every pin to an input -- a known, non-driving state (independent of
   --  whatever the registers held before) so nothing fights the external wiring.
   GPX.Set_Directions (S, Inputs => 16#FFFF#, Result => St);

   --  probe: read the input port.
   GPX.Read_Port (S, Orig, St);
   Gap; Probe (int (Orig), Boolean'Pos (St = GPX.OK));
   if St /= GPX.OK then
      No_Device;
      loop
         delay until Clock + Seconds (3600);
      end loop;
   end if;

   --  out-reg round-trip: write the output register, read it back.  Pins stay
   --  inputs, so nothing is driven -- this checks the write + read path only.
   for P of Patterns loop
      GPX.Write_Port (S, P, St);
      if St = GPX.OK then
         GPX.Read_Outputs (S, V, St);
      end if;
      Gap;
      Out_Reg (int (P), int (V), Boolean'Pos (St = GPX.OK and then V = P));
   end loop;

   --  per-pin RMW of the output register.
   GPX.Write_Pin (S, 5, GPX.High, St);
   GPX.Read_Outputs (S, V, St);
   Gap;
   Pin_R (5, 1, Boolean'Pos ((V and Bit5) /= 0),
          Boolean'Pos (St = GPX.OK and then (V and Bit5) /= 0));

   GPX.Write_Pin (S, 5, GPX.Low, St);
   GPX.Read_Outputs (S, V, St);
   Gap;
   Pin_R (5, 0, Boolean'Pos ((V and Bit5) /= 0),
          Boolean'Pos (St = GPX.OK and then (V and Bit5) = 0));

   --  polarity-inversion register round-trip (write then read back).
   GPX.Set_Polarity (S, 16#A55A#, St);
   if St = GPX.OK then
      GPX.Read_Polarity (S, V, St);
   end if;
   Gap;
   Pol_Reg (16#A55A#, int (V), Boolean'Pos (St = GPX.OK and then V = 16#A55A#));
   GPX.Set_Polarity (S, 0, St);             --  restore normal polarity

   GPX.Release (S);
   Gap; Done;

   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
