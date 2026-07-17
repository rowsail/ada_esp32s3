--  OS-adapter callbacks and table construction (ESP-IDF v5.4.4 g_wifi_osi_funcs
--  semantics, esp32s3/esp_adapter.c).  The memory allocators map onto the
--  DMA-capable leftover-DRAM heap; the sync primitives (sem/mutex/queue/event-
--  group/task/timer) onto the Jorvik-backed pool in ESP32S3.WiFi.RTOS; clocks
--  and PHY onto ESP32S3.WiFi.PHY; the WMAC interrupt onto ESP32S3.WiFi.Interrupt.
--  Any slot still unimplemented points at a NAMED halt-stub (below) that prints
--  its slot name before spinning, so a hardware run names what the blob needs
--  next.  See BRINGUP.md.
with Interfaces;    use type Interfaces.Unsigned_32;
with System;
with Ada.Real_Time; use Ada.Real_Time;
with ESP32S3.Log;
with ESP32S3.MAC;
with ESP32S3.RNG;
with ESP32S3.WiFi.RTOS;
with ESP32S3.WiFi.PHY;
with ESP32S3.WiFi.Interrupt;
with System.Machine_Code; use System.Machine_Code;
with System.Storage_Elements; use System.Storage_Elements;

package body ESP32S3.WiFi.OS_Adapter is

   --  ------------------------------------------------------------------------
   --  Diagnostic halt: name the unimplemented slot, then stop.  (No_Return.)
   --  ------------------------------------------------------------------------
   procedure Halt (Name : String) with No_Return;
   procedure Halt (Name : String) is
   begin
      ESP32S3.Log.Put_Line ("");
      ESP32S3.Log.Put_Line ("[wifi] UNIMPLEMENTED OS-adapter slot: " & Name);
      loop
         null;
      end loop;
   end Halt;

   --  A slot not yet named/implemented: announce it (can't say which, but flags
   --  that an unhandled slot was reached) and halt.
   procedure Stub_Silent with Convention => C, No_Return;
   procedure Stub_Silent is
   begin
      Halt ("<unnamed slot (others)>");
   end Stub_Silent;

   --  ------------------------------------------------------------------------
   --  Memory: the blob's allocations map onto the freestanding C heap, which is
   --  the leftover-DRAM arena -- internal, DMA-capable SRAM (correct for Wi-Fi
   --  RX/TX buffers; PSRAM would not be DMA-capable).
   --  ------------------------------------------------------------------------
   function C_Malloc (Size : Interfaces.Unsigned_32) return System.Address
     with Import, Convention => C, External_Name => "malloc";
   procedure C_Free (P : System.Address)
     with Import, Convention => C, External_Name => "free";
   function C_Calloc (N, Size : Interfaces.Unsigned_32) return System.Address
     with Import, Convention => C, External_Name => "calloc";
   function C_Realloc (P : System.Address; Size : Interfaces.Unsigned_32)
     return System.Address
     with Import, Convention => C, External_Name => "realloc";

   --  zalloc(size) = calloc(1, size); the single-arg wrappers the table needs.
   function Zalloc (Size : Interfaces.Unsigned_32) return System.Address
     with Convention => C;
   function Zalloc (Size : Interfaces.Unsigned_32) return System.Address is
     (C_Calloc (1, Size));

   --  ------------------------------------------------------------------------
   --  Trivial real services.
   --  ------------------------------------------------------------------------
   function Env_Is_Chip return Interfaces.Unsigned_8 with Convention => C;
   function Env_Is_Chip return Interfaces.Unsigned_8 is (1);   --  real silicon

   function Is_From_Isr return Interfaces.Unsigned_8 with Convention => C;
   function Is_From_Isr return Interfaces.Unsigned_8 is (0);   --  TODO real check

   function Esp_Timer_Get_Time return Interfaces.Integer_64 with Convention => C;
   function Esp_Timer_Get_Time return Interfaces.Integer_64 is
      Us : constant Duration := To_Duration (Clock - Time_First) * 1_000_000;
   begin
      return Interfaces.Integer_64 (Us);
   end Esp_Timer_Get_Time;

   --  esp_random / os_random: one fresh word from the HARDWARE RNG (was a
   --  fixed-seed LCG).  The Wi-Fi RF is up whenever the blob calls this, so the
   --  RNG's noise source is live and its output is fit for the blob's nonces.
   function Rand_Impl return Interfaces.Unsigned_32 with Convention => C;
   function Rand_Impl return Interfaces.Unsigned_32
   is (Interfaces.Unsigned_32 (ESP32S3.RNG.Read));

   --  os_get_random(void *buf, size_t len): fill len bytes from the hardware RNG
   --  (was a no-op that left the blob's buffer untouched).  Returns 0 on success.
   function Os_Get_Random
     (Buf : System.Address; Len : Interfaces.Unsigned_32) return Interfaces.Integer_32
     with Convention => C;
   function Os_Get_Random
     (Buf : System.Address; Len : Interfaces.Unsigned_32) return Interfaces.Integer_32 is
   begin
      if Len > 0 then
         declare
            Out_Bytes : ESP32S3.RNG.Byte_Array (0 .. Natural (Len) - 1)
              with Import, Address => Buf;
         begin
            ESP32S3.RNG.Fill (Out_Bytes);
         end;
      end if;
      return 0;
   end Os_Get_Random;

   --  esp_get_free_heap_size: the live free-payload byte count of the app heap
   --  (the leftover-DRAM arena behind malloc), read from Bare_Heap via its C
   --  symbol so this library keeps no build dependency on the boot-side unit --
   --  the same way malloc/free are resolved at link time.  (Was a fixed 65_536.)
   function Bare_Heap_Free_Bytes return Interfaces.Unsigned_32
     with Import, Convention => C, External_Name => "__bare_heap_free_bytes";

   function Get_Free_Heap_Size return Interfaces.Unsigned_32 with Convention => C;
   function Get_Free_Heap_Size return Interfaces.Unsigned_32
   is (Bare_Heap_Free_Bytes);

   --  _task_ms_to_tick: the Jorvik tick is 1 ms, so ticks == ms.
   function Ms_To_Tick (Ms : Interfaces.Unsigned_32) return Interfaces.Integer_32
     with Convention => C;
   function Ms_To_Tick (Ms : Interfaces.Unsigned_32) return Interfaces.Integer_32
   is (Interfaces.Integer_32 (Ms));

   function Task_Max_Prio return Interfaces.Integer_32 with Convention => C;
   function Task_Max_Prio return Interfaces.Integer_32 is (25);

   function Slowclk_Cal return Interfaces.Unsigned_32 with Convention => C;
   function Slowclk_Cal return Interfaces.Unsigned_32 is (0);

   procedure Void_Noop with Convention => C;
   procedure Void_Noop is null;

   procedure Log_Noop with Convention => C;
   procedure Log_Noop is null;

   function Ret_Zero return Interfaces.Integer_32 with Convention => C;
   function Ret_Zero return Interfaces.Integer_32 is (0);

   --  esp_event_post(base, id, data, size, ticks): the blob notifies us of
   --  Wi-Fi events (STA start/connected/disconnected, scan done, ...).  We do
   --  not run an event loop -- the scan and connect paths poll their own state
   --  -- so we just acknowledge the post.  (WIFI_EVENT ids: 2=STA_START,
   --  4=STA_CONNECTED, 5=STA_DISCONNECTED with the reason at data+39.)
   function Event_Post
     (Base : System.Address; Id : Interfaces.Integer_32;
      Data : System.Address; Size, Ticks : Interfaces.Unsigned_32)
      return Interfaces.Integer_32 with Convention => C;
   function Event_Post
     (Base : System.Address; Id : Interfaces.Integer_32;
      Data : System.Address; Size, Ticks : Interfaces.Unsigned_32)
      return Interfaces.Integer_32
   is
      pragma Unreferenced (Base, Id, Data, Size, Ticks);
   begin
      return 0;
   end Event_Post;

   --  ------------------------------------------------------------------------
   --  Spin lock + Wi-Fi critical section.  spin_lock_create hands back a small
   --  malloc'd portMUX (the blob only needs a non-null, free-able handle); the
   --  actual mutual exclusion is the interrupt mask that wifi_int_disable raises
   --  and wifi_int_restore lowers.  On Xtensa, `rsil` reads PS and raises
   --  INTLEVEL (returning the prior PS, so nesting works); `wsr.ps` restores it.
   --  ------------------------------------------------------------------------
   function Spin_Create return System.Address with Convention => C;
   function Spin_Create return System.Address is (C_Malloc (8));

   function Int_Disable (Mux : System.Address) return Interfaces.Unsigned_32
     with Convention => C;
   function Int_Disable (Mux : System.Address) return Interfaces.Unsigned_32 is
      pragma Unreferenced (Mux);
      Old : Interfaces.Unsigned_32;
   begin
      Asm ("rsil %0, 3",
           Outputs  => Interfaces.Unsigned_32'Asm_Output ("=a", Old),
           Volatile => True);
      return Old;
   end Int_Disable;

   procedure Int_Restore
     (Mux : System.Address; State : Interfaces.Unsigned_32)
     with Convention => C;
   procedure Int_Restore
     (Mux : System.Address; State : Interfaces.Unsigned_32)
   is
      pragma Unreferenced (Mux);
   begin
      Asm ("wsr.ps %0" & ASCII.LF & "rsync",
           Inputs   => Interfaces.Unsigned_32'Asm_Input ("a", State),
           Volatile => True);
   end Int_Restore;

   --  ------------------------------------------------------------------------
   --  read_mac: hand the blob the factory base (STA) MAC, via the shared HAL
   --  ESP32S3.MAC.  Only the STA/base MAC is needed for a scan.
   --  ------------------------------------------------------------------------
   function Read_Mac
     (Mac : System.Address; Mac_Type : Interfaces.Integer_32)
      return Interfaces.Integer_32 with Convention => C;
   function Read_Mac
     (Mac : System.Address; Mac_Type : Interfaces.Integer_32)
      return Interfaces.Integer_32
   is
      pragma Unreferenced (Mac_Type);   --  STA/base MAC (scan needs only this)
      Base : constant ESP32S3.MAC.MAC_Address := ESP32S3.MAC.Base;
      M    : array (0 .. 5) of Interfaces.Unsigned_8 with Import, Address => Mac;
   begin
      for I in 0 .. 5 loop
         M (I) := Base (I);
      end loop;
      return 0;
   end Read_Mac;

   --  ------------------------------------------------------------------------
   --  WMAC interrupt hookup -- integrated with GNARL (see ESP32S3.WiFi.Interrupt).
   --  set_intr routes the peripheral source to the CPU interrupt GNARL owns;
   --  set_isr records the blob's C handler (called from the Ada protected
   --  handler); ints_on is a no-op (attaching the handler already enabled the
   --  CPU interrupt).  The blob's own CPU-interrupt NUMBER is ignored -- we use
   --  our fixed Device_L2_1.  (clear_intr is a no-op, as in IDF.)
   --  ------------------------------------------------------------------------
   procedure Do_Set_Intr
     (Cpu, Source, Num, Prio : Interfaces.Integer_32) with Convention => C;
   procedure Do_Set_Intr
     (Cpu, Source, Num, Prio : Interfaces.Integer_32) is
      pragma Unreferenced (Cpu, Num, Prio);
   begin
      Interrupt.Route_Source (Source);
   end Do_Set_Intr;

   procedure Do_Set_Isr
     (N : Interfaces.Integer_32; F : System.Address; Arg : System.Address)
     with Convention => C;
   procedure Do_Set_Isr
     (N : Interfaces.Integer_32; F : System.Address; Arg : System.Address) is
      pragma Unreferenced (N);
   begin
      Interrupt.Set_Handler (F, Arg);
   end Do_Set_Isr;

   procedure Do_Ints_On (Mask : Interfaces.Unsigned_32) with Convention => C;
   procedure Do_Ints_On (Mask : Interfaces.Unsigned_32) is
      pragma Unreferenced (Mask);
   begin
      null;   --  GNARL enabled the CPU interrupt when the handler was attached
   end Do_Ints_On;

   --  wifi_reset_mac = periph_module_reset(PERIPH_WIFI_MODULE): pulse the
   --  WIFIMAC reset bit (SYSTEM_WIFIMAC_RST = BIT2) in SYSCON_WIFI_RST_EN_REG.
   Wifi_Rst_En_Reg : constant := 16#6002_6018#;
   Wifimac_Rst     : constant Interfaces.Unsigned_32 := 16#0000_0004#;

   procedure Wifi_Reset_Mac with Convention => C;
   procedure Wifi_Reset_Mac is
      use Interfaces;
      R : Unsigned_32 with Import, Volatile, Address => To_Address (Wifi_Rst_En_Reg);
   begin
      R := R or Wifimac_Rst;
      R := R and not Wifimac_Rst;
   end Wifi_Reset_Mac;

   --  ------------------------------------------------------------------------
   --  Named halt-stubs for the heavy slots (this wave): each prints its name.
   --  ------------------------------------------------------------------------
   procedure St_Wifi_Int_Disable   with Convention => C, No_Return;
   procedure St_Wifi_Int_Restore   with Convention => C, No_Return;
   procedure St_Task_Yield_Isr     with Convention => C;
   procedure St_Spin_Lock_Create   with Convention => C, No_Return;
   procedure St_Semphr_Create      with Convention => C, No_Return;
   procedure St_Semphr_Take        with Convention => C, No_Return;
   procedure St_Semphr_Give        with Convention => C, No_Return;
   procedure St_Thread_Semphr_Get  with Convention => C, No_Return;
   procedure St_Mutex_Create       with Convention => C, No_Return;
   procedure St_Recursive_Mutex    with Convention => C, No_Return;
   procedure St_Mutex_Lock         with Convention => C, No_Return;
   procedure St_Mutex_Unlock       with Convention => C, No_Return;
   procedure St_Queue_Create       with Convention => C, No_Return;
   procedure St_Queue_Send         with Convention => C, No_Return;
   procedure St_Queue_Recv         with Convention => C, No_Return;
   procedure St_Queue_Msg_Waiting  with Convention => C, No_Return;
   procedure St_Event_Group_Create with Convention => C, No_Return;
   procedure St_Event_Group_Wait   with Convention => C, No_Return;
   procedure St_Task_Create_Pinned with Convention => C, No_Return;
   procedure St_Task_Create        with Convention => C, No_Return;
   procedure St_Task_Delay         with Convention => C, No_Return;
   procedure St_Task_Get_Current   with Convention => C, No_Return;
   procedure St_Event_Post         with Convention => C, No_Return;
   procedure St_Phy_Enable         with Convention => C, No_Return;
   procedure St_Phy_Disable        with Convention => C, No_Return;
   procedure St_Read_Mac           with Convention => C, No_Return;
   procedure St_Timer_Arm          with Convention => C, No_Return;
   procedure St_Timer_Setfn        with Convention => C, No_Return;
   procedure St_Wifi_Reset_Mac     with Convention => C, No_Return;
   procedure St_Wifi_Clock_Enable  with Convention => C, No_Return;
   procedure St_Nvs_Open           with Convention => C, No_Return;
   procedure St_Wifi_Create_Queue  with Convention => C, No_Return;

   procedure St_Wifi_Int_Disable   is begin Halt ("wifi_int_disable");   end St_Wifi_Int_Disable;
   procedure St_Wifi_Int_Restore   is begin Halt ("wifi_int_restore");   end St_Wifi_Int_Restore;
   procedure St_Task_Yield_Isr     is null;   --  ISR context: no work, no I/O
   procedure St_Spin_Lock_Create   is begin Halt ("spin_lock_create");   end St_Spin_Lock_Create;
   procedure St_Semphr_Create      is begin Halt ("semphr_create");      end St_Semphr_Create;
   procedure St_Semphr_Take        is begin Halt ("semphr_take");        end St_Semphr_Take;
   procedure St_Semphr_Give        is begin Halt ("semphr_give");        end St_Semphr_Give;
   procedure St_Thread_Semphr_Get  is begin Halt ("wifi_thread_semphr_get"); end St_Thread_Semphr_Get;
   procedure St_Mutex_Create       is begin Halt ("mutex_create");       end St_Mutex_Create;
   procedure St_Recursive_Mutex    is begin Halt ("recursive_mutex_create"); end St_Recursive_Mutex;
   procedure St_Mutex_Lock         is begin Halt ("mutex_lock");         end St_Mutex_Lock;
   procedure St_Mutex_Unlock       is begin Halt ("mutex_unlock");       end St_Mutex_Unlock;
   procedure St_Queue_Create       is begin Halt ("queue_create");       end St_Queue_Create;
   procedure St_Queue_Send         is begin Halt ("queue_send");         end St_Queue_Send;
   procedure St_Queue_Recv         is begin Halt ("queue_recv");         end St_Queue_Recv;
   procedure St_Queue_Msg_Waiting  is begin Halt ("queue_msg_waiting");  end St_Queue_Msg_Waiting;
   procedure St_Event_Group_Create is begin Halt ("event_group_create"); end St_Event_Group_Create;
   procedure St_Event_Group_Wait   is begin Halt ("event_group_wait_bits"); end St_Event_Group_Wait;
   procedure St_Task_Create_Pinned is begin Halt ("task_create_pinned_to_core"); end St_Task_Create_Pinned;
   procedure St_Task_Create        is begin Halt ("task_create");        end St_Task_Create;
   procedure St_Task_Delay         is begin Halt ("task_delay");         end St_Task_Delay;
   procedure St_Task_Get_Current   is begin Halt ("task_get_current_task"); end St_Task_Get_Current;
   procedure St_Event_Post         is begin Halt ("event_post");         end St_Event_Post;
   procedure St_Phy_Enable         is begin Halt ("phy_enable");         end St_Phy_Enable;
   procedure St_Phy_Disable        is begin Halt ("phy_disable");        end St_Phy_Disable;
   procedure St_Read_Mac           is begin Halt ("read_mac");           end St_Read_Mac;
   procedure St_Timer_Arm          is begin Halt ("timer_arm");          end St_Timer_Arm;
   procedure St_Timer_Setfn        is begin Halt ("timer_setfn");        end St_Timer_Setfn;
   procedure St_Wifi_Reset_Mac     is begin Halt ("wifi_reset_mac");     end St_Wifi_Reset_Mac;
   procedure St_Wifi_Clock_Enable  is begin Halt ("wifi_clock_enable");  end St_Wifi_Clock_Enable;
   procedure St_Nvs_Open           is begin Halt ("nvs_open");           end St_Nvs_Open;
   procedure St_Wifi_Create_Queue  is begin Halt ("wifi_create_queue");  end St_Wifi_Create_Queue;

   --  ------------------------------------------------------------------------
   procedure Install is
      Stub : constant Slot := Stub_Silent'Address;
      Zero : constant Slot := Ret_Zero'Address;
      Void : constant Slot := Void_Noop'Address;
      MAlloc : constant Slot := C_Malloc'Address;
      MFree  : constant Slot := C_Free'Address;
      MCall  : constant Slot := C_Calloc'Address;
      MReal  : constant Slot := C_Realloc'Address;
      MZal   : constant Slot := Zalloc'Address;
   begin
      Table :=
        (Version => Adapter_Version,
         Magic   => Adapter_Magic,

         --  trivial reals
         Env_Is_Chip        => Env_Is_Chip'Address,
         Is_From_Isr        => Is_From_Isr'Address,
         Esp_Timer_Get_Time => Esp_Timer_Get_Time'Address,
         Rand               => Rand_Impl'Address,
         Random             => Rand_Impl'Address,
         Get_Free_Heap_Size => Get_Free_Heap_Size'Address,
         Task_Ms_To_Tick    => Ms_To_Tick'Address,
         Task_Get_Max_Priority => Task_Max_Prio'Address,
         Slowclk_Cal_Get    => Slowclk_Cal'Address,
         Log_Write          => Log_Noop'Address,
         Log_Writev         => Log_Noop'Address,
         Log_Timestamp      => Zero,
         Dport_Stall_Start  => Void,
         Dport_Stall_End    => Void,
         Wifi_Apb80m_Request => Void,
         Wifi_Apb80m_Release => Void,
         Wifi_Rtc_Enable_Iso  => Void,
         Wifi_Rtc_Disable_Iso => Void,
         Phy_Update_Country_Info => Zero,
         Get_Random         => Os_Get_Random'Address,   --  os_get_random(buf,len)
         Get_Time           => Zero,

         --  memory allocators -> DMA-capable DRAM heap
         Malloc             => MAlloc,
         Free               => MFree,
         Malloc_Internal    => MAlloc,
         Calloc_Internal    => MCall,
         Realloc_Internal   => MReal,
         Zalloc_Internal    => MZal,
         Wifi_Malloc        => MAlloc,
         Wifi_Realloc       => MReal,
         Wifi_Calloc        => MCall,
         Wifi_Zalloc        => MZal,
         Spin_Lock_Delete   => MFree,
         Mutex_Delete       => RTOS.Delete_Noop'Address,
         Semphr_Delete      => RTOS.Delete_Noop'Address,
         Queue_Delete       => RTOS.Delete_Noop'Address,
         Event_Group_Delete => MFree,
         Task_Delete        => MFree,
         Wifi_Delete_Queue  => MFree,
         Event_Group_Set_Bits   => Zero,
         Event_Group_Clear_Bits => Zero,

         --  Wi-Fi-only coexistence: always grant, never block
         Coex_Init                     => Zero,
         Coex_Enable                   => Zero,
         Coex_Status_Get               => Zero,
         Coex_Wifi_Request             => Zero,
         Coex_Wifi_Release             => Zero,
         Coex_Wifi_Channel_Set         => Zero,
         Coex_Event_Duration_Get       => Zero,
         Coex_Pti_Get                  => Zero,
         Coex_Schm_Interval_Set        => Zero,
         Coex_Schm_Interval_Get        => Zero,
         Coex_Schm_Curr_Period_Get     => Zero,
         Coex_Schm_Curr_Phase_Get      => Zero,
         Coex_Schm_Process_Restart     => Zero,
         Coex_Schm_Register_Cb         => Zero,
         Coex_Register_Start_Cb        => Zero,
         Coex_Schm_Flexible_Period_Set => Zero,
         Coex_Schm_Flexible_Period_Get => Zero,
         Coex_Schm_Get_Phase_By_Idx    => Zero,
         Coex_Deinit                   => Void,
         Coex_Disable                  => Void,
         Coex_Condition_Set            => Void,
         Coex_Schm_Status_Bit_Clear    => Void,
         Coex_Schm_Status_Bit_Set      => Void,

         --  heavy slots -> named halt-stubs (implemented in later waves)
         Set_Intr             => Do_Set_Intr'Address,
         Clear_Intr           => Void,
         Set_Isr              => Do_Set_Isr'Address,
         Ints_On              => Do_Ints_On'Address,
         Ints_Off             => Void_Noop'Address,
         Wifi_Int_Disable     => Int_Disable'Address,
         Wifi_Int_Restore     => Int_Restore'Address,
         Task_Yield_From_Isr  => St_Task_Yield_Isr'Address,
         Spin_Lock_Create     => Spin_Create'Address,
         Semphr_Create        => RTOS.Semphr_Create'Address,
         Semphr_Take          => RTOS.Semphr_Take'Address,
         Semphr_Give          => RTOS.Semphr_Give'Address,
         Wifi_Thread_Semphr_Get => RTOS.Thread_Semphr_Get'Address,
         Mutex_Create         => RTOS.Mutex_Create'Address,
         Recursive_Mutex_Create => RTOS.Recursive_Mutex_Create'Address,
         Mutex_Lock           => RTOS.Mutex_Lock'Address,
         Mutex_Unlock         => RTOS.Mutex_Unlock'Address,
         Queue_Create         => RTOS.Queue_Create'Address,
         Queue_Send           => RTOS.Queue_Send'Address,
         Queue_Send_From_Isr  => RTOS.Queue_Send_From_Isr'Address,
         Queue_Send_To_Back   => RTOS.Queue_Send'Address,
         Queue_Send_To_Front  => RTOS.Queue_Send'Address,
         Queue_Recv           => RTOS.Queue_Recv'Address,
         Queue_Msg_Waiting    => RTOS.Queue_Msg_Waiting'Address,
         Event_Group_Create   => St_Event_Group_Create'Address,
         Event_Group_Wait_Bits => St_Event_Group_Wait'Address,
         Task_Create_Pinned   => RTOS.Task_Create_Pinned'Address,
         Task_Create          => RTOS.Task_Create'Address,
         Task_Delay           => RTOS.Task_Delay'Address,
         Task_Get_Current_Task => RTOS.Get_Current_Task'Address,
         Event_Post           => Event_Post'Address,

         Phy_Enable           => PHY.Phy_Enable'Address,
         Phy_Disable          => PHY.Phy_Disable'Address,
         Read_Mac             => Read_Mac'Address,
         Timer_Arm            => RTOS.Timer_Arm'Address,
         Timer_Arm_Us         => RTOS.Timer_Arm_Us'Address,
         Timer_Disarm         => RTOS.Timer_Disarm'Address,
         Timer_Done           => RTOS.Timer_Done'Address,
         Timer_Setfn          => RTOS.Timer_Setfn'Address,
         Wifi_Reset_Mac       => Wifi_Reset_Mac'Address,
         --  On esp32s3 wifi_module_enable's register mask is 0 (WiFi clocks are
         --  already on at boot), so clock enable/disable are effectively no-ops.
         Wifi_Clock_Enable    => Void,
         Wifi_Clock_Disable   => Void,
         Nvs_Open             => St_Nvs_Open'Address,
         Wifi_Create_Queue    => RTOS.Wifi_Create_Queue'Address,

         --  anything not named above
         others => Stub);
   end Install;

end ESP32S3.WiFi.OS_Adapter;
