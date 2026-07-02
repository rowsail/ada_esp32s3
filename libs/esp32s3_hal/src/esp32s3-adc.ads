with Ada.Finalization;
with ESP32S3.GPIO;

--  ESP32-S3 SAR ADC (analog-to-digital converter) -- one-shot reads.
--
--  Two ADC units, each with up to ten 12-bit channels mapped to fixed GPIOs:
--    ADC1 channel n -> GPIO (n + 1)   (ch0 = GPIO1 .. ch9 = GPIO10)
--    ADC2 channel n -> GPIO (n + 11)  (ch0 = GPIO11 .. ch9 = GPIO20)
--  This driver does software-triggered single conversions through the RTC
--  controller.  Each conversion returns a raw 0 .. 4095 code; per-channel input
--  attenuation sets the full-scale voltage (0 dB ~ 1.1 V .. 12 dB ~ 3.3 V).
--
--  Ownership: a unit is a shared resource handed out as a CLAIMED handle, LIMITED
--  (non-copyable) and CONTROLLED (released automatically on scope exit).  Uses
--  finalization, so it targets the embedded/full profile.

package ESP32S3.ADC is

   type ADC_Unit is (ADC1, ADC2);
   type Channel_Index is range 0 .. 9;

   --  Input attenuation -> approximate full-scale input voltage.
   type Attenuation is (Db_0, Db_2_5, Db_6, Db_12);

   subtype Raw_Value is
     Natural range 0 .. 4095;     --  12-bit conversion result

   --  Non-copyable handle to a claimed ADC unit (check Is_Valid after Claim).
   type Reader is limited private;

   procedure Claim (R : in out Reader; Unit : ADC_Unit);
   function Is_Valid (R : Reader) return Boolean;
   procedure Release (R : in out Reader);

   --  Read one sample from channel Ch at the given attenuation (blocking; a
   --  conversion takes a few microseconds).  Returns 0 on an invalid handle.
   function Read
     (R : Reader; Ch : Channel_Index; Atten : Attenuation := Db_12)
      return Raw_Value;

   --  The GPIO a unit's channel is wired to (for routing / documentation).
   function Channel_Pin
     (Unit : ADC_Unit; Ch : Channel_Index) return ESP32S3.GPIO.Pin_Id;

   --  Diagnostics: the self-calibrated initial code, and whether the most recent
   --  conversion's DONE flag asserted (False => the SAR did not convert).
   function Cal_Code (Unit : ADC_Unit) return Natural;
   function Last_Done return Boolean;

private
   type Reader is new Ada.Finalization.Limited_Controlled with record
      Unit : ADC_Unit := ADC1;
      Held : Boolean := False;
   end record;
   overriding
   procedure Finalize (R : in out Reader);
end ESP32S3.ADC;
