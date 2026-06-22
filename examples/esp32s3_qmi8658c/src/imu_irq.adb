package body IMU_IRQ is

   procedure Handler is
   begin
      Fired := True;   --  latch only; the main task does the I2C work
   end Handler;

end IMU_IRQ;
