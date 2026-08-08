with Ada.Unchecked_Conversion;
with System;

package body ESP32S3.Esp_Loader.Serial_Link is

   package Serial renames ESP32S3.UART;

   type Port_Access is access all Port;
   function To_Port is new
     Ada.Unchecked_Conversion (System.Address, Port_Access);

   --  How long to sit on an idle line before admitting nothing is coming.  The
   --  UART's own Read waits only briefly, so a caller's timeout is spent here,
   --  polling, rather than in one long blocking read -- which also keeps the
   --  common case (bytes already waiting) free of any delay at all.
   Poll_Interval_Ms : constant := 2;

   ---------------------------------------------------------------------------
   --  The four callbacks.  Library-level, as the no-trampoline rule requires.
   ---------------------------------------------------------------------------

   procedure Send (Ctx : System.Address; Data : Byte_Array) is
      P         : constant Port_Access := To_Port (Ctx);
      Out_Bytes : Serial.Byte_Array (0 .. Data'Length - 1);
   begin
      for I in Out_Bytes'Range loop
         Out_Bytes (I) := Serial.Byte (Data (Data'First + I));
      end loop;
      Serial.Write (P.Serial, Out_Bytes);
   end Send;

   procedure Receive
     (Ctx        : System.Address;
      Into       : out Byte_Array;
      Last       : out Natural;
      Timeout_Ms : Natural)
   is
      P        : constant Port_Access := To_Port (Ctx);
      Waited   : Natural := 0;
      In_Bytes : Serial.Byte_Array (0 .. Into'Length - 1);
      Waiting  : Natural;
      Count    : Natural;
   begin
      Last := Into'First - 1;

      --  Wait for the FIRST byte only; once the target is talking, take
      --  whatever has arrived and let the frame reader ask again.
      loop
         Waiting := Serial.Available (P.Serial);
         exit when Waiting > 0 or else Waited >= Timeout_Ms;
         delay Duration (Poll_Interval_Ms) / 1000.0;
         Waited := Waited + Poll_Interval_Ms;
      end loop;

      if Waiting = 0 then
         return;
      end if;

      --  Ask for exactly what is already there.  UART.Read waits briefly for
      --  EACH byte it was asked for, so requesting the whole buffer when ten
      --  bytes have arrived would stall for the other 246 -- once per reply,
      --  which across a few hundred blocks is the whole transfer time.
      Waiting := Natural'Min (Waiting, In_Bytes'Length);
      Serial.Read (P.Serial, In_Bytes (0 .. Waiting - 1), Count);
      for I in 0 .. Count - 1 loop
         Into (Into'First + I) := Interfaces.Unsigned_8 (In_Bytes (I));
      end loop;
      if Count > 0 then
         Last := Into'First + Count - 1;
      end if;
   end Receive;

   procedure Assert_Reset (Ctx : System.Address; Asserted : Boolean) is
      P : constant Port_Access := To_Port (Ctx);
   begin
      ESP32S3.GPIO.Write (P.Reset_Pin, Asserted = P.Reset_High);
   end Assert_Reset;

   procedure Assert_Boot (Ctx : System.Address; Asserted : Boolean) is
      P : constant Port_Access := To_Port (Ctx);
   begin
      ESP32S3.GPIO.Write (P.Boot_Pin, Asserted = P.Boot_High);
   end Assert_Boot;

   procedure Set_Baud (Ctx : System.Address; Baud : Positive) is
      P : constant Port_Access := To_Port (Ctx);
   begin
      Serial.Set_Baud (P.Serial, Serial.Baud_Rate (Baud));
   end Set_Baud;

   ---------------------------------------------------------------------------

   procedure Open
     (P                 : in out Port;
      On                : ESP32S3.UART.UART_Port;
      Tx                : ESP32S3.GPIO.Pin_Id;
      Rx                : ESP32S3.GPIO.Pin_Id;
      Reset             : ESP32S3.GPIO.Pin_Id;
      Boot              : ESP32S3.GPIO.Pin_Id;
      Baud              : ESP32S3.UART.Baud_Rate := 115_200;
      Reset_Drives_High : Boolean := True;
      Boot_Drives_High  : Boolean := True) is
   begin
      P.Reset_Pin := Reset;
      P.Boot_Pin := Boot;
      P.Reset_High := Reset_Drives_High;
      P.Boot_High := Boot_Drives_High;
      P.Tx_Pin := Tx;
      P.Rx_Pin := Rx;

      --  Release both lines BEFORE configuring them as outputs, so bringing the
      --  programmer up does not glitch a target that is happily running.
      ESP32S3.GPIO.Write (Reset, not Reset_Drives_High);
      ESP32S3.GPIO.Write (Boot, not Boot_Drives_High);
      ESP32S3.GPIO.Configure (Reset, ESP32S3.GPIO.Output);
      ESP32S3.GPIO.Configure (Boot, ESP32S3.GPIO.Output);
      ESP32S3.GPIO.Write (Reset, not Reset_Drives_High);
      ESP32S3.GPIO.Write (Boot, not Boot_Drives_High);

      Serial.Acquire (P.Serial, Port => On, Baud => Baud, Tx => Tx, Rx => Rx);
      P.Opened := True;
   end Open;

   procedure Close (P : in out Port) is
   begin
      if not P.Opened then
         return;
      end if;
      ESP32S3.GPIO.Write (P.Reset_Pin, not P.Reset_High);
      ESP32S3.GPIO.Write (P.Boot_Pin, not P.Boot_High);
      Serial.Release (P.Serial);
      P.Opened := False;
   end Close;

   function As_Link (P : aliased in out Port) return Link
   is (Ctx          => P'Address,
       Send         => Send'Access,
       Receive      => Receive'Access,
       Assert_Reset => Assert_Reset'Access,
       Assert_Boot  => Assert_Boot'Access,
       Set_Baud     => Set_Baud'Access);

end ESP32S3.Esp_Loader.Serial_Link;

