with System;
with ESP32S3.GPIO;
with ESP32S3_Registers; use ESP32S3_Registers;
with ESP32S3_Registers.RTC_CNTL;
with ESP32S3_Registers.RTC_IO;

package body ESP32S3.RTC_IO is

   --  RTC_CNTL_PAD_HOLD: one bit per RTC pad, bit n = hold for GPIO n (0 .. 21).
   --  (The svd names the fields TOUCH_PADn_HOLD / X32x / PDACx / PADn, but the
   --  bit positions are simply the GPIO number, so treat it as a 22-bit mask.)
   Pad_Hold : UInt32
   with
     Volatile,
     Import,
     Address => ESP32S3_Registers.RTC_CNTL.RTC_CNTL_Periph.PAD_HOLD'Address;

   function Bit (Pin : RTC_Pin) return UInt32
   is (2**Natural (Pin));

   procedure Hold (Pin : RTC_Pin) is
   begin
      Pad_Hold := Pad_Hold or Bit (Pin);
   end Hold;

   procedure Release (Pin : RTC_Pin) is
   begin
      Pad_Hold := Pad_Hold and not Bit (Pin);
   end Release;

   function Is_Held (Pin : RTC_Pin) return Boolean
   is ((Pad_Hold and Bit (Pin)) /= 0);

   --  The 22 per-pad RTC_IO config registers are consecutive (GPIO n at
   --  TOUCH_PAD0 + 4*n) and all carry the pull-up/down enables at the same bits
   --  (RUE = 27, RDE = 28), so re-impose them as a plain word array.
   type Pad_Array is array (Natural range 0 .. 21) of UInt32 with Volatile;
   Pads : Pad_Array
   with
     Volatile,
     Import,
     Address => ESP32S3_Registers.RTC_IO.RTC_IO_Periph.TOUCH_PAD0'Address;

   RUE : constant UInt32 := 2**27;    --  pull-up enable
   RDE : constant UInt32 := 2**28;    --  pull-down enable

   procedure Set_Pull (Pin : RTC_Pin; Mode : Pull_Mode) is
      V : UInt32 := Pads (Natural (Pin)) and not (RUE or RDE);
   begin
      case Mode is
         when Up      =>
            V := V or RUE;

         when Down    =>
            V := V or RDE;

         when No_Pull =>
            null;
      end case;
      Pads (Natural (Pin)) := V;
   end Set_Pull;

   MUX_SEL : constant UInt32 :=
     2**19;   --  select the RTC function for the pad
   Fun_IE  : constant UInt32 := 2**13;   --  input-enable in the RTC domain

   procedure Enable_RTC_Input (Pin : RTC_Pin) is
   begin
      Pads (Natural (Pin)) := Pads (Natural (Pin)) or MUX_SEL or Fun_IE;
   end Enable_RTC_Input;

end ESP32S3.RTC_IO;
