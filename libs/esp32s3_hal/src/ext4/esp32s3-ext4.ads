with Interfaces;
with Ada.IO_Exceptions;

--  Root of the pure-Ada ext2/3/4 filesystem (a reimplementation of lwext4).
--
--  This package holds the scalar types shared by every on-disk structure, the
--  fixed ext constants, and the exception set the whole filesystem reports
--  through.  The error model is idiomatic Ada IO: operations RAISE; the
--  IO-family exceptions are the standard ones from Ada.IO_Exceptions (so a
--  future Ada.Streams.Stream_IO bridge maps cleanly), plus a few
--  filesystem-specific ones.
--
--  Targets the ESP32-S3 embedded/full runtimes (exceptions, finalization,
--  secondary stack, heap); it also compiles host-native (x86 GNAT) for testing,
--  since it is pure logic over the ESP32S3.Block_Dev block interface.

package ESP32S3.Ext4 is

   --  Unsigned scalar aliases used throughout the on-disk structures.
   subtype U8 is Interfaces.Unsigned_8;
   subtype U16 is Interfaces.Unsigned_16;
   subtype U32 is Interfaces.Unsigned_32;
   subtype U64 is Interfaces.Unsigned_64;

   --  Raw byte buffers (block/sector contents, checksum inputs, names).
   type Byte_Array is array (Natural range <>) of U8;

   --  A filesystem block number (NOT a 512-byte sector; ext block = 1 KiB .. 64 KiB).
   --  64-bit-clean for the ext4 "64bit" feature.
   type Block_Number is new U64;

   --  Inode numbers (ext4 inode numbers are 32-bit).
   type Inode_Number is new U32;

   --  Fixed inodes defined by the format.
   Root_Inode    : constant Inode_Number := 2;   --  the root directory
   Journal_Inode : constant Inode_Number := 8;   --  the JBD2 journal (Phase 4)

   ---------------------------------------------------------------------------
   --  Error model -- exceptions.
   ---------------------------------------------------------------------------

   --  Standard Ada IO exceptions, reused verbatim (same identity, so a handler
   --  for Ada.IO_Exceptions.* or for these names both catch).
   Status_Error : exception renames Ada.IO_Exceptions.Status_Error;
   Mode_Error   : exception renames Ada.IO_Exceptions.Mode_Error;
   Name_Error   : exception renames Ada.IO_Exceptions.Name_Error;
   Use_Error    : exception renames Ada.IO_Exceptions.Use_Error;
   Device_Error : exception renames Ada.IO_Exceptions.Device_Error;
   End_Error    : exception renames Ada.IO_Exceptions.End_Error;
   Data_Error   : exception renames Ada.IO_Exceptions.Data_Error;

   --  Filesystem-specific failures.
   Unsupported_Feature : exception;   --  an incompat feature we don't implement
   Bad_Checksum        : exception;   --  metadata_csum / crc mismatch
   Corrupt             : exception;   --  structural inconsistency on disk
   No_Space            : exception;   --  out of blocks or inodes
   Not_Empty           : exception;   --  rmdir on a non-empty directory
   Read_Only           : exception;   --  write attempted on a read-only mount

   ---------------------------------------------------------------------------
   --  Little-endian field readers / writers over a byte buffer.  ext on-disk
   --  structures are little-endian; both x86 and the Xtensa target are too, but
   --  these keep the decoding explicit and endian-correct regardless.  Off is a
   --  0-based byte offset from B'First.
   ---------------------------------------------------------------------------

   function Get_U8 (B : Byte_Array; Off : Natural) return U8;
   function Get_U16 (B : Byte_Array; Off : Natural) return U16;
   function Get_U32 (B : Byte_Array; Off : Natural) return U32;
   function Get_U64 (B : Byte_Array; Off : Natural) return U64;

   procedure Put_U8 (B : in out Byte_Array; Off : Natural; V : U8);
   procedure Put_U16 (B : in out Byte_Array; Off : Natural; V : U16);
   procedure Put_U32 (B : in out Byte_Array; Off : Natural; V : U32);
   procedure Put_U64 (B : in out Byte_Array; Off : Natural; V : U64);

   --  Big-endian variants -- the JBD2 journal stores its structures big-endian.
   function Get_U32_BE (B : Byte_Array; Off : Natural) return U32;
   procedure Put_U32_BE (B : in out Byte_Array; Off : Natural; V : U32);

end ESP32S3.Ext4;
