with Ada.Finalization;
with ESP32S3.GPIO;

--  ESP32-S3 RMT (Remote Control / "infinitely-flexible pulse generator").
--
--  RMT transmits and receives sequences of {level, duration} pulses -- the
--  workhorse for IR remotes, WS2812 ("NeoPixel") LEDs, 1-Wire, and any custom
--  bit-banged timing.  The S3 has eight channels: 0 .. 3 transmit, 4 .. 7
--  receive, each with a 48-symbol RAM block.  A pulse pair is one symbol (two
--  {level, duration} fields); duration is in channel ticks, whose length you set
--  via the channel's resolution.
--
--  Ownership: a channel is a shared resource handed out as a CLAIMED handle.  A
--  handle is LIMITED (non-copyable) and CONTROLLED (releases its channel
--  automatically on scope exit, including on an exception).  TX and RX channels
--  are distinct handle types so the two can't be confused.  Uses finalization,
--  so it targets the embedded/full profile.

package ESP32S3.RMT is

   type TX_Index is range 0 .. 3;             --  the four transmit channels
   type RX_Index is range 0 .. 3;             --  the four receive channels

   --  A duration, in channel ticks (15-bit; tick length = 1 / Resolution_Hz).
   type Tick_Count is range 0 .. 32_767;

   --  One RMT symbol: two consecutive pulses (a level held for a duration).
   type RMT_Symbol is record
      Level0    : Boolean := False;
      Duration0 : Tick_Count := 0;
      Level1    : Boolean := False;
      Duration1 : Tick_Count := 0;
   end record;
   for RMT_Symbol use
     record
       Duration0 at 0 range 0 .. 14;
       Level0 at 0 range 15 .. 15;
       Duration1 at 0 range 16 .. 30;
       Level1 at 0 range 31 .. 31;
     end record;
   for RMT_Symbol'Size use 32;

   type Symbol_Array is array (Natural range <>) of RMT_Symbol;

   --  Non-copyable handles to a claimed channel (check Is_Valid after Claim).
   type TX_Channel is limited private;
   type RX_Channel is limited private;

   ----------------------------------------------------------------------------
   --  Transmit.
   ----------------------------------------------------------------------------

   procedure Claim (C : in out TX_Channel; Index : TX_Index);
   function Is_Valid (C : TX_Channel) return Boolean;
   procedure Release (C : in out TX_Channel);

   --  Configure C: each tick = 1 / Resolution_Hz seconds (e.g. 1_000_000 Ã¢ÂÂ 1 ÃÂµs),
   --  output routed to Pin.  Idle level is low.
   --
   --  Blocks (1 .. 4) gives the channel that many consecutive 48-symbol RAM
   --  blocks (Phase 1, "multi-block"), raising the one-shot Transmit ceiling to
   --  Blocks*48-1 symbols.  Blocks > 1 BORROWS the RAM of the higher-numbered TX
   --  channels (channel Index .. Index+Blocks-1), so don't also Claim those.
   procedure Configure
     (C             : in out TX_Channel;
      Resolution_Hz : Positive;
      Pin           : ESP32S3.GPIO.Pin_Id;
      Blocks        : Positive := 1)
   with Pre => Is_Valid (C) and then Blocks <= 4;

   --  Transmit Symbols and block until the channel finishes.  A burst up to the
   --  channel's RAM (Blocks*48-1 symbols) is loaded and sent in one shot; a
   --  LONGER burst is streamed by re-filling the symbol RAM in halves as it
   --  drains (Phase 2, "wrap"), so Symbols may be any length.  Because the call
   --  blocks and busy-polls the re-fill, keep higher-priority interrupts short.
   procedure Transmit (C : TX_Channel; Symbols : Symbol_Array)
   with Pre => Is_Valid (C);

   ----------------------------------------------------------------------------
   --  Receive.
   ----------------------------------------------------------------------------

   procedure Claim (C : in out RX_Channel; Index : RX_Index);
   function Is_Valid (C : RX_Channel) return Boolean;
   procedure Release (C : in out RX_Channel);

   --  Configure C at the given tick resolution, input from Pin.  Reception ends
   --  once the line stays idle for Idle_Ticks ticks.
   procedure Configure
     (C             : in out RX_Channel;
      Resolution_Hz : Positive;
      Pin           : ESP32S3.GPIO.Pin_Id;
      Idle_Ticks    : Tick_Count := 2_000)
   with Pre => Is_Valid (C);

   --  Arm the receiver (call just before the incoming burst).
   procedure Start (C : RX_Channel)
   with Pre => Is_Valid (C);

   --  Block until reception ends, then return the captured symbols in Into and
   --  how many were captured in Count (0 if none / timed out).
   procedure Receive (C : RX_Channel; Into : out Symbol_Array; Count : out Natural)
   with Pre => Is_Valid (C);

private
   type TX_Channel is new Ada.Finalization.Limited_Controlled with record
      Idx    : TX_Index := 0;
      Held   : Boolean := False;
      Blocks : Positive := 1;        --  RAM blocks claimed (set by Configure)
   end record;
   overriding
   procedure Finalize (C : in out TX_Channel);

   type RX_Channel is new Ada.Finalization.Limited_Controlled with record
      Idx  : RX_Index := 0;
      Held : Boolean := False;
   end record;
   overriding
   procedure Finalize (C : in out RX_Channel);
end ESP32S3.RMT;
