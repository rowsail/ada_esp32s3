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
   --  Allocator critical section.  rsil-15 masks THIS core's interrupts (so an
   --  ISR that allocates cannot reenter the allocator on the same core), but it
   --  gives no exclusion against the other CPU -- both cores run GNARL and both
   --  reach this heap (System.Memory on one, task-stack reclamation on the
   --  other).  A single S32C1I (atomic compare-and-swap) spinlock closes that
   --  gap.  Order matters: mask local interrupts FIRST, then take the spinlock,
   --  so we never sleep on the other core while an ISR waits behind us; release
   --  in the reverse order.  The lock word lives in internal DRAM (.bss) --
   --  S32C1I is not supported on PSRAM.
   ---------------------------------------------------------------------------
   Heap_Lock : aliased Unsigned_32 := 0 with Volatile;   --  0 = free, 1 = held

   procedure Spin_Acquire is
      Old  : Unsigned_32;
      Zero : constant Unsigned_32 := 0;   --  expected value (free)
   begin
      loop
         Old := 1;   --  value to store when we win the lock
         Asm
           ("wsr.scompare1 %1"    & ASCII.LF &   --  SCOMPARE1 := 0 (free)
            "s32c1i        %0, %2, 0",            --  if [lock]=0 then [lock]:=1; %0:=old
            Outputs  => Unsigned_32'Asm_Output ("+r", Old),
            Inputs   => (Unsigned_32'Asm_Input ("r", Zero),
                         System.Address'Asm_Input ("r", Heap_Lock'Address)),
            Volatile => True,
            Clobber  => "memory");
         exit when Old = 0;   --  old value was 0 => we now hold the lock
      end loop;
   end Spin_Acquire;

   procedure Spin_Release is
      Zero : constant Unsigned_32 := 0;
   begin
      Asm
        ("memw" & ASCII.LF & "s32i.n %0, %1, 0",
         Inputs   => (Unsigned_32'Asm_Input ("r", Zero),
                      System.Address'Asm_Input ("r", Heap_Lock'Address)),
         Volatile => True,
         Clobber  => "memory");
   end Spin_Release;

   function Enter_Crit return Unsigned_32 is
      Ps : Unsigned_32;
   begin
      Asm
        ("rsil %0, 15",
         Outputs  => Unsigned_32'Asm_Output ("=r", Ps),
         Volatile => True,
         Clobber  => "memory");
      Spin_Acquire;      --  exclude the other core once our interrupts are masked
      return Ps;
   end Enter_Crit;

   procedure Leave_Crit (Ps : Unsigned_32) is
   begin
      Spin_Release;      --  release the other core first
      Asm
        ("wsr.ps %0" & ASCII.LF & "rsync",
         Inputs   => Unsigned_32'Asm_Input ("r", Ps),
         Volatile => True,
         Clobber  => "memory");
   end Leave_Crit;

   --  Largest request the 32-bit allocator can size without wrapping: reject
   --  anything above Storage_Count'Last (e.g. a negative C int reaching malloc as
   --  a huge size_t) rather than wrap it into a tiny block.
   Max_Request : constant Interfaces.C.size_t :=
     Interfaces.C.size_t (Storage_Count'Last);

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
      use type Interfaces.C.size_t;
      Ps : Unsigned_32;
      R  : System.Address;
   begin
      if N > Max_Request then
         return System.Null_Address;   --  would wrap the 32-bit size arithmetic
      end if;
      Ps := Enter_Crit;
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
      use type Interfaces.C.size_t;
      Ps : Unsigned_32;
      R  : System.Address;
   begin
      if N > Max_Request then
         return System.Null_Address;   --  would wrap the 32-bit size arithmetic
      end if;
      Ps := Enter_Crit;
      Ensure_Init;
      R := T.Reallocate (P, Storage_Count (N));
      Leave_Crit (Ps);
      return R;
   end Realloc;

   ------------
   -- Calloc --
   ------------

   function Calloc (Nmemb, Size : Interfaces.C.size_t) return System.Address is
      use type Interfaces.C.size_t;
      Total : Storage_Count;
      Ps    : Unsigned_32;
      R     : System.Address;
   begin
      --  Reject before allocating if Nmemb*Size overflows the (unsigned) size_t
      --  domain or exceeds what the 32-bit allocator can size -- otherwise the
      --  product wraps to a small value and a huge indexable "array" is returned.
      if Size /= 0
        and then (Nmemb > Interfaces.C.size_t'Last / Size
                  or else Nmemb * Size > Max_Request)
      then
         return System.Null_Address;
      end if;
      Total := Storage_Count (Nmemb) * Storage_Count (Size);
      Ps    := Enter_Crit;
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

   --  Volatile: the other core updates this table on a context switch, and the
   --  wait loop below re-reads it each iteration -- without Volatile the compiler
   --  may hoist the loads out of the loop and never observe the switch.
   Running : array (0 .. 1) of System.Address
   with Import, Volatile, Convention => C,
        External_Name => "__gnat_running_thread_table";

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
