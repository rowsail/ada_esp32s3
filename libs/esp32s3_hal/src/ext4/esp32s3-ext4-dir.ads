with ESP32S3.Ext4.Volume;
with ESP32S3.Ext4.Inode;

--  Linear directory entries (ext4_dir_entry_2): walk a directory's data blocks
--  and read inode / rec_len / name_len / file_type / name.  HTree-indexed
--  directories still hold a valid linear layout, so this reads them too; the
--  HTree fast-path (Phase 2) is only an optimisation.

package ESP32S3.Ext4.Dir is

   --  ext file_type values (with the FILETYPE feature).
   FT_Unknown : constant U8 := 0;
   FT_Reg     : constant U8 := 1;
   FT_Dir     : constant U8 := 2;
   FT_Symlink : constant U8 := 7;

   --  Look up Name directly in directory Dir; return its inode number, or 0 if
   --  not present.
   function Lookup
     (V : in out Volume.Context; Dir : Inode.Info; Name : String) return Inode_Number
   with Pre => Name'Length > 0;

   --  Call Visit for every real entry (skips unused slots).  "." and ".." are
   --  reported like any other entry.
   procedure Iterate
     (V     : in out Volume.Context;
      Dir   : Inode.Info;
      Visit : not null access procedure (Name : String; Ino : Inode_Number; File_Type : U8));

   --  Add Name -> Child (with File_Type) to directory Dir by splitting slack in
   --  one of its existing data blocks.  Raises No_Space if no block has room
   --  (directory-block extension is a later step).  Raises Use_Error if Name
   --  already exists (entries must be unique -- a blind append would create a
   --  duplicate dirent); callers that mean to replace remove the old entry first.
   procedure Add_Entry
     (V         : in out Volume.Context;
      Dir       : Inode.Info;
      Name      : String;
      Child     : Inode_Number;
      File_Type : U8)
   with Pre => Name'Length > 0 and then Child >= 1;

   --  Remove Name from directory Dir (merging its slot into the previous entry,
   --  or zeroing its inode if first in the block).  Returns the removed entry's
   --  child inode number, or 0 if Name was not found.
   function Remove_Entry
     (V : in out Volume.Context; Dir : Inode.Info; Name : String) return Inode_Number
   with Pre => Name'Length > 0;

   --  True if Dir contains only "." and ".." (i.e. is empty).
   function Is_Empty (V : in out Volume.Context; Dir : Inode.Info) return Boolean;

   --  Repoint entry Name in Dir at inode New_Ino.  Returns True if found.
   function Set_Entry_Inode
     (V : in out Volume.Context; Dir : Inode.Info; Name : String; New_Ino : Inode_Number)
      return Boolean
   with Pre => Name'Length > 0 and then New_Ino >= 1;

end ESP32S3.Ext4.Dir;
