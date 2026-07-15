--  Body for the ESP32S3.WiFi public API: Initialize (M0 -- OS adapter / PHY /
--  clock bring-up), Scan (M1), and Connect / Connected (M2, WPA2 via the pure-
--  Ada ESP32S3.WiFi.Supplicant), all against the esp_wifi bindings in
--  ESP32S3.WiFi.IDF.  See BRINGUP.md.
with Interfaces;
use type Interfaces.Integer_32, Interfaces.Unsigned_8;
with System;
with ESP32S3.WiFi.IDF;
with ESP32S3.WiFi.OS_Adapter;
with ESP32S3.WiFi.RTOS;
with ESP32S3.WiFi.Port;
with ESP32S3.WiFi.Supplicant;
with ESP32S3.WiFi.PHY;
with ESP32S3.WiFi.Core_Shim;   --  provides the retired libcore.a symbols
pragma Unreferenced (ESP32S3.WiFi.Core_Shim);

package body ESP32S3.WiFi is

   Initialized : Boolean := False;   --  set True by Initialize once M0 works

   function To_Auth (M : Interfaces.Unsigned_32) return Auth_Mode is
     (case M is
        when IDF.AUTH_OPEN          => Open,
        when IDF.AUTH_WEP           => WEP,
        when IDF.AUTH_WPA_PSK       => WPA_PSK,
        when IDF.AUTH_WPA2_PSK      => WPA2_PSK,
        when IDF.AUTH_WPA_WPA2_PSK  => WPA_WPA2_PSK,
        when IDF.AUTH_ENTERPRISE    => WPA2_Enterprise,
        when IDF.AUTH_WPA3_PSK      => WPA3_PSK,
        when IDF.AUTH_WPA2_WPA3_PSK => WPA2_WPA3_PSK,
        when others                 => Other);

   function To_AP (R : IDF.C_AP_Record) return AP_Record is
      A : AP_Record;
      L : Natural := 0;
   begin
      --  SSID is a NUL-terminated uint8[33]; copy up to Max_SSID printable bytes.
      for I in R.SSID'Range loop
         exit when R.SSID (I) = 0 or else L = Max_SSID;
         L := L + 1;
         A.SSID (L) := Character'Val (R.SSID (I));
      end loop;
      A.SSID_Len := L;
      for I in A.BSSID'Range loop
         A.BSSID (I) := R.BSSID (I - 1);   --  BSSID is 1 .. 6, C is 0 .. 5
      end loop;
      A.Channel := Natural (R.Primary);
      A.RSSI    := Integer (R.RSSI);
      A.Auth    := To_Auth (R.Authmode);
      return A;
   end To_AP;

   procedure Initialize (Result : out Status) is
      Cfg : aliased IDF.Wifi_Init_Config;
      Rc  : IDF.Esp_Err;
   begin
      --  M0 bring-up in progress: the OS adapter is implemented incrementally;
      --  the debug traces below name the exact esp_err from each blob call so a
      --  hardware run drives the next step.  See BRINGUP.md.
      RTOS.Install_Exc_Handler;   --  catch faults on the env core
      OS_Adapter.Install;
      Cfg := IDF.Default_Config (OS_Adapter.Table'Address);

      Rc := IDF.Esp_Wifi_Init (Cfg'Address);
      if Rc /= IDF.ESP_OK then
         Result := Radio_Error;
         return;
      end if;

      --  Register the (stub) WPA callback the RX path needs -- esp_supplicant_
      --  init would normally do this; we skipped it.  Without it g_ic+0x1b4 is
      --  null and the WMAC ISR faults dereferencing wpa_sta_rx_mgmt.
      Port.Register_Wpa_Stub;

      Rc := IDF.Esp_Wifi_Set_Mode (IDF.WIFI_MODE_STA);
      if Rc /= IDF.ESP_OK then
         Result := Radio_Error;
         return;
      end if;

      Rc := IDF.Esp_Wifi_Start;
      if Rc /= IDF.ESP_OK then
         Result := Radio_Error;
         return;
      end if;

      Initialized := True;
      Result := OK;
   end Initialize;

   --  The registered software-stack sink for received 802.3 frames (null until
   --  a stack registers one via Set_Frame_Handler).
   Frame_Sink : Frame_Handler := null;

   procedure Set_Frame_Handler (Handler : Frame_Handler) is
   begin
      Frame_Sink := Handler;
   end Set_Frame_Handler;

   procedure Set_Cal_Store (Load : Cal_Load_Hook; Store : Cal_Store_Hook) is
   begin
      PHY.Set_Cal_Store (Load, Store);
   end Set_Cal_Store;

   --  Count of RX-callback firings (diagnostic).
   Rx_Cb_Calls : Natural := 0;
   function Rx_Callback_Count return Natural is (Rx_Cb_Calls);

   function Handshake_Txdone_Count return Natural is
     (Supplicant.Diag_Txdone_Count);
   function Handshake_Ptk_Rc return Interfaces.Integer_32 is
     (Supplicant.Diag_Ptk_Rc);
   function Handshake_Port_State return Interfaces.Integer_32 is
     (Supplicant.Diag_Port_State);
   function Handshake_Gtk_Found return Boolean is (Supplicant.Diag_Gtk_Found);
   function Handshake_Gtk_Rc return Interfaces.Integer_32 is
     (Supplicant.Diag_Gtk_Rc);

   function Send_Frame (Data : System.Address; Len : Natural) return Boolean is
      use type Interfaces.Integer_32;
   begin
      return IDF.Esp_Wifi_Internal_Tx
               (IDF.WIFI_IF_STA, Data, Interfaces.Unsigned_16 (Len)) = IDF.ESP_OK;
   end Send_Frame;

   --  802.3 RX callback (Wi-Fi task context): hand the frame to the stack sink
   --  -- which must copy it out during the call -- then free the blob's buffer.
   function Rx_Cb (Buffer : System.Address; Len : Interfaces.Unsigned_16;
                   Eb : System.Address) return IDF.Esp_Err
     with Convention => C;
   function Rx_Cb (Buffer : System.Address; Len : Interfaces.Unsigned_16;
                   Eb : System.Address) return IDF.Esp_Err
   is
      use type System.Address;
   begin
      Rx_Cb_Calls := Rx_Cb_Calls + 1;
      if Frame_Sink /= null then
         Frame_Sink (Buffer, Natural (Len));
      end if;
      if Eb /= System.Null_Address then
         IDF.Esp_Wifi_Internal_Free_Rx_Buffer (Eb);
      end if;
      return IDF.ESP_OK;
   end Rx_Cb;

   Reg_Rxcb_Rc : Interfaces.Integer_32 := 16#7FFF#;
   function Rx_Reg_Rc return Interfaces.Integer_32 is (Reg_Rxcb_Rc);
   function Isr_Posts return Natural is (RTOS.Isr_Post_Count);

   procedure Start_Data_Path is
   begin
      Reg_Rxcb_Rc :=
        IDF.Esp_Wifi_Internal_Reg_Rxcb (IDF.WIFI_IF_STA, Rx_Cb'Address);
   end Start_Data_Path;

   procedure Connect
     (SSID       : String;
      Passphrase : String := "";
      BSSID      : MAC_Address := (others => 0);
      Result     : out Status)
   is
      use type Interfaces.Unsigned_8;
      Config : array (1 .. IDF.Config_Size) of Interfaces.Unsigned_8 :=
                 (others => 0);
      SL : constant Natural := Natural'Min (SSID'Length, 32);
      PL : constant Natural := Natural'Min (Passphrase'Length, 64);
      Pin : constant Boolean :=
        (for some B of BSSID => B /= 0);   --  non-zero BSSID => pin to it
      Rc : IDF.Esp_Err;
   begin
      if not Initialized then
         Result := Not_Initialized;
         return;
      end if;

      --  Hand the credentials to the WPA2 supplicant (it derives the PMK once
      --  the blob calls wpa_sta_connect with the AP MAC).
      Supplicant.Set_Credentials (SSID, Passphrase);

      --  wifi_sta_config_t: ssid[32] @0, password[64] @32.  The password is
      --  REQUIRED here: the blob's connect-time security check compares the
      --  config's security against the AP's beacon and aborts with reason 210
      --  (NO_AP_FOUND_W_COMPATIBLE_SECURITY) if a WPA2 AP is matched by an
      --  open config.  The RSN IE for the assoc still comes from our appie
      --  (published from Sta_Connect, right before the assoc is built).
      for I in 1 .. SL loop
         Config (I) := Character'Pos (SSID (SSID'First + I - 1));
      end loop;
      for I in 1 .. PL loop
         Config (32 + I) := Character'Pos (Passphrase (Passphrase'First + I - 1));
      end loop;

      --  wifi_sta_config_t: bssid_set @100, bssid[6] @101 (offsets probed on
      --  target).  Pin the AP when a BSSID was given.
      if Pin then
         Config (101) := 1;                       --  bssid_set = true
         for I in 1 .. 6 loop
            Config (101 + I) := BSSID (I);         --  bssid[0..5] @101..106
         end loop;
      end if;

      Rc := IDF.Esp_Wifi_Set_Config (IDF.WIFI_IF_STA, Config'Address);
      if Rc /= IDF.ESP_OK then
         Result := Radio_Error;
         return;
      end if;

      --  Open the 802.3 RX path (so EAPOL and data frames flow up).
      Rc := IDF.Esp_Wifi_Internal_Reg_Rxcb (IDF.WIFI_IF_STA, Rx_Cb'Address);

      --  The RSN IE is now published inline from Supplicant.Sta_Connect (the
      --  wifi task, right before the assoc) -- the OS-adapter task-identity fix
      --  makes set_appie safe there, matching the real wpa_sta_connect order.

      Rc := IDF.Esp_Wifi_Connect;   --  starts association; completes async
      Result := (if Rc = IDF.ESP_OK then OK else Radio_Error);
   end Connect;

   function Connected return Boolean is
      Rec : IDF.C_AP_Record;
   begin
      return Initialized
        and then IDF.Esp_Wifi_Sta_Get_Ap_Info (Rec'Address) = IDF.ESP_OK;
   end Connected;

   function Current_Channel return Natural is
      Rec : IDF.C_AP_Record;
   begin
      if Initialized
        and then IDF.Esp_Wifi_Sta_Get_Ap_Info (Rec'Address) = IDF.ESP_OK
      then
         return Natural (Rec.Primary);
      else
         return 0;
      end if;
   end Current_Channel;

   function Current_BSSID return MAC_Address is
      Rec : IDF.C_AP_Record;
      Out_M : MAC_Address := (others => 0);
   begin
      if Initialized
        and then IDF.Esp_Wifi_Sta_Get_Ap_Info (Rec'Address) = IDF.ESP_OK
      then
         for I in 1 .. 6 loop
            Out_M (I) := Rec.BSSID (I - 1);
         end loop;
      end if;
      return Out_M;
   end Current_BSSID;

   procedure Scan
     (Found : out AP_List; Count : out Natural; Result : out Status)
   is
      Cap : constant Positive := Positive'Max (1, Found'Length);
      Num : aliased Interfaces.Unsigned_16;
      Buf : IDF.C_AP_Array (1 .. Cap);
   begin
      Found := [others => (others => <>)];
      Count := 0;

      if not Initialized then
         Result := Not_Initialized;
         return;
      end if;

      --  Default all-channel scan, blocking until it completes.
      --  NOTE (bring-up): esp_wifi_scan_start faults once the WMAC RX interrupt
      --  starts delivering frames -- the blob's RX ISR is not yet safe in the
      --  bare Xtensa runtime (interrupt stack / non-ISR-safe callback).  See
      --  BRINGUP.md.  Without the interrupt, this completed with 0 APs.
      if IDF.Esp_Wifi_Scan_Start (System.Null_Address, 1) /= IDF.ESP_OK then
         Result := Radio_Error;
         return;
      end if;

      --  Ask for at most Found'Length records; Num returns how many were copied.
      Num := Interfaces.Unsigned_16 (Cap);
      if IDF.Esp_Wifi_Scan_Get_Ap_Records (Num'Access, Buf'Address) /= IDF.ESP_OK
      then
         Result := Radio_Error;
         return;
      end if;

      Count := Natural'Min (Natural (Num), Found'Length);
      for I in 1 .. Count loop
         Found (Found'First + I - 1) := To_AP (Buf (I));
      end loop;
      Result := OK;
   end Scan;

end ESP32S3.WiFi;
