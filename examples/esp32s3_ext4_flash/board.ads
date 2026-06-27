------------------------------------------------------------------------------
--  Board configuration for THIS project -- flash + external PSRAM size.
--
--  Each project owns this file; there is no global board config.  bare_build
--  reads it to size the image header and to build/select the 2nd-stage
--  bootloader (PSRAM_Size is mapped at boot).  Edit + rebuild, or let
--  `esp32-ada config` / `./x config <example>` edit it for you.
--
--  NOTE: these sizes describe the ESP32-S3's OWN in-package boot flash / octal
--  PSRAM -- NOT the external W25Q256FV this example talks to over SPI2.
------------------------------------------------------------------------------
package Board is

   --  Total SPI flash size.  A "hint" for the image header / SPI params; the
   --  real chip size is auto-detected at boot.
   Flash_Size : constant := 2 * 1024 * 1024;     --  2 MB

   --  External PSRAM size MAPPED at 0x3D000000 by the 2nd-stage bootloader.
   --  Must be a multiple of the 64 KB MMU page and <= the physical chip.
   PSRAM_Size : constant := 2 * 1024 * 1024;     --  2 MB

end Board;
