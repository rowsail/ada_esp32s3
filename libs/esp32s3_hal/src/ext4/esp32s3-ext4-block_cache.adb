with Ada.Unchecked_Deallocation;
with Ada.IO_Exceptions;
with Interfaces;

with System.Storage_Elements; use System.Storage_Elements;
package body ESP32S3.Ext4.Block_Cache is

   use type System.Address;

   use type Interfaces.Unsigned_64;
   use type ESP32S3.Block_Dev.Sector_Index;

   procedure Free is new Ada.Unchecked_Deallocation (Meta_Array, Meta_Ptr);
   procedure Free is new Ada.Unchecked_Deallocation (Byte_Array, Bytes_Ptr);

   function C_Malloc (Size : Interfaces.Unsigned_32) return System.Address
     with Import, Convention => C, External_Name => "malloc";
   procedure C_Free (Ptr : System.Address)
     with Import, Convention => C, External_Name => "free";

   overriding procedure Allocate
     (P         : in out Cache_Pool;
      Addr      : out System.Address;
      Size      : Storage_Count;
      Alignment : Storage_Count) is
      use type System.Address;
   begin
      if P.Base = System.Null_Address then
         Addr := C_Malloc (Interfaces.Unsigned_32 (Size));
         if Addr = System.Null_Address then
            raise Storage_Error with "ext4 cache: heap exhausted";
         end if;
         return;
      end if;
      declare
         Start : constant Storage_Count :=
           (P.Next + Alignment - 1) / Alignment * Alignment;
      begin
         if Start + Size > P.Size then
            raise Storage_Error with "ext4 cache: caller storage too small";
         end if;
         Addr := P.Base + Start;
         P.Next := Start + Size;
      end;
   end Allocate;

   overriding procedure Deallocate
     (P         : in out Cache_Pool;
      Addr      : System.Address;
      Size      : Storage_Count;
      Alignment : Storage_Count) is
      pragma Unreferenced (Size, Alignment);
      use type System.Address;
   begin
      --  Caller storage is never freed; heap blocks are.
      if P.Base = System.Null_Address then
         C_Free (Addr);
      end if;
   end Deallocate;

   overriding function Storage_Size (P : Cache_Pool) return Storage_Count
   is (if P.Base = System.Null_Address then Storage_Count'Last else P.Size);

   --  Byte range of entry E within the pool.
   function Lo (C : Cache; E : Natural) return Natural
   is (E * C.BS);

   --  First 512-byte sector of filesystem block B.
   function Base_Sector (C : Cache; B : Block_Number) return ESP32S3.Block_Dev.Sector_Index
   is (ESP32S3.Block_Dev.Sector_Index (B) * ESP32S3.Block_Dev.Sector_Index (C.Spb));

   ----------
   -- Init --
   ----------

   function Meta_Bytes (Entries : Positive) return Natural is
      Sample : constant Meta_Array (0 .. Entries - 1) := (others => <>);
   begin
      return Sample'Size / 8;
   end Meta_Bytes;

   procedure Init
     (C          : in out Cache;
      Dev        : ESP32S3.Block_Dev.Device;
      Block_Size : Positive;
      Entries    : Positive := 32;
      Storage    : System.Address := System.Null_Address;
      Storage_Bytes : Natural := 0) is
      use type System.Address;
      Need_Meta : constant Natural := Meta_Bytes (Entries);
      Need_Data : constant Natural := Entries * Block_Size;
   begin
      if Block_Size mod 512 /= 0 then
         raise Ada.IO_Exceptions.Use_Error with "block size not a multiple of 512";
      end if;
      C.Dev := Dev;
      C.BS := Block_Size;
      C.Spb := Block_Size / 512;
      C.Count := Entries;
      C.Clock := 0;
      --  Point the pool at caller storage (or leave it on the heap), then
      --  allocate normally so the arrays carry proper bounds.
      if Storage /= System.Null_Address then
         if Storage_Bytes < Need_Meta + Need_Data then
            raise Ada.IO_Exceptions.Use_Error with "cache storage too small";
         end if;
         The_Pool.Base := Storage;
         The_Pool.Size := Storage_Count (Storage_Bytes);
         The_Pool.Next := 0;
         C.Owns_Storage := False;
      else
         The_Pool.Base := System.Null_Address;
         C.Owns_Storage := True;
      end if;
      C.Meta := new Meta_Array (0 .. Entries - 1);
      C.Pool := new Byte_Array (0 .. Entries * Block_Size - 1);
      C.Meta.all := (others => <>);
   end Init;

   ----------------
   -- Block_Size --
   ----------------

   function Block_Size (C : Cache) return Natural
   is (C.BS);

   --------------------
   -- Internal moves --
   --------------------

   --  Pull filesystem block Meta(E).Tag from the device into entry E's pool
   --  slot.  One run read straight into the slot: on SD the fixed cost is per
   --  COMMAND (the card's ~2 ms access latency), so fetching a 4 KiB block as
   --  eight one-sector commands was ~8x slower than this single command.
   procedure Load (C : in out Cache; E : Natural) is
      Base : constant ESP32S3.Block_Dev.Sector_Index := Base_Sector (C, C.Meta (E).Tag);
      Run  : ESP32S3.Block_Dev.Sector_Run (0 .. C.BS - 1)
        with Import, Address => C.Pool (Lo (C, E))'Address;
   begin
      ESP32S3.Block_Dev.Read_Sectors (C.Dev, Base, Run);
   end Load;

   --  Push entry E's pool slot back to the device, as one run write (see
   --  Load above for why one command per block, not one per sector).
   procedure Store (C : in out Cache; E : Natural) is
      Base : constant ESP32S3.Block_Dev.Sector_Index := Base_Sector (C, C.Meta (E).Tag);
      Run  : ESP32S3.Block_Dev.Sector_Run (0 .. C.BS - 1)
        with Import, Address => C.Pool (Lo (C, E))'Address;
   begin
      ESP32S3.Block_Dev.Write_Sectors (C.Dev, Base, Run);
   end Store;

   --------------
   -- Resident --
   --------------

   function Resident (C : Cache; B : Block_Number) return Boolean is
   begin
      for E in 0 .. C.Count - 1 loop
         if C.Meta (E).Valid and then C.Meta (E).Tag = B then
            return True;
         end if;
      end loop;
      return False;
   end Resident;

   --  Find block B, loading + evicting as needed; return its entry index.
   function Acquire (C : in out Cache; B : Block_Number) return Natural is
      Victim : Natural := 0;
   begin
      C.Clock := C.Clock + 1;

      --  Already resident?
      for E in 0 .. C.Count - 1 loop
         if C.Meta (E).Valid and then C.Meta (E).Tag = B then
            C.Meta (E).Used := C.Clock;
            return E;
         end if;
      end loop;

      --  Choose a victim: a free slot, else the least-recently-used.
      for E in 0 .. C.Count - 1 loop
         if not C.Meta (E).Valid then
            Victim := E;
            exit;
         end if;
         if C.Meta (E).Used < C.Meta (Victim).Used then
            Victim := E;
         end if;
      end loop;

      if C.Meta (Victim).Valid and then C.Meta (Victim).Dirty then
         Store (C, Victim);
      end if;

      C.Meta (Victim) := (Tag => B, Valid => True, Dirty => False, Used => C.Clock);
      Load (C, Victim);
      return Victim;
   end Acquire;

   ----------
   -- Read --
   ----------

   procedure Read (C : in out Cache; B : Block_Number; Into : out Byte_Array) is
      E   : constant Natural := Acquire (C, B);
      Lo0 : constant Natural := Lo (C, E);
   begin
      Into := C.Pool (Lo0 .. Lo0 + C.BS - 1);
   end Read;

   -------------
   -- Read_At --
   -------------

   procedure Read_At
     (C : in out Cache; B : Block_Number; Block_Off : Natural; Into : out Byte_Array) is
   begin
      --  Enforce the contract here (overflow-safely, before computing the pool
      --  index): the pool is one contiguous array, so an offset/length that
      --  escapes this block would silently read the NEXT cached block.  A length
      --  drawn from on-disk data must raise Corrupt, not cross blocks.
      if Block_Off > C.BS or else Into'Length > C.BS - Block_Off then
         raise Corrupt with "ext4 block_cache: read past block boundary";
      end if;
      declare
         E : constant Natural := Acquire (C, B);
         P : constant Natural := Lo (C, E) + Block_Off;
      begin
         Into := C.Pool (P .. P + Into'Length - 1);
      end;
   end Read_At;

   --------------
   -- Write_At --
   --------------

   procedure Write_At (C : in out Cache; B : Block_Number; Block_Off : Natural; From : Byte_Array)
   is
   begin
      if Block_Off > C.BS or else From'Length > C.BS - Block_Off then
         raise Corrupt with "ext4 block_cache: write past block boundary";
      end if;
      declare
         E : constant Natural := Acquire (C, B);
         P : constant Natural := Lo (C, E) + Block_Off;
      begin
         C.Pool (P .. P + From'Length - 1) := From;
         C.Meta (E).Dirty := True;
      end;
   end Write_At;

   -----------
   -- Write --
   -----------

   procedure Write (C : in out Cache; B : Block_Number; From : Byte_Array) is
      E   : constant Natural := Acquire (C, B);
      Lo0 : constant Natural := Lo (C, E);
   begin
      C.Pool (Lo0 .. Lo0 + C.BS - 1) := From;
      C.Meta (E).Dirty := True;
   end Write;

   -----------
   -- Flush --
   -----------

   procedure Flush (C : in out Cache) is
   begin
      for E in 0 .. C.Count - 1 loop
         if C.Meta (E).Valid and then C.Meta (E).Dirty then
            Store (C, E);
            C.Meta (E).Dirty := False;
         end if;
      end loop;
   end Flush;

   --------------------
   -- For_Each_Dirty --
   --------------------

   procedure For_Each_Dirty
     (C : in out Cache; Visit : not null access procedure (B : Block_Number)) is
   begin
      for E in 0 .. C.Count - 1 loop
         if C.Meta (E).Valid and then C.Meta (E).Dirty then
            Visit (C.Meta (E).Tag);
         end if;
      end loop;
   end For_Each_Dirty;

   ----------------
   -- Dirty_Tags --
   ----------------

   procedure Dirty_Tags (C : in out Cache; Into : out Block_List; Count : out Natural) is
   begin
      Count := 0;
      for E in 0 .. C.Count - 1 loop
         if C.Meta (E).Valid and then C.Meta (E).Dirty then
            exit when Count >= Into'Length;
            Count := Count + 1;
            Into (Into'First + Count - 1) := C.Meta (E).Tag;
         end if;
      end loop;
   end Dirty_Tags;

   ----------
   -- Drop --
   ----------

   procedure Drop (C : in out Cache) is
   begin
      if C.Owns_Storage then
         Free (C.Meta);
         Free (C.Pool);
      else
         C.Meta := null;   --  caller-owned: detach, never deallocate
         C.Pool := null;
      end if;
      C.Count := 0;
      C.BS := 0;
      C.Spb := 0;
   end Drop;

   ----------
   -- Done --
   ----------

   procedure Done (C : in out Cache) is
   begin
      if C.Count > 0 then
         Flush (C);
      end if;
      Drop (C);
   end Done;

end ESP32S3.Ext4.Block_Cache;
