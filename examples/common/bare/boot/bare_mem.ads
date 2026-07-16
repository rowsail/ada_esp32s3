with System;
with Interfaces.C;

--  Freestanding memcpy/memmove/memset/memcmp in Ada -- replaces the C byte-loops
--  that were in bare_libc.c.  GCC lowers struct/array copies, aggregate init and
--  array comparisons into calls to these four, so they must exist even under
--  -ffreestanding; this provides them without any C.
--
--  Exported under the C names and marked WEAK, exactly like the C versions were:
--  GNAT's own System.Memory_* (s-memcop/...) provide STRONG memcpy etc. in the
--  light-tasking runtime and win when present; these serve the embedded/full
--  profiles whose runtime omits them.
--
--  NOTE: the body MUST be compiled with -fno-tree-loop-distribute-patterns (see
--  bare_boot.gpr) or GCC turns the byte loops back into calls to memcpy/memset
--  -- infinite self-recursion.

package Bare_Mem is

   --  Weak, so a profile whose runtime already defines these (light-tasking's
   --  System.Memory_* provide STRONG memcpy/memmove) wins and there is no
   --  multiple-definition clash; where the runtime omits them (embedded/full, or
   --  memset/memcmp under light-tasking) these are the definition.  pragma
   --  Weak_External marks the EXPORTED C symbol weak (pragma Machine_Attribute
   --  "weak" did not -- the emitted "memcpy" etc. stayed strong).
   function Memcpy (Dest, Src : System.Address; N : Interfaces.C.size_t) return System.Address;
   pragma Export (C, Memcpy, "memcpy");
   pragma Weak_External (Memcpy);

   function Memmove (Dest, Src : System.Address; N : Interfaces.C.size_t) return System.Address;
   pragma Export (C, Memmove, "memmove");
   pragma Weak_External (Memmove);

   function Memset
     (Dest : System.Address; C : Interfaces.C.int; N : Interfaces.C.size_t) return System.Address;
   pragma Export (C, Memset, "memset");
   pragma Weak_External (Memset);

   function Memcmp (S1, S2 : System.Address; N : Interfaces.C.size_t) return Interfaces.C.int;
   pragma Export (C, Memcmp, "memcmp");
   pragma Weak_External (Memcmp);

end Bare_Mem;
