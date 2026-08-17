--  Guide step 15 -- switching a port to interrupt-driven RX, then reading.
--
--  Enable_Buffered_Rx is called once at startup, single-threaded, before any
--  task acquires the port; it brings the port up itself if nothing has.
with ESP32S3.UART;
with UART_Buf;

procedure UART_Start is
   use ESP32S3.UART;

   S     : Session;
   Data  : Byte_Array (0 .. 63);
   Count : Natural;
begin
   Enable_Buffered_Rx (UART1, UART_Buf.Ring'Access);

   --  Acquire takes the port AND shapes it -- there is no port-level setup call,
   --  so a port cannot be configured by anyone who does not hold it.
   Acquire (S, UART1, Baud => 9_600, Rx => 18);      --  RX only, e.g. a GPS

   --  Read reports how many bytes actually arrived; a short read is a timeout,
   --  not an error, so always use Count rather than assuming Data filled.
   Read (S, Data, Count);
end UART_Start;
