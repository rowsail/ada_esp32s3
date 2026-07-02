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

   --  DHCP option codes (RFC 2132).
   Opt_Subnet     : constant := 1;
   Opt_Router     : constant := 3;
   Opt_DNS        : constant := 6;
   Opt_Req_IP     : constant := 50;
   Opt_Lease      : constant := 51;
   Opt_Msg_Type   : constant := 53;
   Opt_Server_Id  : constant := 54;
   Opt_Param_List : constant := 55;
   Opt_Pad        : constant := 0;
   Opt_End        : constant := 255;

   --  Fixed BOOTP header field offsets (RFC 951 / 2131).  chaddr is 16 bytes but
   --  we only fill the 6-byte MAC.  The option block starts after the cookie.
   Off_Op      : constant := 0;     --  op (1 = BOOTREQUEST, 2 = BOOTREPLY)
   Off_Flags   : constant := 10;
   Off_Ciaddr  : constant := 12;
   Off_Yiaddr  : constant := 16;
   Off_Chaddr  : constant := 28;
   Off_Cookie  : constant := 236;
   Off_Options : constant := 240;

   Boot_Reply    : constant Byte := 2;
   Flag_Bcast_Hi : constant Byte := 16#80#;   --  high byte of the BOOTP flags word

   --  The fixed transaction id we use for our single-client exchange, and the
   --  DHCP magic cookie (RFC 2131: 99, 130, 83, 99).  Off_Xid is where the xid
   --  sits in the header; both are matched whole on replies.
   Off_Xid : constant := 4;
   Xid     : constant Byte_Array (0 .. 3) := (16#39#, 16#03#, 16#F3#, 16#26#);
   Cookie  : constant Byte_Array (0 .. 3) := (16#63#, 16#82#, 16#53#, 16#63#);

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
   function Build
     (Msg               : Byte;
      MAC               : MAC_Address;
      Ciaddr            : IPv4_Address;
      Broadcast         : Boolean;
      Req_IP, Server_Id : IPv4_Address) return Natural
   is
      Pos : Natural;
   begin
      TX := (others => 0);
      TX (0) := 1;
      TX (1) := 1;
      TX (2) := 6;
      TX (3) := 0;     --  op/htype/hlen/hops
      TX (Off_Xid .. Off_Xid + 3) := Xid;
      if Broadcast then
         TX (Off_Flags) := Flag_Bcast_Hi;
      end if;
      TX (Off_Ciaddr .. Off_Ciaddr + 3) := Ciaddr;
      TX (Off_Chaddr .. Off_Chaddr + 5) := MAC;                  --  chaddr = MAC
      TX (Off_Cookie .. Off_Cookie + 3) := Cookie;               --  magic cookie
      Pos := Off_Options;
      TX (Pos) := Opt_Msg_Type;
      TX (Pos + 1) := 1;
      TX (Pos + 2) := Msg;
      Pos := Pos + 3;
      if Req_IP /= Zero_IP then
         TX (Pos) := Opt_Req_IP;
         TX (Pos + 1) := 4;
         TX (Pos + 2 .. Pos + 5) := Req_IP;
         Pos := Pos + 6;
      end if;
      if Server_Id /= Zero_IP then
         TX (Pos) := Opt_Server_Id;
         TX (Pos + 1) := 4;
         TX (Pos + 2 .. Pos + 5) := Server_Id;
         Pos := Pos + 6;
      end if;
      TX (Pos) := Opt_Param_List;
      TX (Pos + 1) := 4;                 --  param request list
      TX (Pos + 2) := Opt_Subnet;
      TX (Pos + 3) := Opt_Router;
      TX (Pos + 4) := Opt_DNS;
      TX (Pos + 5) := Opt_Lease;
      Pos := Pos + 6;
      TX (Pos) := Opt_End;
      return Pos + 1;
   end Build;

   --  Poll S for a reply of type Want until Deadline; parse its options into
   --  Lease, and report the server id and the assigned address (yiaddr).
   function Wait_Reply
     (S                 : in out WS.Socket;
      Want              : Byte;
      Deadline          : Time;
      Lease             : in out Lease_Info;
      Server_Id, Yiaddr : out IPv4_Address) return Boolean
   is
      From_Addr : IPv4_Address;
      From_Port : WS.Port_Number;
      Count     : Natural;
      Recv_St   : WS.Status;
      Pos, Len  : Natural;
      Code      : Byte;
      Msg       : Byte;
   begin
      Server_Id := Zero_IP;
      Yiaddr := Zero_IP;
      loop
         WS.Receive_From (S, From_Addr, From_Port, RX, Count, Recv_St);
         Count := Natural'Min (Count, RX'Length);   --  never index past RX(299)
         --  Only trust a datagram that is a BOOTREPLY (op=2) for OUR exchange
         --  (matching xid) carrying the DHCP magic cookie; otherwise it is a
         --  stray/rogue packet on UDP/68 and is ignored.
         if Count >= Off_Options
           and then RX (Off_Op) = Boot_Reply
           and then RX (Off_Xid .. Off_Xid + 3) = Xid
           and then RX (Off_Cookie .. Off_Cookie + 3) = Cookie
         then
            Msg := 0;
            Pos := Off_Options;
            --  Walk the option block, never reading past the received bytes: a
            --  truncated header or a length that runs off the end ends the walk,
            --  and each fixed-width option is taken only when its Len delivers it.
            while Pos <= Count - 1 loop
               Code := RX (Pos);
               exit when Code = Opt_End;
               if Code = Opt_Pad then
                  Pos := Pos + 1;
               else
                  exit when Pos + 1 > Count - 1;        --  length byte must exist
                  Len := Natural (RX (Pos + 1));
                  exit when Pos + 1 + Len > Count - 1;  --  whole option body must exist
                  case Code is
                     when Opt_Msg_Type  =>
                        if Len >= 1 then
                           Msg := RX (Pos + 2);
                        end if;

                     when Opt_Server_Id =>
                        if Len >= 4 then
                           Server_Id := RX (Pos + 2 .. Pos + 5);
                        end if;

                     when Opt_Subnet    =>
                        if Len >= 4 then
                           Lease.Subnet := RX (Pos + 2 .. Pos + 5);
                        end if;

                     when Opt_Router    =>
                        if Len >= 4 then
                           Lease.Gateway := RX (Pos + 2 .. Pos + 5);
                        end if;

                     when Opt_DNS       =>
                        if Len >= 4 then
                           Lease.DNS := RX (Pos + 2 .. Pos + 5);
                        end if;

                     when Opt_Lease     =>
                        if Len >= 4 then
                           Lease.Lease_Seconds :=
                             Shift_Left (Unsigned_32 (RX (Pos + 2)), 24)
                             or Shift_Left (Unsigned_32 (RX (Pos + 3)), 16)
                             or Shift_Left (Unsigned_32 (RX (Pos + 4)), 8)
                             or Unsigned_32 (RX (Pos + 5));
                        end if;

                     when others        =>
                        null;
                  end case;
                  Pos := Pos + 2 + Len;
               end if;
            end loop;
            if Msg = Want then
               Yiaddr := RX (Off_Yiaddr .. Off_Yiaddr + 3);
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

   function Do_Acquire
     (Dev    : WS.Device_Access;
      MAC    : MAC_Address;
      Socket : Socket_Id;
      Tries  : Positive;
      Lease  : out Lease_Info;
      Server : out IPv4_Address) return Boolean
   is
      S               : WS.Socket;
      St              : WS.Status;
      TX_Len          : Natural;
      Offered, Srv_Id : IPv4_Address;
   begin
      Lease := (others => <>);
      Server := Zero_IP;
      Configure (Dev.all, MAC, Zero_IP, Zero_IP, Zero_IP);    --  0.0.0.0 for DORA
      WS.Open_UDP (Dev, S, Socket, Client_Port, St);
      if St /= WS.OK then
         return False;
      end if;
      for Attempt in 1 .. Tries loop
         TX_Len := Build (Discover, MAC, Zero_IP, True, Zero_IP, Zero_IP);
         WS.Send_To (S, Bcast, Server_Port, TX (0 .. TX_Len - 1), St);
         if St = WS.OK and then Wait_Reply (S, Offer, Clock + Seconds (2), Lease, Srv_Id, Offered)
         then
            TX_Len := Build (Request, MAC, Zero_IP, True, Offered, Srv_Id);
            WS.Send_To (S, Bcast, Server_Port, TX (0 .. TX_Len - 1), St);
            if St = WS.OK and then Wait_Reply (S, Ack, Clock + Seconds (2), Lease, Srv_Id, Offered)
            then
               Lease.IP := Offered;
               Server := Srv_Id;
               WS.Close (S);
               Configure (Dev.all, MAC, Lease.IP, Lease.Subnet, Lease.Gateway);
               return True;
            end if;
         end if;
      end loop;
      WS.Close (S);
      return False;
   end Do_Acquire;

   --  Renew (Broadcast=False => unicast to Server) or rebind (Broadcast=True).
   --  ciaddr carries the current IP, so the address stays up across the exchange.
   function Do_Renew
     (Dev       : WS.Device_Access;
      MAC       : MAC_Address;
      Socket    : Socket_Id;
      Broadcast : Boolean;
      Server    : IPv4_Address;
      Lease     : in out Lease_Info) return Boolean
   is
      S                   : WS.Socket;
      St                  : WS.Status;
      TX_Len              : Natural;
      Srv_Id, Assigned_IP : IPv4_Address;
   begin
      WS.Open_UDP (Dev, S, Socket, Client_Port, St);
      if St /= WS.OK then
         return False;
      end if;
      TX_Len := Build (Request, MAC, Lease.IP, Broadcast, Zero_IP, Zero_IP);
      if Broadcast then
         WS.Send_To (S, Bcast, Server_Port, TX (0 .. TX_Len - 1), St);
      else
         WS.Send_To (S, Server, Server_Port, TX (0 .. TX_Len - 1), St);
      end if;
      if St = WS.OK and then Wait_Reply (S, Ack, Clock + Seconds (2), Lease, Srv_Id, Assigned_IP)
      then
         if Assigned_IP /= Zero_IP then
            Lease.IP := Assigned_IP;
         end if;
         WS.Close (S);
         Configure (Dev.all, MAC, Lease.IP, Lease.Subnet, Lease.Gateway);
         return True;
      end if;
      WS.Close (S);
      return False;
   end Do_Renew;

   ---------------------------------------------------------------------------
   --  Public one-shot operations
   ---------------------------------------------------------------------------

   function Acquire_Lease
     (Dev    : WS.Device_Access;
      MAC    : MAC_Address;
      Lease  : out Lease_Info;
      Socket : Socket_Id := 0;
      Tries  : Positive := 4) return Boolean
   is
      Server : IPv4_Address;
   begin
      return Do_Acquire (Dev, MAC, Socket, Tries, Lease, Server);
   end Acquire_Lease;

   function Renew_Lease
     (Dev    : WS.Device_Access;
      MAC    : MAC_Address;
      Lease  : in out Lease_Info;
      Socket : Socket_Id := 0) return Boolean is
   begin
      return Do_Renew (Dev, MAC, Socket, Broadcast => True, Server => Zero_IP, Lease => Lease);
   end Renew_Lease;

   ---------------------------------------------------------------------------
   --  Automatic maintenance task
   ---------------------------------------------------------------------------

   Go       : Suspension_Object;
   M_Dev    : WS.Device_Access := null;
   M_MAC    : MAC_Address;
   M_Socket : Socket_Id := 0;
   M_Cb     : Bound_Callback := null;
   M_Bound  : Boolean := False
   with Volatile;
   M_Lease  : Lease_Info;

   procedure Maintain
     (Dev      : WS.Device_Access;
      MAC      : MAC_Address;
      Socket   : Socket_Id := 0;
      On_Bound : Bound_Callback := null) is
   begin
      M_Dev := Dev;
      M_MAC := MAC;
      M_Socket := Socket;
      M_Cb := On_Bound;
      Set_True (Go);
   end Maintain;

   function Is_Bound return Boolean
   is (M_Bound);
   function Current_Lease return Lease_Info
   is (M_Lease);

   task Lease_Task
     with Priority => System.Priority'First + 1;
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
         if M_Cb /= null then
            M_Cb (M_Lease);
         end if;

         --  Hold the lease: renew at T1, rebind at T2, drop at expiry.
         Bound_At := Clock;
         loop
            declare
               Lease_Secs : constant Natural :=
                 Natural
                   (Unsigned_32'Max (60, Unsigned_32'Min (M_Lease.Lease_Seconds, 1_000_000)));
               T1         : constant Time := Bound_At + Seconds (Lease_Secs / 2);
               T2         : constant Time := Bound_At + Seconds (Lease_Secs * 7 / 8);
               Expiry     : constant Time := Bound_At + Seconds (Lease_Secs);
            begin
               delay until T1;
               Renewed := Do_Renew (M_Dev, M_MAC, M_Socket, False, Server, M_Lease);
               if not Renewed then
                  delay until T2;
                  Renewed := Do_Renew (M_Dev, M_MAC, M_Socket, True, Server, M_Lease);
               end if;
               if Renewed then
                  Bound_At := Clock;
                  if M_Cb /= null then
                     M_Cb (M_Lease);
                  end if;
               else
                  delay until Expiry;
                  exit;                              --  expired -> re-acquire
               end if;
            end;
         end loop;
         M_Bound := False;
      end loop;
   end Lease_Task;

end ESP32S3.W5500.DHCP;
