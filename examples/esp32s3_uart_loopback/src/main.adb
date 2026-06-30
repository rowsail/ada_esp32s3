--  Ada UART self-test on the bare-metal ESP32-S3 (no FreeRTOS, no IDF)
--  =====================================================================
--  Exercises the reusable HAL UART driver (ESP32S3.UART) with NO external
--  wiring: the controller's own internal TX->RX loopback (CONF0.LOOPBACK) feeds
--  every transmitted byte straight back to the receiver.  UART is push-pull and
--  unidirectional, so -- unlike I2C -- a fully on-chip loopback works and proves
--  the real data path: baud divider, frame format, TX FIFO, RX FIFO.
--
--    test 1  write a known buffer at 115200 8-N-1 -> read it back -> compare.
--    test 2  hardware RTS/CTS flow control: RTS is matrix-looped to CTS on one
--            pad, a low RX threshold is set, then more bytes than the threshold
--            are written without reading.  The RX FIFO should throttle (RTS
--            deasserts -> CTS deasserts -> the CTS-gated transmitter stalls)
--            well below the total, then drain back fully and intact once read.
--    test 3  per-line inversion: data loops TXD->RXD on one pad; inverting only
--            TX flips the polarity the (non-inverted) RX expects, so the link
--            breaks; inverting RX as well makes both ends agree again.
--
--  Build & run:  ./x run esp32s3_uart_loopback
--    The drivers need full exception propagation, so this runs on the embedded
--    profile (build.sh sets ESP32S3_RTS_PROFILE=embedded), not the default
--    light-tasking.
--  Output:  a banner, the sent/recv byte dumps, then one PASS/FAIL line per
--    test and "[uart] done.".  PASS on all three lines means the run succeeded.
--    The report goes through the ROM printf glue (the reliable console path
--    here).
--  Hardware:  none (self-contained).  UART1's internal TX->RX loopback carries
--    the data; the flow and inversion tests borrow free GPIOs (5 and 4) for an
--    on-chip matrix/pad loopback -- no external wiring or jumpers.
with Interfaces;    use Interfaces;
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.UART;
with ESP32S3.Log;   use ESP32S3.Log;

--  Pull the SMP slave-start entry into the link closure (glue.c calls it after
--  elaboration); core 1 just idles -- the test runs on core 0.
with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   use ESP32S3.UART;

   --  The HAL UART controller under test.
   Port : constant UART_Port := UART1;

   --  Line speed for every test; 8-N-1 frame format is the Acquire default.
   Baud_Rate : constant := 115_200;

   --  A free GPIO that RTS drives and CTS reads back (matrix loopback of the
   --  flow lines; data stays on the controller's internal TX->RX loopback).
   Flow_Control_Pad : constant := 5;

   --  RTS deasserts once the RX FIFO holds this many unread bytes.  Kept low
   --  (and well under the 128-byte FIFO) so the throttle is easy to observe.
   Rx_Flow_Threshold : constant := 8;

   --  A free pad for the inversion test's TXD<->RXD single-pad loopback (CONF0
   --  line-invert applies at the I/O boundary, so this routes through a pad
   --  rather than the controller's internal loopback).
   Inversion_Pad : constant := 4;

   --  Inversion-test pattern: a spread of bit patterns (all-0, all-1, the
   --  alternating 0xA5/0x5A, nibble splits) so a polarity flip is unmissable.
   Inversion_Tx : constant Byte_Array :=
     (16#00#, 16#FF#, 16#A5#, 16#5A#, 16#0F#, 16#F0#, 16#12#, 16#ED#);

   --  Loopback-test pattern: 16 mixed bytes (sync/marker values plus a counting
   --  ramp) so a stuck or shifted bit shows up in the byte-for-byte compare.
   Tx : constant Byte_Array :=
     (16#55#, 16#AA#, 16#00#, 16#FF#, 16#12#, 16#34#, 16#56#, 16#78#,
      16#9A#, 16#BC#, 16#DE#, 16#F0#, 16#0F#, 16#A5#, 16#5A#, 16#C3#);

   --  Start a labelled byte line then dump Count bytes as " %02x".
   --  Recv selects the label: True = "recv", False = "sent".
   procedure Dump (Recv : Boolean; Data : Byte_Array; Count : Natural) is
   begin
      Put ("[uart] ");
      Put (if Recv then "recv" else "sent");
      Put (":");
      for I in Data'First .. Data'First + Count - 1 loop
         Put (" ");
         Put_Hex (Unsigned_32 (Data (I)) and 16#FF#, 2);
      end loop;
      New_Line;
   end Dump;

   --  Flow-control test payload: 64 bytes (>> Rx_Flow_Threshold, < 128-byte
   --  FIFO) so the FIFO fills past the threshold but never overruns.
   Flow_Tx : Byte_Array (0 .. 63);

   --  The held-port handle; everything below runs through it.
   S : Session;

   --  Receive buffers, one per test, each sized to its sent payload.
   Rx           : Byte_Array (Tx'Range);
   Flow_Rx      : Byte_Array (Flow_Tx'Range);
   Inversion_Rx : Byte_Array (Inversion_Tx'Range);

   --  Byte counts the driver actually read back.
   Loopback_Got  : Natural;
   Flow_Got      : Natural;
   Inversion_Got : Natural;   --  TX-only-inverted read (expected short/garbled)
   Both_Got      : Natural;   --  TX+RX-inverted read (expected full + clean)

   --  RX bytes available while TX is throttled; should sit near the threshold.
   Capped : Natural;

   --  Per-test verdicts.
   Equal             : Boolean;   --  reused: loopback compare, then flow compare
   Tx_Only_Broke     : Boolean;   --  TX-only inversion broke the link (as wanted)
   Tx_Rx_Match       : Boolean;   --  TX+RX inversion round-tripped intact
begin
   delay until Clock + Milliseconds (200);   --  let the console settle
   Put_Line ("[uart] bare-metal UART self-test "
             & "(internal TX->RX loopback, no wiring)");

   Acquire (S, Port, Baud => Baud_Rate);     --  claim + 8-N-1, no pins routed
   Enable_Loopback (S);                      --  internal TX->RX (held port)
   Write (S, Tx);
   Read (S, Rx, Loopback_Got);
   Release (S);

   Equal := Loopback_Got = Tx'Length;
   if Equal then
      for I in Tx'Range loop
         if Rx (I) /= Tx (I) then
            Equal := False;
         end if;
      end loop;
   end if;

   Dump (False, Tx, Tx'Length);              --  sent
   Dump (True, Rx, Loopback_Got);            --  recv
   Put ("[uart] loopback: ");
   Put_Line (if Equal then "PASS" else "FAIL");

   ----------------------------------------------------------------------------
   --  Test 2: RTS/CTS hardware flow control.  RTS is matrix-looped to CTS on
   --  Flow_Control_Pad; data still uses the internal TX->RX loopback.  Writing
   --  64 bytes without reading fills the RX FIFO to ~Rx_Flow_Threshold, at which
   --  point RTS deasserts -> CTS deasserts -> the CTS-gated transmitter stalls,
   --  capping RX far below 64.  Draining then re-asserts RTS/CTS and the rest
   --  flows in.
   ----------------------------------------------------------------------------
   for I in Flow_Tx'Range loop
      Flow_Tx (I) := Byte (I);
   end loop;

   Acquire (S, Port);
   Configure_Pins (S,
                   Rts => Flow_Control_Pad, Cts => Flow_Control_Pad,
                   Rx_Flow_Threshold => Rx_Flow_Threshold);
   Write (S, Flow_Tx);                       --  64 bytes queued to the TX FIFO
   delay until Clock + Milliseconds (20);    --  let TX run until throttled
   Capped := Available (S);                  --  RX should be stuck near threshold
   Read (S, Flow_Rx, Flow_Got);              --  drain -> RTS re-asserts -> rest flows
   Release (S);

   Equal := Flow_Got = Flow_Tx'Length and then Capped < Flow_Tx'Length;
   if Equal then
      for I in Flow_Tx'Range loop
         if Flow_Rx (I) /= Flow_Tx (I) then
            Equal := False;
         end if;
      end loop;
   end if;
   Put ("[uart] flow: RX throttled to ");
   Put (Capped);
   Put (" of ");
   Put (Flow_Tx'Length);
   Put (" bytes, all drained: ");
   Put_Line (if Equal then "PASS" else "FAIL");

   ----------------------------------------------------------------------------
   --  Test 3: per-line inversion, changed AFTER configure via Set_Inversion.
   --  Data loops TXD->RXD on one pad (CONF0 line-invert applies at the I/O
   --  boundary).  Inverting only TX flips the idle/start-bit polarity the
   --  (non-inverted) RX expects, so the link BREAKS (garbled / short read);
   --  inverting RX as well makes both ends agree again and the bytes match.
   --  That asymmetry proves the inversion takes effect and is per-line.
   ----------------------------------------------------------------------------
   --  TX inverted only -> polarity mismatch -> link should NOT round-trip cleanly.
   Acquire (S, Port);
   Enable_Loopback (S, False);                          --  off; use a real pad
   Configure_Pins (S, Tx => Inversion_Pad,
                      Rx => Inversion_Pad);             --  single-pad loopback
   Set_Inversion (S, Tx => True);
   Write (S, Inversion_Tx);
   Read  (S, Inversion_Rx, Inversion_Got);
   Release (S);
   Tx_Only_Broke := Inversion_Got /= Inversion_Tx'Length;
   for I in Inversion_Tx'First .. Inversion_Tx'First + Inversion_Got - 1 loop
      if Inversion_Rx (I) /= Inversion_Tx (I) then
         Tx_Only_Broke := True;       --  any deviation = link broke (as expected)
      end if;
   end loop;

   --  TX and RX both inverted -> ends agree again -> clean round-trip.  Acquire
   --  re-routes the single-pad loopback (it resets pins, so we pass them again);
   --  loopback stays off and the TX inversion from above persists until reset.
   Acquire (S, Port, Tx => Inversion_Pad, Rx => Inversion_Pad);
   Set_Inversion (S, Tx => True, Rx => True);
   Write (S, Inversion_Tx);
   Read  (S, Inversion_Rx, Both_Got);
   Release (S);
   Tx_Rx_Match := Both_Got = Inversion_Tx'Length;
   for I in Inversion_Tx'Range loop
      if Inversion_Rx (I) /= Inversion_Tx (I) then
         Tx_Rx_Match := False;
      end if;
   end loop;

   Put ("[uart] invert: TX-only->link-breaks:");
   Put (if Tx_Only_Broke then "y" else "n");
   Put ("  TX+RX->match:");
   Put (if Tx_Rx_Match then "y" else "n");
   Put ("  ");
   Put_Line (if Tx_Only_Broke and Tx_Rx_Match then "PASS" else "FAIL");

   Put_Line ("[uart] done.");

   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
