with Interfaces;    use Interfaces;
with Ada.Real_Time; use Ada.Real_Time;
with ESP32S3.Endian;

package body ESP32S3.W5500.Sockets is

   --  Socket-block register offsets (BSB = Socket_Regs (Index)).
   Sn_MR     : constant Unsigned_16 := 16#00#;
   Sn_CR     : constant Unsigned_16 := 16#01#;
   Sn_IR     : constant Unsigned_16 := 16#02#;
   Sn_SR     : constant Unsigned_16 := 16#03#;
   Sn_PORT   : constant Unsigned_16 := 16#04#;
   Sn_DIPR   : constant Unsigned_16 := 16#0C#;
   Sn_DPORT  : constant Unsigned_16 := 16#10#;
   Sn_TX_FSR : constant Unsigned_16 := 16#20#;
   Sn_TX_WR  : constant Unsigned_16 := 16#24#;
   Sn_RX_RSR : constant Unsigned_16 := 16#26#;
   Sn_RX_RD  : constant Unsigned_16 := 16#28#;

   --  Sn_MR protocol.
   MR_TCP : constant Byte := 16#01#;
   MR_UDP : constant Byte := 16#02#;

   --  Sn_CR commands.
   Cmd_Open    : constant Byte := 16#01#;
   Cmd_Listen  : constant Byte := 16#02#;
   Cmd_Connect : constant Byte := 16#04#;
   Cmd_Discon  : constant Byte := 16#08#;
   Cmd_Close   : constant Byte := 16#10#;
   Cmd_Send    : constant Byte := 16#20#;
   Cmd_Recv    : constant Byte := 16#40#;

   --  Sn_IR flags (write 1 to clear).
   IR_CON     : constant Byte := 16#01#;
   IR_DISCON  : constant Byte := 16#02#;
   IR_RECV    : constant Byte := 16#04#;
   IR_TIMEOUT : constant Byte := 16#08#;
   IR_SEND_OK : constant Byte := 16#10#;

   --  Sn_SR status values.
   SR_CLOSED      : constant Byte := 16#00#;
   SR_INIT        : constant Byte := 16#13#;
   SR_LISTEN      : constant Byte := 16#14#;
   SR_ESTABLISHED : constant Byte := 16#17#;
   SR_CLOSE_WAIT  : constant Byte := 16#1C#;
   SR_UDP         : constant Byte := 16#22#;

   ---------------------------------------------------------------------------
   --  Register helpers (one socket's register block)
   ---------------------------------------------------------------------------

   function R8 (S : Socket; A : Unsigned_16) return Byte
   is (Read_U8 (S.Dev.all, Socket_Regs (S.Index), A));

   procedure W8 (S : Socket; A : Unsigned_16; V : Byte) is
   begin
      Write_U8 (S.Dev.all, Socket_Regs (S.Index), A, V);
   end W8;

   function R16 (S : Socket; A : Unsigned_16) return Unsigned_16
   is (Read_U16 (S.Dev.all, Socket_Regs (S.Index), A));

   procedure W16 (S : Socket; A : Unsigned_16; V : Unsigned_16) is
   begin
      Write_U16 (S.Dev.all, Socket_Regs (S.Index), A, V);
   end W16;

   --  A 16-bit pointer/size register can change between its two byte reads, so
   --  read until two reads agree (datasheet recommendation for FSR/RSR).
   function R16_Stable (S : Socket; A : Unsigned_16) return Unsigned_16 is
      First_Read  : Unsigned_16 := R16 (S, A);
      Second_Read : Unsigned_16;
   begin
      loop
         Second_Read := R16 (S, A);
         exit when First_Read = Second_Read;
         First_Read := Second_Read;
      end loop;
      return First_Read;
   end R16_Stable;

   --  Issue a command and wait until the chip accepts it (Sn_CR self-clears).
   procedure Issue (S : Socket; Command : Byte) is
   begin
      W8 (S, Sn_CR, Command);
      for Tries in 1 .. 2000 loop
         exit when R8 (S, Sn_CR) = 0;
         delay until Clock + Microseconds (50);
      end loop;
   end Issue;

   --  Optional INTn waiter (registered via Set_Event_Waiter); null => poll.
   Waiter : Event_Waiter := null;

   procedure Set_Event_Waiter (W : Event_Waiter) is
   begin
      Waiter := W;
   end Set_Event_Waiter;

   --  The single point the blocking waits funnel through: sleep on INTn for this
   --  socket if a waiter is registered (the interrupts child), else poll.
   procedure Wait_Event (S : Socket) is
   begin
      if Waiter /= null then
         Waiter (S.Index);
      else
         delay until Clock + Milliseconds (1);
      end if;
   end Wait_Event;

   ---------------------------------------------------------------------------
   --  Open / close
   ---------------------------------------------------------------------------

   procedure Open_TCP
     (Dev        : Device_Access;
      S          : in out Socket;
      Index      : Socket_Id;
      Local_Port : Port_Number;
      Result     : out Status) is
   begin
      S.Dev := Dev;
      S.Index := Index;
      S.Proto := TCP_Proto;
      S.Is_Open := False;
      Issue (S, Cmd_Close);
      W8 (S, Sn_MR, MR_TCP);
      W16 (S, Sn_PORT, Local_Port);
      Issue (S, Cmd_Open);
      if R8 (S, Sn_SR) = SR_INIT then
         S.Is_Open := True;
         Result := OK;
      else
         Result := Error;
      end if;
   end Open_TCP;

   procedure Open_UDP
     (Dev        : Device_Access;
      S          : in out Socket;
      Index      : Socket_Id;
      Local_Port : Port_Number;
      Result     : out Status) is
   begin
      S.Dev := Dev;
      S.Index := Index;
      S.Proto := UDP_Proto;
      S.Is_Open := False;
      Issue (S, Cmd_Close);
      W8 (S, Sn_MR, MR_UDP);
      W16 (S, Sn_PORT, Local_Port);
      Issue (S, Cmd_Open);
      if R8 (S, Sn_SR) = SR_UDP then
         S.Is_Open := True;
         Result := OK;
      else
         Result := Error;
      end if;
   end Open_UDP;

   procedure Close (S : in out Socket) is
   begin
      if S.Is_Open then
         --  Graceful active close for TCP: send FIN so the peer sees end-of-
         --  stream (e.g. an FTP server reading a STOR data connection until EOF,
         --  then replying 226).  An abrupt Cmd_Close sends no FIN, leaving the
         --  peer to block until its own timeout.  Then force-free the socket.
         if S.Proto = TCP_Proto then
            Issue (S, Cmd_Discon);
            for Tries in 1 .. 1000 loop
               --  best effort; ~1 RTT
               exit when R8 (S, Sn_SR) = SR_CLOSED;
               Wait_Event (S);
            end loop;
         end if;
         Issue (S, Cmd_Close);
      end if;
      S.Is_Open := False;
      S.Proto := None;
   end Close;

   ---------------------------------------------------------------------------
   --  TCP connection setup
   ---------------------------------------------------------------------------

   procedure Listen (S : in out Socket; Result : out Status) is
   begin
      if not S.Is_Open then
         Result := Not_Open;
         return;
      end if;
      Issue (S, Cmd_Listen);
      Result := (if R8 (S, Sn_SR) = SR_LISTEN then OK else Error);
   end Listen;

   procedure Connect
     (S       : in out Socket;
      Host    : IPv4_Address;
      Port    : Port_Number;
      Result  : out Status;
      Timeout : Duration := 10.0)
   is
      Deadline : constant Time := Clock + To_Time_Span (Timeout);
   begin
      if not S.Is_Open then
         Result := Not_Open;
         return;
      end if;
      Write (S.Dev.all, Socket_Regs (S.Index), Sn_DIPR, Host);
      W16 (S, Sn_DPORT, Port);
      W8 (S, Sn_IR, IR_CON or IR_DISCON or IR_TIMEOUT);   --  clear stale flags
      Issue (S, Cmd_Connect);
      loop
         declare
            SR : constant Byte := R8 (S, Sn_SR);   --  Sn_SR socket status
         begin
            if SR = SR_ESTABLISHED then
               Result := OK;
               return;
            elsif SR = SR_CLOSED then
               declare
                  IR : constant Byte := R8 (S, Sn_IR);   --  Sn_IR interrupt flags
               begin
                  W8 (S, Sn_IR, IR);                        --  clear
                  Result := (if (IR and IR_TIMEOUT) /= 0 then Timed_Out else Refused);
                  return;
               end;
            end if;
         end;
         exit when Clock >= Deadline;
         --  Poll the status with a bounded delay rather than Wait_Event.  When
         --  interrupts are armed Wait_Event blocks on INTn until the chip raises
         --  one; a connection that just hangs (SYN dropped, no response) never
         --  does, so the Deadline check above was unreachable and Connect blocked
         --  forever despite the Timeout.  A short poll makes the timeout real
         --  (connect is one-shot, so the ~5 ms tick cost is irrelevant), and a
         --  refused connection still returns immediately via the SR_CLOSED branch.
         delay until Clock + Milliseconds (5);
      end loop;
      Result := Timed_Out;
   end Connect;

   function State (S : Socket) return Socket_State is
   begin
      case R8 (S, Sn_SR) is
         when SR_CLOSED      =>
            return Closed;

         when SR_INIT        =>
            return Init;

         when SR_LISTEN      =>
            return Listening;

         when SR_ESTABLISHED =>
            return Established;

         when SR_CLOSE_WAIT  =>
            return Close_Wait;

         when SR_UDP         =>
            return Udp;

         when others         =>
            return Other;
      end case;
   end State;

   function Is_Established (S : Socket) return Boolean
   is (R8 (S, Sn_SR) = SR_ESTABLISHED);

   procedure Wait_Connected (S : in out Socket; Result : out Status) is
   begin
      if not S.Is_Open then
         Result := Not_Open;
         return;
      end if;
      loop
         case State (S) is
            when Established =>
               W8 (S, Sn_IR, IR_CON);    --  clear CON so INTn re-arms for data
               Result := OK;
               return;

            when Closed      =>
               Result := Error;
               return;   --  listen ended

            when others      =>
               Wait_Event (S);             --  Listening/transient
         end case;
      end loop;
   end Wait_Connected;

   procedure Set_Receive_Timeout (S : in out Socket; To : Duration) is
   begin
      S.Recv_Timeout := (if To < 0.0 then 0.0 else To);
   end Set_Receive_Timeout;

   procedure Wait_Data (S : in out Socket; Result : out Status) is
      Timed    : constant Boolean := S.Recv_Timeout > 0.0;
      Deadline : Time;
   begin
      if not S.Is_Open then
         Result := Not_Open;
         return;
      end if;
      if Timed then
         Deadline := Clock + To_Time_Span (S.Recv_Timeout);
      end if;
      loop
         if R16_Stable (S, Sn_RX_RSR) > 0 then
            Result := OK;
            return;
         end if;
         case State (S) is
            when Close_Wait | Closed =>
               Result := Closed_By_Peer;
               return;

            when others              =>
               null;
         end case;
         --  The INTn heartbeat re-signals every ~50 ms, so a Wait_Event sleeping
         --  on the interrupt still wakes in time to honour the deadline.
         if Timed and then Clock >= Deadline then
            Result := Timed_Out;
            return;
         end if;
         Wait_Event (S);
      end loop;
   end Wait_Data;

   procedure Disconnect (S : in out Socket) is
   begin
      if S.Is_Open and then S.Proto = TCP_Proto then
         Issue (S, Cmd_Discon);
         for Tries in 1 .. 1000 loop
            --  best-effort wait
            exit when R8 (S, Sn_SR) = SR_CLOSED;
            Wait_Event (S);
         end loop;
      end if;
      S.Is_Open := False;
      S.Proto := None;
   end Disconnect;

   ---------------------------------------------------------------------------
   --  TCP data transfer
   ---------------------------------------------------------------------------

   function Available (S : Socket) return Natural
   is (Natural (R16_Stable (S, Sn_RX_RSR)));

   --  Issue SEND and wait for SEND_OK (or TIMEOUT).  Returns False on timeout.
   function Flush_Send (S : Socket) return Boolean is
      Deadline : constant Time := Clock + Milliseconds (10_000);
   begin
      W8 (S, Sn_IR, IR_SEND_OK);                            --  clear stale SEND_OK
      Issue (S, Cmd_Send);
      loop
         declare
            IR : constant Byte := R8 (S, Sn_IR);   --  Sn_IR interrupt flags
         begin
            if (IR and IR_SEND_OK) /= 0 then
               W8 (S, Sn_IR, IR_SEND_OK);
               return True;
            elsif (IR and IR_TIMEOUT) /= 0 then
               W8 (S, Sn_IR, IR_TIMEOUT);
               return False;
            end if;
         end;
         --  A peer RST after Cmd_Send drops the socket to CLOSED and raises
         --  NEITHER SEND_OK nor TIMEOUT -- without these two exits the loop spun
         --  forever, wedging the sending task.  Match WIZnet's own send() loop:
         --  bail if the socket closed, and cap the total wait.
         if R8 (S, Sn_SR) = SR_CLOSED then
            return False;
         end if;
         exit when Clock >= Deadline;
         Wait_Event (S);
      end loop;
      return False;   --  deadline elapsed
   end Flush_Send;

   procedure Send (S : in out Socket; Data : Byte_Array; Sent : out Natural; Result : out Status)
   is
      Free     : Unsigned_16;
      WR       : Unsigned_16;   --  Sn_TX_WR write pointer
      Send_Len : Natural;
      Deadline : constant Time := Clock + Milliseconds (10_000);
   begin
      if not S.Is_Open then
         Sent := 0;
         Result := Not_Open;
         return;
      end if;
      if Data'Length = 0 then
         Sent := 0;              --  nothing to send; don't issue a 0-byte Cmd_Send
         Result := OK;
         return;
      end if;
      --  Wait for room in the TX buffer rather than giving up: on a SUSTAINED
      --  send the 2 KB socket buffer fills until the peer ACKs (and the peer
      --  drains it continuously), so block here -- TCP send flow control.  Give
      --  up only if the connection drops or a generous deadline elapses.  (The
      --  old "N = 0 => No_Space, return" made Send_All abandon any transfer
      --  larger than the socket buffer; native sockets never hit it.)
      loop
         Free := R16_Stable (S, Sn_TX_FSR);
         exit when Free > 0;
         case State (S) is
            when Established | Close_Wait =>
               null;        --  still connected

            when others                   =>
               Sent := 0;
               Result := Closed_By_Peer;
               return;
         end case;
         if Clock >= Deadline then
            Sent := 0;
            Result := Timed_Out;
            return;
         end if;
         Wait_Event (S);
      end loop;
      Send_Len := Natural'Min (Data'Length, Natural (Free));
      WR := R16 (S, Sn_TX_WR);
      Write (S.Dev.all, Socket_TX (S.Index), WR, Data (Data'First .. Data'First + Send_Len - 1));
      W16 (S, Sn_TX_WR, WR + Unsigned_16 (Send_Len));
      if Flush_Send (S) then
         Sent := Send_Len;
         Result := OK;
      else
         --  SEND was issued and Sn_TX_WR already advanced, so the Send_Len bytes are
         --  committed to the chip (in flight) even though completion did not
         --  confirm in time -- report them consumed so a retry can't double-send.
         Sent := Send_Len;
         Result := Timed_Out;
      end if;
   end Send;

   procedure Receive
     (S : in out Socket; Into : out Byte_Array; Count : out Natural; Result : out Status)
   is
      RSR      : Unsigned_16;   --  Sn_RX_RSR received size
      RD       : Unsigned_16;   --  Sn_RX_RD read pointer
      Recv_Len : Natural;
   begin
      if not S.Is_Open then
         Count := 0;
         Result := Not_Open;
         return;
      end if;
      RSR := R16_Stable (S, Sn_RX_RSR);
      if RSR = 0 then
         Count := 0;
         Result := (if R8 (S, Sn_SR) = SR_CLOSE_WAIT then Closed_By_Peer else OK);
         return;
      end if;
      Recv_Len := Natural'Min (Into'Length, Natural (RSR));
      RD := R16 (S, Sn_RX_RD);
      Read (S.Dev.all, Socket_RX (S.Index), RD, Into (Into'First .. Into'First + Recv_Len - 1));
      W16 (S, Sn_RX_RD, RD + Unsigned_16 (Recv_Len));
      Issue (S, Cmd_Recv);
      W8 (S, Sn_IR, IR_RECV);     --  clear RECV so INTn re-arms for the next data
      Count := Recv_Len;
      Result := OK;
   end Receive;

   ---------------------------------------------------------------------------
   --  UDP datagrams
   ---------------------------------------------------------------------------

   procedure Send_To
     (S      : in out Socket;
      Host   : IPv4_Address;
      Port   : Port_Number;
      Data   : Byte_Array;
      Result : out Status)
   is
      Free : Unsigned_16;
      WR   : Unsigned_16;   --  Sn_TX_WR write pointer
   begin
      if not S.Is_Open then
         Result := Not_Open;
         return;
      end if;
      Free := R16_Stable (S, Sn_TX_FSR);
      if Natural (Free) < Data'Length then
         --  a datagram is all-or-nothing
         Result := No_Space;
         return;
      end if;
      Write (S.Dev.all, Socket_Regs (S.Index), Sn_DIPR, Host);
      W16 (S, Sn_DPORT, Port);
      WR := R16 (S, Sn_TX_WR);
      Write (S.Dev.all, Socket_TX (S.Index), WR, Data);
      W16 (S, Sn_TX_WR, WR + Unsigned_16 (Data'Length));
      Result := (if Flush_Send (S) then OK else Timed_Out);
   end Send_To;

   procedure Receive_From
     (S         : in out Socket;
      From      : out IPv4_Address;
      From_Port : out Port_Number;
      Into      : out Byte_Array;
      Count     : out Natural;
      Result    : out Status)
   is
      RSR         : Unsigned_16;   --  Sn_RX_RSR received size
      RD          : Unsigned_16;   --  Sn_RX_RD read pointer
      Hdr         : Byte_Array (0 .. 7);
      Payload_Len : Natural;
      Copy_Len    : Natural;
   begin
      From := (0, 0, 0, 0);
      From_Port := 0;
      Count := 0;
      if not S.Is_Open then
         Result := Not_Open;
         return;
      end if;
      RSR := R16_Stable (S, Sn_RX_RSR);
      if RSR < 8 then
         --  no complete packet header
         Result := OK;
         return;
      end if;
      RD := R16 (S, Sn_RX_RD);
      Read (S.Dev.all, Socket_RX (S.Index), RD, Hdr);    --  IP(4) port(2) len(2)
      From := (Hdr (0), Hdr (1), Hdr (2), Hdr (3));
      From_Port := ESP32S3.Endian.Join_BE16 (Unsigned_8 (Hdr (4)), Unsigned_8 (Hdr (5)));
      Payload_Len :=
        Natural (ESP32S3.Endian.Join_BE16 (Unsigned_8 (Hdr (6)), Unsigned_8 (Hdr (7))));
      RD := RD + 8;
      Copy_Len := Natural'Min (Into'Length, Payload_Len);
      if Copy_Len > 0 then
         Read (S.Dev.all, Socket_RX (S.Index), RD, Into (Into'First .. Into'First + Copy_Len - 1));
      end if;
      RD := RD + Unsigned_16 (Payload_Len);          --  skip the whole datagram
      W16 (S, Sn_RX_RD, RD);
      Issue (S, Cmd_Recv);
      Count := Copy_Len;
      Result := OK;
   end Receive_From;

end ESP32S3.W5500.Sockets;
