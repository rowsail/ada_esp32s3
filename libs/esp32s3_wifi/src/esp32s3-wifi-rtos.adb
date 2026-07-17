with Ada.Task_Identification;   use Ada.Task_Identification;
with Ada.Unchecked_Conversion;
with Ada.Real_Time;             use Ada.Real_Time;
with System.Machine_Code;       use System.Machine_Code;
with System.Multiprocessors;
with System.Storage_Elements;
with ESP32S3.Log;

package body ESP32S3.WiFi.RTOS is

   use type Interfaces.Unsigned_32;
   use type System.Address;

   Pool_Full : constant System.Address := System.Null_Address;

   --  ------------------------------------------------------------------------
   --  Recursive mutex.  Try_Lock is the non-blocking fast path (free, or already
   --  owned by the caller -> recurse); if it fails the caller blocks in Wait_Lock
   --  until the mutex is free.  Barriers may not read entry parameters, so owner
   --  recursion is resolved in Try_Lock, not in the Wait_Lock barrier.
   --  ------------------------------------------------------------------------
   protected type Rec_Mutex is
      procedure Try_Lock (Caller : Task_Id; Got : out Boolean);
      entry     Wait_Lock (Caller : Task_Id);
      procedure Unlock;
   private
      Held  : Boolean := False;
      Owner : Task_Id := Null_Task_Id;
      Depth : Natural := 0;
   end Rec_Mutex;

   protected body Rec_Mutex is
      procedure Try_Lock (Caller : Task_Id; Got : out Boolean) is
      begin
         if not Held then
            Held  := True;
            Owner := Caller;
            Depth := 1;
            Got   := True;
         elsif Owner = Caller then
            Depth := Depth + 1;
            Got   := True;
         else
            Got := False;
         end if;
      end Try_Lock;

      entry Wait_Lock (Caller : Task_Id) when not Held is
      begin
         Held  := True;
         Owner := Caller;
         Depth := 1;
      end Wait_Lock;

      procedure Unlock is
      begin
         if Depth > 0 then
            Depth := Depth - 1;
            if Depth = 0 then
               Held  := False;
               Owner := Null_Task_Id;
            end if;
         end if;
      end Unlock;
   end Rec_Mutex;

   --  ------------------------------------------------------------------------
   --  Counting semaphore.
   --  ------------------------------------------------------------------------
   protected type Sem is
      procedure Setup (Init : Natural);
      entry     Take;
      --  Non-blocking take: decrement and report success if a count is
      --  available, else leave the count and report failure.  Backs the finite-
      --  and zero-timeout Semphr_Take (which polls this to a deadline rather
      --  than blocking on the Take entry).
      procedure Try_Take (Got : out Boolean);
      procedure Give;
   private
      Count : Natural := 0;
   end Sem;

   protected body Sem is
      procedure Setup (Init : Natural) is
      begin
         Count := Init;
      end Setup;

      entry Take when Count > 0 is
      begin
         Count := Count - 1;
      end Take;

      procedure Try_Take (Got : out Boolean) is
      begin
         if Count > 0 then
            Count := Count - 1;
            Got := True;
         else
            Got := False;
         end if;
      end Try_Take;

      procedure Give is
      begin
         Count := Count + 1;
      end Give;
   end Sem;

   --  ------------------------------------------------------------------------
   --  Queue: a byte ring buffer of `Cap` items of `Isz` bytes.  The WMAC ISR
   --  posts RX frames through queue_send_from_isr, so the ring is NOT an Ada
   --  protected object (a raw ISR calling a PO deadlocks on the ceiling lock);
   --  instead every ring access briefly masks interrupts (rsil/wsr.ps), which
   --  serialises the task and ISR safely.  Blocking send/recv poll with a 1 ms
   --  task delay when full/empty (never from the ISR -- from_isr is always
   --  non-blocking).
   --  ------------------------------------------------------------------------
   Q_Store : constant := 2048;   --  per-queue byte capacity (len*item_size);
                                 --  the wifi event queue is 200*8 = 1600 B
   Block_Forever : constant Interfaces.Unsigned_32 := 16#FFFF_FFFF#;

   type U8_Array is array (Natural range <>) of Interfaces.Unsigned_8;

   type Queue is record
      Store : U8_Array (0 .. Q_Store - 1);
      Isz   : Natural := 0;
      Cap   : Natural := 1;
      Head  : Natural := 0;
      Tail  : Natural := 0;
      Cnt   : Natural := 0;
   end record;
   type Queue_Ptr is access all Queue;

   --  Interrupt mask/restore around a ring access.
   function Int_Mask return Interfaces.Unsigned_32 with Inline;
   function Int_Mask return Interfaces.Unsigned_32 is
      Old : Interfaces.Unsigned_32;
   begin
      Asm ("rsil %0, 3",
           Outputs => Interfaces.Unsigned_32'Asm_Output ("=a", Old),
           Volatile => True);
      return Old;
   end Int_Mask;

   procedure Int_Unmask (State : Interfaces.Unsigned_32) with Inline;
   procedure Int_Unmask (State : Interfaces.Unsigned_32) is
   begin
      Asm ("wsr.ps %0" & ASCII.LF & "rsync",
           Inputs => Interfaces.Unsigned_32'Asm_Input ("a", State),
           Volatile => True);
   end Int_Unmask;

   function Q_Push (Q : Queue_Ptr; Item : System.Address) return Boolean is
      S  : constant Interfaces.Unsigned_32 := Int_Mask;
      Ok : Boolean := False;
   begin
      if Q.Cnt < Q.Cap then
         declare
            Src : U8_Array (0 .. Q.Isz - 1) with Import, Address => Item;
         begin
            for K in 0 .. Q.Isz - 1 loop
               Q.Store (Q.Tail * Q.Isz + K) := Src (K);
            end loop;
         end;
         Q.Tail := (Q.Tail + 1) mod Q.Cap;
         Q.Cnt  := Q.Cnt + 1;
         Ok := True;
      end if;
      Int_Unmask (S);
      return Ok;
   end Q_Push;

   --  Raw push WITHOUT masking interrupts -- for the WMAC ISR, which is already
   --  atomic w.r.t. the (lower-priority) tasks, and where a wsr.ps would corrupt
   --  the interrupt-dispatch register-window state.
   function Q_Push_Raw (Q : Queue_Ptr; Item : System.Address) return Boolean is
   begin
      if Q.Cnt >= Q.Cap then
         return False;
      end if;
      declare
         Src : U8_Array (0 .. Q.Isz - 1) with Import, Address => Item;
      begin
         for K in 0 .. Q.Isz - 1 loop
            Q.Store (Q.Tail * Q.Isz + K) := Src (K);
         end loop;
      end;
      Q.Tail := (Q.Tail + 1) mod Q.Cap;
      Q.Cnt  := Q.Cnt + 1;
      return True;
   end Q_Push_Raw;

   function Q_Pop (Q : Queue_Ptr; Item : System.Address) return Boolean is
      S  : constant Interfaces.Unsigned_32 := Int_Mask;
      Ok : Boolean := False;
   begin
      if Q.Cnt > 0 then
         declare
            Dst : U8_Array (0 .. Q.Isz - 1) with Import, Address => Item;
         begin
            for K in 0 .. Q.Isz - 1 loop
               Dst (K) := Q.Store (Q.Head * Q.Isz + K);
            end loop;
         end;
         Q.Head := (Q.Head + 1) mod Q.Cap;
         Q.Cnt  := Q.Cnt - 1;
         Ok := True;
      end if;
      Int_Unmask (S);
      return Ok;
   end Q_Pop;

   --  ------------------------------------------------------------------------
   --  Static pools + a guarded allocator (create may be called from any task).
   --  ------------------------------------------------------------------------
   Max_Mutex : constant := 32;
   Max_Sem   : constant := 32;
   Max_Queue : constant := 12;

   Mutexes : array (1 .. Max_Mutex) of aliased Rec_Mutex;
   Sems    : array (1 .. Max_Sem)   of aliased Sem;
   Queues  : array (1 .. Max_Queue) of aliased Queue;

   function C_Malloc (Size : Interfaces.Unsigned_32) return System.Address
     with Import, Convention => C, External_Name => "malloc";

   protected Allocator is
      procedure Get_Mutex (I : out Natural);
      procedure Get_Sem   (I : out Natural);
      procedure Get_Queue (I : out Natural);
      procedure Claim_Worker (I : out Natural);
   private
      N_Mutex  : Natural := 0;
      N_Sem    : Natural := 0;
      N_Queue  : Natural := 0;
      N_Worker : Natural := 0;
   end Allocator;

   protected body Allocator is
      procedure Get_Mutex (I : out Natural) is
      begin
         if N_Mutex < Max_Mutex then
            N_Mutex := N_Mutex + 1;
            I       := N_Mutex;
         else
            I := 0;
         end if;
      end Get_Mutex;

      procedure Get_Sem (I : out Natural) is
      begin
         if N_Sem < Max_Sem then
            N_Sem := N_Sem + 1;
            I     := N_Sem;
         else
            I := 0;
         end if;
      end Get_Sem;

      procedure Get_Queue (I : out Natural) is
      begin
         if N_Queue < Max_Queue then
            N_Queue := N_Queue + 1;
            I       := N_Queue;
         else
            I := 0;
         end if;
      end Get_Queue;

      procedure Claim_Worker (I : out Natural) is
      begin
         N_Worker := N_Worker + 1;
         I        := N_Worker;
      end Claim_Worker;
   end Allocator;

   --  ------------------------------------------------------------------------
   --  Task worker pool.  Each worker blocks on its mailbox until task_create
   --  assigns it a (func, param); it then runs func(param) -- the blob's task
   --  body, typically an infinite loop.  Workers are high priority so a created
   --  Wi-Fi task preempts the caller and runs until it blocks (e.g. on its event
   --  queue), at which point the caller of task_create resumes.
   --  ------------------------------------------------------------------------
   Max_Worker  : constant := 3;
   --  Timer + workers at equal (top) priority.  (Raising the timer above the
   --  workers so scan-dwell timers preempt under heavy RX instead caused a fault
   --  -- a timer callback preempting the wifi task mid-RX races on MAC state.
   --  The proper fix is an interrupt-driven timer; see BRINGUP.md.)
   Timer_Prio  : constant System.Priority := System.Priority'Last;
   Worker_Prio : constant System.Priority := System.Priority'Last;
   Worker_Stk  : constant := 8 * 1024;
   --  Pin all Wi-Fi tasks to core 0 (CPU'First), where the WMAC interrupt is
   --  routed.  The ISR/queue interrupt-masking (rsil) only serialises the LOCAL
   --  core, so a worker on core 1 would race the core-0 ISR on the ring buffer.
   Wifi_CPU : constant System.Multiprocessors.CPU := System.Multiprocessors.CPU'First;

   type Task_Entry is access procedure (Arg : System.Address)
     with Convention => C;
   function To_Entry is
     new Ada.Unchecked_Conversion (System.Address, Task_Entry);

   protected type Mailbox is
      procedure Try_Post (F, P : System.Address; Ok : out Boolean);
      entry     Wait (F, P : out System.Address);
   private
      Ready : Boolean := False;
      Taken : Boolean := False;
      FF    : System.Address := System.Null_Address;
      PP    : System.Address := System.Null_Address;
   end Mailbox;

   protected body Mailbox is
      procedure Try_Post (F, P : System.Address; Ok : out Boolean) is
      begin
         if Taken then
            Ok := False;
         else
            Taken := True;
            FF    := F;
            PP    := P;
            Ready := True;
            Ok    := True;
         end if;
      end Try_Post;

      entry Wait (F, P : out System.Address) when Ready is
      begin
         F     := FF;
         P     := PP;
         Ready := False;
      end Wait;
   end Mailbox;

   Mailboxes : array (1 .. Max_Worker) of Mailbox;

   task type Worker
     with Priority => Worker_Prio, CPU => Wifi_CPU, Storage_Size => Worker_Stk;

   --  Worker task identity <-> the handle task_create handed out for it (the
   --  worker's Mailbox address).  The blob's current_task_is_wifi_task compares
   --  osi task_get_current_task() against the handle task_create returned, so
   --  Get_Current_Task MUST return that same handle when running in a worker --
   --  otherwise ieee80211_ioctl (set_appie, etc.) called from the wifi task
   --  wrongly thinks it is off-task and posts+waits on itself -> deadlock.
   Worker_Tid : array (1 .. Max_Worker) of Task_Id := (others => Null_Task_Id);

   task body Worker is
      Idx  : Natural;
      F, P : System.Address;
   begin
      Allocator.Claim_Worker (Idx);
      if Idx in Mailboxes'Range then
         Worker_Tid (Idx) := Current_Task;   --  each worker owns its own slot
         loop
            Mailboxes (Idx).Wait (F, P);
            if F /= System.Null_Address then
               To_Entry (F) (P);  --  run the assigned task body (usually forever)
            end if;
         end loop;
      end if;
   end Worker;

   Workers : array (1 .. Max_Worker) of Worker;
   pragma Unreferenced (Workers);

   --  Handle <-> pool-element address conversions.
   type Mutex_Ptr is access all Rec_Mutex;
   type Sem_Ptr   is access all Sem;
   function To_Mutex is new Ada.Unchecked_Conversion (System.Address, Mutex_Ptr);
   function To_Sem   is new Ada.Unchecked_Conversion (System.Address, Sem_Ptr);
   function To_Queue is new Ada.Unchecked_Conversion (System.Address, Queue_Ptr);

   --  ------------------------------------------------------------------------
   --  Public (C) entry points
   --  ------------------------------------------------------------------------
   function Recursive_Mutex_Create return System.Address is
      I : Natural;
   begin
      Allocator.Get_Mutex (I);
      return (if I = 0 then Pool_Full else Mutexes (I)'Address);
   end Recursive_Mutex_Create;

   function Mutex_Create return System.Address renames Recursive_Mutex_Create;

   function Mutex_Lock (H : System.Address) return Interfaces.Integer_32 is
      M   : constant Mutex_Ptr := To_Mutex (H);
      Me  : constant Task_Id := Current_Task;
      Got : Boolean;
   begin
      if M = null then
         return 0;
      end if;
      M.Try_Lock (Me, Got);
      if not Got then
         M.Wait_Lock (Me);   --  block until free (portMAX_DELAY semantics)
      end if;
      return 1;
   end Mutex_Lock;

   function Mutex_Unlock (H : System.Address) return Interfaces.Integer_32 is
      M : constant Mutex_Ptr := To_Mutex (H);
   begin
      if M /= null then
         M.Unlock;
      end if;
      return 1;
   end Mutex_Unlock;

   function Semphr_Create
     (Max, Init : Interfaces.Unsigned_32) return System.Address
   is
      pragma Unreferenced (Max);
      I : Natural;
   begin
      Allocator.Get_Sem (I);
      if I = 0 then
         return Pool_Full;
      end if;
      Sems (I).Setup (Natural (Init));
      return Sems (I)'Address;
   end Semphr_Create;

   --  Cap for a finite timeout's millisecond count: guards Integer / Time_Span
   --  arithmetic against an absurd Ticks (anything non-portMAX beyond an hour is
   --  effectively forever anyway).  Block_Forever (0xFFFF_FFFF) is handled first,
   --  before this ever applies.
   Max_Finite_Ms : constant := 3_600_000;   --  one hour

   function Semphr_Take
     (H : System.Address; Ticks : Interfaces.Unsigned_32)
      return Interfaces.Integer_32
   is
      S   : constant Sem_Ptr := To_Sem (H);
      Got : Boolean;
   begin
      if S = null then
         return 0;
      end if;

      --  portMAX_DELAY: block until available (the only value the blob passes on
      --  the scan/connect/sniff paths -- see the note below).
      if Ticks = Block_Forever then
         S.Take;
         return 1;
      end if;

      --  Finite timeout (1 tick = 1 ms), including 0.  Try once; then, unless the
      --  caller asked for a non-blocking probe (0), poll to the deadline.  This
      --  mirrors the queue's finite-timeout handling and, unlike a bare Take,
      --  cannot hang -- so a blob path that DOES pass a finite timeout (power
      --  save, stop, SoftAP -- none exercised today, confirmed by on-target
      --  instrumentation) fails cleanly instead of blocking the caller forever.
      S.Try_Take (Got);
      if Got or else Ticks = 0 then
         return (if Got then 1 else 0);
      end if;

      declare
         Ms       : constant Integer :=
           (if Ticks > Max_Finite_Ms then Max_Finite_Ms else Integer (Ticks));
         Deadline : constant Time := Clock + Milliseconds (Ms);
      begin
         loop
            delay until Clock + Milliseconds (1);
            S.Try_Take (Got);
            exit when Got or else Clock >= Deadline;
         end loop;
      end;
      return (if Got then 1 else 0);
   end Semphr_Take;

   function Semphr_Give (H : System.Address) return Interfaces.Integer_32 is
      S : constant Sem_Ptr := To_Sem (H);
   begin
      if S /= null then
         S.Give;
      end if;
      return 1;
   end Semphr_Give;

   --  --- queues ---
   function Queue_Create
     (Len, Item_Size : Interfaces.Unsigned_32) return System.Address
   is
      I  : Natural;
      Ok : Boolean;
   begin
      Ok := Natural (Item_Size) > 0 and then Natural (Len) > 0
        and then Natural (Item_Size) * Natural (Len) <= Q_Store;
      Allocator.Get_Queue (I);
      if I = 0 then
         ESP32S3.Log.Put_Line ("[wifi]  -> queue pool exhausted");
         return Pool_Full;
      end if;
      if not Ok then
         ESP32S3.Log.Put_Line ("[wifi]  -> queue too big for Q_Store");
         return Pool_Full;   --  item*len exceeds Q_Store: raise Q_Store
      end if;
      Queues (I).Isz  := Natural (Item_Size);
      Queues (I).Cap  := Natural (Len);
      Queues (I).Head := 0;
      Queues (I).Tail := 0;
      Queues (I).Cnt  := 0;
      return Queues (I)'Address;
   end Queue_Create;

   function Wifi_Create_Queue
     (Len, Item_Size : Interfaces.Integer_32) return System.Address
   is
      --  wifi_static_queue_t { void *handle; void *storage; }
      type Addr_Pair is array (0 .. 1) of System.Address with Convention => C;
      H : constant System.Address :=
        Queue_Create (Interfaces.Unsigned_32 (Len),
                      Interfaces.Unsigned_32 (Item_Size));
      S : constant System.Address := C_Malloc (8);
   begin
      if S = System.Null_Address or else H = Pool_Full then
         return System.Null_Address;
      end if;
      declare
         W : Addr_Pair with Import, Address => S;
      begin
         W (0) := H;                    --  handle
         W (1) := System.Null_Address;  --  storage (queue owns its own)
      end;
      return S;
   end Wifi_Create_Queue;

   --  Blocking send/recv poll every 1 ms while full/empty.  ONLY from task
   --  context (a task delay is illegal in an ISR); queue_send_from_isr below is
   --  the non-blocking variant the WMAC ISR uses.
   function Queue_Send
     (H, Item : System.Address; Ticks : Interfaces.Unsigned_32)
      return Interfaces.Integer_32
   is
      Q : constant Queue_Ptr := To_Queue (H);
   begin
      if Q = null then
         return 0;
      elsif Q_Push (Q, Item) then
         return 1;
      elsif Ticks /= Block_Forever then
         return 0;
      end if;
      loop
         delay until Clock + Milliseconds (1);
         exit when Q_Push (Q, Item);
      end loop;
      return 1;
   end Queue_Send;

   --  queue_send_from_isr: never blocks, never delays (ISR context).
   Isr_Posts : Natural := 0 with Volatile;
   function Isr_Post_Count return Natural is (Isr_Posts);

   function Queue_Send_From_Isr
     (H, Item, Woken : System.Address) return Interfaces.Integer_32
   is
      pragma Unreferenced (Woken);
      Q : constant Queue_Ptr := To_Queue (H);
   begin
      if Q = null then
         return 0;
      end if;
      Isr_Posts := Isr_Posts + 1;
      return (if Q_Push_Raw (Q, Item) then 1 else 0);
   end Queue_Send_From_Isr;

   function Queue_Recv
     (H, Item : System.Address; Ticks : Interfaces.Unsigned_32)
      return Interfaces.Integer_32
   is
      Q : constant Queue_Ptr := To_Queue (H);
   begin
      if Q = null then
         return 0;
      elsif Q_Pop (Q, Item) then
         return 1;
      elsif Ticks /= Block_Forever then
         return 0;
      end if;
      loop
         delay until Clock + Milliseconds (1);
         exit when Q_Pop (Q, Item);
      end loop;
      return 1;
   end Queue_Recv;

   function Queue_Msg_Waiting (H : System.Address) return Interfaces.Unsigned_32
   is
      Q : constant Queue_Ptr := To_Queue (H);
   begin
      return (if Q = null then 0
              else Interfaces.Unsigned_32 (Q.Cnt));
   end Queue_Msg_Waiting;

   --  --- tasks ---
   function Spawn
     (Func, Param, Handle : System.Address) return Interfaces.Integer_32
   is
      Ok : Boolean;
   begin
      for I in Mailboxes'Range loop
         Mailboxes (I).Try_Post (Func, Param, Ok);
         if Ok then
            if Handle /= System.Null_Address then
               declare
                  H : System.Address with Import, Address => Handle;
               begin
                  H := Mailboxes (I)'Address;   --  opaque task handle
               end;
            end if;
            return 1;   --  pdPASS
         end if;
      end loop;
      ESP32S3.Log.Put_Line ("[wifi] task_create: worker pool exhausted");
      return 0;
   end Spawn;

   function Task_Create_Pinned
     (Func        : System.Address;
      Name        : System.Address;
      Stack_Depth : Interfaces.Unsigned_32;
      Param       : System.Address;
      Prio        : Interfaces.Unsigned_32;
      Handle      : System.Address;
      Core        : Interfaces.Unsigned_32) return Interfaces.Integer_32
   is
      pragma Unreferenced (Name, Stack_Depth, Prio, Core);
   begin
      return Spawn (Func, Param, Handle);
   end Task_Create_Pinned;

   function Task_Create
     (Func        : System.Address;
      Name        : System.Address;
      Stack_Depth : Interfaces.Unsigned_32;
      Param       : System.Address;
      Prio        : Interfaces.Unsigned_32;
      Handle      : System.Address) return Interfaces.Integer_32
   is
      pragma Unreferenced (Name, Stack_Depth, Prio);
   begin
      return Spawn (Func, Param, Handle);
   end Task_Create;

   procedure Task_Delay (Ticks : Interfaces.Unsigned_32) is
   begin
      delay Duration (Ticks) / 1000.0;   --  1 tick = 1 ms
   end Task_Delay;

   --  --- CPU-exception diagnostic ---
   procedure Xt_Set_Exception_Handler
     (N : Interfaces.Integer_32; F : System.Address)
     with Import, Convention => C, External_Name => "xt_set_exception_handler";

   procedure Exc_Handler (Frame : System.Address)
     with Convention => C, No_Return;
   procedure Exc_Handler (Frame : System.Address) is
      use System.Storage_Elements;
      PC    : Interfaces.Unsigned_32 with Import, Address => Frame + 4;
      Cause : Interfaces.Unsigned_32 with Import, Address => Frame + 80;
      Vaddr : Interfaces.Unsigned_32 with Import, Address => Frame + 84;
   begin
      ESP32S3.Log.Put ("!!! CPU EXC cause=0x");
      ESP32S3.Log.Put_Hex (Cause);
      ESP32S3.Log.Put (" pc=0x");
      ESP32S3.Log.Put_Hex (PC);
      ESP32S3.Log.Put (" vaddr=0x");
      ESP32S3.Log.Put_Hex (Vaddr);
      ESP32S3.Log.New_Line;
      loop
         null;
      end loop;
   end Exc_Handler;

   procedure Install_Exc_Handler is
   begin
      for C in Interfaces.Integer_32 range 0 .. 40 loop
         Xt_Set_Exception_Handler (C, Exc_Handler'Address);
      end loop;
   end Install_Exc_Handler;

   --  --- per-task semaphore (wifi_thread_semphr_get) ---
   Max_Thread : constant := 8;
   type Tid_Array  is array (1 .. Max_Thread) of Task_Id;
   type Addr_Array is array (1 .. Max_Thread) of System.Address;
   protected Thread_Map is
      procedure Find (T : Task_Id; S : out System.Address);
      procedure Add  (T : Task_Id; S : System.Address);
   private
      N    : Natural := 0;
      Tids : Tid_Array  := (others => Null_Task_Id);
      Ss   : Addr_Array := (others => System.Null_Address);
   end Thread_Map;

   protected body Thread_Map is
      procedure Find (T : Task_Id; S : out System.Address) is
      begin
         S := System.Null_Address;
         for I in 1 .. N loop
            if Tids (I) = T then
               S := Ss (I);
               return;
            end if;
         end loop;
      end Find;

      procedure Add (T : Task_Id; S : System.Address) is
      begin
         if N < Max_Thread then
            N        := N + 1;
            Tids (N) := T;
            Ss (N)   := S;
         end if;
      end Add;
   end Thread_Map;

   function Thread_Semphr_Get return System.Address is
      Me : constant Task_Id := Current_Task;
      S  : System.Address;
   begin
      Thread_Map.Find (Me, S);
      if S = System.Null_Address then
         S := Semphr_Create (1, 0);
         Thread_Map.Add (Me, S);
      end if;
      return S;
   end Thread_Semphr_Get;

   --  --- software timers ---
   Max_Timer : constant := 16;
   type Timer_Rec is record
      Ptr      : System.Address := System.Null_Address;   --  identity (blob's)
      Fn       : System.Address := System.Null_Address;
      Arg      : System.Address := System.Null_Address;
      Deadline : Time           := Time_First;
      Period   : Time_Span      := Time_Span_Zero;         --  0 => one-shot
      Armed    : Boolean        := False;
   end record;
   type Timer_Array is array (1 .. Max_Timer) of Timer_Rec;

   protected Timer_Mgr is
      procedure Setfn (Ptr, Fn, Arg : System.Address);
      procedure Arm (Ptr : System.Address; Span : Time_Span; Repeat : Boolean);
      procedure Disarm (Ptr : System.Address);
      procedure Done (Ptr : System.Address);
      procedure Take_Expired
        (Now : Time; Fn, Arg : out System.Address; Found : out Boolean);
   private
      T : Timer_Array;
   end Timer_Mgr;

   protected body Timer_Mgr is
      procedure Locate (Ptr : System.Address; I : out Natural) is
      begin
         I := 0;
         for K in T'Range loop
            if T (K).Ptr = Ptr then I := K; return; end if;
         end loop;
         for K in T'Range loop        --  else grab a free slot
            if T (K).Ptr = System.Null_Address then
               T (K).Ptr := Ptr; I := K; return;
            end if;
         end loop;
      end Locate;

      procedure Setfn (Ptr, Fn, Arg : System.Address) is
         I : Natural;
      begin
         Locate (Ptr, I);
         if I /= 0 then T (I).Fn := Fn; T (I).Arg := Arg; end if;
      end Setfn;

      procedure Arm (Ptr : System.Address; Span : Time_Span; Repeat : Boolean) is
         I : Natural;
      begin
         Locate (Ptr, I);
         if I /= 0 then
            T (I).Deadline := Clock + Span;
            T (I).Period   := (if Repeat then Span else Time_Span_Zero);
            T (I).Armed    := True;
         end if;
      end Arm;

      procedure Disarm (Ptr : System.Address) is
         I : Natural;
      begin
         Locate (Ptr, I);
         if I /= 0 then T (I).Armed := False; end if;
      end Disarm;

      procedure Done (Ptr : System.Address) is
         I : Natural;
      begin
         Locate (Ptr, I);
         if I /= 0 then T (I) := (others => <>); end if;
      end Done;

      procedure Take_Expired
        (Now : Time; Fn, Arg : out System.Address; Found : out Boolean) is
      begin
         Fn := System.Null_Address; Arg := System.Null_Address; Found := False;
         for K in T'Range loop
            if T (K).Armed and then T (K).Deadline <= Now then
               Fn := T (K).Fn; Arg := T (K).Arg; Found := True;
               if T (K).Period > Time_Span_Zero then
                  T (K).Deadline := T (K).Deadline + T (K).Period;
               else
                  T (K).Armed := False;
               end if;
               return;
            end if;
         end loop;
      end Take_Expired;
   end Timer_Mgr;

   task Timer_Task
     with Priority => Timer_Prio, CPU => Wifi_CPU, Storage_Size => Worker_Stk;

   task body Timer_Task is
      Now      : Time;
      Fn, Arg  : System.Address;
      Found    : Boolean;
   begin
      Install_Exc_Handler;   --  catch faults on core 0 (this task is pinned there)
      loop
         delay until Clock + Milliseconds (2);
         Now := Clock;
         loop
            Timer_Mgr.Take_Expired (Now, Fn, Arg, Found);
            exit when not Found;
            if Fn /= System.Null_Address then
               To_Entry (Fn) (Arg);
            end if;
         end loop;
      end loop;
   end Timer_Task;

   procedure Timer_Setfn (Ptr, Fn, Arg : System.Address) is
   begin
      Timer_Mgr.Setfn (Ptr, Fn, Arg);
   end Timer_Setfn;

   procedure Timer_Arm
     (Ptr : System.Address; Ms : Interfaces.Unsigned_32;
      Repeat : Interfaces.Unsigned_32) is
   begin
      Timer_Mgr.Arm (Ptr, Milliseconds (Integer (Ms)), Repeat /= 0);
   end Timer_Arm;

   procedure Timer_Arm_Us
     (Ptr : System.Address; Us : Interfaces.Unsigned_32;
      Repeat : Interfaces.Unsigned_32) is
   begin
      Timer_Mgr.Arm (Ptr, Microseconds (Integer (Us)), Repeat /= 0);
   end Timer_Arm_Us;

   procedure Timer_Disarm (Ptr : System.Address) is
   begin
      Timer_Mgr.Disarm (Ptr);
   end Timer_Disarm;

   procedure Timer_Done (Ptr : System.Address) is
   begin
      Timer_Mgr.Done (Ptr);
   end Timer_Done;

   function To_Addr is new Ada.Unchecked_Conversion (Task_Id, System.Address);

   --  Return the SAME handle task_create returned for the running task: for a
   --  pool worker that is its Mailbox address; for any other task (env task,
   --  timer task) fall back to the raw Task_Id.  Keeps the blob's
   --  current_task_is_wifi_task check correct (see Worker_Tid).
   function Get_Current_Task return System.Address is
      Me : constant Task_Id := Current_Task;
   begin
      for I in 1 .. Max_Worker loop
         if Worker_Tid (I) = Me then
            return Mailboxes (I)'Address;
         end if;
      end loop;
      return To_Addr (Me);
   end Get_Current_Task;

   procedure Delete_Noop (H : System.Address) is null;

end ESP32S3.WiFi.RTOS;
