--  Ada I2S self-test on the bare-metal ESP32-S3 (no FreeRTOS, no IDF)
--  ==================================================================
--
--  What it demonstrates
--    The reusable HAL I2S driver (ESP32S3.I2S).  It brings I2S0 up as a stereo
--    16-bit master, loops its data-out line back into data-in through ONE GPIO
--    pad, then DMAs a buffer out and captures it back full-duplex in a single
--    Transfer and compares it word for word.  The S3 I2S has no CPU FIFO, so
--    data moves only over the GDMA crossbar -- this exercises the whole DMA
--    path, real serial framing and round-trip, not a register echo.  It also
--    exercises the controlled (RAII) Session: Acquire on scope entry and an
--    automatic Release on scope exit.
--
--  Build & run
--    ./x run esp32s3_i2s_loopback
--    Built as the EMBEDDED profile (build.sh sets ESP32S3_RTS_PROFILE=embedded);
--    the Session relies on finalization, which light-tasking forbids.
--
--  Output (over the USB-Serial-JTAG console, via the ROM printf glue)
--    [i2s] bare-metal I2S full-duplex DMA loopback self-test (no wiring)
--    [i2s] full-duplex loopback (64 samples): PASS
--    [i2s] done.
--
--  Hardware
--    None (self-contained, no wiring).  The hardware SIG_LOOPBACK bit makes the
--    transmitter and receiver share WS + BCK internally, and the data-out signal
--    is fed back into data-in on a single GPIO pad through the signal matrix --
--    so no external BCLK/WS/DOUT/DIN routing and no loopback jumper are needed.

with Interfaces;   use Interfaces;
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.I2S;   use ESP32S3.I2S;
with ESP32S3.GPIO;
with ESP32S3.Log;   use ESP32S3.Log;

--  Pull the SMP slave-start entry into the link closure (glue.c calls it after
--  elaboration); core 1 just idles -- the test runs on core 0.
with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is

   --  The single GPIO pad the data-out signal is fed back into data-in on; no
   --  external wiring, the matrix routes it internally (see header).
   Loopback_Data_Pad : constant ESP32S3.GPIO.Pin_Id := 4;

   --  Audio format: 16-bit stereo at 16 kHz.
   Sample_Rate_Hz : constant Positive := 16_000;

   --  Each sample is one 16-bit word = 2 bytes; the DMA byte count is the word
   --  count times this.
   Bytes_Per_Sample : constant := 2;

   --  Test pattern.  Fill Tx with a cheap full-range pseudo-random ramp so a
   --  word swap or a stuck line shows up: sample I = (I * Step + Offset) mod
   --  2**16.  The constants are arbitrary (a large odd stride + an odd offset);
   --  they only need to make the 64 words distinct and span the 16-bit range.
   Pattern_Step   : constant := 1031;
   Pattern_Offset : constant := 17;
   Pattern_Modulus : constant := 65536;   --  2**16 -- wrap into Unsigned_16

   --  64 words = 32 stereo frames = 128 bytes.
   type Samples is array (0 .. 63) of Unsigned_16;
   Tx : Samples;
   Rx : Samples := (others => 0);
begin
   delay until Clock + Milliseconds (200);
   Put_Line ("[i2s] bare-metal I2S full-duplex DMA loopback self-test "
             & "(no wiring)");

   for I in Samples'Range loop
      Tx (I) := Unsigned_16 ((I * Pattern_Step + Pattern_Offset) mod
                             Pattern_Modulus);
   end loop;

   Setup (I2S0, Sample_Rate => Sample_Rate_Hz, Bits => Bits_16);
   Enable_Loopback (I2S0, Pad => Loopback_Data_Pad);

   declare
      S  : Session;                       --  limited: cannot be copied/shared
      Ok : Boolean := False;
   begin
      Acquire (S, I2S0);                  --  suspends until the port is free
      Transfer (S, Tx'Address, Rx'Address, Samples'Length * Bytes_Per_Sample);
      Ok := (for all I in Samples'Range => Rx (I) = Tx (I));
      Put ("[i2s] full-duplex loopback (");
      Put (Samples'Length);
      Put (" samples): ");
      Put_Line (if Ok then "PASS" else "FAIL");
   end;                                   --  S finalizes -> port released

   Put_Line ("[i2s] done.");

   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
