with Ada.Finalization;
with System;
with ESP32S3.GPIO;
with ESP32S3.I2C;
with ESP32S3.I2S;

--  ESP32-S3 driver for the Everest ES8311 low-power mono audio codec.
--
--  The ES8311 is controlled over I2C and carries audio over I2S.  This driver
--  brings it up for AUDIO OUTPUT (the mono DAC): it runs the I2C register-init
--  sequence and configures an I2S port as the master that generates MCLK, BCLK
--  (SCLK) and LRCK and shifts 16-bit PCM out on the codec's DSDIN line.  The
--  codec runs as an I2S slave clocked from the ESP's MCLK = 256 x sample-rate
--  (4.096 MHz at 16 kHz); the register coefficients are the codec-vendor's for
--  that 256x / 16-bit configuration (rate-independent).
--
--  Concurrent access is guarded the same way as the other drivers: audio output
--  goes through a limited, non-copyable, CONTROLLED Output handle that owns the
--  I2S port exclusively and releases it automatically on scope exit.  Requires a
--  tasking runtime (embedded/full profile), like ESP32S3.I2S.
--
--  Register sequence + clock coefficients ported from Espressif's es8311 driver
--  (esp-bsp); see the example README for the source links.
package ESP32S3.ES8311 is

   --  I2C 7-bit address: 0x18 with CE/AD0 low (default), 0x19 with CE high.
   subtype Address is ESP32S3.I2C.Slave_Address;
   Default_Address : constant Address := 16#18#;

   ----------------------------------------------------------------------------
   --  One-time bring-up -- call once at startup, single-threaded, before any
   --  task contends for the audio port.
   ----------------------------------------------------------------------------

   --  Initialise the codec for 16-bit output at Sample_Rate (the I2S then runs
   --  MCLK = 256 x Sample_Rate).  Sda/Scl are the I2C control pins (the bus is
   --  brought up here); Mclk/Sclk/Lrck/Dsdin are the I2S pads.  The codec's
   --  ASDOUT (its ADC out) is not used for output and is left unwired.
   --  Ok is False if the codec did not ACK on I2C (check wiring/address).
   --  Asdout is the codec's ADC data-out line (the ESP's data-in).  Leave it
   --  No_Pin for output only; pass a pin (e.g. IO3) to also bring up the ADC /
   --  microphone capture path, then read it with Capture.  Mic_Gain_Db sets the
   --  ADC PGA gain in 6 dB steps (0 .. 42 dB), used only when Asdout is given.
   procedure Setup
     (I2C_Bus      : ESP32S3.I2C.I2C_Host;
      Sda          : ESP32S3.GPIO.Pin_Id;
      Scl          : ESP32S3.GPIO.Pin_Id;
      Port         : ESP32S3.I2S.I2S_Port;
      Mclk         : ESP32S3.GPIO.Pin_Id;
      Sclk         : ESP32S3.GPIO.Pin_Id;
      Lrck         : ESP32S3.GPIO.Pin_Id;
      Dsdin        : ESP32S3.GPIO.Pin_Id;
      Asdout       : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Sample_Rate  : Positive := 16_000;
      Volume       : Natural  := 70;          --  DAC volume, 0 .. 100 %
      Mic_Gain_Db  : Natural  := 24;          --  ADC PGA gain, 0 .. 42 dB
      I2C_Clock_Hz : Positive := 100_000;
      Addr         : Address  := Default_Address;
      Ok           : out Boolean);

   --  Set the DAC output volume (0 .. 100 %).  Setup must have run.
   procedure Set_Volume (Percent : Natural; Ok : out Boolean);

   ----------------------------------------------------------------------------
   --  Concurrent, mutually-exclusive audio output.
   ----------------------------------------------------------------------------

   --  Raised by Acquire if Setup was never run.
   Not_Ready : exception;

   --  An exclusive hold on the codec's audio (I2S) port.  Limited (cannot be
   --  copied) and CONTROLLED (auto-releases on scope exit, incl. on exception).
   type Output is limited private;

   --  Take exclusive ownership of the audio port (suspends until it is free).
   procedure Acquire (O : in out Output);

   --  Shift Length BYTES of 16-bit PCM (interleaved L/R frames; the mono codec
   --  plays the left slot) out to the codec.  Blocking; Length 1 .. 4095.  Note
   --  back-to-back Play calls leave a brief gap between buffers (an audible
   --  click for a continuous tone); use Play_Continuous for gapless playback.
   procedure Play (O : Output; Samples : System.Address; Length : Natural);

   --  Start playing the Samples buffer on a self-looping DMA and return
   --  immediately: it is replayed forever with NO gap between passes (gapless,
   --  click-free) and zero CPU cost after the call.  Samples must stay valid
   --  (in internal SRAM) and should hold a whole number of wave periods so the
   --  wrap is seamless -- e.g. for a steady tone, size the buffer to an integer
   --  number of cycles.  Length 1 .. 4095 bytes.  Stop halts it.
   procedure Play_Continuous (O : Output; Samples : System.Address;
                              Length : Natural);

   --  Stop a continuous playback started by Play_Continuous.
   procedure Stop (O : Output);

   --  Capture Length BYTES of 16-bit PCM from the codec's ADC (microphone) into
   --  Samples.  Setup must have been given an Asdout pin.  Blocking, and does
   --  NOT disturb playback -- so you can capture while Play_Continuous keeps the
   --  tone (and the shared master clock) running.  The mono ADC fills the left
   --  slot of each stereo frame.  Length 1 .. 4095.
   procedure Capture (O : Output; Samples : System.Address; Length : Natural);

   --  Relinquish the port (also done automatically on scope exit).
   procedure Release (O : in out Output);

private
   --  Output owns an I2S.Session, whose own finalization releases the port -- so
   --  Output is limited (non-copyable) and auto-releasing without extra code.
   type Output is limited record
      Audio : ESP32S3.I2S.Session;
   end record;
end ESP32S3.ES8311;
