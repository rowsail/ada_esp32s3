with System;
with System.Storage_Elements;
with Interfaces;
with ESP32S3.GPIO;
with ESP32S3.RTC_IO;

--  ESP32-S3 RTC low-power domain: retained memory, deep sleep, and wake sources.
--
--  In deep sleep the digital core (CPU + main RAM) is powered down; only the RTC
--  domain stays alive, so on wake the chip RESETS and re-runs from the start --
--  but data kept in RTC memory survives.  This package gives you: a pointer to
--  that retained memory, the cause of the current boot (power-on vs woken from
--  deep sleep), and deep-sleep entry with a timer or an RTC-GPIO wake source.
--
--  No tasking is required; the operations are simple register pokes.  It still
--  lives with the embedded/full drivers (it has no certifiable-profile barrier,
--  but is grouped with the rest of the HAL).
package ESP32S3.RTC is

   ----------------------------------------------------------------------------
   --  Retained memory.
   --
   --  RTC slow memory (8 KB at 0x5000_0000) keeps its contents across deep sleep
   --  and most resets (power-on clears it).  Overlay your own data on it, e.g.
   --     Boot_Count : Interfaces.Unsigned_32
   --       with Import, Volatile, Address => ESP32S3.RTC.Slow_Memory;
   --  (the very start may be used by the ULP coprocessor if you enable it; this
   --  HAL does not, so the whole region is free here).
   ----------------------------------------------------------------------------

   Slow_Memory      : constant System.Address := System'To_Address (16#5000_0000#);
   Slow_Memory_Size : constant := 8 * 1024;

   --  Word-addressed access to the retained region (a bounds-checked alternative
   --  to overlaying your own variable on Slow_Memory).  Index is a 32-bit word
   --  index, 0 .. 2047.
   subtype Word_Index is Natural range 0 .. Slow_Memory_Size / 4 - 1;

   function  Read  (Index : Word_Index) return Interfaces.Unsigned_32;
   procedure Write (Index : Word_Index; Value : Interfaces.Unsigned_32);

   --  Typed retained object: instantiate once per stored item, giving a distinct
   --  byte Offset into the region.  The Object persists across deep sleep.
   --     package Counter is new ESP32S3.RTC.Retained (Unsigned_32, Offset => 0);
   --     ... Counter.Object := Counter.Object + 1; ...
   generic
      type Item is private;
      Offset : Natural := 0;          --  byte offset into Slow_Memory
   package Retained is
      Object : Item
        with Import, Volatile,
             Address => System.Storage_Elements."+"
                          (Slow_Memory,
                           System.Storage_Elements.Storage_Offset (Offset));
   end Retained;

   ----------------------------------------------------------------------------
   --  Boot / wake cause.
   ----------------------------------------------------------------------------

   type Wake_Cause is (Power_On, Deep_Sleep_Timer, Deep_Sleep_GPIO, Other_Reset);

   --  Why the chip is running now (read from the RTC reset + wake-cause regs).
   function Last_Wake return Wake_Cause;

   --  Raw RTC reset-cause code (5 = deep-sleep wake) and wake-source bits, for
   --  callers that want the unmapped values.
   function Raw_Reset_Cause return Natural;
   function Raw_Wake_Cause  return Natural;

   --  If a deep-sleep call returns instead of sleeping, the FSM rejected it;
   --  this gives the reject-cause bits.
   function Raw_Reject_Cause return Natural;

   ----------------------------------------------------------------------------
   --  Deep sleep.  These do NOT return: the chip powers its digital core down
   --  and resets on wake (re-running from the start, with RTC memory intact).
   ----------------------------------------------------------------------------

   --  Sleep and wake after (approximately) Wake_After.  The timer runs on the
   --  uncalibrated RTC slow clock (~136 kHz), so the delay is approximate.
   procedure Deep_Sleep_For (Wake_After : Duration);

   --  Sleep until an RTC-capable pin reaches High/low (EXT1 wake).  Only RTC pads
   --  (GPIO 0 .. 21) can wake the chip, so the parameter is the RTC_Pin subtype:
   --  a non-RTC pin is a caught constraint, not a silent never-wake (the EXT1
   --  select mask is a 22-bit field, and 2**Pin for Pin > 21 wrapped to 0 -> no
   --  pad selected -> the chip would sleep forever).  Needs an external signal on
   --  the pad; configure the pad as an input first.
   procedure Deep_Sleep_Until
     (Pin : ESP32S3.RTC_IO.RTC_Pin; High : Boolean := True);

   --  Auto-feed (effectively disable) the RTC super-watchdog.  A deep-sleep wake
   --  can leave it armed, so call this if a woken app means to stay awake.
   procedure Disable_Super_Watchdog;

end ESP32S3.RTC;
