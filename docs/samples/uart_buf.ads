--  Guide step 15 -- the caller-owned ring buffer for interrupt-driven RX.
--
--  It lives in a PACKAGE, not in the procedure that calls Enable_Buffered_Rx:
--  the RX ISR writes it, so it has to outlive every scope.  Declare it inside a
--  subprogram and the compiler says
--     error: non-local pointer cannot point to local object
--
--  And it must be declared WITHOUT bounds, taking them from the initial value,
--  so its nominal subtype stays the unconstrained Byte_Array the access type
--  designates.  With explicit bounds it is a constrained subtype, 'Access is
--  illegal, and the only way through would be 'Unrestricted_Access:
--     Ring : aliased ESP32S3.UART.Byte_Array (0 .. 255) := (others => 0);  -- WRONG
with ESP32S3.UART;

package UART_Buf is
   Ring : aliased ESP32S3.UART.Byte_Array := (0 .. 255 => 0);
end UART_Buf;
