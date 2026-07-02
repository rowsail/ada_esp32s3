with System;
with ESP32S3.GDMA;
with ESP32S3.GPIO;
with ESP32S3_Registers.SPI2;

--  RAW SPI2/SPI3 register driver -- the ZFP-safe *mechanism* with NO mutual
--  exclusion.  PRIVATE child: only the ESP32S3.SPI subtree may use it; the
--  application cannot `with` it, and reaches SPI only through the task-safe
--  parent (ESP32S3.SPI).  See the parent for the design rationale.
--
--  (SPI_Host / SPI_Mode / No_Pin are declared in the parent and used here by
--  child visibility.)

private package ESP32S3.SPI.Engine is

   --  A configured host plus its Claimed GDMA channel.  Limited because it holds
   --  a (limited, controlled) GDMA Channel; built in place by Open.
   type Bus is limited private;

   procedure Open (B : in out Bus; Host : SPI_Host; Mode : SPI_Mode; Clock_Hz : Positive);

   function Is_Open (B : Bus) return Boolean;

   --  Change just the bit clock of an already-Open bus (no GDMA re-Claim).
   procedure Set_Clock (B : Bus; Hz : Positive);

   --  Change just the SPI mode (CPOL/CPHA) of an already-Open bus.  Applied per
   --  device at Acquire, so two devices on one host can run different modes.
   procedure Set_Mode (B : Bus; Mode : SPI_Mode);

   procedure Configure_Pins
     (B    : Bus;
      Sclk : ESP32S3.GPIO.Optional_Pin;
      Mosi : ESP32S3.GPIO.Optional_Pin;
      Miso : ESP32S3.GPIO.Optional_Pin;
      Cs   : ESP32S3.GPIO.Optional_Pin := No_Pin);

   procedure Enable_Loopback (B : Bus; Pad : ESP32S3.GPIO.Pin_Id);

   --  Enable (Enabled => True) or suppress (False) the peripheral's hardware CS0
   --  output for this host.  Suppressed when a device drives its own chip select
   --  via a callback, so the auto-asserted CS0 cannot disturb another device's
   --  pad sharing the bus (sets MISC.CS0_DIS).
   procedure Set_Hardware_CS (B : Bus; Enabled : Boolean);

   procedure Transfer (B : Bus; Tx, Rx : System.Address; Length : Natural);

   procedure Close (B : in out Bus);

private
   --  Pointer to a host's register block (SPI2 and SPI3 share the layout).
   type Periph_Ref is access all ESP32S3_Registers.SPI2.SPI2_Peripheral;

   type Bus is record
      Regs  : Periph_Ref := null;
      Chan  : ESP32S3.GDMA.Channel;
      Host  : SPI_Host := SPI2;
      Valid : Boolean := False;
   end record;
end ESP32S3.SPI.Engine;
