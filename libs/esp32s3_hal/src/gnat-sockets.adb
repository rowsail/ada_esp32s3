with Interfaces;
with Ada.Real_Time;
with Ada.Streams;  use Ada.Streams;
with Net_Devices;

package body GNAT.Sockets is

   use type Net_Devices.Status;
   use type Net_Devices.Device_Access;
   use type Interfaces.Unsigned_16;

   Max_Sockets : constant := 8;                 --  most any one interface provides
   subtype Sock_Index is Natural range 0 .. Max_Sockets - 1;

   --  Registered interfaces and the per-(interface, socket) state.
   Registry : array (Interface_Id) of Net_Devices.Device_Access := (others => null);
   N_Ifaces : Natural := 0;

   In_Use       : array (Interface_Id, Sock_Index) of Boolean := (others => (others => False));
   Local_Ports  : array (Interface_Id, Sock_Index) of Net_Devices.Port_Number :=
                    (others => (others => 0));
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
   function If_Of (S : Socket_Type) return Interface_Id is
   begin
      if S.Iface not in 0 .. Integer (Interface_Id'Last)
        or else Registry (Interface_Id (S.Iface)) = null
      then
         raise Socket_Error;
      end if;
      return Interface_Id (S.Iface);
   end If_Of;

   function Ix_Of (S : Socket_Type) return Sock_Index is
   begin
      if S.Index not in Sock_Index then
         raise Socket_Error;
      end if;
      return S.Index;
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
             (if Modes (Id, J) = Socket_Datagram
              then Net_Devices.UDP else Net_Devices.TCP);
   begin
      if not Opened (Id, J) then
         Registry (Id).Open (J, M, Local_Ports (Id, J), St);
         if St /= Net_Devices.OK then raise Socket_Error; end if;
         Opened (Id, J) := True;
      end if;
   end Ensure_Open;

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
            if Part >= 3 or not Seen then raise Socket_Error; end if;
            Result.B (Part) := Net_Devices.Octet (Octet);
            Part := Part + 1;  Octet := 0;  Seen := False;
         elsif C in '0' .. '9' then
            Octet := Octet * 10 + (Character'Pos (C) - Character'Pos ('0'));
            if Octet > 255 then raise Socket_Error; end if;
            Seen := True;
         else
            raise Socket_Error;
         end if;
      end loop;
      if Part /= 3 or not Seen then raise Socket_Error; end if;
      Result.B (3) := Net_Devices.Octet (Octet);
      return Result;
   end Inet_Addr;

   function Image (Value : Inet_Addr_Type) return String is
      function Img (B : Net_Devices.Octet) return String is
         S : constant String := Integer'Image (Integer (B));
      begin
         return S (S'First + 1 .. S'Last);     --  drop the leading space
      end Img;
   begin
      return Img (Value.B (0)) & "." & Img (Value.B (1)) & "."
           & Img (Value.B (2)) & "." & Img (Value.B (3));
   end Image;

   --  The socket's local address: its interface's own IP plus the local port.
   function Get_Socket_Name (Socket : Socket_Type) return Sock_Addr_Type is
      Id : constant Interface_Id := If_Of (Socket);
   begin
      return (Family => Family_Inet,
              Addr   => (B => Registry (Id).Local_IP),
              Port   => Port_Type (Local_Ports (Id, Ix_Of (Socket))));
   end Get_Socket_Name;

   ---------------------------------------------------------------------------
   --  Sockets
   ---------------------------------------------------------------------------

   procedure Create_Socket (Socket : out Socket_Type;
                            Family  : Family_Type := Family_Inet;
                            Mode    : Mode_Type   := Socket_Stream) is
      pragma Unreferenced (Family);
      Id    : constant Interface_Id := Default_Iface;
      Count : constant Natural      := Registry (Id).Socket_Count;
   begin
      for J in 0 .. Count - 1 loop
         if not In_Use (Id, J) then
            In_Use       (Id, J) := True;
            Local_Ports  (Id, J) := 0;
            Modes        (Id, J) := Mode;
            Opened       (Id, J) := False;
            Recv_Timeout (Id, J) := 0.0;
            Socket := (Iface => Integer (Id), Index => J);
            return;
         end if;
      end loop;
      raise Socket_Error;                        --  all of this interface's sockets in use
   end Create_Socket;

   procedure Bind_Socket (Socket : in out Socket_Type; Address : Sock_Addr_Type) is
      Id : constant Interface_Id := If_Of (Socket);
      J  : constant Sock_Index   := Ix_Of (Socket);
   begin
      Local_Ports (Id, J) := Net_Devices.Port_Number (Address.Port);
      if Modes (Id, J) = Socket_Datagram then
         Ensure_Open (Id, J);                    --  UDP is ready to send/recv now
      end if;
   end Bind_Socket;

   procedure Listen_Socket (Socket : in out Socket_Type; Length : Natural := 15) is
      pragma Unreferenced (Length);
      Id : constant Interface_Id := If_Of (Socket);
      J  : constant Sock_Index   := Ix_Of (Socket);
      St : Net_Devices.Status;
   begin
      Ensure_Open (Id, J);                       --  open TCP on the bound port
      Registry (Id).Listen (J, St);
      if St /= Net_Devices.OK then raise Socket_Error; end if;
   end Listen_Socket;

   procedure Accept_Socket (Server  : Socket_Type;
                            Socket  : out Socket_Type;
                            Address : out Sock_Addr_Type) is
      Id   : constant Interface_Id := If_Of (Server);
      J    : constant Sock_Index   := Ix_Of (Server);
      St   : Net_Devices.Status;
      Peer : Net_Devices.IPv4_Address;
      Port : Net_Devices.Port_Number;
   begin
      Registry (Id).Wait_Connected (J, St);
      if St /= Net_Devices.OK then raise Socket_Error; end if;
      Socket := Server;                          --  the listener IS the connection
      Registry (Id).Peer (J, Peer, Port);
      Address := (Family => Family_Inet,
                  Addr   => (B => Peer),
                  Port   => Port_Type (Port));
   end Accept_Socket;

   procedure Connect_Socket (Socket : in out Socket_Type; Server : Sock_Addr_Type) is
      Id : constant Interface_Id := If_Of (Socket);
      J  : constant Sock_Index   := Ix_Of (Socket);
      St : Net_Devices.Status;
   begin
      if Local_Ports (Id, J) = 0 then            --  pick an ephemeral local port
         Local_Ports (Id, J) := Net_Devices.Port_Number (50_000 + J);
      end if;
      Ensure_Open (Id, J);                        --  open TCP on the local port
      Registry (Id).Connect (J, Server.Addr.B, Net_Devices.Port_Number (Server.Port), St);
      if St /= Net_Devices.OK then raise Socket_Error; end if;
   end Connect_Socket;

   procedure Send_Socket (Socket : Socket_Type;
                         Item   : Ada.Streams.Stream_Element_Array;
                         Last   : out Ada.Streams.Stream_Element_Offset;
                         To     : access Sock_Addr_Type := null) is
      Id   : constant Interface_Id := If_Of (Socket);
      J    : constant Sock_Index   := Ix_Of (Socket);
      St   : Net_Devices.Status;
      Sent : Natural;
   begin
      Ensure_Open (Id, J);
      if To /= null then
         Registry (Id).Send_To (J, To.Addr.B, Net_Devices.Port_Number (To.Port), Item, St);
         if St /= Net_Devices.OK then raise Socket_Error; end if;
         Last := Item'Last;                       --  a datagram is all-or-nothing
      else
         Registry (Id).Send (J, Item, Sent, St);
         if St /= Net_Devices.OK and then St /= Net_Devices.No_Space then
            raise Socket_Error;
         end if;
         Last := Item'First + Stream_Element_Offset (Sent) - 1;
      end if;
   end Send_Socket;

   procedure Receive_Socket (Socket : Socket_Type;
                            Item   : out Ada.Streams.Stream_Element_Array;
                            Last   : out Ada.Streams.Stream_Element_Offset;
                            From   : access Sock_Addr_Type := null) is
      Id    : constant Interface_Id := If_Of (Socket);
      J     : constant Sock_Index   := Ix_Of (Socket);
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
            FA : Net_Devices.IPv4_Address;
            FP : Net_Devices.Port_Number;
         begin
            Registry (Id).Receive_From (J, FA, FP, Item, Count, St);
            From.all := (Family => Family_Inet, Addr => (B => FA),
                         Port => Port_Type (FP));
         end;
      else
         Registry (Id).Receive (J, Item, Count, St);
      end if;
      Last := Item'First + Stream_Element_Offset (Count) - 1;
   end Receive_Socket;

   procedure Close_Socket (Socket : in out Socket_Type) is
   begin
      if Socket.Iface in 0 .. Integer (Interface_Id'Last)
        and then Socket.Index in Sock_Index
      then
         declare
            Id : constant Interface_Id := Interface_Id (Socket.Iface);
            J  : constant Sock_Index   := Socket.Index;
         begin
            if Registry (Id) /= null then
               Registry (Id).Close (J);
            end if;
            In_Use (Id, J) := False;
            Opened (Id, J) := False;
         end;
      end if;
      Socket := No_Socket;
   end Close_Socket;

   procedure Set_Socket_Option (Socket : Socket_Type;
                               Level   : Level_Type := Socket_Level;
                               Option  : Option_Type) is
      pragma Unreferenced (Level);
      Id : constant Interface_Id := If_Of (Socket);
      J  : constant Sock_Index   := Ix_Of (Socket);
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
   overriding procedure Read (Stream : in out Socket_Stream_Type;
                              Item   : out Ada.Streams.Stream_Element_Array;
                              Last   : out Ada.Streams.Stream_Element_Offset);
   overriding procedure Write (Stream : in out Socket_Stream_Type;
                               Item   : Ada.Streams.Stream_Element_Array);

   Stream_Pool : array (Interface_Id, Sock_Index) of aliased Socket_Stream_Type;

   overriding procedure Read (Stream : in out Socket_Stream_Type;
                              Item   : out Ada.Streams.Stream_Element_Array;
                              Last   : out Ada.Streams.Stream_Element_Offset) is
   begin
      Receive_Socket (Stream.Sock, Item, Last);
   end Read;

   overriding procedure Write (Stream : in out Socket_Stream_Type;
                               Item   : Ada.Streams.Stream_Element_Array) is
      use Ada.Real_Time;
      First : Stream_Element_Offset := Item'First;
      Last  : Stream_Element_Offset;
      Stuck : Natural := 0;
   begin
      while First <= Item'Last loop
         Send_Socket (Stream.Sock, Item (First .. Item'Last), Last);
         if Last >= First then
            First := Last + 1;  Stuck := 0;
         else
            Stuck := Stuck + 1;                  --  TX buffer momentarily full
            if Stuck > 1000 then raise Socket_Error; end if;
            delay until Clock + Milliseconds (1);
         end if;
      end loop;
   end Write;

   function Stream (Socket : Socket_Type) return Stream_Access is
      Id : constant Interface_Id := If_Of (Socket);
      J  : constant Sock_Index   := Ix_Of (Socket);
   begin
      Stream_Pool (Id, J).Sock := Socket;
      return Stream_Pool (Id, J)'Access;
   end Stream;

end GNAT.Sockets;
