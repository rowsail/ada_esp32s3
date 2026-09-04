with System;
with ESP32S3.GDMA;
with ESP32S3.GPIO;
with ESP32S3_Registers.I2S;

--  RAW I2S0/I2S1 register driver -- the ZFP-safe *mechanism* with NO mutual
--  exclusion.  PRIVATE child: only the ESP32S3.I2S subtree may use it.  See the
--  parent (ESP32S3.I2S) for the design rationale.

private package ESP32S3.I2S.Engine is

   --  A configured port.  No GDMA channel is held while idle: a one-shot
   --  transfer claims one transiently (released as soon as it returns), and a
   --  continuous transmit holds one in Chan only until Stop.  Limited because
   --  Chan is a (limited, controlled) GDMA Channel.
   type Bus is limited private;

   procedure Open
     (B           : in out Bus;
      Port        : I2S_Port;
      Sample_Rate : Positive;
      Bits        : Sample_Bits;
      Mode        : I2S_Mode)
   with Post => Is_Open (B);

   function Is_Open (B : Bus) return Boolean;

   procedure Configure_Pins
     (B    : Bus;
      Bclk : ESP32S3.GPIO.Optional_Pin;
      Ws   : ESP32S3.GPIO.Optional_Pin;
      Dout : ESP32S3.GPIO.Optional_Pin := No_Pin;
      Din  : ESP32S3.GPIO.Optional_Pin := No_Pin;
      Mclk : ESP32S3.GPIO.Optional_Pin := No_Pin)
   with Pre => Is_Open (B);

   procedure Enable_Loopback (B : Bus; Pad : ESP32S3.GPIO.Pin_Id)
   with Pre => Is_Open (B);

   procedure Write (B : Bus; Tx : System.Address; Length : Natural)
   with Pre => Is_Open (B) and then Length in 1 .. 4095;
   procedure Read (B : Bus; Rx : System.Address; Length : Natural)
   with Pre => Is_Open (B) and then Length in 1 .. 4095;
   procedure Transfer (B : Bus; Tx, Rx : System.Address; Length : Natural)
   with Pre => Is_Open (B) and then Length in 1 .. 4095;

   --  Start the TX path streaming Tx (Length bytes) on a SELF-LOOPING DMA and
   --  leave it running: the buffer is replayed forever with no inter-buffer
   --  gap (gapless).  Returns immediately; Stop halts it.  Tx in internal SRAM,
   --  Length 1 .. 4095, and Tx should hold a whole number of wave periods.
   procedure Start_Continuous (B : in out Bus; Tx : System.Address; Length : Natural)
   with Pre => Is_Open (B) and then Length in 1 .. 4095;

   --  Gapless double-buffered streaming: loop the two Half_Length-byte halves of
   --  Tx forever with no restart gap, and refill on demand.  Await_Half blocks
   --  until the DMA finishes a half and returns which one (0/1) to refill, so a
   --  continuously-generated signal stays glitch-free.  Stop ends it.
   procedure Start_Stream (B : in out Bus; Tx : System.Address; Half_Length : Natural)
   with Pre => Is_Open (B) and then Half_Length in 1 .. 4095;

   function Await_Half (B : Bus) return ESP32S3.GDMA.Ring_Half
   with Pre => Is_Open (B);

   --  Stop a continuous transmit (TX clock off) and release its held channel.
   procedure Stop (B : in out Bus)
   with Pre => Is_Open (B);

   --  Blocking RX-only capture of Length bytes into Rx that does NOT touch the
   --  TX path -- so it can run while a continuous transmit (Start_Continuous)
   --  keeps the shared master clock running.  Rx in internal SRAM, 1 .. 4095.
   procedure Capture (B : Bus; Rx : System.Address; Length : Natural)
   with Pre => Is_Open (B) and then Length in 1 .. 4095;

   --  Gapless double-buffered capture STREAMING: the receive mirror of
   --  Start_Stream, on its own DMA channel -- so it runs CONCURRENTLY with a
   --  streaming transmit (full-duplex, e.g. play out a codec's DAC while
   --  recording its ADC, with no clock gap in either direction).
   --  Await_Capture_Half blocks until the DMA has filled a half of Rx and
   --  returns which one (0/1) is ready to read.  Stop_Capture ends it.
   procedure Start_Capture_Stream
     (B : in out Bus; Rx : System.Address; Half_Length : Natural)
   with Pre => Is_Open (B) and then Half_Length in 1 .. 4095;

   function Await_Capture_Half (B : Bus) return ESP32S3.GDMA.Ring_Half
   with Pre => Is_Open (B);

   procedure Stop_Capture (B : in out Bus)
   with Pre => Is_Open (B);

   procedure Close (B : in out Bus);

private
   --  Pointer to a port's register block (both ports use the I2S0 layout; I2S1
   --  is overlaid with that type in the body).
   type Periph_Ref is access all ESP32S3_Registers.I2S.I2S0_Peripheral;

   type Bus is record
      Regs      : Periph_Ref := null;
      Chan      : ESP32S3.GDMA.Channel;   --  held only while Streaming
      Cap_Chan  : ESP32S3.GDMA.Channel;   --  held only while Capturing
      Port      : I2S_Port := I2S0;
      Valid     : Boolean := False;     --  port configured by Open
      Streaming : Boolean := False;     --  a continuous transmit holds Chan
      Capturing : Boolean := False;     --  a capture stream holds Cap_Chan
   end record;
end ESP32S3.I2S.Engine;
