with Ada.Streams;          use Ada.Streams;
with GNAT.Sockets;         use GNAT.Sockets;
with Interfaces;           use Interfaces;
with ESP32S3.Ext4;
with ESP32S3.Ext4.Inode;

package body FTP_Server is

   package E4  renames ESP32S3.Ext4;
   package FSP renames ESP32S3.Ext4.FS;
   use type E4.Inode_Number;

   subtype SEA is Stream_Element_Array;
   subtype SEO is Stream_Element_Offset;

   CR : constant Stream_Element := 13;
   LF : constant Stream_Element := 10;
   Data_Chunk : constant := 1024;

   ---------------------------------------------------------------------------
   --  Session state -- one client at a time, so library-level globals are fine
   --  (Iterate's Visit callback has no Ctx, which forces this anyway).
   ---------------------------------------------------------------------------

   Mnt      : access FSP.Mount;
   RO       : Boolean   := False;
   DPort    : Port_Type := 50_000;
   Host_IP  : String (1 .. 15);            --  dotted IP advertised in PASV
   Host_Len : Natural := 0;

   Ctrl     : Socket_Type;                 --  the control connection
   Cwd      : String (1 .. 1024);          --  current directory (absolute)
   Cwd_Len  : Natural := 1;

   In_Buf   : SEA (0 .. 1023);             --  control-line reassembly
   In_Head  : Natural := 0;
   In_Tail  : Natural := 0;

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
      when Socket_Error => null;
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
      N : Natural := 0;
      C : Stream_Element;
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
         C := In_Buf (SEO (In_Head));
         In_Head := In_Head + 1;
         if C = LF then
            Last := N;
            return True;
         elsif C /= CR then
            if N < Line'Length then
               N := N + 1;
               Line (Line'First + N - 1) := Character'Val (Natural (C));
            end if;
         end if;
      end loop;
   exception
      when Socket_Error => return False;
   end Get_Line;

   ---------------------------------------------------------------------------
   --  Small text helpers
   ---------------------------------------------------------------------------

   function Upper (S : String) return String is
      R : String := S;
   begin
      for I in R'Range loop
         if R (I) in 'a' .. 'z' then
            R (I) := Character'Val (Character'Pos (R (I)) - 32);
         end if;
      end loop;
      return R;
   end Upper;

   function Img (N : Natural) return String is
      S : constant String := Natural'Image (N);
   begin
      return S (S'First + 1 .. S'Last);
   end Img;

   --  Normalised absolute path of Arg, resolved against Cwd (handles "/", "..",
   --  ".", "//", trailing "/").  Result has no trailing slash except "/".
   function Abs_Path (Arg : String) return String is
      Raw  : String (1 .. Cwd_Len + Arg'Length + 2);
      RLen : Natural := 0;
      Out_S : String (1 .. Raw'Length);
      OLen  : Natural := 0;
      I     : Natural;
   begin
      if Arg'Length > 0 and then Arg (Arg'First) = '/' then
         Raw (1 .. Arg'Length) := Arg;  RLen := Arg'Length;
      else
         Raw (1 .. Cwd_Len) := Cwd (1 .. Cwd_Len);  RLen := Cwd_Len;
         if RLen = 0 or else Raw (RLen) /= '/' then
            RLen := RLen + 1;  Raw (RLen) := '/';
         end if;
         Raw (RLen + 1 .. RLen + Arg'Length) := Arg;  RLen := RLen + Arg'Length;
      end if;

      --  Walk components, applying . and ..
      OLen := 1;  Out_S (1) := '/';
      I := 1;
      while I <= RLen loop
         while I <= RLen and then Raw (I) = '/' loop I := I + 1; end loop;
         declare
            Start : constant Natural := I;
         begin
            while I <= RLen and then Raw (I) /= '/' loop I := I + 1; end loop;
            declare
               Comp : constant String := Raw (Start .. I - 1);
            begin
               if Comp = "" or else Comp = "." then
                  null;
               elsif Comp = ".." then
                  while OLen > 1 and then Out_S (OLen) /= '/' loop OLen := OLen - 1; end loop;
                  if OLen > 1 then OLen := OLen - 1; end if;   --  drop the slash
                  if OLen = 0 then OLen := 1; Out_S (1) := '/'; end if;
               else
                  if OLen = 0 or else Out_S (OLen) /= '/' then
                     OLen := OLen + 1; Out_S (OLen) := '/';
                  end if;
                  Out_S (OLen + 1 .. OLen + Comp'Length) := Comp;
                  OLen := OLen + Comp'Length;
               end if;
            end;
         end;
      end loop;
      return Out_S (1 .. OLen);
   end Abs_Path;

   --  Split an absolute path into (parent dir, last name).
   procedure Split (Path : String; Dir : out String; Dir_Len : out Natural;
                    Name : out String; Name_Len : out Natural) is
      Slash : Natural := Path'First;
   begin
      for I in Path'Range loop
         if Path (I) = '/' then Slash := I; end if;
      end loop;
      Name_Len := Path'Last - Slash;
      Name (Name'First .. Name'First + Name_Len - 1) := Path (Slash + 1 .. Path'Last);
      if Slash = Path'First then
         Dir_Len := 1; Dir (Dir'First) := '/';
      else
         Dir_Len := Slash - Path'First;
         Dir (Dir'First .. Dir'First + Dir_Len - 1) := Path (Path'First .. Slash - 1);
      end if;
   end Split;

   ---------------------------------------------------------------------------
   --  Passive data connection
   ---------------------------------------------------------------------------

   --  Open the data listener and tell the client where to connect (PASV).
   procedure Do_Pasv is
      P1 : constant Natural := Natural (DPort) / 256;
      P2 : constant Natural := Natural (DPort) mod 256;
      H  : String := Host_IP (1 .. Host_Len);
   begin
      if Have_Pasv then
         begin Close_Socket (Data_Sock); exception when others => null; end;
      end if;
      Create_Socket (Data_Sock, Family_Inet, Socket_Stream);
      Bind_Socket   (Data_Sock, (Family => Family_Inet,
                                 Addr => Any_Inet_Addr, Port => DPort));
      Listen_Socket (Data_Sock);
      Have_Pasv := True;
      --  227 wants the IP with commas: a.b.c.d -> a,b,c,d
      for I in H'Range loop
         if H (I) = '.' then H (I) := ','; end if;
      end loop;
      Reply ("227", "Entering Passive Mode (" & H & "," & Img (P1) & "," & Img (P2) & ")");
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
      return True;
   exception
      when Socket_Error =>
         Reply ("425", "data connection failed");
         Have_Pasv := False;
         return False;
   end Accept_Data;

   procedure Close_Data (Conn : in out Socket_Type) is
   begin
      begin Close_Socket (Conn); exception when others => null; end;
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
   Entries   : array (1 .. Max_Entries) of Entry_Rec;
   N_Entries : Natural := 0;

   procedure Record_Entry (Name : String; Ino : E4.Inode_Number; File_Type : E4.U8) is
      pragma Unreferenced (File_Type);
   begin
      if Name = "." or else Name = ".." then return; end if;
      if N_Entries < Max_Entries then
         N_Entries := N_Entries + 1;
         Entries (N_Entries).Len := Natural'Min (Name'Length, 255);
         Entries (N_Entries).Name (1 .. Entries (N_Entries).Len) :=
           Name (Name'First .. Name'First + Entries (N_Entries).Len - 1);
         Entries (N_Entries).Ino := Ino;
      end if;
   end Record_Entry;

   procedure Do_List (Arg : String; Long : Boolean) is
      Conn : Socket_Type;
      Path : constant String := Abs_Path (Arg);
      Dir  : E4.Inode.Info;
   begin
      begin
         FSP.Stat (Mnt.all, FSP.Lookup (Mnt.all, Path), Dir);
      exception
         when others => Reply ("550", "no such directory"); return;
      end;
      if not E4.Inode.Is_Dir (Dir) then
         Reply ("550", "not a directory"); return;
      end if;

      N_Entries := 0;
      FSP.Iterate (Mnt.all, Dir, Record_Entry'Access);

      if not Accept_Data (Conn) then return; end if;
      for K in 1 .. N_Entries loop
         declare
            Nm   : constant String := Entries (K).Name (1 .. Entries (K).Len);
            Info : E4.Inode.Info;
            Line : String (1 .. 320);
            L    : Natural := 0;
            procedure Put (S : String) is
            begin Line (L + 1 .. L + S'Length) := S; L := L + S'Length; end Put;
         begin
            FSP.Stat (Mnt.all, Entries (K).Ino, Info);
            if Long then
               if E4.Inode.Is_Dir (Info) then Put ("drwxr-xr-x");
               elsif E4.Inode.Is_Symlink (Info) then Put ("lrwxrwxrwx");
               else Put ("-rw-r--r--");
               end if;
               Put (" 1 ftp ftp ");
               Put (Img (Natural (Info.Size)));
               Put (" Jan  1 00:00 ");
            end if;
            Put (Nm);
            Put (Character'Val (13) & Character'Val (10));
            declare
               B : SEA (1 .. SEO (L));
            begin
               for I in 1 .. L loop
                  B (SEO (I)) := Stream_Element (Character'Pos (Line (I)));
               end loop;
               Send_All (Conn, B);
            end;
         end;
      end loop;
      Close_Data (Conn);
      Reply ("226", "directory send OK");
   end Do_List;

   ---------------------------------------------------------------------------
   --  RETR / STOR
   ---------------------------------------------------------------------------

   procedure Do_Retr (Arg : String) is
      Conn   : Socket_Type;
      Path   : constant String := Abs_Path (Arg);
      Info   : E4.Inode.Info;
      Offset : Interfaces.Unsigned_64 := 0;
      Buf    : E4.Byte_Array (0 .. Data_Chunk - 1);
      Last   : Natural;
   begin
      begin
         FSP.Stat (Mnt.all, FSP.Lookup (Mnt.all, Path), Info);
      exception
         when others => Reply ("550", "no such file"); return;
      end;
      if not E4.Inode.Is_Reg (Info) then
         Reply ("550", "not a regular file"); return;
      end if;
      if not Accept_Data (Conn) then return; end if;
      loop
         FSP.Read_File (Mnt.all, Info, Offset, Buf, Last);
         exit when Last = 0;
         declare
            B : SEA (0 .. SEO (Last - 1));
         begin
            for I in 0 .. Last - 1 loop
               B (SEO (I)) := Stream_Element (Buf (I));
            end loop;
            Send_All (Conn, B);
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
      Dir      : String (1 .. 1024);  Dir_Len  : Natural;
      Name     : String (1 .. 255);   Name_Len : Natural;
      Ino      : E4.Inode_Number;
      Scratch  : SEA (0 .. Data_Chunk - 1);
      RLast    : SEO;
   begin
      if RO then Reply ("532", "read-only server"); return; end if;
      Split (Path, Dir, Dir_Len, Name, Name_Len);
      --  Overwrite: truncate an existing file, else create it.
      begin
         Ino := FSP.Lookup (Mnt.all, Path);
         FSP.Truncate (Mnt.all, Ino, 0);
      exception
         when others =>
            Ino := FSP.Create_File (Mnt.all, Dir (1 .. Dir_Len), Name (1 .. Name_Len));
      end;
      if not Accept_Data (Conn) then return; end if;
      loop
         begin
            Receive_Socket (Conn, Scratch, RLast);
         exception
            when Socket_Error => exit;
         end;
         exit when RLast < Scratch'First;     --  EOF
         declare
            D : E4.Byte_Array (0 .. Natural (RLast - Scratch'First));
         begin
            for I in D'Range loop
               D (I) := E4.U8 (Scratch (Scratch'First + SEO (I)));
            end loop;
            FSP.Append (Mnt.all, Ino, D);
         end;
      end loop;
      Close_Data (Conn);
      FSP.Commit (Mnt.all);
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
      Info : E4.Inode.Info;
   begin
      FSP.Stat (Mnt.all, FSP.Lookup (Mnt.all, Path), Info);
      if E4.Inode.Is_Dir (Info) then
         Cwd_Len := Path'Length;
         Cwd (1 .. Cwd_Len) := Path;
         Reply ("250", "directory changed");
      else
         Reply ("550", "not a directory");
      end if;
   exception
      when others => Reply ("550", "no such directory");
   end Do_Cwd;

   procedure Do_Size (Arg : String) is
      Info : E4.Inode.Info;
   begin
      FSP.Stat (Mnt.all, FSP.Lookup (Mnt.all, Abs_Path (Arg)), Info);
      if E4.Inode.Is_Reg (Info) then
         Reply ("213", Img (Natural (Info.Size)));
      else
         Reply ("550", "not a regular file");
      end if;
   exception
      when others => Reply ("550", "no such file");
   end Do_Size;

   --  MKD / RMD / DELE share the split-and-act shape.
   procedure Path_Op (Arg : String; Op : Character) is
      Path : constant String := Abs_Path (Arg);
      Dir  : String (1 .. 1024);  Dir_Len  : Natural;
      Name : String (1 .. 255);   Name_Len : Natural;
   begin
      if RO then Reply ("532", "read-only server"); return; end if;
      Split (Path, Dir, Dir_Len, Name, Name_Len);
      case Op is
         when 'M' => FSP.Mkdir  (Mnt.all, Dir (1 .. Dir_Len), Name (1 .. Name_Len));
         when 'R' => FSP.Rmdir  (Mnt.all, Dir (1 .. Dir_Len), Name (1 .. Name_Len));
         when others => FSP.Unlink (Mnt.all, Dir (1 .. Dir_Len), Name (1 .. Name_Len));
      end case;
      FSP.Commit (Mnt.all);
      if Op = 'M' then
         Reply ("257", """" & Path & """ created");
      else
         Reply ("250", "done");
      end if;
   exception
      when others => Reply ("550", "operation failed");
   end Path_Op;

   ---------------------------------------------------------------------------
   --  The command loop for one client
   ---------------------------------------------------------------------------

   procedure Serve_Client is
      Line : String (1 .. 1024);
      Last : Natural;
   begin
      In_Head := 0; In_Tail := 0; Have_Pasv := False;
      Cwd_Len := 1; Cwd (1) := '/';
      Reply ("220", "ESP32-S3 ext4 FTP");
      loop
         exit when not Get_Line (Line, Last);
         declare
            L   : constant String := Line (1 .. Last);
            Sp  : Natural := 0;
         begin
            for I in L'Range loop
               if L (I) = ' ' then Sp := I; exit; end if;
            end loop;
            declare
               Cmd : constant String := Upper (if Sp = 0 then L else L (L'First .. Sp - 1));
               Arg : constant String := (if Sp = 0 then "" else L (Sp + 1 .. L'Last));
            begin
               if    Cmd = "USER" then Reply ("331", "send any password");
               elsif Cmd = "PASS" then Reply ("230", "logged in (anonymous)");
               elsif Cmd = "SYST" then Reply ("215", "UNIX Type: L8");
               elsif Cmd = "FEAT" then Reply ("211", "no features");
               elsif Cmd = "TYPE" then Reply ("200", "type set");
               elsif Cmd = "NOOP" then Reply ("200", "ok");
               elsif Cmd = "OPTS" then Reply ("200", "ok");
               elsif Cmd = "PWD" or else Cmd = "XPWD" then
                  Reply ("257", """" & Cwd (1 .. Cwd_Len) & """");
               elsif Cmd = "CWD"  then Do_Cwd (Arg);
               elsif Cmd = "CDUP" then Do_Cwd ("..");
               elsif Cmd = "PASV" then Do_Pasv;
               elsif Cmd = "LIST" then Do_List (Arg, Long => True);
               elsif Cmd = "NLST" then Do_List (Arg, Long => False);
               elsif Cmd = "RETR" then Do_Retr (Arg);
               elsif Cmd = "STOR" then Do_Stor (Arg);
               elsif Cmd = "SIZE" then Do_Size (Arg);
               elsif Cmd = "DELE" then Path_Op (Arg, 'D');
               elsif Cmd = "MKD" or else Cmd = "XMKD" then Path_Op (Arg, 'M');
               elsif Cmd = "RMD" or else Cmd = "XRMD" then Path_Op (Arg, 'R');
               elsif Cmd = "QUIT" then Reply ("221", "bye"); exit;
               else Reply ("502", "command not implemented");
               end if;
            end;
         end;
      end loop;
      if Have_Pasv then
         begin Close_Socket (Data_Sock); exception when others => null; end;
         Have_Pasv := False;
      end if;
   end Serve_Client;

   ---------------------------------------------------------------------------
   --  Run
   ---------------------------------------------------------------------------

   procedure Run
     (FS        : not null access ESP32S3.Ext4.FS.Mount;
      Local_IP  : String;
      Port      : GNAT.Sockets.Port_Type := 21;
      Data_Port : GNAT.Sockets.Port_Type := 50_000;
      Read_Only : Boolean := False)
   is
      Listener : Socket_Type;
      Peer     : Sock_Addr_Type;
   begin
      Mnt      := FS;
      RO       := Read_Only;
      DPort    := Data_Port;
      Host_Len := Natural'Min (Local_IP'Length, 15);
      Host_IP (1 .. Host_Len) := Local_IP (Local_IP'First .. Local_IP'First + Host_Len - 1);

      loop
         Create_Socket (Listener, Family_Inet, Socket_Stream);
         Bind_Socket   (Listener, (Family => Family_Inet,
                                   Addr => Any_Inet_Addr, Port => Port));
         Listen_Socket (Listener);
         Accept_Socket (Listener, Ctrl, Peer);     --  Ctrl becomes the connection
         begin
            Serve_Client;
         exception
            when others => null;                    --  one bad client never kills us
         end;
         begin Close_Socket (Ctrl); exception when others => null; end;
      end loop;
   end Run;

end FTP_Server;
