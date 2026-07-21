with Interfaces; use Interfaces;
with System;

--  The display framebuffers, in external PSRAM.
package FB is

   Width  : constant := 800;
   Height : constant := 480;
   Bytes  : constant := Width * Height * 2;    --  RGB565 -> 768_000 bytes

   --  32-byte aligned so the GDMA can stream it straight from PSRAM.
   type Framebuffer is array (0 .. Bytes - 1) of Unsigned_8
     with Alignment => 32;

   --  Two buffers in the external-RAM bss section (each 768 000 B -- far too big
   --  for internal SRAM).  FB0 is what Start_RGB streams; FB1 is the spare for a
   --  future tear-free double-buffer flip.
   FB0 : Framebuffer with Linker_Section => ".ext_ram.bss";
   FB1 : Framebuffer with Linker_Section => ".ext_ram.bss";

   --  Fill FB0 with eight vertical colour bars -- a visible RGB565 test pattern.
   procedure Test_Pattern;

   Box : constant := 80;   --  moving-box side, in pixels

   --  Fill Buf (any framebuffer address) with the eight colour bars.  Used once
   --  to seed each buffer; the demo then only touches the moving box.
   procedure Draw_Bars (Buf : System.Address);

   --  Paint the Box-sized square at (X, Y) in Buf: White => a white box, else
   --  restore the colour bars underneath (i.e. erase a box).  This is all the
   --  per-frame drawing the direct double-buffered demo does -- a few KB, so it
   --  never saturates PSRAM against the scan-out DMA (a full-frame redraw does).
   procedure Paint_Box (Buf : System.Address; X, Y : Natural; White : Boolean);

   --  Draw a white frame around Buf's edge -- unlike the vertical bars, a border
   --  makes any vertical roll or buffer mixing obvious.
   procedure Draw_Border (Buf : System.Address);

end FB;
