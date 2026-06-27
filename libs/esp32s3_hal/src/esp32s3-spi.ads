with System;
with Ada.Finalization;
with ESP32S3.GPIO;

--  ESP32-S3 general-purpose SPI master (SPI2 / SPI3), task-safe.
--
--  This is the ONLY SPI interface the application sees.  The raw register
--  driver lives in the private child ESP32S3.SPI.Engine (un-`with`-able from
--  outside this subtree), so the unsynchronised "ZFP" primitives can't be
--  called by accident -- access is always mediated here.
--
--  Each host is guarded by a protected object; Acquire hands out a limited,
--  non-copyable Session that owns the host exclusively (other tasks suspend on
--  Acquire until it is released).  The blocking DMA Transfer runs OUTSIDE the
--  protected lock -- the lock only arbitrates ownership.  A Session releases
--  automatically when it goes out of scope.
--
--  Requires a tasking runtime (Jorvik light-tasking or richer).
package ESP32S3.SPI is

   --  The two general-purpose hosts (SPI0/SPI1 are the flash/PSRAM controllers
   --  and are deliberately not offered).
   type SPI_Host is (SPI2, SPI3);

   --  SPI clock polarity/phase mode (0 .. 3).
   subtype SPI_Mode is Natural range 0 .. 3;

   --  Sentinel: leave that line unrouted / inherit the host default (= No_Pin).
   No_Pin : constant ESP32S3.GPIO.Pad_Number := ESP32S3.GPIO.No_Pin;

   --  Optional application-driven chip select.  A device may bring its own select
   --  instead of the host's single hardware CS0 pin, so "chip select" can be a
   --  plain GPIO, several GPIOs feeding a 3:8 address decoder, an I/O-expander
   --  line, etc.  Registered at Acquire (see below); the driver calls it with
   --  Active => True to select the device before its bytes move and False to
   --  deselect when the transaction ends (see Select_Device).  Ctx is the
   --  per-device context handed back on every call -- the mapping lives entirely
   --  in the callback (cf. ESP32S3.Block_Dev's Ctx).
   --
   --  Two requirements, both from where it runs:
   --    * It must be a library-level subprogram with NO captured state -- this
   --      HAL builds under No_Implicit_Dynamic_Code, so a closure would emit a
   --      GNAT trampoline that faults on the S3.  Per-device state travels in Ctx.
   --    * It must be fast, non-blocking, and must not raise: it runs while the
   --      bus lock is held (and at scope exit during finalization).  Drive the
   --      line(s) and return -- no delay, no Acquire, no I2C round-trip.
   type CS_Select is access procedure (Ctx : System.Address; Active : Boolean);

   --  An exclusive hold on a host.  Limited (cannot be copied -- two tasks can
   --  never share one) and CONTROLLED: it releases the host automatically when
   --  it goes out of scope, including during exception unwinding, so a fault
   --  between Acquire and Release can't leak the lock.  Release stays available
   --  to hand the host back early (it is idempotent).  This relies on
   --  finalization, so these task-safe drivers target the embedded/full profile.
   type Session is limited private;

   ----------------------------------------------------------------------------
   --  One-time host configuration -- call once per host at startup, before any
   --  task contends for it (single-threaded).
   ----------------------------------------------------------------------------

   --  Bring Host up as a full-duplex master and Claim its GDMA channel.  Mode
   --  and bit clock are NOT set here -- they are a per-device property applied at
   --  Acquire, so two devices on one host can run different modes/clocks.
   procedure Setup (Host : SPI_Host);

   --  Route the host's SHARED bus lines to physical pads -- the wires every
   --  device on the host uses (Sclk/Mosi/Miso), plus an optional hardware CS0
   --  pad.  Each line is a validated GPIO pin (reserved/absent pads are caught at
   --  compile or run time); pass No_Pin to leave it unrouted.  Call once after
   --  Setup.  A device wired to a DIFFERENT set of pads on the same controller
   --  overrides these per-hold via Acquire's Sclk/Mosi/Miso (the rare case).
   procedure Configure_Pins (Host : SPI_Host;
                             Sclk : ESP32S3.GPIO.Optional_Pin;
                             Mosi : ESP32S3.GPIO.Optional_Pin;
                             Miso : ESP32S3.GPIO.Optional_Pin;
                             Cs   : ESP32S3.GPIO.Optional_Pin := No_Pin);

   --  Change just the bit clock of a Setup host (Hz, clamped to ~80 kHz .. 80
   --  MHz) mid-hold, with no GDMA re-Claim.  Acquire already applies each
   --  device's clock; this is for a device that changes speed WITHIN one hold
   --  (e.g. an SD card raising its clock after the init handshake).
   procedure Set_Clock (Host : SPI_Host; Hz : Positive);

   --  Internal MOSI->MISO loopback through one GPIO pad (self-test; no wiring).
   procedure Enable_Loopback (Host : SPI_Host; Pad : ESP32S3.GPIO.Pin_Id);

   ----------------------------------------------------------------------------
   --  Concurrent, mutually-exclusive use.
   ----------------------------------------------------------------------------

   --  Raised by Acquire if Host was never Setup -- configuration must precede
   --  ownership (see the one-time configuration section above).
   Not_Initialized : exception;

   --  Raised by Transfer if its Session does not currently hold a host.  The
   --  transfer reaches the hardware only through one ownership-checked gateway
   --  in the body, so "transfer without holding the host" fails loudly.
   Not_Owned : exception;

   --  Take exclusive ownership of a Setup host and apply THIS device's bus
   --  configuration.  Suspends until no other task holds it.  Keep it across a
   --  whole transaction, then Release / let it go out of scope.  Raises
   --  Not_Initialized if Host was never Setup.
   --
   --  Applied under the exclusive hold (so reprogramming can't collide with
   --  another device's transfer):
   --    * Mode, Clock_Hz: this device's SPI mode and bit clock -- a per-device
   --      property, so a flash at mode 0 / 8 MHz and a display at mode 3 / 40 MHz
   --      can share one host.
   --    * Sclk, Mosi, Miso: usually No_Pin = keep the host's Setup routing (the
   --      common shared-bus case).  Set them only for a device wired to a
   --      DIFFERENT set of pads on the same controller -- the GPIO matrix is then
   --      re-routed to this device's pins for the hold.
   --
   --  Chip select, in order of preference:
   --    * CS_Pin set (the common case): the driver drives that GPIO itself as an
   --      active-low software chip select -- it configures the pad as an output,
   --      parks it deselected, and Select_Device holds it low across the whole
   --      transaction.  No callback, no extra setup.
   --    * Select_CB set: the device drives its OWN select through that callback
   --      (Ctx handed back on every call) -- for a select that is not one plain
   --      GPIO, e.g. several GPIOs into a 3:8 decoder or an I/O-expander line.
   --    * neither (both defaulted): the host's single hardware CS0, routed by
   --      Configure_Pins, is used exactly as before (it toggles per Transfer).
   --  With CS_Pin or Select_CB, the hardware CS0 is suppressed for this hold so it
   --  cannot disturb another device sharing the bus.
   procedure Acquire (S         : in out Session;
                      Host      : SPI_Host;
                      Mode      : SPI_Mode := 0;
                      Clock_Hz  : Positive := 1_000_000;
                      Sclk      : ESP32S3.GPIO.Optional_Pin := No_Pin;
                      Mosi      : ESP32S3.GPIO.Optional_Pin := No_Pin;
                      Miso      : ESP32S3.GPIO.Optional_Pin := No_Pin;
                      CS_Pin    : ESP32S3.GPIO.Optional_Pin := No_Pin;
                      Select_CB : CS_Select      := null;
                      Ctx       : System.Address  := System.Null_Address);

   --  Assert (On => True) / deassert (On => False) this device's chip select --
   --  its CS_Pin or its callback, whichever was given at Acquire.  Bracket a
   --  whole device command so CS is held across a multi-phase transaction
   --  (opcode || address || data) rather than dropping between Transfers:
   --     Select_Device (S, True);  Transfer (..); Transfer (..);  Select_Device (S, False);
   --  No-op for a hardware-CS Session (neither CS_Pin nor Select_CB given) --
   --  there the peripheral toggles CS0 per Transfer.  Raises Not_Owned unless S
   --  holds a host.
   procedure Select_Device (S : in out Session; On : Boolean);

   --  Full-duplex DMA transfer of Length bytes on the held host: shift Tx out on
   --  MOSI, capture MISO into Rx.  Blocking.  Buffers in internal SRAM.  Raises
   --  Not_Owned unless S currently holds a host.  Length must be 1 .. 4095 (one
   --  DMA descriptor) -- the precondition catches an out-of-range length, which
   --  the engine would otherwise drop silently.
   procedure Transfer (S : Session; Tx, Rx : System.Address; Length : Natural)
     with Pre => Length in 1 .. 4095;

   --  Relinquish ownership (lets a waiting task proceed).  Harmless if already
   --  released.  Always release a Session you Acquired.
   procedure Release (S : in out Session);

private
   type Session is new Ada.Finalization.Limited_Controlled with record
      Host      : SPI_Host       := SPI2;
      Active    : Boolean        := False;                 --  holds Host's guard
      CS_Pin    : ESP32S3.GPIO.Optional_Pin := No_Pin;     --  driver-driven sw CS
      Select_CB : CS_Select      := null;                  --  app CS hook, null = hw CS0
      Ctx       : System.Address := System.Null_Address;   --  per-device context
      Selected  : Boolean        := False;                 --  CS currently asserted?
   end record;
   --  Finalize releases the host AND, if Selected, calls Select_CB (Off) first --
   --  so a fault between select and deselect can never leave a device asserted.
   overriding procedure Finalize (S : in out Session);   --  auto-release on scope exit
end ESP32S3.SPI;
