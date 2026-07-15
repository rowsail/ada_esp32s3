with Interfaces;    use Interfaces;
with Ada.Real_Time; use Ada.Real_Time;

package body ESP32S3.WiFi.DHCP is

   package Net renames ESP32S3.WiFi.IP;
   use type Net.IPv4;

   subtype Octet is Net.Octet;
   subtype Bytes is Net.Byte_Array;

   Client_Port : constant Net.U16 := 68;
   Server_Port : constant Net.U16 := 67;

   --  BOOTP/DHCP fixed field offsets (into the UDP payload).
   Magic  : constant := 236;   --  99, 130, 83, 99 then options
   Yiaddr : constant := 16;    --  "your" (assigned) IP
   Chaddr : constant := 28;    --  client hardware address (16 bytes)

   --  DHCP option codes.
   Opt_Subnet   : constant Octet := 1;
   Opt_Router   : constant Octet := 3;
   Opt_DNS      : constant Octet := 6;
   Opt_Lease    : constant Octet := 51;
   Opt_Msg_Type : constant Octet := 53;
   Opt_Server   : constant Octet := 54;
   Opt_Req_IP   : constant Octet := 50;
   Opt_Param    : constant Octet := 55;
   Opt_End      : constant Octet := 255;

   --  DHCP message types.
   Discover : constant Octet := 1;
   Offer    : constant Octet := 2;
   Request  : constant Octet := 3;
   Ack      : constant Octet := 5;

   procedure Put32 (B : in out Bytes; I : Natural; V : Unsigned_32) is
   begin
      B (I)     := Octet (Shift_Right (V, 24) and 16#FF#);
      B (I + 1) := Octet (Shift_Right (V, 16) and 16#FF#);
      B (I + 2) := Octet (Shift_Right (V, 8)  and 16#FF#);
      B (I + 3) := Octet (V and 16#FF#);
   end Put32;

   function Get32 (B : Bytes; I : Natural) return Unsigned_32 is
     (Shift_Left (Unsigned_32 (B (I)),     24) or
      Shift_Left (Unsigned_32 (B (I + 1)), 16) or
      Shift_Left (Unsigned_32 (B (I + 2)), 8)  or
      Unsigned_32 (B (I + 3)));

   --  A transaction id derived from the station MAC (stable per boot).
   function Make_Xid return Unsigned_32 is
      M : constant Net.MAC := Net.Own_MAC;
   begin
      return Shift_Left (Unsigned_32 (M (2)), 24) or
             Shift_Left (Unsigned_32 (M (3)), 16) or
             Shift_Left (Unsigned_32 (M (4)), 8)  or
             Unsigned_32 (M (5));
   end Make_Xid;

   --  Fill the common BOOTP header of an outgoing message.
   procedure Fill_Header (P : in out Bytes; Xid : Unsigned_32) is
      M : constant Net.MAC := Net.Own_MAC;
   begin
      P := (others => 0);
      P (0) := 1;      --  op = BOOTREQUEST
      P (1) := 1;      --  htype = Ethernet
      P (2) := 6;      --  hlen
      Put32 (P, 4, Xid);
      --  flags: UNICAST reply (broadcast bit clear).  Our radio can only decrypt
      --  frames sent to us (PTK) -- broadcast data frames need the group key
      --  (GTK), which the supplicant does not install -- so we ask the server to
      --  unicast the OFFER/ACK to our MAC (RFC 2131 s4.1: server unicasts to
      --  chaddr + yiaddr when the broadcast bit is clear).
      P (10) := 0;
      for I in 0 .. 5 loop
         P (Chaddr + I) := M (I);
      end loop;
      P (Magic)     := 99;
      P (Magic + 1) := 130;
      P (Magic + 2) := 83;
      P (Magic + 3) := 99;
   end Fill_Header;

   --  Find option Code in the options area; return its value slice bounds.
   procedure Find_Option (P : Bytes; Code : Octet;
                          Found : out Boolean; First, Last : out Natural) is
      I : Natural := Magic + 4;
   begin
      Found := False; First := 0; Last := 0;
      while I <= P'Last loop
         exit when P (I) = Opt_End;
         if P (I) = 0 then           --  pad
            I := I + 1;
         elsif I + 1 <= P'Last then
            declare
               Len : constant Natural := Natural (P (I + 1));
            begin
               exit when I + 1 + Len > P'Last;
               if P (I) = Code then
                  Found := True;
                  First := I + 2;
                  Last  := I + 1 + Len;
                  return;
               end if;
               I := I + 2 + Len;
            end;
         else
            exit;
         end if;
      end loop;
   end Find_Option;

   function Msg_Type (P : Bytes) return Octet is
      Found : Boolean;
      F, L  : Natural;
   begin
      Find_Option (P, Opt_Msg_Type, Found, F, L);
      return (if Found then P (F) else 0);
   end Msg_Type;

   function Opt_IP (P : Bytes; Code : Octet; Value : out Net.IPv4) return Boolean is
      Found : Boolean;
      F, L  : Natural;
   begin
      Value := (0, 0, 0, 0);
      Find_Option (P, Code, Found, F, L);
      if Found and then L - F + 1 = 4 then
         Value := Net.IPv4 (P (F .. F + 3));
         return True;
      end if;
      return False;
   end Opt_IP;

   --  Wait (Poll-driving) for a reply of the wanted message type + our Xid.
   function Await (Socket : Net.Socket_Id; Xid : Unsigned_32; Want : Octet;
                   Reply : out Bytes; Reply_Len : out Natural;
                   Timeout : Duration) return Boolean is
      From      : Net.IPv4;
      From_Port : Net.U16;
      Deadline  : constant Time := Clock + To_Time_Span (Timeout);
   begin
      loop
         Net.Poll;
         Net.Receive_From (Socket, From, From_Port, Reply, Reply_Len);
         if Reply_Len >= Magic + 4
           and then Get32 (Reply, 4) = Xid
           and then Msg_Type (Reply (Reply'First .. Reply'First + Reply_Len - 1))
                    = Want
         then
            return True;
         end if;
         exit when Clock >= Deadline;
         delay until Clock + Milliseconds (5);
      end loop;
      return False;
   end Await;

   function Acquire
     (Socket : Net.Socket_Id;
      L      : out Lease;
      Tries  : Positive := 4) return Boolean
   is
      Xid       : constant Unsigned_32 := Make_Xid;
      Ok        : Boolean;
      Reply     : Bytes (0 .. 767);
      Reply_Len : Natural;
      Server    : Net.IPv4 := (0, 0, 0, 0);
      Offered   : Net.IPv4;
   begin
      L := (others => <>);
      Net.Open (Socket, Client_Port, Ok);
      if not Ok then
         return False;
      end if;

      for Attempt in 1 .. Tries loop
         --  DISCOVER
         declare
            P : Bytes (0 .. Magic + 15);
         begin
            Fill_Header (P, Xid);
            P (Magic + 4) := Opt_Msg_Type; P (Magic + 5) := 1; P (Magic + 6) := Discover;
            P (Magic + 7) := Opt_Param;    P (Magic + 8) := 3;
            P (Magic + 9) := Opt_Subnet;   P (Magic + 10) := Opt_Router;
            P (Magic + 11) := Opt_DNS;
            P (Magic + 12) := Opt_End;
            Net.Send_To (Socket, Net.Broadcast_IP, Server_Port, P (0 .. Magic + 12), Ok);
         end;

         if Await (Socket, Xid, Offer, Reply, Reply_Len, 2.0) then
            Offered := Net.IPv4 (Reply (Yiaddr .. Yiaddr + 3));
            if not Opt_IP (Reply (Reply'First .. Reply'First + Reply_Len - 1),
                           Opt_Server, Server)
            then
               Server := (0, 0, 0, 0);
            end if;

            --  REQUEST the offered address.
            declare
               P : Bytes (0 .. Magic + 25);
            begin
               Fill_Header (P, Xid);
               P (Magic + 4) := Opt_Msg_Type; P (Magic + 5) := 1; P (Magic + 6) := Request;
               P (Magic + 7) := Opt_Req_IP;   P (Magic + 8) := 4;
               P (Magic + 9 .. Magic + 12) := Bytes (Offered);
               P (Magic + 13) := Opt_Server;  P (Magic + 14) := 4;
               P (Magic + 15 .. Magic + 18) := Bytes (Server);
               P (Magic + 19) := Opt_End;
               Net.Send_To (Socket, Net.Broadcast_IP, Server_Port, P (0 .. Magic + 19), Ok);
            end;

            if Await (Socket, Xid, Ack, Reply, Reply_Len, 2.0) then
               declare
                  R : Bytes renames Reply (Reply'First .. Reply'First + Reply_Len - 1);
                  Found : Boolean;
                  F, La : Natural;
               begin
                  L.Addr := Net.IPv4 (R (Yiaddr .. Yiaddr + 3));
                  if not Opt_IP (R, Opt_Subnet,  L.Mask)    then L.Mask := (255, 255, 255, 0); end if;
                  if not Opt_IP (R, Opt_Router,  L.Gateway) then L.Gateway := (0, 0, 0, 0); end if;
                  if not Opt_IP (R, Opt_DNS,     L.DNS)     then L.DNS := (0, 0, 0, 0); end if;
                  Find_Option (R, Opt_Lease, Found, F, La);
                  if Found and then La - F + 1 = 4 then
                     L.Lease_Seconds := Get32 (R, F);
                  end if;
               end;
               Net.Configure (L.Addr, L.Mask, L.Gateway, L.DNS);
               Net.Close (Socket);
               return True;
            end if;
         end if;
      end loop;

      Net.Close (Socket);
      return False;
   end Acquire;

end ESP32S3.WiFi.DHCP;
