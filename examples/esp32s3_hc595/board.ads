------------------------------------------------------------------------------
--  Board configuration for THIS project -- flash + external PSRAM size.
--  bare_build reads it to size the image header and build/select the bootloader.
------------------------------------------------------------------------------
package Board is

   Flash_Size : constant := 2 * 1024 * 1024;     --  2 MB

   PSRAM_Size : constant := 2 * 1024 * 1024;     --  2 MB

end Board;
