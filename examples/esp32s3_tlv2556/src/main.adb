--  TI TLV2556 12-bit serial ADC bring-up on the bare-metal ESP32-S3
--  ================================================================
--  What it demonstrates
--    The reusable HAL driver ESP32S3.TLV2556 on a TI TLV2556 12-bit, 11-channel
--    SPI ADC that shares SPI2 with the other devices on the bus (its chip select
--    is its own GPIO, IO12, driven through the SPI driver's application
--    chip-select callback -- exactly like the W25Q flash on IO21).  It:
--      1. brings the converter up (programs configuration register 2),
--      2. reads the three internal SELF-TEST voltages, which are ratiometric to
--         the reference rails and so read fixed codes (0 / 2048 / 4095)
--         regardless of the reference voltage or any analog wiring -- a complete
--         end-to-end check of the SPI protocol with nothing connected to the
--         analog inputs,
--      3. reads analog input AIN0 and reports its raw code.
--
--  Build & run
--    ./x run esp32s3_tlv2556          --  embedded profile (build.sh sets it)
--    Report prints over USB-Serial-JTAG via ESP32S3.Log.
--
--  Output (with the ADC wired)
--    [tlv2556] TI TLV2556 12-bit ADC bring-up (SPI2, CS=IO12)
--    [tlv2556] self-test: zero=0 half=2048 full=4095   PASS
--    [tlv2556] AIN0 = 1234 / 4095
--    [tlv2556] done.
--    With nothing wired the self-test codes are wrong and it prints FAIL.
--
--  Hardware
--    TLV2556 on SPI2: SCLK=GPIO1  DATA IN<-MOSI=GPIO4  DATA OUT->MISO=GPIO45
--    CS=GPIO12.  3V3 / GND; the bus is shared with the SPI flash.
with Interfaces;    use Interfaces;
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.SPI;
with ESP32S3.TLV2556;
with ESP32S3.GPIO;
with ESP32S3.Log;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   package SPI renames ESP32S3.SPI;
   package ADC renames ESP32S3.TLV2556;
   package Log renames ESP32S3.Log;
   use type ADC.Sample;

   --  SPI2 bus pins (shared with the flash); the ADC select is its own GPIO.
   SCLK_Pin : constant := 1;
   MOSI_Pin : constant := 4;
   MISO_Pin : constant := 45;
   CS_Pin   : constant ESP32S3.GPIO.Pin_Id := 12;

   --  The TLV2556 runs its I/O clock to 10 MHz at 3.3 V; 8 MHz is comfortable.
   Clock_Hz : constant := 8_000_000;

   --  The ADC device: SPI2, its own bit clock, and its chip select on IO12.  The
   --  SPI driver applies the clock and drives the CS GPIO (active-low, held across
   --  each conversion) at Acquire -- no callback.
   Dev : ADC.Device := (Host => SPI.SPI2, Clock_Hz => Clock_Hz, CS_Pin => CS_Pin, others => <>);

   Zero, Half, Full, A0 : ADC.Sample;

   --  Allow a couple of LSB of slack on the (analog) self-test conversions.
   function Near (Got, Want : ADC.Sample; Tol : ADC.Sample) return Boolean
   is (Got <= Want + Tol and then Got + Tol >= Want);
begin
   delay until Clock + Milliseconds (200);
   Log.Put_Line ("[tlv2556] TI TLV2556 12-bit ADC bring-up (SPI2, CS=IO12)");

   SPI.Setup (SPI.SPI2);
   SPI.Configure_Pins (SPI.SPI2, Sclk => SCLK_Pin, Mosi => MOSI_Pin, Miso => MISO_Pin);

   ADC.Initialize (Dev, Ref => ADC.External);

   Zero := ADC.Read (Dev, ADC.Test_Zero);
   Half := ADC.Read (Dev, ADC.Test_Half);
   Full := ADC.Read (Dev, ADC.Test_Full);

   Log.Put ("[tlv2556] self-test: zero=");
   Log.Put (Natural (Zero));
   Log.Put (" half=");
   Log.Put (Natural (Half));
   Log.Put (" full=");
   Log.Put (Natural (Full));
   Log.Put_Line
     ((if Near (Zero, 0, 4) and then Near (Half, 2048, 8) and then Near (Full, 4095, 4)
       then "   PASS"
       else "   FAIL"));

   A0 := ADC.Read (Dev, ADC.AIN0);
   Log.Put ("[tlv2556] AIN0 = ");
   Log.Put (Natural (A0));
   Log.Put_Line (" / 4095");

   Log.Put_Line ("[tlv2556] done.");
   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
