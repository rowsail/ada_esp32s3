with System;
with System.Storage_Elements;  use System.Storage_Elements;

--  First-fit free-list allocator core -- the algorithm that was in bare_heap.c,
--  now in Ada and free of target dependencies (no lock, no linker symbols), so
--  the SAME code runs under the native host test (boot/test/) and on target
--  behind Bare_Heap's malloc/free.  The caller provides mutual exclusion.
--
--  Blocks are kept in ascending address order (split forward, never reordered);
--  free does a single forward coalescing sweep, so adjacent free blocks never
--  persist.  Payloads and the header are 16-byte aligned.
package Bare_Heap_Core is

   --  One-time init: hand the allocator the arena [Base, Base+Size).
   procedure Init (Base : System.Address; Size : Storage_Count);

   --  first-fit malloc; returns a 16-aligned payload, or Null_Address on OOM
   --  (or N = 0, or before Init).
   function Allocate (N : Storage_Count) return System.Address;

   --  free + forward-coalesce.  No-op on Null_Address.
   procedure Deallocate (P : System.Address);

   --  realloc: keep the block if the request still fits, else allocate, copy
   --  the old payload, and free.  N = 0 frees and returns Null_Address.
   function Reallocate (P : System.Address; N : Storage_Count)
                        return System.Address;

   --  True once Init has run.
   function Ready return Boolean;

   --  Test-only: walk the list and check it is well-formed -- blocks strictly
   --  ascending and contiguous from the arena base to its top, all within the
   --  arena, and no two adjacent free blocks (coalescing complete).
   function Invariants_Hold return Boolean;

end Bare_Heap_Core;
