with Interfaces;

--  Tiny console-logging shim for bare-metal examples.
--
--  Formatted output without a hosted runtime: there is no Ada.Text_IO console on
--  this target, so this routes through the ROM printf via fixed-signature C
--  wrappers (hal_log_* in examples/common/bare/bare_log.c, linked into every
--  example).  Examples format in Ada -- Put a String, an Integer (optionally
--  field-padded), an unsigned, hex, or a fixed-point value -- instead of
--  hand-writing a glue.c helper per message.
--
--  Strings are passed to C NUL-terminated (built in a small stack buffer), so no
--  secondary stack or heap is used and the package is light enough for the
--  embedded/ZFP profiles.  Each call is one short esp_rom_printf, so the ROM
--  printf's per-call limits (it truncates past ~6 conversions and drops past the
--  64-byte FIFO in a single call) never bite -- compose a line from several Puts.

package ESP32S3.Log is

   --  Write a string (no newline).
   procedure Put (S : String);

   --  Write a single character.
   procedure Put (C : Character);

   --  Write a string then a newline (just a newline when S is omitted/empty).
   procedure Put_Line (S : String := "");

   --  Write a newline.
   procedure New_Line;

   --  Write a signed decimal integer, optionally right-justified to at least
   --  Width characters.  Pad is the fill character: ' ' pads before the sign
   --  (right-justify), '0' pads between the sign and the digits (zero-fill).
   procedure Put (N : Integer; Width : Natural := 0; Pad : Character := ' ');

   --  Write an unsigned decimal integer.
   procedure Put_Unsigned (N : Interfaces.Unsigned_32);

   --  Write N in lowercase hex (no "0x" prefix), zero-padded to at least Width
   --  digits (Width => 0 means no padding, e.g. Width => 8 gives "%08x").
   procedure Put_Hex (N : Interfaces.Unsigned_32; Width : Natural := 0);

   --  Write Numer/Denom as a fixed-point decimal with Decimals fractional
   --  digits, e.g. Put_Fixed (Temp_MilliC, 1000, 2) prints "23.45", and
   --  Put_Fixed (T_CentiC, 100, 2) prints a value given in hundredths.  Handles
   --  the sign and rounds toward zero.
   procedure Put_Fixed
     (Numer : Integer; Denom : Positive; Decimals : Natural := 2);

end ESP32S3.Log;
