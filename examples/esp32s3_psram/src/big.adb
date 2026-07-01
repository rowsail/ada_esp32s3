with Interfaces;               use Interfaces;
with System.Storage_Elements;  use System.Storage_Elements;
with ESP32S3.Log;              use ESP32S3.Log;   --  buffered console

package body Big is

   Size : constant := 1024 * 1024;   --  1 MB

   --  Placed in the external-RAM bss section, mapped into the PSRAM window at
   --  0x3D000000 by this example's psram.ld (the 2nd-stage bootloader brings the
   --  octal PSRAM up and maps it; glue.c re-applies the cache map after start.S).
   Buffer : array (0 .. Size - 1) of Unsigned_8
     with Linker_Section => ".ext_ram.bss";

   --  The env task reports the buffer's address + checksum (was native_buf_report
   --  over esp_rom_printf; now pure Ada over the buffered ESP32S3.Log console).
   --  0x3C/0x3D = external PSRAM data range; 0x3F = internal SRAM.
   procedure Report (Addr, Bytes, Checksum : Unsigned_32) is
      Top   : constant Unsigned_32 := Shift_Right (Addr, 24);
      Where : constant String :=
        (if Top = 16#3C# or else Top = 16#3D# then "PSRAM"
         elsif Top = 16#3F# then "internal-SRAM"
         else "?");
   begin
      Put ("[psram] buffer @ 0x");   Put_Hex (Addr, Width => 8);
      Put ("  ");                    Put_Unsigned (Bytes);
      Put (" bytes  checksum=0x");   Put_Hex (Checksum, Width => 8);
      Put ("  (");                   Put (Where);
      Put_Line (")");
   end Report;

   procedure Run is
      Sum : Unsigned_32 := 0;
   begin
      --  Write a pattern across the whole 1 MB...
      for I in Buffer'Range loop
         Buffer (I) := Unsigned_8 (I mod 256);
      end loop;
      --  ...then read it all back and checksum it (proves the round trip).
      for I in Buffer'Range loop
         Sum := Sum + Unsigned_32 (Buffer (I));
      end loop;
      Report (Unsigned_32 (To_Integer (Buffer'Address)),
              Buffer'Length, Sum);
   end Run;

end Big;
