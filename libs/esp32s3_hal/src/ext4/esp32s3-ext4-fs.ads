with Ada.Finalization;
with ESP32S3.Block_Dev;
with ESP32S3.Ext4.Volume;
with ESP32S3.Ext4.Inode;
with ESP32S3.Ext4.Journal;

--  Public facade for a mounted ext filesystem.  A Mount is a limited, controlled
--  handle: it flushes and releases the block cache automatically when it leaves
--  scope (including on exception unwind), so there is no silently-unflushed
--  state.  Errors are raised (see ESP32S3.Ext4).
package ESP32S3.Ext4.FS is

   type Mount is tagged limited private;

   --  Mount Dev: read + feature-gate the superblock, bring up the cache.
   --  Cache_Blocks is the number of filesystem blocks the LRU cache holds.
   procedure Open (M            : in out Mount;
                   Dev          : ESP32S3.Block_Dev.Device;
                   Read_Only    : Boolean  := True;
                   Cache_Blocks : Positive := 32);

   --  Flush + release (also done by finalization; idempotent).
   procedure Close (M : in out Mount);

   --  Resolve an absolute path to its inode number (raises Name_Error if absent).
   function Lookup (M : in out Mount; Path : String) return Inode_Number;

   --  Read inode N's metadata.
   procedure Stat (M : in out Mount; N : Inode_Number; I : out Inode.Info);

   --  Read up to Into'Length bytes of file I from byte Offset; Last = count read.
   procedure Read_File (M      : in out Mount;
                        I      : Inode.Info;
                        Offset : U64;
                        Into   : out Byte_Array;
                        Last   : out Natural);

   --  Iterate directory I's entries.
   procedure Iterate
     (M     : in out Mount;
      I     : Inode.Info;
      Visit : not null access procedure
                (Name : String; Ino : Inode_Number; File_Type : U8));

   --  Create a regular file Name in directory Dir_Path; return its inode number.
   --  (Requires a writable, non-metadata_csum volume.)
   function Create_File (M : in out Mount; Dir_Path, Name : String)
      return Inode_Number;

   --  Set the entire contents of (empty) file inode N from one in-memory buffer
   --  (up to ~4 MiB at 4 KiB blocks: 12 direct + one single-indirect block).
   procedure Write_File (M : in out Mount; N : Inode_Number; Data : Byte_Array);

   --  Append Data to the end of regular file inode N.  Streaming: call it
   --  repeatedly with small chunks to grow a file WITHOUT holding the whole
   --  thing in memory.  Reaches direct + single + double indirect (~4 GiB at
   --  4 KiB blocks).
   procedure Append (M : in out Mount; N : Inode_Number; Data : Byte_Array);

   --  Create a subdirectory / remove a regular file / remove an empty directory.
   procedure Mkdir  (M : in out Mount; Dir_Path, Name : String);
   procedure Unlink (M : in out Mount; Dir_Path, Name : String);
   procedure Rmdir  (M : in out Mount; Dir_Path, Name : String);

   --  Rename Old_Name in Old_Dir to New_Name in New_Dir.
   procedure Rename (M : in out Mount;
                     Old_Dir, Old_Name, New_Dir, New_Name : String);

   --  Truncate file inode N to New_Size; hard-link an existing file.
   procedure Truncate (M : in out Mount; N : Inode_Number; New_Size : U64);
   procedure Link (M : in out Mount; Target_Path, New_Dir, New_Name : String);

   --  Create symbolic link Name in Dir_Path pointing at the text Target.
   procedure Symlink (M : in out Mount; Dir_Path, Name, Target : String);

   --  Atomically commit the pending write-set (the dirty metadata + the
   --  superblock, from one or more preceding operations) as a single journaled
   --  transaction: journal -> barrier -> checkpoint -> reset.  The write-set must
   --  fit the cache (so this covers metadata + small-data operations; large-file
   --  data is not journaled).  Non-csum filesystems.
   procedure Commit (M : in out Mount);

   --  (test) Commit but stop right after the barrier (simulate a crash before
   --  the checkpoint); the next mount's recovery completes it.
   procedure Commit_Crash (M : in out Mount);

   --  (test) Discard the volatile cache without checkpointing (simulate power
   --  loss); the Mount becomes inert.
   procedure Drop_Cache (M : in out Mount);

   --  The mounted volume's block size in bytes.
   function Block_Size (M : Mount) return Natural;

   --  Physical block holding logical block L_Block of file I (0 => hole).
   --  (Exposed mainly for tests.)
   function Map_Block (M : in out Mount; I : Inode.Info; L_Block : U64)
      return Block_Number;

   --  Write one committed journal transaction logging New_Data for Targets and
   --  set the RECOVER flag (does not checkpoint).  Exposed for the crash-safety
   --  test; the recovery path then applies it.
   procedure Journal_Commit (M        : in out Mount;
                             Targets  : Journal.Target_Array;
                             New_Data : Byte_Array);

private

   type Mount is new Ada.Finalization.Limited_Controlled with record
      V    : Volume.Context;
      Live : Boolean := False;
   end record;

   overriding procedure Finalize (M : in out Mount);

end ESP32S3.Ext4.FS;
