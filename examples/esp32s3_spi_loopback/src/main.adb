--  What it demonstrates
--    An Ada SPI MASTER hardware self-test on the bare-metal ESP32-S3 (no
--    FreeRTOS, no IDF) -- exercises the reusable HAL master driver
--    (ESP32S3.SPI) with NO external wiring.
--
--    Unlike I2C, the SPI matrix CAN loop a controller's MOSI back into its own
--    MISO through one pad (Enable_Loopback), so this verifies the full duplex
--    DMA path AND the read direction on silicon, using only the master:
--      test0  loopback a 32-byte pseudo-random pattern through one pad and
--             compare MISO-captured Rx to Tx, byte for byte.  PASS = Rx = Tx,
--             which proves START..clock..capture..the GDMA in/out descriptors
--             and the bounded transfer-complete wait all work.
--      test1  the controlled (RAII) Session auto-releases the host on scope
--             exit, even via an exception: Acquire, raise, then re-acquire.
--             PASS = the re-acquire did not deadlock (the lock was freed).
--
--  Build & run
--    ./x run esp32s3_spi_loopback
--    Needs the embedded profile (the Session is a controlled type); build.sh
--    sets ESP32S3_RTS_PROFILE=embedded.
--
--  Output (over the USB-Serial-JTAG console)
--    [spi] bare-metal SPI master full-duplex DMA loopback self-test (no wiring)
--    [spi] test0 (32-byte loopback): PASS
--    [spi] test1 (RAII auto-release): PASS
--    [spi] done.
--
--  Hardware
--    None (self-contained): the master's MOSI is fed back into its own MISO on a
--    single GPIO pad through the signal matrix -- no external wiring.
with Interfaces;    use Interfaces;
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.SPI; use ESP32S3.SPI;
with ESP32S3.GPIO;
with ESP32S3.Log; use ESP32S3.Log;

--  Pull the SMP slave-start entry into the link closure (glue.c calls it after
--  elaboration); core 1 just idles -- the test runs on core 0.
with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is

   Host : constant SPI_Host := SPI2;

   --  Free general-purpose pads (avoid 26..32 = flash / PSRAM).  With internal
   --  loopback the data-out signal is fed back to data-in on Loopback_Pad, so no
   --  external wiring is needed; Sclk/Mosi/Miso just need to be valid pads.
   Sclk_Pad     : constant := 12;
   Mosi_Pad     : constant := 11;
   Miso_Pad     : constant := 13;
   Loopback_Pad : constant ESP32S3.GPIO.Pin_Id := 10;

   --  32-byte pseudo-random pattern (a large odd stride spans the byte range so
   --  a stuck/swapped line shows up).
   type Buffer is array (0 .. 31) of Unsigned_8;
   Tx : aliased Buffer;
   Rx : aliased Buffer := (others => 0);
begin
   delay until Clock + Milliseconds (200);   --  let the console settle
   Put_Line ("[spi] bare-metal SPI master full-duplex DMA loopback self-test " & "(no wiring)");

   for I in Tx'Range loop
      Tx (I) := Unsigned_8 ((I * 37 + 19) mod 256);
   end loop;

   Setup (Host);
   Configure_Pins (Host, Sclk => Sclk_Pad, Mosi => Mosi_Pad, Miso => Miso_Pad);
   Enable_Loopback (Host, Pad => Loopback_Pad);   --  MOSI -> MISO internally

   --  test0: full-duplex loopback transfer; MISO captures what MOSI shifts out.
   declare
      Session_Handle : Session;
      Ok             : Boolean;
   begin
      Acquire (Session_Handle, Host, Mode => 0, Clock_Hz => 8_000_000);
      Transfer (Session_Handle, Tx'Address, Rx'Address, Tx'Length);
      Release (Session_Handle);
      Ok := (for all I in Tx'Range => Rx (I) = Tx (I));
      Put ("[spi] test0 (32-byte loopback): ");
      Put_Line (if Ok then "PASS" else "FAIL");
   end;

   --  test1: the Session is controlled, so it auto-releases the host on scope
   --  exit, even via an exception.  A leaked lock would block the second Acquire
   --  forever, so reaching the verdict with Reacquired = True is the proof.
   declare
      Reacquired : Boolean := False;
   begin
      begin
         declare
            Session_Handle : Session;
         begin
            Acquire (Session_Handle, Host);
            raise Program_Error;          --  fault before any explicit Release
         end;                             --  Finalize (T) -> Release on unwind
      exception
         when others =>
            null;
      end;

      declare
         Session_Handle : Session;
      begin
         Acquire (Session_Handle, Host);  --  would deadlock if the lock leaked
         Reacquired := True;
         Release (Session_Handle);
      end;
      Put ("[spi] test1 (RAII auto-release): ");
      Put_Line (if Reacquired then "PASS" else "FAIL");
   end;

   Put_Line ("[spi] done.");

   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
