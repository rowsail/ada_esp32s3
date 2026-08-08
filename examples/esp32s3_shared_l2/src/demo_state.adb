package body Demo_State is

   task body Can_Reader is
      F : ESP32S3.TWAI.Queued_Frame;
   begin
      ESP32S3.TWAI.Get (F);
      Can_Frame := F;
      Can_Got := True;
   end Can_Reader;

end Demo_State;
