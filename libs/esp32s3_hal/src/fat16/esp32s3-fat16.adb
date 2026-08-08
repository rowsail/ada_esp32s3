with Ada.IO_Exceptions;

package body ESP32S3.Fat16 is

   use type ESP32S3.Block_Dev.Sector_Index;
   use type Interfaces.Unsigned_64;

   package Blocks renames ESP32S3.Block_Dev;

   Sector_Bytes     : constant := 512;
   Slot_Bytes       : constant := 32;      --  one directory entry
   Slots_Per_Sector : constant := Sector_Bytes / Slot_Bytes;

   --  Directory attribute bits (FAT specification names in the comments).
   Attr_Read_Only : constant Interfaces.Unsigned_8 := 16#01#;
   Attr_Hidden    : constant Interfaces.Unsigned_8 := 16#02#;
   Attr_Volume_Id : constant Interfaces.Unsigned_8 := 16#08#;
   Attr_Directory : constant Interfaces.Unsigned_8 := 16#10#;

   --  A slot whose attribute byte is exactly this is a long-name fragment,
   --  not a file: read-only + hidden + system + volume-id together, a
   --  combination no real entry ever carries.  That is precisely why the VFAT
   --  designers chose it -- MS-DOS skips such slots without understanding them.
   Attr_Long_Name : constant Interfaces.Unsigned_8 := 16#0F#;

   --  Characters a single long-name slot carries, split 5 + 6 + 2 around the
   --  fields the slot shares with the 8.3 entry layout it is disguised as.
   Chars_Per_Slot : constant := 13;
   Max_Name_Slots : constant := 20;    --  20 * 13 = 260, so 255 always fits

   ---------------------------------------------------------------------------
   --  Little-endian field access
   ---------------------------------------------------------------------------

   function Get_8
     (Data : Blocks.Sector; Offset : Natural) return Interfaces.Unsigned_8
   is (Data (Offset));

   function Get_16
     (Data : Blocks.Sector; Offset : Natural) return Interfaces.Unsigned_16
   is (Interfaces.Unsigned_16 (Data (Offset))
       or Interfaces.Shift_Left
            (Interfaces.Unsigned_16 (Data (Offset + 1)), 8));

   function Get_32
     (Data : Blocks.Sector; Offset : Natural) return Interfaces.Unsigned_32
   is (Interfaces.Unsigned_32 (Data (Offset))
       or Interfaces.Shift_Left (Interfaces.Unsigned_32 (Data (Offset + 1)), 8)
       or Interfaces.Shift_Left
            (Interfaces.Unsigned_32 (Data (Offset + 2)), 16)
       or Interfaces.Shift_Left
            (Interfaces.Unsigned_32 (Data (Offset + 3)), 24));

   ---------------------------------------------------------------------------
   --  Device access.  The block layer raises on an I/O failure; every read
   --  goes through here so a failure becomes a Status_Kind at the one place
   --  rather than escaping into the caller's control flow.
   ---------------------------------------------------------------------------

   procedure Fetch
     (Vol     : Volume;
      LBA     : Blocks.Sector_Index;
      Data    : out Blocks.Sector;
      Success : out Boolean) is
   begin
      Blocks.Read_Sector (Vol.Device, LBA, Data);
      Success := True;
   exception
      when Ada.IO_Exceptions.Device_Error =>
         Data := (others => 0);
         Success := False;
   end Fetch;

   ---------------------------------------------------------------------------
   --  The file allocation table
   ---------------------------------------------------------------------------

   --  The entry for Cluster, through the one-sector cache.
   procedure Fat_Entry
     (Vol     : in out Volume;
      Cluster : Cluster_Index;
      Value   : out Cluster_Index;
      Success : out Boolean)
   is
      Byte_Offset : constant Natural := Natural (Cluster) * 2;
      LBA         : constant Blocks.Sector_Index :=
        Vol.Fat_Start + Blocks.Sector_Index (Byte_Offset / Sector_Bytes);
   begin
      Value := 0;
      if Natural (Cluster) >= Vol.Clusters + Natural (First_Data_Cluster) then
         Success := False;
         return;
      end if;

      if Vol.Fat_Cache_LBA /= LBA then
         Fetch (Vol, LBA, Vol.Fat_Cache, Success);
         if not Success then
            Vol.Fat_Cache_LBA := No_Sector;
            return;
         end if;
         Vol.Fat_Cache_LBA := LBA;
      end if;

      Value :=
        Cluster_Index (Get_16 (Vol.Fat_Cache, Byte_Offset mod Sector_Bytes));
      Success := True;
   end Fat_Entry;

   --  Advance along a chain.  Last is set when Cluster ends it; a chain that
   --  runs into a free or bad cluster is corruption, reported as not-Success.
   procedure Next_Cluster
     (Vol     : in out Volume;
      Cluster : Cluster_Index;
      Value   : out Cluster_Index;
      Last    : out Boolean;
      Success : out Boolean)
   is
      Link : Cluster_Index;
   begin
      Value := 0;
      Last := False;
      Fat_Entry (Vol, Cluster, Link, Success);
      if not Success then
         return;
      end if;

      if Link >= End_Of_Chain then
         Last := True;
      elsif Link < First_Data_Cluster
        or else Link = Bad_Cluster
        or else Natural (Link) >= Vol.Clusters + Natural (First_Data_Cluster)
      then
         Success := False;
      else
         Value := Link;
      end if;
   end Next_Cluster;

   --  First sector of a data cluster.
   function Cluster_Start
     (Vol : Volume; Cluster : Cluster_Index) return Blocks.Sector_Index
   is (Vol.Data_Start
       + Blocks.Sector_Index (Natural (Cluster) - Natural (First_Data_Cluster))
         * Blocks.Sector_Index (Vol.Sectors_Per_Cluster));

   --  Cluster sizes are powers of two by definition; anything else means we
   --  are not looking at a real BPB.
   function Is_Power_Of_Two (Value : Natural) return Boolean
   is (Value > 0
       and then (Interfaces.Unsigned_32 (Value)
                 and (Interfaces.Unsigned_32 (Value) - 1))
                = 0);

   ---------------------------------------------------------------------------
   --  Names
   ---------------------------------------------------------------------------

   --  The checksum a long-name slot carries so it can be tied to the 8.3 entry
   --  that follows it.  Any mismatch means the two disagree -- a volume edited
   --  by something that did not understand long names -- and the long name is
   --  then discarded in favour of the short one.
   function Short_Name_Checksum
     (Raw : Blocks.Sector; Offset : Natural) return Interfaces.Unsigned_8
   is
      Sum : Interfaces.Unsigned_8 := 0;
   begin
      for I in 0 .. 10 loop
         Sum := Interfaces.Rotate_Right (Sum, 1) + Raw (Offset + I);
      end loop;
      return Sum;
   end Short_Name_Checksum;

   --  Render the 11-byte 8.3 field as a displayable name: trailing blanks
   --  dropped, the dot put back, and the two case flags Windows records in the
   --  otherwise-unused NT-reserved byte applied.
   procedure Short_Name
     (Raw    : Blocks.Sector;
      Offset : Natural;
      Text   : out String;
      Last   : out Natural)
   is
      Case_Flags : constant Interfaces.Unsigned_8 := Raw (Offset + 12);
      Lower_Base : constant Boolean := (Case_Flags and 16#08#) /= 0;
      Lower_Ext  : constant Boolean := (Case_Flags and 16#10#) /= 0;
      Base_Last  : Natural := 0;
      Ext_Last   : Natural := 0;

      function Fold (C : Character; Lower : Boolean) return Character
      is (if Lower and then C in 'A' .. 'Z'
          then Character'Val (Character'Pos (C) + 32)
          else C);
   begin
      Last := 0;

      for I in 0 .. 7 loop
         if Raw (Offset + I) /= Character'Pos (' ') then
            Base_Last := I + 1;
         end if;
      end loop;
      for I in 8 .. 10 loop
         if Raw (Offset + I) /= Character'Pos (' ') then
            Ext_Last := I - 8 + 1;
         end if;
      end loop;

      for I in 1 .. Base_Last loop
         Last := Last + 1;
         Text (Text'First + Last - 1) :=
           Fold (Character'Val (Raw (Offset + I - 1)), Lower_Base);
      end loop;

      --  A leading 0xE5 is stored as 0x05, because 0xE5 alone means "deleted".
      if Last > 0 and then Raw (Offset) = 16#05# then
         Text (Text'First) := Character'Val (16#E5#);
      end if;

      if Ext_Last > 0 then
         Last := Last + 1;
         Text (Text'First + Last - 1) := '.';
         for I in 1 .. Ext_Last loop
            Last := Last + 1;
            Text (Text'First + Last - 1) :=
              Fold (Character'Val (Raw (Offset + 8 + I - 1)), Lower_Ext);
         end loop;
      end if;
   end Short_Name;

   function Upper (C : Character) return Character
   is (if C in 'a' .. 'z' then Character'Val (Character'Pos (C) - 32) else C);

   --  FAT names are case-insensitive, so this is what "the same file" means.
   function Same_Name (Left, Right : String) return Boolean is
   begin
      if Left'Length /= Right'Length then
         return False;
      end if;
      for I in 0 .. Left'Length - 1 loop
         if Upper (Left (Left'First + I)) /= Upper (Right (Right'First + I))
         then
            return False;
         end if;
      end loop;
      return True;
   end Same_Name;

   ---------------------------------------------------------------------------
   --  Directory scanning
   ---------------------------------------------------------------------------

   --  State carried across the slots of one entry.  A long name arrives in
   --  slots that PRECEDE the 8.3 entry they belong to, in descending ordinal
   --  order, so the fragments are placed by ordinal rather than appended.
   type Long_Name_State is record
      Valid    : Boolean := False;
      Checksum : Interfaces.Unsigned_8 := 0;
      Text     : String (1 .. Max_Name_Slots * Chars_Per_Slot) :=
        (others => ' ');
      Filled   : Natural := 0;   --  highest character position written
      Ended    : Natural :=
        0;   --  position of the NUL terminator, 0 if unseen
   end record;

   procedure Reset (State : out Long_Name_State) is
   begin
      State :=
        (Valid    => False,
         Checksum => 0,
         Text     => (others => ' '),
         Filled   => 0,
         Ended    => 0);
   end Reset;

   --  Absorb one long-name slot.
   procedure Take_Long_Name_Slot
     (State : in out Long_Name_State; Raw : Blocks.Sector; Offset : Natural)
   is
      --  Byte offsets of the three character runs inside the slot, and how
      --  many characters each holds.
      type Run is record
         At_Byte : Natural;
         Count   : Natural;
      end record;
      Runs : constant array (1 .. 3) of Run := ((1, 5), (14, 6), (28, 2));

      Ordinal : constant Natural := Natural (Raw (Offset) and 16#3F#);
      Is_Last : constant Boolean := (Raw (Offset) and 16#40#) /= 0;
      Base    : Natural;
      Place   : Natural;
      Code    : Interfaces.Unsigned_16;
   begin
      --  The physically-first slot carries the highest ordinal and the flag;
      --  it starts a fresh name.
      if Is_Last then
         Reset (State);
         State.Valid := True;
         State.Checksum := Raw (Offset + 13);
      elsif not State.Valid or else Raw (Offset + 13) /= State.Checksum then
         State.Valid := False;
         return;
      end if;

      if Ordinal not in 1 .. Max_Name_Slots then
         State.Valid := False;
         return;
      end if;

      Base := (Ordinal - 1) * Chars_Per_Slot;
      Place := Base;

      for R of Runs loop
         for I in 0 .. R.Count - 1 loop
            Place := Place + 1;
            Code := Get_16 (Raw, Offset + R.At_Byte + I * 2);
            if Code = 0 then
               if State.Ended = 0 then
                  State.Ended := Place - 1;
               end if;
            elsif Code /= 16#FFFF# then
               State.Text (Place) :=
                 (if Code <= 16#FF#
                  then Character'Val (Code)
                  else
                    '?');   --  beyond Latin-1: keep the slot, lose the glyph
               if Place > State.Filled then
                  State.Filled := Place;
               end if;
            end if;
         end loop;
      end loop;
   end Take_Long_Name_Slot;

   function Long_Name_Length (State : Long_Name_State) return Natural
   is (if State.Ended > 0 then State.Ended else State.Filled);

   --  Read the sector a scan currently points into.  The root directory is a
   --  flat run of sectors; a subdirectory is a cluster chain.
   procedure Scan_Sector
     (Vol     : in out Volume;
      Scan    : Search;
      Data    : out Blocks.Sector;
      Valid   : out Boolean;
      Success : out Boolean) is
   begin
      Data := (others => 0);
      Success := True;
      Valid := False;

      if Scan.In_Root then
         if Scan.Sector_Num >= Vol.Root_Sectors then
            return;
         end if;
         Fetch
           (Vol,
            Vol.Root_Start + Blocks.Sector_Index (Scan.Sector_Num),
            Data,
            Success);
      else
         if Scan.Cluster < First_Data_Cluster then
            return;
         end if;
         Fetch
           (Vol,
            Cluster_Start (Vol, Scan.Cluster)
            + Blocks.Sector_Index (Scan.Sector_Num),
            Data,
            Success);
      end if;
      Valid := Success;
   end Scan_Sector;

   --  Step to the next sector, following the chain out of the current cluster
   --  when a subdirectory runs past its end.  Exhausted says the directory is
   --  finished.
   procedure Advance_Sector
     (Vol       : in out Volume;
      Scan      : in out Search;
      Exhausted : out Boolean;
      Success   : out Boolean)
   is
      Following : Cluster_Index;
      Last      : Boolean;
   begin
      Exhausted := False;
      Success := True;
      Scan.Index := 0;
      Scan.Sector_Num := Scan.Sector_Num + 1;

      if Scan.In_Root then
         Exhausted := Scan.Sector_Num >= Vol.Root_Sectors;
         return;
      end if;

      if Scan.Sector_Num < Vol.Sectors_Per_Cluster then
         return;
      end if;

      Next_Cluster (Vol, Scan.Cluster, Following, Last, Success);
      if not Success or else Last then
         Exhausted := True;
      else
         Scan.Cluster := Following;
         Scan.Sector_Num := 0;
      end if;
   end Advance_Sector;

   ---------------------------------------------------------------------------
   --  Public: volume
   ---------------------------------------------------------------------------

   function Is_Mounted (Vol : Volume) return Boolean
   is (Vol.Ready);

   function Cluster_Bytes (Vol : Volume) return Natural
   is (Vol.Sectors_Per_Cluster * Sector_Bytes);

   function Cluster_Count (Vol : Volume) return Natural
   is (Vol.Clusters);

   function Total_Bytes (Vol : Volume) return Interfaces.Unsigned_64
   is (Interfaces.Unsigned_64 (Vol.Clusters)
       * Interfaces.Unsigned_64 (Cluster_Bytes (Vol)));

   function Label (Vol : Volume) return String is
      Last : Natural := 0;
   begin
      for I in Vol.Volume_Label'Range loop
         if Vol.Volume_Label (I) /= ' ' then
            Last := I;
         end if;
      end loop;
      return Vol.Volume_Label (1 .. Last);
   end Label;

   function Free_Bytes (Vol : in out Volume) return Interfaces.Unsigned_64 is
      Free    : Natural := 0;
      Value   : Cluster_Index;
      Success : Boolean;
   begin
      if not Vol.Ready then
         return 0;
      end if;
      for C in
        Natural (First_Data_Cluster)
        .. Vol.Clusters + Natural (First_Data_Cluster) - 1
      loop
         Fat_Entry (Vol, Cluster_Index (C), Value, Success);
         exit when not Success;
         if Value = 0 then
            Free := Free + 1;
         end if;
      end loop;
      return
        Interfaces.Unsigned_64 (Free)
        * Interfaces.Unsigned_64 (Cluster_Bytes (Vol));
   end Free_Bytes;

   --  Read the label from the root directory's volume-id entry, which is what
   --  Windows rewrites when the volume is renamed (the copy in the boot sector
   --  can go stale).  Absent one, the boot-sector copy already in Vol stands.
   procedure Load_Label_From_Root (Vol : in out Volume) is
      Data    : Blocks.Sector;
      Success : Boolean;
      Attr    : Interfaces.Unsigned_8;
   begin
      for S in 0 .. Vol.Root_Sectors - 1 loop
         Fetch (Vol, Vol.Root_Start + Blocks.Sector_Index (S), Data, Success);
         exit when not Success;
         for Slot in 0 .. Slots_Per_Sector - 1 loop
            declare
               Offset : constant Natural := Slot * Slot_Bytes;
            begin
               exit when Data (Offset) = 0;             --  end of directory
               Attr := Data (Offset + 11);
               if Data (Offset) /= 16#E5#
                 and then Attr /= Attr_Long_Name
                 and then (Attr and Attr_Volume_Id) /= 0
               then
                  for I in 0 .. 10 loop
                     Vol.Volume_Label (I + 1) :=
                       Character'Val (Data (Offset + I));
                  end loop;
                  return;
               end if;
            end;
         end loop;
      end loop;
   end Load_Label_From_Root;

   --  Validate a boot sector and, if it describes a FAT16 volume, record its
   --  layout with Partition_Start folded into every LBA.
   procedure Read_Boot_Sector
     (Vol             : in out Volume;
      Partition_Start : Blocks.Sector_Index;
      Status          : out Status_Kind)
   is
      Data    : Blocks.Sector;
      Success : Boolean;

      Bytes_Per_Sector : Interfaces.Unsigned_16;
      Reserved         : Interfaces.Unsigned_16;
      Total_16         : Interfaces.Unsigned_16;
      Total_32         : Interfaces.Unsigned_32;
      Fat_Size_16      : Interfaces.Unsigned_16;
      Total_Sectors    : Interfaces.Unsigned_32;
      Meta_Sectors     : Interfaces.Unsigned_32;
   begin
      Status := Not_Formatted;

      Fetch (Vol, Partition_Start, Data, Success);
      if not Success then
         Status := Device_Failed;
         return;
      end if;

      if Get_16 (Data, 510) /= 16#AA55# then
         return;
      end if;

      Bytes_Per_Sector := Get_16 (Data, 11);
      Vol.Sectors_Per_Cluster := Natural (Get_8 (Data, 13));
      Reserved := Get_16 (Data, 14);
      Vol.Fat_Copies := Natural (Get_8 (Data, 16));
      Vol.Root_Entries := Natural (Get_16 (Data, 17));
      Total_16 := Get_16 (Data, 19);
      Fat_Size_16 := Get_16 (Data, 22);
      Total_32 := Get_32 (Data, 32);

      --  Is this a BPB at all?  A partition table also ends in 0xAA55, and its
      --  bytes land in these fields as zeros -- so the structural test comes
      --  FIRST, and only a sector that passes it is worth classifying.  Failing
      --  here leaves Not_Formatted, which is the caller's cue to try LBA 0 as a
      --  partition table instead.
      if Bytes_Per_Sector /= Sector_Bytes
        or else not Is_Power_Of_Two (Vol.Sectors_Per_Cluster)
        or else Reserved = 0
        or else Vol.Fat_Copies = 0
      then
         return;
      end if;

      --  It is a FAT BPB.  A FAT32 one zeroes the 16-bit FAT size and the
      --  root-entry count, which is a volume we refuse rather than misread.
      if Fat_Size_16 = 0 or else Vol.Root_Entries = 0 then
         Status := Unsupported;
         return;
      end if;

      Total_Sectors :=
        (if Total_16 /= 0
         then Interfaces.Unsigned_32 (Total_16)
         else Total_32);
      if Total_Sectors = 0 then
         return;
      end if;

      Vol.Fat_Sectors := Natural (Fat_Size_16);
      Vol.Fat_Start := Partition_Start + Blocks.Sector_Index (Reserved);
      Vol.Root_Start :=
        Vol.Fat_Start
        + Blocks.Sector_Index (Vol.Fat_Copies)
          * Blocks.Sector_Index (Vol.Fat_Sectors);
      Vol.Root_Sectors :=
        (Vol.Root_Entries * Slot_Bytes + Sector_Bytes - 1) / Sector_Bytes;
      Vol.Data_Start :=
        Vol.Root_Start + Blocks.Sector_Index (Vol.Root_Sectors);

      Meta_Sectors :=
        Interfaces.Unsigned_32 (Reserved)
        + Interfaces.Unsigned_32 (Vol.Fat_Copies)
          * Interfaces.Unsigned_32 (Vol.Fat_Sectors)
        + Interfaces.Unsigned_32 (Vol.Root_Sectors);
      if Meta_Sectors >= Total_Sectors then
         return;
      end if;

      Vol.Clusters :=
        Natural
          ((Total_Sectors - Meta_Sectors)
           / Interfaces.Unsigned_32 (Vol.Sectors_Per_Cluster));

      --  The cluster count IS the FAT type -- not the "FAT16" string in the
      --  boot sector, which is a comment.  Below 4085 clusters the on-disk
      --  table is 12-bit and every entry we read would be misaligned.
      if Vol.Clusters < 4085 then
         Status := Unsupported;
         return;
      elsif Vol.Clusters > 65524 then
         Status := Unsupported;
         return;
      end if;

      --  The table must be large enough for the clusters the geometry claims.
      if (Vol.Clusters + Natural (First_Data_Cluster)) * 2
        > Vol.Fat_Sectors * Sector_Bytes
      then
         Status := Bad_Data;
         return;
      end if;

      for I in 0 .. 10 loop
         Vol.Volume_Label (I + 1) := Character'Val (Data (43 + I));
      end loop;

      Status := Ok;
   end Read_Boot_Sector;

   procedure Mount
     (Vol    : out Volume;
      Device : ESP32S3.Block_Dev.Device;
      Status : out Status_Kind)
   is
      Data       : Blocks.Sector;
      Success    : Boolean;
      Part_Start : Interfaces.Unsigned_32;
      Part_Type  : Interfaces.Unsigned_8;
   begin
      Vol.Device := Device;
      Vol.Ready := False;
      Vol.Fat_Cache_LBA := No_Sector;

      --  Try a boot sector at LBA 0 first (a "superfloppy", which is what
      --  mkfs.fat writes to a bare device).  Only if that is not a FAT16 boot
      --  sector do we read LBA 0 as a partition table instead -- the layout
      --  Windows expects on a USB stick.
      Read_Boot_Sector (Vol, 0, Status);
      if Status = Ok then
         Load_Label_From_Root (Vol);
         Vol.Ready := True;
         return;
      elsif Status /= Not_Formatted then
         --  There IS a filesystem at LBA 0, it is just not one we read (FAT32,
         --  FAT12) or it is damaged.  Report that, rather than going on to read
         --  its boot sector as a partition table and calling the volume blank.
         return;
      end if;

      Fetch (Vol, 0, Data, Success);
      if not Success then
         Status := Device_Failed;
         return;
      end if;
      if Get_16 (Data, 510) /= 16#AA55# then
         Status := Not_Formatted;
         return;
      end if;

      --  Four 16-byte entries at offset 446.  Take the first FAT16 one.
      for Slot in 0 .. 3 loop
         declare
            Offset : constant Natural := 446 + Slot * 16;
         begin
            Part_Type := Get_8 (Data, Offset + 4);
            Part_Start := Get_32 (Data, Offset + 8);
            if Part_Start /= 0 and then Part_Type in 16#04# | 16#06# | 16#0E#
            then
               Read_Boot_Sector
                 (Vol, Blocks.Sector_Index (Part_Start), Status);
               if Status = Ok then
                  Load_Label_From_Root (Vol);
                  Vol.Ready := True;
               end if;
               return;
            end if;
         end;
      end loop;

      Status := Not_Formatted;
   end Mount;

   ---------------------------------------------------------------------------
   --  Public: directory entries
   ---------------------------------------------------------------------------

   function Name (Item : Directory_Entry) return String
   is (Item.Text (1 .. Item.Text_Last));

   function Size (Item : Directory_Entry) return Interfaces.Unsigned_32
   is (Item.Bytes);

   function Is_Directory (Item : Directory_Entry) return Boolean
   is ((Item.Attributes and Attr_Directory) /= 0);

   function Is_Read_Only (Item : Directory_Entry) return Boolean
   is ((Item.Attributes and Attr_Read_Only) /= 0);

   function Is_Hidden (Item : Directory_Entry) return Boolean
   is ((Item.Attributes and Attr_Hidden) /= 0);

   ---------------------------------------------------------------------------
   --  Public: listing
   ---------------------------------------------------------------------------

   --  Begin a scan of the directory that starts at Cluster (0 = the root).
   procedure Open_Scan
     (Vol : in out Volume; Cluster : Cluster_Index; Result : out Search)
   is
      pragma Unreferenced (Vol);
   begin
      Result :=
        (Active     => True,
         In_Root    => Cluster < First_Data_Cluster,
         Cluster    => Cluster,
         Sector_Num => 0,
         Index      => 0);
   end Open_Scan;

   --  The scanning engine.  Runs the slot walk, folding long-name fragments
   --  into the 8.3 entry they precede, and stops on the first real entry.
   procedure Scan_Next
     (Vol    : in out Volume;
      Result : in out Search;
      Item   : out Directory_Entry;
      Found  : out Boolean)
   is
      Data      : Blocks.Sector;
      Valid     : Boolean;
      Success   : Boolean;
      Exhausted : Boolean;
      Long      : Long_Name_State;
      Attr      : Interfaces.Unsigned_8;
   begin
      Item := (others => <>);
      Found := False;
      Reset (Long);

      if not Result.Active then
         return;
      end if;

      loop
         Scan_Sector (Vol, Result, Data, Valid, Success);
         if not Success or else not Valid then
            Result.Active := False;
            return;
         end if;

         while Result.Index < Slots_Per_Sector loop
            declare
               Offset : constant Natural := Result.Index * Slot_Bytes;
               Head   : constant Interfaces.Unsigned_8 := Data (Offset);
            begin
               Result.Index := Result.Index + 1;

               if Head = 0 then
                  --  No entry here and none after it: the directory ends.
                  Result.Active := False;
                  return;
               end if;

               if Head = 16#E5# then
                  Reset (Long);                       --  deleted

               else
                  Attr := Data (Offset + 11);

                  if Attr = Attr_Long_Name then
                     Take_Long_Name_Slot (Long, Data, Offset);

                  elsif (Attr and Attr_Volume_Id) /= 0
                    or else Head = Character'Pos ('.')
                  then
                     Reset (Long);                    --  label, "." or ".."

                  else
                     if Long.Valid
                       and then Long.Checksum
                                = Short_Name_Checksum (Data, Offset)
                       and then Long_Name_Length (Long) in 1 .. Max_Name_Length
                     then
                        Item.Text_Last := Long_Name_Length (Long);
                        Item.Text (1 .. Item.Text_Last) :=
                          Long.Text (1 .. Item.Text_Last);
                     else
                        Short_Name (Data, Offset, Item.Text, Item.Text_Last);
                     end if;

                     Item.Attributes := Attr;
                     Item.Bytes := Get_32 (Data, Offset + 28);
                     Item.Start_Cluster :=
                       Cluster_Index (Get_16 (Data, Offset + 26));
                     Found := Item.Text_Last > 0;
                     if Found then
                        return;
                     end if;
                     Reset (Long);
                  end if;
               end if;
            end;
         end loop;

         Advance_Sector (Vol, Result, Exhausted, Success);
         if not Success or else Exhausted then
            Result.Active := False;
            return;
         end if;
      end loop;
   end Scan_Next;

   --  Find one component inside the directory starting at Cluster.
   procedure Find_In_Directory
     (Vol       : in out Volume;
      Cluster   : Cluster_Index;
      Component : String;
      Item      : out Directory_Entry;
      Found     : out Boolean)
   is
      Scan : Search;
   begin
      Open_Scan (Vol, Cluster, Scan);
      loop
         Scan_Next (Vol, Scan, Item, Found);
         exit when not Found;
         exit when Same_Name (Name (Item), Component);
      end loop;
   end Find_In_Directory;

   --  Walk a path down from the root.  Wants_Directory says the final
   --  component must be one (so Start_Search and Open can each be strict).
   procedure Resolve
     (Vol             : in out Volume;
      Path            : String;
      Wants_Directory : Boolean;
      Item            : out Directory_Entry;
      Cluster         : out Cluster_Index;
      Status          : out Status_Kind)
   is
      First   : Natural := Path'First;
      Stop    : Natural;
      Found   : Boolean;
      Current : Cluster_Index := 0;   --  0 = the root directory

      function Is_Separator (C : Character) return Boolean
      is (C = '/' or else C = '\');
   begin
      Item := (others => <>);
      Cluster := 0;
      Status := Ok;

      loop
         while First <= Path'Last and then Is_Separator (Path (First)) loop
            First := First + 1;
         end loop;
         exit when First > Path'Last;

         Stop := First;
         while Stop <= Path'Last and then not Is_Separator (Path (Stop)) loop
            Stop := Stop + 1;
         end loop;

         if Stop - First > Max_Name_Length then
            Status := Name_Too_Long;
            return;
         end if;

         Find_In_Directory
           (Vol, Current, Path (First .. Stop - 1), Item, Found);
         if not Found then
            Status := Not_Found;
            return;
         end if;

         First := Stop;

         --  More to come: this component has to be a directory to descend into.
         while First <= Path'Last and then Is_Separator (Path (First)) loop
            First := First + 1;
         end loop;

         if First <= Path'Last then
            if not Is_Directory (Item) then
               Status := Not_Found;
               return;
            end if;
            Current := Item.Start_Cluster;
         else
            Cluster := Item.Start_Cluster;
            if Wants_Directory /= Is_Directory (Item) then
               Status := Not_A_File;
            end if;
            return;
         end if;
      end loop;

      --  The path named the root itself.
      if not Wants_Directory then
         Status := Not_A_File;
      end if;
   end Resolve;

   procedure Start_Search
     (Vol    : in out Volume;
      Path   : String;
      Result : out Search;
      Status : out Status_Kind)
   is
      Item    : Directory_Entry;
      Cluster : Cluster_Index;
   begin
      Result := (others => <>);

      if not Vol.Ready then
         Status := Not_Formatted;
         return;
      end if;

      Resolve
        (Vol,
         Path,
         Wants_Directory => True,
         Item            => Item,
         Cluster         => Cluster,
         Status          => Status);
      if Status /= Ok then
         return;
      end if;

      Open_Scan (Vol, Cluster, Result);
   end Start_Search;

   procedure Next_Entry
     (Vol    : in out Volume;
      Result : in out Search;
      Item   : out Directory_Entry;
      Found  : out Boolean) is
   begin
      Scan_Next (Vol, Result, Item, Found);
   end Next_Entry;

   ---------------------------------------------------------------------------
   --  Public: files
   ---------------------------------------------------------------------------

   function Is_Open (The_File : File) return Boolean
   is (The_File.Open_For_Read);

   function Size (The_File : File) return Interfaces.Unsigned_32
   is (The_File.Bytes);

   function Position (The_File : File) return Interfaces.Unsigned_32
   is (The_File.Offset);

   function At_End (The_File : File) return Boolean
   is (The_File.Offset >= The_File.Bytes);

   procedure Open
     (Vol      : in out Volume;
      Path     : String;
      The_File : out File;
      Status   : out Status_Kind)
   is
      Item    : Directory_Entry;
      Cluster : Cluster_Index;
   begin
      The_File := (others => <>);

      if not Vol.Ready then
         Status := Not_Formatted;
         return;
      end if;

      Resolve
        (Vol,
         Path,
         Wants_Directory => False,
         Item            => Item,
         Cluster         => Cluster,
         Status          => Status);
      if Status /= Ok then
         return;
      end if;

      --  An empty file has no cluster at all; that is legal, and every read
      --  from it simply returns nothing.
      if Item.Bytes > 0 and then Cluster < First_Data_Cluster then
         Status := Bad_Data;
         return;
      end if;

      The_File :=
        (Open_For_Read => True,
         Bytes         => Item.Bytes,
         Offset        => 0,
         First_Cluster => Cluster,
         Cluster       => Cluster,
         Cluster_Base  => 0);
   end Open;

   procedure Seek
     (Vol      : in out Volume;
      The_File : in out File;
      To       : Interfaces.Unsigned_32;
      Status   : out Status_Kind)
   is
      Span    : constant Interfaces.Unsigned_32 :=
        Interfaces.Unsigned_32 (Cluster_Bytes (Vol));
      Follow  : Cluster_Index;
      Last    : Boolean;
      Success : Boolean;
   begin
      if To > The_File.Bytes then
         Status := Bad_Data;
         return;
      end if;

      Status := Ok;

      --  Rewind to the start whenever the target is behind the cluster we are
      --  sitting in; FAT chains are singly linked, so backwards means restart.
      if To < The_File.Cluster_Base then
         The_File.Cluster := The_File.First_Cluster;
         The_File.Cluster_Base := 0;
      end if;

      while The_File.Cluster_Base + Span <= To loop
         Next_Cluster (Vol, The_File.Cluster, Follow, Last, Success);
         if not Success then
            Status := Bad_Data;
            return;
         end if;
         exit when Last;
         The_File.Cluster := Follow;
         The_File.Cluster_Base := The_File.Cluster_Base + Span;
      end loop;

      The_File.Offset := To;
   end Seek;

   procedure Read
     (Vol      : in out Volume;
      The_File : in out File;
      Into     : out Byte_Array;
      Last     : out Natural)
   is
      Span      : constant Interfaces.Unsigned_32 :=
        Interfaces.Unsigned_32 (Cluster_Bytes (Vol));
      Remaining : Interfaces.Unsigned_32;
      Follow    : Cluster_Index;
      Chain_End : Boolean;
      Success   : Boolean;
   begin
      --  Into is deliberately NOT pre-cleared: on a megabyte-sized firmware
      --  image that memset would cost as much as the read.  Only
      --  Into'First .. Last is meaningful, which is what Last is for.
      Last := Into'First - 1;

      if The_File.Bytes = 0 or else The_File.Offset >= The_File.Bytes then
         return;
      end if;

      Remaining := The_File.Bytes - The_File.Offset;
      if Interfaces.Unsigned_32 (Into'Length) < Remaining then
         Remaining := Interfaces.Unsigned_32 (Into'Length);
      end if;

      while Remaining > 0 loop
         --  Step into the next cluster when the offset has walked off this one.
         if The_File.Offset >= The_File.Cluster_Base + Span then
            Next_Cluster (Vol, The_File.Cluster, Follow, Chain_End, Success);
            if not Success or else Chain_End then
               return;    --  chain shorter than the size claims: stop clean

            end if;
            The_File.Cluster := Follow;
            The_File.Cluster_Base := The_File.Cluster_Base + Span;
         end if;

         declare
            In_Cluster : constant Natural :=
              Natural (The_File.Offset - The_File.Cluster_Base);
            Sector_Num : constant Natural := In_Cluster / Sector_Bytes;
            In_Sector  : constant Natural := In_Cluster mod Sector_Bytes;
            LBA        : constant Blocks.Sector_Index :=
              Cluster_Start (Vol, The_File.Cluster)
              + Blocks.Sector_Index (Sector_Num);
            Chunk      : Natural;
         begin
            if In_Sector = 0 and then Remaining >= Sector_Bytes then
               --  Sector-aligned and at least a whole sector wanted: read a run
               --  of whole sectors straight into the caller's buffer.  This is
               --  what keeps a megabyte-sized firmware image off the one-sector
               --  copy path.
               declare
                  Left_In_Cluster : constant Natural :=
                    Vol.Sectors_Per_Cluster - Sector_Num;
                  Wanted          : constant Natural :=
                    Natural (Remaining) / Sector_Bytes;
                  Count           : constant Natural :=
                    Natural'Min (Left_In_Cluster, Wanted);
                  Run             :
                    Blocks.Sector_Run (0 .. Count * Sector_Bytes - 1)
                  with Import, Address => Into (Last + 1)'Address;
               begin
                  Blocks.Read_Sectors (Vol.Device, LBA, Run);
                  Chunk := Count * Sector_Bytes;
               end;
            else
               declare
                  Data : Blocks.Sector;
               begin
                  Fetch (Vol, LBA, Data, Success);
                  if not Success then
                     return;
                  end if;
                  Chunk :=
                    Natural'Min
                      (Sector_Bytes - In_Sector, Natural (Remaining));
                  for I in 0 .. Chunk - 1 loop
                     Into (Last + 1 + I) := Data (In_Sector + I);
                  end loop;
               end;
            end if;

            Last := Last + Chunk;
            The_File.Offset :=
              The_File.Offset + Interfaces.Unsigned_32 (Chunk);
            Remaining := Remaining - Interfaces.Unsigned_32 (Chunk);
         end;
      end loop;
   exception
      when Ada.IO_Exceptions.Device_Error =>
         null;   --  a run read failed; Last already reports what did arrive
   end Read;

   procedure Read_File
     (Vol    : in out Volume;
      Path   : String;
      Into   : out Byte_Array;
      Last   : out Natural;
      Status : out Status_Kind)
   is
      The_File : File;
      Got      : Natural;
   begin
      Last := Into'First - 1;

      Open (Vol, Path, The_File, Status);
      if Status /= Ok then
         return;
      end if;

      if Interfaces.Unsigned_64 (The_File.Bytes)
        > Interfaces.Unsigned_64 (Into'Length)
      then
         Status := Bad_Data;   --  never hand back a silently truncated image
         return;
      end if;

      Read (Vol, The_File, Into (Into'First .. Into'Last), Got);
      Last := Got;

      if Interfaces.Unsigned_32 (Last - Into'First + 1) /= The_File.Bytes then
         Status := Bad_Data;
      end if;
   end Read_File;

end ESP32S3.Fat16;

