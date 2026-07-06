with Interfaces;
with ESP32S3.Ext4.Volume;

use type Interfaces.Unsigned_16;
use type Interfaces.Unsigned_32;

--  ext inode read.  The 60-byte i_block area is kept raw -- it is either the
--  classic block map (12 direct + 3 indirect pointers) or, when EXTENTS_FL is
--  set, the root of an extent tree (Phase 2); the block-map facade decides.

package ESP32S3.Ext4.Inode with SPARK_Mode => On is

   type Info is record
      Mode       : U16 := 0;
      Size       : U64 := 0;          --  file size in bytes
      Flags      : U32 := 0;
      Links      : U16 := 0;
      Blocks_512 : U64 := 0;          --  i_blocks, in 512-byte units
      I_Block    : Byte_Array (0 .. 59) := [others => 0];  --  raw map / extent root
   end record;

   EXTENTS_FL     : constant U32 := 16#0008_0000#;
   INLINE_DATA_FL : constant U32 := 16#1000_0000#;

   function Is_Dir (I : Info) return Boolean
   is ((I.Mode and 16#F000#) = 16#4000#);
   function Is_Reg (I : Info) return Boolean
   is ((I.Mode and 16#F000#) = 16#8000#);
   function Is_Symlink (I : Info) return Boolean
   is ((I.Mode and 16#F000#) = 16#A000#);

   function Uses_Extents (I : Info) return Boolean
   is ((I.Flags and EXTENTS_FL) /= 0);
   function Is_Inline (I : Info) return Boolean
   is ((I.Flags and INLINE_DATA_FL) /= 0);

   --  Read inode N (>= 1).
   procedure Read (V : in out Volume.Context; N : Inode_Number; I : out Info)
   with Pre => N >= 1, SPARK_Mode => Off;

   --  Write inode N's modelled fields (mode/size/flags/links/i_blocks/i_block).
   --  Fresh zero-initialises the whole inode first (for a freshly-allocated one);
   --  otherwise the unmodelled fields are preserved.  Recomputes the checksum
   --  when metadata_csum is in effect.
   procedure Write
     (V : in out Volume.Context; N : Inode_Number; I : Info; Fresh : Boolean := False)
   with Pre => N >= 1, SPARK_Mode => Off;

   --  Mark inode N as deleted on disk (links_count := 0, dtime := nonzero) so
   --  e2fsck treats the now-free inode as a clean deletion.
   procedure Mark_Deleted (V : in out Volume.Context; N : Inode_Number)
   with Pre => N >= 1, SPARK_Mode => Off;

end ESP32S3.Ext4.Inode;
