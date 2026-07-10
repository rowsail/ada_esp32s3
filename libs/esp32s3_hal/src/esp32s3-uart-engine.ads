with ESP32S3.GPIO;
with ESP32S3_Registers.UART;

--  RAW UART0/1/2 register driver -- the ZFP-safe *mechanism* with NO mutual
--  exclusion.  PRIVATE child: only the ESP32S3.UART subtree may use it; the
--  application reaches UART only through the task-safe parent.  See the parent
--  for the design rationale.
--
--  (UART_Port / Baud_Rate / Data_Bits / Parity_Mode / Stop_Bits / Byte /
--  Byte_Array are declared in the parent and used here by child visibility.)

private package ESP32S3.UART.Engine is

   --  A configured UART port.
   type Bus is private;

   function Open
     (Port : UART_Port; Baud : Baud_Rate; Bits : Data_Bits; Parity : Parity_Mode; Stop : Stop_Bits)
      return Bus
   with Post => Is_Open (Open'Result);

   function Is_Open (B : Bus) return Boolean;

   --  Route TXD (push-pull out) / RXD (in, pulled up) and, optionally, the
   --  hardware-flow-control lines RTS (push-pull out) / CTS (in) to pads; No_Pin
   --  skips a line.  Giving Rts enables RX flow control (drive RTS, throttling
   --  the peer when our RX FIFO reaches Rx_Flow_Threshold bytes); giving Cts
   --  enables TX flow control (gate our transmitter on the peer's CTS).
   procedure Configure_Pins
     (B                 : Bus;
      Tx                : ESP32S3.GPIO.Optional_Pin;
      Rx                : ESP32S3.GPIO.Optional_Pin;
      Rts               : ESP32S3.GPIO.Optional_Pin;
      Cts               : ESP32S3.GPIO.Optional_Pin;
      Rx_Flow_Threshold : Natural)
   with Pre => Is_Open (B);

   --  Independently re-program one frame attribute on an open port: the baud
   --  divider, or a single CONF0 field (data bits / parity / stop bits) via a
   --  read-modify-write that leaves the other fields untouched.
   procedure Set_Baud (B : Bus; Baud : Baud_Rate)
   with Pre => Is_Open (B);
   procedure Set_Data_Bits (B : Bus; Bits : Data_Bits)
   with Pre => Is_Open (B);
   procedure Set_Parity (B : Bus; Parity : Parity_Mode)
   with Pre => Is_Open (B);
   procedure Set_Stop_Bits (B : Bus; Stop : Stop_Bits)
   with Pre => Is_Open (B);

   --  Controller-level internal TX->RX loopback (CONF0.LOOPBACK).
   procedure Set_Loopback (B : Bus; On : Boolean)
   with Pre => Is_Open (B);

   --  Independently invert each line at the controller (CONF0 *_INV bits).
   procedure Set_Inversion (B : Bus; Tx, Rx, Rts, Cts : Boolean)
   with Pre => Is_Open (B);

   --  Push every byte to the TX FIFO, waiting (bounded) for room.
   procedure Write (B : Bus; Data : Byte_Array)
   with Pre => Is_Open (B);

   --  Bytes waiting in the RX FIFO.
   function Rx_Available (B : Bus) return Natural
   with Pre => Is_Open (B);

   --  Read up to Data'Length bytes (bounded wait per byte); Count = received.
   --  Serves from the interrupt-filled ring if buffered RX is enabled.
   procedure Read (B : Bus; Data : out Byte_Array; Count : out Natural)
   with Pre => Is_Open (B);

   --  Turn on interrupt-driven RX: the RX ISR drains the FIFO into Buf so nothing
   --  is lost between Reads.  Read/Rx_Available then serve from Buf.
   procedure Enable_Buffered_Rx (B : Bus; Buf : Rx_Buffer_Access);

   procedure Close (B : in out Bus);

private
   --  Pointer to a port's register block (all three share the layout).
   type Periph_Ref is access all ESP32S3_Registers.UART.UART_Peripheral;

   type Bus is record
      Regs  : Periph_Ref := null;
      Port  : UART_Port := UART0;
      Valid : Boolean := False;
   end record;
end ESP32S3.UART.Engine;
