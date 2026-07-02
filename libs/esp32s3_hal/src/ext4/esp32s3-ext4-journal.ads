with ESP32S3.Ext4.Volume;

--  JBD2 journal recovery (replay-on-mount).  The journal lives in inode 8 as a
--  regular file; its on-disk structures are BIG-ENDIAN (unlike the rest of ext).
--  On a volume whose superblock has the RECOVER incompat flag set, the pending
--  committed transactions are replayed into the filesystem before normal use,
--  then the journal is reset and the flag cleared.
--
--  Handles the classic (non-checksummed) journal format used by ext3 and by
--  ext4 with ^metadata_csum.  A checksummed journal (CSUM_V2/V3) raises
--  Unsupported_Feature for now.

package ESP32S3.Ext4.Journal is

   --  Does the volume's superblock ask for journal recovery?
   function Needs_Recovery (V : Volume.Context) return Boolean;

   --  Replay committed transactions into the filesystem, honour revoke records,
   --  reset the journal superblock and clear the volume's RECOVER flag.  No-op
   --  if the journal is already empty.  Caller must hold a writable volume.
   procedure Replay (V : in out Volume.Context);

   type Target_Array is array (Positive range <>) of Block_Number;

   --  Write ONE committed transaction to the journal: log New_Data (Targets'Length
   --  filesystem blocks, block i held at offset (i-1)*block_size of New_Data) for
   --  the given target blocks, append a commit block, point the journal at it and
   --  set the fs RECOVER flag.  Does NOT checkpoint -- a crash (or the next mount's
   --  Replay) applies the logged blocks to their targets.  This is the commit half
   --  of the journal: a crash after Commit recovers forward, before it has no
   --  effect.  Non-checksummed journals only.
   procedure Commit
     (V        : in out Volume.Context;
      Targets  : Target_Array;
      New_Data : Byte_Array);

   --  Commit the cache's dirty metadata blocks AND the superblock as one
   --  journaled transaction: log them + write the journal commit (durable), set
   --  the fs RECOVER flag (the barrier), checkpoint the metadata to its final
   --  locations, then clear RECOVER and reset the journal.  A crash after the
   --  barrier recovers forward (Replay); a crash before it has no effect.  This
   --  is how the write path is made atomic.  Non-checksummed filesystems only.
   --
   --  Simulate_Crash stops right after the barrier (journal committed, RECOVER
   --  set, metadata NOT yet checkpointed) -- for the crash-recovery tests.
   procedure Transaction_Commit
     (V : in out Volume.Context; Simulate_Crash : Boolean := False);

end ESP32S3.Ext4.Journal;
