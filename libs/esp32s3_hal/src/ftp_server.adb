with Ada.Streams;  use Ada.Streams;
with GNAT.Sockets; use GNAT.Sockets;
with Interfaces;   use Interfaces;
with ESP32S3.Ext4;
with ESP32S3.Ext4.FS;
with ESP32S3.Ext4.Inode;
with ESP32S3.Ext4.VFS;

package body FTP_Server is

   package E4 renames ESP32S3.Ext4;
   package FSP renames ESP32S3.Ext4.FS;
   package VFS renames ESP32S3.Ext4.VFS;
   use type E4.Inode_Number;
   use type VFS.Mount_Ref;

   subtype SEA is Stream_Element_Array;
   subtype SEO is Stream_Element_Offset;

   CR         : constant Stream_Element := 13;
   LF         : constant Stream_Element := 10;
   Data_Chunk : constant := 1024;

   ---------------------------------------------------------------------------
   --  Session state -- one client at a time, so library-level globals are fine
   --  (Iterate's Visit callback has no Ctx, which forces this anyway).
   ---------------------------------------------------------------------------

   --  The mount the current command resolved to, and whether the path was the
   --  virtual root "/".  Set by Resolve_Path; commands then act on Active_M.
   Active_M : VFS.Mount_Ref;
   At_Root  : Boolean := False;

   RO       : Boolean := False;
   DPort    : Port_Type := 50_000;
   Host_IP  : String (1 .. 15);            --  dotted IP advertised in PASV
   Host_Len : Natural := 0;
   Name     : String (1 .. 64);            --  server name for the 220 greeting
   Name_Len : Natural := 0;

   Ctrl      : Socket_Type;               --  the control connection
   Ctrl_Peer : Sock_Addr_Type;            --  its remote address (data-peer check)
   Cwd     : String (1 .. 1024);          --  current directory (absolute)
   Cwd_Len : Natural := 1;

   In_Buf  : SEA (0 .. 1023);             --  control-line reassembly
   In_Head : Natural := 0;
   In_Tail : Natural := 0;

   Have_Pasv : Boolean := False;
   Data_Sock : Socket_Type;                --  the PASV data listener

   ---------------------------------------------------------------------------
   --  Low-level socket I/O
   ---------------------------------------------------------------------------

   procedure Send_All (Sock : Socket_Type; Data : SEA) is
      Last : SEO;
      Pos  : SEO := Data'First;
   begin
      while Pos <= Data'Last loop
         Send_Socket (Sock, Data (Pos .. Data'Last), Last);
         exit when Last < Pos;
         Pos := Last + 1;
      end loop;
   exception
      when Socket_Error =>
         null;
   end Send_All;

   procedure Send_Str (Sock : Socket_Type; S : String) is
      Buf : SEA (1 .. SEO (S'Length));
   begin
      for I in S'Range loop
         Buf (SEO (I - S'First) + 1) := Stream_Element (Character'Pos (S (I)));
      end loop;
      Send_All (Sock, Buf);
   end Send_Str;

   procedure Reply (Code, Text : String) is
   begin
      Send_Str (Ctrl, Code & " " & Text & Character'Val (13) & Character'Val (10));
   end Reply;

   --  Read one CRLF-terminated control line (CR/LF stripped).  False on close.
   function Get_Line (Line : out String; Last : out Natural) return Boolean is
      Count : Natural := 0;
      Octet : Stream_Element;
   begin
      Last := 0;
      loop
         if In_Head >= In_Tail then
            declare
               RLast : SEO;
            begin
               Receive_Socket (Ctrl, In_Buf, RLast);
               if RLast < In_Buf'First then
                  return False;                       --  peer closed

               end if;
               In_Head := 0;
               In_Tail := Natural (RLast - In_Buf'First + 1);
            end;
         end if;
         Octet := In_Buf (SEO (In_Head));
         In_Head := In_Head + 1;
         if Octet = LF then
            Last := Count;
            return True;
         elsif Octet /= CR then
            if Count < Line'Length then
               Count := Count + 1;
               Line (Line'First + Count - 1) := Character'Val (Natural (Octet));
            end if;
         end if;
      end loop;
   exception
      when Socket_Error =>
         return False;
   end Get_Line;

   ---------------------------------------------------------------------------
   --  Small text helpers
   ---------------------------------------------------------------------------

   function Upper (S : String) return String is
      Result : String := S;
   begin
      for I in Result'Range loop
         if Result (I) in 'a' .. 'z' then
            Result (I) := Character'Val (Character'Pos (Result (I)) - 32);
         end if;
      end loop;
      return Result;
   end Upper;

   function Img (N : Natural) return String is
      Image_Str : constant String := Natural'Image (N);
   begin
      return Image_Str (Image_Str'First + 1 .. Image_Str'Last);
   end Img;

   --  Normalised absolute path of Arg, resolved against Cwd (handles "/", "..",
   --  ".", "//", trailing "/").  Result has no trailing slash except "/".
   function Abs_Path (Arg : String) return String is
      Raw      : String (1 .. Cwd_Len + Arg'Length + 2);
      Raw_Len  : Natural := 0;
      Out_Path : String (1 .. Raw'Length);
      Out_Len  : Natural := 0;
      I        : Natural;
   begin
      if Arg'Length > 0 and then Arg (Arg'First) = '/' then
         Raw (1 .. Arg'Length) := Arg;
         Raw_Len := Arg'Length;
      else
         Raw (1 .. Cwd_Len) := Cwd (1 .. Cwd_Len);
         Raw_Len := Cwd_Len;
         if Raw_Len = 0 or else Raw (Raw_Len) /= '/' then
            Raw_Len := Raw_Len + 1;
            Raw (Raw_Len) := '/';
         end if;
         Raw (Raw_Len + 1 .. Raw_Len + Arg'Length) := Arg;
         Raw_Len := Raw_Len + Arg'Length;
      end if;

      --  Walk components, applying . and ..
      Out_Len := 1;
      Out_Path (1) := '/';
      I := 1;
      while I <= Raw_Len loop
         while I <= Raw_Len and then Raw (I) = '/' loop
            I := I + 1;
         end loop;
         declare
            Start : constant Natural := I;
         begin
            while I <= Raw_Len and then Raw (I) /= '/' loop
               I := I + 1;
            end loop;
            declare
               Comp : constant String := Raw (Start .. I - 1);
            begin
               if Comp = "" or else Comp = "." then
                  null;
               elsif Comp = ".." then
                  while Out_Len > 1 and then Out_Path (Out_Len) /= '/' loop
                     Out_Len := Out_Len - 1;
                  end loop;
                  if Out_Len > 1 then
                     Out_Len := Out_Len - 1;
                  end if;   --  drop the slash
                  if Out_Len = 0 then
                     Out_Len := 1;
                     Out_Path (1) := '/';
                  end if;
               else
                  if Out_Len = 0 or else Out_Path (Out_Len) /= '/' then
                     Out_Len := Out_Len + 1;
                     Out_Path (Out_Len) := '/';
                  end if;
                  Out_Path (Out_Len + 1 .. Out_Len + Comp'Length) := Comp;
                  Out_Len := Out_Len + Comp'Length;
               end if;
            end;
         end;
      end loop;
      return Out_Path (1 .. Out_Len);
   end Abs_Path;

   --  Split an absolute path into (parent dir, last name).
   procedure Split
     (Path     : String;
      Dir      : out String;
      Dir_Len  : out Natural;
      Name     : out String;
      Name_Len : out Natural)
   is
      Slash : Natural := Path'First;
   begin
      for I in Path'Range loop
         if Path (I) = '/' then
            Slash := I;
         end if;
      end loop;
      Name_Len := Path'Last - Slash;
      Name (Name'First .. Name'First + Name_Len - 1) := Path (Slash + 1 .. Path'Last);
      if Slash = Path'First then
         Dir_Len := 1;
         Dir (Dir'First) := '/';
      else
         Dir_Len := Slash - Path'First;
         Dir (Dir'First .. Dir'First + Dir_Len - 1) := Path (Path'First .. Slash - 1);
      end if;
   end Split;

   --  Route an absolute VFS path to its backing mount.  Sets Active_M and At_Root
   --  (globals) and returns the path WITHIN that mount.  For the virtual root "/"
   --  or an unknown volume, Active_M is null (At_Root distinguishes the two) and
   --  the result is "".
   function Resolve_Path (Path : String) return String is
      Slice_First, Slice_Last : Natural;
      Found                   : Boolean;
   begin
      VFS.Resolve (Path, Active_M, Slice_First, Slice_Last, Found, At_Root);
      if Found then
         return (if Slice_Last >= Slice_First then Path (Slice_First .. Slice_Last) else "/");
      else
         Active_M := null;
         return "";
      end if;
   end Resolve_Path;

   ---------------------------------------------------------------------------
   --  Passive data connection
   ---------------------------------------------------------------------------

   --  Open the data listener and tell the client where to connect (PASV).
   procedure Do_Pasv is
      Port_Hi  : constant Natural := Natural (DPort) / 256;
      Port_Lo  : constant Natural := Natural (DPort) mod 256;
      Host_Str : String := Host_IP (1 .. Host_Len);
   begin
      if Have_Pasv then
         begin
            Close_Socket (Data_Sock);
         exception
            when others =>
               null;
         end;
      end if;
      Create_Socket (Data_Sock, Family_Inet, Socket_Stream);
      begin
         Bind_Socket (Data_Sock, (Family => Family_Inet, Addr => Any_Inet_Addr, Port => DPort));
         Listen_Socket (Data_Sock);
      exception
         when Socket_Error =>
            --  Bind/Listen failed after Create: close the slot (else it leaks and
            --  the catch-all in Run tears down the control session) and report.
            Close_Socket (Data_Sock);
            Have_Pasv := False;
            Reply ("425", "cannot open data listener");
            return;
      end;
      Have_Pasv := True;
      --  227 wants the IP with commas: a.b.c.d -> a,b,c,d
      for I in Host_Str'Range loop
         if Host_Str (I) = '.' then
            Host_Str (I) := ',';
         end if;
      end loop;
      Reply
        ("227",
         "Entering Passive Mode (" & Host_Str & "," & Img (Port_Hi) & "," & Img (Port_Lo) & ")");
   end Do_Pasv;

   --  Accept the pending data connection (the listener becomes the connection).
   function Accept_Data (Conn : out Socket_Type) return Boolean is
      Addr : Sock_Addr_Type;
   begin
      if not Have_Pasv then
         Reply ("425", "use PASV first");
         return False;
      end if;
      Reply ("150", "opening data connection");
      Accept_Socket (Data_Sock, Conn, Addr);
      --  Only accept a data connection from the same host as the control session:
      --  the listener binds Any_Inet_Addr on a predictable port, so otherwise a
      --  third party on the network could race the client to it and receive the
      --  file (or inject a STOR body).
      if Addr.Addr /= Ctrl_Peer.Addr then
         Close_Socket (Conn);
         Reply ("425", "data connection from unexpected host");
         return False;
      end if;
      return True;
   exception
      when Socket_Error =>
         --  Close the listener before dropping Have_Pasv, or the next Do_Pasv
         --  (which only closes when Have_Pasv is set) leaks this slot forever.
         begin
            Close_Socket (Data_Sock);
         exception
            when others =>
               null;
         end;
         Reply ("425", "data connection failed");
         Have_Pasv := False;
         return False;
   end Accept_Data;

   procedure Close_Data (Conn : in out Socket_Type) is
   begin
      begin
         Close_Socket (Conn);
      exception
         when others =>
            null;
      end;
      Have_Pasv := False;
   end Close_Data;

   ---------------------------------------------------------------------------
   --  Directory listing (LIST / NLST).  Iterate's Visit has no Ctx, so record
   --  the entries first, then Stat + format each (no FS re-entrancy mid-walk).
   ---------------------------------------------------------------------------

   Max_Entries : constant := 256;
   type Entry_Rec is record
      Name : String (1 .. 255);
      Len  : Natural := 0;
      Ino  : E4.Inode_Number := 0;
   end record;
   --  ~69 KB: allocated on first listing so it lands on the heap (PSRAM on
   --  boards that put the heap there) rather than in internal-RAM .bss.
   type Entry_Array is array (1 .. Max_Entries) of Entry_Rec;
   type Entry_Array_Ptr is access Entry_Array;
   Entries     : Entry_Array_Ptr := null;
   N_Entries   : Natural := 0;

   procedure Need_Entries is
   begin
      if Entries = null then
         Entries := new Entry_Array;
      end if;
   end Need_Entries;

   procedure Record_Entry (Name : String; Ino : E4.Inode_Number; File_Type : E4.U8) is
      pragma Unreferenced (File_Type);
   begin
      if Name = "." or else Name = ".." then
         return;
      end if;
      if N_Entries < Max_Entries then
         N_Entries := N_Entries + 1;
         Entries (N_Entries).Len := Natural'Min (Name'Length, 255);
         Entries (N_Entries).Name (1 .. Entries (N_Entries).Len) :=
           Name (Name'First .. Name'First + Entries (N_Entries).Len - 1);
         Entries (N_Entries).Ino := Ino;
      end if;
   end Record_Entry;

   --  Send one listing line ("<name>\r\n", or an "ls -l"-style line when Long).
   procedure Send_Entry (Conn : Socket_Type; Nm : String; Long, Is_Dir : Boolean; Size : Natural)
   is
      Line : String (1 .. 320);
      Len  : Natural := 0;
      procedure Put (S : String) is
      begin
         Line (Len + 1 .. Len + S'Length) := S;
         Len := Len + S'Length;
      end Put;
   begin
      if Long then
         Put (if Is_Dir then "drwxr-xr-x" else "-rw-r--r--");
         Put (" 1 ftp ftp ");
         Put (Img (Size));
         Put (" Jan  1 00:00 ");
      end if;
      Put (Nm);
      Put (Character'Val (13) & Character'Val (10));
      declare
         Bytes : SEA (1 .. SEO (Len));
      begin
         for I in 1 .. Len loop
            Bytes (SEO (I)) := Stream_Element (Character'Pos (Line (I)));
         end loop;
         Send_All (Conn, Bytes);
      end;
   end Send_Entry;

   procedure Do_List (Arg : String; Long : Boolean) is
      Conn : Socket_Type;
      Path : constant String := Abs_Path (Arg);
      Sub  : constant String := Resolve_Path (Path);
      Dir  : E4.Inode.Info;
   begin
      --  The virtual root "/" lists the mounted volumes ("flash", "sd", ...).
      if At_Root then
         if not Accept_Data (Conn) then
            return;
         end if;
         for I in 1 .. VFS.Count loop
            Send_Entry (Conn, VFS.Name (I), Long, Is_Dir => True, Size => 0);
         end loop;
         Close_Data (Conn);
         Reply ("226", "directory send OK");
         return;
      end if;
      if Active_M = null then
         Reply ("550", "no such directory");
         return;
      end if;

      begin
         FSP.Stat (Active_M.all, FSP.Lookup (Active_M.all, Sub), Dir);
      exception
         when others =>
            Reply ("550", "no such directory");
            return;
      end;
      if not E4.Inode.Is_Dir (Dir) then
         Reply ("550", "not a directory");
         return;
      end if;

      Need_Entries;
      N_Entries := 0;
      FSP.Iterate (Active_M.all, Dir, Record_Entry'Access);

      if not Accept_Data (Conn) then
         return;
      end if;
      for K in 1 .. N_Entries loop
         declare
            Nm   : constant String := Entries (K).Name (1 .. Entries (K).Len);
            Info : E4.Inode.Info;
         begin
            FSP.Stat (Active_M.all, Entries (K).Ino, Info);
            Send_Entry (Conn, Nm, Long, E4.Inode.Is_Dir (Info), Natural (Info.Size));
         end;
      end loop;
      Close_Data (Conn);
      Reply ("226", "directory send OK");
   exception
      when others =>
         --  A Stat/Iterate/Send failure after Accept_Data opened the data socket
         --  must not escape and leak that socket (repeated, this exhausts the
         --  W5500's 8-socket pool) -- mirror Do_Retr/Do_Stor.  Close_Data is safe
         --  on an unopened Conn (it swallows the Close_Socket error).
         Close_Data (Conn);
         Reply ("550", "list error");
   end Do_List;

   ---------------------------------------------------------------------------
   --  RETR / STOR
   ---------------------------------------------------------------------------

   procedure Do_Retr (Arg : String) is
      Conn   : Socket_Type;
      Path   : constant String := Abs_Path (Arg);
      Sub    : constant String := Resolve_Path (Path);
      Info   : E4.Inode.Info;
      Offset : Interfaces.Unsigned_64 := 0;
      Buf    : E4.Byte_Array (0 .. Data_Chunk - 1);
      Last   : Natural;
   begin
      if Active_M = null then
         Reply ("550", "no such file");
         return;
      end if;
      begin
         FSP.Stat (Active_M.all, FSP.Lookup (Active_M.all, Sub), Info);
      exception
         when others =>
            Reply ("550", "no such file");
            return;
      end;
      if not E4.Inode.Is_Reg (Info) then
         Reply ("550", "not a regular file");
         return;
      end if;
      if not Accept_Data (Conn) then
         return;
      end if;
      loop
         FSP.Read_File (Active_M.all, Info, Offset, Buf, Last);
         exit when Last = 0;
         declare
            Bytes : SEA (0 .. SEO (Last - 1));
         begin
            for I in 0 .. Last - 1 loop
               Bytes (SEO (I)) := Stream_Element (Buf (I));
            end loop;
            Send_All (Conn, Bytes);
         end;
         Offset := Offset + Interfaces.Unsigned_64 (Last);
      end loop;
      Close_Data (Conn);
      Reply ("226", "transfer complete");
   exception
      when others =>
         Close_Data (Conn);
         Reply ("550", "read error");
   end Do_Retr;

   procedure Do_Stor (Arg : String) is
      Conn     : Socket_Type;
      Path     : constant String := Abs_Path (Arg);
      Sub      : constant String := Resolve_Path (Path);
      Dir      : String (1 .. 1024);
      Dir_Len  : Natural;
      Name     : String (1 .. 255);
      Name_Len : Natural;
      Ino      : E4.Inode_Number;
      Scratch  : SEA (0 .. Data_Chunk - 1);
      RLast    : SEO;
   begin
      if RO then
         Reply ("532", "read-only server");
         return;
      end if;
      if Active_M = null then
         Reply ("550", "no such path");
         return;
      end if;
      Split (Sub, Dir, Dir_Len, Name, Name_Len);
      --  Overwrite: truncate an existing file, else create it.
      begin
         Ino := FSP.Lookup (Active_M.all, Sub);
         FSP.Truncate (Active_M.all, Ino, 0);
      exception
         when others =>
            Ino := FSP.Create_File (Active_M.all, Dir (1 .. Dir_Len), Name (1 .. Name_Len));
      end;
      if not Accept_Data (Conn) then
         return;
      end if;
      loop
         begin
            Receive_Socket (Conn, Scratch, RLast);
         exception
            when Socket_Error =>
               exit;
         end;
         exit when RLast < Scratch'First;     --  EOF
         declare
            Chunk : E4.Byte_Array (0 .. Natural (RLast - Scratch'First));
         begin
            for I in Chunk'Range loop
               Chunk (I) := E4.U8 (Scratch (Scratch'First + SEO (I)));
            end loop;
            FSP.Append (Active_M.all, Ino, Chunk);
         end;
      end loop;
      Close_Data (Conn);
      FSP.Commit (Active_M.all);
      Reply ("226", "transfer complete");
   exception
      when others =>
         Close_Data (Conn);
         Reply ("550", "write error");
   end Do_Stor;

   ---------------------------------------------------------------------------
   --  Simple filesystem commands
   ---------------------------------------------------------------------------

   procedure Do_Cwd (Arg : String) is
      Path : constant String := Abs_Path (Arg);
      Sub  : constant String := Resolve_Path (Path);
      Info : E4.Inode.Info;
   begin
      --  "/" (the virtual root) and a mount point's own root are always dirs.
      if At_Root then
         Cwd_Len := 1;
         Cwd (1) := '/';
         Reply ("250", "directory changed");
         return;
      end if;
      if Active_M = null then
         Reply ("550", "no such directory");
         return;
      end if;
      FSP.Stat (Active_M.all, FSP.Lookup (Active_M.all, Sub), Info);
      if E4.Inode.Is_Dir (Info) then
         Cwd_Len := Path'Length;
         Cwd (1 .. Cwd_Len) := Path;
         Reply ("250", "directory changed");
      else
         Reply ("550", "not a directory");
      end if;
   exception
      when others =>
         Reply ("550", "no such directory");
   end Do_Cwd;

   procedure Do_Size (Arg : String) is
      Path : constant String := Abs_Path (Arg);
      Sub  : constant String := Resolve_Path (Path);
      Info : E4.Inode.Info;
   begin
      if Active_M = null then
         Reply ("550", "no such file");
         return;
      end if;
      FSP.Stat (Active_M.all, FSP.Lookup (Active_M.all, Sub), Info);
      if E4.Inode.Is_Reg (Info) then
         Reply ("213", Img (Natural (Info.Size)));
      else
         Reply ("550", "not a regular file");
      end if;
   exception
      when others =>
         Reply ("550", "no such file");
   end Do_Size;

   --  MKD / RMD / DELE share the split-and-act shape.
   procedure Path_Op (Arg : String; Op : Character) is
      Path     : constant String := Abs_Path (Arg);
      Sub      : constant String := Resolve_Path (Path);
      Dir      : String (1 .. 1024);
      Dir_Len  : Natural;
      Name     : String (1 .. 255);
      Name_Len : Natural;
   begin
      if RO then
         Reply ("532", "read-only server");
         return;
      end if;
      if Active_M = null then
         Reply ("550", "operation failed");
         return;
      end if;
      Split (Sub, Dir, Dir_Len, Name, Name_Len);
      case Op is
         when 'M'    =>
            FSP.Mkdir (Active_M.all, Dir (1 .. Dir_Len), Name (1 .. Name_Len));

         when 'R'    =>
            FSP.Rmdir (Active_M.all, Dir (1 .. Dir_Len), Name (1 .. Name_Len));

         when others =>
            FSP.Unlink (Active_M.all, Dir (1 .. Dir_Len), Name (1 .. Name_Len));
      end case;
      FSP.Commit (Active_M.all);
      if Op = 'M' then
         Reply ("257", """" & Path & """ created");
      else
         Reply ("250", "done");
      end if;
   exception
      when others =>
         Reply ("550", "operation failed");
   end Path_Op;

   ---------------------------------------------------------------------------
   --  The command loop for one client
   ---------------------------------------------------------------------------

   procedure Serve_Client is
      Line : String (1 .. 1024);
      Last : Natural;
   begin
      In_Head := 0;
      In_Tail := 0;
      Have_Pasv := False;
      Cwd_Len := 1;
      Cwd (1) := '/';
      Reply ("220", Name (1 .. Name_Len) & " FTP server ready");
      loop
         exit when not Get_Line (Line, Last);
         declare
            Request_Line : constant String := Line (1 .. Last);
            Space_Pos    : Natural := 0;
         begin
            for I in Request_Line'Range loop
               if Request_Line (I) = ' ' then
                  Space_Pos := I;
                  exit;
               end if;
            end loop;
            declare
               Cmd : constant String :=
                 Upper
                   (if Space_Pos = 0
                    then Request_Line
                    else Request_Line (Request_Line'First .. Space_Pos - 1));
               Arg : constant String :=
                 (if Space_Pos = 0 then "" else Request_Line (Space_Pos + 1 .. Request_Line'Last));
            begin
               if Cmd = "USER" then
                  Reply ("331", "send any password");
               elsif Cmd = "PASS" then
                  Reply ("230", "logged in (anonymous)");
               elsif Cmd = "SYST" then
                  Reply ("215", "UNIX Type: L8");
               elsif Cmd = "FEAT" then
                  Reply ("211", "no features");
               elsif Cmd = "TYPE" then
                  Reply ("200", "type set");
               elsif Cmd = "NOOP" then
                  Reply ("200", "ok");
               elsif Cmd = "OPTS" then
                  Reply ("200", "ok");
               elsif Cmd = "PWD" or else Cmd = "XPWD" then
                  Reply ("257", """" & Cwd (1 .. Cwd_Len) & """");
               elsif Cmd = "CWD" then
                  Do_Cwd (Arg);
               elsif Cmd = "CDUP" then
                  Do_Cwd ("..");
               elsif Cmd = "PASV" then
                  Do_Pasv;
               elsif Cmd = "LIST" then
                  Do_List (Arg, Long => True);
               elsif Cmd = "NLST" then
                  Do_List (Arg, Long => False);
               elsif Cmd = "RETR" then
                  Do_Retr (Arg);
               elsif Cmd = "STOR" then
                  Do_Stor (Arg);
               elsif Cmd = "SIZE" then
                  Do_Size (Arg);
               elsif Cmd = "DELE" then
                  Path_Op (Arg, 'D');
               elsif Cmd = "MKD" or else Cmd = "XMKD" then
                  Path_Op (Arg, 'M');
               elsif Cmd = "RMD" or else Cmd = "XRMD" then
                  Path_Op (Arg, 'R');
               elsif Cmd = "QUIT" then
                  Reply ("221", "bye");
                  exit;
               else
                  Reply ("502", "command not implemented");
               end if;
            end;
         end;
      end loop;
      if Have_Pasv then
         begin
            Close_Socket (Data_Sock);
         exception
            when others =>
               null;
         end;
         Have_Pasv := False;
      end if;
   end Serve_Client;

   ---------------------------------------------------------------------------
   --  Run
   ---------------------------------------------------------------------------

   procedure Run
     (Local_IP    : String := "";
      Server_Name : String := "Ada ESP32-S3";
      Port        : GNAT.Sockets.Port_Type := 21;
      Data_Port   : GNAT.Sockets.Port_Type := 50_000;
      Read_Only   : Boolean := False)
   is
      Listener : Socket_Type;
      Peer     : Sock_Addr_Type;
      Derive   : constant Boolean := Local_IP'Length = 0;

      --  Record the dotted-decimal address PASV will advertise.
      procedure Set_Host (S : String) is
      begin
         Host_Len := Natural'Min (S'Length, 15);
         Host_IP (1 .. Host_Len) := S (S'First .. S'First + Host_Len - 1);
      end Set_Host;
   begin
      RO := Read_Only;
      DPort := Data_Port;
      Name_Len := Natural'Min (Server_Name'Length, 64);
      Name (1 .. Name_Len) := Server_Name (Server_Name'First .. Server_Name'First + Name_Len - 1);
      if not Derive then
         Set_Host (Local_IP);
      end if;

      loop
         Create_Socket (Listener, Family_Inet, Socket_Stream);
         Bind_Socket (Listener, (Family => Family_Inet, Addr => Any_Inet_Addr, Port => Port));
         Listen_Socket (Listener);
         Accept_Socket (Listener, Ctrl, Peer);     --  Ctrl becomes the connection
         Ctrl_Peer := Peer;                         --  remember for the data-peer check
         --  Idle timeout on the control connection: without it a client that
         --  vanishes without a FIN (power loss, upstream drop) wedges this
         --  single-client server forever.  A control receive that blocks past the
         --  timeout raises Socket_Error, which Serve_Client's handler turns into a
         --  clean session close so the next client can connect.  (Standard FTP
         --  idle-timeout behaviour.)
         begin
            Set_Socket_Option
              (Ctrl, Socket_Level, (Name => Receive_Timeout, Timeout => 300.0));
         exception
            when others =>
               null;
         end;
         --  No IP given: PASV advertises the address the client reached us on.
         if Derive then
            Set_Host (Image (Get_Socket_Name (Ctrl).Addr));
         end if;
         begin
            Serve_Client;
         exception
            when others =>
               null;                    --  one bad client never kills us
         end;
         begin
            Close_Socket (Ctrl);
         exception
            when others =>
               null;
         end;
      end loop;
   end Run;

end FTP_Server;
