with System;
with Ada.Unchecked_Conversion;
with Ada.IO_Exceptions;

package body ESP32S3.Block_Dev.SDMMC_Source is

   use type ESP32S3.SDMMC.Status;

   type Card_Access is access all ESP32S3.SDMMC.Card;
   function To_Card is new
     Ada.Unchecked_Conversion (System.Address, Card_Access);

   procedure Do_Read
     (Ctx : System.Address; LBA : Sector_Index; Data : out Sector)
   is
      C  : constant Card_Access := To_Card (Ctx);
      B  : ESP32S3.SDMMC.Block;
      St : ESP32S3.SDMMC.Status;
   begin
      ESP32S3.SDMMC.Read_Block
        (C.all, ESP32S3.SDMMC.Block_Address (LBA), B, St);
      if St /= ESP32S3.SDMMC.OK then
         raise Ada.IO_Exceptions.Device_Error with "SDMMC read failed";
      end if;
      Data := Sector (B);
   end Do_Read;

   procedure Do_Write (Ctx : System.Address; LBA : Sector_Index; Data : Sector)
   is
      C  : constant Card_Access := To_Card (Ctx);
      St : ESP32S3.SDMMC.Status;
   begin
      ESP32S3.SDMMC.Write_Block
        (C.all,
         ESP32S3.SDMMC.Block_Address (LBA),
         ESP32S3.SDMMC.Block (Data),
         St);
      if St /= ESP32S3.SDMMC.OK then
         raise Ada.IO_Exceptions.Device_Error with "SDMMC write failed";
      end if;
   end Do_Write;

   --  SDMMC knows the card's capacity (from the CSD), so report it exactly.
   function Do_Count (Ctx : System.Address) return Sector_Index is
      C : constant Card_Access := To_Card (Ctx);
   begin
      return Sector_Index (ESP32S3.SDMMC.Capacity_Blocks (C.all));
   end Do_Count;

   function Make (C : not null access ESP32S3.SDMMC.Card) return Device is
   begin
      return
        (Ctx   => C.all'Address,
         Read  => Do_Read'Access,
         Write => Do_Write'Access,
         Count => Do_Count'Access,
         Erase => null);
   end Make;

end ESP32S3.Block_Dev.SDMMC_Source;
