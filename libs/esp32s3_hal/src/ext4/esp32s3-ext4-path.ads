with ESP32S3.Ext4.Volume;

--  Path resolution: walk a '/'-separated absolute path from the root inode,
--  looking each component up in its parent directory.

package ESP32S3.Ext4.Path is

   --  Resolve Path (absolute, e.g. "/a/b/file") to its inode number.
   --  Raises Name_Error if a component is missing, Use_Error if a non-final
   --  component is not a directory.
   function Resolve
     (V : in out Volume.Context; Path : String) return Inode_Number;

end ESP32S3.Ext4.Path;
