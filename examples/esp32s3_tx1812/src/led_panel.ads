with ESP32S3.TX1812;

--  The LED string, declared at LIBRARY LEVEL on purpose: its storage is reserved
--  at ELABORATION (it lands in .bss), not on a task stack.  Because a Strip is
--  statically sized by its Count discriminant, declaring `Panel : Strip (64)`
--  here reserves -- at build time -- the 64 pixel colours AND the 64*24 = 1536
--  RMT-symbol frame buffer.  If it does not fit, the LINK fails, so "do we have
--  enough memory for 64 LEDs?" is answered by the build, not at run time.
--
--  Footprint:  64 * 3 colour bytes  +  1536 * 4 symbol bytes  ~= 6.4 KiB
--  (plus the small RMT channel handle) -- check it in app.map under `led_panel`.

package LED_Panel is

   LED_Count : constant := 64;

   Panel : ESP32S3.TX1812.Strip (Count => LED_Count);

end LED_Panel;
