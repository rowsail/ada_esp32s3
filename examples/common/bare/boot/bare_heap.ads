with System;
with Interfaces.C;

--  Target malloc/free/realloc/calloc, in Ada, over the O(1) Tlsf_Core allocator
--  (replaces bare_heap.c).  Adds the target-only glue the core deliberately
--  omits: a global rsil-15 critical section (serialises the env task + the
--  finalizers), the arena bounds from the linker (--defsym __bare_heap_base /
--  __bare_heap_end -> the leftover-DRAM or PSRAM region, chosen in bare_build.sh
--  so this unit is arena-agnostic), and the per-task primary-stack reclamation
--  hook for the full profile.  Linked only for the heap profiles.

package Bare_Heap is

   function Malloc (N : Interfaces.C.size_t) return System.Address;
   pragma Export (C, Malloc, "malloc");

   procedure Free (P : System.Address);
   pragma Export (C, Free, "free");

   function Realloc (P : System.Address; N : Interfaces.C.size_t) return System.Address;
   pragma Export (C, Realloc, "realloc");

   function Calloc (Nmemb, Size : Interfaces.C.size_t) return System.Address;
   pragma Export (C, Calloc, "calloc");

   --  Live free-payload byte count of the arena (Tlsf_Core.Free_Bytes), read
   --  under the allocator lock.  Exported so the Wi-Fi OS adapter's
   --  get_free_heap_size can report a real figure without the wifi library
   --  depending on this boot-side unit (it links against the symbol, as with
   --  malloc).
   function Heap_Free_Bytes return Interfaces.C.size_t;
   pragma Export (C, Heap_Free_Bytes, "__bare_heap_free_bytes");

   --  Free a terminated task's heap-allocated primary stack -- but only once the
   --  thread is no longer the running thread on either core (else a cross-core
   --  free could pull the stack from under a task still on it).  Bounded spin:
   --  leak-on-timeout rather than risk a use-after-free.
   procedure Task_Stack_Free (Stack, Thread : System.Address);
   pragma Export (C, Task_Stack_Free, "__gnat_task_stack_free");

end Bare_Heap;
