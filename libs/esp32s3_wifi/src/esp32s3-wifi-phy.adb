with Interfaces;               use Interfaces;
with System;
with System.Storage_Elements;  use System.Storage_Elements;
with System.Machine_Code;      use System.Machine_Code;
with ESP32S3.Log;
with ESP32S3.MAC;

package body ESP32S3.WiFi.PHY is

   use type System.Address;

   --  Default esp32s3 PHY init data (esp_phy_init_data_t.params[128]), the exact
   --  bytes IDF's phy_init_data.c produces at the default max TX power (20 dBm).
   Phy_Init_Data : constant array (0 .. 127) of Unsigned_8 :=
     (16#00#, 16#00#, 16#50#, 16#50#, 16#50#, 16#4C#, 16#4C#, 16#48#,
      16#4C#, 16#48#, 16#48#, 16#44#, 16#4A#, 16#46#, 16#46#, 16#42#,
      16#00#, 16#00#, 16#00#, 16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#,
      16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#,
      16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#,
      16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#,
      16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#,
      16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#,
      16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#00#, 16#00#,
      16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#,
      16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#,
      16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#,
      16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#,
      16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#74#,
      16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#,
      16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#);

   --  esp_phy_calibration_data_t = version[4] + mac[6] + opaque[1894] = 1904 B.
   Cal_Size           : constant := 1904;
   Mac_Offset         : constant := 4;     --  .mac starts after version[4]
   PHY_RF_CAL_PARTIAL : constant Interfaces.Integer_32 := 0;
   PHY_RF_CAL_FULL    : constant Interfaces.Integer_32 := 2;

   --  RF-calibration persistence hooks (see ESP32S3.WiFi.Set_Cal_Store).
   Load_Hook  : Cal_Load_Hook  := null;
   Store_Hook : Cal_Store_Hook := null;

   procedure Set_Cal_Store (Load : Cal_Load_Hook; Store : Cal_Store_Hook) is
   begin
      Load_Hook  := Load;
      Store_Hook := Store;
   end Set_Cal_Store;

   --  A stored blob is trustworthy only if its embedded MAC is THIS chip's (an
   --  image copied to another board must recalibrate).  The version[4] + opaque
   --  data are produced by this same PHY lib, so the MAC check suffices here.
   function Blob_Matches_Chip (Blob : Cal_Blob) return Boolean is
      Base : constant ESP32S3.MAC.MAC_Address := ESP32S3.MAC.Base;
   begin
      for I in 0 .. 5 loop
         if Blob (Mac_Offset + I) /= Base (I) then
            return False;
         end if;
      end loop;
      return True;
   end Blob_Matches_Chip;

   --  Clock enables in SYSCON_WIFI_CLK_EN_REG (esp_phy_common_clock_enable +
   --  phy_module_enable): WIFI_BT_COMMON (0x78078F, already includes PHY_EN bit
   --  22 0x400000) plus the RNG clock (BIT15 0x8000) that phy_module_enable adds
   --  before RF calibration.
   Wifi_Clk_En_Reg : constant := 16#6002_6014#;
   --  0x78078F = WIFI_BT_COMMON (incl PHY_EN bit22), 0x8000 = RNG; also OR the
   --  full SYSTEM_WIFI_CLK_EN composite (0xFB9FCF) so the MAC/BB clocks are on.
   Phy_Clk_Mask    : constant Unsigned_32 :=
     16#0078_078F# or 16#0000_8000# or 16#00FB_9FCF#;

   function Register_Chipv7_Phy
     (Init, Cal : System.Address; Mode : Interfaces.Integer_32)
      return Interfaces.Integer_32
     with Import, Convention => C, External_Name => "register_chipv7_phy";

   procedure Phy_Wakeup_Init
     with Import, Convention => C, External_Name => "phy_wakeup_init";

   function C_Calloc (N, Sz : Unsigned_32) return System.Address
     with Import, Convention => C, External_Name => "calloc";
   procedure C_Free (P : System.Address)
     with Import, Convention => C, External_Name => "free";

   Calibrated : Boolean := False;

   --  ---- libphy de-blob: first transpiled function (proof of method) --------
   --  force_txrx_off(en): a self-contained libphy primitive -- a read-modify-
   --  write of the TX/RX force register 0x60006110 (bits 9/11) with 1 us settling
   --  gaps, no i2c / g_phyFuns / ROM.  Faithful Ada port of the disassembly,
   --  wired in by linker --wrap so the blob's version never runs.  A wrong TX/RX
   --  force sequence disrupts the radio, so "still associates + fetches" proves
   --  the port.  See research/wifi-re/PHY_BOUNDARY.md.
   procedure Ets_Delay_Us (Us : Interfaces.Unsigned_32)
     with Import, Convention => C, External_Name => "ets_delay_us";

   Force_Txrx_Count : Interfaces.Unsigned_32 := 0
     with Export, Convention => C, External_Name => "ada_force_txrx_count";

   procedure Wrap_Force_Txrx_Off (En : Interfaces.Unsigned_32)
     with Export, Convention => C, External_Name => "__wrap_force_txrx_off";
   procedure Wrap_Force_Txrx_Off (En : Interfaces.Unsigned_32) is
      use type Interfaces.Unsigned_32;
      Reg  : Interfaces.Unsigned_32 with Import, Volatile,
        Address => System'To_Address (16#6000_6110#);
      Mask : constant Interfaces.Unsigned_32 := 16#FFFF_F0FF#;  --  clear bits 8..11
      Final : Interfaces.Unsigned_32;
   begin
      Force_Txrx_Count := Force_Txrx_Count + 1;
      if (En and 16#FF#) /= 0 then
         --  Force TX/RX off: set bit 11, settle, then set bits 9+11.
         Reg := (Reg and Mask) or 16#0000_0800#;
         Ets_Delay_Us (1);
         Final := (Reg and Mask) or 16#0000_0A00#;
      else
         --  Release: set bit 9, settle, then clear bits 8..11.
         Reg := (Reg and Mask) or 16#0000_0200#;
         Ets_Delay_Us (1);
         Final := Reg and Mask;
      end if;
      Reg := Final;
      Ets_Delay_Us (1);
   end Wrap_Force_Txrx_Off;

   --  Batch 2: three more self-contained baseband/SYSCON RMW primitives (0x6001c
   --  low-rate mode, 0x60026 wifi-enable).  Same faithful-port pattern.
   Ports2_Count : Interfaces.Unsigned_32 := 0
     with Export, Convention => C, External_Name => "ada_phy_ports2_count";

   procedure Poke (Addr, Val : Interfaces.Unsigned_32) is
      Cell : Interfaces.Unsigned_32 with Import, Volatile,
        Address => System'To_Address (Addr);
   begin
      Cell := Val;
   end Poke;
   function Peek (Addr : Interfaces.Unsigned_32) return Interfaces.Unsigned_32 is
      Cell : Interfaces.Unsigned_32 with Import, Volatile,
        Address => System'To_Address (Addr);
   begin
      return Cell;
   end Peek;

   procedure Wrap_Disable_Low_Rate
     with Export, Convention => C, External_Name => "__wrap_phy_disable_low_rate";
   procedure Wrap_Disable_Low_Rate is
      use type Interfaces.Unsigned_32;
   begin
      Ports2_Count := Ports2_Count + 1;
      Poke (16#6001_C860#, Peek (16#6001_C860#) and 16#FFFF_FBFF#);  --  clr bit10
      Poke (16#6001_C860#, Peek (16#6001_C860#) and 16#FFFF_F7FF#);  --  clr bit11
      Poke (16#6001_C87C#, Peek (16#6001_C87C#) and 16#FFFF_F7FF#);  --  clr bit11
   end Wrap_Disable_Low_Rate;

   procedure Wrap_Enable_Low_Rate
     with Export, Convention => C, External_Name => "__wrap_phy_enable_low_rate";
   procedure Wrap_Enable_Low_Rate is
      use type Interfaces.Unsigned_32;
   begin
      Ports2_Count := Ports2_Count + 1;
      Poke (16#6001_C860#, Peek (16#6001_C860#) or 16#0000_0400#);   --  set bit10
      Poke (16#6001_C860#, Peek (16#6001_C860#) or 16#0000_0800#);   --  set bit11
      Poke (16#6001_C87C#, Peek (16#6001_C87C#) or 16#0000_0800#);   --  set bit11
   end Wrap_Enable_Low_Rate;

   procedure Wrap_Wifi_Enable_Set (En : Interfaces.Unsigned_32)
     with Export, Convention => C, External_Name => "__wrap_phy_wifi_enable_set";
   procedure Wrap_Wifi_Enable_Set (En : Interfaces.Unsigned_32) is
      use type Interfaces.Unsigned_32;
      V : constant Interfaces.Unsigned_32 := Peek (16#6002_600C#);
   begin
      Ports2_Count := Ports2_Count + 1;
      if (En and 16#FF#) /= 0 then
         Poke (16#6002_600C#, V or 16#0000_0002#);   --  set bit1
      else
         Poke (16#6002_600C#, V and 16#FFFF_FFFD#);  --  clear bit1
      end if;
   end Wrap_Wifi_Enable_Set;

   --  Batch 3: five more self-contained 0x6001c (baseband) RMW primitives --
   --  antenna default, WiFi AGC enable/disable, TX scrambler seed, RIFS mode.
   Ports3_Count : Interfaces.Unsigned_32 := 0
     with Export, Convention => C, External_Name => "ada_phy_ports3_count";

   procedure Wrap_Ant_Dft_Cfg (En : Interfaces.Unsigned_32)
     with Export, Convention => C, External_Name => "__wrap_ant_dft_cfg";
   procedure Wrap_Ant_Dft_Cfg (En : Interfaces.Unsigned_32) is
      use type Interfaces.Unsigned_32;
   begin
      Ports3_Count := Ports3_Count + 1;
      Poke (16#6001_C11C#,
            (Peek (16#6001_C11C#) and 16#FFFF_F7FF#)
            or Shift_Left (En and 1, 11));                --  bit11 = En
   end Wrap_Ant_Dft_Cfg;

   procedure Wrap_Enable_Wifi_Agc
     with Export, Convention => C, External_Name => "__wrap_ram_enable_wifi_agc";
   procedure Wrap_Enable_Wifi_Agc is
      use type Interfaces.Unsigned_32;
   begin
      Ports3_Count := Ports3_Count + 1;
      Poke (16#6001_C080#, Peek (16#6001_C080#) and 16#FFFF_FFFE#);
      Poke (16#6001_C01C#,
            (Peek (16#6001_C01C#) and 16#FF00_FFFF#) or 16#0020_0000#);
      Poke (16#6001_C034#, Peek (16#6001_C034#) or 16#0000_0080#);
   end Wrap_Enable_Wifi_Agc;

   procedure Wrap_Disable_Wifi_Agc
     with Export, Convention => C, External_Name => "__wrap_ram_disable_wifi_agc";
   procedure Wrap_Disable_Wifi_Agc is
      use type Interfaces.Unsigned_32;
   begin
      Ports3_Count := Ports3_Count + 1;
      Poke (16#6001_C01C#,
            (Peek (16#6001_C01C#) and 16#FF00_FFFF#) or 16#007F_0000#);
      Poke (16#6001_C034#, Peek (16#6001_C034#) or 16#0000_0080#);
      Poke (16#6001_C080#, Peek (16#6001_C080#) or 16#0000_0001#);
   end Wrap_Disable_Wifi_Agc;

   procedure Wrap_Set_Tx_Seed (Seed : Interfaces.Unsigned_32)
     with Export, Convention => C, External_Name => "__wrap_phy_set_tx_seed";
   procedure Wrap_Set_Tx_Seed (Seed : Interfaces.Unsigned_32) is
      use type Interfaces.Unsigned_32;
   begin
      Ports3_Count := Ports3_Count + 1;
      Poke (16#6001_C400#,
            (Peek (16#6001_C400#) and 16#FFFF_FF80#) or (Seed and 16#7F#));
   end Wrap_Set_Tx_Seed;

   procedure Wrap_Rifs_Mode_En (En : Interfaces.Unsigned_32)
     with Export, Convention => C, External_Name => "__wrap_wifi_rifs_mode_en";
   procedure Wrap_Rifs_Mode_En (En : Interfaces.Unsigned_32) is
      use type Interfaces.Unsigned_32;
   begin
      Ports3_Count := Ports3_Count + 1;
      Poke (16#6001_C0F4#,
            (Peek (16#6001_C0F4#) and 16#FFFF_FFFE#) or (En and 1));
   end Wrap_Rifs_Mode_En;

   --  Batch 4: baseband getters (noise floor, CCA) + more RMW writers (CCA-cnt,
   --  antenna TX, 11b-LR rx, tsens power).  Getters are read-only (cannot affect
   --  the radio); writers follow the same faithful-port pattern.
   Ports4_Count : Interfaces.Unsigned_32 := 0
     with Export, Convention => C, External_Name => "ada_phy_ports4_count";

   --  As Integer_32 (bit pattern) -- these return signed dBm-ish values.
   function Wrap_Get_Noise_Floor return Interfaces.Integer_32
     with Export, Convention => C, External_Name => "__wrap_phy_get_noise_floor";
   function Wrap_Get_Noise_Floor return Interfaces.Integer_32 is
      use type Interfaces.Unsigned_32;
   begin
      Ports4_Count := Ports4_Count + 1;
      return Interfaces.Integer_32 ((Peek (16#6001_C050#) and 16#3FF#)) - 16#400#;
   end Wrap_Get_Noise_Floor;

   function Wrap_Read_Hw_Noisefloor return Interfaces.Integer_32
     with Export, Convention => C, External_Name => "__wrap_read_hw_noisefloor";
   function Wrap_Read_Hw_Noisefloor return Interfaces.Integer_32 is
      use type Interfaces.Unsigned_32;
      V : constant Interfaces.Unsigned_32 :=
        (Peek (16#6001_C08C#) and 16#FFF#) - 16#1000#;   --  12-bit two's-complement
   begin
      Ports4_Count := Ports4_Count + 1;
      return Interfaces.Integer_32 (Shift_Right_Arithmetic (V, 2));
   end Wrap_Read_Hw_Noisefloor;

   function Wrap_Get_Cca return Interfaces.Unsigned_32
     with Export, Convention => C, External_Name => "__wrap_phy_get_cca";
   function Wrap_Get_Cca return Interfaces.Unsigned_32 is
      use type Interfaces.Unsigned_32;
   begin
      Ports4_Count := Ports4_Count + 1;
      return Peek (16#6001_C01C#) and 16#FF#;
   end Wrap_Get_Cca;

   function Wrap_Get_Fetx_Delay return Interfaces.Unsigned_32
     with Export, Convention => C, External_Name => "__wrap_phy_get_fetx_delay";
   function Wrap_Get_Fetx_Delay return Interfaces.Unsigned_32 is
      use type Interfaces.Unsigned_32;
   begin
      Ports4_Count := Ports4_Count + 1;
      if (Peek (16#6000_6070#) and 16#4000_0000#) /= 0 then   --  bit30 set -> 0
         return 0;
      end if;
      return Peek (16#6000_6090#) and 16#1FF#;
   end Wrap_Get_Fetx_Delay;

   --  phy_get_cca_cnt(uint32 *out): out[0]/out[1] = 27-bit counters, returns 5-bit field.
   function Wrap_Get_Cca_Cnt (Out_Ptr : System.Address) return Interfaces.Unsigned_32
     with Export, Convention => C, External_Name => "__wrap_phy_get_cca_cnt";
   function Wrap_Get_Cca_Cnt (Out_Ptr : System.Address) return Interfaces.Unsigned_32 is
      use type Interfaces.Unsigned_32;
      Outs : array (0 .. 1) of Interfaces.Unsigned_32
        with Import, Volatile, Address => Out_Ptr;
   begin
      Ports4_Count := Ports4_Count + 1;
      Outs (0) := Peek (16#6001_D05C#) and 16#7FF_FFFF#;
      Outs (1) := Peek (16#6001_D060#) and 16#7FF_FFFF#;
      return Shift_Right (Peek (16#6001_D05C#) and 16#800_0000#, 27);
   end Wrap_Get_Cca_Cnt;

   procedure Wrap_Set_Cca_Cnt (Val, Flag : Interfaces.Unsigned_32)
     with Export, Convention => C, External_Name => "__wrap_phy_set_cca_cnt";
   procedure Wrap_Set_Cca_Cnt (Val, Flag : Interfaces.Unsigned_32) is
      use type Interfaces.Unsigned_32;
   begin
      Ports4_Count := Ports4_Count + 1;
      Poke (16#6001_D058#,
            (Peek (16#6001_D058#) and 16#F800_0000#) or (Val and 16#7FF_FFFF#));
      if (Flag and 16#FF#) /= 0 then
         Poke (16#6001_D058#, Peek (16#6001_D058#) or 16#1800_0000#);
      end if;
   end Wrap_Set_Cca_Cnt;

   procedure Wrap_Ant_Wifitx_Cfg (A, B : Interfaces.Unsigned_32)
     with Export, Convention => C, External_Name => "__wrap_ant_wifitx_cfg";
   procedure Wrap_Ant_Wifitx_Cfg (A, B : Interfaces.Unsigned_32) is
      use type Interfaces.Unsigned_32;
   begin
      Ports4_Count := Ports4_Count + 1;
      Poke (16#6000_60B0#,
            (Peek (16#6000_60B0#) and 16#FFFF_00FF#) or Shift_Left (A and 16#FF#, 8));
      Poke (16#6000_60B0#,
            (Peek (16#6000_60B0#) and 16#FF00_FFFF#) or Shift_Left (B and 16#FF#, 16));
   end Wrap_Ant_Wifitx_Cfg;

   procedure Wrap_Ant_Bttx_Cfg (A, B : Interfaces.Unsigned_32)
     with Export, Convention => C, External_Name => "__wrap_ant_bttx_cfg";
   procedure Wrap_Ant_Bttx_Cfg (A, B : Interfaces.Unsigned_32) is
      use type Interfaces.Unsigned_32;
   begin
      Ports4_Count := Ports4_Count + 1;
      Poke (16#6000_60B4#,
            (Peek (16#6000_60B4#) and 16#00FF_FFFF#) or Shift_Left (A and 16#FF#, 24));
      Poke (16#6000_60B8#,
            (Peek (16#6000_60B8#) and 16#FFFF_FF00#) or (B and 16#FF#));
   end Wrap_Ant_Bttx_Cfg;

   procedure Wrap_Rx11blr_Cfg (En : Interfaces.Unsigned_32)
     with Export, Convention => C, External_Name => "__wrap_phy_rx11blr_cfg";
   procedure Wrap_Rx11blr_Cfg (En : Interfaces.Unsigned_32) is
      use type Interfaces.Unsigned_32;
      B10 : constant Interfaces.Unsigned_32 := Shift_Left (En, 10) and 16#400#;
      B11 : constant Interfaces.Unsigned_32 := Shift_Left (En, 11) and 16#800#;
   begin
      Ports4_Count := Ports4_Count + 1;
      Poke (16#6001_C860#, (Peek (16#6001_C860#) and 16#FFFF_FBFF#) or B10);
      Poke (16#6001_C860#, (Peek (16#6001_C860#) and 16#FFFF_F7FF#) or B11);
      Poke (16#6001_C87C#, (Peek (16#6001_C87C#) and 16#FFFF_F7FF#) or B11);
   end Wrap_Rx11blr_Cfg;

   procedure Wrap_Set_Tsens_Power (En : Interfaces.Unsigned_32)
     with Export, Convention => C, External_Name => "__wrap_phy_set_tsens_power";
   procedure Wrap_Set_Tsens_Power (En : Interfaces.Unsigned_32) is
      use type Interfaces.Unsigned_32;
      Bits : constant Interfaces.Unsigned_32 :=
        (if (En and 16#FF#) /= 0 then 16#C0_0000# else 0);
   begin
      Ports4_Count := Ports4_Count + 1;
      Poke (16#6000_8850#, (Peek (16#6000_8850#) and 16#FF3F_FFFF#) or Bits);
   end Wrap_Set_Tsens_Power;

   --  Batch 5: three more baseband writers -- AGC saturation gain, FFT-scale
   --  force, and the BB register init (a magic-constant write).
   Ports5_Count : Interfaces.Unsigned_32 := 0
     with Export, Convention => C, External_Name => "ada_phy_ports5_count";

   procedure Wrap_Agc_Sat_Gain (G : Interfaces.Unsigned_32)
     with Export, Convention => C, External_Name => "__wrap_rom_wifi_agc_sat_gain";
   procedure Wrap_Agc_Sat_Gain (G : Interfaces.Unsigned_32) is
   begin
      Ports5_Count := Ports5_Count + 1;
      Poke (16#6001_C064#, G);
      Poke (16#6001_C114#, G);
   end Wrap_Agc_Sat_Gain;

   procedure Wrap_Fft_Scale_Force (A, B : Interfaces.Unsigned_32)
     with Export, Convention => C, External_Name => "__wrap_phy_fft_scale_force";
   procedure Wrap_Fft_Scale_Force (A, B : Interfaces.Unsigned_32) is
      use type Interfaces.Unsigned_32;
   begin
      Ports5_Count := Ports5_Count + 1;
      --  bits 20..27 = B; then bit19 = A(bit0).
      Poke (16#6001_CC00#,
            (Peek (16#6001_CC00#) and 16#F00F_FFFF#) or Shift_Left (B and 16#FF#, 20));
      Poke (16#6001_CC00#, Peek (16#6001_CC00#) and 16#FFF7_FFFF#);
      Poke (16#6001_CC00#,
            (Peek (16#6001_CC00#) and 16#FFF7_FFFF#) or (Shift_Left (A, 19) and 16#8_0000#));
   end Wrap_Fft_Scale_Force;

   procedure Wrap_Bb_Reg_Init
     with Export, Convention => C, External_Name => "__wrap_ram_bb_reg_init";
   procedure Wrap_Bb_Reg_Init is
      use type Interfaces.Unsigned_32;
   begin
      Ports5_Count := Ports5_Count + 1;
      Poke (16#6001_CC48#, 16#1704_33AF#);
      Poke (16#6001_C400#, Peek (16#6001_C400#) or 16#0000_6000#);
   end Wrap_Bb_Reg_Init;

   --  ---- g_phyFuns resolver -------------------------------------------------
   --  Some ported functions are invoked by the PHY ROM through the g_phyFuns
   --  function-pointer table, which --wrap can't redirect (the table is filled
   --  by ROM at init).  After register_chipv7_phy has populated it, scan the
   --  table and rewrite any slot that still points at a blob version of a
   --  function we've ported (__real_X) to our Ada (__wrap_X).  Then ROM
   --  dispatches through the table land in our Ada too.  Exact-address match, so
   --  ROM-only slots (kept) are never touched.
   G_Phy_Funs : System.Address
     with Import, Convention => C, External_Name => "g_phyFuns";
   Resolver_Patched : Interfaces.Unsigned_32 := 0
     with Export, Convention => C, External_Name => "ada_phy_resolver_patched";
   Resolver_Already : Interfaces.Unsigned_32 := 0
     with Export, Convention => C, External_Name => "ada_phy_resolver_already";
   Resolver_Nonnull : Interfaces.Unsigned_32 := 0
     with Export, Convention => C, External_Name => "ada_phy_resolver_nonnull";

   --  __real_X = the original blob function (created by --wrap).
   procedure R_Force_Txrx_Off      with Import, Convention => C, External_Name => "__real_force_txrx_off";
   procedure R_Disable_Low_Rate    with Import, Convention => C, External_Name => "__real_phy_disable_low_rate";
   procedure R_Enable_Low_Rate     with Import, Convention => C, External_Name => "__real_phy_enable_low_rate";
   procedure R_Wifi_Enable_Set     with Import, Convention => C, External_Name => "__real_phy_wifi_enable_set";
   procedure R_Ant_Dft_Cfg         with Import, Convention => C, External_Name => "__real_ant_dft_cfg";
   procedure R_Enable_Wifi_Agc     with Import, Convention => C, External_Name => "__real_ram_enable_wifi_agc";
   procedure R_Disable_Wifi_Agc    with Import, Convention => C, External_Name => "__real_ram_disable_wifi_agc";
   procedure R_Set_Tx_Seed         with Import, Convention => C, External_Name => "__real_phy_set_tx_seed";
   procedure R_Rifs_Mode_En        with Import, Convention => C, External_Name => "__real_wifi_rifs_mode_en";
   procedure R_Get_Noise_Floor     with Import, Convention => C, External_Name => "__real_phy_get_noise_floor";
   procedure R_Read_Hw_Noisefloor  with Import, Convention => C, External_Name => "__real_read_hw_noisefloor";
   procedure R_Get_Cca             with Import, Convention => C, External_Name => "__real_phy_get_cca";
   procedure R_Get_Fetx_Delay      with Import, Convention => C, External_Name => "__real_phy_get_fetx_delay";
   procedure R_Get_Cca_Cnt         with Import, Convention => C, External_Name => "__real_phy_get_cca_cnt";
   procedure R_Set_Cca_Cnt         with Import, Convention => C, External_Name => "__real_phy_set_cca_cnt";
   procedure R_Ant_Wifitx_Cfg      with Import, Convention => C, External_Name => "__real_ant_wifitx_cfg";
   procedure R_Ant_Bttx_Cfg        with Import, Convention => C, External_Name => "__real_ant_bttx_cfg";
   procedure R_Rx11blr_Cfg         with Import, Convention => C, External_Name => "__real_phy_rx11blr_cfg";
   procedure R_Set_Tsens_Power     with Import, Convention => C, External_Name => "__real_phy_set_tsens_power";
   procedure R_Agc_Sat_Gain        with Import, Convention => C, External_Name => "__real_rom_wifi_agc_sat_gain";
   procedure R_Fft_Scale_Force     with Import, Convention => C, External_Name => "__real_phy_fft_scale_force";
   procedure R_Bb_Reg_Init         with Import, Convention => C, External_Name => "__real_ram_bb_reg_init";

   type Redirect is record
      From_Blob, To_Ada : System.Address;
   end record;
   Ported : constant array (Positive range <>) of Redirect :=
     ((R_Force_Txrx_Off'Address,     Wrap_Force_Txrx_Off'Address),
      (R_Disable_Low_Rate'Address,   Wrap_Disable_Low_Rate'Address),
      (R_Enable_Low_Rate'Address,    Wrap_Enable_Low_Rate'Address),
      (R_Wifi_Enable_Set'Address,    Wrap_Wifi_Enable_Set'Address),
      (R_Ant_Dft_Cfg'Address,        Wrap_Ant_Dft_Cfg'Address),
      (R_Enable_Wifi_Agc'Address,    Wrap_Enable_Wifi_Agc'Address),
      (R_Disable_Wifi_Agc'Address,   Wrap_Disable_Wifi_Agc'Address),
      (R_Set_Tx_Seed'Address,        Wrap_Set_Tx_Seed'Address),
      (R_Rifs_Mode_En'Address,       Wrap_Rifs_Mode_En'Address),
      (R_Get_Noise_Floor'Address,    Wrap_Get_Noise_Floor'Address),
      (R_Read_Hw_Noisefloor'Address, Wrap_Read_Hw_Noisefloor'Address),
      (R_Get_Cca'Address,            Wrap_Get_Cca'Address),
      (R_Get_Fetx_Delay'Address,     Wrap_Get_Fetx_Delay'Address),
      (R_Get_Cca_Cnt'Address,        Wrap_Get_Cca_Cnt'Address),
      (R_Set_Cca_Cnt'Address,        Wrap_Set_Cca_Cnt'Address),
      (R_Ant_Wifitx_Cfg'Address,     Wrap_Ant_Wifitx_Cfg'Address),
      (R_Ant_Bttx_Cfg'Address,       Wrap_Ant_Bttx_Cfg'Address),
      (R_Rx11blr_Cfg'Address,        Wrap_Rx11blr_Cfg'Address),
      (R_Set_Tsens_Power'Address,    Wrap_Set_Tsens_Power'Address),
      (R_Agc_Sat_Gain'Address,       Wrap_Agc_Sat_Gain'Address),
      (R_Fft_Scale_Force'Address,    Wrap_Fft_Scale_Force'Address),
      (R_Bb_Reg_Init'Address,        Wrap_Bb_Reg_Init'Address));

   procedure Resolve_Phy_Table is
      use type System.Address;
      Base : constant System.Address := G_Phy_Funs;   --  the table base pointer
      Slots : constant := 200;
      Table : array (0 .. Slots - 1) of System.Address
        with Import, Volatile, Address => Base;
   begin
      if Base = System.Null_Address then
         return;
      end if;
      for I in Table'Range loop
         if Table (I) /= System.Null_Address then
            Resolver_Nonnull := Resolver_Nonnull + 1;
         end if;
         for P of Ported loop
            if Table (I) = P.From_Blob then
               Table (I) := P.To_Ada;
               Resolver_Patched := Resolver_Patched + 1;
            elsif Table (I) = P.To_Ada then
               Resolver_Already := Resolver_Already + 1;
            end if;
         end loop;
      end loop;
   end Resolve_Phy_Table;

   procedure Phy_Enable is
      Cal : System.Address;
      Clk : Unsigned_32 with Import, Volatile,
              Address => To_Address (Wifi_Clk_En_Reg);
   begin
      Clk := Clk or Phy_Clk_Mask;   --  common clock + PHY-cal/RNG clock

      if not Calibrated then
         Cal := C_Calloc (1, Cal_Size);
         if Cal = System.Null_Address then
            ESP32S3.Log.Put_Line ("[wifi] PHY: cal_data alloc failed");
            return;
         end if;
         declare
            --  Overlay the heap cal buffer as a Cal_Blob so the hooks read/write
            --  it in place -- no 1904-byte copy on the (small) Wi-Fi task stack.
            Cal_Bytes : Cal_Blob with Import, Address => Cal;
            Mode      : Interfaces.Integer_32 := PHY_RF_CAL_FULL;
            Loaded    : Boolean := False;
         begin
            --  A valid stored calibration -> fast PARTIAL cal off its baseline.
            --  Load_Hook fills Cal_Bytes in place; if it is not this chip's blob
            --  we fall through to FULL (which stamps the MAC + overwrites all).
            if Load_Hook /= null
              and then Load_Hook (Cal_Bytes)
              and then Blob_Matches_Chip (Cal_Bytes)
            then
               Mode   := PHY_RF_CAL_PARTIAL;
               Loaded := True;
            end if;

            --  Fresh FULL buffer: stamp this chip's MAC (the cal keys off it).
            if not Loaded then
               declare
                  Base : constant ESP32S3.MAC.MAC_Address := ESP32S3.MAC.Base;
               begin
                  for I in 0 .. 5 loop
                     Cal_Bytes (Mac_Offset + I) := Base (I);
                  end loop;
               end;
            end if;

            if Loaded then
               ESP32S3.Log.Put_Line ("[wifi] PHY: RF cal PARTIAL (stored baseline)");
            else
               ESP32S3.Log.Put_Line ("[wifi] PHY: RF cal FULL");
            end if;

            --  Run RF calibration (PARTIAL or FULL).  A non-zero result is
            --  normal for a fresh FULL buffer (the cal self-check), not an error.
            declare
               Rc : constant Interfaces.Integer_32 :=
                 Register_Chipv7_Phy (Phy_Init_Data'Address, Cal, Mode);
               pragma Unreferenced (Rc);
            begin
               null;
            end;

            --  Persist a freshly-produced FULL calibration for the next boot.
            --  (Full-cal output is inherently good, so storing here is safe.)
            if not Loaded and then Store_Hook /= null then
               Store_Hook (Cal_Bytes);
            end if;
         end;
         C_Free (Cal);   --  PHY keeps its own copy of the calibration data
         --  register_chipv7_phy has now populated g_phyFuns; redirect any table
         --  slot still pointing at a blob version of a ported function to Ada.
         Resolve_Phy_Table;
         Calibrated := True;
      else
         Phy_Wakeup_Init;
      end if;
   end Phy_Enable;

   procedure Phy_Disable is
   begin
      null;   --  leave the RF on (continuous scanning); TODO phy_close_rf
   end Phy_Disable;

end ESP32S3.WiFi.PHY;
