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

   ----------------------------------------------------------------------------
   --  RGB parallel mode -- a TFT panel driven by continuous HSYNC / VSYNC / DE /
   --  PCLK timing (as opposed to the command-driven i8080 mode above).
   --
   --  Acquire_RGB INITIALISES the peripheral: it enables the controller, sets the
   --  pixel clock, programs the panel timing, and routes the data + sync pins.
   --  It does NOT yet stream a framebuffer -- setting up the continuously-
   --  refreshing DMA from a PSRAM framebuffer, the frame interrupt and the
   --  double-buffer flip is the next step.  Ownership-checked like the i8080 path.
   ----------------------------------------------------------------------------

   --  Up to 16 RGB data lines (D0 .. D15): use 0 .. 15 for a 16-bit (RGB565)
   --  panel, 0 .. 7 for an 8-bit (RGB332) one.  Any line may be left unrouted.
   type RGB_Data_Pins is array (0 .. 15) of ESP32S3.GPIO.Optional_Pin;

   --  Panel timing (from its datasheet) + colour depth + signal polarities.
   --  Horizontal widths/porches are in pixel clocks; vertical, in lines.
   type RGB_Config is record
      H_Res   : Positive;          --  active pixels per line   (e.g. 800)
      V_Res   : Positive;          --  active lines per frame   (e.g. 480)
      H_Sync  : Positive;          --  HSYNC pulse width
      H_Back  : Positive;          --  horizontal back porch
      H_Front : Positive;          --  horizontal front porch
      V_Sync  : Positive;          --  VSYNC pulse width
      V_Back  : Positive;          --  vertical back porch
      V_Front : Positive;          --  vertical front porch
      Pclk_Hz : Positive;          --  pixel clock (e.g. 30_000_000)
      Two_Byte        : Boolean := True;   --  True: 16-bit RGB565; False: 8-bit
      HSync_Idle_High : Boolean := True;   --  idle level (active-low HSYNC => True)
      VSync_Idle_High : Boolean := True;
      DE_Idle_High    : Boolean := False;  --  DE is usually active-high => idle low
      Pclk_Falling    : Boolean := False;  --  latch data on the falling PCLK edge
   end record;

   --  Which LCD_DATA_OUT signal (0 .. 15) drives each panel data line.  Default
   --  is 1:1 (line i <- LCD_DATA_OUT i).  For an 8-bit (RGB332) framebuffer on a
   --  16-bit RGB565 panel, point several panel lines at the low 8 signals to fan
   --  the colour bits out (bit replication) -- the LCD_CAM shifts one byte/pixel
   --  yet the panel still receives full-width RGB565.  The GPIO matrix allows one
   --  output signal to drive many pads, so this costs nothing at run time.
   type RGB_Signal_Map is array (0 .. 15) of Natural;
   Identity_Signals : constant RGB_Signal_Map :=
     (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15);

   --  The RGB data lines plus the four control signals.
   type RGB_Pins is record
      Data    : RGB_Data_Pins := (others => No_Pin);
      Signals : RGB_Signal_Map := Identity_Signals;
      Pclk    : ESP32S3.GPIO.Optional_Pin := No_Pin;
      HSync   : ESP32S3.GPIO.Optional_Pin := No_Pin;
      VSync   : ESP32S3.GPIO.Optional_Pin := No_Pin;
      DE      : ESP32S3.GPIO.Optional_Pin := No_Pin;
   end record;

   --  Take ownership and bring the controller up in RGB mode with Config's
   --  timing, routing Pins.  Initialises the peripheral only (see above).
   procedure Acquire_RGB (S : in out Session; Config : RGB_Config; Pins : RGB_Pins);

   --  Start continuous refresh from Framebuffer (call after Acquire_RGB).
   --  Framebuffer holds Length bytes = H_Res * V_Res * (2 for RGB565, 1 for
   --  8-bit); it should be a 32-byte-aligned buffer -- in PSRAM for anything
   --  above ~a few tens of KB (an 800x480x2 framebuffer is 768 000 B).  A GDMA
   --  channel streams it to the panel forever.  After drawing into it, call Flush
   --  so the DMA re-reads the change.  Stop_RGB halts the refresh and frees the
   --  channel.  Raise Not_Owned unless S holds the controller.
   procedure Start_RGB
     (S : Session; Framebuffer : System.Address; Length : Natural);
   procedure Flush (S : Session; Framebuffer : System.Address; Length : Natural);
   procedure Stop_RGB (S : Session);

   --  DOUBLE-BUFFERED bounce refresh: two Length-byte PSRAM framebuffers.  The
   --  panel shows one while you draw the other (Back_Buffer); Flip shows what you
   --  drew -- the driver switches source at the next frame boundary (tear-free)
   --  and Flip blocks until the old front is free to draw again.  Rock-solid at
   --  any update rate (scan-out is from SRAM), and needs no Flush or Sync.  This
   --  is the robust way to "draw one while displaying the other".
   procedure Start_RGB
     (S : Session; Fb0, Fb1 : System.Address; Length : Natural);

   --  DIRECT double-buffered refresh (an alternative to Start_RGB's bounce mode):
   --  the GDMA scans Fb0 STRAIGHT from PSRAM -- near-zero CPU, no per-frame copy.
   --  Fb0/Fb1 are two Length-byte PSRAM framebuffers.  Because the scan-out DMA
   --  shares the PSRAM bus, all framebuffer work must happen in vertical blanking
   --  (where the DMA is idle) or it tears.  So the per-frame loop is:
   --      LCD.Sync (S);                        --  wait for blanking
   --      ... draw into LCD.Back_Buffer (S) ...
   --      LCD.Flush (S, region ...);           --  write the change back to PSRAM
   --      LCD.Flip (S);                        --  swap buffers (tear-free here)
   --  This suits LIGHT / incremental updates that fit the blanking window; heavy
   --  full-frame animation wants Start_RGB (bounce).  Stop_RGB stops either mode.
   procedure Start_RGB_Direct
     (S : Session; Fb0, Fb1 : System.Address; Length : Natural);
   procedure Sync (S : Session);
   procedure Flip (S : Session);
   function Back_Buffer (S : Session) return System.Address;

   procedure Release (S : in out Session);

private
   type Session is new Ada.Finalization.Limited_Controlled with record
      Active : Boolean := False;
   end record;
   overriding
   procedure Finalize (S : in out Session);
end ESP32S3.LCD;
