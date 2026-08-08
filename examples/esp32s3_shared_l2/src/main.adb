--  Two drivers, one interrupt -- ESP32S3.Shared_L2 on the bare-metal ESP32-S3
--  ===========================================================================
--  What it demonstrates
--    Ada allows exactly ONE protected handler per Interrupt_ID, and the
--    ESP32-S3 has only two dispatched device slots at level 2.  The buffered
--    UART receiver and the TWAI (CAN) receiver both want CPU_INT 19, so an
--    image containing both used to raise Program_Error inside
--    System.BB.Interrupts at ELABORATION -- a boot loop, before main ran.
--
--    ESP32S3.Shared_L2 owns the slot instead, and drivers REGISTER with it.  On
--    each interrupt every registered service is called and looks at its own
--    peripheral's status, exactly as the runtime's Level2_Dispatch already does
--    for the kernel's tick and cross-core poke.  This program is the proof: it
--    drives BOTH receivers, on the same interrupt, at the same time.
--
--  Build & run
--    ./x run esp32s3_shared_l2        -- embedded profile (Sessions use
--                                        finalization, which light-tasking
--                                        forbids)
--
--  Output
--    A banner, then "[uart] ... PASS" for the bytes that came back through the
--    interrupt-driven ring, "[twai] ... PASS" for the CAN frame that came back
--    through the same interrupt, and a final "[shared] tenants= 2 dispatches=N"
--    with N > 0 -- which is what says both really went through one handler.
--
--  Hardware / wiring
--    None.  The UART uses the controller's internal TX->RX loopback and the
--    TWAI its self-test mode with a GPIO-matrix loopback, so both receive their
--    own transmissions on-chip.

with Interfaces;    use Interfaces;
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.UART;
with ESP32S3.TWAI;
with ESP32S3.Shared_L2;
with ESP32S3.GPIO;
with ESP32S3.Log; use ESP32S3.Log;

with Demo_State;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is

   package U renames ESP32S3.UART;
   package Can renames ESP32S3.TWAI;

   use type U.Byte;
   use type Can.Data_Length;

   --  Any free pads: both loopbacks stay inside the controller / matrix, so
   --  nothing is actually driven off-chip.
   Uart_Tx      : constant ESP32S3.GPIO.Pin_Id := 17;
   Uart_Rx      : constant ESP32S3.GPIO.Pin_Id := 18;
   Loopback_Pad : constant ESP32S3.GPIO.Pin_Id := 4;   --  TWAI TX -> RX

   Probe : constant String := "shared-l2";

   ---------------------------------------------------------------------------

   procedure Uart_Round_Trip (Passed : out Boolean) is
      Session : U.Session;
      Got     : U.Byte_Array (1 .. Probe'Length) := (others => 0);
      Count   : Natural := 0;
      Waited  : Natural := 0;
   begin
      Passed := False;

      --  Buffered RX first: it routes the UART's interrupt to the shared slot
      --  and registers the service.  Then take the port and loop it back.
      U.Enable_Buffered_Rx (U.UART1, Demo_State.Rx_Ring'Access);
      U.Acquire
        (Session, Port => U.UART1, Baud => 115_200,
         Tx => Uart_Tx, Rx => Uart_Rx);
      U.Enable_Loopback (Session);

      --  Routing the pads and closing the loop can shake a spurious start bit
      --  into the receiver, so settle and throw away whatever is already in the
      --  ring before sending the probe -- otherwise the comparison is one byte
      --  out of step.
      delay until Clock + Milliseconds (20);
      --  Drain by what is ACTUALLY buffered: Read waits for the bytes it was
      --  asked for, so asking for more than is there stalls.
      while U.Available (Session) > 0 loop
         declare
            Junk : U.Byte_Array (1 .. Natural'Min (32, U.Available (Session)));
            N    : Natural;
         begin
            U.Read (Session, Junk, N);
         end;
      end loop;

      declare
         Out_Bytes : U.Byte_Array (1 .. Probe'Length);
      begin
         for I in Probe'Range loop
            Out_Bytes (I) := U.Byte (Character'Pos (Probe (I)));
         end loop;
         U.Write (Session, Out_Bytes);
      end;

      --  The bytes come back through the interrupt into Rx_Ring, so this waits
      --  on the shared dispatcher, not on a polled FIFO.
      while Count < Got'Length and then Waited < 500 loop
         delay until Clock + Milliseconds (2);
         Waited := Waited + 2;
         declare
            Ready : constant Natural :=
              Natural'Min (U.Available (Session), Got'Length - Count);
         begin
            if Ready > 0 then
               declare
                  Chunk : U.Byte_Array (1 .. Ready);
                  N     : Natural;
               begin
                  U.Read (Session, Chunk, N);
                  for I in 1 .. N loop
                     Count := Count + 1;
                     Got (Count) := Chunk (I);
                  end loop;
               end;
            end if;
         end;
      end loop;

      U.Release (Session);

      Passed := Count = Got'Length;
      for I in Probe'Range loop
         if Passed and then Got (I) /= U.Byte (Character'Pos (Probe (I))) then
            Passed := False;
         end if;
      end loop;

      Put ("[uart] buffered RX over the shared slot: got");
      Put (Natural'Image (Count));
      Put (" of");
      Put (Natural'Image (Got'Length));
      Put_Line (if Passed then " bytes  PASS" else " bytes  FAIL");
   end Uart_Round_Trip;

   ---------------------------------------------------------------------------

   procedure Twai_Round_Trip (Passed : out Boolean) is
      Session : Can.Session;
      Frame   : constant Can.Standard_Frame :=
        (Id     => 16#123#,
         Length => 4,
         Data   => (16#5A#, 16#A5#, 16#12#, 16#34#, others => 0),
         others => <>);
      Waited  : Natural := 0;
   begin
      Passed := False;

      --  Self-test + matrix loopback: the controller acknowledges its own
      --  frame, so no second node and no transceiver are needed.
      Can.Acquire (Session, Mode => Can.Self_Test, Bit_Rate => 125_000);
      Can.Enable_Loopback (Session, Pad => Loopback_Pad);
      Can.Enable_Rx_Interrupt (Session);   --  registers with the shared slot

      Can.Send (Session, Frame);

      while not Demo_State.Can_Got and then Waited < 500 loop
         delay until Clock + Milliseconds (2);
         Waited := Waited + 2;
      end loop;

      if Demo_State.Can_Got then
         Passed :=
           Demo_State.Can_Frame.Id = 16#123#
           and then not Demo_State.Can_Frame.Extended
           and then Demo_State.Can_Frame.Length = Frame.Length;
         for I in 1 .. Natural (Frame.Length) loop
            if Passed and then Demo_State.Can_Frame.Data (I) /= Frame.Data (I) then
               Passed := False;
            end if;
         end loop;
      end if;

      Can.Release (Session);

      Put ("[twai] CAN RX over the shared slot: ");
      Put_Line (if Passed then "frame matched  PASS" else "no match  FAIL");
   end Twai_Round_Trip;

   Uart_Ok : Boolean;
   Twai_Ok : Boolean;

begin
   delay until Clock + Milliseconds (200);
   Put_Line ("");
   Put_Line ("=== ESP32S3.Shared_L2: two receivers on CPU_INT 19 ===");

   Uart_Round_Trip (Uart_Ok);
   Twai_Round_Trip (Twai_Ok);

   --  Two tenants and a non-zero dispatch count is the whole claim: both
   --  drivers were serviced through ONE protected handler on ONE interrupt.
   Put ("[shared] tenants=");
   Put (Natural'Image (ESP32S3.Shared_L2.Tenant_Count));
   Put ("  dispatches=");
   Put_Line (Natural'Image (ESP32S3.Shared_L2.Dispatches));

   Put_Line
     (if Uart_Ok and then Twai_Ok
      then "[shared] done: both receivers ran on one interrupt."
      else "[shared] done: FAILURES above.");

   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
