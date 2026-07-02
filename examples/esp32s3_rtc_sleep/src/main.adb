--  Ada RTC deep-sleep + retained-memory self-test (ESP32-S3, no FreeRTOS, no IDF)
--  ============================================================================
--  What it demonstrates:
--    The reusable HAL RTC driver (ESP32S3.RTC).  A boot counter lives in
--    retained RTC slow memory, which survives deep sleep -- in deep sleep the
--    digital core powers down and the chip RESETS on wake, re-running Main from
--    the start, but the RTC domain (and its memory) stays alive.  Each boot we
--    read the wake cause, bump the counter, and -- for the first few boots --
--    deep-sleep with a timer wake.  The counter persisting across the resets,
--    and the wake cause turning into "deep-sleep-timer", proves retained memory
--    + deep sleep + timer wake.  After a few cycles the board stays awake and
--    repeats the final state so it can be captured cleanly (the USB-JTAG console
--    drops during each sleep).
--
--  Build & run:  ./x run esp32s3_rtc_sleep
--    Built as the embedded profile (build.sh sets ESP32S3_RTS_PROFILE=embedded),
--    not the default light-tasking.
--  Output:  a banner, then one "[rtc] boot:" line per boot showing the wake
--    cause and the retained boot-count climbing 1 -> 2 -> 3 -> 4 across the
--    deep-sleep resets, then a repeated "[rtc] FINAL:" line.  PASS means the
--    counter reached 4 (so it survived the resets) and the last wake was a
--    deep-sleep timer wake.
--  Hardware:  none (self-contained; timer wake, no wake-source wiring).
with Interfaces;    use Interfaces;
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.RTC;
with ESP32S3.Log; use ESP32S3.Log;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   --  Human-readable wake-cause name.  Indexed by the integer code: either
   --  Wake_Cause'Pos of a mapped cause (Power_On=0, Deep_Sleep_Timer=1,
   --  Deep_Sleep_GPIO=2, Other_Reset=3), or a raw reject-cause code.
   function Cause_Name (Cause_Code : Integer) return String
   is (case Cause_Code is
         when 0      => "power-on",
         when 1      => "deep-sleep-timer",
         when 2      => "deep-sleep-gpio",
         when others => "other-reset");

   use ESP32S3.RTC;
   Wake : constant Wake_Cause := Last_Wake;

   --  The boot counter, kept in retained RTC slow memory (word 0) via the
   --  driver's Read/Write accessors.
   Counter_Word : constant Word_Index := 0;
   Boot_Count   : Unsigned_32 := Read (Counter_Word);

   --  How long the digital core stays powered down before the RTC timer wakes
   --  it (approximate -- it runs on the uncalibrated ~136 kHz RTC slow clock).
   Sleep_Duration : constant Duration := 2.0;

   --  Stay awake and stop deep-sleeping once the counter reaches this many
   --  boots -- enough resets to prove the counter survived and incremented.
   Final_Boot_Count : constant Unsigned_32 := 4;

   --  Boot-count value printed when a deep-sleep call was rejected (returned
   --  instead of sleeping) -- a sentinel that can't occur on a real boot.
   Sleep_Rejected_Marker : constant Integer := -1;
begin
   delay until Clock + Milliseconds (200);
   Put_Line ("[rtc] bare-metal RTC deep-sleep + retained-memory self-test");
   Disable_Super_Watchdog;     --  a deep-sleep wake can leave it armed

   --  A deep-sleep wake continues the count; anything else (power-on / a flash
   --  reset) starts fresh at 1.
   if Wake = Deep_Sleep_Timer or else Wake = Deep_Sleep_GPIO then
      Boot_Count := Boot_Count + 1;
   else
      Boot_Count := 1;
   end if;
   Write (Counter_Word, Boot_Count);               --  persist it

   Put ("[rtc] boot: wake=");
   Put (Cause_Name (Wake_Cause'Pos (Wake)));
   Put ("  retained boot-count=");
   Put (Integer (Boot_Count));
   New_Line;

   if Boot_Count < Final_Boot_Count then
      --  Sleep ~2 s and wake via the RTC timer; this does not return on success.
      Put_Line ("[rtc] entering deep sleep for ~2000 ms " & "(console drops until wake)...");
      delay until Clock + Milliseconds (50);     --  let the console flush
      Deep_Sleep_For (Sleep_Duration);
      --  Only reached if the sleep was rejected -- report the cause and stop.
      loop
         Put ("[rtc] FINAL: boot-count=");
         Put (Sleep_Rejected_Marker);
         Put ("  last-wake=");
         Put (Cause_Name (Integer (Raw_Reject_Cause)));
         Put ("  ");
         Put_Line ("FAIL");
         delay until Clock + Seconds (2);
      end loop;
   end if;

   --  Reached only after several wake cycles: stay awake and report the result
   --  (counter advanced past 1, and the last wake was a deep-sleep timer wake).
   loop
      Put ("[rtc] FINAL: boot-count=");
      Put (Integer (Boot_Count));
      Put ("  last-wake=");
      Put (Cause_Name (Wake_Cause'Pos (Wake)));
      Put ("  ");
      Put_Line
        (if Boot_Count >= Final_Boot_Count and then Wake = Deep_Sleep_Timer
         then "PASS"
         else "FAIL");
      delay until Clock + Seconds (2);
   end loop;
end Main;
