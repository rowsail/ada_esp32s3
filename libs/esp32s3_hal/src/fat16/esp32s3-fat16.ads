with Interfaces;
with ESP32S3.Block_Dev;

--  A pure-Ada FAT16 reader with long-filename (VFAT) support.
--
--  The filesystem to reach for when a PC has to see the medium.  A device that
--  exposes its storage over USB mass storage (ESP32S3.USB.MSC) appears as a
--  removable drive; format it FAT and Windows, macOS and Linux all mount it
--  with no driver and no ceremony, the user drops files on it, and the device
--  reads them back.  ESP32S3.Ext4 is the better filesystem, but only Linux
--  mounts it.
--
--  Scope is deliberately narrow: FAT16 only, READ ONLY, plus the separate
--  ESP32S3.Fat16.Mkfs child that lays down an empty volume on blank media.
--  Files are read, never written -- the PC writes them.  FAT12 and FAT32
--  volumes are recognised and REJECTED rather than misread, so wrongly
--  formatted media fails loudly instead of returning plausible rubbish.
--
--  FAT16 addresses up to 65524 clusters, which at the 64 KB maximum cluster
--  size is 4 GB -- ample for the SPI NOR parts (ESP32S3.W25Q) this is aimed at,
--  and for a small SD card.
--
--  Long filenames are read, and preferred over the 8.3 alias: real payload
--  names ("partition-table.bin" is 19 characters) have no faithful short form.
--  Names come back as Latin-1 -- the LFN on-disk encoding is UCS-2, and code
--  points above 255 become '?'.
--
--  The volume is reached through the ESP32S3.Block_Dev vtable -- the same seam
--  the ext4 stack uses -- so it runs over ESP32S3.Block_Dev.W25Q_Source or an
--  SD card on target, and over a file-backed device in the host test harness.
--  Nothing is allocated: all state lives in the caller's Volume, Search and
--  File objects.
--
--  NOT task-safe: one Volume is for one user at a time (it carries a
--  single-sector FAT cache).  Block-level access is also EXCLUSIVE with the USB
--  mass-storage path -- the host and the device must not hold the volume at
--  once, or their caches corrupt each other.  Hand the medium over before
--  exposing it, exactly as ESP32S3.USB.MSC warns.
--
--  Embedded/full profiles only: it raises and returns String, so it needs
--  exceptions and a secondary stack.

package ESP32S3.Fat16 is

   --  Positive-indexed on purpose: Read reports an empty result as
   --  Last = Into'First - 1, which must stay a valid Natural.
   type Byte_Array is array (Positive range <>) of Interfaces.Unsigned_8;

   type Status_Kind is
     (Ok,
      Not_Formatted,   --  no recognisable boot sector / partition table
      Unsupported,     --  a FAT volume, but FAT12, FAT32 or exFAT
      Bad_Data,        --  structurally corrupt: bad cluster chain, short read
      Not_Found,       --  no such path
      Not_A_File,      --  the path names a directory where a file was wanted
      Name_Too_Long,   --  a path component longer than Max_Name_Length
      Device_Failed);  --  the block device raised on read

   --  The longest name we reconstruct.  FAT's own LFN limit is 255
   --  characters, spread over up to 20 directory slots of 13 characters.
   Max_Name_Length : constant := 255;

   --  ------------------------------------------------------------------
   --  Volumes
   --  ------------------------------------------------------------------
   type Volume is limited private;

   --  Read the volume's layout from Device.  Accepts either an MBR-partitioned
   --  disk (the first FAT16 partition is used -- what Windows expects on a USB
   --  stick) or a "superfloppy" whose boot sector is at LBA 0.  Device must
   --  stay valid and unchanged for as long as Vol is used.
   procedure Mount
     (Vol    : out Volume;
      Device : ESP32S3.Block_Dev.Device;
      Status : out Status_Kind);

   function Is_Mounted (Vol : Volume) return Boolean;

   --  The volume label, trailing blanks trimmed ("" when the volume has none).
   function Label (Vol : Volume) return String
   with Post => Label'Result'Length <= 11;

   --  Capacity and free space of the data area, in bytes.  Free_Bytes walks
   --  the whole file allocation table (a few tens of sectors), so it is a
   --  deliberate call, not an attribute to poll.
   function Total_Bytes (Vol : Volume) return Interfaces.Unsigned_64;
   function Free_Bytes (Vol : in out Volume) return Interfaces.Unsigned_64;

   --  Geometry, for callers that care (Mkfs's tests, diagnostics).
   function Cluster_Bytes (Vol : Volume) return Natural;
   function Cluster_Count (Vol : Volume) return Natural;

   --  ------------------------------------------------------------------
   --  Directory entries
   --  ------------------------------------------------------------------
   type Directory_Entry is private;

   --  The entry's name: its long name where it has one, otherwise its 8.3
   --  short name with the trailing blanks removed and the dot restored.
   function Name (Item : Directory_Entry) return String
   with Post => Name'Result'Length <= Max_Name_Length;

   function Size (Item : Directory_Entry) return Interfaces.Unsigned_32;
   function Is_Directory (Item : Directory_Entry) return Boolean;
   function Is_Read_Only (Item : Directory_Entry) return Boolean;
   function Is_Hidden (Item : Directory_Entry) return Boolean;

   --  ------------------------------------------------------------------
   --  Listing a directory
   --  ------------------------------------------------------------------
   --
   --     Start_Search (Volume, "/", Scan, Status);
   --     loop
   --        Next_Entry (Volume, Scan, Item, Found);
   --        exit when not Found;
   --        Put_Line (Name (Item));
   --     end loop;
   --
   --  Volume labels, the "." and ".." links and deleted entries are skipped;
   --  everything else is reported, directories included.
   type Search is private;

   --  Path names a directory; "" and "/" both mean the root.  Separators may
   --  be '/' or '\'.
   procedure Start_Search
     (Vol    : in out Volume;
      Path   : String;
      Result : out Search;
      Status : out Status_Kind);

   procedure Next_Entry
     (Vol    : in out Volume;
      Result : in out Search;
      Item   : out Directory_Entry;
      Found  : out Boolean);

   --  ------------------------------------------------------------------
   --  Reading a file
   --  ------------------------------------------------------------------
   type File is private;

   --  Open Path for reading.  Name matching is case-insensitive (FAT's own
   --  rule) and matches against the long name where there is one, the short
   --  name otherwise.
   procedure Open
     (Vol      : in out Volume;
      Path     : String;
      The_File : out File;
      Status   : out Status_Kind);

   function Is_Open (The_File : File) return Boolean;
   function Size (The_File : File) return Interfaces.Unsigned_32;
   function Position (The_File : File) return Interfaces.Unsigned_32;
   function At_End (The_File : File) return Boolean;

   --  Read up to Into'Length bytes from the current position.  Last is the
   --  index in Into of the final byte read, Into'First - 1 at end of file.  A
   --  short read means end of file, never a transient condition.
   procedure Read
     (Vol      : in out Volume;
      The_File : in out File;
      Into     : out Byte_Array;
      Last     : out Natural)
   with Pre => Is_Open (The_File), Post => Last <= Into'Last;

   --  Move to an absolute byte offset.  Seeking to Size (The_File) is legal
   --  and leaves the file at end; beyond it is Bad_Data.
   procedure Seek
     (Vol      : in out Volume;
      The_File : in out File;
      To       : Interfaces.Unsigned_32;
      Status   : out Status_Kind)
   with Pre => Is_Open (The_File);

   --  Convenience: open Path, read the whole file into Into, close it.  Last
   --  is the final byte index used.  Too small a buffer is Bad_Data, so a
   --  truncated read is never mistaken for a complete one.
   procedure Read_File
     (Vol    : in out Volume;
      Path   : String;
      Into   : out Byte_Array;
      Last   : out Natural;
      Status : out Status_Kind);

private

   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;

   subtype Cluster_Index is Interfaces.Unsigned_16;

   --  FAT16 reserves 0 and 1; 0xFFF8 .. 0xFFFF end a chain and 0xFFF7 marks a
   --  bad cluster, so the largest usable cluster number is 0xFFF6.
   First_Data_Cluster : constant Cluster_Index := 2;
   Bad_Cluster        : constant Cluster_Index := 16#FFF7#;
   End_Of_Chain       : constant Cluster_Index := 16#FFF8#;

   No_Sector : constant ESP32S3.Block_Dev.Sector_Index :=
     ESP32S3.Block_Dev.Sector_Index'Last;

   type Volume is limited record
      Device : ESP32S3.Block_Dev.Device;
      Ready  : Boolean := False;

      --  Layout, all as absolute LBAs on the device (the partition's offset
      --  is already folded in, so nothing downstream has to remember it).
      Fat_Start           : ESP32S3.Block_Dev.Sector_Index := 0;
      Fat_Sectors         : Natural := 0;
      Fat_Copies          : Natural := 0;
      Root_Start          : ESP32S3.Block_Dev.Sector_Index := 0;
      Root_Sectors        : Natural := 0;
      Root_Entries        : Natural := 0;
      Data_Start          : ESP32S3.Block_Dev.Sector_Index := 0;
      Sectors_Per_Cluster : Natural := 0;
      Clusters            : Natural := 0;

      Volume_Label : String (1 .. 11) := (others => ' ');

      --  One cached FAT sector.  Walking a chain otherwise re-reads the same
      --  sector for every cluster, and on NOR flash that is the whole cost of
      --  a sequential read.
      Fat_Cache     : ESP32S3.Block_Dev.Sector := (others => 0);
      Fat_Cache_LBA : ESP32S3.Block_Dev.Sector_Index := No_Sector;
   end record;

   type Directory_Entry is record
      Text          : String (1 .. Max_Name_Length) := (others => ' ');
      Text_Last     : Natural := 0;
      Bytes         : Interfaces.Unsigned_32 := 0;
      Start_Cluster : Cluster_Index := 0;
      Attributes    : Interfaces.Unsigned_8 := 0;
   end record;

   --  Where a directory scan has got to.  The root directory is a fixed run
   --  of sectors and has no cluster chain, so Cluster is 0 there and the scan
   --  simply runs to Root_Sectors.
   type Search is record
      Active     : Boolean := False;
      In_Root    : Boolean := True;
      Cluster    : Cluster_Index := 0;   --  current cluster (subdirectories)
      Sector_Num : Natural :=
        0;         --  sector within cluster, or within root
      Index      : Natural := 0;         --  32-byte slot within that sector
   end record;

   type File is record
      Open_For_Read : Boolean := False;
      Bytes         : Interfaces.Unsigned_32 := 0;
      Offset        : Interfaces.Unsigned_32 := 0;
      First_Cluster : Cluster_Index := 0;
      Cluster       : Cluster_Index := 0;  --  cluster holding Offset
      Cluster_Base  : Interfaces.Unsigned_32 := 0;  --  file offset of Cluster
   end record;

end ESP32S3.Fat16;

