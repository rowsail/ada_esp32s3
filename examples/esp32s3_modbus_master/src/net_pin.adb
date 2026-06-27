package body Net_Pin is

   procedure Pin_Eth0 (Sock : in out GNAT.Sockets.Socket_Type) is
   begin
      GNAT.Sockets.Set_Interface (Sock, 0);   --  confine this socket to the W5500
   end Pin_Eth0;

end Net_Pin;
