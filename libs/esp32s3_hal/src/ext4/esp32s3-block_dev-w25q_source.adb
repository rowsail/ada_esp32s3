with System;
with Interfaces;            use Interfaces;
with Ada.Unchecked_Conversion;
with Ada.IO_Exceptions;

package body ESP32S3.Block_Dev.W25Q_Source is

   package W25Q renames ESP32S3.W25Q;
   use type W25Q.Byte_Array;
   use type W25Q.Address;

   Sector_Bytes : constant := Sector'Length;   --  512

   type Source_Access is access all Source;
   function To_Source is
     new Ada.Unchecked_Conversion (System.Address, Source_Access);

   ----------------------------------------------------------------------------
   --  Helpers
   ----------------------------------------------------------------------------

   --  Byte address of LBA, with a range check against the configured size.
   function Sector_Address (S : Source; LBA : Sector_Index) return W25Q.Address is
   begin
      if LBA >= S.Count then
         raise Ada.IO_Exceptions.Device_Error with "W25Q block LBA out of range";
      end if;
      return W25Q.Address (LBA) * Sector_Bytes;
   end Sector_Address;

   --  Program Data at Addr, splitting into <=256-byte page writes.  Addr and the
   --  chunking are page-aligned by construction (Addr is 512- or 4096-aligned and
   --  Data'Length is a multiple of the 256-byte page), so no write crosses a page
   --  boundary.  Assumes the target only needs 1->0 bit changes (erased, or a
   --  superset of the new bits) -- the caller guarantees that.
   procedure Program_Pages (Flash : W25Q.Flash;
                            Addr  : W25Q.Address;
                            Data  : W25Q.Byte_Array)
   is
      Pos : Natural      := Data'First;
      A   : W25Q.Address := Addr;
   begin
      while Pos <= Data'Last loop
         declare
            N : constant Natural :=
              Natural'Min (W25Q.Page_Size, Data'Last - Pos + 1);
         begin
            W25Q.Program_Page (Flash, A, Data (Pos .. Pos + N - 1));
            Pos := Pos + N;
            A   := A + W25Q.Address (N);
         end;
      end loop;
   end Program_Pages;

   --  True if New_Data can be written over Old_Data by programming alone (every
   --  1 bit of New_Data is already 1 in Old_Data), i.e. no bit needs setting back
   --  to 1, so no erase is required.
   function Clear_Only (Old_Data, New_Data : W25Q.Byte_Array) return Boolean is
   begin
      for I in New_Data'Range loop
         if (New_Data (I) and Old_Data (I)) /= New_Data (I) then
            return False;
         end if;
      end loop;
      return True;
   end Clear_Only;

   ----------------------------------------------------------------------------
   --  Block_Dev vtable
   ----------------------------------------------------------------------------

   procedure Do_Read (Ctx : System.Address; LBA : Sector_Index; Data : out Sector)
   is
      S    : constant Source_Access := To_Source (Ctx);
      Addr : constant W25Q.Address  := Sector_Address (S.all, LBA);
      B    : W25Q.Byte_Array (0 .. Sector_Bytes - 1);
   begin
      W25Q.Read (S.Flash, Addr, B);
      Data := Sector (B);
   end Do_Read;

   procedure Do_Write (Ctx : System.Address; LBA : Sector_Index; Data : Sector) is
      S       : constant Source_Access := To_Source (Ctx);
      Addr    : constant W25Q.Address  := Sector_Address (S.all, LBA);
      New_B   : constant W25Q.Byte_Array (0 .. Sector_Bytes - 1) :=
                  W25Q.Byte_Array (Data);
      Old_B   : W25Q.Byte_Array (0 .. Sector_Bytes - 1);
   begin
      W25Q.Read (S.Flash, Addr, Old_B);

      if Old_B = New_B then
         return;                         --  already on the medium -- nothing to do
      elsif Clear_Only (Old_B, New_B) then
         Program_Pages (S.Flash, Addr, New_B);     --  program in place, no erase
      else
         --  Read-modify-write the whole 4 KB erase block: a 0->1 bit somewhere
         --  forces an erase, which clears all Sectors_Per_Erase sectors in it.
         declare
            Base   : constant W25Q.Address :=
                       Addr - (Addr mod W25Q.Sector_Size);
            Offset : constant Natural := Natural (Addr - Base);
         begin
            W25Q.Read (S.Flash, Base, S.Buf);
            S.Buf (Offset .. Offset + Sector_Bytes - 1) := New_B;
            W25Q.Erase_Sector (S.Flash, Base);
            Program_Pages (S.Flash, Base, S.Buf);
         end;
      end if;
   end Do_Write;

   function Do_Count (Ctx : System.Address) return Sector_Index is
      S : constant Source_Access := To_Source (Ctx);
   begin
      return S.Count;
   end Do_Count;

   --  Erase every 4 KB flash sector that the run [First, First+Count) touches
   --  (one erase op each).  A subsequent write into the erased space is a
   --  clear-only program, so a caller that rewrites the whole block pays one
   --  erase instead of a read-modify-write per 512-byte sector.
   procedure Do_Erase (Ctx   : System.Address;
                       First : Sector_Index;
                       Count : Sector_Index)
   is
      S          : constant Source_Access := To_Source (Ctx);
      Per_Erase  : constant Sector_Index := W25Q.Sector_Size / Sector_Bytes;  --  8
      First_Blk  : constant Sector_Index := First / Per_Erase;
      Last_Blk   : constant Sector_Index := (First + Count - 1) / Per_Erase;
   begin
      if Count = 0 then
         return;
      end if;
      if First + Count > S.Count then
         raise Ada.IO_Exceptions.Device_Error with "W25Q erase out of range";
      end if;
      for Blk in First_Blk .. Last_Blk loop
         W25Q.Erase_Sector (S.Flash, W25Q.Address (Blk) * W25Q.Sector_Size);
      end loop;
   end Do_Erase;

   ----------------------------------------------------------------------------
   --  Construction
   ----------------------------------------------------------------------------

   procedure Configure (Src            : in out Source;
                        Flash          : ESP32S3.W25Q.Flash;
                        Capacity_Bytes : ESP32S3.W25Q.Address := 0)
   is
      Cap : W25Q.Address := Capacity_Bytes;
      ID  : W25Q.JEDEC_ID;
   begin
      if Cap = 0 then                       --  auto-detect from the JEDEC id
         W25Q.Read_Identification (Flash, ID);
         Cap := W25Q.Capacity_Bytes (ID);
         if Cap = 0 then
            raise Unknown_Capacity
              with "W25Q_Source: could not detect flash size from JEDEC id";
         end if;
      end if;
      Src.Flash := Flash;
      Src.Count := Sector_Index (Cap / Sector_Bytes);
      Src.Buf   := (others => 16#FF#);
   end Configure;

   function Make (Src : not null access Source) return Device is
   begin
      return (Ctx   => Src.all'Address,
              Read  => Do_Read'Access,
              Write => Do_Write'Access,
              Count => Do_Count'Access,
              Erase => Do_Erase'Access);
   end Make;

end ESP32S3.Block_Dev.W25Q_Source;
