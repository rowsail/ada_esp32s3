--  On-target malloc/free stress of the Ada TLSF allocator (ESP32-S3)
--  =================================================================
--  What it demonstrates:
--    On-target malloc/free stress of the Ada TLSF allocator (Tlsf_Core) behind
--    the live malloc/free symbols.  It calls malloc/free directly over the real
--    heap, writing a unique byte pattern into each block and re-checking it
--    before freeing, so any overlap, stale pointer or corruption is caught.
--
--  Build & run:
--    ./x run esp32s3_heaptest          -- DRAM heap (default)
--    HEAP_PSRAM=1 stresses the PSRAM arena at 0x3D000000 instead (build.sh sets
--    the linker --defsym for the arena; needs PSRAM on the board).  This is an
--    embedded-profile example (build.sh sets ESP32S3_RTS_PROFILE=embedded).
--
--  Output:
--    A banner, then one result line.  PASS means every re-checked allocation
--    still held its pattern (no overlap/corruption); FAIL means a block was
--    misaligned or a pattern was clobbered.
--
--  Hardware: none (self-contained); PSRAM only when HEAP_PSRAM=1.
with Interfaces;              use Interfaces;
with Interfaces.C;            use Interfaces.C;
with System;                  use System;
with System.Storage_Elements; use System.Storage_Elements;
with Ada.Real_Time;           use Ada.Real_Time;
with ESP32S3.Log;             use ESP32S3.Log;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   function Malloc (N : size_t) return Address;
   pragma Import (C, Malloc, "malloc");
   procedure C_Free (P : Address);
   pragma Import (C, C_Free, "free");

   procedure Fill (A : Address; Size : Storage_Count; Value : Storage_Element) is
      Arr : Storage_Array (1 .. Size)
      with Import, Address => A;
   begin
      Arr := (others => Value);
   end Fill;

   function Verify (A : Address; Size : Storage_Count; Value : Storage_Element) return Boolean is
      Arr : Storage_Array (1 .. Size)
      with Import, Address => A;
   begin
      return (for all B of Arr => B = Value);
   end Verify;

   --  Deterministic glibc-style linear congruential generator (LCG).  We use a
   --  fixed PRNG rather than the hardware RNG so the malloc/free sequence is
   --  reproducible: a failing run can be replayed and debugged bit-for-bit.
   --  Constants are glibc's rand() recurrence Seed := Seed*Mult + Inc; the high
   --  bits are the good ones, so the low 8 are dropped before taking the range.
   LCG_Mult      : constant Unsigned_32 := 1_103_515_245;  -- glibc multiplier
   LCG_Inc       : constant Unsigned_32 := 12_345;          -- glibc increment
   LCG_Drop_Bits : constant := 8;  -- discard low (least-random) bits
   Seed          : Unsigned_32 := 2_463_534_242;  -- fixed start -> reproducible

   --  Random_Below (Bound) returns a value in 0 .. Bound - 1.
   function Random_Below (Bound : Positive) return Natural is
   begin
      Seed := Seed * LCG_Mult + LCG_Inc;
      return Natural (Shift_Right (Seed, LCG_Drop_Bits) mod Unsigned_32 (Bound));
   end Random_Below;

   Max_Live   : constant := 32;   -- max simultaneously-live blocks
   Max_Bytes  : constant := 256;  -- max allocation size (bytes)
   Iterations : constant := 50_000;  -- malloc-or-free operations to run
   Min_Align  : constant := 16;   -- malloc must return 16-byte-aligned blocks

   type Slot is record
      Addr    : Address := Null_Address;
      Size    : Storage_Count := 0;
      Pattern : Storage_Element := 0;   -- byte written into the whole block
   end record;
   Live   : array (1 .. Max_Live) of Slot;
   Bad    : Natural := 0;   -- misalignments + corruptions detected
   Allocs : Natural := 0;   -- successful mallocs (for the report)
   Index  : Natural;        -- chosen slot for this iteration
begin
   --  Let the console settle before the banner so it isn't lost in boot noise.
   delay until Clock + Milliseconds (200);
   Put_Line ("[heap] on-target malloc/free stress (Ada Tlsf allocator)");

   for Step in 1 .. Iterations loop
      Index := Random_Below (Max_Live) + 1;
      if Live (Index).Addr = Null_Address then
         --  Slot is empty: allocate, stamp a pattern, and record it.
         declare
            Size : constant Storage_Count := Storage_Count (Random_Below (Max_Bytes) + 1);
            A    : constant Address := Malloc (size_t (Size));
         begin
            if A /= Null_Address then
               if To_Integer (A) mod Min_Align /= 0 then
                  Bad := Bad + 1;
               end if;
               Live (Index) := (A, Size, Storage_Element (Random_Below (Max_Bytes)));
               Fill (A, Size, Live (Index).Pattern);
               Allocs := Allocs + 1;
            end if;
         end;
      else
         --  Slot is live: re-check its pattern survived, then free it.
         if not Verify (Live (Index).Addr, Live (Index).Size, Live (Index).Pattern) then
            Bad := Bad + 1;
         end if;
         C_Free (Live (Index).Addr);
         Live (Index) := (Null_Address, 0, 0);
      end if;
   end loop;

   --  Drain: verify and free anything still live at the end of the run.
   for S of Live loop
      if S.Addr /= Null_Address then
         if not Verify (S.Addr, S.Size, S.Pattern) then
            Bad := Bad + 1;
         end if;
         C_Free (S.Addr);
      end if;
   end loop;

   Put ("[heap] allocs=");
   Put (Allocs);
   Put ("  corruption=");
   Put (Bad);
   Put_Line (if Bad = 0 then "  PASS" else "  *** FAIL ***");

   --  Result printed; idle forever so the report stays on the console.
   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
