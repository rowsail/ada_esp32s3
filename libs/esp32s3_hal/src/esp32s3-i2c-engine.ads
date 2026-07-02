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

   function Open (Host : I2C_Host; Clock_Hz : Positive) return Bus;

   function Is_Open (B : Bus) return Boolean;

   --  Route SCL/SDA to pads as open-drain with internal pull-ups.
   procedure Configure_Pins
     (B : Bus; Scl : ESP32S3.GPIO.Pin_Id; Sda : ESP32S3.GPIO.Pin_Id);

   --  One START..STOP master write transaction.  Success := slave ACKed addr +
   --  every data byte (when Check_Ack).  Data length 0 is an address-only probe.
   procedure Write
     (B         : Bus;
      Addr      : Slave_Address;
      Data      : Byte_Array;
      Success   : out Boolean;
      Check_Ack : Boolean := True);

   --  One START..STOP master read transaction (ACK all but last byte).
   --  Success := slave ACKed the address.
   procedure Read
     (B       : Bus;
      Addr    : Slave_Address;
      Data    : out Byte_Array;
      Success : out Boolean);

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
