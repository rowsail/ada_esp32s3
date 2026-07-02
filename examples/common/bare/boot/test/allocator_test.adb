--  Native host test: run the identical stress over BOTH allocators -- the
--  first-fit Bare_Heap_Core and the O(1) Tlsf_Core -- so a divergence is caught.
with Ada.Text_IO; use Ada.Text_IO;
with Heap_Stress;
with Bare_Heap_Core;
with Tlsf_Core;

procedure Allocator_Test is
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

   F1, F2 : Natural := 0;
begin
   First_Fit (F1);
   TLSF (F2);
   New_Line;
   if F1 = 0 and then F2 = 0 then
      Put_Line ("ALL PASS");
   else
      Put_Line ("*** TEST FAILED ***");
   end if;
end Allocator_Test;
