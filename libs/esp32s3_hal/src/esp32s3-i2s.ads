with System;
with Interfaces;
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

   --  Typed PCM sample buffers -- the idiomatic way to move audio.  The element
   --  type fixes the on-wire width, so the driver derives the byte count itself
   --  (no caller-side "* 2") and the typed Write/Read/Transfer below CHECK the
   --  buffer's width against the port's configured Bits.  Signed two's-complement,
   --  as PCM is.  A PCM_32 buffer carries 24- or 32-bit samples (both occupy a
   --  32-bit slot).  For raw, already-framed bytes (a foreign/DMA buffer built
   --  elsewhere, an opaque bit-pattern self-test) use the *_Raw primitives.
   type PCM_8 is array (Natural range <>) of Interfaces.Integer_8;
   type PCM_16 is array (Natural range <>) of Interfaces.Integer_16;
   type PCM_32 is array (Natural range <>) of Interfaces.Integer_32;

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
   --  Concurrent, mutually-exclusive use.  Acquire a port AND configure it in
   --  the same call; every transfer plus every later reconfiguration runs
   --  through the held Session.  There is no port-based setup that precedes
   --  ownership: you cannot touch a port without holding it.
   --
   --  Because bringing a port up claims a GDMA channel (a heavyweight, once-per-
   --  port resource), the FIRST Acquire of a port opens it at the given config
   --  and later Acquires reuse it as-is (they do not re-open or inherit a new
   --  config); call Reconfigure on the held port to change the audio format.
   ----------------------------------------------------------------------------

   --  Raised by any operation below if the Session does not currently hold a
   --  port.  All reach the hardware only through one ownership-checked gateway
   --  in the body, so "transfer without holding the port" fails loudly.
   Not_Owned : exception;

   --  Take exclusive ownership of Port (suspends until it is free) and, on the
   --  first Acquire of the port, bring it up as a stereo master at (about)
   --  Sample_Rate with the given sample width and data-path mode, claim its GDMA
   --  channel, and route the signals to pads.  In Standard mode BCLK =
   --  Sample_Rate * Bits * 2; in PDM mode the serial clock runs at Sample_Rate
   --  * 128 (the sigma-delta oversample).  Each pin is optional (No_Pin =
   --  unrouted), so a link routes only what it uses (e.g. Din for a TX-only DAC,
   --  Dout for an RX-only mic).  Mclk routes the master clock out (a codec's
   --  MCLK input); only on I2S0.  Leave No_Pin for codecs that clock from BCLK.
   procedure Acquire
     (S           : in out Session;
      Port        : I2S_Port;
      Sample_Rate : Positive := 16_000;
      Bits        : Sample_Bits := Bits_16;
      Mode        : I2S_Mode := Standard;
      Bclk        : ESP32S3.GPIO.Optional_Pin := No_Pin;
      Ws          : ESP32S3.GPIO.Optional_Pin := No_Pin;
      Dout        : ESP32S3.GPIO.Optional_Pin := No_Pin;
      Din         : ESP32S3.GPIO.Optional_Pin := No_Pin;
      Mclk        : ESP32S3.GPIO.Optional_Pin := No_Pin);

   --  Re-open the held port at a new audio format and pin routing (re-claims the
   --  GDMA channel).  Use this to change sample rate / width / mode on a port
   --  you already hold.  Raises Not_Owned unless S holds the port.
   procedure Reconfigure
     (S           : Session;
      Sample_Rate : Positive := 16_000;
      Bits        : Sample_Bits := Bits_16;
      Mode        : I2S_Mode := Standard;
      Bclk        : ESP32S3.GPIO.Optional_Pin := No_Pin;
      Ws          : ESP32S3.GPIO.Optional_Pin := No_Pin;
      Dout        : ESP32S3.GPIO.Optional_Pin := No_Pin;
      Din         : ESP32S3.GPIO.Optional_Pin := No_Pin;
      Mclk        : ESP32S3.GPIO.Optional_Pin := No_Pin);

   --  Re-route the held port's signals to physical pads (a finer change than
   --  Reconfigure, leaving the audio format untouched).  Raises Not_Owned unless
   --  S holds the port.
   procedure Configure_Pins
     (S    : Session;
      Bclk : ESP32S3.GPIO.Optional_Pin := No_Pin;
      Ws   : ESP32S3.GPIO.Optional_Pin := No_Pin;
      Dout : ESP32S3.GPIO.Optional_Pin := No_Pin;
      Din  : ESP32S3.GPIO.Optional_Pin := No_Pin;
      Mclk : ESP32S3.GPIO.Optional_Pin := No_Pin);

   --  Internal data-line loopback through one GPIO pad (self-test; no wiring):
   --  TX and RX share WS+BCK internally (the hardware SIG_LOOPBACK bit) and the
   --  data-out signal is fed back into data-in on Pad, on the held port.  Raises
   --  Not_Owned unless S holds the port.
   procedure Enable_Loopback (S : Session; Pad : ESP32S3.GPIO.Pin_Id);

   --  The sample width the held port is currently configured for (the Bits of
   --  its most recent Acquire/Reconfigure).  Raises Not_Owned unless S holds the
   --  port.  The typed transfers below use it in their preconditions.
   function Configured_Bits (S : Session) return Sample_Bits;

   ----------------------------------------------------------------------------
   --  Transfers come in two layers.
   --
   --    * Typed (preferred): pass a PCM_8/16/32 buffer.  The driver derives the
   --      byte count from the array, and a precondition checks the buffer's
   --      element width matches the port's configured Bits -- a PCM_16 buffer on
   --      a Bits_24 port is a contract violation, caught, not silent noise.
   --
   --    * *_Raw (escape hatch): a 'Address + byte Length, for bytes already
   --      framed elsewhere -- a foreign/DMA buffer, an opaque bit-pattern test.
   --
   --  Buffers live in internal SRAM; the byte count is 1 .. 4095.  All raise
   --  Not_Owned unless S holds the port.
   ----------------------------------------------------------------------------

   --  Shift a buffer out on the data-out line.  Blocking.
   procedure Write (S : Session; Samples : PCM_8)
   with Pre => Configured_Bits (S) = Bits_8;
   procedure Write (S : Session; Samples : PCM_16)
   with Pre => Configured_Bits (S) = Bits_16;
   procedure Write (S : Session; Samples : PCM_32)
   with Pre => Configured_Bits (S) in Bits_24 | Bits_32;
   procedure Write_Raw (S : Session; Tx : System.Address; Length : Natural);

   --  Capture from the data-in line into a buffer.  Blocking.
   procedure Read (S : Session; Samples : out PCM_8)
   with Pre => Configured_Bits (S) = Bits_8;
   procedure Read (S : Session; Samples : out PCM_16)
   with Pre => Configured_Bits (S) = Bits_16;
   procedure Read (S : Session; Samples : out PCM_32)
   with Pre => Configured_Bits (S) in Bits_24 | Bits_32;
   procedure Read_Raw (S : Session; Rx : System.Address; Length : Natural);

   --  Full-duplex: shift Tx out and capture Rx in simultaneously (same length).
   procedure Transfer (S : Session; Tx : PCM_8; Rx : out PCM_8)
   with Pre => Configured_Bits (S) = Bits_8 and then Tx'Length = Rx'Length;
   procedure Transfer (S : Session; Tx : PCM_16; Rx : out PCM_16)
   with Pre => Configured_Bits (S) = Bits_16 and then Tx'Length = Rx'Length;
   procedure Transfer (S : Session; Tx : PCM_32; Rx : out PCM_32)
   with
     Pre =>
       Configured_Bits (S) in Bits_24 | Bits_32 and then Tx'Length = Rx'Length;
   procedure Transfer_Raw
     (S : Session; Tx, Rx : System.Address; Length : Natural);

   --  Start a self-looping DMA that replays the buffer forever with NO
   --  inter-buffer gap and return immediately, leaving the TX clock running --
   --  gapless playback of a periodic waveform at zero CPU cost after the call.
   --  The buffer must stay valid (internal SRAM) and should hold a whole number
   --  of wave periods so the wrap is seamless.  Stop halts it.
   procedure Start_Continuous (S : Session; Samples : PCM_8)
   with Pre => Configured_Bits (S) = Bits_8;
   procedure Start_Continuous (S : Session; Samples : PCM_16)
   with Pre => Configured_Bits (S) = Bits_16;
   procedure Start_Continuous (S : Session; Samples : PCM_32)
   with Pre => Configured_Bits (S) in Bits_24 | Bits_32;
   procedure Start_Continuous_Raw
     (S : Session; Tx : System.Address; Length : Natural);

   --  Stop a continuous transmit started by Start_Continuous (TX clock off).
   --  Raises Not_Owned unless S holds the port.
   procedure Stop (S : Session);

   --  Capture into a buffer WITHOUT disturbing the TX path -- so it can run
   --  concurrently with a continuous transmit (Start_Continuous), which supplies
   --  the shared master clock.  Blocking.
   procedure Capture (S : Session; Samples : out PCM_8)
   with Pre => Configured_Bits (S) = Bits_8;
   procedure Capture (S : Session; Samples : out PCM_16)
   with Pre => Configured_Bits (S) = Bits_16;
   procedure Capture (S : Session; Samples : out PCM_32)
   with Pre => Configured_Bits (S) in Bits_24 | Bits_32;
   procedure Capture_Raw (S : Session; Rx : System.Address; Length : Natural);

   --  Relinquish ownership (lets a waiting task proceed).  Idempotent.
   procedure Release (S : in out Session);

private
   type Session is new Ada.Finalization.Limited_Controlled with record
      Port   : I2S_Port := I2S0;
      Active : Boolean := False;   --  holds Port's guard
   end record;
   overriding
   procedure Finalize (S : in out Session);   --  auto-release on scope exit
end ESP32S3.I2S;
