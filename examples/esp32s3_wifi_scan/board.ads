------------------------------------------------------------------------------
--  Board configuration for the Wi-Fi scan example -- flash + external PSRAM.
--  Matches the connected dev board.  The Wi-Fi driver's DMA buffers come from
--  the leftover-DRAM heap (DMA-capable internal SRAM), not PSRAM.
------------------------------------------------------------------------------
package Board is

   Flash_Size : constant := 2 * 1024 * 1024;     --  2 MB

   PSRAM_Size : constant := 2 * 1024 * 1024;     --  2 MB

end Board;
