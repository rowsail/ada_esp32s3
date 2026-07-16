with Interfaces; use Interfaces;
with System;

package body Psram_Board is

   --  ROM console printf: bare_board_init runs before adainit, so the buffered
   --  ESP32S3.Log console is not elaborated yet -- use the always-available ROM
   --  printf (as the C glue did).
   procedure Rom_Printf_Rc (Fmt : System.Address; Rc : Integer_32);
   pragma Import (C, Rom_Printf_Rc, "esp_rom_printf");
   procedure Rom_Printf (Fmt : System.Address);
   pragma Import (C, Rom_Printf, "esp_rom_printf");

   --  ROM cache routines (rom_syms.ld).
   function Cache_Dbus_MMU_Set
     (Ext_Ram, Vaddr, Paddr, Psize, Num, Fixed : Unsigned_32) return Integer_32;
   pragma Import (C, Cache_Dbus_MMU_Set, "Cache_Dbus_MMU_Set");
   procedure Cache_Disable_DCache;
   pragma Import (C, Cache_Disable_DCache, "Cache_Disable_DCache");
   procedure Cache_Enable_DCache (Autoload : Unsigned_32);
   pragma Import (C, Cache_Enable_DCache, "Cache_Enable_DCache");

   Map_Msg : constant String :=
     "[psram] mapped PSRAM @0x3D000000 rc=%d (bootloader did the bring-up)"
     & ASCII.LF & ASCII.NUL;
   Abort_Msg : constant String := "[psram] abort()" & ASCII.LF & ASCII.NUL;

   ----------------
   -- Board_Init --
   ----------------

   --  bare_board_init: re-map the octal PSRAM into the d-bus (SPIRAM access bit
   --  0x8000, 2 MB / 32 pages).  Disable the d-cache for the MMU write, then
   --  re-enable it -- exactly what the C did.
   procedure Board_Init
   with Export, Convention => C, External_Name => "bare_board_init";

   procedure Board_Init is
      Rc : Integer_32;
   begin
      Cache_Disable_DCache;                                   --  MMU write needs cache off
      Rc := Cache_Dbus_MMU_Set (16#8000#, 16#3D00_0000#, 0, 64, 32, 0);
      Cache_Enable_DCache (0);
      Rom_Printf_Rc (Map_Msg'Address, Rc);
   end Board_Init;

   -----------
   -- Abort --
   -----------

   --  Freestanding abort that libgcc references (the light-tasking runtime has
   --  none): print + halt, as the C glue did.
   procedure Abort_Exec
   with Export, Convention => C, External_Name => "abort", No_Return;

   procedure Abort_Exec is
   begin
      Rom_Printf (Abort_Msg'Address);
      loop
         null;
      end loop;
   end Abort_Exec;

end Psram_Board;
