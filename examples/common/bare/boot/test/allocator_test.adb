--  Native host test: run the identical stress over BOTH allocators -- the
--  first-fit Bare_Heap_Core and the O(1) Tlsf_Core -- so a divergence is caught.
with Ada.Text_IO; use Ada.Text_IO;
with System;
with System.Storage_Elements; use System.Storage_Elements;
with Heap_Stress;
with Bare_Heap_Core;
with Tlsf_Core;

procedure Allocator_Test is

   --  Free_Bytes accounting is Tlsf_Core-specific (Bare_Heap_Core has no such
   --  counter), so it is checked here rather than in the shared Heap_Stress.
   --  The strong property: after Init the free total is F0, and any alloc/free
   --  sequence that ends fully drained must restore it EXACTLY -- so the +=/-=
   --  in Insert_Free/Remove_Free never leak or double-count across split and
   --  coalesce.  Also: a live allocation must drop the total by at least the
   --  payload requested, and the total may never exceed the arena.
   function Tlsf_Free_Bytes_Ok return Boolean is
      Arena : Storage_Array (1 .. 64 * 1024) with Alignment => 16;
      Base, Busy : Storage_Count;
      P    : array (1 .. 8) of System.Address;
   begin
      Tlsf_Core.Init (Arena'Address, Arena'Length);
      Base := Tlsf_Core.Free_Bytes;
      if Base > Arena'Length then
         return False;                       --  cannot exceed the arena
      end if;
      for I in P'Range loop
         P (I) := Tlsf_Core.Allocate (200);
      end loop;
      Busy := Tlsf_Core.Free_Bytes;
      if Busy >= Base or else Base - Busy < 8 * 200 then
         return False;                       --  8 live allocs must drop >= 8*200
      end if;
      for I in P'Range loop
         Tlsf_Core.Deallocate (P (I));
      end loop;
      return Tlsf_Core.Free_Bytes = Base;    --  exact restore after full drain
   end Tlsf_Free_Bytes_Ok;
   procedure First_Fit is new
     Heap_Stress
       ("first-fit",
        Bare_Heap_Core.Init,
        Bare_Heap_Core.Allocate,
        Bare_Heap_Core.Deallocate,
        Bare_Heap_Core.Reallocate,
        Bare_Heap_Core.Ready,
        Bare_Heap_Core.Invariants_Hold);

   procedure TLSF is new
     Heap_Stress
       ("tlsf",
        Tlsf_Core.Init,
        Tlsf_Core.Allocate,
        Tlsf_Core.Deallocate,
        Tlsf_Core.Reallocate,
        Tlsf_Core.Ready,
        Tlsf_Core.Invariants_Hold);

   F1, F2  : Natural := 0;
   Free_Ok : Boolean;
begin
   First_Fit (F1);
   TLSF (F2);
   Free_Ok := Tlsf_Free_Bytes_Ok;
   Put_Line
     ("tlsf-free-bytes: " & (if Free_Ok then "PASS" else "*** FAIL ***"));
   New_Line;
   if F1 = 0 and then F2 = 0 and then Free_Ok then
      Put_Line ("ALL PASS");
   else
      Put_Line ("*** TEST FAILED ***");
   end if;
end Allocator_Test;
