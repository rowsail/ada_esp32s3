--  Ada I2S PDM microphone capture demo on the bare-metal ESP32-S3 (no FreeRTOS)
--  ===========================================================================
--
--  What it demonstrates
--    The reusable HAL I2S driver's PDM mode (ESP32S3.I2S, Mode => PDM): the
--    hardware PDM->PCM decimator on the receive side -- the path a digital PDM
--    microphone (or a PDM-output ADC) uses.  In PDM mode the ESP is the clock
--    master: it drives the mic clock out on the WS pin and reads the mic's
--    1-bit pulse-density stream in on the data pin; the hardware decimates it
--    back to PCM, which the DMA delivers as ordinary 16-bit samples.  It also
--    exercises the controlled (RAII) Session: Acquire on scope entry and an
--    automatic Release on scope exit.
--
--  Build & run
--    ./x run esp32s3_i2s_pdm
--    Built as the EMBEDDED profile (build.sh sets ESP32S3_RTS_PROFILE=embedded);
--    the Session relies on finalization, which light-tasking forbids.
--
--  Output (over the USB-Serial-JTAG console, via the ROM printf glue)
--    [i2s-pdm] bare-metal I2S PDM microphone capture demo (needs an external ...
--    [i2s-pdm] wire a PDM mic: CLK <- GPIO5   DATA -> GPIO6   (plus VDD/GND)
--    [i2s-pdm] with no mic the data line floats -- expect railed/quiet; ...
--    [i2s-pdm] block 1: min=-1840 max=2010 peak-to-peak=3850 <-- signal present
--    ...
--    [i2s-pdm] capture done.
--    Per block the tail is "<-- signal present" when the capture swings above
--    the floor, "(railed -- no mic?)" when the floating input saturates the
--    decimator at a rail, or "(quiet)" otherwise.
--
--  Hardware
--    A real PDM microphone -- REQUIRED.  PDM cannot be self-tested on-chip:
--    there is no internal loopback for the converters (SIG_LOOPBACK only shares
--    the standard-I2S WS+BCK), and the decimator's mandatory high-pass filter
--    strips DC -- so any static level you could synthesise from a GPIO (a pull
--    resistor or a driven pin) is rejected and cannot stand in for a mic.
--    Genuine verification needs a real PDM device producing a toggling
--    bitstream.  Wire a PDM mic:
--
--        mic CLK  <-  GPIO 5   (Clock_Pin below -- the ESP drives this)
--        mic DATA ->  GPIO 6   (Data_Pin below)
--        mic SEL/L-R, VDD, GND per its datasheet
--
--    The demo captures several blocks and prints each block's peak-to-peak
--    level, so with a mic wired you can watch the level rise when you speak or
--    tap it.  With no mic the input floats -- expect a railed/quiet reading.
with Interfaces;    use Interfaces;  --  Integer_16'Range bounds below
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.I2S; use ESP32S3.I2S;
with ESP32S3.GPIO;
with ESP32S3.Log; use ESP32S3.Log;

--  Pull the SMP slave-start entry into the link closure (glue.c calls it after
--  elaboration); core 1 just idles -- the demo runs on core 0.
with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   --  PDM microphone pins (validated GPIO pins; the ESP drives Clock, reads
   --  Data).
   Clock_Pin : constant ESP32S3.GPIO.Pin_Id := 5;
   Data_Pin  : constant ESP32S3.GPIO.Pin_Id := 6;

   --  Audio format: 16-bit stereo PCM at 16 kHz.
   Sample_Rate_Hz : constant Positive := 16_000;

   --  Each stereo frame is two 16-bit samples (left + right).
   Samples_Per_Frame : constant := 2;

   --  16-bit stereo PCM.  256 frames = 512 words = 1024 bytes (< 4095 DMA cap).
   Frames : constant := 256;

   --  Capture this many blocks, ~one block every 100 ms (see the delay below).
   Blocks : constant := 8;

   --  The decimator's first few output frames are settling; skip them so the
   --  startup transient isn't counted in the peak-to-peak.
   Settle_Frames : constant := 8;

   --  Peak-to-peak above this counts as "signal present".
   Signal_Floor : constant := 1_500;

   --  A floating input (no mic) saturates the decimator near +/-32768; treat a
   --  capture pinned this close to either rail as railed, not as a signal.
   Rail_Threshold : constant := 32_000;

   subtype Sample_Index is Natural range 0 .. Samples_Per_Frame * Frames - 1;
   --  PCM_16 is the driver's typed signed-16-bit buffer.  Read fills it directly
   --  (byte count + width derived from the array), so the recovered samples are
   --  already signed PCM -- no Unchecked_Conversion to reinterpret raw words.
   Rx : PCM_16 (Sample_Index) := (others => 0);
begin
   delay until Clock + Milliseconds (200);
   Put_Line
     ("[i2s-pdm] bare-metal I2S PDM microphone capture demo " & "(needs an external PDM mic)");
   Put ("[i2s-pdm] wire a PDM mic: CLK <- GPIO");
   Put (Integer (Clock_Pin));
   Put ("   DATA -> GPIO");
   Put (Integer (Data_Pin));
   Put_Line ("   (plus VDD/GND)");
   Put_Line
     ("[i2s-pdm] with no mic the data line floats -- expect "
      & "railed/quiet; speak/tap to see the level rise");

   for Block in 1 .. Blocks loop
      declare
         Session_Port : Session;          --  limited: cannot be copied/shared
         Minimum      : Integer := Integer (Integer_16'Last);
         Maximum      : Integer := Integer (Integer_16'First);
         Value        : Integer;
      begin
         --  PDM mic: clock OUT on Ws, data IN on Din (no BCK, no Dout for
         --  RX-only).  The first Acquire brings the port up at this config and
         --  routes the pins; later iterations reuse it.
         Acquire
           (Session_Port,
            I2S0,
            Sample_Rate => Sample_Rate_Hz,
            Bits        => Bits_16,
            Mode        => PDM,
            Ws          => ESP32S3.GPIO.Optional_Pin (Clock_Pin),
            Din         => ESP32S3.GPIO.Optional_Pin (Data_Pin));
         Read (Session_Port, Rx);   --  typed: PDM mic -> signed PCM_16

         --  Peak-to-peak of the recovered left channel (even index), skipping a
         --  few startup frames so the decimator settle isn't counted.
         for Frame in Settle_Frames .. Frames - 1 loop
            Value := Integer (Rx (Samples_Per_Frame * Frame));
            Minimum := Integer'Min (Minimum, Value);
            Maximum := Integer'Max (Maximum, Value);
         end loop;

         --  "Signal" only if the capture both swings (> Signal_Floor) AND is
         --  not pinned at a rail -- a floating input (no mic) saturates the
         --  decimator near -32768, which must not read as a present signal.
         declare
            Railed : constant Boolean :=
              Minimum <= -Rail_Threshold or else Maximum >= Rail_Threshold;
            Signal : constant Boolean := not Railed and then Maximum - Minimum > Signal_Floor;
         begin
            Put ("[i2s-pdm] block ");
            Put (Block);
            Put (": min=");
            Put (Minimum);
            Put (" max=");
            Put (Maximum);
            Put (" peak-to-peak=");
            Put (Maximum - Minimum);
            Put (" ");
            Put_Line
              (if Signal
               then "<-- signal present"
               elsif Railed
               then "(railed -- no mic?)"
               else "(quiet)");
         end;
      end;                                --  Session_Port finalizes -> released

      delay until Clock + Milliseconds (100);
   end loop;

   Put_Line ("[i2s-pdm] capture done.");

   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
