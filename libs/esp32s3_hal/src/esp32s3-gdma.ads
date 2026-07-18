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

   function Await_Half (C : Channel) return Natural;

   --  Gapless double-buffered CAPTURE (Periph_To_Mem): the receive mirror of
   --  Start_Stream.  The DMA fills the two Half_Length-byte halves of Buffer
   --  forever as one uninterrupted transfer; Await_In_Half blocks until a half
   --  has been FILLED and returns which one (0 or 1) is ready to read -- so a
   --  continuous consumer (a demodulator) is paced by the DMA itself and never
   --  misses samples.  Stop (C, Periph_To_Mem) ends it.
   procedure Start_In_Stream (C : Channel; Buffer : System.Address; Half_Length : Natural)
   with Pre => Half_Length = 0 or else Is_DMA_Capable (Buffer);

   function Await_In_Half (C : Channel) return Natural;

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
