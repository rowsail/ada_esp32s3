------------------------------------------------------------------------------
--  Board configuration -- Waveshare ESP32-S3-Touch-LCD-7 (800x480, N*R8 octal
--  PSRAM).  bare_build reads it to size the image header and to build/select the
--  2nd-stage bootloader (PSRAM_Size is mapped at 0x3D000000 at boot).
------------------------------------------------------------------------------
package Board is

   --  SPI flash size (a header hint; the real chip size is auto-detected).
   Flash_Size : constant := 16 * 1024 * 1024;    --  16 MB

   --  External octal PSRAM MAPPED at 0x3D000000 by the 2nd-stage bootloader.
   --  2 MB is plenty for two 768 000-byte RGB565 framebuffers (1.5 MB); the chip
   --  itself is larger, but only this window is mapped.  Multiple of the 64 KB
   --  MMU page.
   PSRAM_Size : constant := 2 * 1024 * 1024;     --  2 MB window

end Board;
