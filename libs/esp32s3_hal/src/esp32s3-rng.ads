with ESP32S3_Registers;

--  ESP32-S3 hardware Random Number Generator (RNG).
--
--  Each read of the RNG data register returns a fresh 32-bit value
--  (HW-verified: ESP32S3_Registers.RNG.RNG_Periph.DATA at 0x6003507C changes on
--  every read).  Note this is the *RNG peripheral* register, NOT esp-idf's
--  WDEV_RND_REG (0x600260B0) -- that one only yields entropy with the RF clock
--  domain up (Wi-Fi/BT), which this bare runtime does not start, so it reads a
--  constant here.
--
--  ENTROPY CAVEAT: the RNG derives randomness from analog / clock-jitter noise.
--  For CRYPTOGRAPHIC-quality output the TRM wants an active entropy source -- the
--  RF subsystem (not present here) or the SAR-ADC bootloader entropy.  Without one
--  it still produces varying values from internal clock jitter -- fine for
--  dithering, non-secret IDs, test data, or seeding a software PRNG, but do NOT
--  treat it as a CSPRNG as-is.  Also: don't read in a tight loop faster than the
--  hardware refreshes, or successive words may correlate.
--
--  ZFP-safe: Preelaborate, no heap, no secondary stack, no finalization.
--
--  Task-safe by construction -- and the one peripheral that keeps both
--  properties.  A Read is a single atomic 32-bit register load and Fill writes
--  only the caller's buffer; there is no shared mutable driver state, so
--  concurrent readers simply get independent random words.  No protected object
--  is needed (and none is added, so RNG stays usable in a ZFP context too).

package ESP32S3.RNG
  with Preelaborate
is
   subtype Word is ESP32S3_Registers.UInt32;        --  a 32-bit value

   --  One fresh 32-bit random word straight from the hardware RNG.
   function Read return Word
   with Inline;

   type Byte is mod 2**8 with Size => 8;
   type Byte_Array is array (Natural range <>) of Byte with Pack;

   --  Fill Buffer with random bytes (a word at a time; the last, possibly
   --  partial, word supplies any tail bytes).  Length need not be a multiple of 4.
   procedure Fill (Buffer : out Byte_Array);

   --  Turn on a hardware entropy source so Read / Fill are fit for cryptographic
   --  use (keys, nonces).  Without an RF subsystem the RNG would otherwise see only
   --  clock jitter (see the ENTROPY CAVEAT above); this enables the internal 8 MHz
   --  RC clock -- the RNG's primary noise source -- and starts the SAR ADC
   --  continuously sampling a disconnected input for additional entropy.  This is
   --  the supported, RF-free path (it mirrors esp-idf's bootloader_random_enable
   --  for the S3).  Call once at start-up, before relying on the RNG for secrets.
   procedure Enable_Entropy_Source;

   --  Stop the SAR ADC entropy source (the 8 MHz clock is left running).
   procedure Disable_Entropy_Source;
end ESP32S3.RNG;
