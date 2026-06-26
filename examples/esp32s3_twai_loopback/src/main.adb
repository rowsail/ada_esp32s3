--  Ada TWAI (CAN) self-test on the bare-metal ESP32-S3 (no FreeRTOS, no IDF)
--  ========================================================================
--  What it demonstrates
--    The reusable HAL TWAI driver (ESP32S3.TWAI).  The controller is put in
--    self-test mode, where it can transmit a CAN frame and receive its own copy
--    with no second node to acknowledge it.  TX is looped back to RX through one
--    GPIO pad (the matrix loops out->in -- no wiring), so the whole send/receive
--    path runs on silicon.  We round-trip a standard (11-bit id) and an
--    extended (29-bit id) frame, both as data and as remote-request (RTR), using
--    the overloaded Send/Receive and the Available/Is_Extended peek to pick the
--    right Receive each time.
--
--  Build & run
--    ./x run esp32s3_twai_loopback        -- built as the embedded profile
--                                            (build.sh sets ESP32S3_RTS_PROFILE
--                                            =embedded; the Session uses
--                                            finalization, which light-tasking
--                                            forbids).
--
--  Output
--    A banner, then one "[twai] ... PASS" line per round-trip (4 total: standard
--    /extended x data/RTR), then "[twai] done.".  Each line echoes the received
--    id, length and a match=y/n that compares id, width, RTR flag, length and
--    payload against what was sent.  All four read PASS on working silicon.
--
--  Hardware / wiring
--    None (self-contained).  Self-test mode + the GPIO-matrix loopback feed the
--    controller's own TX back into its RX on a single pad, so no external CAN
--    transceiver and no jumper are needed.  For a real bus, Configure_Pins would
--    route TX/RX to a transceiver (e.g. SN65HVD230) instead of Enable_Loopback.
with Interfaces;   use Interfaces;
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.TWAI; use ESP32S3.TWAI;
with ESP32S3.GPIO;
with ESP32S3.Log;  use ESP32S3.Log;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   --  One self-rx result line.
   procedure Result
     (Extended : Boolean;          --  29-bit id frame vs 11-bit standard
      Remote   : Boolean;          --  remote-request (RTR) vs data frame
      Got      : Boolean;          --  a frame was received at all
      Data_Ok  : Boolean;          --  echoed id/width/RTR/len/payload all match
      Ok       : Boolean;          --  overall pass = Got and Data_Ok
      Id       : Unsigned_32;      --  received identifier (for the printout)
      Len      : Unsigned_32) is   --  received length / DLC (for the printout)
   begin
      Put ("[twai] ");
      Put (if Extended then "extended(29-bit)" else "standard(11-bit)");
      Put (" ");
      Put (if Remote then "remote(RTR)" else "data      ");
      Put (" self-rx: got=");
      Put (Boolean'Pos (Got));
      Put (" id=0x");
      Put_Hex (Id);
      Put (" len=");
      Put (Integer (Len));
      Put (" match=");
      Put (if Data_Ok then "y" else "n");
      Put ("  ");
      Put_Line (if Ok then "PASS" else "FAIL");
   end Result;

   --  The GPIO pad whose matrix signal is looped TX->RX for the self-test; any
   --  free pad works since nothing is wired to it.
   Loopback_Pad : constant ESP32S3.GPIO.Pin_Id := 4;   --  TX driven, RX read back

   --  CAN bit rate.  The driver fixes a 16-time-quanta bit layout (SJW=3,
   --  TSEG1=12, TSEG2=3, sample point at 13/16) and derives the prescaler (BRP)
   --  from the APB clock for this rate.  125 kbit/s is a common CAN-bus speed.
   Bus_Bit_Rate : constant := 125_000;

   --  Standard (11-bit id) data frame.  Payload is an arbitrary 5-byte test
   --  pattern (the trailing zeros fill the fixed 8-byte Data array, unused).
   Standard_Data : constant Standard_Frame :=
     (Id     => 16#123#,                         --  11-bit data frame
      Length => 5,
      Data   => (16#DE#, 16#AD#, 16#BE#, 16#EF#, 16#42#, 0, 0, 0),
      others => <>);

   --  Extended (29-bit id) data frame, 3-byte payload.
   Extended_Data : constant Extended_Frame :=
     (Id     => 16#14AB_CDE#,                    --  29-bit data frame
      Length => 3,
      Data   => (16#01#, 16#02#, 16#03#, others => 0),
      others => <>);

   --  Standard remote-transmission request: carries an id and a requested DLC
   --  (8) but no payload -- it asks another node for data.
   Standard_Remote : constant Standard_Frame :=
     (Id     => 16#7A5#,                         --  11-bit remote request (RTR)
      Remote => True,                            --  requests 8 bytes, sends none
      Length => 8,
      others => <>);

   --  Extended remote-transmission request -- RTR is orthogonal to id width.
   Extended_Remote : constant Extended_Frame :=
     (Id     => 16#1F1_2345#,                    --  29-bit remote request (RTR)
      Remote => True,
      Length => 6,
      others => <>);
begin
   delay until Clock + Milliseconds (200);
   Put_Line ("[twai] bare-metal TWAI (CAN) self-test loopback (no wiring)");

   Setup (Mode => Self_Test, Bit_Rate => Bus_Bit_Rate);

   declare
      Bus         : Session;            --  controlled handle: owns the controller
      Rx_Standard : Standard_Frame;     --  received 11-bit frame
      Rx_Extended : Extended_Frame;     --  received 29-bit frame
      Got         : Boolean;            --  a frame was received
      Data_Ok     : Boolean;            --  the echo matched what was sent
   begin
      Acquire (Bus);
      Enable_Loopback (Bus, Loopback_Pad);    --  loopback on the held controller

      --  Standard (11-bit) round-trip: Send picks the overload from the type.
      Send (Bus, Standard_Data);
      Got := Available (Bus) and then not Is_Extended (Bus);
      if Got then
         Receive (Bus, Rx_Standard, Got);
      end if;
      Data_Ok := Got and then not Rx_Standard.Remote
                   and then Rx_Standard.Id = Standard_Data.Id
                   and then Rx_Standard.Length = Standard_Data.Length;
      if Data_Ok then
         for I in 0 .. Standard_Data.Length - 1 loop
            Data_Ok := Data_Ok
                         and then Rx_Standard.Data (I) = Standard_Data.Data (I);
         end loop;
      end if;
      Result (Extended => False, Remote => False, Got => Got, Data_Ok => Data_Ok,
              Ok => Got and then Data_Ok,
              Id => Unsigned_32 (Rx_Standard.Id),
              Len => Unsigned_32 (Rx_Standard.Length));

      --  Extended (29-bit) data round-trip.
      Send (Bus, Extended_Data);
      Got := Available (Bus) and then Is_Extended (Bus);
      if Got then
         Receive (Bus, Rx_Extended, Got);
      end if;
      Data_Ok := Got and then not Rx_Extended.Remote
                   and then Rx_Extended.Id = Extended_Data.Id
                   and then Rx_Extended.Length = Extended_Data.Length;
      if Data_Ok then
         for I in 0 .. Extended_Data.Length - 1 loop
            Data_Ok := Data_Ok
                         and then Rx_Extended.Data (I) = Extended_Data.Data (I);
         end loop;
      end if;
      Result (Extended => True, Remote => False, Got => Got, Data_Ok => Data_Ok,
              Ok => Got and then Data_Ok,
              Id => Unsigned_32 (Rx_Extended.Id),
              Len => Unsigned_32 (Rx_Extended.Length));

      --  Standard remote-request (RTR) round-trip: carries Id + DLC, no data.
      Send (Bus, Standard_Remote);
      Got := Available (Bus) and then not Is_Extended (Bus);
      if Got then
         Receive (Bus, Rx_Standard, Got);
      end if;
      --  A correct RTR echo: Remote set, matching Id and requested length.
      Data_Ok := Got and then Rx_Standard.Remote
                   and then Rx_Standard.Id = Standard_Remote.Id
                   and then Rx_Standard.Length = Standard_Remote.Length;
      Result (Extended => False, Remote => True, Got => Got, Data_Ok => Data_Ok,
              Ok => Got and then Data_Ok,
              Id => Unsigned_32 (Rx_Standard.Id),
              Len => Unsigned_32 (Rx_Standard.Length));

      --  Extended (29-bit) remote-request (RTR) round-trip -- RTR works on either
      --  width, the Remote flag is orthogonal to the addressing standard.
      Send (Bus, Extended_Remote);
      Got := Available (Bus) and then Is_Extended (Bus);
      if Got then
         Receive (Bus, Rx_Extended, Got);
      end if;
      Data_Ok := Got and then Rx_Extended.Remote
                   and then Rx_Extended.Id = Extended_Remote.Id
                   and then Rx_Extended.Length = Extended_Remote.Length;
      Result (Extended => True, Remote => True, Got => Got, Data_Ok => Data_Ok,
              Ok => Got and then Data_Ok,
              Id => Unsigned_32 (Rx_Extended.Id),
              Len => Unsigned_32 (Rx_Extended.Length));
   end;                               --  Bus finalizes -> controller released

   Put_Line ("[twai] done.");

   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
