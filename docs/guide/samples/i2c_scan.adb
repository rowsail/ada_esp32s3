--  Guide step 13 -- "Scanning the bus".
--
--  A zero-length Write is a complete transaction with no payload: START, the
--  address byte, STOP.  Success is then simply "did anything ACK this address",
--  which is exactly what a bus scan needs.
--
--  Two things the compiler will hold you to, and the reason this file is
--  compiled rather than hand-copied into the page:
--    * (1 .. 0 => 0) is the null array aggregate -- upper bound below lower.
--    * Slave_Address is a Natural subtype but Put_Hex takes an Unsigned_32, so
--      the conversion is required.
with Interfaces;
with ESP32S3.I2C;
with ESP32S3.Log; use ESP32S3.Log;

procedure I2C_Scan is
   S  : ESP32S3.I2C.Session;      --  releases itself when this scope exits
   Ok : Boolean;
begin
   ESP32S3.I2C.Acquire (S, ESP32S3.I2C.I2C0);
   for A in ESP32S3.I2C.Slave_Address'Range loop      --  0 .. 16#7F#
      ESP32S3.I2C.Write (S, A, Data => (1 .. 0 => 0), Success => Ok);
      if Ok then
         Put ("[i2c] device at 0x");
         Put_Hex (Interfaces.Unsigned_32 (A), Width => 2);
         New_Line;
      end if;
   end loop;
end I2C_Scan;
