--  ES8311 audio codec -- full-duplex 440 Hz loopback -- bare-metal ESP32-S3
--  ========================================================================
--  What it demonstrates
--    Brings up an Everest ES8311 mono audio codec full-duplex: it plays a
--    click-free 440 Hz sine on the codec's DAC and, at the same time, captures
--    the codec's ADC (microphone) and estimates the tone it hears back -- a
--    loopback test (acoustic speaker -> mic, or an electrical loop).  Control
--    is over I2C; audio is over I2S.  The codec is an I2S slave clocked from
--    the ESP's MCLK = 256 * sample-rate.
--
--    Playback runs continuously on a self-looping DMA (Play_Continuous), which
--    keeps the shared I2S master clock running; capture (Capture) then samples
--    the data-in line underneath it without disturbing playback.  We estimate
--    the captured frequency by counting threshold zero-crossings -- it should
--    read ~440 Hz, confirming the mic picks up the tone.
--
--  Build & run
--    ./x run esp32s3_es8311
--    Needs the embedded runtime profile, which the example's build.sh selects
--    (ESP32S3_RTS_PROFILE=embedded).
--
--  Output
--    A banner, then `codec init: OK` once the codec ACKs on I2C and the
--    register-init sequence completes (`FAILED` = no I2C ACK: check
--    address/wiring), then one `captured: peak=... est tone=... Hz` line per
--    second.  With the board's speaker + mic the mic picks up the 440 Hz
--    playback, so each line reports ~440 Hz (+/-11 Hz is the zero-crossing
--    estimator's resolution over the ~46 ms window).
--
--  Hardware -- ES8311 codec (e.g. on the Waveshare ESP32-S3 audio board)
--    I2C control : SDA = IO8, SCL = IO7, codec at 7-bit address 0x18
--                  (CE/AD0 low; 0x19 if CE is high).
--    I2S audio   : MCLK = IO1, BCLK/SCLK = IO2, WS/LRCK = IO4,
--                  DOUT/DSDIN = IO5 (data out to the codec, playback),
--                  DIN/ASDOUT = IO3 (data in from the codec's ADC, capture).
with Interfaces;    use Interfaces;
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.GPIO;
with ESP32S3.I2C;
with ESP32S3.I2S;
with ESP32S3.ES8311;
with ESP32S3.Log; use ESP32S3.Log;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is

   Sample_Rate    : constant := 16_000;   --  I2S sample rate (Hz)
   Tone_Frequency : constant := 440;       --  test-tone frequency (Hz), concert A
   Amplitude      : constant := 30_000;    --  sine peak ~-1 dBFS (full-scale Int16)
   Mic_Gain       : constant := 24;        --  ADC PGA gain (dB), range 0 .. 42
   --  Samples are signed 16-bit per channel; the codec runs MCLK = 256 *
   --  Sample_Rate (= 4.096 MHz at 16 kHz), the 256x ratio the driver's
   --  coefficient table is built for.

   --  Codec DAC volume, 0 .. 100 %.  Reg 0x32 is 0.5 dB/step, so ~75 % ~= 0 dB
   --  (unity) and higher is positive gain (100 % ~= +32 dB) that CLIPS.  Drive
   --  loudness from a full-scale digital signal at unity codec gain, not by
   --  boosting the codec -- so this stays at 75 % and feeds the ~-1 dBFS sine.
   Dac_Volume : constant := 75;

   type Sample is new Interfaces.Integer_16;
   type Frame is record
      L, R : Sample;
   end record;
   for Frame'Size use 32;

   ----------------------------------------------------------------------------
   --  Playback: one seamless loop = the fewest whole cycles that are an integer
   --  number of samples.  gcd(16000, 440) = 40, so 11 cycles = 400 frames.
   ----------------------------------------------------------------------------
   Cycles    : constant := Tone_Frequency / 40;   --  11
   Frames    : constant := Sample_Rate / 40;      --  400
   Buf_Bytes : constant := Frames * 4;         --  1600 bytes (<= 4095)

   Cycle : array (0 .. Frames - 1) of Sample;  --  one full sine cycle

   procedure Build_Cycle is
      Half  : constant := Frames / 2;          --  200 (one half-cycle)
      Value : Integer;
   begin
      for K in 0 .. Half - 1 loop
         declare
            Parabola    : constant Integer := K * (Half - K);
            --  64-bit intermediate: Amplitude*16*Parabola reaches ~5.2e9 at
            --  full scale.
            Numerator   : constant Long_Long_Integer :=
              Long_Long_Integer (Amplitude) * 16 * Long_Long_Integer (Parabola);
            Denominator : constant Long_Long_Integer :=
              Long_Long_Integer (5 * Half * Half - 4 * Parabola);
         begin
            Value := Integer (Numerator / Denominator);
         end;
         Cycle (K) := Sample (Value);
         Cycle (K + Half) := -Sample (Value);
      end loop;
   end Build_Cycle;

   type Buffer is array (0 .. Frames - 1) of Frame;
   Buf : Buffer;                                --  the looping playback buffer

   ----------------------------------------------------------------------------
   --  Capture: one chunk we sample from the ADC and analyse.
   ----------------------------------------------------------------------------
   Capture_Frames : constant := 800;                  --  50 ms = ~22 cycles of 440 Hz
   Capture_Bytes  : constant := Capture_Frames * 4;   --  3200 bytes (<= 4095)
   type Capture_Buffer is array (0 .. Capture_Frames - 1) of Frame;
   Capture_Buf    : Capture_Buffer;

   Quiet_Peak : constant := 200;               --  captured peak below this = silence

   --  Estimate the level and frequency of the captured (left) channel.
   --
   --  Robustness: skip the first frames (RX-start FIFO-priming transient can
   --  drop a rail-value spike), remove the ADC's DC offset, and base the
   --  detection threshold on the mean-absolute-deviation rather than a
   --  single peak -- so one stray spike can't lift the threshold above the real
   --  tone.  For a sine, peak ~= 1.57 * mean-absolute-deviation.  Frequency is
   --  from threshold zero-crossings: two +/- crossings per cycle, so
   --  frequency = flips*Sample_Rate/(2*Analysed_Frames).
   Skip_Frames     : constant := 64;                       --  drop ~4 ms of startup transient
   First           : constant := Skip_Frames;              --  Capture_Buf is 0-indexed
   Analysed_Frames : constant := Capture_Frames - Skip_Frames;

   procedure Analyse (Peak : out Integer; Frequency_Hz : out Integer) is
      Sum          : Long_Long_Integer := 0;
      Mean         : Integer;
      Mean_Abs_Dev : Integer;
      Threshold    : Integer;
      State        : Integer := 0;   --  +1 above +Threshold, -1 below -Threshold, 0 unknown
      Flips        : Natural := 0;
   begin
      for I in First .. Capture_Buf'Last loop
         Sum := Sum + Long_Long_Integer (Capture_Buf (I).L);
      end loop;
      Mean := Integer (Sum / Analysed_Frames);

      Sum := 0;
      for I in First .. Capture_Buf'Last loop
         Sum := Sum + Long_Long_Integer (abs (Integer (Capture_Buf (I).L) - Mean));
      end loop;
      Mean_Abs_Dev := Integer (Sum / Analysed_Frames);
      Peak := (Mean_Abs_Dev * 157) / 100;          --  ~ sine peak, for display
      Threshold := Integer'Max (Mean_Abs_Dev / 2, 1);   --  safely below peak, above noise

      for I in First .. Capture_Buf'Last loop
         declare
            Value : constant Integer := Integer (Capture_Buf (I).L) - Mean;
         begin
            if Value > Threshold then
               if State = -1 then
                  Flips := Flips + 1;
               end if;
               State := 1;
            elsif Value < -Threshold then
               if State = 1 then
                  Flips := Flips + 1;
               end if;
               State := -1;
            end if;
         end;
      end loop;
      Frequency_Hz := Flips * Sample_Rate / (2 * Analysed_Frames);
   end Analyse;

begin
   delay until Clock + Milliseconds (200);
   Put_Line
     ("[es8311] ES8311 codec: 440 Hz test tone on the DAC output " & "(I2C control + I2S audio)");
   Build_Cycle;

   --  Frame i is at phase Cycles*i cycles: index the unit circle at
   --  (Cycles*i) mod Frames so the 400 frames carry exactly 11 cycles.
   for I in Buf'Range loop
      declare
         Sine_Sample : constant Sample := Cycle ((Cycles * I) mod Frames);
      begin
         Buf (I) := (L => Sine_Sample, R => Sine_Sample);
      end;
   end loop;

   declare
      Ok             : Boolean;
      Audio          : ESP32S3.ES8311.Output;
      Peak           : Integer;   --  estimated sine peak of the captured tone
      Estimated_Tone : Integer;   --  estimated captured frequency (Hz)
   begin
      ESP32S3.ES8311.Setup
        (I2C_Bus     => ESP32S3.I2C.I2C0,
         Sda         => 8,
         Scl         => 7,
         Port        => ESP32S3.I2S.I2S0,
         Mclk        => 1,
         Sclk        => 2,
         Lrck        => 4,
         Dsdin       => 5,
         Asdout      => 3,                        --  codec ADC out -> our data in
         Sample_Rate => Sample_Rate,
         Volume      => Dac_Volume,
         Mic_Gain_Db => Mic_Gain,
         Ok          => Ok);
      if Ok then
         Put_Line ("[es8311] codec init: OK");
      else
         Put_Line ("[es8311] codec init: FAILED (I2C no ACK? check address/wiring)");
         loop
            delay until Clock + Seconds (3600);   --  init failed: stop here
         end loop;
      end if;

      Put_Line
        ("[es8311] playing 440 Hz... (connect a speaker/headphone to " & "the codec output)");
      ESP32S3.ES8311.Acquire (Audio);          --  hold the audio port
      --  Kick the gapless loop; the DMA replays Buf forever, click-free, and
      --  keeps the I2S master clock running for capture.
      ESP32S3.ES8311.Play_Continuous (Audio, Buf'Address, Buf_Bytes);

      Put ("[es8311] mic capture on (ADC PGA ");
      Put (Mic_Gain);
      Put_Line (" dB) -- play feeds the speaker, mic should hear it");
      loop
         ESP32S3.ES8311.Capture (Audio, Capture_Buf'Address, Capture_Bytes);
         Analyse (Peak, Estimated_Tone);
         --  Below this captured-peak level the line is treated as silence, so
         --  the (meaningless) frequency estimate is suppressed.
         if Peak < Quiet_Peak then
            Put ("[es8311] captured: peak=");
            Put (Peak);
            Put_Line (" (quiet -- no tone picked up?)");
         else
            Put ("[es8311] captured: peak=");
            Put (Peak);
            Put ("  est tone=");
            Put (Estimated_Tone);
            Put_Line (" Hz");
         end if;
         delay until Clock + Milliseconds (1000);
      end loop;
   end;
end Main;
