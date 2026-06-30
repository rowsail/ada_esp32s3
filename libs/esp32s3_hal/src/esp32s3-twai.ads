with Interfaces;
with Ada.Finalization;
with ESP32S3.GPIO;

--  ESP32-S3 TWAI (Two-Wire Automotive Interface = CAN 2.0), task-safe.
--
--  One CAN controller (SJA1000-compatible).  This driver sends and receives both
--  standard (11-bit identifier) and extended (29-bit, CAN 2.0B) data frames.  A
--  real bus needs an external
--  transceiver on the TX/RX pins; for a wiring-free self-test the controller's
--  self-test mode lets it transmit and receive its own frame (no second node to
--  acknowledge), with TX looped back to RX through one GPIO pad.
--
--  The single controller is guarded by a protected object; Acquire hands out a
--  limited, controlled Session that owns it exclusively and releases on scope
--  exit.  Uses finalization, so it targets the embedded/full profile.
package ESP32S3.TWAI is

   --  Bus mode: Normal drives a real bus; Listen_Only never transmits/acks;
   --  Self_Test transmits + self-receives without an external acknowledgement.
   type Bus_Mode is (Normal, Listen_Only, Self_Test);

   subtype Data_Length is Natural range 0 .. 8;
   type Data_Bytes is array (0 .. 7) of Interfaces.Unsigned_8;

   --  CAN identifiers come in two widths.  Each frame type carries its own, so
   --  the identifier is range-checked to the standard it belongs to, and Send is
   --  overloaded on it --- you cannot put a 29-bit id in a standard frame.
   subtype Standard_Id is Interfaces.Unsigned_32 range 0 .. 16#7FF#;        --  11-bit
   subtype Extended_Id is Interfaces.Unsigned_32 range 0 .. 16#1FFF_FFFF#;  --  29-bit

   --  A standard (11-bit ID) CAN frame.  Remote => True makes it a remote-transmission
   --  request (RTR): it carries Id and Length (the requested data length) but no
   --  Data on the wire -- a node owning that Id is expected to answer with a data
   --  frame.  Remote => False (the default) is an ordinary data frame.
   type Standard_Frame is record
      Id     : Standard_Id := 0;
      Remote : Boolean     := False;
      Length : Data_Length := 0;
      Data   : Data_Bytes  := (others => 0);
   end record;

   --  An extended (29-bit ID) CAN frame (CAN 2.0B); Remote as above.
   type Extended_Frame is record
      Id     : Extended_Id := 0;
      Remote : Boolean     := False;
      Length : Data_Length := 0;
      Data   : Data_Bytes  := (others => 0);
   end record;

   No_Pin : constant ESP32S3.GPIO.Pad_Number := ESP32S3.GPIO.No_Pin;

   type Session is limited private;

   ----------------------------------------------------------------------------
   --  Concurrent, mutually-exclusive use.  Acquire the controller AND configure
   --  it in the same call; every transfer plus every later reconfiguration runs
   --  through the held Session -- so changing a setting requires ownership and
   --  can never race another task.  All register access lives in the private
   --  Engine child; the handle is hidden in the body and reached only through
   --  one ownership-checked gateway.  There is no startup call that precedes
   --  ownership: you cannot touch the controller without holding it.
   ----------------------------------------------------------------------------

   --  Raised by any operation below if S does not hold the controller.  Each
   --  reaches the hardware only through the gateway, so "use the bus without
   --  holding it" fails loudly.
   Not_Owned : exception;

   --  Take exclusive ownership of the controller (suspends until free) and bring
   --  it up at (about) Bit_Rate bits/s in the given mode, accepting all
   --  identifiers.  Every Acquire (re)applies the mode and bit rate, so the
   --  controller comes up in exactly the requested state.  Route TX/RX to a
   --  transceiver with Configure_Pins, or loop back for a self-test with
   --  Enable_Loopback, once held.
   procedure Acquire (S        : in out Session;
                      Mode     : Bus_Mode := Normal;
                      Bit_Rate : Positive  := 125_000);

   --  Re-apply the mode and bit rate on the controller S already holds, without
   --  releasing it.  Raises Not_Owned unless S holds the controller.
   procedure Reconfigure (S        : Session;
                          Mode     : Bus_Mode := Normal;
                          Bit_Rate : Positive  := 125_000);

   --  Route TWAI TX/RX to physical pads (for a real transceiver), on the held
   --  controller.  Raises Not_Owned unless S holds it.
   procedure Configure_Pins (S  : Session;
                             Tx : ESP32S3.GPIO.Optional_Pin;
                             Rx : ESP32S3.GPIO.Optional_Pin);

   --  Loop TX back to RX through one pad for a wiring-free self-test (use with
   --  Setup (Self_Test)), on the held controller.  Raises Not_Owned unless held.
   procedure Enable_Loopback (S : Session; Pad : ESP32S3.GPIO.Pin_Id);

   --  Transmit F and block until the controller finishes (in Self_Test mode this
   --  also self-receives it).  Send is overloaded on the frame's addressing
   --  standard.  Raises Not_Owned unless S holds the controller.
   procedure Send (S : Session; F : Standard_Frame);
   procedure Send (S : Session; F : Extended_Frame);

   --  A received frame may be standard or extended --- the sender chooses ---
   --  so receiving is a two-step idiom.  Available reports whether a frame is
   --  waiting; Is_Extended reports its width (call only when Available); then
   --  call the matching Receive overload:
   --
   --     if Available (S) then
   --        if Is_Extended (S) then Receive (S, Ext, Got);
   --        else                    Receive (S, Std, Got); end if;
   --     end if;
   --
   --  Receive returns Got => True and releases the buffer, Got => False if the
   --  waiting frame is of the OTHER width (left buffered for the matching
   --  overload) or none arrived within a short timeout.  All three reach the
   --  hardware through the gateway, so they raise Not_Owned unless S holds it.
   function  Available   (S : Session) return Boolean;
   function  Is_Extended (S : Session) return Boolean;
   procedure Receive (S : Session; F : out Standard_Frame; Got : out Boolean);
   procedure Receive (S : Session; F : out Extended_Frame; Got : out Boolean);

   procedure Release (S : in out Session);

private
   type Session is new Ada.Finalization.Limited_Controlled with record
      Active : Boolean := False;
   end record;
   overriding procedure Finalize (S : in out Session);
end ESP32S3.TWAI;
