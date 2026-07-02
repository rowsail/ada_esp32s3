with Ada.IO_Exceptions;

package body ESP32S3.Block_Dev is

   function Sector_Count (Dev : Device) return Sector_Index is
   begin
      if Dev.Count = null then
         return 0;
      end if;
      return Dev.Count (Dev.Ctx);
   end Sector_Count;

   procedure Read_Sector (Dev : Device; LBA : Sector_Index; Data : out Sector)
   is
   begin
      if Dev.Read = null then
         raise Ada.IO_Exceptions.Device_Error
           with "block device has no read primitive";
      end if;
      Dev.Read (Dev.Ctx, LBA, Data);
   end Read_Sector;

   procedure Write_Sector (Dev : Device; LBA : Sector_Index; Data : Sector) is
   begin
      if Dev.Write = null then
         raise Ada.IO_Exceptions.Use_Error with "block device is read-only";
      end if;
      Dev.Write (Dev.Ctx, LBA, Data);
   end Write_Sector;

   procedure Erase_Sectors (Dev : Device; First, Count : Sector_Index) is
   begin
      if Dev.Erase /= null then
         --  no-op on a device without the capability
         Dev.Erase (Dev.Ctx, First, Count);
      end if;
   end Erase_Sectors;

end ESP32S3.Block_Dev;
