with Interfaces;
with ESP32S3.GPIO;

--  RAW TWAI (CAN) register driver -- the ZFP-safe *mechanism* with NO mutual
--  exclusion.  PRIVATE child: only the ESP32S3.TWAI subtree may use it; the
--  application reaches TWAI only through the task-safe parent, which hides the
--  Bus handle and hands it out solely through its ownership-checked gateway.
--  This is the only unit that names the TWAI controller registers.
--
--  (Frame / Data_Length / Data_Bytes / Bus_Mode are declared in the parent and
--  used here by child visibility.)

private package ESP32S3.TWAI.Engine is

   use type Interfaces.Unsigned_32;   --  '<=' in Send's Pre

   --  A configured controller.  (The TWAI block is a singleton, so this carries
   --  only the operating-mode flag + a validity bit -- the registers live at a
   --  fixed address reached in the body.)
   type Bus is private;

   --  Bring the controller up at (about) Bit_Rate bit/s in the given mode,
   --  accepting all identifiers.
   function Open (Mode : Bus_Mode; Bit_Rate : Positive) return Bus;

   --  Route TWAI TX/RX to physical pads (for a real transceiver).
   procedure Configure_Pins
     (B : Bus; Tx : ESP32S3.GPIO.Optional_Pin; Rx : ESP32S3.GPIO.Optional_Pin);

   --  Loop TX back to RX through one pad (wiring-free self-test).
   procedure Enable_Loopback (B : Bus; Pad : ESP32S3.GPIO.Pin_Id);

   --  Transmit a frame and block until the controller finishes (self-test
   --  self-RX).  Extended selects the 29-bit on-wire format; Remote sends an RTR
   --  request (Length only, no Data on the wire); Id carries 11 or 29 significant
   --  bits accordingly.
   procedure Send
     (B                : Bus;
      Extended, Remote : Boolean;
      Id               : Interfaces.Unsigned_32;
      Length           : Data_Length;
      Data             : Data_Bytes)
   with Pre => (if Extended then Id <= 16#1FFF_FFFF# else Id <= 16#7FF#);

   --  Is a received frame waiting (RX buffer non-empty)?  RX_Extended reports the
   --  waiting frame's width (the frame-info FF bit, valid only when RX_Pending).
   function RX_Pending (B : Bus) return Boolean;
   function RX_Extended (B : Bus) return Boolean;

   --  Read the waiting frame if its width matches Want_Extended: decode Id/Remote/
   --  Length/Data, release the buffer, Got => True.  (An RTR frame has no Data.)
   --  Got => False (buffer left intact) if the waiting frame is the other width,
   --  or none arrived within a short timeout.
   procedure Receive
     (B             : Bus;
      Want_Extended : Boolean;
      Id            : out Interfaces.Unsigned_32;
      Remote        : out Boolean;
      Length        : out Data_Length;
      Data          : out Data_Bytes;
      Got           : out Boolean);

   --  Interrupt-driven RX.  Enable_Rx_Interrupt routes the TWAI interrupt to a
   --  CPU interrupt and enables it; from then on the handler drains the FIFO
   --  into a software ring.  Get_Frame blocks until a frame is queued and pops
   --  it; Rx_Overruns counts dropped frames (full FIFO or ring).
   procedure Enable_Rx_Interrupt;
   procedure Get_Frame (F : out Queued_Frame);
   function Rx_Overruns return Natural;

private
   type Bus is record
      Self_Mode : Boolean := False;   --  controller is in self-test mode
      Valid     : Boolean := False;
   end record;
end ESP32S3.TWAI.Engine;
