with Ada.Streams;   use Ada.Streams;
with GNAT.Sockets;  use GNAT.Sockets;

package body FTP_Client is

   subtype SEA is Stream_Element_Array;
   subtype SEO is Stream_Element_Offset;

   CR : constant Stream_Element := 13;
   LF : constant Stream_Element := 10;

   Data_Chunk : constant := 1024;     --  per-read data-connection scratch size

   ---------------------------------------------------------------------------
   --  Low-level I/O on a socket
   ---------------------------------------------------------------------------

   --  Send every byte of Data (looping over partial sends); OK False on error.
   procedure Send_All (Sock : Socket_Type; Data : SEA; OK : out Boolean) is
      Last : SEO;
      Pos  : SEO := Data'First;
   begin
      while Pos <= Data'Last loop
         Send_Socket (Sock, Data (Pos .. Data'Last), Last);
         exit when Last < Pos;          --  nothing accepted -> give up
         Pos := Last + 1;
      end loop;
      OK := Pos > Data'Last;
   exception
      when Socket_Error => OK := False;
   end Send_All;

   --  Send one control line (Text followed by CRLF) on the control connection.
   procedure Send_Line (S : in out Session; Text : String; OK : out Boolean) is
      Buf : SEA (1 .. SEO (Text'Length) + 2);
   begin
      for I in Text'Range loop
         Buf (SEO (I - Text'First + 1)) := Stream_Element (Character'Pos (Text (I)));
      end loop;
      Buf (Buf'Last - 1) := CR;
      Buf (Buf'Last)     := LF;
      Send_All (S.Control, Buf, OK);
   end Send_Line;

   --  Read one CRLF-terminated line from the control connection into Line (CR/LF
   --  stripped).  Refills the session buffer via Receive_Socket as needed; a peer
   --  close becomes Connect_Failed, a Receive timeout becomes Timed_Out.
   procedure Get_Line (S    : in out Session;
                       Line : out String;
                       Last : out Natural;
                       St   : out Status)
   is
      N : Natural := 0;
      C : Interfaces.Unsigned_8;
   begin
      St   := OK;
      Last := 0;
      loop
         if S.Head >= S.Tail then                 --  buffer empty: refill
            declare
               Scratch : SEA (0 .. SEO (In_Buf_Last));
               RLast   : SEO;
            begin
               Receive_Socket (S.Control, Scratch, RLast);
               if RLast < Scratch'First then       --  control connection closed
                  St := Connect_Failed;
                  return;
               end if;
               S.Head := 0;
               S.Tail := Natural (RLast - Scratch'First + 1);
               for I in 0 .. S.Tail - 1 loop
                  S.Buf (I) := Interfaces.Unsigned_8 (Scratch (Scratch'First + SEO (I)));
               end loop;
            end;
         end if;

         C := S.Buf (S.Head);
         S.Head := S.Head + 1;
         if Stream_Element (C) = LF then
            Last := N;
            return;
         elsif Stream_Element (C) /= CR then
            if N < Line'Length then
               N := N + 1;
               Line (Line'First + N - 1) := Character'Val (Natural (C));
            end if;                                --  else drop (over-long line)
         end if;
      end loop;
   exception
      when Socket_Error => St := Timed_Out;
   end Get_Line;

   ---------------------------------------------------------------------------
   --  FTP replies
   ---------------------------------------------------------------------------

   --  The 3-digit reply code at the start of Line, or -1 if absent.
   function Code_Of (Line : String; Last : Natural) return Integer is
      F : constant Natural := Line'First;
   begin
      if Last >= 3
        and then (for all I in F .. F + 2 => Line (I) in '0' .. '9')
      then
         return (Character'Pos (Line (F))     - Character'Pos ('0')) * 100
              + (Character'Pos (Line (F + 1)) - Character'Pos ('0')) * 10
              + (Character'Pos (Line (F + 2)) - Character'Pos ('0'));
      else
         return -1;
      end if;
   end Code_Of;

   --  A reply line "NNN-" opens a multi-line reply that ends at the next "NNN "
   --  with the same code.
   function Is_Mid_Multiline (Line : String; Last : Natural) return Boolean is
     (Last >= 4 and then Line (Line'First + 3) = '-');

   function Is_Final_Line (Line : String; Last, Code : Natural) return Boolean is
     (Code_Of (Line, Last) = Code
      and then (Last < 4 or else Line (Line'First + 3) = ' '));

   --  Read a whole reply (consuming any continuation lines); return its code.
   procedure Read_Reply (S : in out Session; Code : out Integer; St : out Status)
   is
      Line  : String (1 .. 256);
      Last  : Natural;
      First : Integer;
   begin
      Get_Line (S, Line, Last, St);
      if St /= OK then Code := -1; return; end if;
      First := Code_Of (Line, Last);
      if First < 0 then St := Protocol_Error; Code := -1; return; end if;
      if Is_Mid_Multiline (Line, Last) then
         loop
            Get_Line (S, Line, Last, St);
            if St /= OK then Code := -1; return; end if;
            exit when Is_Final_Line (Line, Last, First);
         end loop;
      end if;
      Code := First;
   end Read_Reply;

   --  Send a command and read its reply code.
   procedure Command (S    : in out Session;
                      Text : String;
                      Code : out Integer;
                      St   : out Status)
   is
      Sent : Boolean;
   begin
      Send_Line (S, Text, Sent);
      if not Sent then Code := -1; St := Connect_Failed; return; end if;
      Read_Reply (S, Code, St);
   end Command;

   --  Send a command and return its first reply line (for replies we must parse,
   --  e.g. PASV and SIZE); drains any continuation lines.
   procedure Command_Line (S    : in out Session;
                           Text : String;
                           Code : out Integer;
                           Line : out String;
                           Last : out Natural;
                           St   : out Status)
   is
      Sent : Boolean;
   begin
      Send_Line (S, Text, Sent);
      if not Sent then Code := -1; Last := 0; St := Connect_Failed; return; end if;
      Get_Line (S, Line, Last, St);
      if St /= OK then Code := -1; return; end if;
      Code := Code_Of (Line, Last);
      if Code < 0 then St := Protocol_Error; return; end if;
      if Is_Mid_Multiline (Line, Last) then
         declare
            L2 : String (1 .. 256);
            N2 : Natural;
         begin
            loop
               Get_Line (S, L2, N2, St);
               exit when St /= OK or else Is_Final_Line (L2, N2, Code);
            end loop;
         end;
      end if;
   end Command_Line;

   --  Map a simple-command reply (expecting 2xx) to a Status.
   function Simple_Result (Code : Integer; St : Status) return Status is
   begin
      if St /= OK then return St;
      elsif Code in 200 .. 299 then return OK;
      elsif Code in 400 .. 599 then return Server_Error;
      else return Protocol_Error;
      end if;
   end Simple_Result;

   ---------------------------------------------------------------------------
   --  Passive data connection
   ---------------------------------------------------------------------------

   --  Issue PASV, parse the advertised port, and open the data connection.  The
   --  advertised IP is intentionally ignored -- the data connection reuses the
   --  control connection's server IP (S.Host), which is what a NATed server
   --  actually wants and is identical for a direct server.
   procedure Open_Passive (S : in out Session; Data : out Socket_Type; St : out Status)
   is
      Line : String (1 .. 256);
      Last : Natural;
      Code : Integer;
      Nums : array (1 .. 6) of Natural := (others => 0);
      Slot : Natural := 1;
      I    : Natural;
   begin
      Command_Line (S, "PASV", Code, Line, Last, St);
      if St /= OK then return; end if;
      if Code /= 227 then
         St := (if Code in 400 .. 599 then Server_Error else Protocol_Error);
         return;
      end if;

      --  Parse the six comma-separated numbers inside the parentheses.
      I := Line'First;
      while I <= Line'First + Last - 1 and then Line (I) /= '(' loop
         I := I + 1;
      end loop;
      if I > Line'First + Last - 1 then St := Protocol_Error; return; end if;
      I := I + 1;
      while I <= Line'First + Last - 1 and then Slot <= 6 loop
         exit when Line (I) = ')';
         if Line (I) in '0' .. '9' then
            Nums (Slot) := Nums (Slot) * 10
                           + (Character'Pos (Line (I)) - Character'Pos ('0'));
         elsif Line (I) = ',' then
            Slot := Slot + 1;
         end if;
         I := I + 1;
      end loop;
      if Slot < 6 then St := Protocol_Error; return; end if;

      declare
         Addr : constant Sock_Addr_Type :=
           (Family => Family_Inet, Addr => S.Host,
            Port   => Port_Type (Nums (5) * 256 + Nums (6)));
      begin
         Create_Socket (Data, Family_Inet, Socket_Stream);
         if S.Timeout > 0.0 then
            Set_Socket_Option
              (Data, Socket_Level, (Name => Receive_Timeout, Timeout => S.Timeout));
         end if;
         Connect_Socket (Data, Addr);
         St := OK;
      exception
         when Socket_Error => St := Data_Failed;
      end;
   end Open_Passive;

   ---------------------------------------------------------------------------
   --  Session
   ---------------------------------------------------------------------------

   procedure Connect (S        : in out Session;
                      Host     : GNAT.Sockets.Inet_Addr_Type;
                      User     : String;
                      Password : String;
                      Result   : out Status;
                      Port     : GNAT.Sockets.Port_Type := 21;
                      Timeout  : Duration               := 0.0)
   is
      Code : Integer;
      St   : Status;
   begin
      S.Open    := False;
      S.Host    := Host;
      S.Timeout := Timeout;
      S.Head    := 0;
      S.Tail    := 0;

      begin
         Create_Socket (S.Control, Family_Inet, Socket_Stream);
         if Timeout > 0.0 then
            Set_Socket_Option
              (S.Control, Socket_Level, (Name => Receive_Timeout, Timeout => Timeout));
         end if;
         Connect_Socket (S.Control, (Family_Inet, Host, Port));
      exception
         when Socket_Error => Result := Connect_Failed; return;
      end;

      Read_Reply (S, Code, St);                 --  greeting
      if St /= OK or else Code /= 220 then
         Close_Socket (S.Control);
         Result := (if St /= OK then St else Connect_Failed);
         return;
      end if;

      Command (S, "USER " & User, Code, St);
      if St /= OK then Close_Socket (S.Control); Result := St; return; end if;
      if Code = 331 then                        --  password required
         Command (S, "PASS " & Password, Code, St);
         if St /= OK then Close_Socket (S.Control); Result := St; return; end if;
      end if;
      if Code not in 200 .. 299 then            --  530 etc.
         Close_Socket (S.Control);
         Result := Auth_Failed;
         return;
      end if;

      Command (S, "TYPE I", Code, St);          --  binary
      if Simple_Result (Code, St) /= OK then
         Close_Socket (S.Control);
         Result := (if St /= OK then St else Server_Error);
         return;
      end if;

      S.Open := True;
      Result := OK;
   end Connect;

   procedure Quit (S : in out Session) is
      Code : Integer;
      St   : Status;
      Sent : Boolean;
   begin
      if not S.Open then return; end if;
      Send_Line (S, "QUIT", Sent);
      if Sent then Read_Reply (S, Code, St); end if;   --  best effort
      Close_Socket (S.Control);
      S.Open := False;
   exception
      when Socket_Error =>
         begin
            Close_Socket (S.Control);
         exception
            when others => null;
         end;
         S.Open := False;
   end Quit;

   function Is_Open (S : Session) return Boolean is (S.Open);

   --  Set the final Result and, when the failure may have left the control stream
   --  closed, hung or out of sync, tear the session down so Is_Open is truthful.
   --  Only OK and Server_Error (a complete 4xx/5xx reply -- the link is fine, the
   --  server just refused) keep the session; every other failure (Connect_Failed,
   --  Timed_Out, Protocol_Error, Data_Failed, Auth_Failed) drops it.  Recover with
   --  a fresh Connect.
   procedure Finish (S : in out Session; St : Status; Result : out Status) is
   begin
      if S.Open and then St not in OK | Server_Error | Not_Connected then
         begin
            Close_Socket (S.Control);
         exception
            when Socket_Error => null;
         end;
         S.Open := False;
      end if;
      Result := St;
   end Finish;

   ---------------------------------------------------------------------------
   --  Transfers
   ---------------------------------------------------------------------------

   --  Shared by Retrieve and List: open a passive data connection, issue Cmd,
   --  stream the data to Sink until the server closes, then read the final reply.
   procedure Stream_In (S      : in out Session;
                        Cmd    : String;
                        Sink   : Data_Sink;
                        Ctx    : System.Address;
                        Result : out Status)
   is
      Data    : Socket_Type;
      St      : Status;
      Code    : Integer;
      Scratch : SEA (0 .. SEO (Data_Chunk - 1));
      RLast   : SEO;
   begin
      if not S.Open then Result := Not_Connected; return; end if;

      Open_Passive (S, Data, St);
      if St /= OK then Finish (S, St, Result); return; end if;

      Command (S, Cmd, Code, St);
      if St /= OK then Close_Socket (Data); Finish (S, St, Result); return; end if;
      if Code not in 100 .. 199 then            --  expect 150 / 125
         Close_Socket (Data);
         Finish (S, (if Code in 400 .. 599 then Server_Error else Protocol_Error),
                 Result);
         return;
      end if;

      loop
         begin
            Receive_Socket (Data, Scratch, RLast);
         exception
            when Socket_Error =>
               Close_Socket (Data); Finish (S, Timed_Out, Result); return;
         end;
         exit when RLast < Scratch'First;       --  EOF (server closed)
         declare
            Chunk : Byte_Array (0 .. Natural (RLast - Scratch'First));
         begin
            for J in Chunk'Range loop
               Chunk (J) := Interfaces.Unsigned_8 (Scratch (Scratch'First + SEO (J)));
            end loop;
            Sink (Ctx, Chunk);
         end;
      end loop;
      Close_Socket (Data);

      Read_Reply (S, Code, St);                 --  expect 226 / 250
      Finish (S, (if St /= OK then St
                  elsif Code in 200 .. 299 then OK
                  elsif Code in 400 .. 599 then Server_Error
                  else Protocol_Error),
              Result);
   end Stream_In;

   procedure Retrieve (S      : in out Session;
                       Path   : String;
                       Sink   : Data_Sink;
                       Ctx    : System.Address;
                       Result : out Status) is
   begin
      Stream_In (S, "RETR " & Path, Sink, Ctx, Result);
   end Retrieve;

   procedure List (S      : in out Session;
                   Sink   : Data_Sink;
                   Ctx    : System.Address;
                   Result : out Status;
                   Path   : String := "") is
   begin
      if Path = "" then
         Stream_In (S, "NLST", Sink, Ctx, Result);
      else
         Stream_In (S, "NLST " & Path, Sink, Ctx, Result);
      end if;
   end List;

   procedure Store (S      : in out Session;
                    Path   : String;
                    Source : Data_Source;
                    Ctx    : System.Address;
                    Result : out Status)
   is
      Data : Socket_Type;
      St   : Status;
      Code : Integer;
      Buf  : Byte_Array (0 .. Data_Chunk - 1);
      Last : Natural;
      Sent : Boolean;
   begin
      if not S.Open then Result := Not_Connected; return; end if;

      Open_Passive (S, Data, St);
      if St /= OK then Finish (S, St, Result); return; end if;

      Command (S, "STOR " & Path, Code, St);
      if St /= OK then Close_Socket (Data); Finish (S, St, Result); return; end if;
      if Code not in 100 .. 199 then
         Close_Socket (Data);
         Finish (S, (if Code in 400 .. 599 then Server_Error else Protocol_Error),
                 Result);
         return;
      end if;

      loop
         Source (Ctx, Buf, Last);
         exit when Last = 0;
         declare
            Out_Buf : SEA (0 .. SEO (Last - 1));
         begin
            for J in 0 .. Last - 1 loop
               Out_Buf (SEO (J)) := Stream_Element (Buf (Buf'First + J));
            end loop;
            Send_All (Data, Out_Buf, Sent);
         end;
         if not Sent then
            Close_Socket (Data); Finish (S, Data_Failed, Result); return;
         end if;
      end loop;
      Close_Socket (Data);                      --  EOF to the server

      Read_Reply (S, Code, St);
      Finish (S, (if St /= OK then St
                  elsif Code in 200 .. 299 then OK
                  elsif Code in 400 .. 599 then Server_Error
                  else Protocol_Error),
              Result);
   end Store;

   ---------------------------------------------------------------------------
   --  Simple commands
   ---------------------------------------------------------------------------

   procedure Simple (S : in out Session; Text : String; Result : out Status) is
      Code : Integer;
      St   : Status;
   begin
      if not S.Open then Result := Not_Connected; return; end if;
      Command (S, Text, Code, St);
      Finish (S, Simple_Result (Code, St), Result);
   end Simple;

   procedure Change_Dir (S : in out Session; Path : String; Result : out Status) is
   begin
      Simple (S, "CWD " & Path, Result);
   end Change_Dir;

   procedure Make_Dir (S : in out Session; Path : String; Result : out Status) is
   begin
      Simple (S, "MKD " & Path, Result);
   end Make_Dir;

   procedure Remove_Dir (S : in out Session; Path : String; Result : out Status) is
   begin
      Simple (S, "RMD " & Path, Result);
   end Remove_Dir;

   procedure Delete_File (S : in out Session; Path : String; Result : out Status) is
   begin
      Simple (S, "DELE " & Path, Result);
   end Delete_File;

   procedure File_Size (S      : in out Session;
                        Path   : String;
                        Size   : out Natural;
                        Result : out Status)
   is
      Line : String (1 .. 256);
      Last : Natural;
      Code : Integer;
      St   : Status;
   begin
      Size := 0;
      if not S.Open then Result := Not_Connected; return; end if;
      Command_Line (S, "SIZE " & Path, Code, Line, Last, St);
      if St /= OK then Finish (S, St, Result); return; end if;
      if Code = 213 then
         for I in Line'First + 4 .. Line'First + Last - 1 loop
            if Line (I) in '0' .. '9' then
               Size := Size * 10 + (Character'Pos (Line (I)) - Character'Pos ('0'));
            end if;
         end loop;
         Finish (S, OK, Result);
      elsif Code in 400 .. 599 then
         Finish (S, Server_Error, Result);
      else
         Finish (S, Protocol_Error, Result);
      end if;
   end File_Size;

end FTP_Client;
