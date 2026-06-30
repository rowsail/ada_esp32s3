with Interfaces;               use Interfaces;
with System.Machine_Code;      use System.Machine_Code;
with ESP32S3_Registers;        use ESP32S3_Registers;
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
   --  never falsely dropped; when nothing drains we give up after 50 ms and drop
   --  the rest, so a host-less board is delayed at most ~50 ms per Send.  CCOUNT
   --  runs at the 240 MHz core clock and wraps every ~17.9 s; the 50 ms window is
   --  well within one wrap, so modular subtraction is safe.
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
      Asm ("rsr.ccount %0",
           Outputs  => Unsigned_32'Asm_Output ("=a", R),
           Volatile => True);
      return R;
   end CCOUNT;

   function Endpoint_Ready return Boolean is
     (USB_DEVICE_Periph.EP1_CONF.SERIAL_IN_EP_DATA_FREE) with Inline;

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
   -- Send --
   ----------

   --  Push raw bytes straight to the IN FIFO, 64 bytes per USB packet, flushing
   --  each with WR_DONE.  Bails (dropping the remainder) if the host isn't
   --  draining within the timeout, so a host-less board never hangs.
   procedure Send (S : String) is
      I : Integer := S'First;
      N : Natural;
   begin
      while I <= S'Last loop
         if not Wait_Ready then
            return;   --  host not draining: drop the remainder rather than hang
         end if;

         N := 0;
         while I <= S'Last and then N < Fifo_Size loop
            USB_DEVICE_Periph.EP1 :=
              (RDWR_BYTE => Byte (Character'Pos (S (I))), others => <>);
            I := I + 1;
            N := N + 1;
         end loop;

         USB_DEVICE_Periph.EP1_CONF := (WR_DONE => True, others => <>);
      end loop;
   end Send;

   -----------
   -- Flush --
   -----------

   procedure Flush is
   begin
      if Len > 0 then
         Send (Buf (1 .. Len));
         Len := 0;
      end if;
   end Flush;

   ---------
   -- Put --
   ---------

   procedure Put (C : Character) is
   begin
      if Len = Buf_Size then     --  buffer full: make room first
         Flush;
      end if;
      Len := Len + 1;
      Buf (Len) := C;
      if C = ASCII.LF then       --  flush whole lines as they complete
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

end ESP32S3.Console;
