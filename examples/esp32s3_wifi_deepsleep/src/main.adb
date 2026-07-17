--  ESP32-S3: associate to Wi-Fi, then deep-sleep -- the RTC power-down IS the
--  radio power-down.
--
--  What it demonstrates:
--    Bring the radio up (ESP32S3.WiFi.Initialize), associate to the AP in
--    Wifi_Credentials, hold the link briefly, then enter deep sleep via
--    ESP32S3.RTC.Deep_Sleep_For.  In deep sleep the RTC controller powers down
--    the entire digital + RF domain -- the Wi-Fi radio, the MAC and the CPU all
--    lose power -- so no explicit esp_wifi_stop / phy_close_rf is required: the
--    sleep itself is the power-down.  (The lower-MAC blob already cycles the RF
--    on/off continuously while running; deep sleep then cuts the domain.)  The
--    timer wake RESETS the chip, which re-runs Main and re-initialises the radio
--    from scratch; a boot counter in retained RTC memory (survives deep sleep)
--    proves the cycle.  After a few cycles it stays awake and repeats a FINAL
--    line so the console can be caught (the console drops during each sleep).
--
--  Build & run:  ./x run esp32s3_wifi_deepsleep  (or ./build.sh + ./flash.sh).
--    First copy src/wifi_credentials.ads.template to src/wifi_credentials.ads
--    and fill in your network (the real file is git-ignored).
--
--  Output: per boot, a banner, the wake cause + retained boot-count, "Initialize
--    ... OK", "*** ASSOCIATED ***", then "Entering deep sleep ..." -- with the
--    count climbing 1 -> 2 -> 3 across the deep-sleep resets, then a repeated
--    "[final]" line.
--
--  Hardware: none beyond the board.  Console is on UART0 (this board is a
--    UART-bridge, not the USB-serial-JTAG); a JTAG board would use the default
--    console instead (its console drops across each sleep either way).

with Interfaces;   use Interfaces;
with Wifi_Credentials;
with Ada.Real_Time; use Ada.Real_Time;
with ESP32S3.Log;   use ESP32S3.Log;
with ESP32S3.WiFi;  use ESP32S3.WiFi;
with ESP32S3.RTC;
with ESP32S3.UART;
with ESP32S3.UART.Text;
with ESP32S3.Serial;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is

   --  UART-bridge board: route console to UART0 (as esp32s3_wifi_scan does).
   Con : aliased ESP32S3.UART.Session;

   use ESP32S3.RTC;

   function Status_Image (S : Status) return String is
     (case S is
        when OK              => "OK",
        when Not_Initialized => "NOT_INITIALIZED",
        when Busy            => "BUSY",
        when Timeout         => "TIMEOUT",
        when Radio_Error     => "RADIO_ERROR");

   function Cause_Name (Wake : Wake_Cause) return String is
     (case Wake is
        when Power_On         => "power-on",
        when Deep_Sleep_Timer => "deep-sleep-timer",
        when Deep_Sleep_GPIO  => "deep-sleep-gpio",
        when Other_Reset      => "other-reset");

   Target_SSID  : constant String := Wifi_Credentials.SSID;
   Target_Pass  : constant String := Wifi_Credentials.Pass;
   Target_BSSID : constant MAC_Address :=
     MAC_Address (Wifi_Credentials.BSSID);

   Wake : constant Wake_Cause := Last_Wake;

   --  Boot counter in retained RTC slow memory (word 0); survives deep sleep.
   Counter_Word : constant Word_Index := 0;
   Boot_Count   : Unsigned_32 := Read (Counter_Word);

   --  Timer wake delay (approximate: uncalibrated ~136 kHz RTC slow clock).
   Sleep_Duration   : constant Duration := 5.0;

   --  Stay awake once we have proven the sleep/wake cycle this many times.
   Final_Boot_Count : constant Unsigned_32 := 3;

   St    : Status;
   Found : AP_List (1 .. 20);
   Count : Natural;
begin
   ESP32S3.UART.Acquire (Con, ESP32S3.UART.UART0);
   ESP32S3.Serial.Set_Output (ESP32S3.UART.Text.As_Device (Con));

   delay until Clock + Milliseconds (200);
   Disable_Super_Watchdog;   --  a deep-sleep wake can leave it armed

   --  A deep-sleep wake continues the count; power-on / flash reset starts fresh.
   if Wake = Deep_Sleep_Timer or else Wake = Deep_Sleep_GPIO then
      Boot_Count := Boot_Count + 1;
   else
      Boot_Count := 1;
   end if;
   Write (Counter_Word, Boot_Count);

   Put_Line ("");
   Put_Line ("=== ESP32-S3 Wi-Fi + deep sleep ===");
   Put ("boot: wake=");
   Put (Cause_Name (Wake));
   Put ("  retained boot-count=");
   Put (Integer (Boot_Count));
   New_Line;

   Put ("Initialize ... ");
   Initialize (St);
   Put_Line (Status_Image (St));

   if St = OK then
      --  A quick scan shows the radio is live before we associate.
      Scan (Found, Count, St);
      if St = OK then
         Put ("Scan found ");
         Put (Count);
         Put_Line (" AP(s)");
      end if;

      Put_Line ("Connecting to AP '" & Target_SSID & "' ...");
      Connect (Target_SSID, Target_Pass, BSSID => Target_BSSID, Result => St);
      Put ("  connect start: ");
      Put_Line (Status_Image (St));

      --  Hold the link up briefly (radio on, ~100 mA measurable) before sleep.
      for I in 1 .. 3 loop
         delay until Clock + Seconds (1);
         Put ("  connected=");
         Put_Line ((if Connected then "yes" else "no"));
      end loop;
   else
      Put_Line ("  init failed -- sleeping anyway to retry on the next boot.");
   end if;

   --  Once the cycle is proven a few times, stay awake and repeat the final
   --  state so it can be captured (the console drops during each sleep).
   if Boot_Count >= Final_Boot_Count then
      loop
         Put ("[final] cycled ");
         Put (Integer (Boot_Count));
         Put_Line (" boots across deep sleep -- staying awake.");
         delay until Clock + Seconds (3);
      end loop;
   end if;

   Put_Line ("Entering deep sleep -- the RTC power-down cuts the Wi-Fi RF, MAC");
   Put_Line ("and CPU domain (this IS the radio power-down); timer will wake us.");
   delay until Clock + Milliseconds (50);   --  let the UART FIFO drain first
   Deep_Sleep_For (Sleep_Duration);         --  does not return; chip resets

   --  Reached only if the deep-sleep FSM rejected the request (see RTC).
   loop
      delay until Clock + Seconds (1);
   end loop;
end Main;
