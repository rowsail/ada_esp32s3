with Interfaces;
with Ada.Finalization;
with ESP32S3.GPIO;

--  ESP32-S3 I2C master (I2C0 / I2C1), task-safe.
--
--  This is the ONLY I2C interface the application sees.  The raw register
--  driver lives in the private child ESP32S3.I2C.Engine (un-`with`-able from
--  outside this subtree), so the unsynchronised "ZFP" primitives can't be
--  called by accident -- access is always mediated here.
--
--  Each host is guarded by a protected object; Acquire hands out a limited,
--  non-copyable Session that owns the host exclusively (other tasks suspend on
--  Acquire until it is released).  The blocking transaction (Write / Read) runs
--  OUTSIDE the protected lock -- the lock only arbitrates ownership, never held
--  across the bus busy-wait.
--
--  This first cut is a polled, single-segment master: each Write / Read is one
--  complete START..STOP transaction.  Read takes up to 32 data bytes (the RX
--  FIFO depth); Write takes up to 31, because the address byte shares the 32-deep
--  TX FIFO with the payload.  Requires a tasking runtime (Jorvik or richer).

package ESP32S3.I2C is

   --  The two general-purpose I2C controllers.
   type I2C_Host is (I2C0, I2C1);

   --  7-bit slave address (the R/W bit is added by the driver).
   subtype Slave_Address is Natural range 0 .. 16#7F#;

   type Byte is new Interfaces.Unsigned_8;
   type Byte_Array is array (Natural range <>) of Byte;

   --  Largest single-transaction payload (the controller's TX/RX FIFO depth).
   Max_Transfer : constant := 32;

   --  An exclusive hold on a host.  Limited (cannot be copied) and CONTROLLED:
   --  releases the host automatically on scope exit, including during exception
   --  unwinding, so a fault between Acquire and Release can't leak the lock.
   --  Release stays available to hand the host back early (idempotent).  This
   --  relies on finalization -> these task-safe drivers target embedded/full.
   type Session is limited private;

   --  True while S holds its host (between Acquire and Release / finalization);
   --  the ownership guard the Write / Read preconditions below rely on.
   function Is_Held (S : Session) return Boolean;

   ----------------------------------------------------------------------------
   --  One-time host configuration -- call once per host at startup, before any
   --  task contends for it (single-threaded).
   ----------------------------------------------------------------------------

   --  Bring Host up as a master at the given SCL bit clock (Hz, standard 100
   --  kHz / fast 400 kHz are typical; clamped to a sane range).
   procedure Setup (Host : I2C_Host; Clock_Hz : Positive := 100_000);

   --  Route the host's SCL/SDA to physical pads as open-drain lines with the
   --  internal pull-ups enabled (no external resistors needed for a quick
   --  bring-up; add real pull-ups for production buses).  Scl/Sda are validated
   --  GPIO pins -- a reserved/absent pad is rejected at compile or run time.
   procedure Configure_Pins
     (Host : I2C_Host; Scl : ESP32S3.GPIO.Pin_Id; Sda : ESP32S3.GPIO.Pin_Id);

   ----------------------------------------------------------------------------
   --  Concurrent, mutually-exclusive use.
   ----------------------------------------------------------------------------

   --  Raised by Acquire if Host was never Setup -- configuration must precede
   --  ownership (see the one-time configuration section above).
   Not_Initialized : exception;

   --  Raised by Write/Read if the Session does not currently hold a host.  Both
   --  reach the hardware only through one ownership-checked gateway in the body,
   --  so "transact without holding the host" fails loudly.
   Not_Owned : exception;

   --  Take exclusive ownership of a Setup host.  Suspends until no other task
   --  holds it.  Keep it across a whole transaction, then Release.  Raises
   --  Not_Initialized if Host was never Setup.
   procedure Acquire (S : in out Session; Host : I2C_Host)
   with Post => Is_Held (S);

   --  Master write: START, (Addr<<1 | W), Data bytes, STOP.  Success is True
   --  iff the slave ACKed the address and every byte.  Data length 0 sends an
   --  address-only probe (useful for bus scanning).  Blocking.  Raises
   --  Not_Owned unless S currently holds a host.
   procedure Write
     (S         : Session;
      Addr      : Slave_Address;
      Data      : Byte_Array;
      Success   : out Boolean;
      Check_Ack : Boolean := True)
   with Pre => Is_Held (S) and then Data'Length <= Max_Transfer - 1;

   --  Master read: START, (Addr<<1 | R), read Data'Length bytes (ACK all but
   --  the last, NACK the last), STOP.  Success is True iff the slave ACKed the
   --  address.  Blocking.  Raises Not_Owned unless S currently holds a host.
   procedure Read
     (S : Session; Addr : Slave_Address; Data : out Byte_Array; Success : out Boolean)
   with Pre => Is_Held (S) and then Data'Length <= Max_Transfer;

   --  Relinquish ownership (lets a waiting task proceed).  Harmless if already
   --  released.  Always release a Session you Acquired.
   procedure Release (S : in out Session)
   with Post => not Is_Held (S);

private
   type Session is new Ada.Finalization.Limited_Controlled with record
      Host   : I2C_Host := I2C0;
      Active : Boolean := False;   --  holds Host's guard
   end record;

   overriding
   procedure Finalize (S : in out Session);   --  auto-release on scope exit
   function Is_Held (S : Session) return Boolean is (S.Active);

end ESP32S3.I2C;
