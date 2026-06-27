with GNAT.Sockets;

--  A library-level, closure-free socket hook that PINS a socket to interface 0
--  (the W5500), to pass as Modbus.Master.Connect's Configure argument.  Keeping the
--  facade-only Set_Interface call in the application (not in Modbus.Master) is what
--  lets the master be host-tested; on a multi-NIC board this is where you'd choose
--  which interface a slave's traffic must use.
package Net_Pin is
   procedure Pin_Eth0 (Sock : in out GNAT.Sockets.Socket_Type);
end Net_Pin;
