with Interfaces;
with System;

--  Speak the ESP32 serial ROM-bootloader protocol as the HOST, so one ESP32
--  can program another over a UART: the device-side twin of what esptool (and
--  this SDK's own examples/common/bare/espflash) does from a PC.  A production
--  jig, a field programmer or a board that reflashes its own daughterboard all
--  need this, and none of them can run Python.
--
--  Only the ROM loader is spoken -- no downloadable stub -- so there is no
--  compression and no stub-only command.  That costs transfer time and nothing
--  else; raise the baud rate with Set_Baud and a megabyte moves in a few
--  seconds.
--
--  ------------------------------------------------------------------------
--  The wire
--  ------------------------------------------------------------------------
--  Every exchange is a SLIP frame (0xC0 delimited, 0xDB escaped) carrying an
--  8-byte header -- direction, opcode, payload length, checksum -- then the
--  payload.  The target answers with the same opcode and a status pair whose
--  first byte is zero on success.  Requests are idempotent enough that a
--  missed reply is simply retried.
--
--  ------------------------------------------------------------------------
--  Driving the target
--  ------------------------------------------------------------------------
--  To reach the ROM loader the target must see IO0 low as it leaves reset.
--  From a PC that means wiggling DTR/RTS and hoping the board's auto-reset
--  circuit is the flavour you guessed -- esptool and our host tool both try
--  two dances and alternate.  A board doing this itself has no such problem:
--  it drives the target's EN and IO0 directly, so Connect performs ONE
--  deterministic sequence.  Assert_Reset and Assert_Boot are asked for the
--  LOGICAL state (True = held in reset / boot requested); which way round the
--  pin goes is the caller's business, and on the usual open-drain transistor
--  it is inverted.
--
--  ------------------------------------------------------------------------
--  Streaming
--  ------------------------------------------------------------------------
--  Images are streamed, never buffered: Begin_Image declares the length, Write
--  is called with whatever chunks the source produces (a filesystem read, a
--  network packet), and full 1 KB blocks go out as they fill.  End_Image pads
--  the last partial block with 0xFF -- erased flash -- and checks that exactly
--  the declared length arrived.  So flashing a megabyte costs a kilobyte of
--  RAM, and a truncated source is an error rather than a corrupt target.
--
--  Not task-safe: one Session is for one user at a time.
--  Embedded/full profiles only (it delays, raises, and returns String).

package ESP32S3.Esp_Loader is

   type Byte_Array is array (Positive range <>) of Interfaces.Unsigned_8;

   type Status_Kind is
     (Ok,
      No_Response,      --  the target never answered: absent, wrong wiring,
      --  wrong baud, or it did not enter the ROM loader
      Bad_Reply,        --  answered, but not with a frame we can make sense of
      Target_Refused,   --  a well-formed reply reporting a command failure
      Not_Connected,    --  operation attempted before a successful Connect
      Wrong_Length,     --  more or fewer image bytes than Begin_Image declared
      Unsupported);     --  the transport cannot do what was asked (e.g. no
   --  Set_Baud was supplied)

   --  The FLASH_DATA payload the ROM accepts.  Not a tuning knob -- every
   --  ESP ROM loader's receive buffer is this size.
   Block_Bytes : constant := 1024;

   --  ------------------------------------------------------------------
   --  Which chip is on the other end
   --  ------------------------------------------------------------------
   --  Connect identifies the target, because the ROM protocol is NOT uniform
   --  across the family and guessing wrong corrupts the flash rather than
   --  failing cleanly.  Three differences are handled here:
   --
   --    * the original ESP32 ROM ends every reply with FOUR status bytes, not
   --      two, so the error flag is in a different place;
   --    * the ESP32 and ESP8266 ROMs take a 16-byte FLASH_BEGIN payload, the
   --      rest a 20-byte one with an encryption word;
   --    * the ESP8266 ROM has no SPI_ATTACH and no SPI_SET_PARAMS at all, and
   --      needs a workaround for a bug in how its FLASH_BEGIN sizes an erase.
   --
   --  An unrecognised chip is still usable -- it is driven with the modern
   --  defaults, which is what every part since the ESP32-S2 wants.
   type Chip_Kind is
     (Unknown,
      Esp8266,
      Esp32,
      Esp32_S2,
      Esp32_S3,
      Esp32_C2,
      Esp32_C3,
      Esp32_C5,
      Esp32_C6,
      Esp32_C61,
      Esp32_H2,
      Esp32_H21,
      Esp32_H4,
      Esp32_P4,
      Esp32_S31,
      Esp32_E22);

   --  The part's marketing name ("ESP32-C6"), for a log line or a display.
   function Chip_Name (Kind : Chip_Kind) return String;

   --  Flash sizes vary far more than chips do, so this is NOT guessed from the
   --  chip: Configure_Flash still wants the size the caller knows.

   --  ------------------------------------------------------------------
   --  The transport
   --  ------------------------------------------------------------------
   --  A record of access-to-subprogram plus an opaque context, like
   --  ESP32S3.Block_Dev: no tagging, no finalization, swappable at run time.
   --  ESP32S3.Esp_Loader.Serial_Link builds one over a UART and two GPIOs.

   type Send_Proc is
     access procedure (Ctx : System.Address; Data : Byte_Array);

   --  Collect whatever has arrived, waiting up to Timeout_Ms for the FIRST
   --  byte.  Last is the index of the final byte stored, Into'First - 1 if
   --  nothing came.  Returning early with a short read is fine and expected.
   type Receive_Proc is
     access procedure
       (Ctx        : System.Address;
        Into       : out Byte_Array;
        Last       : out Natural;
        Timeout_Ms : Natural);

   --  Drive one of the target's control lines to its LOGICAL state:
   --  Assert_Reset (True) holds the target in reset, Assert_Boot (True) asks
   --  for the download loader.  Electrical polarity is the caller's business.
   type Line_Proc is
     access procedure (Ctx : System.Address; Asserted : Boolean);

   --  Optional: change the local UART's rate, after the target has agreed to.
   type Baud_Proc is access procedure (Ctx : System.Address; Baud : Positive);

   type Link is record
      Ctx          : System.Address := System.Null_Address;
      Send         : Send_Proc := null;
      Receive      : Receive_Proc := null;
      Assert_Reset : Line_Proc := null;
      Assert_Boot  : Line_Proc := null;
      Set_Baud     : Baud_Proc := null;
   end record;

   --  ------------------------------------------------------------------
   --  Sessions
   --  ------------------------------------------------------------------
   type Session is limited private;

   --  Reset the target into its download loader, synchronise with it, and
   --  identify it.  Retries the whole sequence a few times before giving up,
   --  because a ROM that is still coming up misses the first SYNC.  A target
   --  that answers but cannot be identified still connects, as Unknown.
   procedure Connect (S : out Session; Over : Link; Status : out Status_Kind);

   function Is_Connected (S : Session) return Boolean;

   --  What Connect found on the other end.  Unknown until then, and still
   --  Unknown for a chip newer than this table -- which is not fatal.
   function Chip (S : Session) return Chip_Kind;

   --  What identification actually read, whatever it concluded.  Chip alone
   --  reports a chip newer than these tables and a detection that went wrong
   --  identically, and those want opposite responses.
   function Security_Status (S : Session) return Status_Kind;
   function Security_Bytes (S : Session) return Natural;
   function Reported_Chip_Id (S : Session) return Interfaces.Unsigned_32;
   function Magic_Status (S : Session) return Status_Kind;
   function Reported_Magic (S : Session) return Interfaces.Unsigned_32;

   --  How the last command's reply hunt went: how many frames it read, and
   --  what the last of them was.  Zero frames means nothing came back at all;
   --  frames with the wrong opcode mean the stream is out of step.
   function Frames_Read (S : Session) return Natural;
   function Last_Frame_Dir (S : Session) return Interfaces.Unsigned_8;
   function Last_Frame_Op (S : Session) return Interfaces.Unsigned_8;
   function Last_Frame_Len (S : Session) return Natural;

   --  Reset the target WITHOUT connecting: Into_Download False simply runs
   --  whatever is flashed.  Also what Finish uses to start the new firmware.
   procedure Reset_Target (Over : Link; Into_Download : Boolean := False);

   --  Agree a faster rate with the target, then switch the local UART to it.
   --  Unsupported when the Link supplied no Set_Baud.  Everything after this
   --  runs at the new rate; Connect always starts at the ROM's 115200.
   procedure Set_Baud
     (S : in out Session; Baud : Positive; Status : out Status_Kind)
   with Pre => Is_Connected (S);

   --  Attach the target's SPI flash and tell the ROM how big it is.  Required
   --  before any image is written.  Flash_Bytes is the TARGET's flash size.
   procedure Configure_Flash
     (S           : in out Session;
      Flash_Bytes : Interfaces.Unsigned_32;
      Status      : out Status_Kind)
   with Pre => Is_Connected (S);

   --  ------------------------------------------------------------------
   --  Writing an image
   --  ------------------------------------------------------------------
   --
   --     Begin_Image (Loader, At_Offset => 16#1_0000#, Length => Size, ...);
   --     loop
   --        Read_Some (Chunk, Last);
   --        exit when Last < Chunk'First;
   --        Write (Loader, Chunk (Chunk'First .. Last), Status);
   --     end loop;
   --     End_Image (Loader, Status);
   --
   --  Begin_Image erases the region, which takes the target a while on a large
   --  image -- it is the slowest step in a flashing run.
   procedure Begin_Image
     (S         : in out Session;
      At_Offset : Interfaces.Unsigned_32;
      Length    : Interfaces.Unsigned_32;
      Status    : out Status_Kind)
   with Pre => Is_Connected (S);

   procedure Write
     (S : in out Session; Data : Byte_Array; Status : out Status_Kind)
   with Pre => Is_Connected (S);

   procedure End_Image (S : in out Session; Status : out Status_Kind)
   with Pre => Is_Connected (S);

   --  Bytes still owed to the current image (0 when none is open).
   function Remaining (S : Session) return Interfaces.Unsigned_32;

   --  Leave the loader.  Run True resets the target so the new firmware
   --  starts; False leaves it sitting in the ROM loader for another image.
   procedure Finish
     (S : in out Session; Run : Boolean := True; Status : out Status_Kind)
   with Pre => Is_Connected (S);

   --  ------------------------------------------------------------------
   --  Inspecting the target
   --  ------------------------------------------------------------------

   --  Read one of the target's registers.  The chip-identification magic lives
   --  at 16#4000_1000# on every ESP32 variant, which is how a caller can tell
   --  what it is talking to.
   procedure Read_Register
     (S       : in out Session;
      Address : Interfaces.Unsigned_32;
      Value   : out Interfaces.Unsigned_32;
      Status  : out Status_Kind)
   with Pre => Is_Connected (S);

   --  The MD5 the TARGET computes over a region of its own flash, as the ROM
   --  returns it: 32 lowercase hex characters.  Comparing it against the image
   --  just written is what makes a "programmed OK" indication mean something --
   --  the caller supplies the expected digest, which this package does not
   --  compute (there is no MD5 in the SDK yet).
   subtype Digest_Text is String (1 .. 32);

   procedure Read_Md5
     (S         : in out Session;
      At_Offset : Interfaces.Unsigned_32;
      Length    : Interfaces.Unsigned_32;
      Digest    : out Digest_Text;
      Status    : out Status_Kind)
   with Pre => Is_Connected (S);

private

   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;

   --  Staging for outgoing bytes.  SLIP is written incrementally through this
   --  rather than into a whole escaped copy of the frame: a FLASH_DATA frame
   --  is over a kilobyte and its worst-case escaping is twice that, which is
   --  not something to put on an embedded stack once per block.
   Out_Staging : constant := 256;

   --  A reply frame.  The longest is the MD5 answer (8 header + 32 digest + 2
   --  status); the slack absorbs the ROM's chattier error frames.
   In_Frame : constant := 256;

   --  Bytes pulled from the transport at a time.
   In_Staging : constant := 256;

   --  Replies end with this many status bytes, the first of which is the
   --  error flag.  Two everywhere except the original ESP32's ROM.
   Default_Status_Bytes : constant := 2;

   type Session is limited record
      Over      : Link;
      Connected : Boolean := False;

      --  Set by Connect, and what every per-chip decision below reads.
      Kind         : Chip_Kind := Unknown;
      Status_Bytes : Natural := Default_Status_Bytes;

      --  What identification actually saw, kept so an Unknown can be reported
      --  rather than merely admitted to.
      Probe_Sec_Status : Status_Kind := Not_Connected;
      Probe_Sec_Bytes  : Natural := 0;
      Probe_Chip_Id    : Interfaces.Unsigned_32 := 0;
      Probe_Reg_Status : Status_Kind := Not_Connected;
      Probe_Magic      : Interfaces.Unsigned_32 := 0;

      --  What the LAST command's reply hunt saw.  "No response" is the same
      --  report whether nothing arrived or the wrong thing did, and those are
      --  different faults.
      Probe_Frames   : Natural := 0;
      Probe_Last_Dir : Interfaces.Unsigned_8 := 0;
      Probe_Last_Op  : Interfaces.Unsigned_8 := 0;
      Probe_Last_Len : Natural := 0;

      --  Outgoing staging (flushed when full and at each frame's end).
      Out_Buf : Byte_Array (1 .. Out_Staging) := (others => 0);
      Out_Len : Natural := 0;

      --  Incoming staging, consumed a byte at a time by the SLIP reader.
      In_Buf : Byte_Array (1 .. In_Staging) := (others => 0);
      In_Len : Natural := 0;
      In_Pos : Natural := 0;

      --  The image being streamed.
      Block      : Byte_Array (1 .. Block_Bytes) := (others => 16#FF#);
      Block_Fill : Natural := 0;
      Block_Seq  : Interfaces.Unsigned_32 := 0;
      Owed       : Interfaces.Unsigned_32 := 0;
      Image_Open : Boolean := False;
   end record;

end ESP32S3.Esp_Loader;

