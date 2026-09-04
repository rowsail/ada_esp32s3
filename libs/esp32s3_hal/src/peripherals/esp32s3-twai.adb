with ESP32S3.TWAI.Engine;

package body ESP32S3.TWAI is

   package E renames ESP32S3.TWAI.Engine;

   --------------------------------------------------------------------------
   --  Single-controller ownership guard.
   --------------------------------------------------------------------------

   protected Guard is
      entry Acquire;
      procedure Release;
   private
      Held : Boolean := False;
   end Guard;

   protected body Guard is
      entry Acquire when not Held is
      begin
         Held := True;
      end Acquire;
      procedure Release is
      begin
         Held := False;
      end Release;
   end Guard;

   ----------------------------------------------------------------------------
   --  State -- the single, ownership-checked gateway to the controller.
   --
   --  The configured Bus handle (from the private Engine child, the only unit
   --  that names the TWAI registers) lives in this package's BODY.  Owned (S)
   --  returns it and Bring_Up (S, ...) re-creates it; both refuse with Not_Owned
   --  unless S holds the controller -- so a transfer or a reconfiguration
   --  physically cannot reach the hardware without proving ownership, and a new
   --  op cannot be written that skips the check.
   ----------------------------------------------------------------------------

   package State is
      procedure Bring_Up (S : Session; Mode : Bus_Mode; Bit_Rate : Positive);
      function Owned (S : Session) return E.Bus;
   end State;

   package body State is
      The_Bus : E.Bus;                 --  configured handle, hidden here

      procedure Bring_Up (S : Session; Mode : Bus_Mode; Bit_Rate : Positive) is
      begin
         if not S.Active then
            raise Not_Owned with "TWAI used without holding it -- Acquire first";
         end if;
         The_Bus := E.Open (Mode, Bit_Rate);
      end Bring_Up;

      function Owned (S : Session) return E.Bus is
      begin
         if not S.Active then
            raise Not_Owned with "TWAI used without holding it -- Acquire first";
         end if;
         return The_Bus;
      end Owned;
   end State;

   -------------
   -- Acquire --
   -------------

   procedure Acquire
     (S : in out Session; Mode : Bus_Mode := Normal; Bit_Rate : Positive := 125_000) is
   begin
      Guard.Acquire;
      S.Active := True;
      Reconfigure (S, Mode, Bit_Rate);   --  bring it up through the held Session
   end Acquire;

   -----------------
   -- Reconfigure --
   -----------------

   procedure Reconfigure (S : Session; Mode : Bus_Mode := Normal; Bit_Rate : Positive := 125_000)
   is
   begin
      State.Bring_Up (S, Mode, Bit_Rate);
   end Reconfigure;

   --------------------
   -- Configure_Pins --
   --------------------

   procedure Configure_Pins
     (S : Session; Tx : ESP32S3.GPIO.Optional_Pin; Rx : ESP32S3.GPIO.Optional_Pin) is
   begin
      E.Configure_Pins (State.Owned (S), Tx, Rx);
   end Configure_Pins;

   ---------------------
   -- Enable_Loopback --
   ---------------------

   procedure Enable_Loopback (S : Session; Pad : ESP32S3.GPIO.Pin_Id) is
   begin
      E.Enable_Loopback (State.Owned (S), Pad);
   end Enable_Loopback;

   ----------
   -- Send --
   ----------

   procedure Send (S : Session; F : Standard_Frame) is
   begin
      E.Send
        (State.Owned (S),
         Extended => False,
         Remote   => F.Remote,
         Id       => F.Id,
         Length   => F.Length,
         Data     => F.Data);
   end Send;

   procedure Send (S : Session; F : Extended_Frame) is
   begin
      E.Send
        (State.Owned (S),
         Extended => True,
         Remote   => F.Remote,
         Id       => F.Id,
         Length   => F.Length,
         Data     => F.Data);
   end Send;

   ---------------
   -- Available --
   ---------------

   function Available (S : Session) return Boolean
   is (E.RX_Pending (State.Owned (S)));

   function Is_Extended (S : Session) return Boolean
   is (E.RX_Extended (State.Owned (S)));

   -------------
   -- Receive --
   -------------

   procedure Receive (S : Session; F : out Standard_Frame; Got : out Boolean) is
      Id          : Interfaces.Unsigned_32;
      Remote_Flag : Boolean;
      Length      : Data_Length;
      Data        : Data_Bytes;
   begin
      E.Receive
        (State.Owned (S),
         Want_Extended => False,
         Id            => Id,
         Remote        => Remote_Flag,
         Length        => Length,
         Data          => Data,
         Got           => Got);
      F :=
        (if Got
         then (Id => Standard_Id (Id), Remote => Remote_Flag, Length => Length, Data => Data)
         else (others => <>));
   end Receive;

   procedure Receive (S : Session; F : out Extended_Frame; Got : out Boolean) is
      Id          : Interfaces.Unsigned_32;
      Remote_Flag : Boolean;
      Length      : Data_Length;
      Data        : Data_Bytes;
   begin
      E.Receive
        (State.Owned (S),
         Want_Extended => True,
         Id            => Id,
         Remote        => Remote_Flag,
         Length        => Length,
         Data          => Data,
         Got           => Got);
      F :=
        (if Got
         then (Id => Extended_Id (Id), Remote => Remote_Flag, Length => Length, Data => Data)
         else (others => <>));
   end Receive;

   -------------------------
   -- Interrupt-driven RX --
   -------------------------

   procedure Enable_Rx_Interrupt (S : Session) is
   begin
      if not S.Active then
         raise Not_Owned
           with "TWAI Enable_Rx_Interrupt without holding it -- Acquire first";
      end if;
      E.Enable_Rx_Interrupt;
   end Enable_Rx_Interrupt;

   procedure Get (F : out Queued_Frame) is
   begin
      E.Get_Frame (F);   --  pops the software queue; no controller access
   end Get;

   function Rx_Overruns return Natural
   is (E.Rx_Overruns);

   ------------
   -- Health --
   ------------

   function Health (S : Session) return Bus_State
   is (E.Health (State.Owned (S)));

   procedure Recover (S : Session) is
   begin
      E.Recover (State.Owned (S));
   end Recover;

   -------------
   -- Release --
   -------------

   procedure Release (S : in out Session) is
   begin
      if S.Active then
         S.Active := False;
         Guard.Release;
      end if;
   end Release;

   overriding
   procedure Finalize (S : in out Session) is
   begin
      Release (S);
   end Finalize;

end ESP32S3.TWAI;
