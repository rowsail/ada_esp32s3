with System;
with System.Storage_Elements; use System.Storage_Elements;

--  Two-Level Segregated Fit (TLSF) allocator -- O(1) malloc AND free, bounded
--  fragmentation, so it scales to a large/slow (e.g. PSRAM) heap where the
--  first-fit list (linear scan + full-list coalesce on every free) degrades to
--  O(n) per op.  Free blocks are bucketed by a two-level size class (power-of-
--  two first level x linear second level); per-level bitmaps + find-first-set
--  locate a fitting bucket in O(1); coalescing uses boundary tags (each block
--  knows its physical previous block and its size), so free touches only the
--  block and its two physical neighbours.
--
--  Same interface as Bare_Heap_Core, so the same host harness (boot/test/) runs
--  it.  Target-dependency-free (no lock, no linker symbols); caller serialises.

package Tlsf_Core is

   procedure Init (Base : System.Address; Size : Storage_Count);
   function Allocate (N : Storage_Count) return System.Address;
   procedure Deallocate (P : System.Address);
   function Reallocate (P : System.Address; N : Storage_Count) return System.Address;
   function Ready return Boolean;

   --  Test-only: physical-chain consistency (prev-phys links, ascending,
   --  contiguous, no two adjacent free, ends at the sentinel).
   function Invariants_Hold return Boolean;

end Tlsf_Core;
