--  What it demonstrates
--    An Ada I2C MASTER hardware self-test on the bare-metal ESP32-S3 (no
--    FreeRTOS, no IDF) -- exercises the reusable HAL master driver
--    (ESP32S3.I2C) with NO external wiring and no device on the bus.
--
--    What this self-test proves on silicon, using only the master + its own
--    pads:
--      test0  write to an ABSENT address (ACK-checked): the master issues a
--             real START, clocks the 7-bit address, samples the (absent) ACK,
--             sees NACK and ends with a STOP -> Success = False.  PASS = NACK
--             detected.
--      test1  multi-byte write to that address with ACK-checking OFF: the
--             master clocks the address + 5 data bytes + STOP to completion
--             regardless of ACK -> Success = True.  PASS = the full
--             transaction completes.
--      test2  acquire the host, raise an exception in scope, then re-acquire:
--             the controlled Session auto-releases on unwind, so the
--             re-acquire succeeds.  PASS = re-acquire did not deadlock.
--
--    Together these exercise START/STOP, 7-bit addressing, the command-
--    sequence FSM, multi-byte FIFO transmit, the bus timing, and ACK/NACK
--    detection.
--
--  Build & run
--    ./x run esp32s3_i2c_loopback
--    Needs the embedded profile (full exception propagation, used by test2);
--    build.sh sets ESP32S3_RTS_PROFILE=embedded.
--
--  Output  (report goes through the ROM printf glue, the reliable console
--  path here)
--    [i2c] bare-metal I2C master hardware self-test (no wiring, no device)
--    [i2c] test0: PASS
--    [i2c] test1: PASS
--    [i2c] test2: PASS
--    [i2c] done.
--
--  Hardware
--    None (self-contained): the master's SDA and SCL each loop their own
--    output back to their own input on two free pads; no external device.
--
--    Why no internal master<->slave loopback?  I2C SDA is a bidirectional
--    open-drain (wired-AND) node: both ends must DRIVE and READ the same wire.
--    The ESP32-S3 GPIO matrix gives each pad exactly one output source, so it
--    cannot wire-AND two on-chip controllers onto one pad -- there is no way to
--    internally connect two I2C controllers into a working bus.  (Cross-coupling
--    two pads breaks the master's mandatory write-readback; a single shared pad
--    breaks the slave's mandatory ACK.)  Verifying the READ direction and ACK
--    handshake therefore needs a real shared bus: an external device, or a
--    jumper tying two pads together.  See the README.
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.I2C;
with ESP32S3.Log; use ESP32S3.Log;

--  Pull the SMP slave-start entry into the link closure (glue.c calls it after
--  elaboration); core 1 just idles -- the test runs on core 0.
with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   use ESP32S3.I2C;

   procedure Verdict (Test : Integer; Ok : Boolean) is
   begin
      Put ("[i2c] test");
      Put (Test);
      Put (": ");
      Put_Line (if Ok then "PASS" else "FAIL");
   end Verdict;

   Host : constant I2C_Host := I2C0;

   --  Two free general-purpose pads (avoid 26..32 = flash / PSRAM); the master's
   --  SDA and SCL each loop their own output back to their own input.
   Sda_Pad : constant := 4;
   Scl_Pad : constant := 6;

   --  No device lives at this address on the (empty) bus.
   Absent : constant Slave_Address := 16#55#;

   Payload : constant Byte_Array := (16#A5#, 16#3C#, 16#01#, 16#FE#, 16#7D#);

   Session_Handle : Session;
   Ok             : Boolean;
begin
   delay until Clock + Milliseconds (200);   --  let the console settle
   Put_Line ("[i2c] bare-metal I2C master hardware self-test " & "(no wiring, no device)");

   Setup (Host, Clock_Hz => 100_000);
   Configure_Pins (Host, Scl => Scl_Pad, Sda => Sda_Pad);

   --  test0: ACK-checked write to an absent address -> expect NACK.
   Acquire (Session_Handle, Host);
   Write (Session_Handle, Absent, (1 => 16#00#), Ok);
   Release (Session_Handle);
   Verdict (0, not Ok);                       --  PASS = NACK correctly detected

   --  test1: multi-byte write, ACK-checking off -> expect completion.
   Acquire (Session_Handle, Host);
   Write (Session_Handle, Absent, Payload, Ok, Check_Ack => False);
   Release (Session_Handle);
   Verdict (1, Ok);                           --  PASS = full transaction completed

   --  test2: the Session is a controlled type, so it auto-releases the host when
   --  it leaves scope -- even via an exception.  Acquire then raise inside a
   --  block; if Finalize released the host, the next Acquire succeeds.  (A leaked
   --  lock would block the second Acquire forever, so reaching the verdict at all
   --  -- with Reacquired True -- is the proof.)
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
      Verdict (2, Reacquired);
   end;

   Put_Line ("[i2c] done.");

   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
