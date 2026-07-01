with System.Address_To_Access_Conversions;

package body ESP32S3.UART.Text is

   --  As a child of ESP32S3.UART, the full view of Session is visible here, so we
   --  can recover the held Session from the address stashed in the Device's Ctx.
   package Conv is new System.Address_To_Access_Conversions (Session);

   procedure Write_Adapter (Ctx : System.Address; S : String) is
      Sess : constant Conv.Object_Pointer := Conv.To_Pointer (Ctx);
      Data : Byte_Array (0 .. S'Length - 1);
   begin
      if S'Length = 0 then
         return;
      end if;
      for I in Data'Range loop
         Data (I) := Byte (Character'Pos (S (S'First + I)));
      end loop;
      Write (Sess.all, Data);   --  ESP32S3.UART.Write: blocking, push-pull
   end Write_Adapter;

   procedure Flush_Adapter (Ctx : System.Address) is
      pragma Unreferenced (Ctx);
   begin
      null;   --  UART.Write goes straight to the TX FIFO; nothing buffered here
   end Flush_Adapter;

   function As_Device (S : aliased in out Session) return ESP32S3.Serial.Device is
   begin
      return (Write => Write_Adapter'Access,
              Flush => Flush_Adapter'Access,
              Ctx   => S'Address);
   end As_Device;

   --  Non-blocking single-byte input from the held UART.  Only touch the RX FIFO
   --  when Available reports a byte waiting, so the read returns immediately
   --  instead of paying UART.Read's per-byte settle wait on an empty FIFO.
   procedure Read_Adapter (Ctx : System.Address; C : out Character;
                           Avail : out Boolean) is
      Sess : constant Conv.Object_Pointer := Conv.To_Pointer (Ctx);
      One  : Byte_Array (0 .. 0);
      N    : Natural;
   begin
      if Available (Sess.all) > 0 then
         Read (Sess.all, One, N);
         if N > 0 then
            C := Character'Val (Natural (One (0)));
            Avail := True;
            return;
         end if;
      end if;
      C := ASCII.NUL;
      Avail := False;
   end Read_Adapter;

   function As_Input_Device
     (S : aliased in out Session) return ESP32S3.Serial.In_Device is
   begin
      return (Read => Read_Adapter'Access, Ctx => S'Address);
   end As_Input_Device;

end ESP32S3.UART.Text;
