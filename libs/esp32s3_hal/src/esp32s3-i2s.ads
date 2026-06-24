with System;
with Ada.Finalization;
with ESP32S3.GPIO;

--  ESP32-S3 I2S (digital audio serial bus), task-safe, DMA-driven.
--
--  Two instances (I2S0 / I2S1).  Each moves PCM samples over the GDMA crossbar
--  (the S3 I2S has no CPU FIFO -- data flows only through DMA), in standard
--  Philips/TDM format.  This driver brings a port up as a master that generates
--  BCLK + WS and shifts a sample buffer out on its data-out line (TX) and/or
--  captures one on its data-in line (RX).
--
--  Like ESP32S3.SPI, the raw register driver lives in the private child
--  ESP32S3.I2S.Engine; the application only ever sees this package.  Each port
--  is guarded by a protected object, and Acquire hands out a limited,
--  non-copyable, CONTROLLED Session that owns the port exclusively and releases
--  it automatically on scope exit (so a fault between Acquire and Release can't
--  leak the lock).  The blocking DMA transfer runs OUTSIDE the lock.  Relies on
--  finalization, so it targets the embedded/full profile.
--
--  Requires a tasking runtime (Jorvik light-tasking or richer).
package ESP32S3.I2S is

   --  The two I2S controllers.
   type I2S_Port is (I2S0, I2S1);

   --  Sample width in bits (the buffer element size the DMA moves).
   type Sample_Bits is (Bits_8, Bits_16, Bits_24, Bits_32);

   --  Data-path mode.
   --
   --  Standard : ordinary I2S/TDM -- the PCM buffer appears verbatim on the
   --             data wire (BCLK + WS framed), for a codec/DAC/ADC.
   --
   --  PDM      : the hardware sigma-delta converters sit between the buffer and
   --             the wire.  On TX the PCM2PDM converter turns each PCM sample
   --             into a 1-bit pulse-density stream (feed it to a class-D amp or
   --             an RC low-pass for analog out); on RX the PDM2PCM converter
   --             decimates a 1-bit PDM input back to PCM (a PDM microphone, or a
   --             PDM-output ADC).  The DMA still moves ordinary PCM either way,
   --             so Write/Read/Transfer are unchanged -- only the on-wire format
   --             differs.  Note the converters high-pass filter (remove DC), so
   --             a constant level does not survive a PDM round trip.
   type I2S_Mode is (Standard, PDM);

   --  Sentinel for Configure_Pins: leave that line unrouted.
   No_Pin : constant ESP32S3.GPIO.Pad_Number := ESP32S3.GPIO.No_Pin;

   --  An exclusive hold on a port.  Limited (cannot be copied) and CONTROLLED
   --  (auto-releases on scope exit, including during exception unwinding).
   type Session is limited private;

   ----------------------------------------------------------------------------
   --  One-time port configuration -- call once per port at startup, before any
   --  task contends for it (single-threaded).
   ----------------------------------------------------------------------------

   --  Bring Port up as a stereo master at (about) Sample_Rate_Hz with the given
   --  sample width and data-path mode, and Claim its GDMA channel.  In Standard
   --  mode BCLK = Sample_Rate * Bits * 2; in PDM mode the serial clock runs at
   --  Sample_Rate * 128 (the sigma-delta oversample).
   procedure Setup (Port        : I2S_Port;
                    Sample_Rate : Positive    := 16_000;
                    Bits        : Sample_Bits := Bits_16;
                    Mode        : I2S_Mode    := Standard);

   --  Internal data-line loopback through one GPIO pad (self-test; no wiring):
   --  TX and RX share WS+BCK internally (the hardware SIG_LOOPBACK bit) and the
   --  data-out signal is fed back into data-in on Pad.
   procedure Enable_Loopback (Port : I2S_Port; Pad : ESP32S3.GPIO.Pin_Id);

   --  Route the port's signals to physical pads for an external codec.  Each
   --  line is a validated GPIO pin; pass No_Pin to leave a line unrouted (e.g.
   --  Din for a TX-only DAC, or Dout for an RX-only microphone).
   --  Mclk routes the master clock out (e.g. to a codec's MCLK input); only
   --  supported on I2S0.  Leave No_Pin for codecs that clock from BCLK.
   procedure Configure_Pins (Port : I2S_Port;
                             Bclk : ESP32S3.GPIO.Optional_Pin := No_Pin;
                             Ws   : ESP32S3.GPIO.Optional_Pin := No_Pin;
                             Dout : ESP32S3.GPIO.Optional_Pin := No_Pin;
                             Din  : ESP32S3.GPIO.Optional_Pin := No_Pin;
                             Mclk : ESP32S3.GPIO.Optional_Pin := No_Pin);

   ----------------------------------------------------------------------------
   --  Concurrent, mutually-exclusive use.
   ----------------------------------------------------------------------------

   --  Raised by Acquire if Port was never Setup -- configuration must precede
   --  ownership (see the one-time configuration section above).
   Not_Initialized : exception;

   --  Raised by Write/Read/Transfer if the Session does not currently hold a
   --  port.  All reach the hardware only through one ownership-checked gateway
   --  in the body, so "transfer without holding the port" fails loudly.
   Not_Owned : exception;

   --  Take exclusive ownership of a Setup port (suspends until it is free).
   --  Raises Not_Initialized if Port was never Setup.
   procedure Acquire (S : in out Session; Port : I2S_Port);

   --  Shift Length bytes (1 .. 4095) from Tx out on the data-out line.  Blocking.
   --  Buffer in internal SRAM.  Raises Not_Owned unless S holds a port.
   procedure Write (S : Session; Tx : System.Address; Length : Natural);

   --  Capture Length bytes (1 .. 4095) from the data-in line into Rx.  Blocking.
   --  Raises Not_Owned unless S holds a port.
   procedure Read (S : Session; Rx : System.Address; Length : Natural);

   --  Full-duplex: shift Tx out and capture Rx in simultaneously (same Length).
   --  Raises Not_Owned unless S holds a port.
   procedure Transfer (S : Session; Tx, Rx : System.Address; Length : Natural);

   --  Start streaming Tx (Length bytes, 1 .. 4095) on a self-looping DMA and
   --  return immediately, leaving the TX clock running: the buffer is replayed
   --  forever with NO inter-buffer gap -- gapless playback of a periodic
   --  waveform with zero CPU cost after the call.  Tx must stay valid (in
   --  internal SRAM) and should hold a whole number of wave periods so the
   --  wrap is seamless.  Stop halts it.  Raises Not_Owned unless S holds a port.
   procedure Start_Continuous (S : Session; Tx : System.Address; Length : Natural);

   --  Stop a continuous transmit started by Start_Continuous (TX clock off).
   --  Raises Not_Owned unless S holds a port.
   procedure Stop (S : Session);

   --  Capture Length bytes (1 .. 4095) from the data-in line into Rx WITHOUT
   --  disturbing the TX path -- so it can run concurrently with a continuous
   --  transmit (Start_Continuous), which supplies the shared master clock.
   --  Blocking.  Raises Not_Owned unless S holds a port.
   procedure Capture (S : Session; Rx : System.Address; Length : Natural);

   --  Relinquish ownership (lets a waiting task proceed).  Idempotent.
   procedure Release (S : in out Session);

private
   type Session is new Ada.Finalization.Limited_Controlled with record
      Port   : I2S_Port := I2S0;
      Active : Boolean  := False;   --  holds Port's guard
   end record;
   overriding procedure Finalize (S : in out Session);   --  auto-release on scope exit
end ESP32S3.I2S;
