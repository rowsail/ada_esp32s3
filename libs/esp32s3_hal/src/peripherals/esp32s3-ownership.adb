package body ESP32S3.Ownership is

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

end ESP32S3.Ownership;
