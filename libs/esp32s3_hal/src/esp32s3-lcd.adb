with ESP32S3.LCD.Engine;

package body ESP32S3.LCD is

   package E renames ESP32S3.LCD.Engine;

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
   --  that names the LCD_CAM registers + owns the GDMA channel) lives in this
   --  package's BODY.  Owned (S) is the only export that returns it, and it
   --  raises Not_Owned unless S holds the controller -- so a transfer or a
   --  reconfiguration physically cannot reach the hardware without proving
   --  ownership, and a new op cannot be written that skips the check.  The Bus
   --  is limited (holds a limited-controlled GDMA Channel), so Owned hands out
   --  an access to the single hidden instance.
   ----------------------------------------------------------------------------

   package State is
      procedure Bring_Up (S : Session; Pclk_Hz : Positive);
      function Owned (S : Session) return access E.Bus;
   end State;

   package body State is
      The_Bus : aliased E.Bus;         --  configured handle, hidden here

      procedure Bring_Up (S : Session; Pclk_Hz : Positive) is
      begin
         if not S.Active then
            raise Not_Owned
              with "LCD used without holding it -- Acquire first";
         end if;
         E.Open (The_Bus, Pclk_Hz);
      end Bring_Up;

      function Owned (S : Session) return access E.Bus is
      begin
         if not S.Active then
            raise Not_Owned
              with "LCD used without holding it -- Acquire first";
         end if;
         return The_Bus'Access;
      end Owned;
   end State;

   -------------
   -- Acquire --
   -------------

   procedure Acquire
     (S       : in out Session;
      Pclk_Hz : Positive := 1_000_000;
      Data    : Data_Pins := (others => No_Pin);
      Pclk    : ESP32S3.GPIO.Optional_Pin := No_Pin) is
   begin
      Guard.Acquire;
      S.Active := True;
      Reconfigure (S, Pclk_Hz, Data, Pclk);
   end Acquire;

   -----------------
   -- Reconfigure --
   -----------------

   procedure Reconfigure
     (S       : Session;
      Pclk_Hz : Positive := 1_000_000;
      Data    : Data_Pins := (others => No_Pin);
      Pclk    : ESP32S3.GPIO.Optional_Pin := No_Pin) is
   begin
      State.Bring_Up (S, Pclk_Hz);
      E.Configure_Pins (State.Owned (S).all, Data, Pclk);
   end Reconfigure;

   --------------------
   -- Configure_Pins --
   --------------------

   procedure Configure_Pins
     (S : Session; Data : Data_Pins; Pclk : ESP32S3.GPIO.Optional_Pin) is
   begin
      E.Configure_Pins (State.Owned (S).all, Data, Pclk);
   end Configure_Pins;

   ----------------------
   -- Enable_Clock_Out --
   ----------------------

   procedure Enable_Clock_Out (S : Session; Pclk_Pad : ESP32S3.GPIO.Pin_Id) is
   begin
      E.Enable_Clock_Out (State.Owned (S).all, Pclk_Pad);
   end Enable_Clock_Out;

   --------------
   -- Transmit --
   --------------

   procedure Transmit
     (S : Session; Tx : System.Address; Length : Natural; Ok : out Boolean) is
   begin
      E.Transmit (State.Owned (S).all, Tx, Length, Ok);
   end Transmit;

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

end ESP32S3.LCD;
