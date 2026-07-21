with System;
with ESP32S3.GPIO;
with ESP32S3.GDMA;

--  RAW LCD_CAM (i80 parallel) register driver -- the ZFP-safe *mechanism* with
--  NO mutual exclusion.  PRIVATE child: only the ESP32S3.LCD subtree may use it;
--  the application reaches LCD only through the task-safe parent, which hides the
--  Bus handle and hands it out solely through its ownership-checked gateway.
--  This is the only unit that names the LCD_CAM registers and owns the GDMA
--  channel.
--
--  (Data_Pins is declared in the parent and used here by child visibility.)

private package ESP32S3.LCD.Engine is

   --  A configured controller.  No GDMA channel is held while idle: Transmit
   --  claims one transiently, for the duration of the transfer only.
   type Bus is limited private;

   --  Bring the LCD up in 8-bit mode at (about) Pclk_Hz.  No DMA channel is
   --  claimed here.  Is_Valid is True once the controller is configured.
   procedure Open (B : in out Bus; Pclk_Hz : Positive);
   function Is_Valid (B : Bus) return Boolean;

   --  Route the data bus and pixel clock to physical pads.
   procedure Configure_Pins (B : Bus; Data : Data_Pins; Pclk : ESP32S3.GPIO.Optional_Pin);

   --  Bring the LCD up in RGB mode: clock, colour depth and panel timing.  No
   --  DMA channel or refresh is started here.  (RGB_Config / RGB_Pins are
   --  declared in the parent and used here by child visibility.)
   procedure Open_RGB (B : in out Bus; Config : RGB_Config);
   procedure Configure_RGB_Pins (B : Bus; Pins : RGB_Pins);

   --  Start / update / stop continuous RGB refresh.  Start_RGB claims a GDMA
   --  channel bound to LCD_CAM and streams Framebuffer (Length bytes, may be
   --  PSRAM) to the panel forever; Flush_RGB writes an updated framebuffer back
   --  to PSRAM for the DMA to re-read; Stop_RGB halts and frees the channel.
   procedure Start_RGB (B : Bus; Framebuffer : System.Address; Length : Natural);
   procedure Flush_RGB (Framebuffer : System.Address; Length : Natural);
   procedure Stop_RGB;

   --  DOUBLE-BUFFERED bounce mode: like Start_RGB but two framebuffers.  Draw the
   --  Back_Buffer, then Flip -- the refill switches source at the next frame
   --  boundary (tear-free), Flip blocks until the old front is free.  No Flush.
   procedure Start_RGB_DB (B : Bus; Fb0, Fb1 : System.Address; Length : Natural);

   --  DIRECT double-buffered RGB: stream Fb0 straight from PSRAM (near-zero CPU),
   --  Fb1 as the back.  Do all framebuffer work in blanking: Sync, draw
   --  Back_Buffer, Flush_RGB it, Flip.  Fragile vs bounce (shared PSRAM bus).
   procedure Start_RGB_Direct (B : Bus; Fb0, Fb1 : System.Address; Length : Natural);
   procedure Sync (B : Bus);

   --  Flip + Back_Buffer serve whichever mode is live (bounce-DB or direct).
   procedure Flip (B : Bus);
   function Back_Buffer return System.Address;

   --  Free-run the pixel clock continuously on Pclk_Pad (no data transaction).
   procedure Enable_Clock_Out (B : Bus; Pclk_Pad : ESP32S3.GPIO.Pin_Id);

   --  Stream Length bytes (1 .. 4095) from Tx out the data bus, one per PCLK.
   --  Ok is True once the transfer completes.
   procedure Transmit (B : Bus; Tx : System.Address; Length : Natural; Ok : out Boolean)
   with Pre => Length in 1 .. 4095;

private
   type Bus is limited record
      Valid : Boolean := False;        --  controller configured by Open
   end record;
end ESP32S3.LCD.Engine;
