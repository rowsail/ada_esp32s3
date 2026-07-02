--  Ada GDMA self-test on the bare-metal ESP32-S3 (no FreeRTOS, no IDF)
--  ====================================================================
--  Exercises the reusable HAL DMA driver (ESP32S3.GDMA):
--    test1  a memory-to-memory copy of a 64-byte buffer, compared byte for byte;
--    test2  the controlled (RAII) Channel handle -- claim all five channels,
--           confirm a sixth claim is rejected, then (after the handles leave
--           scope, so Finalize releases them) confirm a fresh claim succeeds.
--
--  test2 is the point of the controlled handle: a Channel is non-copyable (two
--  tasks can't alias one) and auto-releases on scope exit, so channels can't
--  leak or be reused through a stale copy.  Report goes through the ROM printf
--  glue (the reliable console path here).
--
--  Build & run:  ./x run esp32s3_gdma_copy
--    Drivers need finalization, so this runs on the embedded profile
--    (build.sh sets ESP32S3_RTS_PROFILE=embedded), not the default light-tasking.
--  Output:  a banner, one line per test, then "[gdma] done.".  PASS on both the
--    "mem2mem copy (64 B)" and the "raii:" lines means the run succeeded.
--  Hardware:  none (self-contained; mem-to-mem DMA, no external wiring).
with Interfaces;    use Interfaces;
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.GDMA; use ESP32S3.GDMA;
with ESP32S3.Log;  use ESP32S3.Log;

--  Pull the SMP slave-start entry into the link closure (glue.c calls it after
--  elaboration); core 1 just idles -- the test runs on core 0.
with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   procedure Banner is
   begin
      Put_Line ("[gdma] bare-metal GDMA mem-to-mem + RAII channel self-test");
   end Banner;

   procedure Copy_Result (Ok : Boolean) is
   begin
      Put ("[gdma] mem2mem copy (64 B): ");
      Put_Line (if Ok then "PASS" else "FAIL");
   end Copy_Result;

   procedure Raii_Result (Five, Sixth, Reclaimed, Ok : Boolean) is
   begin
      Put ("[gdma] raii: 5-claimed=");
      Put (if Five then "y" else "n");
      Put (" 6th-rejected=");
      Put (if Sixth then "y" else "n");
      Put (" reclaimed=");
      Put (if Reclaimed then "y" else "n");
      Put ("  ");
      Put_Line (if Ok then "PASS" else "FAIL");
   end Raii_Result;

   procedure Done is
   begin
      Put_Line ("[gdma] done.");
   end Done;

   type Buffer is array (0 .. 63) of Unsigned_8;
   Src : Buffer;
   Dst : Buffer := (others => 0);
begin
   delay until Clock + Milliseconds (200);
   Banner;

   for I in Buffer'Range loop
      Src (I) := Unsigned_8 ((I * 7 + 1) mod 256);
   end loop;

   --  test1: claim a channel, mem2mem copy, compare.
   declare
      Channel_Handle : Channel;
      Ok             : Boolean := False;
   begin
      Claim (Channel_Handle, Mem2Mem);
      if Is_Valid (Channel_Handle) then
         Copy (Channel_Handle, Dst'Address, Src'Address, Buffer'Length);
         Ok := (for all I in Buffer'Range => Dst (I) = Src (I));
      end if;
      Copy_Result (Ok);
   end;                                   --  C finalizes -> channel released

   --  test2: exhaust the pool, confirm a sixth claim fails, then prove the
   --  channels are reclaimed once the handles go out of scope (Finalize).
   declare
      Five, Sixth_Rejected, Reclaimed : Boolean := False;
   begin
      declare
         C1, C2, C3, C4, C5, Extra : Channel;
      begin
         Claim (C1, Mem2Mem);
         Claim (C2, Mem2Mem);
         Claim (C3, Mem2Mem);
         Claim (C4, Mem2Mem);
         Claim (C5, Mem2Mem);
         Five :=
           Is_Valid (C1)
           and then Is_Valid (C2)
           and then Is_Valid (C3)
           and then Is_Valid (C4)
           and then Is_Valid (C5);
         Claim (Extra, Mem2Mem);          --  no channel left
         Sixth_Rejected := not Is_Valid (Extra);
      end;                                --  Finalize C1..C5, Extra -> all freed

      declare
         Channel_Handle : Channel;
      begin
         Claim (Channel_Handle, Mem2Mem);   --  succeeds only if the five were freed
         Reclaimed := Is_Valid (Channel_Handle);
      end;

      Raii_Result (Five, Sixth_Rejected, Reclaimed, Five and Sixth_Rejected and Reclaimed);
   end;

   Done;

   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
