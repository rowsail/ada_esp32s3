with ESP32S3.Ext4.Volume;

--  High-level mutation: create a regular file and give it contents.  Write
--  support targets filesystems WITHOUT metadata_csum (ext2/3 and ext4 with
--  ^metadata_csum); attempting it on a metadata_csum volume raises Read_Only,
--  since the group-descriptor/bitmap/dir-tail checksums are not yet recomputed.
package ESP32S3.Ext4.Writer is

   --  Create a regular file Name in directory Dir_Path; return its inode number.
   function Create_File (V : in out Volume.Context; Dir_Path, Name : String)
      return Inode_Number;

   --  Set the entire contents of (currently empty) file inode N in one call,
   --  from an in-memory buffer.  Allocates 12 direct + one single-indirect
   --  block, so up to (12 + block_size/4) * block_size bytes (~4 MiB at 4 KiB).
   procedure Write_Small (V : in out Volume.Context; N : Inode_Number;
                          Data : Byte_Array);

   --  Append Data to the END of regular file inode N, growing it block by block.
   --  Streaming: call it repeatedly with small chunks to build a large file
   --  without holding the whole thing in memory.  Reaches 12 direct + single +
   --  double indirect = ~4 GiB at 4 KiB blocks (triple indirect unsupported); a
   --  final size past that raises Use_Error before allocating anything.  If the
   --  volume fills mid-append (No_Space) the bytes written so far are committed
   --  (no leaked blocks) and the exception propagates.
   procedure Append (V : in out Volume.Context; N : Inode_Number;
                     Data : Byte_Array);

   --  Create an empty subdirectory Name in directory Dir_Path (with "."/"..").
   procedure Mkdir (V : in out Volume.Context; Dir_Path, Name : String);

   --  Remove regular file Name from directory Dir_Path; frees its inode + data
   --  blocks when the last link goes.  (Files with indirect/extent maps are not
   --  yet freeable -> Unsupported_Feature.)
   procedure Unlink (V : in out Volume.Context; Dir_Path, Name : String);

   --  Remove empty subdirectory Name from Dir_Path (raises Not_Empty otherwise).
   procedure Rmdir (V : in out Volume.Context; Dir_Path, Name : String);

   --  Rename Old_Name in Old_Dir to New_Name in New_Dir (same or different
   --  directory).  The target must not already exist.  Moving a directory across
   --  parents fixes up its ".." and the two parents' link counts.
   procedure Rename (V : in out Volume.Context;
                     Old_Dir, Old_Name, New_Dir, New_Name : String);

   --  Set regular file inode N's size to New_Size.  Shrinking frees the now-unused
   --  data (+ indirect) blocks; growing just extends the size (sparse).  Direct /
   --  single-indirect only.
   procedure Truncate (V : in out Volume.Context; N : Inode_Number; New_Size : U64);

   --  Create a hard link New_Name in New_Dir to the existing file Target_Path
   --  (not a directory; target must not already exist).
   procedure Link (V : in out Volume.Context;
                   Target_Path, New_Dir, New_Name : String);

   --  Create a symbolic link Name in Dir_Path whose contents is Target (the
   --  link text -- not resolved).  Short targets (< 60 bytes) are stored inline
   --  in the inode ("fast symlink"); longer ones use a single data block.  The
   --  target must not exceed one block.
   procedure Make_Symlink (V : in out Volume.Context;
                           Dir_Path, Name, Target : String);

end ESP32S3.Ext4.Writer;
