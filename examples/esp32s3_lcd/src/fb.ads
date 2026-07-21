with Interfaces; use Interfaces;

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

end FB;
