--  IDF-free 2nd-stage bootloader -- loader core, in ZFP-style Ada (no runtime:
--  no tasking / exceptions / secondary stack / elaboration; -gnatp).  Reached from
--  start.S as "boot_main".  It: disables the boot watchdogs, reads the app image
--  from flash and copies its RAM segments, maps the app's flash IROM/DROM into the
--  cache MMU and enables the cache, brings up the octal PSRAM (the thin C shim
--  psram_bringup over the vendored IDF blobs), then jumps to the app entry.
--  Register access is direct MMIO; flash/cache/PSRAM primitives are ROM or C imports.
with Interfaces;              use Interfaces;
with System;                  use System;
with System.Storage_Elements; use System.Storage_Elements;
with Ada.Unchecked_Conversion;

procedure Boot_Main is

   App_Offset : constant Unsigned_32 := 16#1_0000#;   --  factory app @ flash 0x10000

   --  ---- direct MMIO -------------------------------------------------------
   procedure Poke (Addr, Val : Unsigned_32) is
      R : Unsigned_32
      with Import, Volatile, Address => To_Address (Integer_Address (Addr));
   begin
      R := Val;
   end Poke;

   function Peek (Addr : Unsigned_32) return Unsigned_32 is
      R : Unsigned_32
      with Import, Volatile, Address => To_Address (Integer_Address (Addr));
   begin
      return R;
   end Peek;

   procedure Clear_Bits (Addr, Mask : Unsigned_32) is
   begin
      Poke (Addr, Peek (Addr) and not Mask);
   end Clear_Bits;

   --  ---- ROM / C imports ---------------------------------------------------
   function Spiflash_Read (Src : Unsigned_32; Dst : Address; Len : Unsigned_32) return Integer
   with Import, Convention => C, External_Name => "esp_rom_spiflash_read";

   procedure Cache_Disable_ICache
   with Import, Convention => C, External_Name => "Cache_Disable_ICache";
   procedure Cache_Disable_DCache
   with Import, Convention => C, External_Name => "Cache_Disable_DCache";
   procedure Cache_Enable_DCache (Autoload : Unsigned_32)
   with Import, Convention => C, External_Name => "Cache_Enable_DCache";
   function Cache_Ibus_MMU_Set
     (Ext_Ram, Vaddr, Paddr, Psize, Num, Fixed : Unsigned_32) return Integer
   with Import, Convention => C, External_Name => "Cache_Ibus_MMU_Set";
   function Cache_Dbus_MMU_Set
     (Ext_Ram, Vaddr, Paddr, Psize, Num, Fixed : Unsigned_32) return Integer
   with Import, Convention => C, External_Name => "Cache_Dbus_MMU_Set";
   procedure Cache_Invalidate_ICache_All
   with Import, Convention => C, External_Name => "Cache_Invalidate_ICache_All";

   --  the octal-PSRAM bring-up (the thin C shim over the vendored IDF objects)
   procedure Psram_Bringup
   with Import, Convention => C, External_Name => "psram_bringup";

   --  ROM console (variadic; declare the fixed arities we use)
   function Printf (Fmt : Address) return Integer
   with Import, Convention => C, External_Name => "esp_rom_printf";
   function Printf1 (Fmt : Address; A1 : Unsigned_32) return Integer
   with Import, Convention => C, External_Name => "esp_rom_printf";

   --  app entry, called as a plain C function pointer
   type Entry_Proc is access procedure with Convention => C;
   function To_Entry is new Ada.Unchecked_Conversion (Address, Entry_Proc);

   --  ---- ESP32-S3 load-address ranges + 64 KB MMU page count ---------------
   function In_DRAM (A : Unsigned_32) return Boolean
   is (A >= 16#3FC8_0000# and A < 16#3FD0_0000#);
   function In_IRAM (A : Unsigned_32) return Boolean
   is (A >= 16#4037_0000# and A < 16#403E_0000#);
   function In_DROM (A : Unsigned_32) return Boolean
   is (A >= 16#3C00_0000# and A < 16#3E00_0000#);
   function In_IROM (A : Unsigned_32) return Boolean
   is (A >= 16#4200_0000# and A < 16#4400_0000#);
   function MMU_Pages (V, Sz : Unsigned_32) return Unsigned_32
   is (((V and 16#FFFF#) + Sz + 16#FFFF#) / 16#1_0000#);

   Hdr                                  : array (0 .. 5) of Unsigned_32;   --  24-byte image header
   Seg                                  :
     array (0 .. 1) of Unsigned_32;   --  per-segment (load_addr, len)
   Magic, Nseg, Entry_A, Pos, Load, Len : Unsigned_32;
   Drom_V, Drom_P, Drom_Sz              : Unsigned_32 := 0;
   Irom_V, Irom_P, Irom_Sz              : Unsigned_32 := 0;
   Ignore                               : Integer;

   L_Msg : constant String := "[ada-free-boot] loading app image @0x%08x" & ASCII.LF & ASCII.NUL;
   J_Msg : constant String := "[ada-free-boot] jumping to app entry 0x%08x" & ASCII.LF & ASCII.NUL;
   Bad   : constant String := "[ada-free-boot] bad image magic" & ASCII.LF & ASCII.NUL;
begin
   --  Disable the boot watchdogs the ROM armed (TG0 MWDT + RTC WDT).
   Poke (16#6001_F064#, 16#50D8_3AA1#);
   Poke (16#6001_F048#, 0);
   Poke (16#6001_F064#, 0);
   Poke (16#6000_80B0#, 16#50D8_3AA1#);
   Poke (16#6000_8098#, 0);
   Poke (16#6000_80B0#, 0);

   Ignore := Printf1 (L_Msg'Address, App_Offset);

   --  Image header: byte0 = magic 0xE9, byte1 = segment_count, word1 = entry_addr.
   Ignore := Spiflash_Read (App_Offset, Hdr'Address, 24);
   Magic := Hdr (0) and 16#FF#;
   Nseg := Shift_Right (Hdr (0), 8) and 16#FF#;
   Entry_A := Hdr (1);
   if Magic /= 16#E9# then
      Ignore := Printf (Bad'Address);
      loop
         null;
      end loop;
   end if;

   --  Walk the segments: copy RAM ones into SRAM, record the flash IROM/DROM ones.
   Pos := App_Offset + 24;
   for I in 1 .. Nseg loop
      Ignore := Spiflash_Read (Pos, Seg'Address, 8);
      Load := Seg (0);
      Len := Seg (1);
      Pos := Pos + 8;
      if In_IRAM (Load) or In_DRAM (Load) then
         Ignore := Spiflash_Read (Pos, To_Address (Integer_Address (Load)), (Len + 3) and not 3);
      elsif In_DROM (Load) then
         Drom_V := Load;
         Drom_P := Pos;
         Drom_Sz := Len;
      elsif In_IROM (Load) then
         Irom_V := Load;
         Irom_P := Pos;
         Irom_Sz := Len;
      end if;
      Pos := Pos + Len;
   end loop;

   --  Map the app's flash IROM (i-bus) + DROM (d-bus) into the cache MMU (64 KB
   --  pages, ext_ram=0=MMU_ACCESS_FLASH), enable the cache buses + the D-cache.
   Cache_Disable_ICache;
   Cache_Disable_DCache;
   Ignore :=
     Cache_Ibus_MMU_Set
       (0, Irom_V and not 16#FFFF#, Irom_P and not 16#FFFF#, 64, MMU_Pages (Irom_V, Irom_Sz), 0);
   Ignore :=
     Cache_Dbus_MMU_Set
       (0, Drom_V and not 16#FFFF#, Drom_P and not 16#FFFF#, 64, MMU_Pages (Drom_V, Drom_Sz), 0);
   Clear_Bits (16#600C_4064#, 3);   --  EXTMEM ICACHE_CTRL1: clear SHUT core0+1 -> i-bus on
   Clear_Bits (16#600C_4004#, 3);   --  EXTMEM DCACHE_CTRL1: clear SHUT core0+1 -> d-bus on
   Cache_Enable_DCache (0);         --  (I-cache is enabled by the app's start.S)
   Cache_Invalidate_ICache_All;

   --  Bring up + map the octal PSRAM (thin C shim over the vendored IDF blobs).
   Psram_Bringup;

   --  Hand off to the app.
   Ignore := Printf1 (J_Msg'Address, Entry_A);
   To_Entry (To_Address (Integer_Address (Entry_A))).all;

   loop
      null;
   end loop;   --  unreachable; the app does not return
end Boot_Main;
