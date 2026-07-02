--  Optional INTn support for the W5500 socket engine.
--
--  Calling Enable arms the W5500's socket interrupts and wires INTn (the pin the
--  Device was Setup with) to a falling-edge GPIO interrupt, then registers a
--  waiter with ESP32S3.W5500.Sockets so its blocking operations (Wait_Connected,
--  Wait_Data, Send's wait-for-SEND_OK, Connect, Disconnect) SLEEP on the
--  interrupt instead of polling.
--
--  It is entirely optional: if you never call Enable, the socket engine polls and
--  none of this runs.  If the Device was Setup with no Int pin, Enable is a no-op
--  and polling stays.  Disable reverts to polling.
--
--  A small library-level heartbeat task re-checks every 50 ms as a safety net, so
--  a blocking wait can never hang on a missed edge (the single INTn line is
--  level-shared across the eight sockets); normal events still wake instantly.

package ESP32S3.W5500.Interrupts is

   procedure Enable (Dev : in out Device);
   procedure Disable (Dev : in out Device);
   function Armed return Boolean;

end ESP32S3.W5500.Interrupts;
