with ESP32S3.GPIO;
with ESP32S3_Registers.I2C;

--  RAW I2C0/I2C1 master register driver -- the ZFP-safe *mechanism* with NO
--  mutual exclusion.  PRIVATE child: only the ESP32S3.I2C subtree may use it;
--  the application cannot `with` it, and reaches I2C only through the task-safe
--  parent (ESP32S3.I2C).  See the parent for the design rationale.
--
--  (I2C_Host / Slave_Address / Byte / Byte_Array are declared in the parent and
--  used here by child visibility.)

private package ESP32S3.I2C.Engine is

   --  A configured master controller.
   type Bus is private;

   function Open (Host : I2C_Host; Clock_Hz : Positive) return Bus
   with Post => Is_Open (Open'Result);

   function Is_Open (B : Bus) return Boolean;

   --  Route SCL/SDA to pads as open-drain with internal pull-ups.
   procedure Configure_Pins (B : Bus; Scl : ESP32S3.GPIO.Pin_Id; Sda : ESP32S3.GPIO.Pin_Id)
   with Pre => Is_Open (B);

   --  One START..STOP master write transaction of ANY length.  Success := slave
   --  ACKed addr + every data byte (when Check_Ack).  Data length 0 is an
   --  address-only probe.  Payloads past the FIFO are sent in bursts joined by
   --  the command FSM's END opcode, which pauses it WITHOUT a STOP (see the body).
   procedure Write
     (B         : Bus;
      Addr      : Slave_Address;
      Data      : Byte_Array;
      Success   : out Boolean;
      Check_Ack : Boolean := True)
   with Pre => Is_Open (B);

   --  One START..STOP master read transaction of ANY length (ACK all but the last
   --  byte).  Success := slave ACKed the address.  Zero length is rejected.
   procedure Read (B : Bus; Addr : Slave_Address; Data : out Byte_Array; Success : out Boolean)
   with Pre => Is_Open (B);

   --  One combined transaction: START, write Tx, REPEATED START, read Rx, STOP --
   --  no STOP between the phases, so the slave sees a single command.  Both
   --  lengths are unbounded (Rx must be >= 1).
   procedure Write_Read
     (B       : Bus;
      Addr    : Slave_Address;
      Tx      : Byte_Array;
      Rx      : out Byte_Array;
      Success : out Boolean)
   with Pre => Is_Open (B);

   procedure Close (B : in out Bus);

private
   --  Pointer to a controller's register block (I2C0 and I2C1 share the layout).
   type Periph_Ref is access all ESP32S3_Registers.I2C.I2C_Peripheral;

   type Bus is record
      Regs  : Periph_Ref := null;
      Host  : I2C_Host := I2C0;
      Valid : Boolean := False;
   end record;
end ESP32S3.I2C.Engine;
