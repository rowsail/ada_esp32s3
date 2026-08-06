with System;
with Ada.Unchecked_Conversion;
with Ada.IO_Exceptions;

package body ESP32S3.Block_Dev.SDMMC_Source is

   use type ESP32S3.SDMMC.Status;

   type Card_Access is access all ESP32S3.SDMMC.Card;
   function To_Card is new Ada.Unchecked_Conversion (System.Address, Card_Access);

   procedure Do_Read (Ctx : System.Address; LBA : Sector_Index; Data : out Sector) is
      C  : constant Card_Access := To_Card (Ctx);
      B  : ESP32S3.SDMMC.Block;
      St : ESP32S3.SDMMC.Status;
   begin
      ESP32S3.SDMMC.Read_Block (C.all, ESP32S3.SDMMC.Block_Address (LBA), B, St);
      if St /= ESP32S3.SDMMC.OK then
         raise Ada.IO_Exceptions.Device_Error with "SDMMC read failed";
      end if;
      Data := Sector (B);
   end Do_Read;

   --  A whole run in one CMD18: the card's read-access latency is paid once
   --  for the run instead of once per sector.  The driver's Block_Run and our
   --  Sector_Run are both flat byte arrays; overlay rather than copy.
   --
   --  A failed run falls back to single-sector reads before giving up: run
   --  transfers have failure modes singles do not (a drain loop starved past
   --  its deadline mid-stream), and a transient one must degrade to the slow
   --  path, not bubble up as "device gone" -- the filesystem above treats an
   --  unreadable volume as a candidate for REFORMATTING.
   procedure Do_Read_Run (Ctx : System.Address; First : Sector_Index; Data : out Sector_Run) is
      C  : constant Card_Access := To_Card (Ctx);
      B  : ESP32S3.SDMMC.Block_Run (0 .. Data'Length - 1)
        with Import, Address => Data'Address;
      St : ESP32S3.SDMMC.Status;
   begin
      ESP32S3.SDMMC.Read_Blocks (C.all, ESP32S3.SDMMC.Block_Address (First), B, St);
      if St /= ESP32S3.SDMMC.OK then
         declare
            Sec : Sector;
            Dst : Natural := Data'First;
         begin
            for S in 0 .. Data'Length / Sector'Length - 1 loop
               Do_Read (Ctx, First + Sector_Index (S), Sec);
               Data (Dst .. Dst + Sector'Length - 1) := Sector_Run (Sec);
               Dst := Dst + Sector'Length;
            end loop;
         end;
      end if;
   end Do_Read_Run;


   procedure Do_Write (Ctx : System.Address; LBA : Sector_Index; Data : Sector) is
      C  : constant Card_Access := To_Card (Ctx);
      St : ESP32S3.SDMMC.Status;
   begin
      ESP32S3.SDMMC.Write_Block
        (C.all, ESP32S3.SDMMC.Block_Address (LBA), ESP32S3.SDMMC.Block (Data), St);
      if St /= ESP32S3.SDMMC.OK then
         raise Ada.IO_Exceptions.Device_Error with "SDMMC write failed";
      end if;
   end Do_Write;

   --  A whole run in one CMD25, the write-side twin of Do_Read_Run -- same
   --  single-sector fallback on a failed run.
   procedure Do_Write_Run (Ctx : System.Address; First : Sector_Index; Data : Sector_Run) is
      C  : constant Card_Access := To_Card (Ctx);
      B  : ESP32S3.SDMMC.Block_Run (0 .. Data'Length - 1)
        with Import, Address => Data'Address;
      St : ESP32S3.SDMMC.Status;
   begin
      ESP32S3.SDMMC.Write_Blocks (C.all, ESP32S3.SDMMC.Block_Address (First), B, St);
      if St /= ESP32S3.SDMMC.OK then
         declare
            Src : Natural := Data'First;
         begin
            for S in 0 .. Data'Length / Sector'Length - 1 loop
               Do_Write (Ctx, First + Sector_Index (S),
                         Sector (Data (Src .. Src + Sector'Length - 1)));
               Src := Src + Sector'Length;
            end loop;
         end;
      end if;
   end Do_Write_Run;

   --  SDMMC knows the card's capacity (from the CSD), so report it exactly.
   function Do_Count (Ctx : System.Address) return Sector_Index is
      C : constant Card_Access := To_Card (Ctx);
   begin
      return Sector_Index (ESP32S3.SDMMC.Capacity_Blocks (C.all));
   end Do_Count;

   function Make (C : not null access ESP32S3.SDMMC.Card) return Device is
   begin
      return
        (Ctx       => C.all'Address,
         Read      => Do_Read'Access,
         Write     => Do_Write'Access,
         Count     => Do_Count'Access,
         Erase     => null,
         Read_Run  => Do_Read_Run'Access,
         Write_Run => Do_Write_Run'Access);
   end Make;

end ESP32S3.Block_Dev.SDMMC_Source;
