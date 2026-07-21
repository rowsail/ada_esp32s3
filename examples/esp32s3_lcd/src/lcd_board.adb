with Interfaces; use Interfaces;

package body Lcd_Board is

   --  ROM cache routines (rom_syms.ld).
   function Cache_Dbus_MMU_Set
     (Ext_Ram, Vaddr, Paddr, Psize, Num, Fixed : Unsigned_32) return Integer_32;
   pragma Import (C, Cache_Dbus_MMU_Set, "Cache_Dbus_MMU_Set");
   procedure Cache_Disable_DCache;
   pragma Import (C, Cache_Disable_DCache, "Cache_Disable_DCache");
   procedure Cache_Enable_DCache (Autoload : Unsigned_32);
   pragma Import (C, Cache_Enable_DCache, "Cache_Enable_DCache");

   --  bare_board_init: re-map the octal PSRAM into the d-bus (SPIRAM access bit
   --  0x8000, 2 MB / 32 pages of 64 KB).  Disable the d-cache for the MMU write,
   --  then re-enable it.
   procedure Board_Init
     with Export, Convention => C, External_Name => "bare_board_init";

   procedure Board_Init is
      Rc : Integer_32 with Unreferenced;
   begin
      Cache_Disable_DCache;
      Rc := Cache_Dbus_MMU_Set (16#8000#, 16#3D00_0000#, 0, 64, 32, 0);
      Cache_Enable_DCache (0);
   end Board_Init;

end Lcd_Board;
