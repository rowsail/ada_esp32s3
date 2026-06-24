with System;
with ESP32S3.GDMA;
with ESP32S3.GPIO;
with ESP32S3_Registers.I2S;

--  RAW I2S0/I2S1 register driver -- the ZFP-safe *mechanism* with NO mutual
--  exclusion.  PRIVATE child: only the ESP32S3.I2S subtree may use it.  See the
--  parent (ESP32S3.I2S) for the design rationale.
private package ESP32S3.I2S.Engine is

   --  A configured port plus its Claimed GDMA channel.  Limited because it holds
   --  a (limited, controlled) GDMA Channel; built in place by Open.
   type Bus is limited private;

   procedure Open (B           : in out Bus;
                   Port        : I2S_Port;
                   Sample_Rate : Positive;
                   Bits        : Sample_Bits;
                   Mode        : I2S_Mode);

   function Is_Open (B : Bus) return Boolean;

   procedure Configure_Pins (B : Bus;
                             Bclk : ESP32S3.GPIO.Optional_Pin;
                             Ws   : ESP32S3.GPIO.Optional_Pin;
                             Dout : ESP32S3.GPIO.Optional_Pin := No_Pin;
                             Din  : ESP32S3.GPIO.Optional_Pin := No_Pin;
                             Mclk : ESP32S3.GPIO.Optional_Pin := No_Pin);

   procedure Enable_Loopback (B : Bus; Pad : ESP32S3.GPIO.Pin_Id);

   procedure Write    (B : Bus; Tx : System.Address; Length : Natural);
   procedure Read     (B : Bus; Rx : System.Address; Length : Natural);
   procedure Transfer (B : Bus; Tx, Rx : System.Address; Length : Natural);

   --  Start the TX path streaming Tx (Length bytes) on a SELF-LOOPING DMA and
   --  leave it running: the buffer is replayed forever with no inter-buffer
   --  gap (gapless).  Returns immediately; Stop halts it.  Tx in internal SRAM,
   --  Length 1 .. 4095, and Tx should hold a whole number of wave periods.
   procedure Start_Continuous (B : Bus; Tx : System.Address; Length : Natural);

   --  Stop a continuous transmit (TX clock off).
   procedure Stop (B : Bus);

   --  Blocking RX-only capture of Length bytes into Rx that does NOT touch the
   --  TX path -- so it can run while a continuous transmit (Start_Continuous)
   --  keeps the shared master clock running.  Rx in internal SRAM, 1 .. 4095.
   procedure Capture (B : Bus; Rx : System.Address; Length : Natural);

   procedure Close (B : in out Bus);

private
   --  Pointer to a port's register block (both ports use the I2S0 layout; I2S1
   --  is overlaid with that type in the body).
   type Periph_Ref is access all ESP32S3_Registers.I2S.I2S0_Peripheral;

   type Bus is record
      Regs  : Periph_Ref := null;
      Chan  : ESP32S3.GDMA.Channel;
      Port  : I2S_Port   := I2S0;
      Valid : Boolean    := False;
   end record;
end ESP32S3.I2S.Engine;
