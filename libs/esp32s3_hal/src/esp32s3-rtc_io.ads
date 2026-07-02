with ESP32S3.GPIO;

--  ESP32-S3 RTC-IO: the low-power GPIO domain (GPIO0 .. GPIO21 are RTC-capable).
--
--  The headline feature is pad HOLD: latch a pad at its current output level so
--  it keeps driving while the rest of the chip changes -- and, crucially, while
--  the chip is in deep sleep (the digital core powers down, but a held RTC pad
--  stays put) and across the reset that a deep-sleep wake causes.  Use it to keep
--  a load enabled / a reset line asserted while you sleep.
--
--  A held pad ignores ordinary GPIO writes until you Release it.  No tasking is
--  required (register pokes); RTC-IO works under every runtime profile.

package ESP32S3.RTC_IO is

   --  The RTC-capable pads.
   subtype RTC_Pin is ESP32S3.GPIO.Pin_Id range 0 .. 21;

   --  Latch Pin at its current level.  After this, GPIO Set/Clear on Pin have no
   --  effect on the pad until Release; the level survives deep sleep and the
   --  wake reset.  (Set the pad to the wanted output level first.)
   procedure Hold (Pin : RTC_Pin);

   --  Release the latch; the pad follows the GPIO output register again.
   procedure Release (Pin : RTC_Pin);

   --  True while Pin is held.
   function Is_Held (Pin : RTC_Pin) return Boolean;

   --  Route Pin into the RTC domain as an input.  This connects its RTC pull (so
   --  the pad holds a defined level in the RTC domain, including deep sleep) and
   --  keeps it readable with ESP32S3.GPIO.Read.  Call before Set_Pull.
   procedure Enable_RTC_Input (Pin : RTC_Pin);

   --  RTC-domain pull-up / pull-down on a pad.  These are the RTC pulls (active
   --  in the RTC domain, including deep sleep), distinct from the digital IO_MUX
   --  pulls configured through ESP32S3.GPIO; they take effect once the pad is in
   --  the RTC domain (Enable_RTC_Input).
   type Pull_Mode is (No_Pull, Up, Down);
   procedure Set_Pull (Pin : RTC_Pin; Mode : Pull_Mode);

end ESP32S3.RTC_IO;
