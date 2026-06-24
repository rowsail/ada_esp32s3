with ESP32S3.I2S.Engine;

package body ESP32S3.I2S is

   package E renames ESP32S3.I2S.Engine;

   --  One protected guard per port -- arbitrates exclusive ownership.  The
   --  guarded section is tiny (flip a flag); the actual transfer runs outside.
   protected type Port_Guard is
      entry    Acquire;
      procedure Release;
   private
      Held : Boolean := False;
   end Port_Guard;

   protected body Port_Guard is
      entry Acquire when not Held is
      begin
         Held := True;
      end Acquire;

      procedure Release is
      begin
         Held := False;
      end Release;
   end Port_Guard;

   Guards : array (I2S_Port) of Port_Guard;

   ----------------------------------------------------------------------------
   --  State -- the single, ownership-checked gateway to the raw register bus.
   --
   --  The per-port Bus array lives in this package's BODY, so nothing else in
   --  ESP32S3.I2S can name it.  Owned (S) is the ONLY export that returns a Bus,
   --  and it raises Not_Owned unless S currently holds the port -- so a transfer
   --  physically cannot reach the registers without proving ownership, and a new
   --  transfer op cannot be written that skips the check.  The startup config
   --  entries are port-keyed (single-threaded, pre-Acquire) and never hand a Bus
   --  back out.
   ----------------------------------------------------------------------------

   package State is
      procedure Open (Port : I2S_Port; Sample_Rate : Positive; Bits : Sample_Bits;
                      Mode : I2S_Mode);
      procedure Enable_Loopback (Port : I2S_Port; Pad : ESP32S3.GPIO.Pin_Id);
      procedure Configure_Pins (Port : I2S_Port;
                                Bclk : ESP32S3.GPIO.Optional_Pin;
                                Ws   : ESP32S3.GPIO.Optional_Pin;
                                Dout : ESP32S3.GPIO.Optional_Pin;
                                Din  : ESP32S3.GPIO.Optional_Pin;
                                Mclk : ESP32S3.GPIO.Optional_Pin);
      function  Ready (Port : I2S_Port) return Boolean;
      function  Owned (S : Session) return access E.Bus;
   end State;

   package body State is
      Buses     : array (I2S_Port) of aliased E.Bus;  --  raw port instance, hidden
      Ready_Map : array (I2S_Port) of Boolean := (others => False);

      procedure Open (Port : I2S_Port; Sample_Rate : Positive; Bits : Sample_Bits;
                      Mode : I2S_Mode)
      is
      begin
         E.Open (Buses (Port), Port, Sample_Rate, Bits, Mode);
         Ready_Map (Port) := True;
      end Open;

      procedure Enable_Loopback (Port : I2S_Port; Pad : ESP32S3.GPIO.Pin_Id) is
      begin
         E.Enable_Loopback (Buses (Port), Pad);
      end Enable_Loopback;

      procedure Configure_Pins (Port : I2S_Port;
                                Bclk : ESP32S3.GPIO.Optional_Pin;
                                Ws   : ESP32S3.GPIO.Optional_Pin;
                                Dout : ESP32S3.GPIO.Optional_Pin;
                                Din  : ESP32S3.GPIO.Optional_Pin;
                                Mclk : ESP32S3.GPIO.Optional_Pin) is
      begin
         E.Configure_Pins (Buses (Port), Bclk, Ws, Dout, Din, Mclk);
      end Configure_Pins;

      function Ready (Port : I2S_Port) return Boolean is (Ready_Map (Port));

      function Owned (S : Session) return access E.Bus is
      begin
         if not S.Active then
            raise Not_Owned
              with "I2S port used without holding it -- Acquire first";
         end if;
         return Buses (S.Port)'Access;
      end Owned;
   end State;

   -----------
   -- Setup --
   -----------

   procedure Setup (Port        : I2S_Port;
                    Sample_Rate : Positive    := 16_000;
                    Bits        : Sample_Bits := Bits_16;
                    Mode        : I2S_Mode    := Standard) is
   begin
      State.Open (Port, Sample_Rate, Bits, Mode);
   end Setup;

   procedure Enable_Loopback (Port : I2S_Port; Pad : ESP32S3.GPIO.Pin_Id) is
   begin
      State.Enable_Loopback (Port, Pad);
   end Enable_Loopback;

   procedure Configure_Pins (Port : I2S_Port;
                             Bclk : ESP32S3.GPIO.Optional_Pin := No_Pin;
                             Ws   : ESP32S3.GPIO.Optional_Pin := No_Pin;
                             Dout : ESP32S3.GPIO.Optional_Pin := No_Pin;
                             Din  : ESP32S3.GPIO.Optional_Pin := No_Pin;
                             Mclk : ESP32S3.GPIO.Optional_Pin := No_Pin) is
   begin
      State.Configure_Pins (Port, Bclk, Ws, Dout, Din, Mclk);
   end Configure_Pins;

   -------------
   -- Acquire --
   -------------

   procedure Acquire (S : in out Session; Port : I2S_Port) is
   begin
      if not State.Ready (Port) then
         raise Not_Initialized with "I2S port acquired before Setup";
      end if;
      Guards (Port).Acquire;          --  suspends here until the port is free
      S.Port   := Port;
      S.Active := True;
   end Acquire;

   -----------
   -- Write --
   -----------

   procedure Write (S : Session; Tx : System.Address; Length : Natural) is
   begin
      E.Write (State.Owned (S).all, Tx, Length);   --  Owned raises unless held
   end Write;

   ----------
   -- Read --
   ----------

   procedure Read (S : Session; Rx : System.Address; Length : Natural) is
   begin
      E.Read (State.Owned (S).all, Rx, Length);
   end Read;

   --------------
   -- Transfer --
   --------------

   procedure Transfer (S : Session; Tx, Rx : System.Address; Length : Natural) is
   begin
      E.Transfer (State.Owned (S).all, Tx, Rx, Length);
   end Transfer;

   ----------------------
   -- Start_Continuous --
   ----------------------

   procedure Start_Continuous (S : Session; Tx : System.Address; Length : Natural)
   is
   begin
      E.Start_Continuous (State.Owned (S).all, Tx, Length);
   end Start_Continuous;

   ----------
   -- Stop --
   ----------

   procedure Stop (S : Session) is
   begin
      E.Stop (State.Owned (S).all);
   end Stop;

   -------------
   -- Capture --
   -------------

   procedure Capture (S : Session; Rx : System.Address; Length : Natural) is
   begin
      E.Capture (State.Owned (S).all, Rx, Length);
   end Capture;

   -------------
   -- Release --
   -------------

   procedure Release (S : in out Session) is
   begin
      if S.Active then
         S.Active := False;
         Guards (S.Port).Release;
      end if;
   end Release;

   --  Scope-exit / exception-unwind cleanup: hand the port back if still held.
   overriding procedure Finalize (S : in out Session) is
   begin
      Release (S);
   end Finalize;

end ESP32S3.I2S;
