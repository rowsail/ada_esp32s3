with System;
with Ada.Unchecked_Conversion;
with Ada.IO_Exceptions;

package body ESP32S3.Block_Dev.SD_SPI_Source is

   use type ESP32S3.SD_SPI.Status;

   type Card_Access is access all ESP32S3.SD_SPI.Card;
   function To_Card is new
     Ada.Unchecked_Conversion (System.Address, Card_Access);

   procedure Do_Read
     (Ctx : System.Address; LBA : Sector_Index; Data : out Sector)
   is
      C  : constant Card_Access := To_Card (Ctx);
      B  : ESP32S3.SD_SPI.Block;
      St : ESP32S3.SD_SPI.Status;
   begin
      ESP32S3.SD_SPI.Read_Block
        (C.all, ESP32S3.SD_SPI.Block_Address (LBA), B, St);
      if St /= ESP32S3.SD_SPI.OK then
         raise Ada.IO_Exceptions.Device_Error with "SD read failed";
      end if;
      Data := Sector (B);
   end Do_Read;

   procedure Do_Write (Ctx : System.Address; LBA : Sector_Index; Data : Sector)
   is
      C  : constant Card_Access := To_Card (Ctx);
      St : ESP32S3.SD_SPI.Status;
   begin
      ESP32S3.SD_SPI.Write_Block
        (C.all,
         ESP32S3.SD_SPI.Block_Address (LBA),
         ESP32S3.SD_SPI.Block (Data),
         St);
      if St /= ESP32S3.SD_SPI.OK then
         raise Ada.IO_Exceptions.Device_Error with "SD write failed";
      end if;
   end Do_Write;

   --  SD_SPI exposes no sector count; the filesystem sizes itself from the
   --  superblock, so 0 (unknown) is fine here.
   function Do_Count (Ctx : System.Address) return Sector_Index is
      pragma Unreferenced (Ctx);
   begin
      return 0;
   end Do_Count;

   function Make (C : not null access ESP32S3.SD_SPI.Card) return Device is
   begin
      return
        (Ctx   => C.all'Address,
         Read  => Do_Read'Access,
         Write => Do_Write'Access,
         Count => Do_Count'Access,
         Erase => null);
   end Make;

end ESP32S3.Block_Dev.SD_SPI_Source;
