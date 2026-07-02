--  ESP32-S3 GPIO driver -- a reusable pin abstraction over the generated register
--  layer (Interfaces.ESP32S3.GPIO + Interfaces.ESP32S3.IO_MUX).
--
--  Any pad 0 .. 48: configure direction / pull / drive strength, and
--  set / clear / toggle / write / read. (Pin interrupts are a follow-up.)
--
--  Task-safe: Set / Clear / Write use the hardware-atomic W1TS/W1TC banks and
--  Read is a pure load, so those are safe to call concurrently as-is.  The
--  read-modify-write operations (Configure, Toggle) are serialised through a
--  protected object.  (Holding a protected object, this package requires a
--  tasking runtime.)  Driving the same pin from two tasks is still the app's
--  call -- the lock keeps the registers consistent, not your intent.
--
--  Pads that the silicon does not expose, or that are bonded to the in-package
--  SPI flash / octal PSRAM, are excluded by the Pin_Id subtype below: driving
--  them would hang the chip, so naming one is a compile-time error for a static
--  value and a predicate check at run time.

package ESP32S3.GPIO is
   --  GPIO pad numbers as the silicon numbers them (0 .. 48); -1 is the "no pin"
   --  sentinel that drivers use for an optional line left unrouted (Optional_Pin).
   type Pad_Number is range -1 .. 48;

   --  Sentinel for an optional pin argument (e.g. an unused SPI chip-select).
   No_Pin : constant Pad_Number := -1;

   --  A GPIO pin an application may legitimately drive -- the type EVERY driver
   --  uses to name a pin.  The static predicate excludes the pads that don't
   --  exist on the ESP32-S3 (22 .. 25) and those wired to the in-package SPI
   --  flash and octal PSRAM (26 .. 37); driving any of them hangs the chip.
   --  (Boards without octal PSRAM could also use 33 .. 37, but the bare runtime
   --  here maps octal PSRAM, so they are reserved.)
   --
   --  Enforcement: because the predicate is STATIC, a reserved/absent pad used
   --  where a Pin_Id is expected as a static value is flagged at COMPILE time
   --  ("static expression fails static predicate check") -- so declare pin
   --  constants of type Pin_Id to get that check.  A dynamic value is verified
   --  by the subtype's predicate at RUN time wherever assertion/predicate checks
   --  are enabled (-gnata).  (No Predicate_Failure message: it would pull in
   --  Ada.Exceptions, which the light-tasking runtime does not provide.)
   subtype Pin_Id is Pad_Number range 0 .. 48
   with Static_Predicate => Pin_Id in 0 .. 21 | 38 .. 48;

   --  A pin argument that may be omitted: a real Pin_Id, or No_Pin (-1).
   subtype Optional_Pin is Pad_Number
   with Static_Predicate => Optional_Pin in -1 | 0 .. 21 | 38 .. 48;

   type Pin_Mode is (Input, Output);
   type Pull_Mode is (Floating, Pull_Up, Pull_Down);

   --  IO_MUX FUN_DRV field (0 .. 3), roughly 5 / 10 / 20 / 40 mA.
   type Drive_Strength is (Drive_Weak, Drive_Medium, Drive_Strong, Drive_Strongest);

   --  Configure a pad as a plain GPIO: direction + pull + drive. The pad is
   --  always routed through the GPIO matrix as a software-controlled GPIO
   --  (IO_MUX MCU_SEL = 1, GPIO output index 256). Output pads get their driver
   --  enabled; input pads get the input buffer enabled. (Routing a pad to a
   --  peripheral signal is the job of that peripheral's own Configure_Pins,
   --  which programs the matrix directly -- not this driver.)
   procedure Configure
     (Pin   : Pin_Id;
      Mode  : Pin_Mode;
      Pull  : Pull_Mode := Floating;
      Drive : Drive_Strength := Drive_Medium);

   procedure Set (Pin : Pin_Id);              --  drive high  (atomic W1TS)
   procedure Clear (Pin : Pin_Id);              --  drive low   (atomic W1TC)
   procedure Toggle (Pin : Pin_Id);              --  flip the current output level
   procedure Write (Pin : Pin_Id; On : Boolean);
   function Read (Pin : Pin_Id) return Boolean;  --  sample the input level

end ESP32S3.GPIO;
