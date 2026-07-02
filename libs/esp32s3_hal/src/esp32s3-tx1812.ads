with Interfaces; use Interfaces;
with ESP32S3.GPIO;
with ESP32S3.RMT;

--  N.B. a Strip is statically sized by its Count discriminant: it carries both
--  the Count-pixel colour buffer AND the Count*24 RMT-symbol frame buffer, so
--  declaring e.g. `Panel : Strip (64)` reserves all of it at elaboration (no
--  heap) and the linker verifies it fits -- see the esp32s3_tx1812 example.

--  ESP32-S3 driver for TX1812 addressable RGB LEDs.
--
--  The TX1812 (like the WS2812 / "NeoPixel" family) is a single-wire, daisy-
--  chainable RGB LED: 24 bits of colour are clocked in MSB-first as a precisely
--  timed pulse train (a '1' is a long-high/short-low bit, a '0' short-high/
--  long-low), and a >80 us low "reset" latches them.  This driver generates
--  that waveform with the RMT peripheral (one RMT symbol per data bit).
--
--  Ownership follows the HAL idiom: a Strip is a CLAIMED handle that takes an
--  RMT transmit channel on Acquire and releases it automatically on scope exit
--  (its RMT channel component is controlled).  Acquire the Strip, Set pixel
--  colours into its buffer, then Show to clock them out.
--
--  LIMITATION (single LED for now): the underlying RMT.Transmit sends at most
--  47 symbols per burst, and each LED needs 24 -- so today a Strip drives ONE
--  LED (Count => 1).  Driving a longer string needs RMT wrap/refill support,
--  which is a later step; the API is already shaped for it (Count, per-pixel
--  Set), so only Show's transport changes.

package ESP32S3.TX1812 is

   --  A pixel colour (8 bits per channel; the wire order is handled internally).
   type Color is record
      R, G, B : Unsigned_8 := 0;
   end record;

   Off   : constant Color := (0, 0, 0);
   Red   : constant Color := (255, 0, 0);
   Green : constant Color := (0, 255, 0);
   Blue  : constant Color := (0, 0, 255);
   White : constant Color := (255, 255, 255);

   --  A chain of Count LEDs on one data pin (Count = 1 for a single LED).
   type Strip (Count : Positive) is limited private;

   --  Claim RMT transmit channel Channel and route it to Pin; the Strip is then
   --  ready to Show.  Check Is_Valid afterwards (it fails if the channel is
   --  already taken).  Call this once before setting any colours.
   --
   --  Blocks (1 .. 4) gives the channel extra RMT RAM so up to ~Blocks*2 LEDs go
   --  out in one shot without the wrap re-fill (it borrows the higher TX
   --  channels' RAM -- see ESP32S3.RMT.Configure).  Longer strings stream via
   --  wrap regardless, so the default of 1 is fine for any length.
   procedure Acquire
     (S       : in out Strip;
      Pin     : ESP32S3.GPIO.Pin_Id;
      Channel : ESP32S3.RMT.TX_Index := 0;
      Blocks  : Positive := 1);

   --  True once Acquire has successfully claimed + configured the channel.
   function Is_Valid (S : Strip) return Boolean;

   --  Release the RMT channel (also done automatically when S leaves scope).
   procedure Release (S : in out Strip);

   --  Set one pixel's colour in the buffer (Index in 1 .. Count; out-of-range
   --  is ignored).  Buffered only -- call Show to push it to the LED(s).
   procedure Set (S : in out Strip; Index : Positive; C : Color);

   --  Set every pixel to C (buffered; call Show to display).
   procedure Set_All (S : in out Strip; C : Color);

   --  Clock the buffered colours out to the LED(s) and latch them.
   procedure Show (S : in out Strip);

private
   Symbols_Per_LED : constant :=
     24;                    --  24-bit GRB, 1 sym/bit

   type Pixel_Array is array (Positive range <>) of Color;

   --  One LED's 24 RMT symbols.  Frame is Count of these -- a contiguous
   --  Count*24-symbol buffer, but indexed by Count alone so the discriminant
   --  constraint is legal.  Show overlays a flat Symbol_Array on it to transmit.
   subtype LED_Symbols is ESP32S3.RMT.Symbol_Array (0 .. Symbols_Per_LED - 1);
   type Frame_Array is array (Positive range <>) of LED_Symbols;

   type Strip (Count : Positive) is limited record
      Chan   :
        ESP32S3.RMT.TX_Channel;                 --  auto-released on final.
      Pixels : Pixel_Array (1 .. Count) := (others => Off);
      Frame  : Frame_Array (1 .. Count);               --  pre-encoded, static
      Ready  : Boolean := False;
   end record;
end ESP32S3.TX1812;
