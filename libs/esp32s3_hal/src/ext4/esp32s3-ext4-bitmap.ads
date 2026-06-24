with ESP32S3.Ext4.Volume;

--  Block and inode allocation via the per-group bitmaps.  Allocation sets the
--  bit, decrements the group + superblock free counts (and bumps used-dirs for a
--  directory inode).  Write-side only -- valid on a filesystem WITHOUT
--  metadata_csum (bitmap/group-descriptor checksums are not recomputed here).
package ESP32S3.Ext4.Bitmap is

   --  Allocate one data block; returns its block number.  Raises No_Space.
   function Alloc_Block (V : in out Volume.Context) return Block_Number;

   --  Allocate one inode; returns its number.  As_Dir bumps the group's
   --  used-dirs count.  Raises No_Space.
   function Alloc_Inode (V : in out Volume.Context; As_Dir : Boolean)
      return Inode_Number;

   --  Release a previously-allocated block / inode.  The free counts (group +
   --  superblock; used-dirs for a directory inode) are adjusted ONLY when the
   --  bitmap bit was actually set -- so a double-free or a stale/incoherent
   --  bitmap read (e.g. a flaky SD card) is a no-op rather than a count drift,
   --  and the count stays consistent with the bitmap by construction.
   procedure Free_Block (V : in out Volume.Context; B : Block_Number);
   procedure Free_Inode (V : in out Volume.Context; N : Inode_Number;
                         Was_Dir : Boolean);

   --  TRIPWIRE.  Number of Free_Block/Free_Inode calls that hit an ALREADY-clear
   --  bit (a double-free bug, or a stale read).  The count update is suppressed
   --  on those (no drift), but the event is recorded here so callers can surface
   --  it rather than have it silently masked: the host harness asserts this is 0
   --  (catching real double-free bugs), and on-target examples log it (catching a
   --  flaky card without aborting the operation).
   function  Phantom_Free_Count return Natural;
   procedure Reset_Phantom_Free_Count;

end ESP32S3.Ext4.Bitmap;
