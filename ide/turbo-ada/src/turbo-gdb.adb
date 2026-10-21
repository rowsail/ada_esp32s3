with Ada.Calendar;
with Ada.Containers.Vectors;
with Ada.Strings.Fixed;
with Interfaces.C;
with GNAT.Expect;
with GNAT.OS_Lib;
with Turbo.Pipes;

package body Turbo.GDB is

   use Ada.Strings.Unbounded;
   use Turbo.Pipes;
   use type Ada.Calendar.Time;
   use type Ada.Containers.Count_Type;

   Gdb_Q, Srv_Q, Con_Q : aliased Line_Queue;
   Gdb_R : Line_Reader (Gdb_Q'Access);
   Srv_R : Line_Reader (Srv_Q'Access);
   Con_R : Line_Reader (Con_Q'Access);

   Gdb_P, Srv_P, Con_P : GNAT.Expect.Process_Descriptor;
   Gdb_Up, Srv_Up, Con_Up : Boolean := False;
   Gdb_In : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;

   --  A native program's terminal (Start_Native): read by Con_R.
   Pty_Master, Pty_Slave : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
   Native : Boolean := False;

   The_State : Session_State := Off;
   Error_Msg : Unbounded_String;
   Srv_Log   : String_Vectors.Vector;     --  the server's last lines
   Console   : String_Vectors.Vector;     --  for Take_Console

   package Stop_Vectors is new Ada.Containers.Vectors (Positive, Stop_Info);
   Stops : Stop_Vectors.Vector;

   Next_Token  : Natural := 0;
   Want_Token  : Natural := 0;            --  the reply Command is waiting for
   Reply       : Unbounded_String;        --  "^class,results" for Want_Token
   Have_Reply  : Boolean := False;
   Capturing   : Boolean := False;        --  collect ~ output for Console_Command
   Captured    : Unbounded_String;

   function State return Session_State is (The_State);
   function Is_Native return Boolean is (Native);
   function Last_Error return String is (To_String (Error_Msg));

   --  MI text

   function Is_Octal (C : Character) return Boolean is (C in '0' .. '7');

   function C_String (Text : String) return String is
      R : Unbounded_String;
      I : Natural := Text'First;
      Last : Natural := Text'Last;
   begin
      if I <= Last and then Text (I) = '"' then
         I := I + 1;
      end if;
      if Last >= I and then Text (Last) = '"' then
         Last := Last - 1;
      end if;
      while I <= Last loop
         if Text (I) = '\' and then I < Last then
            I := I + 1;
            case Text (I) is
               when 'n' => Append (R, ASCII.LF);
               when 't' => Append (R, ASCII.HT);
               when 'r' => Append (R, ASCII.CR);
               when 'a' => Append (R, ASCII.BEL);
               when 'b' => Append (R, ASCII.BS);
               when 'f' => Append (R, ASCII.FF);
               when 'v' => Append (R, ASCII.VT);
               when 'e' => Append (R, ASCII.ESC);
               when '0' .. '7' =>
                  declare
                     V : Natural := 0;
                     K : Natural := 0;
                  begin
                     while K < 3 and then I <= Last and then Is_Octal (Text (I)) loop
                        V := V * 8 + Character'Pos (Text (I)) - Character'Pos ('0');
                        I := I + 1;
                        K := K + 1;
                     end loop;
                     Append (R, Character'Val (V mod 256));
                     I := I - 1;
                  end;
               when others => Append (R, Text (I));   --  \" \\ \'
            end case;
         else
            Append (R, Text (I));
         end if;
         I := I + 1;
      end loop;
      return To_String (R);
   end C_String;

   function MI_To_JSON (Results : String) return String is
      P : Natural := Results'First;
      R : Unbounded_String;

      function At_End return Boolean is (P > Results'Last);

      procedure Value;
      procedure Members (Close : Character);

      procedure String_Value is
         Start : constant Natural := P;
      begin
         P := P + 1;
         while not At_End and then Results (P) /= '"' loop
            if Results (P) = '\' then
               P := P + 1;
            end if;
            P := P + 1;
         end loop;
         Append (R, JSON.Quote (C_String (Results (Start .. Natural'Min (P, Results'Last)))));
         P := P + 1;
      end String_Value;

      procedure Value is
      begin
         if At_End then
            Append (R, "null");
            return;
         end if;
         case Results (P) is
            when '"' =>
               String_Value;
            when '{' =>
               P := P + 1;
               Append (R, "{");
               if not At_End and then Results (P) = '}' then
                  P := P + 1;
               else
                  Members ('}');
               end if;
               Append (R, "}");
            when '[' =>
               P := P + 1;
               Append (R, "[");
               if not At_End and then Results (P) = ']' then
                  P := P + 1;
               else
                  loop
                     if not At_End and then Results (P) not in '"' | '{' | '[' then
                        --  A result in a list: keep its value, drop the name.
                        while not At_End and then Results (P) /= '=' loop
                           P := P + 1;
                        end loop;
                        P := P + 1;
                     end if;
                     Value;
                     exit when At_End or else Results (P) /= ',';
                     P := P + 1;
                     Append (R, ",");
                  end loop;
                  if not At_End and then Results (P) = ']' then
                     P := P + 1;
                  end if;
               end if;
               Append (R, "]");
            when others =>
               --  Not MI: take the rest of the field as a string.
               declare
                  Start : constant Natural := P;
               begin
                  while not At_End and then Results (P) not in ',' | '}' | ']' loop
                     P := P + 1;
                  end loop;
                  Append (R, JSON.Quote (Results (Start .. P - 1)));
               end;
         end case;
      end Value;

      procedure Members (Close : Character) is
      begin
         loop
            declare
               Start : constant Natural := P;
            begin
               while not At_End and then Results (P) /= '=' loop
                  P := P + 1;
               end loop;
               exit when At_End;
               Append (R, JSON.Quote (Results (Start .. P - 1)) & ":");
               P := P + 1;
               Value;
            end;
            exit when At_End or else Results (P) /= ',';
            P := P + 1;
            Append (R, ",");
         end loop;
         if not At_End and then Results (P) = Close then
            P := P + 1;
         end if;
      end Members;
   begin
      Append (R, "{");
      if Results'Length > 0 then
         Members (ASCII.NUL);
      end if;
      Append (R, "}");
      return To_String (R);
   end MI_To_JSON;

   function Quote (S : String) return String is
      R : Unbounded_String := To_Unbounded_String ("""");
   begin
      for C of S loop
         case C is
            when '"' | '\' => Append (R, '\' & C);
            when ASCII.LF => Append (R, "\n");
            when others => Append (R, C);
         end case;
      end loop;
      return To_String (R) & """";
   end Quote;

   --  Records from GDB

   procedure Add_Console (Line : String) is
   begin
      Console.Append (Line);
      if Console.Length > 2000 then
         Console.Delete_First;
      end if;
   end Add_Console;

   procedure Handle_Stop (Results : String) is
      Doc   : JSON.Document;
      Ok    : Boolean;
      S     : Stop_Info;
   begin
      Doc.Parse (MI_To_JSON (Results), Ok);
      if Ok then
         declare
            Root  : constant JSON.Value := Doc.Root;
            Frame : constant JSON.Value := Doc.Get (Root, "frame");
         begin
            S.Reason := To_Unbounded_String (Doc.To_String (Doc.Get (Root, "reason")));
            S.File := To_Unbounded_String (Doc.To_String (Doc.Get (Frame, "fullname")));
            S.Line := Natural'Value ("0" & Doc.To_String (Doc.Get (Frame, "line")));
            S.Func := To_Unbounded_String (Doc.To_String (Doc.Get (Frame, "func")));
            S.Addr := To_Unbounded_String (Doc.To_String (Doc.Get (Frame, "addr")));
            S.Detail := To_Unbounded_String
              (Doc.To_String (Doc.Get (Root, "signal-meaning"),
                              Doc.To_String (Doc.Get (Root, "exit-code"))));
         exception
            when Constraint_Error =>
               S.Line := 0;
         end;
      end if;
      Stops.Append (S);
      The_State := Stopped;      --  after an exit too: GDB is still there
   end Handle_Stop;

   procedure Handle_Line (L : String) is
      I     : Natural := L'First;
      Token : Natural := 0;
   begin
      if L'Length = 0 or else (L'Length >= 5 and then L (L'First .. L'First + 4) = "(gdb)") then
         return;
      end if;
      while I <= L'Last and then L (I) in '0' .. '9' loop
         Token := Token * 10 + Character'Pos (L (I)) - Character'Pos ('0');
         I := I + 1;
      end loop;
      if I > L'Last then
         return;
      end if;
      declare
         Kind  : constant Character := L (I);
         Rest  : constant String := L (I + 1 .. L'Last);
         Comma : constant Natural := Ada.Strings.Fixed.Index (Rest, ",");
         Class : constant String := (if Comma = 0 then Rest else Rest (Rest'First .. Comma - 1));
         Res   : constant String := (if Comma = 0 then "" else Rest (Comma + 1 .. Rest'Last));
      begin
         case Kind is
            when '^' =>
               if Class = "running" then
                  The_State := Running;
               end if;
               if Token /= 0 and then Token = Want_Token then
                  Reply := To_Unbounded_String (Rest);
                  Have_Reply := True;
               end if;
            when '*' =>
               if Class = "running" then
                  The_State := Running;
               elsif Class = "stopped" then
                  Handle_Stop (Res);
               end if;
            when '~' =>
               declare
                  T : constant String := C_String (Rest);
               begin
                  if Capturing then
                     Append (Captured, T);
                  end if;
               end;
            when '@' =>
               --  OpenOCD's own chatter (resets, halts), relayed by GDB: not
               --  the program's output; kept only for a console command.
               if Capturing then
                  Append (Captured, C_String (Rest));
               end if;
            when others =>
               null;    --  & (log), = (notifications), + (status)
         end case;
      end;
   end Handle_Line;

   procedure Drain_Gdb is
      Line  : Unbounded_String;
      Found : Boolean;
   begin
      loop
         Gdb_Q.Take (Line, Found);
         exit when not Found;
         Handle_Line (To_String (Line));
      end loop;
   end Drain_Gdb;

   procedure Drain_Server is
      Line  : Unbounded_String;
      Found : Boolean;
   begin
      loop
         Srv_Q.Take (Line, Found);
         exit when not Found;
         Srv_Log.Append (To_String (Line));
         if Srv_Log.Length > 40 then
            Srv_Log.Delete_First;
         end if;
      end loop;
   end Drain_Server;

   function Server_Tail return String is
      R : Unbounded_String;
      N : Natural := 0;
   begin
      for K in reverse Srv_Log.First_Index .. Srv_Log.Last_Index loop
         declare
            L : constant String := Srv_Log (K);
         begin
            if Ada.Strings.Fixed.Index (L, "Error") > 0 or else Ada.Strings.Fixed.Index (L, "error") > 0
              or else N = 0
            then
               R := To_Unbounded_String
                 (L & (if Length (R) > 0 then ASCII.LF & To_String (R) else ""));
               N := N + 1;
            end if;
         end;
         exit when N >= 3;
      end loop;
      return To_String (R);
   end Server_Tail;

   procedure Poll is
      Line  : Unbounded_String;
      Found : Boolean;
   begin
      Drain_Gdb;
      Drain_Server;
      loop
         Con_Q.Take (Line, Found);
         exit when not Found;
         Add_Console (To_String (Line));
      end loop;
      if The_State in Stopped | Running then
         if Gdb_Q.Closed then
            The_State := Failed;
            Error_Msg := To_Unbounded_String ("GDB stopped");
         elsif not Native and then Srv_Q.Closed then
            The_State := Failed;
            Error_Msg := To_Unbounded_String ("OpenOCD stopped: " & Server_Tail);
         end if;
      end if;
   end Poll;

   function Take_Stop (S : out Stop_Info) return Boolean is
   begin
      if Stops.Is_Empty then
         return False;
      end if;
      S := Stops.First_Element;
      Stops.Delete_First;
      return True;
   end Take_Stop;

   function Take_Console return String_Vectors.Vector is
      R : constant String_Vectors.Vector := Console;
   begin
      Console.Clear;
      return R;
   end Take_Console;

   --  Commands

   procedure Write_Gdb (Text : String) is
      Msg : constant String := Text & ASCII.LF;
      N   : Integer;
   begin
      N := GNAT.OS_Lib.Write (Gdb_In, Msg'Address, Msg'Length);
      if N /= Msg'Length then
         The_State := Failed;
         Error_Msg := To_Unbounded_String ("cannot write to GDB");
      end if;
   end Write_Gdb;

   procedure Command (Text : String; R : in out Result; Timeout : Duration := 10.0) is
      Deadline : constant Ada.Calendar.Time := Ada.Calendar.Clock + Timeout;
      Line     : Unbounded_String;
      Found    : Boolean;
   begin
      R.Ok := False;
      R.Value := JSON.No_Value;
      R.Class := Null_Unbounded_String;
      R.Error := Null_Unbounded_String;
      if not Gdb_Up or else Gdb_Q.Closed then
         R.Error := To_Unbounded_String ("GDB is not running");
         return;
      end if;
      Next_Token := Next_Token + 1;
      Want_Token := Next_Token;
      Have_Reply := False;
      Write_Gdb (Ada.Strings.Fixed.Trim (Natural'Image (Want_Token), Ada.Strings.Left) & Text);
      loop
         Gdb_Q.Take (Line, Found);
         if Found then
            Handle_Line (To_String (Line));
            exit when Have_Reply;
         elsif Gdb_Q.Closed then
            R.Error := To_Unbounded_String ("GDB stopped");
            Want_Token := 0;
            return;
         elsif Ada.Calendar.Clock > Deadline then
            R.Error := To_Unbounded_String ("GDB did not answer in time (" & Text & ")");
            Want_Token := 0;
            return;
         else
            delay 0.005;
         end if;
      end loop;
      Want_Token := 0;
      declare
         Rest  : constant String := To_String (Reply);
         Comma : constant Natural := Ada.Strings.Fixed.Index (Rest, ",");
         Class : constant String := (if Comma = 0 then Rest else Rest (Rest'First .. Comma - 1));
         Res   : constant String := (if Comma = 0 then "" else Rest (Comma + 1 .. Rest'Last));
         Ok    : Boolean;
      begin
         R.Class := To_Unbounded_String (Class);
         R.Doc.Parse (MI_To_JSON (Res), Ok);
         R.Value := (if Ok then R.Doc.Root else JSON.No_Value);
         if Class = "error" then
            R.Error := To_Unbounded_String (R.Doc.To_String (R.Doc.Get (R.Value, "msg"), "error"));
         else
            R.Ok := True;
         end if;
      end;
   end Command;

   procedure Command (Text : String; Ok : out Boolean; Timeout : Duration := 10.0) is
      R : Result;
   begin
      Command (Text, R, Timeout);
      Ok := R.Ok;
      if not R.Ok then
         Error_Msg := R.Error;
      end if;
   end Command;

   procedure Console_Command (Text : String; Output : out Unbounded_String;
                              Ok : out Boolean; Timeout : Duration := 10.0) is
      R : Result;
   begin
      Captured := Null_Unbounded_String;
      Capturing := True;
      Command ("-interpreter-exec console " & Quote (Text), R, Timeout);
      Capturing := False;
      Output := Captured;
      Ok := R.Ok;
      if not R.Ok then
         Error_Msg := R.Error;
         Output := R.Error;
      end if;
   end Console_Command;

   --  Lifetime

   procedure Start_Server (Command, Dir : String; Ok : out Boolean;
                           Timeout : Duration := 20.0) is
      Deadline : constant Ada.Calendar.Time := Ada.Calendar.Clock + Timeout;
      Args : GNAT.OS_Lib.Argument_List :=
        [new String'("-c"), new String'("cd " & Shell_Quote (Dir) & " && exec " & Command)];
   begin
      Ok := False;
      Srv_Log.Clear;
      Error_Msg := Null_Unbounded_String;
      Spawn (Srv_P, Srv_Q, Srv_R, "/bin/sh", Args, Srv_Up);
      for A of Args loop
         GNAT.OS_Lib.Free (A);
      end loop;
      if not Srv_Up then
         Error_Msg := To_Unbounded_String ("cannot start: " & Command);
         return;
      end if;
      loop
         Drain_Server;
         for L of Srv_Log loop
            if Ada.Strings.Fixed.Index (L, "Listening on port 3333") > 0 then
               Ok := True;
               return;
            end if;
         end loop;
         if Srv_Q.Closed then
            Drain_Server;
            Error_Msg := To_Unbounded_String (Server_Tail);
            Kill (Srv_P, Srv_Q, Srv_Up, 0.0);
            return;
         end if;
         if Ada.Calendar.Clock > Deadline then
            Error_Msg := To_Unbounded_String ("OpenOCD did not start: " & Server_Tail);
            Kill (Srv_P, Srv_Q, Srv_Up, 0.0);
            return;
         end if;
         delay 0.05;
      end loop;
   end Start_Server;

   Common_Settings : constant String_Vectors.Vector :=
     ["-gdb-set mi-async on",
      "-gdb-set pagination off",
      "-gdb-set confirm off",
      "-gdb-set print frame-arguments scalars"];

   procedure Start (Gdb, Elf, Dir : String; Ok : out Boolean) is
      Args : GNAT.OS_Lib.Argument_List :=
        [new String'("--interpreter=mi3"), new String'("-q"), new String'("-nx"),
         new String'("-cd=" & Dir), new String'(Elf)];
   begin
      Ok := False;
      Stops.Clear;
      Spawn (Gdb_P, Gdb_Q, Gdb_R, Gdb, Args, Gdb_Up);
      for A of Args loop
         GNAT.OS_Lib.Free (A);
      end loop;
      if not Gdb_Up then
         Error_Msg := To_Unbounded_String ("cannot start " & Gdb);
         return;
      end if;
      Gdb_In := GNAT.Expect.Get_Input_Fd (Gdb_P);
      Native := False;
      for C of String_Vectors.Vector'
        (String_Vectors."&" (Common_Settings, String_Vectors.Vector'
         [--  The ESP32-S3 has two instruction and two data breakpoints;
          --  saying so makes GDB refuse a third up front instead of failing
          --  when it resumes.
          "-gdb-set remote hardware-breakpoint-limit 2",
          "-gdb-set remote hardware-watchpoint-limit 2"]))
      loop
         Command (C, Ok, Timeout => 15.0);
         if not Ok then
            return;
         end if;
      end loop;
      Command ("-target-select extended-remote :3333", Ok, Timeout => 20.0);
      if Ok then
         The_State := Stopped;      --  OpenOCD halts the target for GDB
      end if;
      Drain_Gdb;
      Stops.Clear;                  --  that halt is not a stop of the program
   end Start;

   function Pty_Open (Name : out Interfaces.C.char_array; Max : Interfaces.C.int;
                      Slave : out Interfaces.C.int) return Interfaces.C.int
     with Import, Convention => C, External_Name => "tada_pty_open";

   procedure Start_Native (Gdb, Exe, Dir : String; Ok : out Boolean) is
      Args : GNAT.OS_Lib.Argument_List :=
        [new String'("--interpreter=mi3"), new String'("-q"), new String'("-nx"),
         new String'("-cd=" & Dir), new String'(Exe)];
   begin
      Ok := False;
      Stops.Clear;
      Error_Msg := Null_Unbounded_String;
      Spawn (Gdb_P, Gdb_Q, Gdb_R, Gdb, Args, Gdb_Up);
      for A of Args loop
         GNAT.OS_Lib.Free (A);
      end loop;
      if not Gdb_Up then
         Error_Msg := To_Unbounded_String ("cannot start " & Gdb);
         return;
      end if;
      Gdb_In := GNAT.Expect.Get_Input_Fd (Gdb_P);
      Native := True;
      for C of Common_Settings loop
         Command (C, Ok, Timeout => 15.0);
         if not Ok then
            return;
         end if;
      end loop;
      declare
         use type Interfaces.C.int;
         Name  : Interfaces.C.char_array (1 .. 256);
         Slave : Interfaces.C.int;
         M     : constant Interfaces.C.int := Pty_Open (Name, Name'Length, Slave);
      begin
         if M >= 0 then
            Pty_Master := GNAT.OS_Lib.File_Descriptor (M);
            Pty_Slave := GNAT.OS_Lib.File_Descriptor (Slave);
            Command ("-inferior-tty-set " & Quote (Interfaces.C.To_Ada (Name)), Ok);
            Con_Q.Clear;
            Con_Q.Set_Closed (False);
            Con_R.Start (Pty_Master);
         end if;
         --  Without one the program writes into GDB's own output, where
         --  anything that is not an MI record is passed over.
      end;
      Ok := True;
      The_State := Stopped;      --  loaded, not yet run
   end Start_Native;

   procedure Close_Pty is
      use type GNAT.OS_Lib.File_Descriptor;
      Deadline : constant Ada.Calendar.Time := Ada.Calendar.Clock + 2.0;
   begin
      if Pty_Master = GNAT.OS_Lib.Invalid_FD then
         return;
      end if;
      --  With the program gone and our hold on the slave let go, the
      --  master reads end-of-file and the reader is free again.
      GNAT.OS_Lib.Close (Pty_Slave);
      while not Con_Q.Closed and then Ada.Calendar.Clock < Deadline loop
         delay 0.02;
      end loop;
      GNAT.OS_Lib.Close (Pty_Master);
      Pty_Master := GNAT.OS_Lib.Invalid_FD;
      Pty_Slave := GNAT.OS_Lib.Invalid_FD;
      Con_Q.Clear;
   end Close_Pty;

   procedure Reset_Halt (Ok : out Boolean) is
      Ignore : Unbounded_String;
   begin
      --  The register cache predates the reset: without the flush GDB still
      --  believes the old PC and refuses to resume ("target is running").
      Console_Command ("monitor reset halt", Ignore, Ok, Timeout => 10.0);
      if Ok then
         Console_Command ("maintenance flush register-cache", Ignore, Ok);
      end if;
      --  The halt is reported (*stopped) after the command's reply, and
      --  not as a stop of the program: wait for it a moment, then drop it.
      declare
         Deadline : constant Ada.Calendar.Time := Ada.Calendar.Clock + 1.0;
      begin
         loop
            Drain_Gdb;
            exit when not Stops.Is_Empty or else Ada.Calendar.Clock > Deadline;
            delay 0.02;
         end loop;
      end;
      Stops.Clear;
      if Ok then
         The_State := Stopped;
      end if;
   end Reset_Halt;

   procedure Start_Console (Command, Dir : String) is
      --  Command may be a list ("stty ...; exec cat ..."): no exec in front.
      Args : GNAT.OS_Lib.Argument_List :=
        [new String'("-c"), new String'("cd " & Shell_Quote (Dir) & " && " & Command)];
   begin
      Spawn (Con_P, Con_Q, Con_R, "/bin/sh", Args, Con_Up);
      for A of Args loop
         GNAT.OS_Lib.Free (A);
      end loop;
   end Start_Console;

   procedure Stop is
      Ok     : Boolean;
      Ignore : Unbounded_String;
   begin
      if Gdb_Up and then not Gdb_Q.Closed then
         if The_State = Running then
            Command ("-exec-interrupt", Ok, Timeout => 3.0);
            declare
               Deadline : constant Ada.Calendar.Time := Ada.Calendar.Clock + 3.0;
            begin
               while The_State = Running and then Ada.Calendar.Clock < Deadline loop
                  Drain_Gdb;
                  delay 0.02;
               end loop;
            end;
         end if;
         Command ("-break-delete", Ok, Timeout => 3.0);
         if Native then
            Console_Command ("kill", Ignore, Ok, Timeout => 3.0);   --  fails when it has exited
         else
            Console_Command ("monitor reset run", Ignore, Ok, Timeout => 5.0);
            Command ("-target-detach", Ok, Timeout => 3.0);
         end if;
         Write_Gdb ("-gdb-exit");
      end if;
      Kill (Gdb_P, Gdb_Q, Gdb_Up, 2.0);
      Kill (Srv_P, Srv_Q, Srv_Up, 0.0);
      Kill (Con_P, Con_Q, Con_Up, 0.0);
      Close_Pty;
      Stops.Clear;
      Native := False;
      The_State := Off;
   end Stop;

end Turbo.GDB;
