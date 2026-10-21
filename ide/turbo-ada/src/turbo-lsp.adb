with Ada.Calendar;
with Ada.Characters.Handling;
with Ada.Containers.Indefinite_Vectors;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with GNAT.Expect;
with GNAT.OS_Lib;
with Turbo.Term;

package body Turbo.LSP is

   use Ada.Strings.Unbounded;
   use Turbo.JSON;
   use type Ada.Calendar.Time;
   use type GNAT.OS_Lib.String_Access;

   package String_Vectors is new Ada.Containers.Indefinite_Vectors (Positive, String);
   package Version_Maps is new Ada.Containers.Indefinite_Ordered_Maps (String, Integer);
   use type String_Vectors.Vector;

   --  Messages from the reader task to the main loop.

   protected Inbox is
      procedure Put (Msg : String);
      procedure Take (Msg : out Unbounded_String; Found : out Boolean);
      procedure Set_Closed (Closed : Boolean);
      function Closed return Boolean;
      procedure Clear;
   private
      Queue     : String_Vectors.Vector;
      Is_Closed : Boolean := True;
   end Inbox;

   protected body Inbox is
      procedure Put (Msg : String) is
      begin
         Queue.Append (Msg);
      end Put;

      procedure Take (Msg : out Unbounded_String; Found : out Boolean) is
      begin
         Found := not Queue.Is_Empty;
         if Found then
            Msg := To_Unbounded_String (Queue.First_Element);
            Queue.Delete_First;
         end if;
      end Take;

      procedure Set_Closed (Closed : Boolean) is
      begin
         Is_Closed := Closed;
      end Set_Closed;

      function Closed return Boolean is (Is_Closed);

      procedure Clear is
      begin
         Queue.Clear;
      end Clear;
   end Inbox;

   --  The reader: blocking reads on the server's stdout, split into
   --  messages by their Content-Length headers.  Anything that is not a
   --  message (the server's stderr shares the pipe) is skipped.

   task Reader is
      entry Start (Fd : GNAT.OS_Lib.File_Descriptor);
   end Reader;

   task body Reader is
      Input : GNAT.OS_Lib.File_Descriptor;
      Buf   : String (1 .. 65536);
      N     : Integer;
      Acc   : Unbounded_String;
      Header : constant String := "Content-Length:";
   begin
      loop
         select
            accept Start (Fd : GNAT.OS_Lib.File_Descriptor) do
               Input := Fd;
            end Start;
         or
            terminate;
         end select;
         Acc := Null_Unbounded_String;
         loop
            N := GNAT.OS_Lib.Read (Input, Buf'Address, Buf'Length);
            exit when N <= 0;
            Append (Acc, Buf (1 .. N));
            loop
               declare
                  H : constant Natural := Index (Acc, Header);
               begin
                  if H = 0 then
                     --  Junk with no header: keep only a tail that might be
                     --  the start of one.
                     if Length (Acc) > Header'Length then
                        Delete (Acc, 1, Length (Acc) - Header'Length);
                     end if;
                     exit;
                  end if;
                  if H > 1 then
                     Delete (Acc, 1, H - 1);
                  end if;
                  declare
                     Blank : constant Natural :=
                       Index (Acc, ASCII.CR & ASCII.LF & ASCII.CR & ASCII.LF);
                  begin
                     exit when Blank = 0;
                     declare
                        Line_End : constant Natural := Index (Acc, ASCII.CR & ASCII.LF);
                        Len      : Natural;
                     begin
                        Len := Natural'Value
                          (Ada.Strings.Fixed.Trim
                             (Slice (Acc, Header'Length + 1, Line_End - 1),
                              Ada.Strings.Both));
                        exit when Length (Acc) < Blank + 3 + Len;
                        Inbox.Put (Slice (Acc, Blank + 4, Blank + 3 + Len));
                        Delete (Acc, 1, Blank + 3 + Len);
                     exception
                        when Constraint_Error =>
                           --  A malformed header: drop it and resync.
                           Delete (Acc, 1, Blank + 3);
                     end;
                  end;
               end;
            end loop;
         end loop;
         Inbox.Set_Closed (True);
      end loop;
   end Reader;

   --  Server state

   Process   : GNAT.Expect.Process_Descriptor;
   Out_Fd    : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
   The_State : Server_State := Off;
   Error_Msg : Unbounded_String;
   Progress  : Unbounded_String;
   Next_Id   : Natural := 0;
   Open_Docs : Version_Maps.Map;
   Diags     : Path_Maps.Map;
   Changed   : Boolean := False;

   function State return Server_State is
   begin
      if The_State = Running and then Inbox.Closed then
         The_State := Failed;
         Error_Msg := To_Unbounded_String ("the language server stopped");
      end if;
      return The_State;
   end State;

   function Status_Text return String is
     (case State is
         when Off => "",
         when Running =>
           (if Progress = Null_Unbounded_String then "ALS" else "ALS " & To_String (Progress)),
         when Failed => "ALS failed");

   function Last_Error return String is (To_String (Error_Msg));

   --  Paths and URIs

   function URI (Path : String) return String is
      Hex  : constant String := "0123456789ABCDEF";
      R    : Unbounded_String := To_Unbounded_String ("file://");
      P    : String := Path;
   begin
      if Term.Is_Windows then
         for C of P loop
            if C = '\' then
               C := '/';
            end if;
         end loop;
         Append (R, "/");
      end if;
      for C of P loop
         if C in 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '-' | '.' | '_' | '~' | '/'
           | ':'
         then
            Append (R, C);
         else
            Append (R, '%' & Hex (Character'Pos (C) / 16 + 1)
                    & Hex (Character'Pos (C) mod 16 + 1));
         end if;
      end loop;
      return To_String (R);
   end URI;

   function Path_Of (URI : String) return String is
      Prefix : constant String := "file://";
      R      : Unbounded_String;
      I      : Natural;
      function Hex (C : Character) return Natural is
        (case C is
            when '0' .. '9' => Character'Pos (C) - Character'Pos ('0'),
            when 'a' .. 'f' => Character'Pos (C) - Character'Pos ('a') + 10,
            when 'A' .. 'F' => Character'Pos (C) - Character'Pos ('A') + 10,
            when others => 0);
   begin
      if URI'Length < Prefix'Length
        or else URI (URI'First .. URI'First + Prefix'Length - 1) /= Prefix
      then
         return URI;
      end if;
      I := URI'First + Prefix'Length;
      while I <= URI'Last loop
         if URI (I) = '%' and then I + 2 <= URI'Last then
            Append (R, Character'Val (Hex (URI (I + 1)) * 16 + Hex (URI (I + 2))));
            I := I + 3;
         else
            Append (R, URI (I));
            I := I + 1;
         end if;
      end loop;
      if Term.Is_Windows then
         declare
            S : String := To_String (R);
         begin
            for C of S loop
               if C = '/' then
                  C := '\';
               end if;
            end loop;
            --  "\C:\x" -> "C:\x"
            if S'Length > 2 and then S (S'First) = '\' and then S (S'First + 2) = ':' then
               return S (S'First + 1 .. S'Last);
            end if;
            return S;
         end;
      end if;
      return To_String (R);
   end Path_Of;

   function Text_Document (Path : String) return String is
     ("{""uri"":" & Quote (URI (Path)) & "}");

   function Position_Params (Path : String; Line, Char : Natural) return String is
     ("{""textDocument"":" & Text_Document (Path)
      & ",""position"":{""line"":" & Image (Line) & ",""character"":" & Image (Char) & "}}");

   function To_Char (Line : Wide_Wide_String; Col : Positive) return Natural is
      N : Natural := 0;
   begin
      for I in Line'First .. Integer'Min (Line'Last, Line'First + Col - 2) loop
         N := N + (if Wide_Wide_Character'Pos (Line (I)) > 16#FFFF# then 2 else 1);
      end loop;
      return N;
   end To_Char;

   function To_Col (Line : Wide_Wide_String; Char : Natural) return Positive is
      N   : Natural := 0;
      Col : Positive := 1;
   begin
      for I in Line'Range loop
         exit when N >= Char;
         N := N + (if Wide_Wide_Character'Pos (Line (I)) > 16#FFFF# then 2 else 1);
         Col := Col + 1;
      end loop;
      return Col;
   end To_Col;

   --  Finding the server

   function Find_Server (Configured : String) return String is
      use Ada.Directories;
      Exe  : constant String :=
        "ada_language_server" & (if Term.Is_Windows then ".exe" else "");
      Home : constant String :=
        (if Ada.Environment_Variables.Exists ("HOME")
         then Ada.Environment_Variables.Value ("HOME")
         elsif Ada.Environment_Variables.Exists ("USERPROFILE")
         then Ada.Environment_Variables.Value ("USERPROFILE")
         else "");

      function Is_File (P : String) return Boolean is
        (P /= "" and then Exists (P) and then Ada.Directories.Kind (P) = Ordinary_File);

      Extension_Dirs : constant String_Vectors.Vector :=
        String_Vectors.To_Vector (Home & "/.vscode/extensions", 1)
        & String'(Home & "/.vscode-server/extensions")
        & String'(Home & "/.vscode-oss/extensions");

      function In_Extensions (Dir : String) return String is
      --  The newest adacore.ada-* extension with a server for this machine.
         Archs   : constant String_Vectors.Vector :=
           String_Vectors.To_Vector ("x64", 1) & "arm64";
         Systems : constant String_Vectors.Vector :=
           String_Vectors.To_Vector ("linux", 1) & "darwin" & "win32";
         Best : Unbounded_String;
         Path : Unbounded_String;
         S    : Search_Type;
         E    : Directory_Entry_Type;
      begin
         if not Exists (Dir) then
            return "";
         end if;
         Start_Search (S, Dir, "", [Directory => True, others => False]);
         while More_Entries (S) loop
            Get_Next_Entry (S, E);
            declare
               N : constant String := Ada.Characters.Handling.To_Lower (Simple_Name (E));
            begin
               if N'Length > 11 and then N (N'First .. N'First + 10) = "adacore.ada"
                 and then Simple_Name (E) > To_String (Best)
               then
                  for Arch of Archs loop
                     for OS_Name of Systems loop
                        declare
                           Candidate : constant String :=
                             Full_Name (E) & "/" & Arch & "/" & OS_Name & "/" & Exe;
                        begin
                           if Is_File (Candidate) then
                              Best := To_Unbounded_String (Simple_Name (E));
                              Path := To_Unbounded_String (Candidate);
                           end if;
                        end;
                     end loop;
                  end loop;
               end if;
            end;
         end loop;
         End_Search (S);
         return To_String (Path);
      exception
         when others => return To_String (Path);
      end In_Extensions;

   begin
      if Configured /= "" then
         return (if Is_File (Configured) then Configured else "");
      end if;
      declare
         On_Path : GNAT.OS_Lib.String_Access :=
           GNAT.OS_Lib.Locate_Exec_On_Path ("ada_language_server");
      begin
         if On_Path /= null then
            return P : constant String := On_Path.all do
               GNAT.OS_Lib.Free (On_Path);
            end return;
         end if;
      end;
      if Home /= "" then
         if Is_File (Home & "/.alire/bin/" & Exe) then
            return Home & "/.alire/bin/" & Exe;
         end if;
         for Ext of Extension_Dirs loop
            declare
               Found : constant String := In_Extensions (Ext);
            begin
               if Found /= "" then
                  return Found;
               end if;
            end;
         end loop;
      end if;
      return "";
   end Find_Server;

   --  Sending

   procedure Send (Body_Text : String) is
      Msg : constant String :=
        "Content-Length:" & Natural'Image (Body_Text'Length)
        & ASCII.CR & ASCII.LF & ASCII.CR & ASCII.LF & Body_Text;
      N   : Integer;
   begin
      if The_State /= Running then
         return;
      end if;
      N := GNAT.OS_Lib.Write (Out_Fd, Msg'Address, Msg'Length);
      if N /= Msg'Length then
         The_State := Failed;
         Error_Msg := To_Unbounded_String ("cannot write to the language server");
      end if;
   end Send;

   procedure Notify (Method, Params : String) is
   begin
      Send ("{""jsonrpc"":""2.0"",""method"":" & Quote (Method)
            & ",""params"":" & Params & "}");
   end Notify;

   function Send_Request (Method, Params : String) return Natural is
   begin
      Next_Id := Next_Id + 1;
      Send ("{""jsonrpc"":""2.0"",""id"":" & Image (Next_Id) & ",""method"":"
            & Quote (Method) & ",""params"":" & Params & "}");
      return Next_Id;
   end Send_Request;

   --  Receiving

   procedure Handle_Diagnostics (Doc : Document; Params : Value) is
      File : constant String := Path_Of (To_String (Doc, Get (Doc, Params, "uri")));
      List : constant Value := Get (Doc, Params, "diagnostics");
      V    : Diagnostic_Vectors.Vector;
      D    : Value := First_Member (Doc, List);
   begin
      while Is_Present (D) loop
         declare
            R  : constant Value := Get (Doc, D, "range");
            It : Diagnostic;
         begin
            It.Line := To_Integer (Doc, Path (Doc, R, "start.line"));
            It.Char := To_Integer (Doc, Path (Doc, R, "start.character"));
            It.End_Line := To_Integer (Doc, Path (Doc, R, "end.line"));
            It.End_Char := To_Integer (Doc, Path (Doc, R, "end.character"));
            It.Severity := Positive'Max (1, Positive'Min (4,
                             To_Integer (Doc, Get (Doc, D, "severity"), 1)));
            It.Message := To_Unbounded_String (To_String (Doc, Get (Doc, D, "message")));
            V.Append (It);
         end;
         D := Next_Member (Doc, D);
      end loop;
      Diags.Include (File, V);
      Changed := True;
   end Handle_Diagnostics;

   procedure Handle_Progress (Doc : Document; Params : Value) is
      V    : constant Value := Get (Doc, Params, "value");
      Kind : constant String := To_String (Doc, Get (Doc, V, "kind"));
      Pct  : constant Integer := To_Integer (Doc, Get (Doc, V, "percentage"), -1);
   begin
      if Kind = "end" then
         Progress := Null_Unbounded_String;
      elsif Pct >= 0 then
         Progress := To_Unbounded_String (Image (Pct) & "%");
      end if;
   end Handle_Progress;

   procedure Dispatch
     (Text : String; Want_Id : Natural; R : access Response; Matched : out Boolean)
   is
   --  One message.  A response to Want_Id is parsed into R (Matched).
      Doc : Document;
      Ok  : Boolean;
   begin
      Matched := False;
      Doc.Parse (Text, Ok);
      if not Ok then
         return;
      end if;
      declare
         Top    : constant Value := Root (Doc);
         Id     : constant Value := Get (Doc, Top, "id");
         Method : constant String := To_String (Doc, Get (Doc, Top, "method"));
      begin
         if Method /= "" and then Is_Present (Id) then
            --  A request from the server: progress tokens, registrations,
            --  configuration.  None needs more than an empty answer.
            Send ("{""jsonrpc"":""2.0"",""id"":"
                  & (if Kind_Of (Doc, Id) = J_String then Quote (To_String (Doc, Id))
                     else To_String (Doc, Id))
                  & ",""result"":"
                  & (if Method = "workspace/configuration" then "[]" else "null") & "}");
         elsif Method = "textDocument/publishDiagnostics" then
            Handle_Diagnostics (Doc, Get (Doc, Top, "params"));
         elsif Method = "$/progress" then
            Handle_Progress (Doc, Get (Doc, Top, "params"));
         elsif Method = "window/showMessage" then
            if To_Integer (Doc, Path (Doc, Top, "params.type"), 4) = 1 then
               Error_Msg := To_Unbounded_String
                 (To_String (Doc, Path (Doc, Top, "params.message")));
            end if;
         elsif Method = "" and then R /= null
           and then To_Integer (Doc, Id, -1) = Want_Id
         then
            Matched := True;
            R.Doc.Parse (Text, Ok);
            declare
               RTop : constant Value := Root (R.Doc);
               Err  : constant Value := Get (R.Doc, RTop, "error");
            begin
               if Is_Present (Err) then
                  R.Ok := False;
                  R.Error := To_Unbounded_String (To_String (R.Doc, Get (R.Doc, Err, "message")));
                  --  Keep the first line: servers put stack traces after it.
                  declare
                     NL : constant Natural := Index (R.Error, (1 => ASCII.LF));
                  begin
                     if NL > 0 then
                        R.Error := Head (R.Error, NL - 1);
                     end if;
                  end;
               else
                  R.Ok := True;
                  R.Result := Get (R.Doc, RTop, "result");
               end if;
            end;
         end if;
      end;
   end Dispatch;

   procedure Poll is
      Msg     : Unbounded_String;
      Found   : Boolean;
      Matched : Boolean;
   begin
      loop
         Inbox.Take (Msg, Found);
         exit when not Found;
         Dispatch (To_String (Msg), 0, null, Matched);
      end loop;
   end Poll;

   procedure Request
     (Method  : String;
      Params  : String;
      R       : in out Response;
      Cancel  : Cancel_Func := null;
      Timeout : Duration := 15.0)
   is
      Id       : Natural;
      Deadline : constant Ada.Calendar.Time := Ada.Calendar.Clock + Timeout;
      Msg      : Unbounded_String;
      Found    : Boolean;
      Matched  : Boolean;
   begin
      R.Ok := False;
      R.Result := No_Value;
      R.Error := Null_Unbounded_String;
      if State /= Running then
         R.Error := To_Unbounded_String ("the language server is not running");
         return;
      end if;
      Id := Send_Request (Method, Params);
      loop
         Inbox.Take (Msg, Found);
         if Found then
            Dispatch (To_String (Msg), Id, R'Unchecked_Access, Matched);
            exit when Matched;
         else
            if State /= Running then
               R.Error := To_Unbounded_String ("the language server stopped");
               return;
            end if;
            if Ada.Calendar.Clock > Deadline then
               R.Error := To_Unbounded_String ("the language server did not answer in time");
               Notify ("$/cancelRequest", "{""id"":" & Image (Id) & "}");
               return;
            end if;
            if Cancel /= null and then Cancel.all then
               R.Error := To_Unbounded_String ("cancelled");
               Notify ("$/cancelRequest", "{""id"":" & Image (Id) & "}");
               return;
            end if;
            delay 0.01;
         end if;
      end loop;
   end Request;

   --  Lifetime

   procedure Start
     (Executable   : String;
      Project_File : String;
      Root_Dir     : String;
      Ok           : out Boolean)
   is
      Args : GNAT.OS_Lib.Argument_List (1 .. 0);
      Pid  : constant Integer :=
        GNAT.OS_Lib.Pid_To_Integer (GNAT.OS_Lib.Current_Process_Id);
   begin
      Ok := False;
      if The_State = Running then
         Stop;
      end if;
      Error_Msg := Null_Unbounded_String;
      Progress := Null_Unbounded_String;
      Open_Docs.Clear;
      Diags.Clear;
      Changed := True;
      Inbox.Clear;
      begin
         GNAT.Expect.Non_Blocking_Spawn
           (Process, Executable, Args, Buffer_Size => 0, Err_To_Out => True);
      exception
         when others =>
            The_State := Failed;
            Error_Msg := To_Unbounded_String ("cannot start " & Executable);
            return;
      end;
      Out_Fd := GNAT.Expect.Get_Input_Fd (Process);
      Inbox.Set_Closed (False);
      Reader.Start (GNAT.Expect.Get_Output_Fd (Process));
      The_State := Running;

      declare
         R : Response;
      begin
         Request
           ("initialize",
            "{""processId"":" & Image (Pid)
            & ",""clientInfo"":{""name"":""Turbo Ada"",""version"":" & Quote (Version) & "}"
            & ",""rootUri"":" & Quote (URI (Root_Dir))
            & ",""capabilities"":{"
            &   """general"":{""positionEncodings"":[""utf-16""]},"
            &   """window"":{""workDoneProgress"":true},"
            &   """workspace"":{""configuration"":false,""applyEdit"":false},"
            &   """textDocument"":{"
            &     """synchronization"":{""didSave"":true},"
            &     """hover"":{""contentFormat"":[""plaintext""]},"
            &     """completion"":{""completionItem"":{""snippetSupport"":false,"
            &        """resolveSupport"":{""properties"":[""documentation"",""detail""]}}},"
            &     """documentSymbol"":{""hierarchicalDocumentSymbolSupport"":true},"
            &     """definition"":{},""references"":{},""rename"":{},"
            &     """publishDiagnostics"":{}}}"
            & ",""initializationOptions"":{""ada"":{""projectFile"":"
            & Quote (Project_File) & "}}}",
            R, Timeout => 30.0);
         if not R.Ok then
            Error_Msg := R.Error;
            Stop;
            The_State := Failed;
            return;
         end if;
      end;
      Notify ("initialized", "{}");
      Ok := True;
   end Start;

   procedure Stop is
      Deadline : Ada.Calendar.Time;
   begin
      if The_State = Off then
         return;
      end if;
      if The_State = Running and then not Inbox.Closed then
         declare
            R : Response;
         begin
            Request ("shutdown", "null", R, Timeout => 2.0);
         end;
         Notify ("exit", "null");
      end if;
      --  Give it a moment to leave; then make sure, because the reader
      --  task (and so the IDE's own exit) waits on the pipe closing.
      Deadline := Ada.Calendar.Clock + 1.0;
      while not Inbox.Closed and then Ada.Calendar.Clock < Deadline loop
         delay 0.02;
      end loop;
      if not Inbox.Closed then
         begin
            GNAT.Expect.Send_Signal (Process, 9);
         exception
            when others => null;
         end;
         Deadline := Ada.Calendar.Clock + 2.0;
         while not Inbox.Closed and then Ada.Calendar.Clock < Deadline loop
            delay 0.02;
         end loop;
      end if;
      begin
         GNAT.Expect.Close (Process);
      exception
         when others => null;
      end;
      Inbox.Clear;
      Open_Docs.Clear;
      Diags.Clear;
      Changed := True;
      Progress := Null_Unbounded_String;
      The_State := Off;
   end Stop;

   --  Documents

   function Is_Open (Path : String) return Boolean is (Open_Docs.Contains (Path));

   function Sent_Version (Path : String) return Integer is
     (if Open_Docs.Contains (Path) then Open_Docs.Element (Path) else -1);

   procedure Open_Document (Path : String; Version : Natural; Text : String) is
   begin
      if State /= Running or else Open_Docs.Contains (Path) then
         return;
      end if;
      Notify ("textDocument/didOpen",
              "{""textDocument"":{""uri"":" & Quote (URI (Path))
              & ",""languageId"":""ada"",""version"":" & Image (Version)
              & ",""text"":" & Quote (Text) & "}}");
      Open_Docs.Include (Path, Version);
   end Open_Document;

   procedure Change_Document (Path : String; Version : Natural; Text : String) is
   begin
      if State /= Running or else not Open_Docs.Contains (Path)
        or else Open_Docs.Element (Path) = Version
      then
         return;
      end if;
      Notify ("textDocument/didChange",
              "{""textDocument"":{""uri"":" & Quote (URI (Path))
              & ",""version"":" & Image (Version)
              & "},""contentChanges"":[{""text"":" & Quote (Text) & "}]}");
      Open_Docs.Include (Path, Version);
   end Change_Document;

   procedure Save_Document (Path : String) is
   begin
      if State = Running and then Open_Docs.Contains (Path) then
         Notify ("textDocument/didSave", "{""textDocument"":" & Text_Document (Path) & "}");
      end if;
   end Save_Document;

   procedure Close_Document (Path : String) is
   begin
      if Open_Docs.Contains (Path) then
         if State = Running then
            Notify ("textDocument/didClose", "{""textDocument"":" & Text_Document (Path) & "}");
         end if;
         Open_Docs.Delete (Path);
      end if;
      if Diags.Contains (Path) then
         Diags.Delete (Path);
         Changed := True;
      end if;
   end Close_Document;

   function Diagnostics_For (Path : String) return Diagnostic_Vectors.Vector is
     (if Diags.Contains (Path) then Diags.Element (Path)
      else Diagnostic_Vectors.Empty_Vector);

   function All_Diagnostics return Path_Maps.Map is (Diags);

   function Diagnostics_Changed return Boolean is
      C : constant Boolean := Changed;
   begin
      Changed := False;
      return C;
   end Diagnostics_Changed;


end Turbo.LSP;
