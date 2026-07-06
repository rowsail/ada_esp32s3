with ESP32S3.Ext4.FS;

--  A tiny mount table: register one or more ext4 filesystems under top-level
--  names so they share ONE path namespace -- "/flash", "/sd", ... -- and resolve a
--  path to the filesystem that backs it.  This is how an application (e.g. the FTP
--  server) exposes several storage devices through one tree without a single
--  device knowing about the others.  Adding a device is one Add call.
--
--  Each storage already reduces to a Block_Dev.Device and mounts as an
--  ESP32S3.Ext4.FS.Mount (the W25Q flash through Block_Dev.WL, an SD card through
--  Block_Dev.SDMMC_Source / SD_SPI_Source); this just names the mounts and routes
--  paths to them.

package ESP32S3.Ext4.VFS is

   type Mount_Ref is access all ESP32S3.Ext4.FS.Mount;

   Max_Mounts : constant := 8;

   --  Register filesystem FS under Name (no slashes), so it appears at "/Name".
   --  The Mount must be library-level (its access is stored here and outlives the
   --  call).  Silently ignored past Max_Mounts.
   procedure Add (Name : String; FS : Mount_Ref)
   with Pre => Name'Length > 0;

   --  The registered mount points, for listing the virtual root "/".
   function Count return Natural;
   function Name (I : Positive) return String
   with Pre => I <= Count;

   --  Resolve an absolute path within the unified namespace:
   --    Is_Root => Path is "/" exactly -- the virtual root (FS is null; list the
   --               mount names).
   --    Found   => Path names a registered volume: FS is its mount and
   --               Path (Sub_First .. Sub_Last) is the path WITHIN it.  An empty
   --               slice (Sub_Last < Sub_First) means the volume root "/".
   --    neither => no such volume.
   procedure Resolve
     (Path      : String;
      FS        : out Mount_Ref;
      Sub_First : out Natural;
      Sub_Last  : out Natural;
      Found     : out Boolean;
      Is_Root   : out Boolean)
   with Pre => Path'Length > 0;

end ESP32S3.Ext4.VFS;
