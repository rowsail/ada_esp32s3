with Interfaces;
with ESP32S3.SPI;
with ESP32S3.GPIO;

--  SD / SDHC memory card over SPI (the simple, universal transport).
--
--  This layers the SD "SPI mode" command protocol (CMD0/8/58, ACMD41, CMD17/24,
--  CRC7) on top of the task-safe ESP32S3.SPI master.  The chip-select is driven
--  as a plain GPIO so it can be held asserted across a whole command / response /
--  data sequence (the SPI peripheral's own CS pulses per transfer, which the SD
--  protocol cannot use).
--
--  Wiring (any free GPIOs -- 4 lines + power):
--     card DI  (MOSI) <- ESP32 MOSI      card DO (MISO) -> ESP32 MISO
--     card CLK        <- ESP32 SCLK      card CS         <- ESP32 CS (GPIO here)
--     card VDD = 3V3, VSS = GND.  A 10k pull-up on DO/MISO is recommended.
--
--  Cards are initialised at <=400 kHz (SD spec) then run faster (Data_Clock_Hz).
--  Addresses are 512-byte logical blocks (LBA); SDHC/SDXC use block addressing,
--  older SDSC byte addressing -- handled internally, the API is always LBA.
--
--  Task-safe: every operation takes the SPI host's Session for the whole
--  transaction, so concurrent callers serialise.  Uses finalization (via the SPI
--  Session) -> embedded / full profiles only.

package ESP32S3.SD_SPI is

   --  A 512-byte logical block (the SD sector size in SPI mode).
   type Block is array (0 .. 511) of Interfaces.Unsigned_8;

   --  Logical block address (sector number).
   type Block_Address is new Interfaces.Unsigned_32;

   --  What the card turned out to be (after Initialize).
   type Card_Kind is (Unknown, SD_V1, SD_V2_SC, SD_V2_HC);
   --  SD_V1   = SDSC v1.x        SD_V2_SC = SDSC v2.0 (byte addressing)
   --  SD_V2_HC = SDHC / SDXC (block addressing)

   --  Result of an operation.
   type Status is
     (OK,
      No_Card,        --  no response to CMD0 (nothing there / not wired)
      Unusable,       --  CMD8 voltage check / OCR says not a 3V3 card
      Init_Timeout,   --  ACMD41 never reported ready
      Read_Error,     --  CMD17 / data token failure
      Write_Error);   --  CMD24 / data-response / busy failure

   --  A single card on one SPI host.  Limited (non-copyable: one object owns the
   --  card's CS line).  Holds no finalizable resource itself -- the SPI Session
   --  taken per operation does the locking -- so it needs no controlled type.
   type Card is limited private;

   ----------------------------------------------------------------------------
   --  Configuration -- call once before Initialize (single-threaded).
   ----------------------------------------------------------------------------

   --  Bring the SPI host up in SPI mode 0 and route the four lines, driving CS
   --  as a GPIO.  Init_Clock_Hz must be <= 400 kHz per the SD spec; Data_Clock_Hz
   --  is what Initialize switches to once the card is ready (<= 25 MHz for the
   --  default-speed SPI mode; clamp to what your wiring tolerates).
   procedure Setup
     (C                    : out Card;
      Host                 : ESP32S3.SPI.SPI_Host;
      Sclk, Mosi, Miso, Cs : ESP32S3.GPIO.Pin_Id;
      Init_Clock_Hz        : Positive := 400_000;
      Data_Clock_Hz        : Positive := 8_000_000);

   ----------------------------------------------------------------------------
   --  Operation.
   ----------------------------------------------------------------------------

   --  Run the power-up + CMD0/8/ACMD41/CMD58 handshake.  On OK the card is ready
   --  and the bus has been raised to Data_Clock_Hz; Kind reports what it is.
   procedure Initialize (C : in out Card; Result : out Status);

   --  What Initialize found (Unknown until a successful Initialize).
   function Kind (C : Card) return Card_Kind;

   --  Read / write one 512-byte block at logical address LBA.
   procedure Read_Block
     (C      : in out Card;
      LBA    : Block_Address;
      Data   : out Block;
      Result : out Status);
   procedure Write_Block
     (C : in out Card; LBA : Block_Address; Data : Block; Result : out Status);

private
   type Card is limited record
      Host            : ESP32S3.SPI.SPI_Host := ESP32S3.SPI.SPI2;
      Cs              : ESP32S3.GPIO.Pin_Id := 0;
      Kind            : Card_Kind := Unknown;
      Block_Addressed : Boolean := False;   --  True for SDHC/SDXC
      Init_Hz         : Positive := 400_000;    --  init handshake clock
      Data_Hz         : Positive := 8_000_000;  --  post-init data clock
   end record;
end ESP32S3.SD_SPI;
