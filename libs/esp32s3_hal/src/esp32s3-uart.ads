with Interfaces;
with Ada.Finalization;
with ESP32S3.GPIO;

--  ESP32-S3 UART (UART0 / UART1 / UART2), task-safe.
--
--  This is the ONLY UART interface the application sees.  The raw register
--  driver lives in the private child ESP32S3.UART.Engine (un-`with`-able from
--  outside this subtree), so the unsynchronised primitives can't be called by
--  accident -- access is always mediated here.
--
--  Each port is guarded by a protected object; Acquire hands out a limited,
--  non-copyable Session that owns the port exclusively (other tasks suspend on
--  Acquire until it is released).  The blocking Write / Read run OUTSIDE the
--  protected lock -- the lock only arbitrates ownership.
--
--  Like the other HAL drivers this targets the embedded profile (full
--  exceptions); see the library README.  Requires a tasking runtime.
package ESP32S3.UART is

   --  The three general-purpose UART controllers.  (UART0 is the ROM console on
   --  dev boards, but this bare runtime uses USB-Serial-JTAG for the console, so
   --  UART0's pads are free to repurpose.)
   type UART_Port is (UART0, UART1, UART2);

   subtype Baud_Rate is Positive range 300 .. 5_000_000;
   type Data_Bits   is range 5 .. 8;
   type Parity_Mode is (None, Even, Odd);
   type Stop_Bits   is (One, Two);

   type Byte is new Interfaces.Unsigned_8;
   type Byte_Array is array (Natural range <>) of Byte;

   --  An exclusive hold on a port.  Limited (cannot be copied) and CONTROLLED:
   --  releases the port automatically on scope exit, including during exception
   --  unwinding, so a fault between Acquire and Release can't leak the lock.
   --  Release stays available to hand the port back early (idempotent).  This
   --  relies on finalization -> these task-safe drivers target embedded/full.
   type Session is limited private;

   ----------------------------------------------------------------------------
   --  Concurrent, mutually-exclusive use.  A port is configured and used ONLY
   --  through a held Session: Acquire takes the port AND configures it, and
   --  every transfer plus every later configuration call runs through that
   --  Session -- so changing a setting requires owning the port, and can never
   --  race another task.  There is no port-based setup that precedes ownership:
   --  you cannot touch a UART you do not hold.
   ----------------------------------------------------------------------------

   --  Raised by ANY operation below (transfer or configuration) if its Session
   --  does not currently hold a port.  Every such call reaches the hardware
   --  only through one ownership-checked gateway in the body, so "use a port
   --  without holding it" fails loudly rather than silently.
   Not_Owned : exception;

   --  Take exclusive ownership of Port, suspending until it is free, AND shape
   --  it to the link in the same call.  The first Acquire of a port creates the
   --  controller; every Acquire then (re)applies the baud + frame format and
   --  routes the four optional pins, so the port ends up in exactly the state
   --  you ask for (it does NOT inherit a previous holder's settings).  Defaults
   --  are 115200 8-N-1 with no pins routed; the pins are all optional (No_Pin =
   --  unrouted), so a link routes only what it uses:
   --     Acquire (S, UART1);                           --  bare: 115200 8-N-1
   --     Acquire (S, UART1, Tx => 17, Rx => 16);       --  full-duplex link
   --     Acquire (S, UART1, Rx => 18);                 --  RX only (e.g. GPS)
   --     Acquire (S, UART1, Tx => 17, Rx => 16,
   --                        Rts => 19, Cts => 20);     --  + RTS/CTS flow ctl
   --
   --  Giving Rts enables RX flow control: the controller drives RTS to pause
   --  the peer once our RX FIFO reaches Rx_Flow_Threshold bytes (of 128).
   --  Giving Cts enables TX flow control: the transmitter only sends while the
   --  peer asserts CTS.  Inputs (RX, CTS) get an internal pull-up so an idle
   --  line reads high.  Re-route pins or change one attribute later with
   --  Reconfigure or the finer calls below.
   procedure Acquire
     (S      : in out Session;
      Port   : UART_Port;
      Baud   : Baud_Rate   := 115_200;
      Bits   : Data_Bits   := 8;
      Parity : Parity_Mode := None;
      Stop   : Stop_Bits   := One;
      Tx     : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Rx     : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Rts    : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Cts    : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Rx_Flow_Threshold : Natural := 100);

   --  Re-apply the whole baud + frame format + pin routing on the port S
   --  already holds, without releasing it -- the same settings Acquire takes,
   --  for a link that renegotiates mid-hold.  Like Acquire it sets the FULL
   --  state, so an omitted pin is unrouted and an omitted attribute returns to
   --  its default.  Raises Not_Owned unless S currently holds a port.  (To
   --  change ONE attribute and leave the rest, use the finer setters below.)
   procedure Reconfigure
     (S      : Session;
      Baud   : Baud_Rate   := 115_200;
      Bits   : Data_Bits   := 8;
      Parity : Parity_Mode := None;
      Stop   : Stop_Bits   := One;
      Tx     : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Rx     : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Rts    : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Cts    : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Rx_Flow_Threshold : Natural := 100);

   --  Push Data to the TX FIFO, waiting for room.  Returns once every byte is
   --  queued (not necessarily fully shifted out).  Raises Not_Owned unless S
   --  currently holds a port.
   procedure Write (S : Session; Data : Byte_Array);

   --  Read up to Data'Length bytes into Data, waiting briefly for each; Count is
   --  how many were actually received (short read on timeout).  Raises Not_Owned
   --  unless S currently holds a port.
   procedure Read (S : Session; Data : out Byte_Array; Count : out Natural);

   --  Bytes currently waiting in the RX FIFO.  Raises Not_Owned unless S holds
   --  a port.
   function Available (S : Session) return Natural;

   --  ----  Finer configuration -- all require the held port  ----------------
   --  Each acts on the port S currently holds and raises Not_Owned unless S is
   --  active (the held Session is the proof that no other task can be mid-
   --  transfer).  Like the transfers above, they reach the hardware only through
   --  the body's single ownership-checked gateway.

   --  Re-program one frame attribute independently, leaving the others (and the
   --  pin routing) untouched.  Each is a read-modify-write of just that
   --  attribute and takes effect immediately.
   procedure Set_Baud      (S : Session; Baud   : Baud_Rate);
   procedure Set_Data_Bits (S : Session; Bits   : Data_Bits);
   procedure Set_Parity    (S : Session; Parity : Parity_Mode);
   procedure Set_Stop_Bits (S : Session; Stop   : Stop_Bits);

   --  Re-route the held port's lines to physical pads (same semantics as
   --  Configure's pin parameters; sets the FULL flow-control + inversion state,
   --  so a reconfigure without a line also turns that line/flow off).  ALL
   --  optional.
   --  The *_Invert flags set each line's polarity (see Set_Inversion); default
   --  False = active-high / standard idle-high UART.
   procedure Configure_Pins
     (S    : Session;
      Tx   : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Rx   : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Rts  : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Cts  : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Rx_Flow_Threshold : Natural := 100;
      Tx_Invert  : Boolean := False;
      Rx_Invert  : Boolean := False;
      Rts_Invert : Boolean := False;
      Cts_Invert : Boolean := False);

   --  Independently invert (or un-invert) each line's polarity on the held port.
   --  Sets the full state of all four lines; default False clears inversion.
   procedure Set_Inversion
     (S    : Session;
      Tx   : Boolean := False;
      Rx   : Boolean := False;
      Rts  : Boolean := False;
      Cts  : Boolean := False);

   --  Controller-level internal TX->RX loopback on the held port (a self-test
   --  that needs NO pins and no wiring -- UART is push-pull, so unlike I2C this
   --  fully works on-chip): bytes written come straight back on Read.
   procedure Enable_Loopback (S : Session; On : Boolean := True);

   --  Relinquish ownership (lets a waiting task proceed).  Harmless if already
   --  released.  Always release a Session you Acquired.
   procedure Release (S : in out Session);

private
   type Session is new Ada.Finalization.Limited_Controlled with record
      Port   : UART_Port := UART0;
      Active : Boolean   := False;
   end record;
   overriding procedure Finalize (S : in out Session);   --  auto-release on scope exit
end ESP32S3.UART;
