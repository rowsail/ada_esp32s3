--  What it demonstrates
--  ---------------------
--  A string of 74HC595 shift registers driven over SPI: MOSI->SER, SCLK->SRCLK,
--  a GPIO RCLK latch and a GPIO /OE.  It walks a single high output across the
--  whole string ("chase"), so you can watch it on LEDs or a scope and confirm
--  the wiring, the chip count, and the bit/chip ordering.
--
--  WIRING (confirm/edit the constants below): SCLK/MOSI are the board's shared
--  SPI2 pads; RCLK = IO5, /OE = IO6; three chips daisy-chained = 24 outputs.
--
--    ./x run esp32s3_hc595   --  then watch the outputs / serial console
with ESP32S3.GPIO;
with ESP32S3.SPI;
with ESP32S3.HC595;
with ESP32S3.Log; use ESP32S3.Log;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   --  ==== board wiring -- confirm/edit ====
   Sclk_Pin : constant := 1;   --  SPI2 SCLK -> 595 SRCLK
   Mosi_Pin : constant := 4;   --  SPI2 MOSI -> 595 SER
   RCLK_Pin : constant ESP32S3.GPIO.Pin_Id := 5;   --  IO5 -> 595 RCLK (latch)
   OE_Pin   : constant ESP32S3.GPIO.Pin_Id := 6;   --  IO6 -> 595 /OE
   Chips    : constant := 3;
   --  ======================================

   SR : ESP32S3.HC595.Controller (Chips);
   N  : Natural;
begin
   Put_Line ("");
   Put_Line ("=== 74HC595 string -- chase test ===");

   --  Bring the shared SPI2 bus up and route its lines (no MISO -- write-only).
   ESP32S3.SPI.Setup (ESP32S3.SPI.SPI2);
   ESP32S3.SPI.Configure_Pins
     (ESP32S3.SPI.SPI2, Sclk => Sclk_Pin, Mosi => Mosi_Pin, Miso => ESP32S3.GPIO.No_Pin);

   ESP32S3.HC595.Initialize (SR, Host => ESP32S3.SPI.SPI2, RCLK => RCLK_Pin, OE => OE_Pin);

   N := ESP32S3.HC595.Output_Count (SR);
   Put (N, 0);
   Put_Line (" outputs; chasing...");

   loop
      for I in 0 .. N - 1 loop
         ESP32S3.HC595.Clear_All (SR);              --  all off
         ESP32S3.HC595.Write_Output (SR, I, True);  --  activate output I
         Put_Line ("  Q" & Natural'Image (I) & " high");
         delay 0.25;                                --  250 ms per output
      end loop;
   end loop;                                        --  then repeat the cycle
end Main;
