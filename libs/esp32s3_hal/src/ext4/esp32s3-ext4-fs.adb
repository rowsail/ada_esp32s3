with ESP32S3.Ext4.Superblock;
with ESP32S3.Ext4.Block_Cache;
with ESP32S3.Ext4.Path;
with ESP32S3.Ext4.Dir;
with ESP32S3.Ext4.File;
with ESP32S3.Ext4.Writer;
with ESP32S3.Ext4.Block_Map;

package body ESP32S3.Ext4.FS is

   use type Interfaces.Unsigned_32;

   --  INCOMPAT feature bits this build can read.  ro_compat bits need no gating
   --  for a read-only mount (that is what ro_compat means); EXTENTS / 64BIT /
   --  META_BG / INLINE_DATA arrive in later phases and will fail the gate here.
   Handled_Incompat : constant U32 :=
     Superblock.Incompat_Filetype
     or Superblock.Incompat_Recover
     or Superblock.Incompat_Flex_BG
     or Superblock.Incompat_Extents
     or Superblock.Incompat_64Bit
     or Superblock.Incompat_Csum_Seed;   --  read-safe: only relocates the seed

   ----------
   -- Open --
   ----------

   procedure Open (M            : in out Mount;
                   Dev          : ESP32S3.Block_Dev.Device;
                   Read_Only    : Boolean  := True;
                   Cache_Blocks : Positive := 32) is
   begin
      Superblock.Read (Dev, M.V.SB);
      Superblock.Require_Supported (M.V.SB, Handled_Incompat);
      ESP32S3.Ext4.Block_Cache.Init
        (M.V.Cache, Dev, M.V.SB.Block_Size, Cache_Blocks);
      M.V.Dev       := Dev;
      M.V.Read_Only := Read_Only;
      M.Live        := True;

      --  Recover a dirty journal before normal use (writable mounts only, and
      --  only on a journaled volume; a read-only mount or a no-journal volume is
      --  left as-is).  The Has_Journal short-circuit also keeps Needs_Recovery
      --  from touching a missing journal inode on an ^has_journal volume.
      if not Read_Only
        and then Superblock.Has_Journal (M.V.SB)
        and then Journal.Needs_Recovery (M.V)
      then
         Journal.Replay (M.V);
         ESP32S3.Ext4.Block_Cache.Flush (M.V.Cache);   --  checkpoint replay
      end if;
   end Open;

   -----------
   -- Close --
   -----------

   procedure Close (M : in out Mount) is
   begin
      if M.Live then
         if not M.V.Read_Only then
            ESP32S3.Ext4.Block_Cache.Flush (M.V.Cache);
            Superblock.Sync (M.V.Dev, M.V.SB);   --  free counts (+ sb csum)
         end if;
         ESP32S3.Ext4.Block_Cache.Done (M.V.Cache);
         M.Live := False;
      end if;
   end Close;

   overriding procedure Finalize (M : in out Mount) is
   begin
      Close (M);
   end Finalize;

   ------------
   -- Lookup --
   ------------

   function Lookup (M : in out Mount; Path : String) return Inode_Number is
   begin
      return ESP32S3.Ext4.Path.Resolve (M.V, Path);
   end Lookup;

   ----------
   -- Stat --
   ----------

   procedure Stat (M : in out Mount; N : Inode_Number; I : out Inode.Info) is
   begin
      Inode.Read (M.V, N, I);
   end Stat;

   ---------------
   -- Read_File --
   ---------------

   procedure Read_File (M      : in out Mount;
                        I      : Inode.Info;
                        Offset : U64;
                        Into   : out Byte_Array;
                        Last   : out Natural) is
   begin
      File.Read (M.V, I, Offset, Into, Last);
   end Read_File;

   -------------
   -- Iterate --
   -------------

   procedure Iterate
     (M     : in out Mount;
      I     : Inode.Info;
      Visit : not null access procedure
                (Name : String; Ino : Inode_Number; File_Type : U8)) is
   begin
      Dir.Iterate (M.V, I, Visit);
   end Iterate;

   -----------------
   -- Create_File --
   -----------------

   function Create_File (M : in out Mount; Dir_Path, Name : String)
      return Inode_Number is
   begin
      return Writer.Create_File (M.V, Dir_Path, Name);
   end Create_File;

   ----------------
   -- Write_File --
   ----------------

   procedure Write_File (M : in out Mount; N : Inode_Number; Data : Byte_Array) is
   begin
      Writer.Write_Small (M.V, N, Data);
   end Write_File;

   procedure Append (M : in out Mount; N : Inode_Number; Data : Byte_Array) is
   begin
      Writer.Append (M.V, N, Data);
   end Append;

   procedure Mkdir (M : in out Mount; Dir_Path, Name : String) is
   begin
      Writer.Mkdir (M.V, Dir_Path, Name);
   end Mkdir;

   procedure Unlink (M : in out Mount; Dir_Path, Name : String) is
   begin
      Writer.Unlink (M.V, Dir_Path, Name);
   end Unlink;

   procedure Rmdir (M : in out Mount; Dir_Path, Name : String) is
   begin
      Writer.Rmdir (M.V, Dir_Path, Name);
   end Rmdir;

   procedure Rename (M : in out Mount;
                     Old_Dir, Old_Name, New_Dir, New_Name : String) is
   begin
      Writer.Rename (M.V, Old_Dir, Old_Name, New_Dir, New_Name);
   end Rename;

   procedure Truncate (M : in out Mount; N : Inode_Number; New_Size : U64) is
   begin
      Writer.Truncate (M.V, N, New_Size);
   end Truncate;

   procedure Link (M : in out Mount; Target_Path, New_Dir, New_Name : String) is
   begin
      Writer.Link (M.V, Target_Path, New_Dir, New_Name);
   end Link;

   procedure Symlink (M : in out Mount; Dir_Path, Name, Target : String) is
   begin
      Writer.Make_Symlink (M.V, Dir_Path, Name, Target);
   end Symlink;

   --  Durably persist a transaction WITHOUT a journal: write the dirty metadata
   --  to its final locations and sync the superblock free counts.  This is the
   --  same durable step the journaled path performs at checkpoint (and that
   --  Close performs on a writable mount) -- it just has no atomic barrier, so an
   --  interrupted commit can leave the volume inconsistent (the price of
   --  ^has_journal).
   procedure Flush_Direct (M : in out Mount) is
   begin
      ESP32S3.Ext4.Block_Cache.Flush (M.V.Cache);
      Superblock.Sync (M.V.Dev, M.V.SB);
   end Flush_Direct;

   procedure Commit (M : in out Mount) is
   begin
      if Superblock.Has_Journal (M.V.SB) then
         Journal.Transaction_Commit (M.V, Simulate_Crash => False);
      else
         Flush_Direct (M);
      end if;
   end Commit;

   procedure Commit_Crash (M : in out Mount) is
   begin
      --  Crash simulation needs the journal's barrier; on a no-journal volume
      --  there is none, so this degenerates to a plain direct flush.
      if Superblock.Has_Journal (M.V.SB) then
         Journal.Transaction_Commit (M.V, Simulate_Crash => True);
      else
         Flush_Direct (M);
      end if;
   end Commit_Crash;

   procedure Drop_Cache (M : in out Mount) is
   begin
      ESP32S3.Ext4.Block_Cache.Drop (M.V.Cache);
      M.Live := False;
   end Drop_Cache;

   ----------------
   -- Block_Size --
   ----------------

   function Block_Size (M : Mount) return Natural is (M.V.SB.Block_Size);

   function Map_Block (M : in out Mount; I : Inode.Info; L_Block : U64)
      return Block_Number is
   begin
      return Block_Map.Logical_To_Physical (M.V, I, L_Block);
   end Map_Block;

   procedure Journal_Commit (M        : in out Mount;
                             Targets  : Journal.Target_Array;
                             New_Data : Byte_Array) is
   begin
      Journal.Commit (M.V, Targets, New_Data);
   end Journal_Commit;

end ESP32S3.Ext4.FS;
