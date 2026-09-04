with ESP32S3.Serial;

--  Adapt a held UART Session into an ESP32S3.Serial.Device, so console-style
--  output (e.g. ESP32S3.Log, which routes through ESP32S3.Serial) can be sent to
--  a UART instead of the USB Serial/JTAG console:
--
--     My_Uart : aliased ESP32S3.UART.Session;          --  must be library-level
--     ...
--     ESP32S3.UART.Acquire (My_Uart, UART1, Tx => 17, Rx => 16);
--     ESP32S3.Serial.Set_Output (ESP32S3.UART.Text.As_Device (My_Uart));
--     Put_Line ("now on UART1");                        --  ESP32S3.Log -> UART1
--
--  The Session is captured BY ADDRESS, so it must be aliased, must already hold
--  the port (Acquire'd), and must outlive the redirection (typically a
--  library-level object) -- otherwise the device points at a finalized Session.

package ESP32S3.UART.Text is

   function As_Device
     (S : aliased in out Session) return ESP32S3.Serial.Device;

   --  Adapt the SAME held Session into an input device, so console-style INPUT
   --  (ESP32S3.Text_IO.Get / Get_Line on the console) can be taken from the UART
   --  instead of the USB Serial/JTAG console:
   --
   --     ESP32S3.Serial.Set_Input (ESP32S3.UART.Text.As_Input_Device (My_Uart));
   --
   --  Same lifetime rule as As_Device: the Session is captured BY ADDRESS, must
   --  be aliased + Acquire'd, and must outlive the redirection.  The read is
   --  non-blocking (one byte if the RX FIFO has one, else "nothing ready").
   function As_Input_Device
     (S : aliased in out Session) return ESP32S3.Serial.In_Device;

end ESP32S3.UART.Text;
