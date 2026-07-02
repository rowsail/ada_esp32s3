with Ada.Unchecked_Deallocation;
with Ada.IO_Exceptions;
with Interfaces;

package body ESP32S3.Ext4.Block_Cache is

   use type Interfaces.Unsigned_64;
   use type ESP32S3.Block_Dev.Sector_Index;

   procedure Free is new Ada.Unchecked_Deallocation (Meta_Array, Meta_Ptr);
   procedure Free is new Ada.Unchecked_Deallocation (Byte_Array, Bytes_Ptr);

   --  Byte range of entry E within the pool.
   function Lo (C : Cache; E : Natural) return Natural
   is (E * C.BS);

   --  First 512-byte sector of filesystem block B.
   function Base_Sector
     (C : Cache; B : Block_Number) return ESP32S3.Block_Dev.Sector_Index
   is (ESP32S3.Block_Dev.Sector_Index (B)
       * ESP32S3.Block_Dev.Sector_Index (C.Spb));

   ----------
   -- Init --
   ----------

   procedure Init
     (C          : in out Cache;
      Dev        : ESP32S3.Block_Dev.Device;
      Block_Size : Positive;
      Entries    : Positive := 32) is
   begin
      if Block_Size mod 512 /= 0 then
         raise Ada.IO_Exceptions.Use_Error
           with "block size not a multiple of 512";
      end if;
      C.Dev := Dev;
      C.BS := Block_Size;
      C.Spb := Block_Size / 512;
      C.Count := Entries;
      C.Clock := 0;
      C.Meta := new Meta_Array (0 .. Entries - 1);
      C.Pool := new Byte_Array (0 .. Entries * Block_Size - 1);
   end Init;

   ----------------
   -- Block_Size --
   ----------------

   function Block_Size (C : Cache) return Natural
   is (C.BS);

   --------------------
   -- Internal moves --
   --------------------

   --  Pull filesystem block Meta(E).Tag from the device into entry E's pool slot.
   procedure Load (C : in out Cache; E : Natural) is
      Base : constant ESP32S3.Block_Dev.Sector_Index :=
        Base_Sector (C, C.Meta (E).Tag);
      Sec  : ESP32S3.Block_Dev.Sector;
      Dst  : Natural := Lo (C, E);
   begin
      for S in 0 .. C.Spb - 1 loop
         ESP32S3.Block_Dev.Read_Sector
           (C.Dev, Base + ESP32S3.Block_Dev.Sector_Index (S), Sec);
         C.Pool (Dst .. Dst + 511) := Byte_Array (Sec);
         Dst := Dst + 512;
      end loop;
   end Load;

   --  Push entry E's pool slot back to the device.
   procedure Store (C : in out Cache; E : Natural) is
      Base : constant ESP32S3.Block_Dev.Sector_Index :=
        Base_Sector (C, C.Meta (E).Tag);
      Sec  : ESP32S3.Block_Dev.Sector;
      Src  : Natural := Lo (C, E);
   begin
      for S in 0 .. C.Spb - 1 loop
         Sec := ESP32S3.Block_Dev.Sector (C.Pool (Src .. Src + 511));
         ESP32S3.Block_Dev.Write_Sector
           (C.Dev, Base + ESP32S3.Block_Dev.Sector_Index (S), Sec);
         Src := Src + 512;
      end loop;
   end Store;

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

      C.Meta (Victim) :=
        (Tag => B, Valid => True, Dirty => False, Used => C.Clock);
      Load (C, Victim);
      return Victim;
   end Acquire;

   ----------
   -- Read --
   ----------

   procedure Read (C : in out Cache; B : Block_Number; Into : out Byte_Array)
   is
      E   : constant Natural := Acquire (C, B);
      Lo0 : constant Natural := Lo (C, E);
   begin
      Into := C.Pool (Lo0 .. Lo0 + C.BS - 1);
   end Read;

   -------------
   -- Read_At --
   -------------

   procedure Read_At
     (C         : in out Cache;
      B         : Block_Number;
      Block_Off : Natural;
      Into      : out Byte_Array) is
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

   procedure Write_At
     (C         : in out Cache;
      B         : Block_Number;
      Block_Off : Natural;
      From      : Byte_Array) is
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
     (C : in out Cache; Visit : not null access procedure (B : Block_Number))
   is
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

   procedure Dirty_Tags
     (C : in out Cache; Into : out Block_List; Count : out Natural) is
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
      Free (C.Meta);
      Free (C.Pool);
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
