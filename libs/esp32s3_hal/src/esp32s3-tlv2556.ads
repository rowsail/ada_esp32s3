with System;
with ESP32S3.SPI;
with ESP32S3.GPIO;

--  Texas Instruments TLV2556 -- 12-bit, 11-channel, 200-kSPS low-power SPI ADC
--  with an internal reference (bare-metal, task-safe).
--
--  The TLV2556 has an SPI-compatible serial interface (SPI mode 0): each I/O
--  cycle clocks an 8-bit command in on DATA IN (the top four bits select the
--  analog input or a command, the low four are configuration register 1) while
--  simultaneously clocking the PREVIOUS conversion's result out on DATA OUT,
--  MSB first.  The converter is therefore PIPELINED -- the result of a channel
--  you address now is read on the next cycle -- which Read hides by priming the
--  conversion, waiting it out, then reading it back.
--
--  Like ESP32S3.W25Q, the chip select is application-driven through an
--  ESP32S3.SPI.CS_Select callback (active-low here), so the ADC can share a bus
--  with other devices.  This driver always uses 16-clock (2-byte) transfers and
--  unipolar, MSB-first output.  Requires a tasking runtime (the controlled SPI
--  Session) -- embedded/full profile.

package ESP32S3.TLV2556 is

   --  A 12-bit unipolar conversion result (0 = REF-, 4095 = full scale at REF+).
   type Sample is range 0 .. 4095;

   --  What to convert: one of the 11 analog inputs (AIN0 .. AIN10), or one of
   --  the three internal self-test voltages.  The self-tests are ratiometric to
   --  the reference rails, so they read fixed codes regardless of the reference
   --  voltage or any analog wiring -- ideal for a bring-up check:
   --    Test_Zero -> 0, Test_Half -> 2048, Test_Full -> 4095.
   --  (The enumeration order matches the chip's command nibbles 0 .. 13.)
   type Analog_Input is
     (AIN0,
      AIN1,
      AIN2,
      AIN3,
      AIN4,
      AIN5,
      AIN6,
      AIN7,
      AIN8,
      AIN9,
      AIN10,
      Test_Half,
      Test_Zero,
      Test_Full);

   --  Reference source, chosen at Initialize: the internal 4.096-V or 2.048-V
   --  reference, or an external reference on REF+/REF- (the chip's power-on
   --  default).  With Internal_4096mV one LSB is exactly 1 mV.
   type Reference is (Internal_4096mV, Internal_2048mV, External);

   --  An ADC device: which SPI host, and how its chip select is driven.  For the
   --  common case set CS_Pin to the select GPIO -- the SPI driver drives it
   --  (active-low, held across each conversion).  For a select that is not one
   --  plain GPIO (a decoder / I/O-expander), leave CS_Pin = No_Pin and supply
   --  CS_CB + Ctx (see ESP32S3.SPI.CS_Select for the callback contract).
   type Device is record
      Host     : ESP32S3.SPI.SPI_Host;
      Clock_Hz : Positive := 8_000_000;   --  TLV2556 I/O <=10 MHz
      CS_Pin   : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      CS_CB    : ESP32S3.SPI.CS_Select := null;
      Ctx      : System.Address := System.Null_Address;
   end record;

   --  Program configuration register 2 (reference source, pin-19 = EOC, normal
   --  mode).  Call once, after the SPI host's Setup, before any
   --  Read.  The first conversion after power-up is discarded internally.
   procedure Initialize (Dev : Device; Ref : Reference := External);

   --  Convert one input and return its 12-bit result.  Self-contained: it primes
   --  the conversion, waits out the (max ~5.5 us) conversion time, and reads the
   --  result back, hiding the chip's pipeline.
   function Read (Dev : Device; Input : Analog_Input) return Sample;

   --  Convert a result to millivolts for the given reference (External returns 0
   --  -- the full scale is the board's REF+, which only the application knows).
   function Millivolts (S : Sample; Ref : Reference) return Natural
   with Post => (if Ref = External then Millivolts'Result = 0);

end ESP32S3.TLV2556;
