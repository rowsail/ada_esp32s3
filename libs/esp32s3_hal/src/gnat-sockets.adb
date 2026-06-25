with Interfaces;
with Ada.Real_Time;
with Ada.Streams;  use Ada.Streams;

package body GNAT.Sockets is

   package W5500 renames ESP32S3.W5500;
   package WS    renames ESP32S3.W5500.Sockets;
   use type WS.Status;
   use type WS.Device_Access;
   use type Interfaces.Unsigned_16;

   --  The bound W5500 and the per-hardware-socket state.
   Default_Dev    : WS.Device_Access := null;
   Engine_Sockets : array (W5500.Socket_Id) of WS.Socket;
   In_Use         : array (W5500.Socket_Id) of Boolean := (others => False);
   Local_Ports    : array (W5500.Socket_Id) of WS.Port_Number := (others => 0);
   Modes          : array (W5500.Socket_Id) of Mode_Type := (others => Socket_Stream);
   Opened         : array (W5500.Socket_Id) of Boolean := (others => False);
   Recv_Timeout   : array (W5500.Socket_Id) of Duration := (others => 0.0);

   procedure Initialize (Device : ESP32S3.W5500.Sockets.Device_Access) is
   begin
      Default_Dev := Device;
   end Initialize;

   function Idx (S : Socket_Type) return W5500.Socket_Id is
   begin
      if S.Index not in 0 .. 7 then
         raise Socket_Error;
      end if;
      return W5500.Socket_Id (S.Index);
   end Idx;

   --  Open the chip socket (TCP or UDP, per its mode) on its bound local port if
   --  not already open.  Called by Bind/Listen/Connect/Send/Receive as needed.
   procedure Ensure_Open (I : W5500.Socket_Id) is
      St : WS.Status;
   begin
      if not Opened (I) then
         case Modes (I) is
            when Socket_Datagram =>
               WS.Open_UDP (Default_Dev, Engine_Sockets (I), I, Local_Ports (I), St);
            when Socket_Stream =>
               WS.Open_TCP (Default_Dev, Engine_Sockets (I), I, Local_Ports (I), St);
         end case;
         if St /= WS.OK then raise Socket_Error; end if;
         Opened (I) := True;
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
            Result.B (Part) := W5500.Byte (Octet);
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
      Result.B (3) := W5500.Byte (Octet);
      return Result;
   end Inet_Addr;

   function Image (Value : Inet_Addr_Type) return String is
      function Img (B : W5500.Byte) return String is
         S : constant String := Integer'Image (Integer (B));
      begin
         return S (S'First + 1 .. S'Last);     --  drop the leading space
      end Img;
   begin
      return Img (Value.B (0)) & "." & Img (Value.B (1)) & "."
           & Img (Value.B (2)) & "." & Img (Value.B (3));
   end Image;

   ---------------------------------------------------------------------------
   --  Sockets
   ---------------------------------------------------------------------------

   procedure Create_Socket (Socket : out Socket_Type;
                            Family  : Family_Type := Family_Inet;
                            Mode    : Mode_Type   := Socket_Stream) is
      pragma Unreferenced (Family);
   begin
      if Default_Dev = null then
         raise Socket_Error;                    --  Initialize (Device) not called
      end if;
      for I in W5500.Socket_Id loop
         if not In_Use (I) then
            In_Use (I)        := True;
            Local_Ports (I)   := 0;
            Modes (I)         := Mode;
            Opened (I)        := False;
            Recv_Timeout (I)  := 0.0;
            Socket := (Index => Integer (I));
            return;
         end if;
      end loop;
      raise Socket_Error;                        --  all eight sockets in use
   end Create_Socket;

   procedure Bind_Socket (Socket : in out Socket_Type; Address : Sock_Addr_Type) is
      I : constant W5500.Socket_Id := Idx (Socket);
   begin
      Local_Ports (I) := WS.Port_Number (Address.Port);
      if Modes (I) = Socket_Datagram then
         Ensure_Open (I);                        --  UDP is ready to send/recv now
      end if;
   end Bind_Socket;

   procedure Listen_Socket (Socket : in out Socket_Type; Length : Natural := 15) is
      pragma Unreferenced (Length);
      I  : constant W5500.Socket_Id := Idx (Socket);
      St : WS.Status;
   begin
      Ensure_Open (I);                           --  open TCP on the bound port
      WS.Listen (Engine_Sockets (I), St);
      if St /= WS.OK then raise Socket_Error; end if;
   end Listen_Socket;

   procedure Accept_Socket (Server  : Socket_Type;
                            Socket  : out Socket_Type;
                            Address : out Sock_Addr_Type) is
      I    : constant W5500.Socket_Id := Idx (Server);
      St   : WS.Status;
      Peer : W5500.IPv4_Address;
   begin
      WS.Wait_Connected (Engine_Sockets (I), St);
      if St /= WS.OK then raise Socket_Error; end if;
      Socket := Server;                          --  the listener IS the connection
      W5500.Read (Default_Dev.all, W5500.Socket_Regs (I), 16#0C#, Peer);   --  Sn_DIPR
      Address := (Family => Family_Inet,
                  Addr   => (B => Peer),
                  Port   => Port_Type
                              (W5500.Read_U16 (Default_Dev.all,
                                               W5500.Socket_Regs (I), 16#10#)));  --  Sn_DPORT
   end Accept_Socket;

   procedure Connect_Socket (Socket : in out Socket_Type; Server : Sock_Addr_Type) is
      I  : constant W5500.Socket_Id := Idx (Socket);
      St : WS.Status;
   begin
      if Local_Ports (I) = 0 then                --  pick an ephemeral local port
         Local_Ports (I) := WS.Port_Number (50000) + WS.Port_Number (I);
      end if;
      Ensure_Open (I);                           --  open TCP on the local port
      WS.Connect (Engine_Sockets (I), Server.Addr.B, WS.Port_Number (Server.Port), St);
      if St /= WS.OK then raise Socket_Error; end if;
   end Connect_Socket;

   procedure Send_Socket (Socket : Socket_Type;
                         Item   : Ada.Streams.Stream_Element_Array;
                         Last   : out Ada.Streams.Stream_Element_Offset;
                         To     : access Sock_Addr_Type := null) is
      I    : constant W5500.Socket_Id := Idx (Socket);
      St   : WS.Status;
      Sent : Natural;
      Src  : W5500.Byte_Array (0 .. Natural (Item'Length) - 1)
               with Import, Address => Item'Address;
   begin
      Ensure_Open (I);
      if To /= null then
         WS.Send_To (Engine_Sockets (I), To.Addr.B, WS.Port_Number (To.Port), Src, St);
         if St /= WS.OK then raise Socket_Error; end if;
         Last := Item'Last;                       --  a datagram is all-or-nothing
      else
         WS.Send (Engine_Sockets (I), Src, Sent, St);
         if St /= WS.OK and then St /= WS.No_Space then raise Socket_Error; end if;
         Last := Item'First + Stream_Element_Offset (Sent) - 1;
      end if;
   end Send_Socket;

   procedure Receive_Socket (Socket : Socket_Type;
                            Item   : out Ada.Streams.Stream_Element_Array;
                            Last   : out Ada.Streams.Stream_Element_Offset;
                            From   : access Sock_Addr_Type := null) is
      I     : constant W5500.Socket_Id := Idx (Socket);
      St    : WS.Status;
      Count : Natural;
      Dst   : W5500.Byte_Array (0 .. Natural (Item'Length) - 1)
                with Import, Address => Item'Address;
   begin
      Ensure_Open (I);
      --  Re-apply the option (Ensure_Open may have just opened the chip socket).
      WS.Set_Receive_Timeout (Engine_Sockets (I), Recv_Timeout (I));
      WS.Wait_Data (Engine_Sockets (I), St);
      if St = WS.Timed_Out then
         raise Socket_Error;                      --  receive timeout elapsed
      end if;
      if From = null and then St = WS.Closed_By_Peer then
         Last := Item'First - 1;                  --  end of stream
         return;
      end if;
      if From /= null then
         declare
            FA : W5500.IPv4_Address;
            FP : WS.Port_Number;
         begin
            WS.Receive_From (Engine_Sockets (I), FA, FP, Dst, Count, St);
            From.all := (Family => Family_Inet, Addr => (B => FA),
                         Port => Port_Type (FP));
         end;
      else
         WS.Receive (Engine_Sockets (I), Dst, Count, St);
      end if;
      Last := Item'First + Stream_Element_Offset (Count) - 1;
   end Receive_Socket;

   procedure Close_Socket (Socket : in out Socket_Type) is
   begin
      if Socket.Index in 0 .. 7 then
         WS.Close (Engine_Sockets (W5500.Socket_Id (Socket.Index)));
         In_Use (W5500.Socket_Id (Socket.Index)) := False;
         Opened (W5500.Socket_Id (Socket.Index)) := False;
      end if;
      Socket := No_Socket;
   end Close_Socket;

   procedure Set_Socket_Option (Socket : Socket_Type;
                               Level   : Level_Type := Socket_Level;
                               Option  : Option_Type) is
      pragma Unreferenced (Level);
      I : constant W5500.Socket_Id := Idx (Socket);
   begin
      case Option.Name is
         when Receive_Timeout =>
            Recv_Timeout (I) := Option.Timeout;
            WS.Set_Receive_Timeout (Engine_Sockets (I), Option.Timeout);
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

   Stream_Pool : array (W5500.Socket_Id) of aliased Socket_Stream_Type;

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
      I : constant W5500.Socket_Id := Idx (Socket);
   begin
      Stream_Pool (I).Sock := Socket;
      return Stream_Pool (I)'Access;
   end Stream;

end GNAT.Sockets;
