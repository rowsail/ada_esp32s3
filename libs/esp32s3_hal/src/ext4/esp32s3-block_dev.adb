with Ada.IO_Exceptions;

package body ESP32S3.Block_Dev is

   function Sector_Count (Dev : Device) return Sector_Index is
   begin
      if Dev.Count = null then
         return 0;
      end if;
      return Dev.Count (Dev.Ctx);
   end Sector_Count;

   procedure Read_Sector (Dev : Device; LBA : Sector_Index; Data : out Sector) is
   begin
      if Dev.Read = null then
         raise Ada.IO_Exceptions.Device_Error with "block device has no read primitive";
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

   procedure Read_Sectors (Dev : Device; First : Sector_Index; Data : out Sector_Run) is
   begin
      if Data'Length mod Sector'Length /= 0 then
         raise Ada.IO_Exceptions.Device_Error with "run length not a whole number of sectors";
      end if;
      if Dev.Read_Run /= null then
         Dev.Read_Run (Dev.Ctx, First, Data);
         return;
      end if;
      declare
         Sectors : constant Natural := Data'Length / Sector'Length;
         Sec     : Sector;
         Dst     : Natural := Data'First;
      begin
         for S in 0 .. Sectors - 1 loop
            Read_Sector (Dev, First + Sector_Index (S), Sec);
            Data (Dst .. Dst + Sector'Length - 1) := Sector_Run (Sec);
            Dst := Dst + Sector'Length;
         end loop;
      end;
   end Read_Sectors;

   procedure Write_Sectors (Dev : Device; First : Sector_Index; Data : Sector_Run) is
   begin
      if Data'Length mod Sector'Length /= 0 then
         raise Ada.IO_Exceptions.Device_Error with "run length not a whole number of sectors";
      end if;
      if Dev.Write_Run /= null then
         Dev.Write_Run (Dev.Ctx, First, Data);
         return;
      end if;
      declare
         Sectors : constant Natural := Data'Length / Sector'Length;
         Src     : Natural := Data'First;
      begin
         for S in 0 .. Sectors - 1 loop
            Write_Sector (Dev, First + Sector_Index (S),
                          Sector (Data (Src .. Src + Sector'Length - 1)));
            Src := Src + Sector'Length;
         end loop;
      end;
   end Write_Sectors;

   procedure Erase_Sectors (Dev : Device; First, Count : Sector_Index) is
   begin
      if Dev.Erase /= null then
         --  no-op on a device without the capability
         Dev.Erase (Dev.Ctx, First, Count);
      end if;
   end Erase_Sectors;

end ESP32S3.Block_Dev;
