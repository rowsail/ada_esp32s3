with System;
with Ada.Finalization;
with Interfaces;

--  ESP32-S3 General DMA (GDMA).
--
--  The S3 has ONE AHB GDMA block with five channel pairs (0 .. 4).  Each pair
--  has an independent transmit (OUT) path and receive (IN) path, and either can
--  be wired to any peripheral through the GDMA crossbar -- the channel is a
--  runtime-assigned resource, not a fixed-per-peripheral one.  This driver
--  models that directly: Claim hands out a free Channel handle bound to a
--  peripheral; later peripheral drivers (SPI, I2S, ...) will Claim a channel
--  and drive their own descriptors over it.
--
--  Transfers are described by linked lists of descriptors in memory; the engine
--  walks the list, moving each buffer.  This first cut implements the
--  memory-to-memory path (Mem2Mem): a single Copy that the hardware completes by
--  looping one channel's OUT path into its own IN path.
--
--  Concurrency / ownership: Claim / Release go through a protected allocator, so
--  concurrent tasks can never be handed the same channel.  The Channel handle is
--  LIMITED (non-copyable -- you can't assign it to another variable or pass a
--  copy to another task, so two tasks can't alias one channel) and CONTROLLED
--  (it releases its channel automatically when it leaves scope, including on an
--  exception, so a channel can't leak or be reused through a stale copy).  Once
--  you hold a Channel, only you touch its registers and descriptors -- so the
--  transfer operations need no further locking.  Using finalization, this driver
--  targets the embedded/full profile (excluded from the light-tasking build).
--
--  Completion is interrupt-driven: a transfer's Wait suspends the calling task
--  and the channel's end-of-transfer interrupt wakes it.  This driver OWNS the
--  Device_L2_0 interrupt (CPU_INT 19) for that -- an application must not also
--  attach a handler to it.

package ESP32S3.GDMA is
   --  DMA buffers must be DMA-capable memory (see Is_DMA_Capable).  Enforce the
   --  preconditions below even when global assertions are off -- a buffer in
   --  flash/PSRAM silently corrupts the transfer, so this is cheap insurance.
   pragma Assertion_Policy (Pre => Check);

   --  The five GDMA channel pairs.
   type Channel_Id is mod 5;

   --  True if the GDMA can transfer to/from A.  Internal SRAM
   --  (0x3FC88000 .. 0x3FD00000) always qualifies.  External PSRAM
   --  (0x3C000000 .. 0x3E000000) qualifies when A is cache-line (32-byte)
   --  aligned: the driver keeps PSRAM coherent by writing back / invalidating the
   --  DCache around each transfer, and enables DMA burst mode for it.  A PSRAM
   --  buffer should also be sized to a 32-byte multiple (or not share its trailing
   --  cache line with live data), since the invalidate rounds up to a whole line.
   --  Flash .rodata (also in 0x3C..) is not writable/aligned for this and is
   --  excluded -- a `constant` aggregate there still cannot be DMA'd.
   function Is_DMA_Capable (A : System.Address) return Boolean;

   --  DMA buffer alignment = the external-memory DCache line.  The GDMA reaches
   --  PSRAM THROUGH the DCache, so a PSRAM buffer must be cache-line aligned (and,
   --  ideally, sized to whole lines) for the write-back/invalidate around a
   --  transfer to touch only that buffer -- see Is_DMA_Capable.
   DMA_Alignment : constant := 32;

   --  A byte buffer GUARANTEED suitable for DMA wherever it lives.  TWO properties
   --  are required, and both are enforced here:
   --
   --    * Aligned START -- Alignment => DMA_Alignment.  Declaring a buffer of this
   --      type (a local, incl. on a PSRAM task stack; a static object; or
   --      `new DMA_Buffer` on the heap) makes GNAT place its DATA on a 32-byte
   --      boundary (it over-aligns the heap allocation as needed, past the array's
   --      bounds "dope").
   --    * Whole-cache-line SIZE -- the length is a multiple of DMA_Alignment.  This
   --      is NOT implied by alignment, and it matters: the PSRAM cache write-back /
   --      invalidate rounds the region UP to a whole cache line, so a buffer that
   --      ended mid-line would have the maintenance op touch the neighbouring
   --      bytes -- dropping an adjacent object's dirty cached write.  With the size
   --      a line multiple, the buffer occupies whole lines exclusively (aligned at
   --      BOTH ends), so the maintenance never reaches beyond it.
   --
   --  Size a payload UP to a 32-byte multiple (e.g. 128 for 100 useful bytes).
   --  The type carries only the ALIGNMENT (so slicing and element copies inside a
   --  driver stay friction-free); the whole-cache-line SIZE is enforced as a
   --  PRECONDITION on the DMA operations below, checked on the whole buffer at the
   --  call boundary -- pass the whole buffer plus a transfer Length, not a slice.
   --  Internal-SRAM buffers are DMA-capable at any alignment, so this type costs
   --  nothing there.
   type DMA_Buffer is array (Natural range <>) of Interfaces.Unsigned_8
     with Alignment => DMA_Alignment;

   --  Self-check of the PSRAM coherency path: does a memory-to-memory DMA between
   --  two buffers of the CALLER'S choosing round-trip a byte pattern?  Call with
   --  PSRAM buffers (e.g. from a task whose stack is in PSRAM) to exercise the
   --  cache write-back/invalidate; the result says which memory was actually
   --  tested.  Buffers must be 32-byte aligned and >= 64 bytes.
   type Self_Test_Result is (Passed_PSRAM, Passed_SRAM, Failed, No_Channel);
   function Self_Test (Buf_A, Buf_B : System.Address) return Self_Test_Result;

   --  Peripherals a channel can be bound to.  Mem2Mem is the internal
   --  memory-to-memory loopback (no external peripheral).  The others match the
   --  GDMA PERI_SEL encoding and are placeholders until their drivers land.
   type Peripheral is (Mem2Mem, SPI2, SPI3, UHCI0, I2S0, I2S1, LCD_CAM, AES, SHA, ADC_DAC, RMT);

   --  An opaque, non-copyable handle to a claimed channel.  Default-initialised
   --  to invalid (check Is_Valid); auto-releases its channel on scope exit.
   type Channel is limited private;

   --  Largest single-descriptor transfer (hardware buffer-size field is 12 bits).
   Max_Transfer : constant := 4095;

   --  Claim a free channel into C and bind both its paths to Peri.  If all five
   --  are in use, C is left invalid (Is_Valid False).  For Mem2Mem the one
   --  channel's OUT and IN paths are used together.  (If C already holds a
   --  channel it is released first.)  C releases its channel automatically when
   --  it goes out of scope -- call Release only to hand it back early.
   procedure Claim (C : in out Channel; Peri : Peripheral);

   --  True when Claim succeeded (a real channel is held).
   function Is_Valid (C : Channel) return Boolean;

   --  Return a channel to the free pool (also tears down its peripheral
   --  binding).  Harmless on an invalid handle.
   procedure Release (C : in out Channel);

   --  Blocking memory-to-memory copy of Length bytes (1 .. Max_Transfer) from
   --  Src to Dst over channel C (claimed for Mem2Mem).  Returns once the
   --  transfer's success-EOF is observed.  Src, Dst and the driver's internal
   --  descriptors must live in INTERNAL SRAM -- the descriptor link address is a
   --  20-bit field the engine completes within the on-chip RAM region.
   --
   --  No-op if C is invalid or Length is 0 / over Max_Transfer.
   procedure Copy (C : Channel; Dst, Src : System.Address; Length : Natural)
   with Pre => Length = 0 or else (Is_DMA_Capable (Src) and then Is_DMA_Capable (Dst));

   ------------------------------------------------------------------------
   --  Peripheral-bound transfers.
   --
   --  A peripheral driver (SPI, I2S, UART/UHCI, ...) Claims a channel bound to
   --  its peripheral, then drives one direction at a time over it.  The GDMA
   --  side here is the same descriptor engine the (HW-verified) Copy uses; the
   --  peripheral's own configuration and its DMA request handshake live in the
   --  peripheral driver.
   ------------------------------------------------------------------------

   --  Data-flow direction of a transfer:
   --    Mem_To_Periph -> the OUT (TX) path reads RAM and feeds the peripheral
   --    Periph_To_Mem -> the IN (RX) path receives from the peripheral into RAM
   type Direction is (Mem_To_Periph, Periph_To_Mem);

   --  Which half of a double-buffered streaming ring: only ever 0 or 1.
   subtype Ring_Half is Natural range 0 .. 1;

   --  Arm a single-buffer transfer in direction Dir on channel C and kick the
   --  GDMA side.  NON-blocking: configure and start the peripheral separately;
   --  the GDMA moves data as the peripheral asserts its DMA request.  Poll Done
   --  or call Wait for completion.  Buffer must be in internal SRAM; Length in
   --  1 .. Max_Transfer.  No-op on an invalid handle or out-of-range Length.
   procedure Start (C : Channel; Dir : Direction; Buffer : System.Address; Length : Natural)
   with Pre => Length = 0 or else Is_DMA_Capable (Buffer);

   --  Arm a CONTINUOUS (self-looping) transmit on C's OUT path: a single
   --  descriptor whose link points back to itself, so the engine replays
   --  Buffer forever with no gap between passes.  NON-blocking and never
   --  completes on its own -- the peripheral keeps consuming Buffer until the
   --  channel is Released (or the peripheral is stopped).  For gapless looped
   --  playback of a periodic waveform (e.g. a steady tone) with zero CPU
   --  involvement after the kick.  Buffer must be in internal SRAM and should
   --  hold a whole number of wave periods so the wrap is seamless; Length in
   --  1 .. Max_Transfer.  No-op on an invalid handle or out-of-range Length.
   procedure Start_Loop (C : Channel; Buffer : System.Address; Length : Natural)
   with Pre => Length = 0 or else Is_DMA_Capable (Buffer);

   --  Type-safe overloads: pass the WHOLE DMA_Buffer plus the transfer Length.
   --  The compiler checks alignment (the type) and the whole-cache-line SIZE (the
   --  predicate, on this parameter pass) of the buffer, so no runtime address
   --  check is needed -- and because the buffer's footprint is a cache-line
   --  multiple, the PSRAM cache maintenance for ANY Length (<= the buffer) rounds
   --  up to a line that still lies within the buffer.  So a partial transfer
   --  passes the whole (line-multiple) buffer and a smaller Length -- do NOT slice
   --  to Length, which would fail the size predicate.  Forward to the address
   --  versions above.
   procedure Copy (C : Channel; Dst, Src : DMA_Buffer; Length : Natural)
   with Pre => Length <= Src'Length and then Length <= Dst'Length
               and then Src'Length mod DMA_Alignment = 0
               and then Dst'Length mod DMA_Alignment = 0;
   procedure Start (C : Channel; Dir : Direction; Buffer : DMA_Buffer; Length : Natural)
   with Pre => Length <= Buffer'Length and then Buffer'Length mod DMA_Alignment = 0;
   procedure Start_Loop (C : Channel; Buffer : DMA_Buffer; Length : Natural)
   with Pre => Length <= Buffer'Length and then Buffer'Length mod DMA_Alignment = 0;

   --  Arm a CONTINUOUS looped transmit of a LARGE buffer -- bigger than the 4095-
   --  byte single-descriptor limit -- on C's OUT path: build a RING of N (<=
   --  Max_Chain) descriptors that between them cover Buffer, the last linking
   --  back to the first, so the peripheral replays the whole buffer forever with
   --  no gap.  This is the display-framebuffer path: stream an LCD framebuffer to
   --  LCD_CAM continuously.  Buffer may be in PSRAM (32-byte aligned); it is
   --  written back to PSRAM before the loop starts (and burst mode is enabled).
   --  After the CPU DRAWS into a live framebuffer, call Flush to push the changes
   --  to PSRAM so the running DMA re-reads them.  The descriptor ring is a single
   --  shared, internal-SRAM array, so one chained loop runs at a time.  Length in
   --  1 .. Max_Chain_Bytes.  No-op on an invalid handle or over-range Length.
   Max_Chain       : constant := 256;                 --  descriptor ring capacity
   Chain_Chunk     : constant := 4080;                --  bytes per descriptor
   Max_Chain_Bytes : constant := Max_Chain * Chain_Chunk;   --  ~1.04 MB
   procedure Start_Loop_Chain (C : Channel; Buffer : System.Address; Length : Natural)
   with Pre => Length = 0 or else Is_DMA_Capable (Buffer);
   procedure Start_Loop_Chain (C : Channel; Buffer : DMA_Buffer; Length : Natural)
   with Pre => Length <= Buffer'Length and then Buffer'Length mod DMA_Alignment = 0;

   --  Retarget the running Start_Loop_Chain ring at New_Base without restarting
   --  the engine (the looping DMA re-reads each node from memory every pass).
   --  Called during vertical blanking, this flips a double-buffered display to
   --  the other framebuffer with no tear.  New_Base must be the same length as
   --  the active chain; write-back New_Base (Flush) before flipping if it is PSRAM.
   procedure Repoint_Chain (C : Channel; New_Base : System.Address);

   --  Flush the OUT FIFO and restart the running Start_Loop_Chain ring from its
   --  first node (next DMA byte = buffer byte 0).  Used ONCE, VSYNC-synced, to
   --  pin the otherwise-random startup phase of a direct-from-PSRAM display.
   procedure Restart_Loop_Chain (C : Channel);

   --  Write the CPU's writes to a PSRAM region back so a running DMA re-reads the
   --  new bytes (a no-op for internal SRAM).  Call after drawing into a live
   --  framebuffer that Start_Loop_Chain is streaming.
   procedure Flush (Buffer : System.Address; Length : Natural);
   procedure Flush (Buffer : DMA_Buffer; Length : Natural)
   with Pre => Length <= Buffer'Length;

   --  Gapless DOUBLE-BUFFERED streaming (Mem_To_Periph).  Loop the two halves of
   --  Buffer forever -- Half_Length bytes each -- as one uninterrupted transfer
   --  (like Start_Loop, so no inter-buffer restart gap), but fire a completion
   --  as each half drains so a producer can refill the half the DMA has left.
   --  Await_Half blocks until a half finishes and returns which one (0 or 1) is
   --  now safe to overwrite; the refill is thus paced by the DMA itself, not a
   --  timer, so a continuously-generated signal never drifts or glitches.
   --  Half_Length in 1 .. Max_Transfer; Buffer (both halves) in internal SRAM.
   --  Stop (C, Mem_To_Periph) ends it.
   procedure Start_Stream (C : Channel; Buffer : System.Address; Half_Length : Natural)
   with Pre => Half_Length = 0 or else Is_DMA_Capable (Buffer);

   function Await_Half (C : Channel) return Ring_Half;

   --  Like Start_Stream, but each of the two Half_Bytes halves is covered by
   --  SEVERAL descriptors, so a half may be much larger than the 4095-byte single-
   --  descriptor cap -- yet still fires just ONE completion per half (Suc_EOF on
   --  the last descriptor of each).  Big halves = a low interrupt rate the refill
   --  hook can sustain (an LCD bounce buffer).  Buffer (both halves) in internal
   --  SRAM; Half_Bytes any size up to the descriptor budget.  Stop ends it.
   procedure Start_Bounce (C : Channel; Buffer : System.Address; Half_Bytes : Natural);

   --  Optional refill HOOK for Start_Stream.  When set, the DMA's per-half
   --  completion interrupt calls it directly -- passing the half (0/1) that just
   --  drained -- INSTEAD of waking an Await_Half producer.  This removes the
   --  task-wakeup latency, which matters when the half period is very short (an
   --  LCD bounce buffer drains a 4 KB half in ~125 us; a task that refills it a
   --  few us late lets the DMA lap it and re-send stale bytes -> flicker).  The
   --  hook runs in INTERRUPT context: it must not block or allocate -- keep it a
   --  short copy into the just-drained half.  It must be a library-level
   --  procedure.  Set before Start_Stream; Stop clears it.
   type Stream_Refill is access procedure (Half : Ring_Half);
   procedure Set_Stream_Refill (C : Channel; Hook : Stream_Refill);

   --  Gapless double-buffered CAPTURE (Periph_To_Mem): the receive mirror of
   --  Start_Stream.  The DMA fills the two Half_Length-byte halves of Buffer
   --  forever as one uninterrupted transfer; Await_In_Half blocks until a half
   --  has been FILLED and returns which one (0 or 1) is ready to read -- so a
   --  continuous consumer (a demodulator) is paced by the DMA itself and never
   --  misses samples.  Stop (C, Periph_To_Mem) ends it.
   procedure Start_In_Stream (C : Channel; Buffer : System.Address; Half_Length : Natural)
   with Pre => Half_Length = 0 or else Is_DMA_Capable (Buffer);

   function Await_In_Half (C : Channel) return Ring_Half;

   --  True once the Dir transfer has signalled success-EOF (also True for an
   --  invalid handle, so a Wait never hangs on one).
   function Done (C : Channel; Dir : Direction) return Boolean;

   --  Block until Done (C, Dir).  After a short spin (for transfers that finish
   --  before an interrupt would pay off) the calling task SUSPENDS and the
   --  channel's GDMA end-of-transfer interrupt wakes it -- so the core is free
   --  for the whole transfer rather than busy-waiting.  Needs the tasking
   --  runtime (embedded/full), like the rest of the Session drivers.
   procedure Wait (C : Channel; Dir : Direction);

   --  Halt a channel direction and detach its descriptor (pulses the engine
   --  reset).  Call after a timeout so a late recovery cannot DMA into a buffer
   --  the caller has already reused.
   procedure Stop (C : Channel; Dir : Direction);

   --  Detach one direction of the channel from its peripheral (PERI_SEL to an
   --  unmatched value).  Claim binds BOTH directions, but a peripheral may only
   --  be served by one channel per direction -- so when two channels serve the
   --  same peripheral (e.g. one streaming TX, another streaming RX), each must
   --  unbind the direction it does not use, or the idle binding shadows the
   --  active one and that direction transfers nothing.
   procedure Unbind (C : Channel; Dir : Direction);

private
   type Channel is new Ada.Finalization.Limited_Controlled with record
      Id    : Channel_Id := 0;
      Valid : Boolean := False;
   end record;
   overriding
   procedure Finalize (C : in out Channel);   --  auto-release on scope exit
end ESP32S3.GDMA;
