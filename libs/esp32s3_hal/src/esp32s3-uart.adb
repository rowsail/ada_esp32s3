with ESP32S3.UART.Engine;

package body ESP32S3.UART is

   package E renames ESP32S3.UART.Engine;   --  E: the low-level register engine

   --  One protected guard per port -- arbitrates exclusive ownership.  The
   --  guarded section is tiny (flip a flag); Write / Read run outside.
   protected type Port_Guard is
      entry Acquire;
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

   Guards : array (UART_Port) of Port_Guard;

   ----------------------------------------------------------------------------
   --  State -- the single, ownership-checked gateway to the raw register bus.
   --
   --  The per-port Bus array lives in this package's BODY, so nothing else in
   --  ESP32S3.UART can even name it.  The ONLY way to obtain a port's Bus is
   --  State.Owned (S), which RAISES Not_Owned unless S currently holds the port.
   --  A transfer or a reconfiguration therefore physically cannot reach the
   --  hardware without proving ownership: the guard is impossible to forget or
   --  bypass, because there is no other door to the registers.  (Guards above
   --  arbitrate WHO holds a port; State enforces that only the holder touches it.)
   ----------------------------------------------------------------------------

   package State is
      --  First-use bring-up: create Port's bus at safe defaults if it has not
      --  been made yet.  Idempotent -- a later Acquire of the port reuses it.
      procedure Ensure (Port : UART_Port);

      --  Enable interrupt-driven RX on a port (port-level config, not per-hold).
      procedure Enable_Rx (Port : UART_Port; Buf : Rx_Buffer_Access);

      --  The held port's raw bus -- the one gateway to the registers.
      --  Raises Not_Owned unless S currently holds a port.
      function Owned (S : Session) return E.Bus;
   end State;

   package body State is
      Buses : array (UART_Port) of E.Bus;       --  raw bus per port, hidden here
      Made  : array (UART_Port) of Boolean := (others => False);

      procedure Ensure (Port : UART_Port) is
      begin
         if not Made (Port) then
            --  Safe default: 115200 8-N-1, no pads routed yet.  Configure
            --  shapes it to the real link once the caller holds the port.
            Buses (Port) := E.Open (Port, 115_200, 8, None, One);
            Made (Port) := True;
         end if;
      end Ensure;

      procedure Enable_Rx (Port : UART_Port; Buf : Rx_Buffer_Access) is
      begin
         --  The port need not have been Acquired yet, and there is no Setup any
         --  more, so bring the bus up first: E.Enable_Buffered_Rx silently does
         --  nothing on an unopened Bus.
         Ensure (Port);
         E.Enable_Buffered_Rx (Buses (Port), Buf);
      end Enable_Rx;

      function Owned (S : Session) return E.Bus is
      begin
         if not S.Active then
            raise Not_Owned with "UART port used without holding it -- Acquire first";
         end if;
         return Buses (S.Port);
      end Owned;
   end State;

   ------------------------
   -- Enable_Buffered_Rx --
   ------------------------

   procedure Enable_Buffered_Rx (Port : UART_Port; Buffer : Rx_Buffer_Access) is
   begin
      State.Enable_Rx (Port, Buffer);
   end Enable_Buffered_Rx;

   -------------
   -- Acquire --
   -------------

   procedure Acquire
     (S                 : in out Session;
      Port              : UART_Port;
      Baud              : Baud_Rate := 115_200;
      Bits              : Data_Bits := 8;
      Parity            : Parity_Mode := None;
      Stop              : Stop_Bits := One;
      Tx                : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Rx                : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Rts               : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Cts               : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Rx_Flow_Threshold : Natural := 100) is
   begin
      if S.Active then
         raise Program_Error with "UART Session already active; Release first";
      end if;
      Guards (Port).Acquire;          --  suspends here until the port is free
      State.Ensure (Port);            --  first acquirer creates the controller
      S.Port := Port;
      S.Active := True;
      --  Now that S holds the port, apply the requested settings through the
      --  same ownership-checked path every other configuration call uses.
      Reconfigure (S, Baud, Bits, Parity, Stop, Tx, Rx, Rts, Cts, Rx_Flow_Threshold);
   end Acquire;

   -----------------
   -- Reconfigure --
   -----------------

   procedure Reconfigure
     (S                 : Session;
      Baud              : Baud_Rate := 115_200;
      Bits              : Data_Bits := 8;
      Parity            : Parity_Mode := None;
      Stop              : Stop_Bits := One;
      Tx                : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Rx                : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Rts               : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Cts               : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Rx_Flow_Threshold : Natural := 100)
   is
      Bus_Ref : constant E.Bus := State.Owned (S);  --  raises unless we hold the port
   begin
      E.Set_Baud (Bus_Ref, Baud);
      E.Set_Data_Bits (Bus_Ref, Bits);
      E.Set_Parity (Bus_Ref, Parity);
      E.Set_Stop_Bits (Bus_Ref, Stop);
      E.Configure_Pins (Bus_Ref, Tx, Rx, Rts, Cts, Rx_Flow_Threshold);
   end Reconfigure;

   ----------------------------------------------------------------------------
   --  Finer configuration + transfers -- every one reaches the hardware
   --  ONLY through State.Owned (S), so each requires the held port and raises
   --  Not_Owned otherwise.  A change can never race another task's transfer,
   --  and a new operation cannot be written that skips the ownership check.
   ----------------------------------------------------------------------------

   procedure Set_Baud (S : Session; Baud : Baud_Rate) is
   begin
      E.Set_Baud (State.Owned (S), Baud);
   end Set_Baud;

   procedure Set_Data_Bits (S : Session; Bits : Data_Bits) is
   begin
      E.Set_Data_Bits (State.Owned (S), Bits);
   end Set_Data_Bits;

   procedure Set_Parity (S : Session; Parity : Parity_Mode) is
   begin
      E.Set_Parity (State.Owned (S), Parity);
   end Set_Parity;

   procedure Set_Stop_Bits (S : Session; Stop : Stop_Bits) is
   begin
      E.Set_Stop_Bits (State.Owned (S), Stop);
   end Set_Stop_Bits;

   procedure Configure_Pins
     (S                 : Session;
      Tx                : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Rx                : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Rts               : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Cts               : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Rx_Flow_Threshold : Natural := 100;
      Tx_Invert         : Boolean := False;
      Rx_Invert         : Boolean := False;
      Rts_Invert        : Boolean := False;
      Cts_Invert        : Boolean := False)
   is
      Bus_Ref : constant E.Bus := State.Owned (S);
   begin
      E.Configure_Pins (Bus_Ref, Tx, Rx, Rts, Cts, Rx_Flow_Threshold);
      E.Set_Inversion (Bus_Ref, Tx_Invert, Rx_Invert, Rts_Invert, Cts_Invert);
   end Configure_Pins;

   procedure Set_Inversion
     (S   : Session;
      Tx  : Boolean := False;
      Rx  : Boolean := False;
      Rts : Boolean := False;
      Cts : Boolean := False) is
   begin
      E.Set_Inversion (State.Owned (S), Tx, Rx, Rts, Cts);
   end Set_Inversion;

   procedure Enable_Loopback (S : Session; On : Boolean := True) is
   begin
      E.Set_Loopback (State.Owned (S), On);
   end Enable_Loopback;

   -----------
   -- Write --
   -----------

   procedure Write (S : Session; Data : Byte_Array) is
   begin
      E.Write (State.Owned (S), Data);   --  Owned raises unless we hold the port
   end Write;

   ----------
   -- Read --
   ----------

   procedure Read (S : Session; Data : out Byte_Array; Count : out Natural) is
   begin
      E.Read (State.Owned (S), Data, Count);
   end Read;

   ---------------
   -- Available --
   ---------------

   function Available (S : Session) return Natural
   is (E.Rx_Available (State.Owned (S)));

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
   overriding
   procedure Finalize (S : in out Session) is
   begin
      Release (S);
   end Finalize;

end ESP32S3.UART;
