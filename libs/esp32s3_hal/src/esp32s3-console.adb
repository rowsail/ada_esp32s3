with Interfaces;                   use Interfaces;
with System.Machine_Code;          use System.Machine_Code;
with ESP32S3_Registers;            use ESP32S3_Registers;
with ESP32S3_Registers.USB_DEVICE; use ESP32S3_Registers.USB_DEVICE;

package body ESP32S3.Console is

   --  The USB Serial/JTAG IN (device->host) FIFO holds one 64-byte packet; the
   --  packet is handed to the host when WR_DONE is written.  EP1_CONF.
   --  SERIAL_IN_EP_DATA_FREE reads 1 when the endpoint can take a new packet and
   --  drops to 0 after WR_DONE until the host drains it.
   Fifo_Size : constant := 64;

   --  Time-bounded wait for the host to drain the previous packet, measured with
   --  the Xtensa CCOUNT cycle counter so the bound is in real time regardless of
   --  per-iteration cost (a status-register read is a slow APB access).  50 ms is
   --  far above host USB poll latency (~1 ms), so output to a connected host is
   --  never falsely dropped.  This wait is only EVER reached once a host has been
   --  confirmed (see Host_Seen in Send); a never-connected board never enters it,
   --  so it pays no delay at all.  When a confirmed host stops draining we give up
   --  after 50 ms once, drop, and revert to non-blocking.  CCOUNT runs at the
   --  240 MHz core clock and wraps every ~17.9 s; the 50 ms window is well within
   --  one wrap, so modular subtraction is safe.
   Cycles_Per_Ms  : constant := 240_000;            --  240 MHz core clock
   Timeout_Cycles : constant := 50 * Cycles_Per_Ms; --  ~50 ms

   --  Line-coalescing TX buffer.  Many small Put/Write calls accumulate here and
   --  are pushed to the FIFO only on a newline, when the buffer fills, or on an
   --  explicit Flush -- so a log line composed of a dozen small writes (e.g. the
   --  numeric formatters in ESP32S3.Log) costs one or two USB packets instead of
   --  a dozen.  Trade-off: output with no trailing newline (a prompt, or a
   --  partial line right before a crash) stays buffered until the next newline or
   --  a Flush call -- call Flush before a long sleep / risky operation if you
   --  need the tail on the wire.  NOT reentrant: like the ROM printf it replaced,
   --  this is a debug console, not synchronised for concurrent loggers.
   Buf_Size : constant := 256;
   Buf      : String (1 .. Buf_Size);
   Len      : Natural := 0;

   --  EP1 and EP1_CONF are Volatile_Full_Access (every access is a single 32-bit
   --  bus op).  We therefore assign the WHOLE register with an aggregate: a
   --  partial-field write would force a read-modify-write, and READING EP1 pops
   --  the RX FIFO -- so the byte write in Send must never read EP1 first.

   function CCOUNT return Unsigned_32 is
      R : Unsigned_32;
   begin
      Asm
        ("rsr.ccount %0",
         Outputs  => Unsigned_32'Asm_Output ("=a", R),
         Volatile => True);
      return R;
   end CCOUNT;

   function Endpoint_Ready return Boolean
   is (USB_DEVICE_Periph.EP1_CONF.SERIAL_IN_EP_DATA_FREE)
   with Inline;

   --  Wait until the endpoint can accept a new packet.  False => no host drained
   --  it within Timeout_Cycles (host absent / not reading).
   function Wait_Ready return Boolean is
      Start : constant Unsigned_32 := CCOUNT;
   begin
      while not Endpoint_Ready loop
         if Unsigned_32'(CCOUNT - Start) >= Timeout_Cycles then
            return False;
         end if;
      end loop;
      return True;
   end Wait_Ready;

   ----------
   -- Emit --
   ----------

   --  Connection state.  We NEVER block waiting on a host we have not confirmed:
   --  Host_Seen starts False and is set only once we OBSERVE the FIFO drain (the
   --  endpoint going free again after we filled it -- proof a host is reading).
   --
   --  While Host_Seen is False, Emit is fully non-blocking: it writes a packet
   --  only if the FIFO is already free, otherwise it drops immediately.  So a
   --  board with NO USB host ever attached pays ZERO delay -- the console never
   --  affects running code (one register read, then write-if-free or return).
   --
   --  Once a host is confirmed, Emit applies the bounded ~50 ms backpressure so
   --  bursts to a connected host are never truncated; if that wait ever times out
   --  (the host went away / stopped reading) Host_Seen is cleared and we drop the
   --  remainder and revert to non-blocking after that single timeout.
   Host_Seen : Boolean := False;   --  observed the host drain a packet?
   Pending   : Boolean := False;   --  a written packet is awaiting drain

   --  Count of bytes that had to be dropped because no host was draining.
   --  Saturating; readable via Dropped_Bytes, cleared by Clear_Dropped, and also
   --  announced in-band by Flush (see below) so a reader sees gaps in the stream.
   Dropped : Unsigned_32 := 0;

   --  Optional drop-notification hook (see On_Drop).  In_Hook guards against a
   --  handler that writes to the console: its own dropped bytes are still tallied
   --  but must not re-enter the hook.
   Drop_Cb : Drop_Handler := null;
   In_Hook : Boolean := False;

   procedure Add_Dropped (Count : Natural) is
   begin
      if Count > 0 then
         if Dropped <= Unsigned_32'Last - Unsigned_32 (Count) then
            Dropped := Dropped + Unsigned_32 (Count);
         else
            Dropped := Unsigned_32'Last;   --  saturate
         end if;
         if Drop_Cb /= null and then not In_Hook then
            In_Hook := True;
            Drop_Cb (Count);              --  may re-enter the console; bounded
            In_Hook := False;
         end if;
      end if;
   end Add_Dropped;

   --  Push raw bytes to the IN FIFO, 64 bytes per USB packet, each ended with
   --  WR_DONE.  Returns the number of bytes it could NOT send (0 = all delivered)
   --  -- non-zero when no host is draining, so the caller can account the loss.
   function Emit (S : String) return Natural is
      I : Integer := S'First;
      N : Natural;
   begin
      while I <= S'Last loop
         if not Endpoint_Ready then
            --  FIFO still holds the previous packet.
            if not Host_Seen then
               return S'Last - I + 1;   --  no host confirmed: drop, never wait
            elsif not Wait_Ready then
               Host_Seen :=
                 False;      --  confirmed host went away: stop blocking
               return S'Last - I + 1;
            end if;
         elsif Pending then
            Host_Seen :=
              True;      --  drained since our last write => host present
         end if;

         --  Endpoint is free: write up to one 64-byte packet and send it.
         N := 0;
         while I <= S'Last and then N < Fifo_Size loop
            USB_DEVICE_Periph.EP1 :=
              (RDWR_BYTE => Byte (Character'Pos (S (I))), others => <>);
            I := I + 1;
            N := N + 1;
         end loop;

         USB_DEVICE_Periph.EP1_CONF := (WR_DONE => True, others => <>);
         Pending := True;
      end loop;
      return 0;
   end Emit;

   --------------------
   -- Announce_Drops --
   --------------------

   --  If output was dropped, prepend a notice the next time the host is draining,
   --  so a gap in the console stream is visible and quantified.  The notice is
   --  only counted as "delivered" (Dropped reset) if it itself got through; its
   --  own bytes are never added to Dropped.
   procedure Announce_Drops is
      Note : String (1 .. 40);
      L    : Natural := 0;

      procedure Lit (T : String) is
      begin
         Note (L + 1 .. L + T'Length) := T;
         L := L + T'Length;
      end Lit;

   begin
      if Dropped = 0 then
         return;
      end if;
      Lit ("[console: ");
      declare
         --  decimal of Dropped
         V : Unsigned_32 := Dropped;
         D : String (1 .. 10);
         F : Natural := D'Last + 1;
      begin
         loop
            F := F - 1;
            D (F) := Character'Val (Character'Pos ('0') + Integer (V mod 10));
            V := V / 10;
            exit when V = 0;
         end loop;
         Lit (D (F .. D'Last));
      end;
      Lit (" bytes dropped]" & ASCII.LF);

      if Emit (Note (1 .. L)) = 0 then
         --  announced only if it reached the host
         Dropped := 0;
      end if;
   end Announce_Drops;

   -----------
   -- Flush --
   -----------

   procedure Flush is
      N : Natural;
   begin
      Announce_Drops;                  --  surface any prior loss first
      if Len > 0 then
         --  Clear the buffer BEFORE emitting, so the drop hook (which may write
         --  to the console from inside Add_Dropped) re-enters a clean buffer
         --  rather than re-sending this line.
         N := Len;
         Len := 0;
         Add_Dropped (Emit (Buf (1 .. N)));
      end if;
   end Flush;

   ---------
   -- Put --
   ---------

   procedure Put (C : Character) is
   begin
      if Len = Buf_Size then
         --  buffer full: make room first
         Flush;
      end if;
      Len := Len + 1;
      Buf (Len) := C;
      if C = ASCII.LF then
         --  flush whole lines as they complete
         Flush;
      end if;
   end Put;

   -----------
   -- Write --
   -----------

   procedure Write (S : String) is
   begin
      for I in S'Range loop
         Put (S (I));
      end loop;
   end Write;

   -------------------
   -- Dropped_Bytes --
   -------------------

   function Dropped_Bytes return Interfaces.Unsigned_32
   is (Dropped);

   -------------------
   -- Clear_Dropped --
   -------------------

   procedure Clear_Dropped is
   begin
      Dropped := 0;
   end Clear_Dropped;

   -------------
   -- On_Drop --
   -------------

   procedure On_Drop (Handler : Drop_Handler) is
   begin
      Drop_Cb := Handler;
   end On_Drop;

   ----------
   -- Read --
   ----------

   --  SERIAL_OUT_EP_DATA_AVAIL reads 1 while the OUT (host->device) FIFO holds
   --  unread bytes; each read of EP1 pops one byte and, when the FIFO empties,
   --  clears the flag.  EP1 is Volatile_Full_Access, so the single read below is
   --  one 32-bit bus op that both returns and consumes the byte -- we must not
   --  touch EP1 unless a byte is actually available, or we would pop nothing / a
   --  stale value.
   procedure Read (C : out Character; Available : out Boolean) is
   begin
      if USB_DEVICE_Periph.EP1_CONF.SERIAL_OUT_EP_DATA_AVAIL then
         C := Character'Val (Natural (USB_DEVICE_Periph.EP1.RDWR_BYTE));
         Available := True;
      else
         C := ASCII.NUL;
         Available := False;
      end if;
   end Read;

end ESP32S3.Console;
