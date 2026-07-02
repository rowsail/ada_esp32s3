with System;
with System.Storage_Elements; use System.Storage_Elements;

--  Allocator-agnostic stress test: instantiate with any allocator that offers
--  the Bare_Heap_Core / Tlsf_Core interface, and it hammers it identically.

generic
   Name : String;
   with procedure Init (Base : System.Address; Size : Storage_Count);
   with function Allocate (N : Storage_Count) return System.Address;
   with procedure Deallocate (P : System.Address);
   with function Reallocate (P : System.Address; N : Storage_Count) return System.Address;
   with function Ready return Boolean;
   with function Invariants_Hold return Boolean;
procedure Heap_Stress (Fails : out Natural);
