--  ES8311 audio-codec full-duplex test: play a gapless 440 Hz sine on the DAC
--  and, at the same time, capture the codec's ADC (microphone) and estimate the
--  tone we hear back -- a loopback test (acoustic, speaker -> mic, or electrical).
--
--  Control is over I2C (SDA=IO8, SCL=IO7); audio is over I2S (MCLK=IO1, SCLK=IO2,
--  LRCK=IO4, DSDIN=IO5 out to the codec, ASDOUT=IO3 in from the codec's ADC).
--  The codec is an I2S slave clocked from the ESP's MCLK = 256*fs.
--
--  Playback runs continuously on a self-looping DMA (Play_Continuous), which
--  keeps the shared I2S master clock running; capture (Capture) then samples the
--  data-in line underneath it without disturbing playback.  We estimate the
--  captured frequency by counting threshold zero-crossings -- it should read
--  ~440 Hz, confirming the mic picks up the tone.
with Interfaces;    use Interfaces;
with Interfaces.C;  use Interfaces.C;
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.GPIO;
with ESP32S3.I2C;
with ESP32S3.I2S;
with ESP32S3.ES8311;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   procedure Banner;             pragma Import (C, Banner, "native_es_banner");
   procedure Init_R (Ok : int);  pragma Import (C, Init_R, "native_es_init");
   procedure Playing;            pragma Import (C, Playing, "native_es_playing");
   procedure Listening (Gain : int);
   pragma Import (C, Listening, "native_es_listening");
   procedure Captured (Peak, Freq : int);
   pragma Import (C, Captured, "native_es_captured");

   Rate     : constant := 16_000;      --  sample rate (Hz)
   Freq     : constant := 440;         --  tone frequency (Hz)
   Amp      : constant := 30_000;      --  ~-1 dBFS peak (full-scale Int16)
   Mic_Gain : constant := 24;          --  ADC PGA gain (dB)

   type Sample is new Interfaces.Integer_16;
   type Frame is record
      L, R : Sample;
   end record;
   for Frame'Size use 32;

   ----------------------------------------------------------------------------
   --  Playback: one seamless loop = the fewest whole cycles that are an integer
   --  number of samples.  gcd(16000, 440) = 40, so 11 cycles = 400 frames.
   ----------------------------------------------------------------------------
   Cycles    : constant := Freq / 40;          --  11
   Frames    : constant := Rate / 40;          --  400
   Buf_Bytes : constant := Frames * 4;         --  1600 bytes (<= 4095)

   Cycle : array (0 .. Frames - 1) of Sample;  --  one full sine cycle

   procedure Build_Cycle is
      Half : constant := Frames / 2;           --  200 (one half-cycle)
      V    : Integer;
   begin
      for K in 0 .. Half - 1 loop
         declare
            P   : constant Integer := K * (Half - K);
            --  64-bit intermediate: Amp*16*P reaches ~5.2e9 at full scale.
            Num : constant Long_Long_Integer :=
              Long_Long_Integer (Amp) * 16 * Long_Long_Integer (P);
            Den : constant Long_Long_Integer :=
              Long_Long_Integer (5 * Half * Half - 4 * P);
         begin
            V := Integer (Num / Den);
         end;
         Cycle (K)        :=  Sample (V);
         Cycle (K + Half) := -Sample (V);
      end loop;
   end Build_Cycle;

   type Buffer is array (0 .. Frames - 1) of Frame;
   Buf : Buffer;                                --  the looping playback buffer

   ----------------------------------------------------------------------------
   --  Capture: one chunk we sample from the ADC and analyse.
   ----------------------------------------------------------------------------
   Cap_Frames : constant := 800;               --  50 ms = ~22 cycles of 440 Hz
   Cap_Bytes  : constant := Cap_Frames * 4;    --  3200 bytes (<= 4095)
   type Cap_Buffer is array (0 .. Cap_Frames - 1) of Frame;
   Cap : Cap_Buffer;

   --  Estimate the level and frequency of the captured (left) channel.
   --
   --  Robustness: skip the first frames (RX-start FIFO-priming transient can
   --  drop a rail-value spike), remove the ADC's DC offset, and base the
   --  detection threshold on the mean-absolute-deviation (MAD) rather than a
   --  single peak -- so one stray spike can't lift the threshold above the real
   --  tone.  For a sine, peak ~= 1.57 * MAD.  Frequency is from threshold
   --  zero-crossings: two +/- crossings per cycle, so freq = flips*Rate/(2*N).
   Skip  : constant := 64;                   --  drop ~4 ms of startup transient
   First : constant := Skip;                 --  Cap is 0-indexed
   N_An  : constant := Cap_Frames - Skip;    --  frames actually analysed

   procedure Analyse (Peak : out Integer; Freq_Hz : out Integer) is
      Sum   : Long_Long_Integer := 0;
      Mean  : Integer;
      MAD   : Integer;
      Thr   : Integer;
      State : Integer := 0;        --  +1 above +Thr, -1 below -Thr, 0 unknown
      Flips : Natural := 0;
   begin
      for I in First .. Cap'Last loop
         Sum := Sum + Long_Long_Integer (Cap (I).L);
      end loop;
      Mean := Integer (Sum / N_An);

      Sum := 0;
      for I in First .. Cap'Last loop
         Sum := Sum + Long_Long_Integer (abs (Integer (Cap (I).L) - Mean));
      end loop;
      MAD  := Integer (Sum / N_An);
      Peak := (MAD * 157) / 100;              --  ~ sine peak, for display
      Thr  := Integer'Max (MAD / 2, 1);       --  safely below peak, above noise

      for I in First .. Cap'Last loop
         declare
            V : constant Integer := Integer (Cap (I).L) - Mean;
         begin
            if V > Thr then
               if State = -1 then
                  Flips := Flips + 1;
               end if;
               State := 1;
            elsif V < -Thr then
               if State = 1 then
                  Flips := Flips + 1;
               end if;
               State := -1;
            end if;
         end;
      end loop;
      Freq_Hz := Flips * Rate / (2 * N_An);
   end Analyse;

begin
   delay until Clock + Milliseconds (200);
   Banner;
   Build_Cycle;

   --  Frame i is at phase Cycles*i cycles: index the unit circle at
   --  (Cycles*i) mod Frames so the 400 frames carry exactly 11 cycles.
   for I in Buf'Range loop
      declare
         S : constant Sample := Cycle ((Cycles * I) mod Frames);
      begin
         Buf (I) := (L => S, R => S);
      end;
   end loop;

   declare
      Ok    : Boolean;
      Audio : ESP32S3.ES8311.Output;
      Peak, Est : Integer;
   begin
      ESP32S3.ES8311.Setup
        (I2C_Bus => ESP32S3.I2C.I2C0,
         Sda     => 8,  Scl   => 7,
         Port    => ESP32S3.I2S.I2S0,
         Mclk    => 1,  Sclk  => 2,  Lrck => 4,  Dsdin => 5,
         Asdout  => 3,                        --  codec ADC out -> our data in
         Sample_Rate => Rate, Volume => 75, Mic_Gain_Db => Mic_Gain, Ok => Ok);
      Init_R (Boolean'Pos (Ok));
      if not Ok then
         loop delay until Clock + Seconds (3600); end loop;
      end if;

      Playing;
      ESP32S3.ES8311.Acquire (Audio);          --  hold the audio port
      --  Kick the gapless loop; the DMA replays Buf forever, click-free, and
      --  keeps the I2S master clock running for capture.
      ESP32S3.ES8311.Play_Continuous (Audio, Buf'Address, Buf_Bytes);

      Listening (int (Mic_Gain));
      loop
         ESP32S3.ES8311.Capture (Audio, Cap'Address, Cap_Bytes);
         Analyse (Peak, Est);
         Captured (int (Peak), int (Est));
         delay until Clock + Milliseconds (1000);
      end loop;
   end;
end Main;
