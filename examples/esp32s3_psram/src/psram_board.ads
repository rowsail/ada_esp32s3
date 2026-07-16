--  esp32s3_psram board bring-up, in Ada (was the bare_board_init + freestanding
--  abort in psram/glue.c).  The 2nd-stage bootloader already brought the octal
--  PSRAM up from SRAM; this only re-maps it into the CPU d-bus at 0x3D000000,
--  which must run AFTER the app's start.S (whose Cache_Set_IDROM_MMU_Size wipes
--  the d-bus MMU) -- so it runs from the weak bare_board_init hook that the bare
--  boot calls on core 0 before adainit.  `with Psram_Board;` in the main pulls it
--  into the link closure (memset comes from the shared Bare_Mem, linked by the
--  build's NEED_BARE_MEM opt-in).
package Psram_Board is
   pragma Elaborate_Body;
end Psram_Board;
