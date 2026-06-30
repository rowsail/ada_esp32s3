with Interfaces;
with ESP32S3.GPIO;
with ESP32S3.SPI;

--  74HC595 serial-in / parallel-out shift register STRING, driven over SPI.
--
--    MOSI  -> SER    (serial data)         SCLK -> SRCLK  (shift clock)
--    <gpio> -> RCLK  (storage-register latch; rising edge copies the shift
--                     register to the outputs)
--    <gpio> -> /OE   (active-low output enable; low = outputs driven)
--
--  Any number of chips may be daisy-chained (each chip's QH' -> the next chip's
--  SER); a string of N chips is N*8 outputs.  The driver keeps a shadow of the
--  desired output state, and Update shifts the whole string out (handling the
--  chain order) and pulses RCLK to latch it.
--
--  The shared SPI bus must be Setup + Configure_Pins'd by the application first
--  (the 595 needs only SCLK + MOSI -- it is write-only).  This driver Acquires
--  the host per Update with NO chip select asserted, so other devices on the bus
--  are undisturbed.  Targets embedded/full (the SPI Session is a controlled type).
package ESP32S3.HC595 is

   subtype Byte is Interfaces.Unsigned_8;

   --  A string of Chips daisy-chained 74HC595s -> Chips*8 parallel outputs.
   type Controller (Chips : Positive) is limited private;

   --  Configure RCLK and /OE as outputs and latch all-zeros into the string, but
   --  KEEP THE OUTPUTS DISABLED (/OE high): they stay high-impedance until the
   --  first Update, which then drops /OE low iff Enable -- so the pins never go
   --  live until the application has pushed a defined state.  The SPI Host must
   --  already be Setup + Configure_Pins'd.  Clock_Hz is the shift clock (<= ~10
   --  MHz is safe for the HC595 at 3.3 V).
   procedure Initialize
     (C        : in out Controller;
      Host     : ESP32S3.SPI.SPI_Host;
      RCLK     : ESP32S3.GPIO.Pin_Id;
      OE       : ESP32S3.GPIO.Pin_Id;
      Clock_Hz : Positive := 10_000_000;
      Enable   : Boolean  := True);

   --  Total parallel outputs (Chips * 8).
   function Output_Count (C : Controller) return Natural;

   --  Modify the SHADOW (call Update to push it to the pins).  Index is
   --  0 .. Output_Count-1: chip Index/8 (chip 0 is the one nearest the ESP), and
   --  that chip's output Q(Index mod 8).
   procedure Set_Output (C : in out Controller; Index : Natural; On : Boolean)
     with Pre => Index < Output_Count (C);

   function Get_Output (C : Controller; Index : Natural) return Boolean
     with Pre => Index < Output_Count (C);

   --  Set one chip's eight outputs at once: bit n -> Qn.  Chip 0 nearest the ESP.
   procedure Set_Byte (C : in out Controller; Chip : Natural; Value : Byte)
     with Pre => Chip < C.Chips;

   --  Shift the shadow out through the whole string and latch it (RCLK pulse).
   procedure Update (C : in out Controller);

   --  Set_Output then Update.
   procedure Write_Output (C : in out Controller; Index : Natural; On : Boolean)
     with Pre => Index < Output_Count (C);

   --  Drive all outputs low / high (sets the shadow and latches).
   procedure Clear_All (C : in out Controller);
   procedure Set_All   (C : in out Controller);

   --  Drive /OE: Enable_Outputs drives it low (outputs active); Disable_Outputs
   --  drives it high (outputs high-impedance).  Does not change the shadow.
   procedure Enable_Outputs  (C : in out Controller);
   procedure Disable_Outputs (C : in out Controller);

private

   --  Indexed 1 .. Chips (a discriminant must appear ALONE in a component
   --  constraint, so "1 .. Chips" is legal where "0 .. Chips - 1" is not).
   --  State (1) is chip 0 (nearest the ESP); the public API stays 0-based.
   type State_Array is array (Positive range <>) of Byte;

   type Controller (Chips : Positive) is limited record
      Host  : ESP32S3.SPI.SPI_Host := ESP32S3.SPI.SPI2;
      Clock : Positive             := 10_000_000;
      RCLK  : ESP32S3.GPIO.Pin_Id  := 0;
      OE    : ESP32S3.GPIO.Pin_Id  := 0;
      Auto_Enable : Boolean := True;    --  drop /OE on the first Update
      Live        : Boolean := False;   --  have the outputs been enabled yet?
      State : State_Array (1 .. Chips) := (others => 0);
   end record;

end ESP32S3.HC595;
