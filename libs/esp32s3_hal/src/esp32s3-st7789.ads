with Ada.Finalization;
with ESP32S3.SPI;
with ESP32S3.GPIO;

--  ST7789 (ST77xx-family) SPI display controller driver.
--
--  4-wire SPI, write-only (CLK + MOSI; no MISO -- the controller cannot be read
--  back, so there is no probe / status).  Three GPIOs the driver drives directly:
--  DC (data/command), CS (chip select), and an optional RST (reset; if No_Pin a
--  software reset is used instead).  Pixels are 16-bit RGB565, MSB-first.
--
--  Locking -- TWO levels, like the TCA9555:
--    * A Session is an exclusive, RAII hold on ONE display, acquired like the
--      RTC.  Hold it across a whole sequence of operations so no other task can
--      corrupt the controller mid-sequence.
--    * The SPI host is locked only INSIDE each operation (assert CS, transfer,
--      deassert CS, release), so the SPI peripheral is used "only as long as
--      necessary" and is free between operations for another task / device.  CS
--      is high whenever the bus is released, so nothing interferes.
--  The per-display guards are a fixed library-level array keyed by the CS pin (a
--  GPIO uniquely identifies one display), so no protected object lives in a
--  Device.  Uses controlled Sessions => embedded / full profiles only.
--
--  Typical use:
--     declare
--        LCD : ESP32S3.ST7789.Device;
--        S   : ESP32S3.ST7789.Session;
--     begin
--        ESP32S3.ST7789.Setup (LCD, Sclk => 12, Mosi => 13, DC => 16, CS => 10,
--                              Width => 240, Height => 240);
--        ESP32S3.ST7789.Acquire (S, LCD);          --  protect this display
--        ESP32S3.ST7789.Init (S);
--        ESP32S3.ST7789.Fill (S, ESP32S3.ST7789.Blue);
--     end;                                          --  Session auto-released

package ESP32S3.ST7789 is

   --  16-bit RGB565 colour (5 red, 6 green, 5 blue), MSB-first on the wire.
   type Color is mod 2**16;
   function RGB (R, G, B : Natural) return Color;   --  each 0 .. 255

   Black : constant Color := 16#0000#;
   White : constant Color := 16#FFFF#;
   Red   : constant Color := 16#F800#;
   Green : constant Color := 16#07E0#;
   Blue  : constant Color := 16#001F#;

   --  A row-major block of pixels for Draw_Bitmap.
   type Color_Array is array (Natural range <>) of Color;

   type Rotation is (Rot_0, Rot_90, Rot_180, Rot_270);

   type Device is limited private;
   type Session is limited private;

   --  Raised by Acquire if the Device was never Setup, and by an operation whose
   --  Session does not currently hold a display.
   Not_Initialized : exception;
   Not_Owned       : exception;

   ----------------------------------------------------------------------------
   --  One-time configuration -- call once per display at startup.
   ----------------------------------------------------------------------------

   --  Record the wiring + geometry and bring the SPI host up (mode 0, full-duplex
   --  master; CS / MISO are NOT routed to the peripheral -- CS is driven here as
   --  a GPIO).  Width/Height are the panel resolution; X_Offset/Y_Offset are the
   --  controller-to-panel origin offset some panels need.  No pin defaults for
   --  the four routed lines.
   procedure Setup
     (Dev                : out Device;
      Sclk, Mosi, DC, CS : ESP32S3.GPIO.Pin_Id;
      Width              : Positive := 240;
      Height             : Positive := 240;
      RST                : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      X_Offset, Y_Offset : Natural := 0;
      Host               : ESP32S3.SPI.SPI_Host := ESP32S3.SPI.SPI2;
      Mode               : ESP32S3.SPI.SPI_Mode := 0;
      Clock_Hz           : Positive := 40_000_000);

   ----------------------------------------------------------------------------
   --  Take / release exclusive ownership of the display.
   ----------------------------------------------------------------------------

   procedure Acquire (S : in out Session; Dev : Device);
   procedure Release (S : in out Session);

   ----------------------------------------------------------------------------
   --  Operations -- each takes the held Session and locks the SPI host only for
   --  its own transfers.  Raise Not_Owned unless S currently holds a display.
   ----------------------------------------------------------------------------

   --  Reset (hardware via RST if wired, else software) and run the power-on init
   --  sequence (sleep-out, 16-bit colour, normal display, display on).  (Named
   --  Init, not Initialize, to avoid clashing with the controlled type's own.)
   procedure Init (S : Session);

   procedure Display_On (S : Session);
   procedure Display_Off (S : Session);
   procedure Set_Rotation (S : Session; Rot : Rotation);  --  sets MADCTL
   procedure Invert (S : Session; On : Boolean);    --  colour inversion
   procedure Sleep (S : Session; On : Boolean);

   --  Fill the whole screen / a rectangle with one colour (clipped to the panel).
   procedure Fill (S : Session; C : Color);
   procedure Fill_Rect (S : Session; X, Y, W, H : Natural; C : Color);
   procedure Set_Pixel (S : Session; X, Y : Natural; C : Color);

   --  Blit a W x H block of pixels (row-major) at (X, Y).  Pixels'Length must be
   --  W * H.
   procedure Draw_Bitmap (S : Session; X, Y, W, H : Natural; Pixels : Color_Array);

private
   type Device is record
      Host       : ESP32S3.SPI.SPI_Host := ESP32S3.SPI.SPI2;
      Mode       : ESP32S3.SPI.SPI_Mode := 0;
      Clock_Hz   : Positive := 40_000_000;
      DC, CS     : ESP32S3.GPIO.Pin_Id := 0;
      RST        : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      W, H       : Positive := 1;
      X_Off      : Natural := 0;
      Y_Off      : Natural := 0;
      Configured : Boolean := False;
   end record;

   type Session is new Ada.Finalization.Limited_Controlled with record
      Active   : Boolean := False;
      Host     : ESP32S3.SPI.SPI_Host := ESP32S3.SPI.SPI2;
      Mode     : ESP32S3.SPI.SPI_Mode := 0;
      Clock_Hz : Positive := 40_000_000;
      DC, CS   : ESP32S3.GPIO.Pin_Id := 0;
      RST      : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      W, H     : Positive := 1;
      X_Off    : Natural := 0;
      Y_Off    : Natural := 0;
   end record;
   overriding
   procedure Finalize (S : in out Session);
end ESP32S3.ST7789;
