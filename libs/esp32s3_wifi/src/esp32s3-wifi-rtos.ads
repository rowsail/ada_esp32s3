--  Jorvik-backed implementations of the FreeRTOS-shaped primitives the Wi-Fi
--  blob calls through the OS adapter.  The blob expects dynamic create/delete of
--  mutexes, semaphores, queues, event groups and tasks; the Jorvik runtime has
--  no dynamic protected objects or tasks, so each kind is served from a STATIC
--  pool and the opaque handle handed back to the blob is the address of a pool
--  element (mapped back on use).  Blocking uses protected entries; portMAX_DELAY
--  waits map to plain (block-forever) entry calls.
--
--  This wave: recursive/plain mutexes and counting semaphores (the first RTOS
--  services esp_wifi_init_internal needs).  Queues, event groups, tasks and
--  timers follow.  All subprograms are Convention=>C for the adapter table.
with System;
with Interfaces;

private package ESP32S3.WiFi.RTOS is

   --  --- mutexes (recursive and plain; the blob's global lock is recursive) ---
   function Recursive_Mutex_Create return System.Address with Convention => C;
   function Mutex_Create           return System.Address with Convention => C;
   function Mutex_Lock   (H : System.Address) return Interfaces.Integer_32
     with Convention => C;
   function Mutex_Unlock (H : System.Address) return Interfaces.Integer_32
     with Convention => C;

   --  --- counting semaphores ---
   --  _semphr_create (max, init) -> handle; take(h, ticks) / give(h) -> bool.
   function Semphr_Create
     (Max, Init : Interfaces.Unsigned_32) return System.Address
     with Convention => C;
   function Semphr_Take
     (H : System.Address; Ticks : Interfaces.Unsigned_32)
      return Interfaces.Integer_32 with Convention => C;
   function Semphr_Give (H : System.Address) return Interfaces.Integer_32
     with Convention => C;

   --  _wifi_thread_semphr_get: a per-task counting semaphore, created lazily on
   --  first call by each task and returned thereafter (FreeRTOS uses TLS).
   function Thread_Semphr_Get return System.Address with Convention => C;

   --  --- queues (byte ring buffers; the wifi task's event transport) ---
   --  queue_create(len, item_size) -> handle; wifi_create_queue additionally
   --  wraps the handle in a {handle, storage} struct the blob dereferences.
   function Queue_Create
     (Len, Item_Size : Interfaces.Unsigned_32) return System.Address
     with Convention => C;
   function Wifi_Create_Queue
     (Len, Item_Size : Interfaces.Integer_32) return System.Address
     with Convention => C;
   function Queue_Send
     (H, Item : System.Address; Ticks : Interfaces.Unsigned_32)
      return Interfaces.Integer_32 with Convention => C;
   --  Non-blocking variant for the WMAC ISR (never delays).
   function Queue_Send_From_Isr
     (H, Item, Woken : System.Address) return Interfaces.Integer_32
     with Convention => C;
   function Queue_Recv
     (H, Item : System.Address; Ticks : Interfaces.Unsigned_32)
      return Interfaces.Integer_32 with Convention => C;
   function Queue_Msg_Waiting (H : System.Address) return Interfaces.Unsigned_32
     with Convention => C;

   --  --- tasks ---
   --  Jorvik has no dynamic tasks, so task_create hands the (func, param) to a
   --  free worker from a static high-priority pool; the worker runs the func
   --  (the blob's task body, an infinite loop) and the returned handle is the
   --  worker's mailbox address.  Core pinning / stack_depth / name are ignored
   --  (workers are fixed); returns pdPASS (1) or 0 if the pool is exhausted.
   function Task_Create_Pinned
     (Func        : System.Address;
      Name        : System.Address;
      Stack_Depth : Interfaces.Unsigned_32;
      Param       : System.Address;
      Prio        : Interfaces.Unsigned_32;
      Handle      : System.Address;
      Core        : Interfaces.Unsigned_32) return Interfaces.Integer_32
     with Convention => C;

   function Task_Create
     (Func        : System.Address;
      Name        : System.Address;
      Stack_Depth : Interfaces.Unsigned_32;
      Param       : System.Address;
      Prio        : Interfaces.Unsigned_32;
      Handle      : System.Address) return Interfaces.Integer_32
     with Convention => C;

   --  vTaskDelay(ticks): relative delay of the calling task (1 tick = 1 ms).
   procedure Task_Delay (Ticks : Interfaces.Unsigned_32) with Convention => C;

   --  DIAGNOSTIC: register a CPU-exception handler (that prints cause/PC/vaddr
   --  then halts) on the CALLING core -- the bare runtime's default is a silent
   --  spin.  Call from each core whose faults you want to see.
   procedure Install_Exc_Handler;

   --  Diagnostic: total items the WMAC ISR has posted via queue_send_from_isr
   --  (RX frames + events) -- a rising count post-connection means the RX
   --  interrupt is delivering frames up to ppTask.
   function Isr_Post_Count return Natural;

   --  _task_get_current_task -> an opaque, unique, stable handle for the caller.
   --  The GNAT Task_Id is the address of the task control block, which serves
   --  exactly that role.
   function Get_Current_Task return System.Address with Convention => C;

   --  --- software timers (ETSTimer / esp_timer) ---
   --  The blob owns each ETSTimer struct and passes its address as the timer
   --  identity.  We keep a side table keyed by that address and fire callbacks
   --  from a polling timer task; the struct itself is treated as opaque.
   procedure Timer_Setfn (Ptr, Fn, Arg : System.Address) with Convention => C;
   procedure Timer_Arm
     (Ptr : System.Address; Ms : Interfaces.Unsigned_32;
      Repeat : Interfaces.Unsigned_32) with Convention => C;
   procedure Timer_Arm_Us
     (Ptr : System.Address; Us : Interfaces.Unsigned_32;
      Repeat : Interfaces.Unsigned_32) with Convention => C;
   procedure Timer_Disarm (Ptr : System.Address) with Convention => C;
   procedure Timer_Done   (Ptr : System.Address) with Convention => C;

   --  Pool objects are never truly freed (fixed pools); delete is a no-op that
   --  the adapter can point the *_delete slots at.
   procedure Delete_Noop (H : System.Address) with Convention => C;

end ESP32S3.WiFi.RTOS;
