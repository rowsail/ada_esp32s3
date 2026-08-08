with ESP32S3.GPIO;
with ESP32S3.UART;

--  The ready-made transport: an ESP32S3.Esp_Loader.Link over a UART and two
--  GPIOs, which is how a board is wired to the target it programs.
--
--     Wire : aliased ESP32S3.Esp_Loader.Serial_Link.Port;
--     ...
--     Open (Wire, On => ESP32S3.UART.UART1,
--           Tx => 4, Rx => 5, Reset => 6, Boot => 18);
--     ESP32S3.Esp_Loader.Connect (Loader, As_Link (Wire), Status);
--
--  The Port must be aliased and must outlive the Link built from it -- the
--  Link captures it by address, exactly as ESP32S3.USB.CDC.As_Device does.
--
--  RESET AND BOOT POLARITY.  The two control pins are almost never wired
--  straight through: the usual circuit is an open-drain transistor whose GATE
--  is driven high to pull the target's EN (or IO0) LOW.  That inverts the
--  sense, so Reset_Drives_High (the default) means "drive the pin HIGH to hold
--  the target in reset", which is what that transistor wants.  A board that
--  connects the pins directly to EN/IO0 sets both to False.  Getting this
--  wrong does not damage anything -- the target simply never enters its
--  loader, and Connect reports No_Response.

package ESP32S3.Esp_Loader.Serial_Link is

   type Port is limited private;

   --  Take the UART, route its pins, and drive the two control lines to their
   --  released state.  Baud is the rate the ROM listens at; raise it after
   --  connecting with ESP32S3.Esp_Loader.Set_Baud, which routes back here.
   procedure Open
     (P                 : in out Port;
      On                : ESP32S3.UART.UART_Port;
      Tx                : ESP32S3.GPIO.Pin_Id;
      Rx                : ESP32S3.GPIO.Pin_Id;
      Reset             : ESP32S3.GPIO.Pin_Id;
      Boot              : ESP32S3.GPIO.Pin_Id;
      Baud              : ESP32S3.UART.Baud_Rate := 115_200;
      Reset_Drives_High : Boolean := True;
      Boot_Drives_High  : Boolean := True);

   function Is_Open (P : Port) return Boolean;

   --  Release the UART and leave both control lines released, so the target
   --  runs normally and the pins are free.
   procedure Close (P : in out Port);

   function As_Link (P : aliased in out Port) return Link
   with Pre => Is_Open (P);

private

   type Port is limited record
      Serial     : ESP32S3.UART.Session;
      Reset_Pin  : ESP32S3.GPIO.Pin_Id := 0;
      Boot_Pin   : ESP32S3.GPIO.Pin_Id := 0;
      Reset_High : Boolean := True;
      Boot_High  : Boolean := True;
      Tx_Pin     : ESP32S3.GPIO.Pin_Id := 0;
      Rx_Pin     : ESP32S3.GPIO.Pin_Id := 0;
      Opened     : Boolean := False;
   end record;

   function Is_Open (P : Port) return Boolean
   is (P.Opened);

end ESP32S3.Esp_Loader.Serial_Link;

