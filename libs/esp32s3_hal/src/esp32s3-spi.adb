with ESP32S3.SPI.Engine;
with ESP32S3.GPIO;

package body ESP32S3.SPI is

   package E renames ESP32S3.SPI.Engine;
   use type ESP32S3.GPIO.Pad_Number;

   --  Drive a Session's chip select.  A built-in CS_Pin is an active-low GPIO
   --  the driver owns; otherwise the device's own callback (if any) is invoked.
   procedure Drive_CS (S : Session; On : Boolean) is
   begin
      if S.CS_Pin /= No_Pin then
         if On then
            ESP32S3.GPIO.Clear (ESP32S3.GPIO.Pin_Id (S.CS_Pin));
         else
            ESP32S3.GPIO.Set (ESP32S3.GPIO.Pin_Id (S.CS_Pin));
         end if;
      elsif S.Select_CB /= null then
         S.Select_CB (S.Ctx, On);
      end if;
   end Drive_CS;

   --  One protected guard per host -- arbitrates exclusive ownership.  The
   --  guarded section is tiny (flip a flag); the actual transfer runs outside.
   protected type Host_Guard is
      entry Acquire;
      procedure Release;
   private
      Held : Boolean := False;
   end Host_Guard;

   protected body Host_Guard is
      entry Acquire when not Held is
      begin
         Held := True;
      end Acquire;

      procedure Release is
      begin
         Held := False;
      end Release;
   end Host_Guard;

   Guards : array (SPI_Host) of Host_Guard;

   ----------------------------------------------------------------------------
   --  State -- the single, ownership-checked gateway to the raw register bus.
   --
   --  The per-host Bus array lives in this package's BODY, so nothing else in
   --  ESP32S3.SPI can name it.  Owned (S) is the ONLY export that returns a Bus,
   --  and it raises Not_Owned unless S currently holds the host -- so a transfer
   --  physically cannot reach the registers without proving ownership, and a new
   --  transfer op cannot be written that skips the check.  The startup config
   --  entries (Open/Set_Clock/Enable_Loopback/Configure_Pins) are host-keyed
   --  (single-threaded, pre-Acquire) and never hand a Bus back out.
   ----------------------------------------------------------------------------

   package State is
      procedure Open (Host : SPI_Host; Mode : SPI_Mode; Clock_Hz : Positive);
      procedure Set_Clock (Host : SPI_Host; Hz : Positive);
      procedure Set_Mode (Host : SPI_Host; Mode : SPI_Mode);
      procedure Enable_Loopback (Host : SPI_Host; Pad : ESP32S3.GPIO.Pin_Id);
      procedure Configure_Pins
        (Host : SPI_Host;
         Sclk : ESP32S3.GPIO.Optional_Pin;
         Mosi : ESP32S3.GPIO.Optional_Pin;
         Miso : ESP32S3.GPIO.Optional_Pin;
         Cs   : ESP32S3.GPIO.Optional_Pin);
      procedure Set_Hardware_CS (Host : SPI_Host; Enabled : Boolean);
      function Ready (Host : SPI_Host) return Boolean;
      function Owned (S : Session) return access E.Bus;
   end State;

   package body State is
      Buses     : array (SPI_Host) of aliased E.Bus;  --  raw bus per host, hidden
      Ready_Map : array (SPI_Host) of Boolean := (others => False);

      procedure Open (Host : SPI_Host; Mode : SPI_Mode; Clock_Hz : Positive) is
      begin
         E.Open (Buses (Host), Host, Mode, Clock_Hz);
         Ready_Map (Host) := True;
      end Open;

      procedure Set_Clock (Host : SPI_Host; Hz : Positive) is
      begin
         E.Set_Clock (Buses (Host), Hz);
      end Set_Clock;

      procedure Set_Mode (Host : SPI_Host; Mode : SPI_Mode) is
      begin
         E.Set_Mode (Buses (Host), Mode);
      end Set_Mode;

      procedure Enable_Loopback (Host : SPI_Host; Pad : ESP32S3.GPIO.Pin_Id) is
      begin
         E.Enable_Loopback (Buses (Host), Pad);
      end Enable_Loopback;

      procedure Configure_Pins
        (Host : SPI_Host;
         Sclk : ESP32S3.GPIO.Optional_Pin;
         Mosi : ESP32S3.GPIO.Optional_Pin;
         Miso : ESP32S3.GPIO.Optional_Pin;
         Cs   : ESP32S3.GPIO.Optional_Pin) is
      begin
         E.Configure_Pins (Buses (Host), Sclk, Mosi, Miso, Cs);
      end Configure_Pins;

      procedure Set_Hardware_CS (Host : SPI_Host; Enabled : Boolean) is
      begin
         E.Set_Hardware_CS (Buses (Host), Enabled);
      end Set_Hardware_CS;

      function Ready (Host : SPI_Host) return Boolean
      is (Ready_Map (Host));

      function Owned (S : Session) return access E.Bus is
      begin
         if not S.Active then
            raise Not_Owned with "SPI host used without holding it -- Acquire first";
         end if;
         return Buses (S.Host)'Access;
      end Owned;
   end State;

   -----------
   -- Setup --
   -----------

   procedure Setup (Host : SPI_Host) is
   begin
      --  Open with placeholder mode/clock just to bring the controller and GDMA
      --  up; each device's real mode and clock are applied at Acquire.
      State.Open (Host, Mode => 0, Clock_Hz => 1_000_000);
   end Setup;

   procedure Configure_Pins
     (Host : SPI_Host;
      Sclk : ESP32S3.GPIO.Optional_Pin;
      Mosi : ESP32S3.GPIO.Optional_Pin;
      Miso : ESP32S3.GPIO.Optional_Pin;
      Cs   : ESP32S3.GPIO.Optional_Pin := No_Pin) is
   begin
      State.Configure_Pins (Host, Sclk, Mosi, Miso, Cs);
   end Configure_Pins;

   procedure Set_Clock (Host : SPI_Host; Hz : Positive) is
   begin
      State.Set_Clock (Host, Hz);
   end Set_Clock;

   procedure Enable_Loopback (Host : SPI_Host; Pad : ESP32S3.GPIO.Pin_Id) is
   begin
      State.Enable_Loopback (Host, Pad);
   end Enable_Loopback;

   -------------
   -- Acquire --
   -------------

   procedure Acquire
     (S         : in out Session;
      Host      : SPI_Host;
      Mode      : SPI_Mode := 0;
      Clock_Hz  : Positive := 1_000_000;
      Sclk      : ESP32S3.GPIO.Optional_Pin := No_Pin;
      Mosi      : ESP32S3.GPIO.Optional_Pin := No_Pin;
      Miso      : ESP32S3.GPIO.Optional_Pin := No_Pin;
      CS_Pin    : ESP32S3.GPIO.Optional_Pin := No_Pin;
      Select_CB : CS_Select := null;
      Ctx       : System.Address := System.Null_Address) is
   begin
      if S.Active then
         raise Program_Error with "SPI Session already active; Release first";
      end if;
      if not State.Ready (Host) then
         raise Not_Initialized with "SPI host acquired before Setup";
      end if;
      Guards (Host).Acquire;          --  suspends here until the host is free
      S.Host := Host;
      S.Active := True;
      S.CS_Pin := CS_Pin;
      S.Select_CB := Select_CB;
      S.Ctx := Ctx;
      S.Selected := False;
      --  Apply this device's mode and clock under the exclusive hold.
      State.Set_Mode (Host, Mode);
      State.Set_Clock (Host, Clock_Hz);
      --  Re-route the GPIO matrix only for a device that overrides the shared bus
      --  pins; No_Pin lines keep the host's Setup routing.
      if Sclk /= No_Pin or else Mosi /= No_Pin or else Miso /= No_Pin then
         State.Configure_Pins (Host, Sclk, Mosi, Miso, Cs => No_Pin);
      end if;
      --  A built-in software CS pin is ours to drive: park it as a deselected
      --  (high) output before the first Select_Device.
      if CS_Pin /= No_Pin then
         ESP32S3.GPIO.Configure
           (ESP32S3.GPIO.Pin_Id (CS_Pin),
            Mode  => ESP32S3.GPIO.Output,
            Drive => ESP32S3.GPIO.Drive_Strong);
         ESP32S3.GPIO.Set (ESP32S3.GPIO.Pin_Id (CS_Pin));
      end if;
      --  A device that drives its own select (software CS pin or callback)
      --  suppresses the hardware CS0 for this hold so it cannot disturb another
      --  device on the bus; a plain hardware-CS device re-enables it.
      State.Set_Hardware_CS (Host, Enabled => CS_Pin = No_Pin and then Select_CB = null);
   end Acquire;

   --------------------
   -- Select_Device --
   --------------------

   procedure Select_Device (S : in out Session; On : Boolean) is
   begin
      if not S.Active then
         raise Not_Owned with "SPI Select_Device without holding the host -- Acquire first";
      end if;
      if S.CS_Pin /= No_Pin or else S.Select_CB /= null then
         --  no-op for hw CS0
         Drive_CS (S, On);
         S.Selected := On;
      end if;
   end Select_Device;

   --------------
   -- Transfer --
   --------------

   procedure Transfer (S : Session; Tx, Rx : System.Address; Length : Natural) is
   begin
      --  Owned raises unless we hold the host; runs OUTSIDE the guard.
      E.Transfer (State.Owned (S).all, Tx, Rx, Length);
   end Transfer;

   -------------
   -- Release --
   -------------

   procedure Release (S : in out Session) is
   begin
      if S.Active then
         --  Deassert a still-selected device before releasing the bus, so an
         --  early exit / exception can't strand a device asserted.
         if S.Selected then
            Drive_CS (S, False);
            S.Selected := False;
         end if;
         S.Active := False;
         Guards (S.Host).Release;
      end if;
   end Release;

   --  Scope-exit / exception-unwind cleanup: hand the host back if still held.
   overriding
   procedure Finalize (S : in out Session) is
   begin
      Release (S);
   end Finalize;

end ESP32S3.SPI;
