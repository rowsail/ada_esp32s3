with ESP32S3.Block_Dev;

--  A small write-back LRU cache of filesystem blocks over a Block_Dev.Device.
--
--  The filesystem block size (1 KiB .. 64 KiB, a power of two and a multiple of
--  the 512-byte sector) is fixed at Init from the superblock.  Storage is
--  heap-allocated (embedded/full have a heap); buffers may live in PSRAM since
--  the SD backend copies to internal-SRAM scratch itself.
--
--  Copy-in / copy-out interface: callers overlay on-disk record types onto their
--  own block buffer.  Dirty blocks are written back on eviction and on Flush.

package ESP32S3.Ext4.Block_Cache is

   type Cache is limited private;

   --  Bring up a cache of Entries blocks of Block_Size bytes over Dev.
   --  Block_Size must be a multiple of 512.
   procedure Init
     (C          : in out Cache;
      Dev        : ESP32S3.Block_Dev.Device;
      Block_Size : Positive;
      Entries    : Positive := 32);

   --  The configured filesystem block size in bytes.
   function Block_Size (C : Cache) return Natural;

   --  Copy filesystem block B into Into (Into'Length must equal Block_Size).
   procedure Read (C : in out Cache; B : Block_Number; Into : out Byte_Array);

   --  Copy Into'Length bytes from offset Block_Off of block B into Into
   --  (Block_Off + Into'Length must be <= Block_Size).  Lets callers read just
   --  the field/entry/chunk they need without a block-sized stack buffer.
   procedure Read_At
     (C         : in out Cache;
      B         : Block_Number;
      Block_Off : Natural;
      Into      : out Byte_Array);

   --  Replace Into'Length bytes at offset Block_Off of block B (and mark dirty).
   procedure Write_At
     (C         : in out Cache;
      B         : Block_Number;
      Block_Off : Natural;
      From      : Byte_Array);

   --  Replace cached block B with From (length = Block_Size) and mark it dirty;
   --  written back on eviction or Flush.
   procedure Write (C : in out Cache; B : Block_Number; From : Byte_Array);

   --  Write every dirty block back to the device.
   procedure Flush (C : in out Cache);

   --  Visit the block number of every currently-dirty entry (the pending
   --  write-set, for journaling it).  The callback must not evict (it may read
   --  the dirty blocks themselves -- those are resident hits).
   procedure For_Each_Dirty
     (C : in out Cache; Visit : not null access procedure (B : Block_Number));

   --  Callback-free variant of For_Each_Dirty: fill Into with the tags of the
   --  currently-dirty entries (up to Into'Length) and set Count.  Preferred on
   --  targets whose stacks are non-executable, where 'Access of a nested
   --  collector passed to For_Each_Dirty would need an unavailable trampoline.
   type Block_List is array (Positive range <>) of Block_Number;
   procedure Dirty_Tags
     (C : in out Cache; Into : out Block_List; Count : out Natural);

   --  Flush, then release all heap storage (cache unusable until re-Init).
   procedure Done (C : in out Cache);

   --  Release all storage WITHOUT flushing (discard volatile state -- used to
   --  simulate a crash in the journal tests).
   procedure Drop (C : in out Cache);

private

   type Entry_Meta is record
      Tag   : Block_Number := 0;
      Valid : Boolean := False;
      Dirty : Boolean := False;
      Used  : U64 := 0;       --  LRU clock stamp
   end record;

   type Meta_Array is array (Natural range <>) of Entry_Meta;
   type Meta_Ptr is access Meta_Array;
   type Bytes_Ptr is access Byte_Array;

   type Cache is limited record
      Dev   : ESP32S3.Block_Dev.Device;
      BS    : Natural := 0;       --  block size, bytes
      Spb   : Natural := 0;       --  512-byte sectors per block
      Count : Natural := 0;       --  number of entries
      Clock : U64 := 0;       --  monotonic LRU stamp
      Meta  : Meta_Ptr := null;  --  Count entries, 0-based
      Pool  : Bytes_Ptr := null;  --  Count * BS bytes, 0-based
   end record;

end ESP32S3.Ext4.Block_Cache;
