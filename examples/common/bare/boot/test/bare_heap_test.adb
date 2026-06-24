--  Native host test for Bare_Heap_Core (the Ada port of bare_libc.c's malloc/
--  free/realloc).  No hardware: runs the SAME allocator source the firmware
--  links, over a static arena, and hammers it -- random alloc/free/realloc with
--  a per-allocation pattern (an overlap or stale pointer corrupts a pattern and
--  is caught), checking the free-list invariants after every operation.
with Ada.Text_IO;             use Ada.Text_IO;
with Interfaces;              use Interfaces;
with System;                  use System;
with System.Storage_Elements; use System.Storage_Elements;
with Bare_Heap_Core;          use Bare_Heap_Core;

procedure Bare_Heap_Test is

   Arena_Bytes : constant := 64 * 1024;
   Arena : Storage_Array (1 .. Arena_Bytes) with Alignment => 16;

   Fails : Natural := 0;
   Checks : Natural := 0;

   procedure Check (Cond : Boolean; Msg : String) is
   begin
      Checks := Checks + 1;
      if not Cond then
         Put_Line ("FAIL: " & Msg);
         Fails := Fails + 1;
      end if;
   end Check;

   --  Byte fill / verify over a payload (overlay).
   procedure Fill (A : Address; Sz : Storage_Count; V : Storage_Element) is
      Arr : Storage_Array (1 .. Sz) with Import, Address => A;
   begin
      Arr := (others => V);
   end Fill;

   function Verify (A : Address; Sz : Storage_Count; V : Storage_Element)
                    return Boolean is
      Arr : Storage_Array (1 .. Sz) with Import, Address => A;
   begin
      return (for all B of Arr => B = V);
   end Verify;

   --  Deterministic LCG (no Ada.Numerics dependency; reproducible failures).
   Seed : Unsigned_32 := 2_463_534_242;
   function Rnd (Modulo : Positive) return Natural is
   begin
      Seed := Seed * 1_103_515_245 + 12_345;
      return Natural (Shift_Right (Seed, 8) mod Unsigned_32 (Modulo));
   end Rnd;

begin
   Init (Arena'Address, Arena_Bytes);
   Check (Ready, "ready after init");
   Check (Invariants_Hold, "invariants after init");

   --  Basic alloc / alignment / free.
   declare
      P : constant Address := Allocate (100);
   begin
      Check (P /= Null_Address, "alloc 100 succeeds");
      Check (To_Integer (P) mod 16 = 0, "payload 16-aligned");
      Check (Invariants_Hold, "invariants after one alloc");
      Deallocate (P);
      Check (Invariants_Hold, "invariants after free");
   end;

   --  Zero-size and OOM.
   Check (Allocate (0) = Null_Address, "alloc 0 -> null");
   Check (Allocate (Arena_Bytes * 2) = Null_Address, "oversized -> null (OOM)");
   Check (Invariants_Hold, "invariants after OOM");

   --  realloc grows and preserves the payload.
   declare
      P : Address := Allocate (40);
      Q : Address;
   begin
      Fill (P, 40, 16#5A#);
      Q := Reallocate (P, 4000);
      Check (Q /= Null_Address, "realloc grow succeeds");
      Check (Verify (Q, 40, 16#5A#), "realloc preserves data");
      Check (Invariants_Hold, "invariants after realloc");
      Deallocate (Q);
   end;

   --  Randomized stress with pattern tracking.
   declare
      Max_Live : constant := 64;
      type Slot is record
         A   : Address := Null_Address;
         Sz  : Storage_Count := 0;
         Pat : Storage_Element := 0;
      end record;
      Live : array (1 .. Max_Live) of Slot;
      Idx, Sz : Natural;
   begin
      for Step in 1 .. 300_000 loop
         Idx := Rnd (Max_Live) + 1;
         if Live (Idx).A = Null_Address then
            --  allocate into a free slot
            Sz := Rnd (512) + 1;
            declare
               A : constant Address := Allocate (Storage_Count (Sz));
            begin
               if A /= Null_Address then
                  Check (To_Integer (A) mod 16 = 0, "stress: aligned");
                  Live (Idx) := (A, Storage_Count (Sz),
                                 Storage_Element (Rnd (256)));
                  Fill (A, Live (Idx).Sz, Live (Idx).Pat);
               end if;
            end;
         else
            --  verify pattern intact, then free
            Check (Verify (Live (Idx).A, Live (Idx).Sz, Live (Idx).Pat),
                   "stress: pattern intact before free");
            Deallocate (Live (Idx).A);
            Live (Idx) := (Null_Address, 0, 0);
         end if;
         Check (Invariants_Hold, "stress: invariants");
         exit when Fails > 0;     --  stop at first failure (Seed reproduces it)
      end loop;

      --  Free everything left, verifying patterns first.
      for S of Live loop
         if S.A /= Null_Address then
            Check (Verify (S.A, S.Sz, S.Pat), "drain: pattern intact");
            Deallocate (S.A);
         end if;
      end loop;
   end;

   --  After draining, the whole arena must be one free block again.
   Check (Invariants_Hold, "invariants after drain");
   declare
      Big : constant Address := Allocate (Arena_Bytes - 256);
   begin
      Check (Big /= Null_Address, "whole arena reclaimed (coalesced)");
      Deallocate (Big);
   end;

   New_Line;
   Put_Line ("checks:" & Checks'Image & "  failures:" & Fails'Image);
   if Fails = 0 then
      Put_Line ("ALL PASS");
   else
      Put_Line ("*** TEST FAILED ***");
   end if;
end Bare_Heap_Test;
