with System;                  use System;
with System.Storage_Elements; use System.Storage_Elements;
with System.Machine_Code;     use System.Machine_Code;
with Interfaces;              use Interfaces;
with Tlsf_Core;

package body Bare_Heap is

   package T renames Tlsf_Core;

   --  Arena bounds from the linker (--defsym in bare_build.sh): the object's
   --  ADDRESS is the value, i.e. the DRAM or PSRAM heap base/end.
   Heap_Base : Storage_Element
   with Import, Convention => C, External_Name => "__bare_heap_base";
   Heap_End  : Storage_Element
   with Import, Convention => C, External_Name => "__bare_heap_end";

   ---------------------------------------------------------------------------
   --  Global rsil-15 critical section (matches the C: env task + finalizers).
   ---------------------------------------------------------------------------
   function Enter_Crit return Unsigned_32 is
      Ps : Unsigned_32;
   begin
      Asm
        ("rsil %0, 15",
         Outputs  => Unsigned_32'Asm_Output ("=r", Ps),
         Volatile => True,
         Clobber  => "memory");
      return Ps;
   end Enter_Crit;

   procedure Leave_Crit (Ps : Unsigned_32) is
   begin
      Asm
        ("wsr.ps %0" & ASCII.LF & "rsync",
         Inputs   => Unsigned_32'Asm_Input ("r", Ps),
         Volatile => True,
         Clobber  => "memory");
   end Leave_Crit;

   Started : Boolean := False;   --  zero init -> .bss (boot-zeroed)

   procedure Ensure_Init is
   begin
      if not Started then
         T.Init
           (Heap_Base'Address,
            Storage_Count (To_Integer (Heap_End'Address) - To_Integer (Heap_Base'Address)));
         Started := True;
      end if;
   end Ensure_Init;

   ------------
   -- Malloc --
   ------------

   function Malloc (N : Interfaces.C.size_t) return System.Address is
      Ps : constant Unsigned_32 := Enter_Crit;
      R  : System.Address;
   begin
      Ensure_Init;
      R := T.Allocate (Storage_Count (N));
      Leave_Crit (Ps);
      return R;
   end Malloc;

   ----------
   -- Free --
   ----------

   procedure Free (P : System.Address) is
      Ps : constant Unsigned_32 := Enter_Crit;
   begin
      T.Deallocate (P);
      Leave_Crit (Ps);
   end Free;

   -------------
   -- Realloc --
   -------------

   function Realloc (P : System.Address; N : Interfaces.C.size_t) return System.Address is
      Ps : constant Unsigned_32 := Enter_Crit;
      R  : System.Address;
   begin
      Ensure_Init;
      R := T.Reallocate (P, Storage_Count (N));
      Leave_Crit (Ps);
      return R;
   end Realloc;

   ------------
   -- Calloc --
   ------------

   function Calloc (Nmemb, Size : Interfaces.C.size_t) return System.Address is
      Total : constant Storage_Count := Storage_Count (Nmemb) * Storage_Count (Size);
      Ps    : constant Unsigned_32 := Enter_Crit;
      R     : System.Address;
   begin
      Ensure_Init;
      R := T.Allocate (Total);
      Leave_Crit (Ps);
      if R /= System.Null_Address then
         --  zero outside the lock
         declare
            Arr : Storage_Array (1 .. Total)
            with Import, Address => R;
         begin
            Arr := (others => 0);
         end;
      end if;
      return R;
   end Calloc;

   ---------------------
   -- Task_Stack_Free --
   ---------------------

   Running : array (0 .. 1) of System.Address
   with Import, Convention => C, External_Name => "__gnat_running_thread_table";

   procedure Task_Stack_Free (Stack, Thread : System.Address) is
   begin
      for I in 1 .. 2_000_000 loop
         if Running (0) /= Thread and then Running (1) /= Thread then
            Free (Stack);
            return;
         end if;
      end loop;
   --  timed out (thread stuck running?) -- leak rather than risk a UAF
   end Task_Stack_Free;

end Bare_Heap;
