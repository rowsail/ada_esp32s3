with ESP32S3.Block_Dev;

--  On-device ext4 formatter (a minimal mkfs.ext4) for the pure-Ada FS.
--
--  Lays down a fresh, minimal ext4 directly on a Block_Dev: ONE block group,
--  4 KiB blocks, classic block-mapped inodes (the same style ESP32S3.Ext4.Writer
--  creates), NO journal, NO metadata_csum, with a root directory and a
--  lost+found.  The result mounts read-write with ESP32S3.Ext4 and passes the
--  host's e2fsck.
--
--  "Minimal" by design -- it is the inverse of the read path, not a feature-rich
--  mkfs:
--    * a single block group, so the volume must be <= 8 * block_size blocks
--      (32768 blocks = 128 MiB at 4 KiB) -- enough for the 32 MB SPI flash;
--    * INCOMPAT_FILETYPE only (directory entries carry a type);
--    * optional JBD2 journal (Journal => True; see Format) and no metadata_csum
--      (which the FS will not write anyway).
--
--  Format a BLANK device (or one whose old contents you do not mind losing):
--  it writes only the metadata + the two directory blocks, leaving data blocks
--  untouched (the FS initialises each as it is allocated).
package ESP32S3.Ext4.Mkfs is

   --  Format Dev.  Total_Blocks is the filesystem size in 4 KiB blocks; 0 means
   --  "use the whole device" (from Block_Dev.Sector_Count).  Volume_Label is an
   --  optional name (truncated to 16 bytes).
   --
   --  Journal => True creates a JBD2 journal (a fixed 1024-block / 4 MiB log,
   --  inode 8) and sets the has_journal feature -- the FS then commits through
   --  the journal (crash-safe) instead of the direct flush.  It needs ~4.2 MiB
   --  of headroom, so it raises Too_Small on a small device; leave it False
   --  (the default) for a no-journal volume (best for small SPI flash).
   procedure Format (Dev          : ESP32S3.Block_Dev.Device;
                     Total_Blocks : U32     := 0;
                     Volume_Label : String  := "";
                     Journal      : Boolean := False);

   --  Device too small to hold the metadata + a root directory.
   Too_Small : exception;

   --  Device larger than one block group (multi-group mkfs not implemented).
   Too_Large : exception;

   --  Device size is unknown (Sector_Count = 0) and Total_Blocks was not given.
   Unknown_Size : exception;

end ESP32S3.Ext4.Mkfs;
