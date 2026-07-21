--  Board bring-up hook: re-map the octal PSRAM into the CPU d-bus at 0x3D000000
--  so the .ext_ram.bss framebuffers (fb.adb) are backed by real PSRAM.  The
--  2nd-stage bootloader already brought the PSRAM up from SRAM; this only
--  re-applies the cache-MMU map, which must run AFTER the app's start.S (whose
--  Cache_Set_IDROM_MMU_Size wipes the d-bus MMU).  It runs from the weak
--  bare_board_init hook the bare boot calls on core 0 before adainit.
--  `with Lcd_Board;` in the main pulls it into the link closure.
package Lcd_Board is
   pragma Elaborate_Body;
end Lcd_Board;
