--  tada-cli: Turbo Ada without a terminal, in the manner of kicad-cli.
--
--    tada-cli [-C DIR] version
--    tada-cli [-C DIR] keys
--    tada-cli [-C DIR] project info [--json]
--    tada-cli [-C DIR] ui [--size COLSxROWS] [--script FILE] [-e STEP]... [FILE...]
--    tada-cli [-C DIR] debug [--break FILE:LINE]... [--watch EXPR]...
--                            [--no-build] [--script FILE] [-e STEP]...
--
--  ui runs the IDE itself on a virtual terminal, driven by a script of keys,
--  waits, screen dumps and checks (Turbo.Script); debug runs a debug
--  session through the IDE's GDB/MI client and prints each stop.  Both exit
--  with 1 when a check fails, so they serve as tests.

with Ada.Calendar;
with Ada.Command_Line;
with Ada.Containers.Indefinite_Vectors;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with GNAT.Expect;
with GNAT.OS_Lib;
with Turbo.App;
with Turbo.Dialogs;
with Turbo.GDB;
with Turbo.JSON;
with Turbo.Projects;
with Turbo.Script;
with Turbo.Term;

procedure Tada_Cli is

   use Ada.Command_Line;
   use Ada.Strings.Unbounded;
   use Ada.Text_IO;
   use type Ada.Calendar.Time;

   package Prj renames Turbo.Projects;
   package GDB renames Turbo.GDB;

   use type Prj.Target_Kind;
   use type Prj.Action;
   use type GDB.Session_State;

   package String_Vectors is new Ada.Containers.Indefinite_Vectors (Positive, String);

   Usage_Error : exception;

   Args : String_Vectors.Vector;
   Pos  : Positive := 1;
   Start_Dir : Unbounded_String := To_Unbounded_String (Ada.Directories.Current_Directory);

   procedure Usage is
   begin
      Put_Line ("usage: tada-cli [-C DIR] COMMAND ...");
      Put_Line ("");
      Put_Line ("  version                  Turbo Ada's version");
      Put_Line ("  keys                     the key names a ui script takes");
      Put_Line ("  project info [--json]    the project as the IDE sees it: kind,");
      Put_Line ("                           target, files, and every command");
      Put_Line ("  ui [OPTIONS] [FILE...]   run the IDE on a virtual terminal, scripted");
      Put_Line ("       --size COLSxROWS    the screen (default 80x25)");
      Put_Line ("       --script FILE       steps, one per line (- for stdin)");
      Put_Line ("       -e STEP             a step (repeatable), after the script's");
      Put_Line ("       --trace             log each step and key on stderr");
      Put_Line ("     steps: key NAME..., type TEXT, wait SECS, wait-for TEXT [SECS],");
      Put_Line ("            wait-stopped [SECS], expect TEXT, expect-not TEXT,");
      Put_Line ("            screen [json], echo TEXT, quit");
      Put_Line ("  debug [OPTIONS]          a debug session, printing each stop");
      Put_Line ("       --break FILE:LINE   a breakpoint (repeatable)");
      Put_Line ("       --watch EXPR        printed at every stop (repeatable)");
      Put_Line ("       --no-build          debug what is there (no make / flash)");
      Put_Line ("       --script FILE, -e STEP  as for ui");
      Put_Line ("     steps: start, step, next, finish, continue, until FILE:LINE,");
      Put_Line ("            break FILE:LINE, watch EXPR, print EXPR (EXPR := V sets),");
      Put_Line ("            stack, wait SECS, expect-line N, expect-value EXPR VALUE");
      Put_Line ("");
      Put_Line ("-C DIR: the project directory (default: the current one); relative");
      Put_Line ("paths are taken from it, as with git -C and make -C.");
      Put_Line ("Exit status: 0 ok, 1 a check or the session failed, 2 bad usage.");
   end Usage;

   function More return Boolean is (Pos <= Args.Last_Index);

   function Take return String is
   begin
      if not More then
         raise Usage_Error with "missing argument";
      end if;
      Pos := Pos + 1;
      return Args (Pos - 1);
   end Take;

   function Img (N : Integer) return String is
     (Ada.Strings.Fixed.Trim (Integer'Image (N), Ada.Strings.Left));

   --  Running the project's commands

   function Shell (Cmd, Dir : String) return Integer is
   --  Cmd through the project's shell in Dir, its output passed through.
      Here : constant String := Ada.Directories.Current_Directory;
      A    : GNAT.OS_Lib.Argument_List :=
        [new String'(Prj.Shell_Flag), new String'(Cmd)];
      Prog : GNAT.OS_Lib.String_Access := GNAT.OS_Lib.Locate_Exec_On_Path (Prj.Shell_Program);
      Code : Integer;
      use type GNAT.OS_Lib.String_Access;
   begin
      if Prog = null then
         Prog := new String'(Prj.Shell_Program);
      end if;
      Ada.Directories.Set_Directory (Dir);
      Code := GNAT.OS_Lib.Spawn (Prog.all, A);
      Ada.Directories.Set_Directory (Here);
      for X of A loop
         GNAT.OS_Lib.Free (X);
      end loop;
      GNAT.OS_Lib.Free (Prog);
      return Code;
   end Shell;

   function Capture (Cmd, Dir : String; Ok : out Boolean) return String is
      Here   : constant String := Ada.Directories.Current_Directory;
      Status : aliased Integer;
      A      : GNAT.OS_Lib.Argument_List := [new String'(Prj.Shell_Flag), new String'(Cmd)];
   begin
      Ada.Directories.Set_Directory (Dir);
      declare
         Out_Text : constant String :=
           GNAT.Expect.Get_Command_Output (Prj.Shell_Program, A, "", Status'Access, Err_To_Out => True);
      begin
         Ada.Directories.Set_Directory (Here);
         for X of A loop
            GNAT.OS_Lib.Free (X);
         end loop;
         Ok := Status = 0;
         return Out_Text;
      end;
   end Capture;

   --  project info

   procedure Project_Info (Json : Boolean) is
      function Field (K, V : String; Last : Boolean := False) return String is
        ("  " & Turbo.JSON.Quote (K) & ": " & Turbo.JSON.Quote (V) & (if Last then "" else ","));
   begin
      if Json then
         Put_Line ("{");
         Put_Line (Field ("kind", Prj.Kind_Image));
         Put_Line (Field ("target", Prj.Target_Image));
         Put_Line (Field ("name", Prj.Name));
         Put_Line (Field ("root", Prj.Root));
         Put_Line (Field ("dir", Prj.Dir));
         Put_Line (Field ("gpr", Prj.Gpr_File));
         Put_Line (Field ("manifest", Prj.Manifest));
         Put_Line (Field ("main_source", Prj.Main_Source));
         Put_Line (Field ("executable",
                          (if Prj.Target = Prj.Target_Native then Prj.Native_Executable else "")));
         Put_Line (Field ("debug",
                          (if not Prj.Can_Debug then ""
                           elsif Prj.Target = Prj.Target_Native then "gdb"
                           else "openocd+gdb")));
         Put_Line ("  ""commands"": {");
         for A in Prj.Action loop
            Put_Line ("    " & Turbo.JSON.Quote (Prj.Label (A)) & ": "
                      & Turbo.JSON.Quote (Prj.Command_For (A))
                      & (if A = Prj.Action'Last then "" else ","));
         end loop;
         Put_Line ("  },");
         Put_Line (Field ("debug_server", Prj.Debug_Server_Command));
         Put_Line (Field ("debug_info", Prj.Debug_Info_Command, Last => True));
         Put_Line ("}");
      else
         Put_Line ("kind:        " & Prj.Kind_Image);
         Put_Line ("target:      " & Prj.Target_Image);
         Put_Line ("name:        " & Prj.Name);
         Put_Line ("root:        " & Prj.Root);
         Put_Line ("dir:         " & Prj.Dir);
         Put_Line ("gpr:         " & Prj.Gpr_File);
         Put_Line ("manifest:    " & Prj.Manifest);
         Put_Line ("main source: " & Prj.Main_Source);
         if Prj.Target = Prj.Target_Native then
            Put_Line ("executable:  " & Prj.Native_Executable);
         end if;
         Put_Line ("debug:       "
                   & (if not Prj.Can_Debug then "(none)"
                      elsif Prj.Target = Prj.Target_Native then "native gdb"
                      else "OpenOCD + GDB on the board"));
         Put_Line ("commands:");
         for A in Prj.Action loop
            if Prj.Command_For (A) /= "" then
               Put_Line ("  " & Prj.Label (A) & (1 .. Integer'Max (1, 14 - Prj.Label (A)'Length) => ' ')
                         & Prj.Command_For (A));
            end if;
         end loop;
         if Prj.Debug_Server_Command /= "" then
            Put_Line ("  Debug server  " & Prj.Debug_Server_Command);
            Put_Line ("  Debug info    " & Prj.Debug_Info_Command);
         end if;
      end if;
   end Project_Info;

   --  ui

   procedure UI is
      Files : Turbo.Dialogs.String_List;
      Rows  : Positive := 25;
      Cols  : Positive := 80;
      Extra : String_Vectors.Vector;
   begin
      while More loop
         declare
            A : constant String := Take;
         begin
            if A = "--size" then
               declare
                  S : constant String := Take;
                  X : constant Natural := Ada.Strings.Fixed.Index (S, "x");
               begin
                  if X = 0 then
                     raise Usage_Error with "--size COLSxROWS, e.g. 100x30";
                  end if;
                  Cols := Positive'Value (S (S'First .. X - 1));
                  Rows := Positive'Value (S (X + 1 .. S'Last));
               end;
            elsif A = "--script" then
               Turbo.Script.Load (Take);
            elsif A = "-e" then
               Extra.Append (Take);
            elsif A = "--trace" then
               Turbo.Script.Set_Trace (True);
            elsif A'Length > 0 and then A (A'First) = '-' then
               raise Usage_Error with "ui: unknown option " & A;
            else
               Files.Append (Ada.Directories.Full_Name (A));
            end if;
         end;
      end loop;
      for S of Extra loop
         Turbo.Script.Add (S);
      end loop;
      Turbo.Term.Start_Virtual (Rows, Cols, Turbo.Script.Source'Access);
      begin
         Turbo.App.Run (Files, To_String (Start_Dir));
      exception
         when Turbo.Term.Script_Ended =>
            null;
      end;
      if Turbo.Script.Failures > 0 then
         Set_Exit_Status (Failure);
      end if;
   end UI;

   --  debug

   Watches   : String_Vectors.Vector;
   Failed    : Boolean := False;
   Last_Line : Natural := 0;

   procedure Check (Ok : Boolean; Why : String) is
   begin
      if not Ok then
         Put_Line (Standard_Error, "tada-cli: FAILED: " & Why);
         Failed := True;
      end if;
   end Check;

   function Evaluate (Expr : String) return String is
      R : GDB.Result;
   begin
      GDB.Command ("-data-evaluate-expression " & GDB.Quote (Expr), R);
      return (if R.Ok then R.Doc.To_String (R.Doc.Get (R.Value, "value"))
              else "<" & To_String (R.Error) & ">");
   end Evaluate;

   procedure Show_Console is
   begin
      for L of GDB.Take_Console loop
         Put_Line ("| " & L);
      end loop;
   end Show_Console;

   procedure Wait_Stop (Limit : Duration := 120.0) is
   --  Until the program stops (or exits), printing its output meanwhile.
      Deadline : constant Ada.Calendar.Time := Ada.Calendar.Clock + Limit;
      S        : GDB.Stop_Info;
   begin
      loop
         GDB.Poll;
         Show_Console;
         if GDB.Take_Stop (S) then
            declare
               Reason : constant String := To_String (S.Reason);
               File   : constant String := To_String (S.File);
            begin
               delay 0.05;          --  output written just before the stop
               GDB.Poll;
               Show_Console;
               if Reason'Length >= 6 and then Reason (Reason'First .. Reason'First + 5) = "exited" then
                  Put_Line ("exited" & (if Reason = "exited-normally" then " normally"
                                        else " " & To_String (S.Detail)));
                  Last_Line := 0;
                  GDB.Stop;
                  return;
               end if;
               Last_Line := S.Line;
               Put_Line ("stopped  " & (if Reason = "" then "-" else Reason) & "  "
                         & (if File = "" then To_String (S.Addr)
                            else Ada.Directories.Simple_Name (File) & ":" & Img (S.Line))
                         & "  " & To_String (S.Func)
                         & (if To_String (S.Detail) /= "" then "  (" & To_String (S.Detail) & ")" else ""));
               for W of Watches loop
                  Put_Line ("  " & W & " = " & Evaluate (W));
               end loop;
               return;
            end;
         end if;
         if GDB.State not in GDB.Stopped | GDB.Running then
            Check (False, "the session ended: " & GDB.Last_Error);
            return;
         end if;
         if Ada.Calendar.Clock > Deadline then
            Check (False, "no stop within" & Duration'Image (Limit) & " s");
            return;
         end if;
         delay 0.05;
      end loop;
   end Wait_Stop;

   procedure Resume (Cmd : String) is
      R : GDB.Result;
   begin
      if GDB.State /= GDB.Stopped then
         Check (False, Cmd & ": the program is not stopped");
         return;
      end if;
      GDB.Command (Cmd, R);
      if R.Ok then
         Wait_Stop;
      else
         Check (False, Cmd & ": " & To_String (R.Error));
      end if;
   end Resume;

   procedure Break (Loc : String; Temporary : Boolean := False) is
      R : GDB.Result;
   begin
      GDB.Command ("-break-insert " & (if Temporary then "-t " else "") & GDB.Quote (Loc), R);
      Check (R.Ok, "break " & Loc & ": " & To_String (R.Error));
   end Break;

   function Console_Device return String is
   --  The board's console, as the IDE opens it for a debug session: the
   --  project's choice, else the port the SDK would flash (./x ports).
      Ok   : Boolean;
      Text : constant String :=
        (if Prj.Console /= "" and then Prj.Console /= "uart" then ""
         elsif Prj.Console = "" and then Prj.Port /= "" then ""
         elsif Prj.Ports_Command = "" then ""
         else Capture (Prj.Ports_Command, Prj.Root, Ok));
      Doc  : Turbo.JSON.Document;
   begin
      if Prj.Console /= "" and then Prj.Console /= "uart" then
         return Prj.Console;
      elsif Prj.Console = "" and then Prj.Port /= "" then
         return Prj.Port;
      end if;
      Doc.Parse (Text, Ok);
      if not Ok then
         return "";
      elsif Prj.Console = "" then
         return Doc.To_String (Doc.Get (Doc.Root, "flash"));
      end if;
      declare
         List : constant Turbo.JSON.Value := Doc.Get (Doc.Root, "ports");
      begin
         for N in 1 .. Doc.Length (List) loop
            if Doc.To_String (Doc.Get (Doc.Element (List, N), "role")) = "uart" then
               return Doc.To_String (Doc.Get (Doc.Element (List, N), "path"));
            end if;
         end loop;
      end;
      return "";
   end Console_Device;

   procedure Start_Session (Build : Boolean) is
      Ok : Boolean;
   begin
      if not Prj.Can_Debug then
         raise Usage_Error with "this project cannot be debugged (" & Prj.Kind_Image & ")";
      end if;
      if Prj.Target = Prj.Target_Native then
         if Build then
            Check (Shell (Prj.Command_For (Prj.Act_Build), Prj.Working_Dir (Prj.Act_Build)) = 0,
                   "the build failed");
            if Failed then
               return;
            end if;
         end if;
         declare
            use type GNAT.OS_Lib.String_Access;
            Exe : constant String := Prj.Native_Executable;
            Gdb_Exe : GNAT.OS_Lib.String_Access := GNAT.OS_Lib.Locate_Exec_On_Path ("gdb");
         begin
            if Exe = "" or else Gdb_Exe = null then
               Check (False, (if Exe = "" then "no program built (build it, or drop --no-build)"
                              else "no gdb on PATH"));
               GNAT.OS_Lib.Free (Gdb_Exe);
               return;
            end if;
            Put_Line ("debugging " & Exe);
            GDB.Start_Native (Gdb_Exe.all, Exe, Prj.Dir, Ok);
            GNAT.OS_Lib.Free (Gdb_Exe);
         end;
         Check (Ok, "gdb did not start: " & GDB.Last_Error);
         if Ok then
            Resume ("-exec-run --start");      --  stops at the Ada main
         end if;
      else
         if Build then
            Check (Shell (Prj.Command_For (Prj.Act_Flash), Prj.Working_Dir (Prj.Act_Flash)) = 0,
                   "the flash failed");
            if Failed then
               return;
            end if;
         end if;
         declare
            Info : constant String := Capture (Prj.Debug_Info_Command, Prj.Root, Ok);
            Gdb_Path, Elf, Main : Unbounded_String := To_Unbounded_String ("_ada_main");
            P : Natural := Info'First;
         begin
            Check (Ok, "no debug tools (" & Prj.Debug_Tools_Command & " gets them)");
            if not Ok then
               return;
            end if;
            while P <= Info'Last loop
               declare
                  E : Natural := Ada.Strings.Fixed.Index (Info (P .. Info'Last), "" & ASCII.LF);
               begin
                  if E = 0 then
                     E := Info'Last + 1;
                  end if;
                  declare
                     L : constant String := Info (P .. E - 1);
                  begin
                     if L'Length > 4 and then L (L'First .. L'First + 3) = "GDB=" then
                        Gdb_Path := To_Unbounded_String (L (L'First + 4 .. L'Last));
                     elsif L'Length > 4 and then L (L'First .. L'First + 3) = "ELF=" then
                        Elf := To_Unbounded_String (L (L'First + 4 .. L'Last));
                     elsif L'Length > 5 and then L (L'First .. L'First + 4) = "MAIN=" then
                        Main := To_Unbounded_String (L (L'First + 5 .. L'Last));
                     end if;
                  end;
                  P := E + 1;
               end;
            end loop;
            Put_Line ("starting OpenOCD");
            GDB.Start_Server (Prj.Debug_Server_Command, Prj.Root, Ok);
            Check (Ok, "OpenOCD did not start: " & GDB.Last_Error);
            if Ok then
               GDB.Start (To_String (Gdb_Path), To_String (Elf), Prj.Root, Ok);
               if Ok then
                  GDB.Reset_Halt (Ok);
               end if;
               Check (Ok, "GDB could not take the board: " & GDB.Last_Error);
            end if;
            if Ok then
               declare
                  Dev : constant String := Console_Device;
               begin
                  --  As the IDE does: a USB-Serial/JTAG console nobody reads
                  --  stalls the program at its next output.
                  if Dev /= "" then
                     GDB.Start_Console
                       ("stty -F " & Dev & " 115200 raw -echo 2>/dev/null; exec cat " & Dev, Prj.Root);
                  end if;
               end;
            end if;
            if Ok then
               Put_Line ("debugging " & To_String (Elf) & " on the board");
               Break (To_String (Main), Temporary => True);
               Resume ("-exec-continue");
            end if;
         end;
      end if;
   end Start_Session;

   procedure Debug is
      Steps  : String_Vectors.Vector;
      Breaks : String_Vectors.Vector;
      Build  : Boolean := True;
   begin
      while More loop
         declare
            A : constant String := Take;
         begin
            if A = "--break" then
               Breaks.Append (Take);
            elsif A = "--watch" then
               Watches.Append (Take);
            elsif A = "--no-build" then
               Build := False;
            elsif A = "-e" then
               Steps.Append (Take);
            elsif A = "--script" then
               declare
                  F : File_Type;
                  N : constant String := Take;
               begin
                  Open (F, In_File, N);
                  while not End_Of_File (F) loop
                     declare
                        L : constant String := Ada.Strings.Fixed.Trim (Get_Line (F), Ada.Strings.Both);
                     begin
                        if L /= "" and then L (L'First) /= '#' then
                           Steps.Append (L);
                        end if;
                     end;
                  end loop;
                  Close (F);
               end;
            else
               raise Usage_Error with "debug: unknown argument " & A;
            end if;
         end;
      end loop;
      if Steps.Is_Empty or else Steps.First_Element /= "start" then
         Steps.Prepend ("start");
      end if;

      for S of Steps loop
         exit when Failed;
         declare
            Sp   : constant Natural := Ada.Strings.Fixed.Index (S, " ");
            Verb : constant String := (if Sp = 0 then S else S (S'First .. Sp - 1));
            Arg  : constant String :=
              (if Sp = 0 then "" else Ada.Strings.Fixed.Trim (S (Sp + 1 .. S'Last), Ada.Strings.Both));
         begin
            Put_Line ("> " & S);
            if Verb = "start" then
               Start_Session (Build);
               for B of Breaks loop
                  Break (B);
               end loop;
            elsif GDB.State = GDB.Off then
               Check (False, Verb & ": the program has ended");
            elsif Verb = "step" then
               Resume ("-exec-step");
            elsif Verb = "next" then
               Resume ("-exec-next");
            elsif Verb = "finish" then
               Resume ("-exec-finish");
            elsif Verb = "continue" then
               Resume ("-exec-continue");
            elsif Verb = "until" then
               Break (Arg, Temporary => True);
               Resume ("-exec-continue");
            elsif Verb = "break" then
               Break (Arg);
            elsif Verb = "watch" then
               Watches.Append (Arg);
               Put_Line ("  " & Arg & " = " & Evaluate (Arg));
            elsif Verb = "print" then
               declare
                  Assign : constant Natural := Ada.Strings.Fixed.Index (Arg, ":=");
                  Out_Text : Unbounded_String;
                  Ok : Boolean;
               begin
                  if Assign > 0 then
                     GDB.Console_Command ("set variable " & Arg, Out_Text, Ok);
                     Check (Ok, "print " & Arg & ": " & To_String (Out_Text));
                     Put_Line ("  " & Ada.Strings.Fixed.Trim (Arg (Arg'First .. Assign - 1), Ada.Strings.Both)
                               & " = " & Evaluate (Arg (Assign + 2 .. Arg'Last)));
                  else
                     Put_Line ("  " & Arg & " = " & Evaluate (Arg));
                  end if;
               end;
            elsif Verb = "stack" then
               declare
                  R : GDB.Result;
               begin
                  GDB.Command ("-stack-list-frames", R);
                  if R.Ok then
                     declare
                        Stack : constant Turbo.JSON.Value := R.Doc.Get (R.Value, "stack");
                     begin
                        for N in 1 .. R.Doc.Length (Stack) loop
                           declare
                              F : constant Turbo.JSON.Value := R.Doc.Element (Stack, N);
                           begin
                              Put_Line ("  #" & Img (N - 1) & " " & R.Doc.To_String (R.Doc.Get (F, "func"), "??")
                                        & "  " & R.Doc.To_String (R.Doc.Get (F, "file"))
                                        & ":" & R.Doc.To_String (R.Doc.Get (F, "line")));
                           end;
                        end loop;
                     end;
                  else
                     Check (False, "stack: " & To_String (R.Error));
                  end if;
               end;
            elsif Verb = "wait" then
               declare
                  Until_T : constant Ada.Calendar.Time := Ada.Calendar.Clock + Duration'Value (Arg);
               begin
                  while Ada.Calendar.Clock < Until_T loop
                     GDB.Poll;
                     Show_Console;
                     delay 0.05;
                  end loop;
               end;
            elsif Verb = "expect-line" then
               Check (Last_Line = Natural'Value (Arg),
                      "expected to stop at line " & Arg & ", stopped at" & Natural'Image (Last_Line));
            elsif Verb = "expect-value" then
               declare
                  Sp2  : constant Natural := Ada.Strings.Fixed.Index (Arg, " ", Ada.Strings.Backward);
                  Expr : constant String := (if Sp2 = 0 then Arg else Arg (Arg'First .. Sp2 - 1));
                  Want : constant String := (if Sp2 = 0 then "" else Arg (Sp2 + 1 .. Arg'Last));
                  Got  : constant String := Evaluate (Expr);
               begin
                  Check (Got = Want, Expr & " = " & Got & ", expected " & Want);
               end;
            else
               raise Usage_Error with "debug: unknown step """ & S & """";
            end if;
         end;
      end loop;
      GDB.Stop;
      if Failed then
         Set_Exit_Status (Failure);
      end if;
   end Debug;

begin
   for K in 1 .. Argument_Count loop
      Args.Append (Argument (K));
   end loop;
   if More and then Args (Pos) = "-C" then
      Pos := Pos + 1;
      Start_Dir := To_Unbounded_String (Ada.Directories.Full_Name (Take));
      Ada.Directories.Set_Directory (To_String (Start_Dir));
   end if;
   if not More then
      Usage;
      Set_Exit_Status (2);
      return;
   end if;
   declare
      Cmd : constant String := Take;
   begin
      if Cmd in "-h" | "--help" | "help" then
         Usage;
      elsif Cmd in "version" | "-v" | "--version" then
         Put_Line ("Turbo Ada " & Turbo.Version);
      elsif Cmd = "keys" then
         Put_Line (Turbo.Script.Key_Names);
      elsif Cmd = "project" then
         declare
            Sub : constant String := (if More then Take else "info");
         begin
            if Sub /= "info" then
               raise Usage_Error with "project: info";
            end if;
            Prj.Detect (To_String (Start_Dir));
            Project_Info (Json => More and then Take = "--json");
         end;
      elsif Cmd = "ui" then
         UI;
      elsif Cmd = "debug" then
         Prj.Detect (To_String (Start_Dir));
         Debug;
      else
         raise Usage_Error with "unknown command " & Cmd;
      end if;
   end;
exception
   when E : Ada.Text_IO.Name_Error =>
      Put_Line (Standard_Error, "tada-cli: cannot open " & Ada.Exceptions.Exception_Message (E)
                & " (a relative path is taken from the -C directory)");
      Set_Exit_Status (2);
   when E : Usage_Error | Turbo.Script.Bad_Step =>
      Put_Line (Standard_Error, "tada-cli: " & Ada.Exceptions.Exception_Message (E));
      Put_Line (Standard_Error, "tada-cli --help for the commands");
      GDB.Stop;
      Set_Exit_Status (2);
end Tada_Cli;
