with Interfaces;              use Interfaces;
with System;
with System.Storage_Elements; use System.Storage_Elements;
with Ada.Real_Time;           use Ada.Real_Time;
with ESP32S3.MAC;

package body ESP32S3.WiFi.IP is

   Max_Frame : constant := 1600;   --  >= a full 802.3 frame

   --  EtherTypes and protocol numbers.
   ET_ARP  : constant U16   := 16#0806#;
   ET_IPV4 : constant U16   := 16#0800#;
   IP_UDP  : constant Octet := 17;
   IP_TCP  : constant Octet := 6;

   Bcast_MAC : constant MAC := (others => 16#FF#);

   --  ----------------------------------------------------------------------
   --  Interface state (env-task owned, except Our_MAC which Start writes once).
   --  ----------------------------------------------------------------------
   Addr, Mask, Gw, Dns : IPv4 := Any_IP;
   Our_MAC             : MAC  := (others => 0);

   function Local_Address return IPv4 is (Addr);
   function Subnet_Mask   return IPv4 is (Mask);
   function Gateway       return IPv4 is (Gw);
   function DNS_Server    return IPv4 is (Dns);
   function Own_MAC       return MAC  is (Our_MAC);
   function Configured    return Boolean is (Addr /= Any_IP);

   procedure Configure (Addr, Mask, Gateway, DNS : IPv4) is
   begin
      IP.Addr := Addr;
      IP.Mask := Mask;
      IP.Gw   := Gateway;
      IP.Dns  := DNS;
   end Configure;

   --  ----------------------------------------------------------------------
   --  Big-endian (network order) 16-bit helpers.
   --  ----------------------------------------------------------------------
   function Get16 (B : Byte_Array; I : Natural) return U16 is
     (Shift_Left (U16 (B (I)), 8) or U16 (B (I + 1)));

   procedure Put16 (B : in out Byte_Array; I : Natural; V : U16) is
   begin
      B (I)     := Octet (Shift_Right (V, 8));
      B (I + 1) := Octet (V and 16#FF#);
   end Put16;

   function Get32 (B : Byte_Array; I : Natural) return Unsigned_32 is
     (Shift_Left (Unsigned_32 (B (I)), 24)
      or Shift_Left (Unsigned_32 (B (I + 1)), 16)
      or Shift_Left (Unsigned_32 (B (I + 2)), 8)
      or Unsigned_32 (B (I + 3)));

   procedure Put32 (B : in out Byte_Array; I : Natural; V : Unsigned_32) is
   begin
      B (I)     := Octet (Shift_Right (V, 24) and 16#FF#);
      B (I + 1) := Octet (Shift_Right (V, 16) and 16#FF#);
      B (I + 2) := Octet (Shift_Right (V, 8) and 16#FF#);
      B (I + 3) := Octet (V and 16#FF#);
   end Put32;

   --  TCP segment RX and the retransmit timer, defined with the TCP section
   --  below but called from Handle_Ip / Poll above it.
   procedure Handle_Tcp (Src, Dst : IPv4; Seg : Byte_Array);
   procedure TCP_Tick;

   --  IPv4 header checksum (16-bit one's-complement of the header words).
   function Checksum (B : Byte_Array) return U16 is
      Sum : Unsigned_32 := 0;
      I   : Natural := B'First;
   begin
      while I + 1 <= B'Last loop
         Sum := Sum + Unsigned_32 (Get16 (B, I));
         I := I + 2;
      end loop;
      if I = B'Last then
         Sum := Sum + Shift_Left (Unsigned_32 (B (I)), 8);
      end if;
      while Shift_Right (Sum, 16) /= 0 loop
         Sum := (Sum and 16#FFFF#) + Shift_Right (Sum, 16);
      end loop;
      return U16 (not Sum and 16#FFFF#);
   end Checksum;

   --  TCP/UDP checksum over the IPv4 pseudo-header (Src, Dst, Proto, segment
   --  length) plus the segment itself.  The segment's own checksum field must
   --  be zero on the way in.  TCP requires this; UDP over IPv4 may skip it.
   function L4_Checksum (Src, Dst : IPv4; Proto : Octet; Seg : Byte_Array)
                         return U16 is
      Sum : Unsigned_32 := 0;
      I   : Natural := Seg'First;
   begin
      Sum := Sum + Unsigned_32 (Get16 (Byte_Array (Src), 0))
                 + Unsigned_32 (Get16 (Byte_Array (Src), 2))
                 + Unsigned_32 (Get16 (Byte_Array (Dst), 0))
                 + Unsigned_32 (Get16 (Byte_Array (Dst), 2))
                 + Unsigned_32 (Proto)
                 + Unsigned_32 (Seg'Length);
      while I + 1 <= Seg'Last loop
         Sum := Sum + Unsigned_32 (Get16 (Seg, I));
         I := I + 2;
      end loop;
      if I = Seg'Last then
         Sum := Sum + Shift_Left (Unsigned_32 (Seg (I)), 8);
      end if;
      while Shift_Right (Sum, 16) /= 0 loop
         Sum := (Sum and 16#FFFF#) + Shift_Right (Sum, 16);
      end loop;
      return U16 (not Sum and 16#FFFF#);
   end L4_Checksum;

   function On_Subnet (Target : IPv4) return Boolean is
   begin
      for I in 0 .. 3 loop
         if (Target (I) and Mask (I)) /= (Addr (I) and Mask (I)) then
            return False;
         end if;
      end loop;
      return True;
   end On_Subnet;

   --  ----------------------------------------------------------------------
   --  Received-frame ring.  Push runs in the Wi-Fi task; Pop in the owner.
   --  ----------------------------------------------------------------------
   Ring_Size : constant := 6;
   type Frame_Buf is record
      Len  : Natural := 0;
      Data : Byte_Array (0 .. Max_Frame - 1) := (others => 0);
   end record;
   type Frame_Ring is array (0 .. Ring_Size - 1) of Frame_Buf;

   protected Rx_Ring is
      procedure Push (Src : System.Address; Len : Natural);
      procedure Pop  (Buf : out Frame_Buf; Got : out Boolean);
   private
      Bufs  : Frame_Ring;
      Head  : Natural := 0;
      Tail  : Natural := 0;
      Count : Natural := 0;
   end Rx_Ring;

   protected body Rx_Ring is
      procedure Push (Src : System.Address; Len : Natural) is
         N : constant Natural := Natural'Min (Len, Max_Frame);
         S : Byte_Array (0 .. N - 1) with Import, Address => Src;
      begin
         if Count < Ring_Size then
            Bufs (Tail).Len := N;
            Bufs (Tail).Data (0 .. N - 1) := S;
            Tail  := (Tail + 1) mod Ring_Size;
            Count := Count + 1;
         end if;   --  else: ring full, drop the frame
      end Push;

      procedure Pop (Buf : out Frame_Buf; Got : out Boolean) is
      begin
         if Count = 0 then
            Got := False;
         else
            Buf   := Bufs (Head);
            Head  := (Head + 1) mod Ring_Size;
            Count := Count - 1;
            Got   := True;
         end if;
      end Pop;
   end Rx_Ring;

   Rx_Count, Tx_Count, Drop_Count : Natural := 0;
   function Rx_Frames return Natural is (Rx_Count);
   function Tx_Frames return Natural is (Tx_Count);
   function Drop_Frames return Natural is (Drop_Count);

   --  The frame sink handed to the driver (Wi-Fi-task context): just enqueue.
   procedure Ingest (Data : System.Address; Len : Natural) is
   begin
      Rx_Count := Rx_Count + 1;
      Rx_Ring.Push (Data, Len);
   end Ingest;

   --  ----------------------------------------------------------------------
   --  ARP: a tiny cache plus request/reply.
   --  ----------------------------------------------------------------------
   type Arp_Entry is record
      IP    : IPv4    := Any_IP;
      HW    : MAC     := (others => 0);
      Valid : Boolean := False;
   end record;
   Arp_Cache : array (0 .. 3) of Arp_Entry;

   procedure Arp_Learn (IP : IPv4; HW : MAC) is
      Free : Integer := -1;
   begin
      for I in Arp_Cache'Range loop
         if Arp_Cache (I).Valid and then Arp_Cache (I).IP = IP then
            Arp_Cache (I).HW := HW;
            return;
         elsif not Arp_Cache (I).Valid and then Free < 0 then
            Free := I;
         end if;
      end loop;
      if Free < 0 then
         Free := Arp_Cache'First;   --  no room: evict the first
      end if;
      Arp_Cache (Free) := (IP => IP, HW => HW, Valid => True);
   end Arp_Learn;

   function Arp_Lookup (IP : IPv4; HW : out MAC) return Boolean is
   begin
      for E of Arp_Cache loop
         if E.Valid and then E.IP = IP then
            HW := E.HW;
            return True;
         end if;
      end loop;
      return False;
   end Arp_Lookup;

   --  Send one 802.3 frame: [dst][src=our][ethertype][payload].
   procedure Send_Eth (Dst : MAC; Ether : U16; Payload : Byte_Array) is
      Frame : Byte_Array (0 .. 13 + Payload'Length);
   begin
      Frame (0 .. 5)  := Byte_Array (Dst);
      Frame (6 .. 11) := Byte_Array (Our_MAC);
      Put16 (Frame, 12, Ether);
      Frame (14 .. 13 + Payload'Length) := Payload;
      declare
         Ok : constant Boolean :=
           Send_Frame (Frame'Address, Frame'Length);
      begin
         if Ok then
            Tx_Count := Tx_Count + 1;
         end if;
      end;
   end Send_Eth;

   procedure Send_Arp (Oper : U16; Target_IP : IPv4; Target_HW : MAC;
                       Dst : MAC) is
      P : Byte_Array (0 .. 27) := (others => 0);
   begin
      Put16 (P, 0, 16#0001#);        --  htype = Ethernet
      Put16 (P, 2, ET_IPV4);         --  ptype = IPv4
      P (4) := 6;                    --  hlen
      P (5) := 4;                    --  plen
      Put16 (P, 6, Oper);            --  1 = request, 2 = reply
      P (8 .. 13)  := Byte_Array (Our_MAC);
      P (14 .. 17) := Byte_Array (Addr);
      P (18 .. 23) := Byte_Array (Target_HW);
      P (24 .. 27) := Byte_Array (Target_IP);
      Send_Eth (Dst, ET_ARP, P);
   end Send_Arp;

   procedure Handle_Arp (P : Byte_Array) is
      --  P is a slice of the received frame, so index relative to P'First.  An
      --  absolute-offset read faulted on every real ARP reply once RX worked.
      First : constant Natural := P'First;
      Oper  : constant U16  := Get16 (P, First + 6);
      SPA   : constant IPv4 := IPv4 (P (First + 14 .. First + 17));
      SHA   : constant MAC  := MAC (P (First + 8 .. First + 13));
      TPA   : constant IPv4 := IPv4 (P (First + 24 .. First + 27));
   begin
      Arp_Learn (SPA, SHA);
      if Oper = 1 and then TPA = Addr and then Configured then
         Send_Arp (Oper => 2, Target_IP => SPA, Target_HW => SHA, Dst => SHA);
      end if;
   end Handle_Arp;

   --  Resolve an IP to a MAC (blocking briefly on the ARP reply).
   function Resolve (Target : IPv4; HW : out MAC) return Boolean is
      Deadline : Time;
   begin
      if Arp_Lookup (Target, HW) then
         return True;
      end if;
      for Attempt in 1 .. 3 loop
         Send_Arp (Oper => 1, Target_IP => Target,
                   Target_HW => (others => 0), Dst => Bcast_MAC);
         Deadline := Clock + Milliseconds (300);
         loop
            Poll;
            if Arp_Lookup (Target, HW) then
               return True;
            end if;
            exit when Clock >= Deadline;
            delay until Clock + Milliseconds (5);
         end loop;
      end loop;
      return False;
   end Resolve;

   --  ----------------------------------------------------------------------
   --  UDP sockets.
   --  ----------------------------------------------------------------------
   Max_DGram : constant := 768;
   Queue_Len : constant := 2;
   type Datagram is record
      From      : IPv4    := Any_IP;
      From_Port : U16     := 0;
      Len       : Natural := 0;
      Data      : Byte_Array (0 .. Max_DGram - 1) := (others => 0);
   end record;
   type DGram_Queue is array (0 .. Queue_Len - 1) of Datagram;

   type Socket_State is record
      Open  : Boolean := False;
      Port  : U16     := 0;
      Q     : DGram_Queue;
      Head  : Natural := 0;
      Tail  : Natural := 0;
      Count : Natural := 0;
   end record;
   Socks : array (Socket_Id) of Socket_State;

   Ephemeral : U16 := 49152;

   function Bound_Port (Id : Socket_Id) return U16 is
     (if Socks (Id).Open then Socks (Id).Port else 0);

   procedure Open (Id : Socket_Id; Local_Port : U16; Ok : out Boolean) is
   begin
      if Socks (Id).Open then
         Ok := False;
         return;
      end if;
      Socks (Id) := (Open => True, others => <>);
      if Local_Port = 0 then
         Socks (Id).Port := Ephemeral;
         Ephemeral := (if Ephemeral >= 65_000 then 49152 else Ephemeral + 1);
      else
         Socks (Id).Port := Local_Port;
      end if;
      Ok := True;
   end Open;

   procedure Close (Id : Socket_Id) is
   begin
      Socks (Id).Open := False;
      Socks (Id).Count := 0;
   end Close;

   procedure Enqueue (Id : Socket_Id; From : IPv4; From_Port : U16;
                      Payload : Byte_Array) is
      N : constant Natural := Natural'Min (Payload'Length, Max_DGram);
      S : Socket_State renames Socks (Id);
   begin
      if S.Count >= Queue_Len then
         return;   --  queue full: drop
      end if;
      S.Q (S.Tail).From      := From;
      S.Q (S.Tail).From_Port := From_Port;
      S.Q (S.Tail).Len       := N;
      S.Q (S.Tail).Data (0 .. N - 1) := Payload (Payload'First .. Payload'First + N - 1);
      S.Tail  := (S.Tail + 1) mod Queue_Len;
      S.Count := S.Count + 1;
   end Enqueue;

   procedure Handle_Udp (Src_IP, Dst_IP : IPv4; Seg : Byte_Array) is
      Src_Port : constant U16 := Get16 (Seg, Seg'First);
      Dst_Port : constant U16 := Get16 (Seg, Seg'First + 2);
      Payload  : Byte_Array renames Seg (Seg'First + 8 .. Seg'Last);
      pragma Unreferenced (Dst_IP);
   begin
      for Id in Socket_Id loop
         if Socks (Id).Open and then Socks (Id).Port = Dst_Port then
            Enqueue (Id, Src_IP, Src_Port, Payload);
            return;
         end if;
      end loop;
   end Handle_Udp;

   procedure Handle_Ip (P : Byte_Array) is
      IHL      : constant Natural := Natural (P (P'First) and 16#0F#) * 4;
      Proto    : constant Octet   := P (P'First + 9);
      Src      : constant IPv4    := IPv4 (P (P'First + 12 .. P'First + 15));
      Dst      : constant IPv4    := IPv4 (P (P'First + 16 .. P'First + 19));
      Tot_Len  : constant Natural := Natural (Get16 (P, P'First + 2));
   begin
      if (P (P'First) and 16#F0#) /= 16#40# then
         return;   --  not IPv4
      end if;
      --  Accept frames addressed to us or to the broadcast address.  While we
      --  are still unconfigured (no address yet) accept ANY destination: a DHCP
      --  OFFER/ACK is unicast to the not-yet-owned "yiaddr", and the socket-port
      --  demux below drops anything we did not bind.
      if Configured and then Dst /= Addr and then Dst /= Broadcast_IP then
         return;   --  not for us
      end if;
      if Proto = IP_UDP and then P'First + Tot_Len - 1 <= P'Last then
         Handle_Udp (Src, Dst, P (P'First + IHL .. P'First + Tot_Len - 1));
      elsif Proto = IP_TCP and then P'First + Tot_Len - 1 <= P'Last then
         Handle_Tcp (Src, Dst, P (P'First + IHL .. P'First + Tot_Len - 1));
      end if;
   end Handle_Ip;

   procedure Dispatch (Frame : Byte_Array) is
      Body_First : constant Natural := Frame'First + 14;
   begin
      --  Guard the header read BEFORE touching bytes 12/13: a runt frame
      --  (< 14 bytes) would otherwise fault in Get16.  A malformed/oversized
      --  decrypted frame must never propagate an exception out of Poll -- that
      --  would kill whatever task is draining the ring (see the handler below).
      if Frame'Length < 14 then
         return;
      end if;
      case U16'(Get16 (Frame, Frame'First + 12)) is
         when ET_ARP =>
            if Frame'Last - Body_First + 1 >= 28 then
               Handle_Arp (Frame (Body_First .. Body_First + 27));
            end if;
         when ET_IPV4 =>
            if Frame'Last - Body_First + 1 >= 20 then
               Handle_Ip (Frame (Body_First .. Frame'Last));
            end if;
         when others =>
            null;
      end case;
   exception
      when others =>
         --  A malformed frame must never escape Poll and kill the draining
         --  task; drop it and count it.
         Drop_Count := Drop_Count + 1;
   end Dispatch;

   Work : Frame_Buf;   --  env-task scratch for the popped frame

   procedure Poll is
      Got : Boolean;
   begin
      --  Process at most one ring's worth of frames per call.  On a busy link
      --  the Wi-Fi-task ISR (Ingest -> Push) runs at higher priority and can
      --  refill the ring faster than we drain it; an unbounded drain then never
      --  returns (livelock).  Bounding the batch lets callers re-check their own
      --  deadlines between polls.
      for I in 1 .. Ring_Size loop
         Rx_Ring.Pop (Work, Got);
         exit when not Got;
         Dispatch (Work.Data (0 .. Work.Len - 1));
      end loop;
      TCP_Tick;   --  drive TCP retransmit timers
   end Poll;

   --  Send one IPv4 packet carrying Payload (an L4 segment): resolve the next
   --  hop (broadcast, on-subnet directly, else via the gateway), prepend the
   --  20-byte IPv4 header, and hand the frame to the link.  Shared by UDP and
   --  TCP.  Ok is False when the next hop cannot be resolved.
   procedure Send_IP (Proto : Octet; Dest : IPv4; Payload : Byte_Array;
                      Ok : out Boolean) is
      Next_Hop : MAC;
      IP_Len   : constant Natural := 20 + Payload'Length;
      Pkt      : Byte_Array (0 .. IP_Len - 1) := (others => 0);
   begin
      Ok := False;
      if Dest = Broadcast_IP then
         Next_Hop := Bcast_MAC;
      elsif On_Subnet (Dest) then
         if not Resolve (Dest, Next_Hop) then
            return;
         end if;
      else
         if not Resolve (Gw, Next_Hop) then
            return;
         end if;
      end if;

      Pkt (0)  := 16#45#;               --  version 4, IHL 5
      Put16 (Pkt, 2, U16 (IP_Len));     --  total length
      Pkt (8)  := 64;                   --  TTL
      Pkt (9)  := Proto;
      Pkt (12 .. 15) := Byte_Array (Addr);
      Pkt (16 .. 19) := Byte_Array (Dest);
      Put16 (Pkt, 10, Checksum (Pkt (0 .. 19)));
      Pkt (20 .. Pkt'Last) := Payload;

      Send_Eth (Next_Hop, ET_IPV4, Pkt);
      Ok := True;
   end Send_IP;

   procedure Send_To (Id : Socket_Id; Dest : IPv4; Dest_Port : U16;
                      Data : Byte_Array; Ok : out Boolean) is
      Seg : Byte_Array (0 .. 8 + Data'Length - 1) := (others => 0);
   begin
      Ok := False;
      if not Socks (Id).Open then
         return;
      end if;
      --  UDP header (8 bytes) + payload; checksum 0 = disabled (legal on IPv4).
      Put16 (Seg, 0, Socks (Id).Port);
      Put16 (Seg, 2, Dest_Port);
      Put16 (Seg, 4, U16 (8 + Data'Length));
      Seg (8 .. Seg'Last) := Data;
      Send_IP (IP_UDP, Dest, Seg, Ok);
   end Send_To;

   procedure Receive_From (Id : Socket_Id; From : out IPv4; From_Port : out U16;
                           Into : out Byte_Array; Count : out Natural) is
      S : Socket_State renames Socks (Id);
   begin
      From := Any_IP;
      From_Port := 0;
      Count := 0;
      if not S.Open or else S.Count = 0 then
         return;
      end if;
      declare
         D : Datagram renames S.Q (S.Head);
         N : constant Natural := Natural'Min (D.Len, Into'Length);
      begin
         From := D.From;
         From_Port := D.From_Port;
         Into (Into'First .. Into'First + N - 1) := D.Data (0 .. N - 1);
         Count := N;
      end;
      S.Head  := (S.Head + 1) mod Queue_Len;
      S.Count := S.Count - 1;
   end Receive_From;

   --  ----------------------------------------------------------------------
   --  TCP: a minimal client-side stack (active open, stop-and-wait send with
   --  retransmission, in-order receive, active/passive close).  No congestion
   --  control and no out-of-order reassembly -- an out-of-order segment is
   --  dropped and re-requested by re-ACKing rcv_nxt.  Enough for HTTP/TLS over
   --  a LAN, not a general-purpose stack.
   --  ----------------------------------------------------------------------
   TH_FIN : constant Octet := 16#01#;
   TH_SYN : constant Octet := 16#02#;
   TH_RST : constant Octet := 16#04#;
   TH_ACK : constant Octet := 16#10#;

   TCP_MSS    : constant := 536;     --  our send segment cap (safe, no PMTUD)
   TCP_RXBuf  : constant := 2048;    --  per-connection receive buffer
   TCP_RTO    : constant Time_Span := Milliseconds (600);
   TCP_Max_Retries : constant := 8;

   Empty : constant Byte_Array (1 .. 0) := (others => 0);

   type TCP_State is
     (Closed, Syn_Sent, Established, Fin_Wait_1, Fin_Wait_2, Closing,
      Time_Wait, Close_Wait, Last_Ack);

   type TCP_Conn is record
      In_Use     : Boolean := False;
      State      : TCP_State := Closed;
      Local_Port : U16 := 0;
      Peer_IP    : IPv4 := Any_IP;
      Peer_Port  : U16 := 0;
      Snd_Una    : Unsigned_32 := 0;   --  oldest unacknowledged send seq
      Snd_Nxt    : Unsigned_32 := 0;   --  next send seq
      Rcv_Nxt    : Unsigned_32 := 0;   --  next expected receive seq
      Reset      : Boolean := False;   --  RST received (aborted/refused)
      Peer_Fin   : Boolean := False;   --  FIN received
      Want_Close : Boolean := False;   --  app asked to close; FIN once send idle
      --  In-order receive buffer (a byte ring).
      Rx         : Byte_Array (0 .. TCP_RXBuf - 1) := (others => 0);
      Rx_Head    : Natural := 0;
      Rx_Len     : Natural := 0;
      --  The single outstanding (retransmittable) segment.  Ctrl = 1 when a SYN
      --  or FIN on it occupies one sequence number.
      Rt_Pending : Boolean := False;
      Rt_Flags   : Octet := 0;
      Rt_Seq     : Unsigned_32 := 0;
      Rt_Len     : Natural := 0;
      Rt_Ctrl    : Natural := 0;
      Rt_MSS     : Boolean := False;   --  include the MSS option (SYN only)
      Rt_Data    : Byte_Array (0 .. TCP_MSS - 1) := (others => 0);
      Rt_Deadline : Time := Time_First;
      Rt_Tries   : Natural := 0;
   end record;
   TCPs : array (Socket_Id) of TCP_Conn;

   --  Sequence comparison with 32-bit wraparound (RFC 793 "modulo" order).
   function Seq_GE (A, B : Unsigned_32) return Boolean is
     ((A - B and 16#8000_0000#) = 0);

   ISS_Counter : Unsigned_32 := 16#1000#;
   ISS_Seeded  : Boolean := False;

   function Next_ISS return Unsigned_32 is
   begin
      if not ISS_Seeded then
         ISS_Seeded := True;
         ISS_Counter :=
           Unsigned_32 (Long_Long_Integer
             (To_Duration (Clock - Time_First) * 1_000_000) mod 2 ** 32);
      end if;
      ISS_Counter := ISS_Counter + 16#4000#;
      return ISS_Counter;
   end Next_ISS;

   --  Build and transmit one TCP segment.  The advertised window is the room
   --  left in the receive buffer, so the peer never overruns us.
   procedure Emit (C : in out TCP_Conn; Flags : Octet; Seq, Ack : Unsigned_32;
                   Data : Byte_Array; With_MSS : Boolean) is
      Opt_Len : constant Natural := (if With_MSS then 4 else 0);
      Hdr_Len : constant Natural := 20 + Opt_Len;
      Seg     : Byte_Array (0 .. Hdr_Len + Data'Length - 1) := (others => 0);
      Ok      : Boolean;
   begin
      Put16 (Seg, 0, C.Local_Port);
      Put16 (Seg, 2, C.Peer_Port);
      Put32 (Seg, 4, Seq);
      Put32 (Seg, 8, Ack);
      Seg (12) := Octet (Shift_Left (Unsigned_32 (Hdr_Len / 4), 4));
      Seg (13) := Flags;
      Put16 (Seg, 14, U16 (TCP_RXBuf - C.Rx_Len));   --  advertised window
      if With_MSS then
         Seg (20) := 2;                --  option kind 2 = MSS
         Seg (21) := 4;                --  option length
         Put16 (Seg, 22, U16 (TCP_MSS));
      end if;
      Seg (Hdr_Len .. Seg'Last) := Data;
      Put16 (Seg, 16, L4_Checksum (Addr, C.Peer_IP, IP_TCP, Seg));
      Send_IP (IP_TCP, C.Peer_IP, Seg, Ok);
   end Emit;

   --  Send a segment that must be acknowledged, recording it for retransmit.
   procedure Emit_Reliable (C : in out TCP_Conn; Flags : Octet; Seq : Unsigned_32;
                            Data : Byte_Array; With_MSS : Boolean; Ctrl : Natural)
   is
   begin
      C.Rt_Pending  := True;
      C.Rt_Flags    := Flags;
      C.Rt_Seq      := Seq;
      C.Rt_Len      := Data'Length;
      C.Rt_Ctrl     := Ctrl;
      C.Rt_MSS      := With_MSS;
      C.Rt_Data (0 .. Data'Length - 1) := Data;
      C.Rt_Tries    := 0;
      C.Rt_Deadline := Clock + TCP_RTO;
      Emit (C, Flags, Seq, C.Rcv_Nxt, Data, With_MSS);
   end Emit_Reliable;

   --  Copy in-order stream bytes into the receive ring, advancing rcv_nxt only
   --  by what fits (the shrinking window makes the peer hold the rest).
   procedure Deliver (C : in out TCP_Conn; Data : Byte_Array) is
      N : constant Natural := Natural'Min (Data'Length, TCP_RXBuf - C.Rx_Len);
   begin
      for K in 0 .. N - 1 loop
         C.Rx ((C.Rx_Head + C.Rx_Len + K) mod TCP_RXBuf) := Data (Data'First + K);
      end loop;
      C.Rx_Len := C.Rx_Len + N;
      C.Rcv_Nxt := C.Rcv_Nxt + Unsigned_32 (N);
   end Deliver;

   --  If all queued data is acknowledged and the app asked to close, send FIN.
   procedure Maybe_Send_Fin (C : in out TCP_Conn) is
   begin
      if C.Want_Close and then not C.Rt_Pending
        and then C.State in Established | Close_Wait
      then
         Emit_Reliable (C, TH_FIN or TH_ACK, C.Snd_Nxt, Empty, False, 1);
         C.Snd_Nxt := C.Snd_Nxt + 1;
         C.State := (if C.State = Established then Fin_Wait_1 else Last_Ack);
      end if;
   end Maybe_Send_Fin;

   procedure Process (C : in out TCP_Conn; Flags : Octet; Seq, Ack : Unsigned_32;
                      Data : Byte_Array) is
      Fin     : constant Boolean := (Flags and TH_FIN) /= 0;
      Syn     : constant Boolean := (Flags and TH_SYN) /= 0;
      Has_Ack : constant Boolean := (Flags and TH_ACK) /= 0;
      Advanced : Boolean := False;
   begin
      if (Flags and TH_RST) /= 0 then
         C.Reset := True;
         C.State := Closed;
         C.Rt_Pending := False;
         return;
      end if;

      --  Retire acknowledged send data.
      if Has_Ack and then Seq_GE (Ack, C.Snd_Una)
        and then Seq_GE (C.Snd_Nxt, Ack)
      then
         C.Snd_Una := Ack;
         if C.Rt_Pending
           and then Seq_GE (C.Snd_Una,
                            C.Rt_Seq + Unsigned_32 (C.Rt_Len + C.Rt_Ctrl))
         then
            C.Rt_Pending := False;
         end if;
      end if;

      if C.State = Syn_Sent then
         if Syn and then Has_Ack and then C.Snd_Una = C.Snd_Nxt then
            C.Rcv_Nxt := Seq + 1;               --  their ISS + 1
            C.State := Established;
            Emit (C, TH_ACK, C.Snd_Nxt, C.Rcv_Nxt, Empty, False);
         end if;
         return;
      end if;

      --  Established and the closing states: accept in-order data and FIN.
      if Data'Length > 0 and then Seq = C.Rcv_Nxt
        and then C.State in Established | Fin_Wait_1 | Fin_Wait_2
      then
         Deliver (C, Data);
         Advanced := True;
      end if;
      if Fin and then Seq + Unsigned_32 (Data'Length) = C.Rcv_Nxt then
         C.Rcv_Nxt := C.Rcv_Nxt + 1;            --  FIN takes one sequence
         C.Peer_Fin := True;
         Advanced := True;
         case C.State is
            when Established => C.State := Close_Wait;
            when Fin_Wait_1  => C.State := Closing;
            when Fin_Wait_2  => C.State := Time_Wait;
            when others      => null;
         end case;
      end if;
      if Advanced then
         Emit (C, TH_ACK, C.Snd_Nxt, C.Rcv_Nxt, Empty, False);
      end if;

      --  Our own FIN now acknowledged: advance the close handshake.
      if not C.Rt_Pending then
         case C.State is
            when Fin_Wait_1 => C.State := Fin_Wait_2;
            when Closing    => C.State := Time_Wait;
            when Last_Ack   => C.State := Closed;
            when others     => null;
         end case;
      end if;
      if C.State = Time_Wait then
         C.State := Closed;                      --  no 2*MSL wait for a client
      end if;
      Maybe_Send_Fin (C);
   end Process;

   procedure Handle_Tcp (Src, Dst : IPv4; Seg : Byte_Array) is
      F        : constant Natural := Seg'First;
   begin
      if Seg'Length < 20 then
         return;
      end if;
      declare
         Dst_Port : constant U16 := Get16 (Seg, F + 2);
         Src_Port : constant U16 := Get16 (Seg, F);
         Seq      : constant Unsigned_32 := Get32 (Seg, F + 4);
         Ack      : constant Unsigned_32 := Get32 (Seg, F + 8);
         Data_Off : constant Natural := Natural (Shift_Right (Seg (F + 12), 4)) * 4;
         Flags    : constant Octet := Seg (F + 13);
      begin
         if Data_Off < 20 or else F + Data_Off > Seg'Last + 1 then
            return;                               --  malformed header length
         end if;
         if L4_Checksum (Src, Dst, IP_TCP, Seg) /= 0 then
            return;                               --  bad checksum
         end if;
         for Id in Socket_Id loop
            declare
               C : TCP_Conn renames TCPs (Id);
            begin
               if C.In_Use and then C.Local_Port = Dst_Port
                 and then C.Peer_Port = Src_Port and then C.Peer_IP = Src
               then
                  Process (C, Flags, Seq, Ack, Seg (F + Data_Off .. Seg'Last));
                  return;
               end if;
            end;
         end loop;
      end;
   end Handle_Tcp;

   procedure TCP_Tick is
      Now : constant Time := Clock;
   begin
      for Id in Socket_Id loop
         declare
            C : TCP_Conn renames TCPs (Id);
         begin
            if C.In_Use and then C.Rt_Pending and then Now >= C.Rt_Deadline then
               if C.Rt_Tries >= TCP_Max_Retries then
                  C.Reset := True;               --  give up: treat as aborted
                  C.State := Closed;
                  C.Rt_Pending := False;
               else
                  C.Rt_Tries := C.Rt_Tries + 1;
                  C.Rt_Deadline := Now + TCP_RTO;
                  Emit (C, C.Rt_Flags, C.Rt_Seq, C.Rcv_Nxt,
                        C.Rt_Data (0 .. C.Rt_Len - 1), C.Rt_MSS);
               end if;
            end if;
         end;
      end loop;
   end TCP_Tick;

   --  --- TCP public API ----------------------------------------------------
   procedure TCP_Open (Id : Socket_Id; Local_Port : U16; Ok : out Boolean) is
      C : TCP_Conn renames TCPs (Id);
   begin
      if C.In_Use then
         Ok := False;
         return;
      end if;
      C := (In_Use => True, Local_Port =>
              (if Local_Port = 0 then Ephemeral else Local_Port), others => <>);
      if Local_Port = 0 then
         Ephemeral := (if Ephemeral >= 65_000 then 49152 else Ephemeral + 1);
      end if;
      Ok := True;
   end TCP_Open;

   procedure TCP_Connect (Id : Socket_Id; Dest : IPv4; Dest_Port : U16;
                          Ok : out Boolean) is
      C   : TCP_Conn renames TCPs (Id);
      ISS : constant Unsigned_32 := Next_ISS;
   begin
      Ok := False;
      if not C.In_Use then
         return;
      end if;
      C.Peer_IP := Dest;
      C.Peer_Port := Dest_Port;
      C.Snd_Una := ISS;
      C.Snd_Nxt := ISS + 1;                       --  SYN consumes one seq
      C.Rcv_Nxt := 0;
      C.Reset := False;
      C.Peer_Fin := False;
      C.State := Syn_Sent;
      Emit_Reliable (C, TH_SYN, ISS, Empty, With_MSS => True, Ctrl => 1);
      Ok := True;
   end TCP_Connect;

   function TCP_Is_Open (Id : Socket_Id) return Boolean is (TCPs (Id).In_Use);

   function TCP_Connected (Id : Socket_Id) return Boolean is
     (TCPs (Id).State in Established | Close_Wait);

   function TCP_Failed (Id : Socket_Id) return Boolean is (TCPs (Id).Reset);

   procedure TCP_Send (Id : Socket_Id; Data : Byte_Array; Sent : out Natural) is
      C : TCP_Conn renames TCPs (Id);
      N : Natural;
   begin
      Sent := 0;
      if C.State /= Established or else C.Rt_Pending then
         return;                                  --  not ready / segment in flight
      end if;
      N := Natural'Min (Data'Length, TCP_MSS);
      if N = 0 then
         return;
      end if;
      Emit_Reliable (C, TH_ACK, C.Snd_Nxt, Data (Data'First .. Data'First + N - 1),
                     With_MSS => False, Ctrl => 0);
      C.Snd_Nxt := C.Snd_Nxt + Unsigned_32 (N);
      Sent := N;
   end TCP_Send;

   function TCP_Send_Idle (Id : Socket_Id) return Boolean is
     (not TCPs (Id).Rt_Pending);

   function TCP_Available (Id : Socket_Id) return Natural is (TCPs (Id).Rx_Len);

   procedure TCP_Receive (Id : Socket_Id; Into : out Byte_Array;
                          Count : out Natural) is
      C : TCP_Conn renames TCPs (Id);
      N : constant Natural := Natural'Min (Into'Length, C.Rx_Len);
   begin
      for K in 0 .. N - 1 loop
         Into (Into'First + K) := C.Rx ((C.Rx_Head + K) mod TCP_RXBuf);
      end loop;
      C.Rx_Head := (C.Rx_Head + N) mod TCP_RXBuf;
      C.Rx_Len := C.Rx_Len - N;
      Count := N;
      --  Freed receive room: nudge the peer with a window update.
      if N > 0 and then C.State in Established | Fin_Wait_1 | Fin_Wait_2 then
         Emit (C, TH_ACK, C.Snd_Nxt, C.Rcv_Nxt, Empty, False);
      end if;
   end TCP_Receive;

   function TCP_Peer_Closed (Id : Socket_Id) return Boolean is
     (TCPs (Id).Peer_Fin);

   procedure TCP_Peer (Id : Socket_Id; Addr : out IPv4; Port : out U16) is
   begin
      Addr := TCPs (Id).Peer_IP;
      Port := TCPs (Id).Peer_Port;
   end TCP_Peer;

   procedure TCP_Close (Id : Socket_Id) is
      C : TCP_Conn renames TCPs (Id);
   begin
      C.Want_Close := True;
      Maybe_Send_Fin (C);
      if C.State in Closed | Syn_Sent then
         C.In_Use := False;                        --  nothing established to close
         C.State := Closed;
      end if;
   end TCP_Close;

   procedure Start is
      M : constant ESP32S3.MAC.MAC_Address := ESP32S3.MAC.Wi_Fi_Station;
   begin
      for I in 0 .. 5 loop
         Our_MAC (I) := M (I);
      end loop;
      Set_Frame_Handler (Ingest'Access);
      --  The connection setup can leave the low-level RX callback unset; hook it
      --  now that the link is up so data frames flow into the sink.
      Start_Data_Path;
   end Start;

end ESP32S3.WiFi.IP;
