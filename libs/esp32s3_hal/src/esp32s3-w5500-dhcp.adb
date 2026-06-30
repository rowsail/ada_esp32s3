with System;
with Interfaces;                   use Interfaces;
with Ada.Real_Time;                use Ada.Real_Time;
with Ada.Synchronous_Task_Control; use Ada.Synchronous_Task_Control;

package body ESP32S3.W5500.DHCP is

   package WS renames ESP32S3.W5500.Sockets;
   use type WS.Status;

   Server_Port : constant WS.Port_Number := 67;
   Client_Port : constant WS.Port_Number := 68;

   Discover : constant Byte := 1;   --  DHCP message types (option 53)
   Offer    : constant Byte := 2;
   Request  : constant Byte := 3;
   Ack      : constant Byte := 5;

   Zero_IP : constant IPv4_Address := (0, 0, 0, 0);
   Bcast   : constant IPv4_Address := (255, 255, 255, 255);

   --  One DHCP client => one set of scratch buffers (uses are never concurrent).
   TX, RX : Byte_Array (0 .. 299);

   ---------------------------------------------------------------------------
   --  Frame build + reply parse
   ---------------------------------------------------------------------------

   --  Build a BOOTP/DHCP frame into TX; return its length.  Ciaddr is the
   --  client's current IP (0 during DORA, the leased IP when renewing).  Req_IP
   --  and Server_Id, when non-zero, add options 50 / 54 (the SELECTING request).
   function Build (Msg : Byte; MAC : MAC_Address; Ciaddr : IPv4_Address;
                   Broadcast : Boolean; Req_IP, Server_Id : IPv4_Address)
                   return Natural is
      P : Natural;
   begin
      TX := (others => 0);
      TX (0) := 1;  TX (1) := 1;  TX (2) := 6;  TX (3) := 0;     --  op/htype/hlen/hops
      TX (4) := 16#39#; TX (5) := 16#03#;                        --  xid (fixed)
      TX (6) := 16#F3#; TX (7) := 16#26#;
      if Broadcast then TX (10) := 16#80#; end if;              --  flags
      for I in 0 .. 3 loop TX (12 + I) := Ciaddr (I); end loop;  --  ciaddr
      for I in 0 .. 5 loop TX (28 + I) := MAC (I);    end loop;  --  chaddr = MAC
      TX (236) := 16#63#; TX (237) := 16#82#;                    --  magic cookie
      TX (238) := 16#53#; TX (239) := 16#63#;
      P := 240;
      TX (P) := 53; TX (P + 1) := 1; TX (P + 2) := Msg;  P := P + 3;
      if Req_IP /= Zero_IP then
         TX (P) := 50; TX (P + 1) := 4;
         for I in 0 .. 3 loop TX (P + 2 + I) := Req_IP (I); end loop;  P := P + 6;
      end if;
      if Server_Id /= Zero_IP then
         TX (P) := 54; TX (P + 1) := 4;
         for I in 0 .. 3 loop TX (P + 2 + I) := Server_Id (I); end loop;  P := P + 6;
      end if;
      TX (P) := 55; TX (P + 1) := 4;                             --  param request list
      TX (P + 2) := 1; TX (P + 3) := 3; TX (P + 4) := 6; TX (P + 5) := 51;  P := P + 6;
      TX (P) := 255;                                             --  end
      return P + 1;
   end Build;

   --  Poll S for a reply of type Want until Deadline; parse its options into
   --  Lease, and report the server id and the assigned address (yiaddr).
   function Wait_Reply (S : in out WS.Socket; Want : Byte; Deadline : Time;
                        Lease : in out Lease_Info;
                        Server_Id, Yiaddr : out IPv4_Address) return Boolean is
      FA           : IPv4_Address;
      FP           : WS.Port_Number;
      Count        : Natural;
      Rst          : WS.Status;
      P, Code, Len : Natural;
      Msg          : Byte;
   begin
      Server_Id := Zero_IP;  Yiaddr := Zero_IP;
      loop
         WS.Receive_From (S, FA, FP, RX, Count, Rst);
         Count := Natural'Min (Count, RX'Length);   --  never index past RX(299)
         --  Only trust a datagram that is a BOOTREPLY (op=2) for OUR exchange
         --  (matching xid) carrying the DHCP magic cookie; otherwise it is a
         --  stray/rogue packet on UDP/68 and is ignored.
         if Count >= 240
           and then RX (0) = 2
           and then RX (4) = 16#39# and then RX (5) = 16#03#
           and then RX (6) = 16#F3# and then RX (7) = 16#26#
           and then RX (236) = 16#63# and then RX (237) = 16#82#
           and then RX (238) = 16#53# and then RX (239) = 16#63#
         then
            Msg := 0;  P := 240;
            --  Walk the option block, never reading past the received bytes: a
            --  truncated header or a length that runs off the end ends the walk,
            --  and each fixed-width option is taken only when its Len delivers it.
            while P <= Count - 1 loop
               Code := Natural (RX (P));
               exit when Code = 255;                 --  end option
               if Code = 0 then                      --  pad
                  P := P + 1;
               else
                  exit when P + 1 > Count - 1;        --  length byte must exist
                  Len := Natural (RX (P + 1));
                  exit when P + 1 + Len > Count - 1;  --  whole option body must exist
                  case Code is
                     when 53 => if Len >= 1 then Msg := RX (P + 2); end if;
                     when 54 => if Len >= 4 then for I in 0 .. 3 loop Server_Id (I) := RX (P + 2 + I); end loop; end if;
                     when 1  => if Len >= 4 then for I in 0 .. 3 loop Lease.Subnet  (I) := RX (P + 2 + I); end loop; end if;
                     when 3  => if Len >= 4 then for I in 0 .. 3 loop Lease.Gateway (I) := RX (P + 2 + I); end loop; end if;
                     when 6  => if Len >= 4 then for I in 0 .. 3 loop Lease.DNS     (I) := RX (P + 2 + I); end loop; end if;
                     when 51 =>
                        if Len >= 4 then
                           Lease.Lease_Seconds :=
                             Shift_Left (Unsigned_32 (RX (P + 2)), 24) or
                             Shift_Left (Unsigned_32 (RX (P + 3)), 16) or
                             Shift_Left (Unsigned_32 (RX (P + 4)), 8)  or
                                         Unsigned_32 (RX (P + 5));
                        end if;
                     when others => null;
                  end case;
                  P := P + 2 + Len;
               end if;
            end loop;
            if Msg = Want then
               for I in 0 .. 3 loop Yiaddr (I) := RX (16 + I); end loop;
               return True;
            end if;
         end if;
         exit when Clock >= Deadline;
         delay until Clock + Milliseconds (10);
      end loop;
      return False;
   end Wait_Reply;

   ---------------------------------------------------------------------------
   --  Acquire (DORA) and renew, sharing the above
   ---------------------------------------------------------------------------

   function Do_Acquire (Dev : WS.Device_Access; MAC : MAC_Address;
                        Socket : Socket_Id; Tries : Positive;
                        Lease : out Lease_Info; Server : out IPv4_Address)
                        return Boolean is
      S       : WS.Socket;
      St      : WS.Status;
      TX_Len  : Natural;
      Offered, SId : IPv4_Address;
   begin
      Lease := (others => <>);  Server := Zero_IP;
      Configure (Dev.all, MAC, Zero_IP, Zero_IP, Zero_IP);    --  0.0.0.0 for DORA
      WS.Open_UDP (Dev, S, Socket, Client_Port, St);
      if St /= WS.OK then return False; end if;
      for Attempt in 1 .. Tries loop
         TX_Len := Build (Discover, MAC, Zero_IP, True, Zero_IP, Zero_IP);
         WS.Send_To (S, Bcast, Server_Port, TX (0 .. TX_Len - 1), St);
         if St = WS.OK
           and then Wait_Reply (S, Offer, Clock + Seconds (2), Lease, SId, Offered)
         then
            TX_Len := Build (Request, MAC, Zero_IP, True, Offered, SId);
            WS.Send_To (S, Bcast, Server_Port, TX (0 .. TX_Len - 1), St);
            if St = WS.OK
              and then Wait_Reply (S, Ack, Clock + Seconds (2), Lease, SId, Offered)
            then
               Lease.IP := Offered;  Server := SId;  WS.Close (S);
               Configure (Dev.all, MAC, Lease.IP, Lease.Subnet, Lease.Gateway);
               return True;
            end if;
         end if;
      end loop;
      WS.Close (S);  return False;
   end Do_Acquire;

   --  Renew (Broadcast=False => unicast to Server) or rebind (Broadcast=True).
   --  ciaddr carries the current IP, so the address stays up across the exchange.
   function Do_Renew (Dev : WS.Device_Access; MAC : MAC_Address;
                      Socket : Socket_Id; Broadcast : Boolean; Server : IPv4_Address;
                      Lease : in out Lease_Info) return Boolean is
      S      : WS.Socket;
      St     : WS.Status;
      TX_Len : Natural;
      SId, Yi : IPv4_Address;
   begin
      WS.Open_UDP (Dev, S, Socket, Client_Port, St);
      if St /= WS.OK then return False; end if;
      TX_Len := Build (Request, MAC, Lease.IP, Broadcast, Zero_IP, Zero_IP);
      if Broadcast then
         WS.Send_To (S, Bcast, Server_Port, TX (0 .. TX_Len - 1), St);
      else
         WS.Send_To (S, Server, Server_Port, TX (0 .. TX_Len - 1), St);
      end if;
      if St = WS.OK
        and then Wait_Reply (S, Ack, Clock + Seconds (2), Lease, SId, Yi)
      then
         if Yi /= Zero_IP then Lease.IP := Yi; end if;
         WS.Close (S);
         Configure (Dev.all, MAC, Lease.IP, Lease.Subnet, Lease.Gateway);
         return True;
      end if;
      WS.Close (S);  return False;
   end Do_Renew;

   ---------------------------------------------------------------------------
   --  Public one-shot operations
   ---------------------------------------------------------------------------

   function Acquire_Lease
     (Dev : WS.Device_Access; MAC : MAC_Address; Lease : out Lease_Info;
      Socket : Socket_Id := 0; Tries : Positive := 4) return Boolean
   is
      Server : IPv4_Address;
   begin
      return Do_Acquire (Dev, MAC, Socket, Tries, Lease, Server);
   end Acquire_Lease;

   function Renew_Lease
     (Dev : WS.Device_Access; MAC : MAC_Address; Lease : in out Lease_Info;
      Socket : Socket_Id := 0) return Boolean is
   begin
      return Do_Renew (Dev, MAC, Socket, Broadcast => True,
                       Server => Zero_IP, Lease => Lease);
   end Renew_Lease;

   ---------------------------------------------------------------------------
   --  Automatic maintenance task
   ---------------------------------------------------------------------------

   Go       : Suspension_Object;
   M_Dev    : WS.Device_Access := null;
   M_MAC    : MAC_Address;
   M_Socket : Socket_Id := 0;
   M_Cb     : Bound_Callback := null;
   M_Bound  : Boolean := False with Volatile;
   M_Lease  : Lease_Info;

   procedure Maintain
     (Dev : WS.Device_Access; MAC : MAC_Address;
      Socket : Socket_Id := 0; On_Bound : Bound_Callback := null) is
   begin
      M_Dev := Dev;  M_MAC := MAC;  M_Socket := Socket;  M_Cb := On_Bound;
      Set_True (Go);
   end Maintain;

   function Is_Bound      return Boolean    is (M_Bound);
   function Current_Lease return Lease_Info is (M_Lease);

   task Lease_Task with Priority => System.Priority'First + 1;
   task body Lease_Task is
      Server   : IPv4_Address;
      Bound_At : Time;
      Renewed  : Boolean;
   begin
      Suspend_Until_True (Go);                       --  wait until Maintain arms us
      loop
         --  Acquire (retrying) -- the chip ends up at 0.0.0.0 until this succeeds.
         while not Do_Acquire (M_Dev, M_MAC, M_Socket, 4, M_Lease, Server) loop
            delay until Clock + Seconds (10);
         end loop;
         M_Bound := True;
         if M_Cb /= null then M_Cb (M_Lease); end if;

         --  Hold the lease: renew at T1, rebind at T2, drop at expiry.
         Bound_At := Clock;
         loop
            declare
               L  : constant Natural := Natural
                      (Unsigned_32'Max (60, Unsigned_32'Min (M_Lease.Lease_Seconds,
                                                             1_000_000)));
               T1 : constant Time := Bound_At + Seconds (L / 2);
               T2 : constant Time := Bound_At + Seconds (L * 7 / 8);
               Ex : constant Time := Bound_At + Seconds (L);
            begin
               delay until T1;
               Renewed := Do_Renew (M_Dev, M_MAC, M_Socket, False, Server, M_Lease);
               if not Renewed then
                  delay until T2;
                  Renewed := Do_Renew (M_Dev, M_MAC, M_Socket, True, Server, M_Lease);
               end if;
               if Renewed then
                  Bound_At := Clock;
                  if M_Cb /= null then M_Cb (M_Lease); end if;
               else
                  delay until Ex;
                  exit;                              --  expired -> re-acquire
               end if;
            end;
         end loop;
         M_Bound := False;
      end loop;
   end Lease_Task;

end ESP32S3.W5500.DHCP;
