with Interfaces;

--  Dynamic wear-leveling FTL -- "Option B" (the ESP-IDF wear_levelling scheme).
--
--  A Block_Dev FILTER: it takes a lower Block_Dev.Device (the raw medium -- a
--  W25Q flash via Block_Dev.W25Q_Source on target, a file-backed device in the
--  host harness) and presents a SMALLER logical Block_Dev whose 512-byte sectors
--  are remapped so that, over time, every logical 4 KB block visits every
--  physical 4 KB block.  That spreads erases across the chip instead of letting a
--  hot logical block (an ext4 metadata block, say) wear out one physical sector.
--  Because it is a plain Block_Dev over a Block_Dev, it carries no flash-specific
--  code and runs unchanged on the host (where it is brute-force tested).
--
--  How it works (O(1) state -- just a move counter, no per-block map):
--    * The medium's 4 KB blocks are split into a data+spare region of D blocks
--      plus 2 fixed config blocks.  L = D - 1 logical blocks are usable; one
--      block in the region is always a free "hole".
--    * A logical block lb maps to physical block  (t + ((lb - t) mod L)) mod D,
--      where t = Move_Steps; the hole sits at (t - 1) mod D and is never mapped.
--    * Every Update_Rate writes, one "move" copies a single block into the hole
--      and advances t by one -- so the hole walks the region and the whole
--      mapping rotates, one block at a time.
--    * State (t, sequence, CRC, geometry) is written to the two config blocks
--      PING-PONG (alternating, each with a higher sequence number).  Mount picks
--      the highest sequence whose CRC validates, so a power failure mid-update
--      always leaves a consistent earlier state -- and a move is ordered
--      copy-then-commit, so an interrupted move is simply redone from the older
--      config.  See the body for the crash-safety argument.
--
--  This is DYNAMIC wear leveling only (sufficient for a 32 MB part): it bounds
--  how unevenly *write* activity wears the chip, but does not actively relocate
--  cold/never-written blocks.  Config blocks are rewritten once per move (= once
--  per Update_Rate writes), which is their wear cost -- raise Update_Rate to
--  trade wear-leveling aggressiveness for less move/config overhead.
--
--  Layering:  ext4  ->  Block_Dev.WL  ->  Block_Dev.W25Q_Source  ->  ESP32S3.W25Q
--
--  Single-threaded use, like the rest of the ext4 stack.
package ESP32S3.Block_Dev.WL is

   --  Wear-leveling erase-block size and the 512-byte sectors within it.  4 KB
   --  matches the W25Q flash erase sector; the remap granularity is one block.
   Block_Bytes        : constant := 4096;
   Sectors_Per_Block  : constant := Block_Bytes / Sector'Length;   --  8

   --  Per-volume state.  Declare one (aliased), Attach it to the lower device,
   --  Mount (or Format) it, then Make a Device from it.  Must outlive the Device.
   type Volume is limited private;

   --  Bind V to the lower medium and compute the geometry.  Reserves the top two
   --  erase blocks of Lower for the ping-pong config; the rest becomes the
   --  data+spare region.  Update_Rate is the number of logical writes between
   --  moves.  Raises Constraint_Error if Lower is too small (< 4 erase blocks).
   procedure Attach (V           : in out Volume;
                     Lower       : Device;
                     Update_Rate : Positive := 16);

   --  Load persisted state from the config blocks (highest valid sequence wins).
   --  Formatted is False if neither config block holds a valid record for this
   --  geometry -- call Format then.
   procedure Mount (V : in out Volume; Formatted : out Boolean);

   --  Write a fresh initial state (Move_Steps = 0) to the config.  Does NOT erase
   --  the data region -- the filesystem (mkfs/ext4) writes that.  Leaves V
   --  mounted.
   procedure Format (V : in out Volume);

   --  Total usable logical 512-byte sectors (L * Sectors_Per_Block).
   function Logical_Sectors (V : Volume) return Sector_Index;

   --  Diagnostic: how many moves the FTL has performed (the map-rotation count;
   --  grows by one every Update_Rate writes).
   function Move_Count (V : Volume) return Interfaces.Unsigned_64;

   --  A Device whose Ctx is V (Write = null if the lower device is read-only).
   --  V must be Mounted/Formatted and outlive the Device.
   function Make (V : not null access Volume) return Device;

private
   type Volume is limited record
      Lower       : Device;
      Data_Blocks : Natural := 0;             --  D: data + one spare/hole
      Logical     : Natural := 0;             --  L = D - 1 usable logical blocks
      Update_Rate : Positive := 16;
      Move_Steps  : Interfaces.Unsigned_64 := 0;   --  t: completed moves
      Access_Count : Natural := 0;            --  writes since the last move
      Sequence    : Interfaces.Unsigned_64 := 0;   --  config generation (ping-pong)
      Mounted     : Boolean := False;
   end record;
end ESP32S3.Block_Dev.WL;
