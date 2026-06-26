--  Ada RMT self-test on the bare-metal ESP32-S3 (no FreeRTOS, no IDF)
--  ==================================================================
--
--  What it demonstrates
--  --------------------
--  The reusable HAL RMT driver (ESP32S3.RMT).  A TX channel transmits a burst of
--  {level, duration} symbols on a GPIO pad; an RX channel reads that SAME pad
--  back and captures the burst; the received durations are compared to what was
--  sent.  This verifies both the TX and RX paths plus the tick divider.
--
--  Build & run
--  -----------
--     ./x run esp32s3_rmt_loopback
--  Built as the EMBEDDED profile (build.sh sets ESP32S3_RTS_PROFILE=embedded):
--  the channel handles use finalization, which light-tasking forbids.
--
--  Output
--  ------
--  A banner, then one result line; PASS means the four symbols round-tripped and
--  every compared duration matched.  Up to eight captured symbols are then dumped
--  as "[rmt]   got[I] = {level0:duration0, level1:duration1}".
--
--  Hardware / wiring
--  -----------------
--  None.  TX and RX share one pad (GPIO4); the GPIO matrix loops the pad's
--  output straight into the RX input, so no external jumper is needed.
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.RMT;   use ESP32S3.RMT;
with ESP32S3.GPIO;
with ESP32S3.Log;   use ESP32S3.Log;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   procedure Banner is
   begin
      Put_Line
        ("[rmt] bare-metal RMT TX->RX single-pad loopback self-test (no wiring)");
   end Banner;

   procedure Result (Sent, Received : Integer; Ok : Boolean) is
   begin
      Put ("[rmt] loopback: sent=");
      Put (Sent);
      Put (" received=");
      Put (Received);
      Put (" durations-match=");
      Put (if Ok then "y" else "n");
      Put ("  ");
      Put_Line (if Ok then "PASS" else "FAIL");
   end Result;

   procedure Dump (I : Integer; L0 : Boolean; D0 : Integer;
                   L1 : Boolean; D1 : Integer) is
   begin
      Put ("[rmt]   got[");
      Put (I);
      Put ("] = {");
      Put (Boolean'Pos (L0));
      Put (":");
      Put (D0);
      Put (", ");
      Put (Boolean'Pos (L1));
      Put (":");
      Put (D1);
      Put_Line ("}");
   end Dump;

   procedure Done is
   begin
      Put_Line ("[rmt] done.");
   end Done;

   --  The single GPIO pad TX drives and RX reads back through the matrix loop.
   Loopback_Pad : constant ESP32S3.GPIO.Pin_Id := 4;

   --  Channel tick rate.  1 MHz means one tick = 1 / 1_000_000 s = 1 us, so the
   --  symbol durations below read directly as microseconds.
   Resolution_Hz : constant := 1_000_000;

   --  Both channels use index 0 (TX channel 0 and RX channel 0 are independent).
   TX_Channel_Index : constant := 0;
   RX_Channel_Index : constant := 0;

   --  End reception after the line stays idle this many ticks (= 1_000 us here).
   --  Comfortably longer than the longest gap inside the burst, so it only fires
   --  once the whole burst has been sent.
   RX_Idle_Ticks : constant Tick_Count := 1_000;

   --  Four distinctive symbols: each is a high pulse then a low pulse, durations
   --  in ticks (= microseconds at Resolution_Hz).  Distinct, monotonically rising
   --  durations make a mismatch easy to spot in the dump.
   Sent : constant Symbol_Array :=
     ((Level0 => True, Duration0 =>  50, Level1 => False, Duration1 =>  60),
      (Level0 => True, Duration0 =>  80, Level1 => False, Duration1 =>  90),
      (Level0 => True, Duration0 => 120, Level1 => False, Duration1 => 130),
      (Level0 => True, Duration0 => 160, Level1 => False, Duration1 => 170));

   --  Capture buffer.  The RX symbol RAM is one 48-symbol block; 16 slots is far
   --  more than the four symbols we expect, leaving headroom for the dump.
   Got   : Symbol_Array (0 .. 15);
   Count : Natural;

   --  A received duration matches a sent one within +/- this many ticks (= us),
   --  absorbing the one-tick rounding the TX/RX dividers can introduce.
   Match_Tolerance_Ticks : constant := 4;
   function Near (A, B : Tick_Count) return Boolean is
     (abs (Integer (A) - Integer (B)) <= Match_Tolerance_Ticks);
begin
   delay until Clock + Milliseconds (200);
   Banner;

   declare
      Tx : TX_Channel;
      Rx : RX_Channel;
      Ok : Boolean := False;
   begin
      Claim (Tx, TX_Channel_Index);
      Claim (Rx, RX_Channel_Index);
      Configure (Tx, Resolution_Hz => Resolution_Hz, Pin => Loopback_Pad);
      Configure (Rx, Resolution_Hz => Resolution_Hz, Pin => Loopback_Pad,
                 Idle_Ticks => RX_Idle_Ticks);

      Start (Rx);                              --  arm the receiver first
      Transmit (Tx, Sent);                     --  drive the burst onto the pad
      Receive (Rx, Got, Count);                --  block until idle, read it back

      --  Every high pulse and every low pulse should round-trip, except the very
      --  last low -- the idle period that ends reception truncates it (standard
      --  RMT behaviour: the last symbol comes back with Duration1 = 0).
      Ok := Count = Sent'Length;
      if Ok then
         for I in Sent'Range loop
            Ok := Ok and then Near (Got (I).Duration0, Sent (I).Duration0);
            if I < Sent'Last then
               Ok := Ok and then Near (Got (I).Duration1, Sent (I).Duration1);
            end if;
         end loop;
      end if;

      Result (Sent'Length, Count, Ok);
      for I in 0 .. Natural'Min (Count, 8) - 1 loop
         Dump (I, Got (I).Level0, Integer (Got (I).Duration0),
               Got (I).Level1, Integer (Got (I).Duration1));
      end loop;
   end;                                        --  Tx, Rx finalize -> released

   Done;

   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
