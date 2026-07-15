--  Exact Ada mirror of Espressif's Wi-Fi OS adapter table (wifi_osi_funcs_t)
--  for esp32s3, pinned to ESP-IDF v5.4.4 (ADAPTER version 8, magic 0xDEADBEAF).
--
--  The blob (libcore/libpp/libnet80211) indexes this table by field OFFSET, so
--  the ORDER and COUNT below must match the C struct exactly.  Each entry is a
--  function-pointer slot -- one machine word -- so we bind them as System.Address
--  and populate each with 'Address of a correctly-typed Ada implementation (see
--  the body); unimplemented slots point at a safe abort stub.  The esp32s3
--  build excludes _phy_common_clock_* and the C6/C5 regdma fields and includes
--  _slowclk_cal_get (per the #if guards in wifi_os_adapter.h).
--
--  Source: $IDF/components/esp_wifi/include/esp_private/wifi_os_adapter.h
with Interfaces;
with System;

package ESP32S3.WiFi.OS_Adapter is

   Adapter_Version : constant Interfaces.Unsigned_32 := 16#0000_0008#;
   Adapter_Magic   : constant Interfaces.Unsigned_32 := 16#DEAD_BEAF#;

   subtype Slot is System.Address;   --  a C function-pointer slot (one word)

   --  Field order is verbatim from wifi_osi_funcs_t (esp32s3, v5.4.4).
   type Osi_Funcs is record
      Version : Interfaces.Unsigned_32;

      Env_Is_Chip              : Slot;
      Set_Intr                 : Slot;
      Clear_Intr               : Slot;
      Set_Isr                  : Slot;
      Ints_On                  : Slot;
      Ints_Off                 : Slot;
      Is_From_Isr              : Slot;
      Spin_Lock_Create         : Slot;
      Spin_Lock_Delete         : Slot;
      Wifi_Int_Disable         : Slot;
      Wifi_Int_Restore         : Slot;
      Task_Yield_From_Isr      : Slot;
      Semphr_Create            : Slot;
      Semphr_Delete            : Slot;
      Semphr_Take              : Slot;
      Semphr_Give              : Slot;
      Wifi_Thread_Semphr_Get   : Slot;
      Mutex_Create             : Slot;
      Recursive_Mutex_Create   : Slot;
      Mutex_Delete             : Slot;
      Mutex_Lock               : Slot;
      Mutex_Unlock             : Slot;
      Queue_Create             : Slot;
      Queue_Delete             : Slot;
      Queue_Send               : Slot;
      Queue_Send_From_Isr      : Slot;
      Queue_Send_To_Back       : Slot;
      Queue_Send_To_Front      : Slot;
      Queue_Recv               : Slot;
      Queue_Msg_Waiting        : Slot;
      Event_Group_Create       : Slot;
      Event_Group_Delete       : Slot;
      Event_Group_Set_Bits     : Slot;
      Event_Group_Clear_Bits   : Slot;
      Event_Group_Wait_Bits    : Slot;
      Task_Create_Pinned       : Slot;   --  _task_create_pinned_to_core
      Task_Create              : Slot;
      Task_Delete              : Slot;
      Task_Delay               : Slot;
      Task_Ms_To_Tick          : Slot;
      Task_Get_Current_Task    : Slot;
      Task_Get_Max_Priority    : Slot;
      Malloc                   : Slot;
      Free                     : Slot;
      Event_Post               : Slot;
      Get_Free_Heap_Size       : Slot;
      Rand                     : Slot;
      Dport_Stall_Start        : Slot;   --  _dport_access_stall_other_cpu_start_wrap
      Dport_Stall_End          : Slot;   --  _dport_access_stall_other_cpu_end_wrap
      Wifi_Apb80m_Request      : Slot;
      Wifi_Apb80m_Release      : Slot;
      Phy_Disable              : Slot;
      Phy_Enable               : Slot;
      --  (esp32s3 omits _phy_common_clock_enable/_disable)
      Phy_Update_Country_Info  : Slot;
      Read_Mac                 : Slot;
      Timer_Arm                : Slot;
      Timer_Disarm             : Slot;
      Timer_Done               : Slot;
      Timer_Setfn              : Slot;
      Timer_Arm_Us             : Slot;
      Wifi_Reset_Mac           : Slot;
      Wifi_Clock_Enable        : Slot;
      Wifi_Clock_Disable       : Slot;
      Wifi_Rtc_Enable_Iso      : Slot;
      Wifi_Rtc_Disable_Iso     : Slot;
      Esp_Timer_Get_Time       : Slot;
      Nvs_Set_I8               : Slot;
      Nvs_Get_I8               : Slot;
      Nvs_Set_U8               : Slot;
      Nvs_Get_U8               : Slot;
      Nvs_Set_U16              : Slot;
      Nvs_Get_U16              : Slot;
      Nvs_Open                 : Slot;
      Nvs_Close                : Slot;
      Nvs_Commit               : Slot;
      Nvs_Set_Blob             : Slot;
      Nvs_Get_Blob             : Slot;
      Nvs_Erase_Key            : Slot;
      Get_Random               : Slot;
      Get_Time                 : Slot;
      Random                   : Slot;
      Slowclk_Cal_Get          : Slot;   --  esp32s3 includes this
      Log_Write                : Slot;
      Log_Writev               : Slot;
      Log_Timestamp            : Slot;
      Malloc_Internal          : Slot;
      Realloc_Internal         : Slot;
      Calloc_Internal          : Slot;
      Zalloc_Internal          : Slot;
      Wifi_Malloc              : Slot;
      Wifi_Realloc             : Slot;
      Wifi_Calloc              : Slot;
      Wifi_Zalloc              : Slot;
      Wifi_Create_Queue        : Slot;
      Wifi_Delete_Queue        : Slot;
      Coex_Init                : Slot;
      Coex_Deinit              : Slot;
      Coex_Enable              : Slot;
      Coex_Disable             : Slot;
      Coex_Status_Get          : Slot;
      Coex_Condition_Set       : Slot;
      Coex_Wifi_Request        : Slot;
      Coex_Wifi_Release        : Slot;
      Coex_Wifi_Channel_Set    : Slot;
      Coex_Event_Duration_Get  : Slot;
      Coex_Pti_Get             : Slot;
      Coex_Schm_Status_Bit_Clear : Slot;
      Coex_Schm_Status_Bit_Set   : Slot;
      Coex_Schm_Interval_Set     : Slot;
      Coex_Schm_Interval_Get     : Slot;
      Coex_Schm_Curr_Period_Get  : Slot;
      Coex_Schm_Curr_Phase_Get   : Slot;
      Coex_Schm_Process_Restart  : Slot;
      Coex_Schm_Register_Cb      : Slot;
      Coex_Register_Start_Cb     : Slot;
      --  (esp32s3 omits the C6/C5 regdma slots)
      Coex_Schm_Flexible_Period_Set : Slot;
      Coex_Schm_Flexible_Period_Get : Slot;
      Coex_Schm_Get_Phase_By_Idx    : Slot;

      Magic : Interfaces.Unsigned_32;
   end record
     with Convention => C;

   --  The table instance the blob calls through (its address goes into the
   --  wifi_init_config_t).  Populated by Install.
   Table : aliased Osi_Funcs;

   --  Fill Table: version/magic, the implemented slots, and every remaining
   --  slot pointed at a safe stub.  Call once before esp_wifi_init.
   procedure Install;

end ESP32S3.WiFi.OS_Adapter;
