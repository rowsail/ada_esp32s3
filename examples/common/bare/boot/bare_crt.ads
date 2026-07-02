with System;
with Interfaces.C;

--  The rest of the freestanding C-runtime glue (was bare_libc.c): the few libc
--  symbols GNAT's runtime references that newlib supplied under ESP-IDF, now in
--  Ada.  Linked only for the heap profiles (embedded/full), same as bare_mem.
--  Strong symbols (these have no GNAT-runtime provider here, unlike mem*).
--
--  Body MUST be compiled with -fno-tree-loop-distribute-patterns (bare_boot.gpr)
--  so GCC does not turn the strlen byte loop into a call to strlen.

package Bare_Crt is

   function Strlen (S : System.Address) return Interfaces.C.size_t;
   pragma Export (C, Strlen, "strlen");

   function Strcmp (A, B : System.Address) return Interfaces.C.int;
   pragma Export (C, Strcmp, "strcmp");

   function Atoi (S : System.Address) return Interfaces.C.int;
   pragma Export (C, Atoi, "atoi");

   --  No environment on bare metal -> always NULL.
   function Getenv (Name : System.Address) return System.Address;
   pragma Export (C, Getenv, "getenv");

   --  Route bytes to the ROM console (via the hal_log_cstr shim).  Used by any
   --  runtime path writing to fd 1/2.
   function Write
     (Fd : Interfaces.C.int; Buf : System.Address; N : Interfaces.C.unsigned)
      return Interfaces.C.int;
   pragma Export (C, Write, "write");

   --  Last-chance / failed-alloc path: reset the board.
   procedure Abort_Exec
   with No_Return;
   pragma Export (C, Abort_Exec, "abort");

   --  Register the DWARF unwind frames for ZCX exceptions (libgcc
   --  __register_frame on the linker-bracketed .eh_frame block).  Called from
   --  ada_env_body before adainit; overrides the weak no-op in bare_glue.c.
   procedure Register_Eh_Frames;
   pragma Export (C, Register_Eh_Frames, "bare_register_eh_frames");

end Bare_Crt;
