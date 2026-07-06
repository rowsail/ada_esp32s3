with System;
with Ada.Finalization;
with ESP32S3.GPIO;

--  ESP32-S3 LCD (the LCD half of the LCD_CAM controller) -- 8-bit Intel-8080
--  parallel master, DMA-driven.
--
--  Drives an 8-bit "i80"/MCU parallel display (or any 8-bit parallel sink): a
--  byte buffer is streamed out the data bus, one byte per pixel clock (PCLK),
--  over the GDMA crossbar.  (The camera-receive half and the RGB/16-bit modes
--  are not covered here.)
--
--  The single controller is guarded by a protected object; Acquire hands out a
--  limited, controlled Session that owns it exclusively and releases on scope
--  exit.  Uses finalization, so it targets the embedded/full profile.

with ESP32S3.GDMA;

package ESP32S3.LCD is
   pragma Assertion_Policy (Pre => Check);

   No_Pin : constant ESP32S3.GPIO.Pad_Number := ESP32S3.GPIO.No_Pin;

   --  The eight parallel data lines (D0 .. D7); any may be left unrouted.
   type Data_Pins is array (0 .. 7) of ESP32S3.GPIO.Optional_Pin;

   type Session is limited private;

   ----------------------------------------------------------------------------
   --  Concurrent, mutually-exclusive use.  Acquire the controller AND configure
   --  it in the same call; every transfer plus every later reconfiguration runs
   --  through the held Session.  There is no startup call that precedes
   --  ownership: you cannot touch the controller without holding it.  Bringing
   --  it up does NOT tie up a GDMA channel -- Transmit claims one only for the
   --  duration of the transfer.
   ----------------------------------------------------------------------------

   --  Raised by any operation below if S does not hold the controller.  Each
   --  reaches the hardware only through the gateway, so "use it without holding
   --  it" fails loudly.
   Not_Owned : exception;

   --  Take exclusive ownership of the controller (suspends until free) and bring
   --  it up in 8-bit mode at (about) Pclk_Hz pixel clock (= 20 MHz / round(20
   --  MHz / Pclk_Hz)), routing the eight data lines and the pixel clock to pads.
   --  Each pin is optional (No_Pin = unrouted).  Every Acquire re-applies the
   --  clock and pin routing.
   procedure Acquire
     (S       : in out Session;
      Pclk_Hz : Positive := 1_000_000;
      Data    : Data_Pins := (others => No_Pin);
      Pclk    : ESP32S3.GPIO.Optional_Pin := No_Pin);

   --  Re-apply the pixel clock and pin routing on the held controller.  Raises
   --  Not_Owned unless S holds it.
   procedure Reconfigure
     (S       : Session;
      Pclk_Hz : Positive := 1_000_000;
      Data    : Data_Pins := (others => No_Pin);
      Pclk    : ESP32S3.GPIO.Optional_Pin := No_Pin);

   --  Re-route the data bus and pixel clock to physical pads (a finer change
   --  than Reconfigure, leaving the clock rate untouched).  Raises Not_Owned
   --  unless S holds it.
   procedure Configure_Pins (S : Session; Data : Data_Pins; Pclk : ESP32S3.GPIO.Optional_Pin);

   --  Free-run the pixel clock continuously on Pclk_Pad (no data transaction) --
   --  useful as a bus clock and for verifying the clock on its own.  On the held
   --  controller; raises Not_Owned unless S holds it.
   procedure Enable_Clock_Out (S : Session; Pclk_Pad : ESP32S3.GPIO.Pin_Id);

   --  Stream Length bytes (1 .. 4095) from Tx out the data bus, one per PCLK.
   --  Blocking; Ok is True once the transfer completes.  Buffer in internal SRAM.
   --  Raises Not_Owned unless S holds the controller.
   procedure Transmit (S : Session; Tx : System.Address; Length : Natural; Ok : out Boolean)
   with Pre => Length in 1 .. 4095;

   --  Type-safe overload (buffer 32-byte aligned + line-multiple sized).
   procedure Transmit (S : Session; Tx : ESP32S3.GDMA.DMA_Buffer; Length : Natural; Ok : out Boolean)
   with Pre => Length <= Tx'Length and then Tx'Length mod ESP32S3.GDMA.DMA_Alignment = 0;

   procedure Release (S : in out Session);

private
   type Session is new Ada.Finalization.Limited_Controlled with record
      Active : Boolean := False;
   end record;
   overriding
   procedure Finalize (S : in out Session);
end ESP32S3.LCD;
