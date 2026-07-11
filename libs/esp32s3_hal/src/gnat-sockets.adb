with Interfaces;
with Ada.Real_Time;
with Ada.Streams; use Ada.Streams;
with Net_Devices;
with Net_Routes;

package body GNAT.Sockets is

   use type Net_Devices.Status;
   use type Net_Devices.Device_Access;
   use type Net_Devices.Interface_Id;
   use type Net_Devices.IPv4_Address;
   use type Interfaces.Unsigned_16;

   Max_Sockets : constant := 8;                 --  most any one interface provides
   subtype Sock_Index is Natural range 0 .. Max_Sockets - 1;

   --  Registered interfaces and the per-(interface, socket) state.
   Registry : array (Interface_Id) of Net_Devices.Device_Access := (others => null);
   N_Ifaces : Natural := 0;

   --  Liveness source for the routing table: is interface Id usable right now?
   --  Library-level + closure-free (bare-metal callback rules); reads the registry.
   function Iface_Is_Up (Id : Interface_Id) return Boolean
   is (Registry (Id) /= null and then Registry (Id).Is_Up);

   In_Use       : array (Interface_Id, Sock_Index) of Boolean := (others => (others => False));
   Local_Ports  : array (Interface_Id, Sock_Index) of Net_Devices.Port_Number :=
     (others => (others => 0));

   --  Rolling ephemeral source port.  A fixed port per socket index reused the
   --  exact 4-tuple on every reconnect to the same server, so the SYN was
   --  rejected while the server side was still in TIME_WAIT.  Hand out a fresh
   --  port each connect, cycling the IANA dynamic range (49152 .. 65535).
   Ephemeral_Lo   : constant := 49_152;
   Ephemeral_Hi   : constant := 65_535;
   Next_Ephemeral : Natural := Ephemeral_Lo;
   Modes        : array (Interface_Id, Sock_Index) of Mode_Type :=
     (others => (others => Socket_Stream));
   Opened       : array (Interface_Id, Sock_Index) of Boolean := (others => (others => False));
   Recv_Timeout : array (Interface_Id, Sock_Index) of Duration := (others => (others => 0.0));

   ---------------------------------------------------------------------------
   --  Interface registry
   ---------------------------------------------------------------------------

   function Add_Interface (Device : Net_Devices.Device_Access) return Interface_Id is
   begin
      if Device = null or else N_Ifaces > Natural (Interface_Id'Last) then
         raise Socket_Error;
      end if;
      declare
         Id : constant Interface_Id := Interface_Id (N_Ifaces);
      begin
         Registry (Id) := Device;
         N_Ifaces := N_Ifaces + 1;
         --  Let the routing table see this interface's up/down state.
         Net_Routes.Configure (Iface_Is_Up'Access);
         return Id;
      end;
   end Add_Interface;

   procedure Initialize (Device : Net_Devices.Device_Access) is
      Id : constant Interface_Id := Add_Interface (Device);
      pragma Unreferenced (Id);
   begin
      null;
   end Initialize;

   --  Which interface a socket lives on / its socket index / its device.
   function If_Of (Socket : Socket_Type) return Interface_Id is
   begin
      if not Socket.Bound or else Registry (Socket.Iface) = null then
         raise Socket_Error;
      end if;
      return Socket.Iface;
   end If_Of;

   function Ix_Of (Socket : Socket_Type) return Sock_Index is
   begin
      if not Socket.Bound or else Socket.Index not in Sock_Index then
         raise Socket_Error;
      end if;
      return Socket.Index;
   end Ix_Of;

   --  Pick the interface a new socket binds to.  Routing per destination is not
   --  wired yet, so for now this is always the first (default) interface.
   function Default_Iface return Interface_Id is
   begin
      if N_Ifaces = 0 then
         raise Socket_Error;                     --  no interface registered

      end if;
      return 0;
   end Default_Iface;

   --  Open the chip socket (TCP or UDP, per its mode) on its bound local port if
   --  not already open.  Called by Bind/Listen/Connect/Send/Receive as needed.
   procedure Ensure_Open (Id : Interface_Id; J : Sock_Index) is
      St : Net_Devices.Status;
      M  : constant Net_Devices.Transport :=
        (if Modes (Id, J) = Socket_Datagram then Net_Devices.UDP else Net_Devices.TCP);
   begin
      if not Opened (Id, J) then
         Registry (Id).Open (J, M, Local_Ports (Id, J), St);
         if St /= Net_Devices.OK then
            raise Socket_Error;
         end if;
         Opened (Id, J) := True;
      end if;
   end Ensure_Open;

   --  Choose the interface for a destination: the routing table when routes are
   --  configured (longest-prefix, metric, live interfaces only); otherwise the
   --  default interface, so a board that sets up no routes behaves as before.
   procedure Resolve_Iface
     (Dest : Net_Devices.IPv4_Address; Id : out Interface_Id; Found : out Boolean) is
   begin
      if Net_Routes.Has_Routes then
         Net_Routes.Resolve (Dest, Id, Found);
      else
         Id := Default_Iface;       --  raises if no interface registered
         Found := True;
      end if;
   end Resolve_Iface;

   --  Re-home a socket onto interface Target before it is opened: allocate a chip
   --  socket there, carry its pre-open state over, and free the old slot.  No-op
   --  when already on Target -- so single-interface boards never actually move.
   procedure Move_To (Socket : in out Socket_Type; Target : Interface_Id) is
      Old_Id : constant Interface_Id := If_Of (Socket);
      Old_J  : constant Sock_Index := Ix_Of (Socket);
   begin
      if Target = Old_Id then
         return;
      end if;
      declare
         Count : constant Natural := Registry (Target).Socket_Count;
         New_J : Sock_Index := 0;
         Found : Boolean := False;
      begin
         for J in 0 .. Count - 1 loop
            if not In_Use (Target, J) then
               New_J := J;
               Found := True;
               exit;
            end if;
         end loop;
         if not Found then
            raise Socket_Error;                     --  target interface is full

         end if;
         if Opened (Old_Id, Old_J) then
            Registry (Old_Id).Close (Old_J);        --  not yet opened in practice

         end if;
         In_Use (Target, New_J) := True;
         Local_Ports (Target, New_J) := Local_Ports (Old_Id, Old_J);
         Modes (Target, New_J) := Modes (Old_Id, Old_J);
         Recv_Timeout (Target, New_J) := Recv_Timeout (Old_Id, Old_J);
         Opened (Target, New_J) := False;
         In_Use (Old_Id, Old_J) := False;
         Opened (Old_Id, Old_J) := False;
         Socket :=
           (Bound  => True,
            Iface  => Target,
            Index  => New_J,
            Pinned => Socket.Pinned,
            Pin    => Socket.Pin);
      end;
   end Move_To;

   --  Find the interface whose own IP is Addr (for bind-to-address pinning).
   procedure Iface_Of_Addr
     (Addr : Net_Devices.IPv4_Address; Id : out Interface_Id; Found : out Boolean) is
   begin
      Id := 0;
      Found := False;
      for I in Interface_Id'Range loop
         if Registry (I) /= null and then Registry (I).Local_IP = Addr then
            Id := I;
            Found := True;
            return;
         end if;
      end loop;
   end Iface_Of_Addr;

   ---------------------------------------------------------------------------
   --  Addresses
   ---------------------------------------------------------------------------

   function Inet_Addr (Image : String) return Inet_Addr_Type is
      Result : Inet_Addr_Type;
      Octet  : Natural := 0;
      Part   : Natural := 0;
      Seen   : Boolean := False;
   begin
      for C of Image loop
         if C = '.' then
            if Part >= 3 or not Seen then
               raise Socket_Error;
            end if;
            Result.B (Part) := Net_Devices.Octet (Octet);
            Part := Part + 1;
            Octet := 0;
            Seen := False;
         elsif C in '0' .. '9' then
            Octet := Octet * 10 + (Character'Pos (C) - Character'Pos ('0'));
            if Octet > 255 then
               raise Socket_Error;
            end if;
            Seen := True;
         else
            raise Socket_Error;
         end if;
      end loop;
      if Part /= 3 or not Seen then
         raise Socket_Error;
      end if;
      Result.B (3) := Net_Devices.Octet (Octet);
      return Result;
   end Inet_Addr;

   function Image (Value : Inet_Addr_Type) return String is
      function Img (Octet : Net_Devices.Octet) return String is
         Image_Str : constant String := Integer'Image (Integer (Octet));
      begin
         return Image_Str (Image_Str'First + 1 .. Image_Str'Last);   --  drop the leading space
      end Img;
   begin
      return
        Img (Value.B (0))
        & "."
        & Img (Value.B (1))
        & "."
        & Img (Value.B (2))
        & "."
        & Img (Value.B (3));
   end Image;

   --  The socket's local address: its interface's own IP plus the local port.
   function Get_Socket_Name (Socket : Socket_Type) return Sock_Addr_Type is
      Id : constant Interface_Id := If_Of (Socket);
   begin
      return
        (Family => Family_Inet,
         Addr   => (B => Registry (Id).Local_IP),
         Port   => Port_Type (Local_Ports (Id, Ix_Of (Socket))));
   end Get_Socket_Name;

   ---------------------------------------------------------------------------
   --  Sockets
   ---------------------------------------------------------------------------

   --  The socket "hardware" pool (In_Use + the per-slot state) is shared: a
   --  board may run more than one task over the same W5500 (e.g. a telnet
   --  session and a background FTP server).  Claiming a free slot is a
   --  read-decide-write that the SPI lock does NOT make atomic, so two
   --  concurrent Create_Sockets could grab the same slot.  This protected
   --  object makes claim/free atomic.  (Move_To also touches In_Use, but only
   --  across interfaces; with the single W5500 interface it returns early.)
   protected Socket_Pool is
      procedure Claim
        (Id    : Interface_Id;
         Count : Natural;
         Mode  : Mode_Type;
         J     : out Sock_Index;
         Ok    : out Boolean);
      procedure Release (Id : Interface_Id; J : Sock_Index);
      procedure Reserve (Id : Interface_Id; J : Sock_Index);
   end Socket_Pool;

   protected body Socket_Pool is
      procedure Claim
        (Id    : Interface_Id;
         Count : Natural;
         Mode  : Mode_Type;
         J     : out Sock_Index;
         Ok    : out Boolean) is
      begin
         J := 0;
         Ok := False;
         for K in 0 .. Count - 1 loop
            if not In_Use (Id, K) then
               In_Use (Id, K) := True;
               Local_Ports (Id, K) := 0;
               Modes (Id, K) := Mode;
               Opened (Id, K) := False;
               Recv_Timeout (Id, K) := 0.0;
               J := K;
               Ok := True;
               return;
            end if;
         end loop;
      end Claim;

      procedure Release (Id : Interface_Id; J : Sock_Index) is
      begin
         In_Use (Id, J) := False;
         Opened (Id, J) := False;
      end Release;

      --  Permanently mark a slot in use so Claim never hands it out (there is no
      --  matching Release): used to fence off a hardware socket another subsystem
      --  drives directly, e.g. DHCP.Maintain's renewal socket.
      procedure Reserve (Id : Interface_Id; J : Sock_Index) is
      begin
         In_Use (Id, J) := True;
      end Reserve;
   end Socket_Pool;

   procedure Reserve_Socket (Iface : Interface_Id; Index : Natural) is
   begin
      if Index <= Sock_Index'Last then
         Socket_Pool.Reserve (Iface, Sock_Index (Index));
      end if;
   end Reserve_Socket;

   procedure Create_Socket
     (Socket : out Socket_Type;
      Family : Family_Type := Family_Inet;
      Mode   : Mode_Type := Socket_Stream)
   is
      pragma Unreferenced (Family);
      Id    : constant Interface_Id := Default_Iface;
      Count : constant Natural := Registry (Id).Socket_Count;
      J     : Sock_Index;
      Ok    : Boolean;
   begin
      Socket_Pool.Claim (Id, Count, Mode, J, Ok);
      if not Ok then
         raise Socket_Error;                     --  all of this interface's sockets in use

      end if;
      Socket := (Bound => True, Iface => Id, Index => J, others => <>);
   end Create_Socket;

   procedure Set_Interface (Socket : in out Socket_Type; Iface : Interface_Id) is
   begin
      Move_To (Socket, Iface);
      Socket.Pinned := True;
      Socket.Pin := Iface;
   end Set_Interface;

   procedure Bind_Socket (Socket : in out Socket_Type; Address : Sock_Addr_Type) is
   begin
      --  Binding to a specific interface's own address pins the socket there (so a
      --  server listens on just that interface); Any_Inet_Addr leaves it free.
      if Address.Addr /= Any_Inet_Addr then
         declare
            Owner : Interface_Id;
            Found : Boolean;
         begin
            Iface_Of_Addr (Address.Addr.B, Owner, Found);
            if Found then
               Set_Interface (Socket, Owner);
            end if;
         end;
      end if;
      declare
         Id : constant Interface_Id := If_Of (Socket);
         J  : constant Sock_Index := Ix_Of (Socket);
      begin
         Local_Ports (Id, J) := Net_Devices.Port_Number (Address.Port);
         if Modes (Id, J) = Socket_Datagram then
            Ensure_Open (Id, J);                 --  UDP is ready to send/recv now

         end if;
      end;
   end Bind_Socket;

   procedure Listen_Socket (Socket : in out Socket_Type; Length : Natural := 15) is
      pragma Unreferenced (Length);
      Id : constant Interface_Id := If_Of (Socket);
      J  : constant Sock_Index := Ix_Of (Socket);
      St : Net_Devices.Status;
   begin
      Ensure_Open (Id, J);                       --  open TCP on the bound port
      Registry (Id).Listen (J, St);
      if St /= Net_Devices.OK then
         raise Socket_Error;
      end if;
   end Listen_Socket;

   procedure Accept_Socket
     (Server : Socket_Type; Socket : out Socket_Type; Address : out Sock_Addr_Type)
   is
      Id   : constant Interface_Id := If_Of (Server);
      J    : constant Sock_Index := Ix_Of (Server);
      St   : Net_Devices.Status;
      Peer : Net_Devices.IPv4_Address;
      Port : Net_Devices.Port_Number;
   begin
      Registry (Id).Wait_Connected (J, St);
      if St /= Net_Devices.OK then
         raise Socket_Error;
      end if;
      Socket := Server;                          --  the listener IS the connection
      Registry (Id).Peer (J, Peer, Port);
      Address := (Family => Family_Inet, Addr => (B => Peer), Port => Port_Type (Port));
   end Accept_Socket;

   procedure Connect_Socket (Socket : in out Socket_Type; Server : Sock_Addr_Type) is
      Target : Interface_Id;
      Found  : Boolean;
   begin
      --  A pinned socket uses only its interface and fails closed if it is down --
      --  never re-routed.  Otherwise route by destination; with no routes this is
      --  the default interface (unchanged behaviour), with routes a down interface
      --  yields no route -> Socket_Error.
      if Socket.Pinned then
         Target := Socket.Pin;
         if not Iface_Is_Up (Target) then
            raise Socket_Error;                  --  fail closed, do not fall through

         end if;
      else
         Resolve_Iface (Server.Addr.B, Target, Found);
         if not Found then
            raise Socket_Error;
         end if;
      end if;
      Move_To (Socket, Target);
      declare
         Id : constant Interface_Id := If_Of (Socket);
         J  : constant Sock_Index := Ix_Of (Socket);
         St : Net_Devices.Status;
      begin
         if Local_Ports (Id, J) = 0 then
            --  pick the next ephemeral local port (fresh 4-tuple per reconnect)
            Local_Ports (Id, J) := Net_Devices.Port_Number (Next_Ephemeral);
            Next_Ephemeral :=
              (if Next_Ephemeral >= Ephemeral_Hi then Ephemeral_Lo else Next_Ephemeral + 1);
         end if;
         Ensure_Open (Id, J);                     --  open TCP on the local port
         Registry (Id).Connect (J, Server.Addr.B, Net_Devices.Port_Number (Server.Port), St);
         if St /= Net_Devices.OK then
            raise Socket_Error;
         end if;
      end;
   end Connect_Socket;

   procedure Send_Socket
     (Socket : Socket_Type;
      Item   : Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset)
   is
      Id   : constant Interface_Id := If_Of (Socket);
      J    : constant Sock_Index := Ix_Of (Socket);
      St   : Net_Devices.Status;
      Sent : Natural;
   begin
      Ensure_Open (Id, J);
      Registry (Id).Send (J, Item, Sent, St);
      if St /= Net_Devices.OK and then St /= Net_Devices.No_Space then
         raise Socket_Error;
      end if;
      Last := Item'First + Stream_Element_Offset (Sent) - 1;
   end Send_Socket;

   procedure Send_Socket
     (Socket : in out Socket_Type;
      Item   : Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset;
      To     : access Sock_Addr_Type)
   is
      St : Net_Devices.Status;
   begin
      --  Route the datagram.  Create_Socket parks every socket on the default
      --  interface; TCP is re-homed by Connect_Socket, and an unpinned UDP
      --  socket must follow the routing table the same way HERE, per
      --  destination -- otherwise a multi-interface board sends its datagrams
      --  out whatever interface happens to be index 0, live or not (found the
      --  hard way: DNS queries leaving a dead Ethernet while cellular was up).
      if To /= null and then not Socket.Pinned then
         declare
            Target : Interface_Id;
            Found  : Boolean;
         begin
            Resolve_Iface (To.Addr.B, Target, Found);
            if not Found then
               raise Socket_Error;                --  no live route to To
            end if;
            Move_To (Socket, Target);             --  no-op when already there
         end;
      end if;

      declare
         Id : constant Interface_Id := If_Of (Socket);
         J  : constant Sock_Index := Ix_Of (Socket);
      begin
         Ensure_Open (Id, J);
         if To /= null then
            Registry (Id).Send_To (J, To.Addr.B, Net_Devices.Port_Number (To.Port), Item, St);
            if St /= Net_Devices.OK then
               raise Socket_Error;
            end if;
            Last := Item'Last;                    --  a datagram is all-or-nothing

         else
            declare
               Sent : Natural;
            begin
               Registry (Id).Send (J, Item, Sent, St);
               if St /= Net_Devices.OK and then St /= Net_Devices.No_Space then
                  raise Socket_Error;
               end if;
               Last := Item'First + Stream_Element_Offset (Sent) - 1;
            end;
         end if;
      end;
   end Send_Socket;

   function Available (Socket : Socket_Type) return Natural is
      Id : constant Interface_Id := If_Of (Socket);
   begin
      if Registry (Id) = null then
         return 0;
      end if;
      return Registry (Id).Available (Ix_Of (Socket));
   end Available;

   procedure Receive_Socket
     (Socket : Socket_Type;
      Item   : out Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset;
      From   : access Sock_Addr_Type := null)
   is
      Id    : constant Interface_Id := If_Of (Socket);
      J     : constant Sock_Index := Ix_Of (Socket);
      St    : Net_Devices.Status;
      Count : Natural;
   begin
      Ensure_Open (Id, J);
      --  Re-apply the option (Ensure_Open may have just opened the chip socket).
      Registry (Id).Set_Receive_Timeout (J, Recv_Timeout (Id, J));
      Registry (Id).Wait_Data (J, St);
      if St = Net_Devices.Timed_Out then
         raise Socket_Error;                      --  receive timeout elapsed

      end if;
      if From = null and then St = Net_Devices.Closed_By_Peer then
         Last := Item'First - 1;                  --  end of stream
         return;
      end if;
      if From /= null then
         declare
            Peer_Addr : Net_Devices.IPv4_Address;
            Peer_Port : Net_Devices.Port_Number;
         begin
            Registry (Id).Receive_From (J, Peer_Addr, Peer_Port, Item, Count, St);
            From.all :=
              (Family => Family_Inet, Addr => (B => Peer_Addr), Port => Port_Type (Peer_Port));
         end;
      else
         Registry (Id).Receive (J, Item, Count, St);
      end if;
      Last := Item'First + Stream_Element_Offset (Count) - 1;
   end Receive_Socket;

   function Inet_Addr (Octets : Net_Devices.IPv4_Address) return Inet_Addr_Type
   is (Inet_Addr_Type'(B => Octets));

   function Device_For (Dest : Inet_Addr_Type) return Net_Devices.Device_Access is
      Id    : Interface_Id;
      Found : Boolean;
   begin
      Resolve_Iface (Dest.B, Id, Found);
      return (if Found then Registry (Id) else null);
   end Device_For;

   procedure Close_Socket (Socket : in out Socket_Type) is
   begin
      if Socket.Bound and then Socket.Index in Sock_Index then
         declare
            Id : constant Interface_Id := Socket.Iface;
            J  : constant Sock_Index := Socket.Index;
         begin
            if Registry (Id) /= null then
               Registry (Id).Close (J);
            end if;
            Socket_Pool.Release (Id, J);
         end;
      end if;
      Socket := No_Socket;
   end Close_Socket;

   procedure Set_Socket_Option
     (Socket : Socket_Type; Level : Level_Type := Socket_Level; Option : Option_Type)
   is
      pragma Unreferenced (Level);
      Id : constant Interface_Id := If_Of (Socket);
      J  : constant Sock_Index := Ix_Of (Socket);
   begin
      case Option.Name is
         when Receive_Timeout =>
            Recv_Timeout (Id, J) := Option.Timeout;
            Registry (Id).Set_Receive_Timeout (J, Option.Timeout);
      end case;
   end Set_Socket_Option;

   ---------------------------------------------------------------------------
   --  Stream over a socket
   ---------------------------------------------------------------------------

   type Socket_Stream_Type is new Ada.Streams.Root_Stream_Type with record
      Sock : Socket_Type := No_Socket;
   end record;

   --  Primitive specs must appear before the type is frozen (by Stream_Pool).
   overriding
   procedure Read
     (Stream : in out Socket_Stream_Type;
      Item   : out Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset);
   overriding
   procedure Write (Stream : in out Socket_Stream_Type; Item : Ada.Streams.Stream_Element_Array);

   Stream_Pool : array (Interface_Id, Sock_Index) of aliased Socket_Stream_Type;

   overriding
   procedure Read
     (Stream : in out Socket_Stream_Type;
      Item   : out Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset) is
   begin
      Receive_Socket (Stream.Sock, Item, Last);
   end Read;

   overriding
   procedure Write (Stream : in out Socket_Stream_Type; Item : Ada.Streams.Stream_Element_Array) is
      use Ada.Real_Time;
      First : Stream_Element_Offset := Item'First;
      Last  : Stream_Element_Offset;
      Stuck : Natural := 0;
   begin
      while First <= Item'Last loop
         Send_Socket (Stream.Sock, Item (First .. Item'Last), Last);
         if Last >= First then
            First := Last + 1;
            Stuck := 0;
         else
            Stuck := Stuck + 1;                  --  TX buffer momentarily full
            if Stuck > 1000 then
               raise Socket_Error;
            end if;
            delay until Clock + Milliseconds (1);
         end if;
      end loop;
   end Write;

   function Stream (Socket : Socket_Type) return Stream_Access is
      Id : constant Interface_Id := If_Of (Socket);
      J  : constant Sock_Index := Ix_Of (Socket);
   begin
      Stream_Pool (Id, J).Sock := Socket;
      return Stream_Pool (Id, J)'Access;
   end Stream;

end GNAT.Sockets;
