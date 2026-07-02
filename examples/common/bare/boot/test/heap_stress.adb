with Ada.Text_IO; use Ada.Text_IO;
with Interfaces;  use Interfaces;
with System;      use System;

procedure Heap_Stress (Fails : out Natural) is

   Arena_Bytes : constant := 64 * 1024;
   Arena       : Storage_Array (1 .. Arena_Bytes)
   with Alignment => 16;

   Bad    : Natural := 0;
   Checks : Natural := 0;

   procedure Check (Cond : Boolean; Msg : String) is
   begin
      Checks := Checks + 1;
      if not Cond then
         Put_Line (Name & ": FAIL: " & Msg);
         Bad := Bad + 1;
      end if;
   end Check;

   procedure Fill (A : Address; Sz : Storage_Count; V : Storage_Element) is
      Arr : Storage_Array (1 .. Sz)
      with Import, Address => A;
   begin
      Arr := (others => V);
   end Fill;

   function Verify (A : Address; Sz : Storage_Count; V : Storage_Element) return Boolean is
      Arr : Storage_Array (1 .. Sz)
      with Import, Address => A;
   begin
      return (for all B of Arr => B = V);
   end Verify;

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

   declare
      P : constant Address := Allocate (100);
   begin
      Check (P /= Null_Address, "alloc 100");
      Check (To_Integer (P) mod 16 = 0, "16-aligned");
      Check (Invariants_Hold, "invariants after alloc");
      Deallocate (P);
      Check (Invariants_Hold, "invariants after free");
   end;

   Check (Allocate (0) = Null_Address, "alloc 0 -> null");
   Check (Allocate (Arena_Bytes * 2) = Null_Address, "oversized -> null");
   Check (Invariants_Hold, "invariants after OOM");

   declare
      P : constant Address := Allocate (40);
      Q : Address;
   begin
      Fill (P, 40, 16#5A#);
      Q := Reallocate (P, 4000);
      Check (Q /= Null_Address, "realloc grow");
      Check (Verify (Q, 40, 16#5A#), "realloc preserves data");
      Check (Invariants_Hold, "invariants after realloc");
      Deallocate (Q);
   end;

   --  Randomised stress with per-allocation pattern tracking.
   declare
      Max_Live : constant := 64;
      type Slot is record
         A   : Address := Null_Address;
         Sz  : Storage_Count := 0;
         Pat : Storage_Element := 0;
      end record;
      Live     : array (1 .. Max_Live) of Slot;
      Idx, Sz  : Natural;
   begin
      for Step in 1 .. 300_000 loop
         Idx := Rnd (Max_Live) + 1;
         if Live (Idx).A = Null_Address then
            Sz := Rnd (512) + 1;
            declare
               A : constant Address := Allocate (Storage_Count (Sz));
            begin
               if A /= Null_Address then
                  Check (To_Integer (A) mod 16 = 0, "stress aligned");
                  Live (Idx) := (A, Storage_Count (Sz), Storage_Element (Rnd (256)));
                  Fill (A, Live (Idx).Sz, Live (Idx).Pat);
               end if;
            end;
         else
            Check (Verify (Live (Idx).A, Live (Idx).Sz, Live (Idx).Pat), "stress pattern intact");
            Deallocate (Live (Idx).A);
            Live (Idx) := (Null_Address, 0, 0);
         end if;
         Check (Invariants_Hold, "stress invariants");
         exit when Bad > 0;
      end loop;

      for S of Live loop
         if S.A /= Null_Address then
            Check (Verify (S.A, S.Sz, S.Pat), "drain pattern intact");
            Deallocate (S.A);
         end if;
      end loop;
   end;

   Check (Invariants_Hold, "invariants after drain");
   declare
      --  After a full drain the arena must coalesce back to one big block; a
      --  fragmented heap could not satisfy this.  The 4 KiB margin covers
      --  header/sentinel overhead and TLSF's good-fit rounding (which can't
      --  hand out the last few % of a single block).
      Big : constant Address := Allocate (Arena_Bytes - 4096);
   begin
      Check (Big /= Null_Address, "large alloc after drain (coalesced)");
      Deallocate (Big);
   end;

   Put_Line
     (Name
      & ": checks:"
      & Checks'Image
      & "  failures:"
      & Bad'Image
      & (if Bad = 0 then "  PASS" else "  *** FAIL ***"));
   Fails := Bad;
end Heap_Stress;
