--  tada_host: checks for the parts of Turbo Ada that do not need a screen.

with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Ada.Environment_Variables;
with Turbo.Buffers;
with Turbo.JSON;
with Turbo.LSP;
with Turbo.Messages;
with Turbo.Projects;
with Turbo.Syntax;

procedure Tada_Host is

   use Ada.Text_IO;
   use Turbo.Buffers;
   use type Turbo.Messages.Msg_Kind;
   use type Turbo.Projects.Project_Kind;
   use type Turbo.Syntax.Token_Class;

   Failures : Natural := 0;
   Checks   : Natural := 0;

   procedure Check (Ok : Boolean; What : String) is
   begin
      Checks := Checks + 1;
      if not Ok then
         Failures := Failures + 1;
         Put_Line ("FAIL  " & What);
      end if;
   end Check;

   function W (S : String) return Wide_Wide_String is
      R : Wide_Wide_String (S'Range);
   begin
      for I in S'Range loop
         R (I) := Wide_Wide_Character'Val (Character'Pos (S (I)));
      end loop;
      return R;
   end W;

   LF : constant Wide_Wide_Character := Wide_Wide_Character'Val (10);

   procedure Buffer_Tests is
      B     : Buffer;
      After : Position;
      Cur   : Position;
   begin
      Check (B.Line_Count = 1 and then B.Line (1) = "", "a new buffer has one empty line");

      B.Insert ((1, 1), "procedure P is" & LF & "begin" & LF & "end P;", After);
      Check (B.Line_Count = 3, "multi-line insert makes three lines");
      Check (After = (3, 7), "insert reports the position after the text");
      Check (B.Modified, "an insert modifies");

      B.Delete ((1, 10), (2, 1));
      Check (B.Line (1) = "procedure" & "begin", "delete across a line end joins the lines");

      B.Undo (Cur);
      Check (B.Line (1) = "procedure P is" and then B.Line (2) = "begin",
             "undo restores the deleted text");
      B.Redo (Cur);
      Check (B.Line (1) = "procedurebegin", "redo deletes it again");
      B.Undo (Cur);

      --  Typed characters merge into one undo step per word.
      B.Set_Unmodified;
      B.Insert ((3, 7), " ", After);
      for C of Wide_Wide_String'("xyz") loop
         declare
            At_Pos : constant Position := After;
         begin
            B.Insert (At_Pos, (1 => C), After);
         end;
      end loop;
      Check (B.Line (3) = "end P; xyz", "typed characters land in order");
      B.Undo (Cur);
      Check (B.Line (3) = "end P; ", "one undo removes the typed word");
      B.Undo (Cur);
      Check (B.Line (3) = "end P;", "the next undo removes the blank");
      Check (not B.Modified, "undoing back to the save point is unmodified");

      --  A save in the middle of typing starts a new undo step.
      B.Insert ((3, 7), "a", After);
      B.Set_Unmodified;
      B.Insert ((3, 8), "b", After);
      Check (B.Modified, "typing after a save is a modification");

      --  Groups undo together.
      B.Begin_Group ((1, 1));
      B.Insert ((1, 1), "-- one" & LF, After);
      B.Insert ((1, 1), "-- two" & LF, After);
      B.End_Group;
      Check (B.Line (1) = "-- two" and then B.Line (2) = "-- one", "grouped inserts");
      B.Undo (Cur);
      Check (B.Line (1) = "procedure P is", "a group undoes as one");

      --  Search.
      declare
         Found : Position;
      begin
         Check (B.Find ("BEGIN", (1, 1), True, False, False, Found) and then Found = (2, 1),
                "case-insensitive find");
         Check (not B.Find ("BEGIN", (1, 1), True, True, False, Found),
                "case-sensitive find misses");
         Check (not B.Find ("P", (1, 1), True, True, True, Found)
                or else Found /= (1, 1), "whole word skips 'procedure'");
         Check (B.Find ("P", (1, 1), True, True, True, Found) and then Found = (1, 11),
                "whole word finds 'P'");
         Check (B.Find ("e", (3, 1), False, True, False, Found) and then Found.Line = 2,
                "backward find");
      end;

      Check (B.Text ((1, 11), (2, 3)) = "P is" & LF & "be", "Text spans lines");
      Check (B.Clamp ((99, 99)) = B.Last_Position, "Clamp past the end");
   end Buffer_Tests;

   procedure Message_Tests is
      use Ada.Strings.Unbounded;
      use Turbo.Messages;
      M : Message;
   begin
      M := Parse ("main.adb:12:5: error: missing "";""");
      Check (M.Kind = Error and then To_String (M.File) = "main.adb"
             and then M.Line = 12 and then M.Col = 5, "GNAT error");
      M := Parse ("src/gpio.ads:3:01: warning: unit ""X"" is not referenced [-gnatwu]");
      Check (M.Kind = Warning and then M.Line = 3 and then M.Col = 1, "GNAT warning");
      M := Parse ("hello.adb:7:04: (style) bad indentation [-gnaty3]");
      Check (M.Kind = Warning, "style check counts as a warning");
      M := Parse ("hello.adb:9:1: info: ""Foo"" inlined");
      Check (M.Kind = Note, "info is a note");
      M := Parse ("main.adb:12:5: missing "";""");
      Check (M.Kind = Error, "pre-GNAT-13 error without 'error:'");
      M := Parse ("app.gpr:4: unknown attribute");
      Check (M.Kind = Error and then M.Line = 4 and then M.Col = 1, "file:line without a column");
      M := Parse ("C:\work\blink\src\main.adb:3:2: error: x");
      Check (M.Line = 3 and then To_String (M.File) = "C:\work\blink\src\main.adb",
             "Windows drive letter");
      M := Parse ("gprbuild: *** compilation phase failed");
      Check (M.Line = 0, "a tool line is not a location");
      M := Parse ("ERROR: Command [""gprbuild"", ""-P"", ""x.gpr""] exited with code 4");
      Check (M.Line = 0, "an Alire error line is not a location");
      M := Parse ("   [Ada]          main.adb");
      Check (M.Line = 0, "a gprbuild progress line is not a location");
   end Message_Tests;

   procedure JSON_Tests is
      use Turbo.JSON;
      D  : Document;
      Ok : Boolean;
   begin
      D.Parse ("{""id"": 7, ""result"": [{""uri"": ""file:///a%20b.adb"", ""range"": "
               & "{""start"": {""line"": 3, ""character"": 9}}}, null, true, -2.5e1],"
               & """s"": ""tab\tq\""\u00e9\ud83d\ude00"", ""e"": {}, ""a"": []}", Ok);
      Check (Ok, "JSON parses");
      declare
         R : constant Value := Root (D);
         A : constant Value := Get (D, R, "result");
      begin
         Check (To_Integer (D, Get (D, R, "id")) = 7, "JSON integer");
         Check (Length (D, A) = 4 and then Kind_Of (D, Element (D, A, 2)) = J_Null
                and then To_Boolean (D, Element (D, A, 3)), "JSON array, null, bool");
         Check (To_Integer (D, Path (D, Element (D, A, 1), "range.start.character")) = 9,
                "JSON Path");
         Check (To_String (D, Get (D, R, "s")) =
                  "tab" & ASCII.HT & "q""" & Character'Val (16#C3#) & Character'Val (16#A9#)
                  & Character'Val (16#F0#) & Character'Val (16#9F#) & Character'Val (16#98#)
                  & Character'Val (16#80#), "JSON escapes and surrogate pairs to UTF-8");
         Check (Kind_Of (D, Get (D, R, "e")) = J_Object and then Length (D, Get (D, R, "a")) = 0,
                "JSON empty object and array");
         Check (not Is_Present (Get (D, Get (D, R, "missing"), "deeper")),
                "JSON missing members chain safely");
      end;
      D.Parse ("{""a"": [1, 2", Ok);
      Check (not Ok, "truncated JSON is rejected");
      D.Parse (Quote ("a""b\c" & ASCII.LF & Character'Val (1)), Ok);
      Check (Ok and then To_String (D, Root (D)) = "a""b\c" & ASCII.LF & Character'Val (1),
             "Quote round-trips");
   end JSON_Tests;

   procedure LSP_Helper_Tests is
      use Turbo.LSP;
      Smile : constant Wide_Wide_String :=
        "a" & Wide_Wide_Character'Val (16#1F600#) & "b";
   begin
      Check (URI ("/tmp/a b/x.adb") = "file:///tmp/a%20b/x.adb", "URI escapes a space");
      Check (Path_Of ("file:///tmp/a%20b/x.adb") = "/tmp/a b/x.adb", "Path_Of decodes it");
      Check (To_Char (Smile, 3) = 3 and then To_Char (Smile, 4) = 4,
             "UTF-16 offset counts a non-BMP character twice");
      Check (To_Col (Smile, 3) = 3 and then To_Col (Smile, 4) = 4 and then To_Col (Smile, 0) = 1,
             "and back");
   end LSP_Helper_Tests;

   procedure Machine_Line_Tests is
      use Turbo.Messages;
      W : constant Message_Window_Access := Create;
   begin
      W.Add_Line ("@x protocol 1");
      Check (W.Line_Count = 0, "@x protocol is not shown");
      W.Add_Line ("@x stage 1/4 Ada -> app_main.o");
      Check (W.Line_Count = 1, "@x stage is shown");
      Check (Stage_Of ("@x stage 2/4 link") = "2/4 link" and then Stage_Of ("[bare] 2/4") = "",
             "Stage_Of");
      W.Add_Line ("@x diag error /sdk/examples/x/src/main.adb:18:19: error: bad");
      W.Add_Line ("@x diag style /sdk/libs/h/src/h.ads:2:1: (style) blank line");
      W.Add_Line ("@x artifact bin /sdk/examples/x/app.bin");
      W.Add_Line ("@x result fail 4");
      Check (W.Errors = 1 and then W.Warnings = 1, "@x diag counted by severity");
      Check (W.Line_Count = 4, "@x result is not shown, artifact is");
   end Machine_Line_Tests;

   procedure Syntax_Tests is
      use Turbo.Syntax;
      procedure Classes_Of (S : String; Want : String; What : String) is
      --  Want: one letter per character: n k c s d p
         L : constant Wide_Wide_String := W (S);
         C : Class_Array (L'Range);
         Got : String (S'Range);
      begin
         Classify (Ada_Lang, L, C);
         for I in C'Range loop
            Got (I) := (case C (I) is
                           when Normal => 'n', when Keyword => 'k',
                           when Comment => 'c', when String_Lit => 's',
                           when Number => 'd', when Directive => 'p');
         end loop;
         Check (Got = Want, What & ": got " & Got);
      end Classes_Of;
   begin
      Classes_Of ("if X then", "kknnnkkkk", "keywords");
      Classes_Of ("X := 1; -- hi", "nnnnndnnccccc", "comment");
      Classes_Of ("C := 'a';", "nnnnnsssn", "character literal");
      Classes_Of ("X'First", "nnnnnnn", "attribute tick is not a literal");
      Classes_Of ("T'('a')", "nnnsssn", "qualified character literal");
      Classes_Of ("16#FF#", "dddddd", "based literal");
      Classes_Of ("""a""""b""", "ssssss", "doubled quote in a string");
      Classes_Of ("pragma Pure;", "kkkkkknppppn", "pragma name");
      Check (Language_Of ("x.ads") = Ada_Lang and then Language_Of ("build.sh") = Shell_Lang
             and then Language_Of ("glue.c") = C_Lang and then Language_Of ("README") = Plain,
             "language from the file name");
   end Syntax_Tests;

   procedure Project_Tests (SDK : String) is
      use Turbo.Projects;
      Tmp : constant String := Ada.Directories.Full_Name ("obj/crate");
   begin
      --  An Alire crate.
      Ada.Directories.Create_Path (Tmp);
      declare
         F : File_Type;
      begin
         Create (F, Out_File, Ada.Directories.Compose (Tmp, "alire.toml"));
         Put_Line (F, "name = ""crate""");
         Close (F);
      end;
      Detect (Tmp);
      Check (Kind = Alire_Crate, "an alire.toml is an Alire crate");
      Check (Command_For (Act_Build) = "alr -n build", "alr build");
      Check (Command_For (Act_Flash) = "", "no flash for a plain crate");
      Check (Is_Interactive (Act_Run) and then not Is_Interactive (Act_Build),
             "run is interactive, build is captured");

      if SDK = "" then
         return;
      end if;

      --  An SDK example, found from inside it.
      Detect (SDK & "/examples/esp32s3_gpio0_blink/src");
      Check (Kind = SDK_Example, "inside examples/ is an SDK example");
      Check (Example = "gpio0_blink", "the example is the one we are in");
      Set_Port ("");
      Set_Profile ("");
      Check (Command_For (Act_Build) = "./x --machine build gpio0_blink", "x build (machine)");
      Set_Port ("/dev/ttyUSB1");
      Set_Profile ("embedded");
      Check (Command_For (Act_Flash) = "./x --machine flash gpio0_blink -p /dev/ttyUSB1",
             "x flash -p");
      Check (Command_For (Act_Run) = "./x run gpio0_blink -p /dev/ttyUSB1 -P embedded",
             "x run -p -P");
      Check (Command_For (Act_Env) = "./x env gpio0_blink -P embedded", "x env");

      --  The environment: KEY=VALUE (./x env) and export KEY="VALUE" (alr).
      declare
         L : String_List;
      begin
         L.Append ("PATH=/opt/tc/bin:/usr/bin");
         L.Append ("export GPR_PROJECT_PATH=""/a:/b""");
         L.Append ("GPR_FILE=/sdk/examples/x/x.gpr");
         L.Append ("[esp32s3_rts] runtime ready: not=a variable");
         Set_Environment (L);
         Check (Environment_Loaded and then Env_Value ("GPR_PROJECT_PATH") = "/a:/b"
                and then Env_Value ("PATH") = "/opt/tc/bin:/usr/bin",
                "environment lines parsed");
         Check (Main_Gpr = "/sdk/examples/x/x.gpr", "GPR_FILE names the project");
         declare
            Cmd : constant String := Command_For (Act_Check, "/sdk/examples/x/src/main.adb");
         begin
            Check (Cmd = "gprbuild -c -u -f -q -P /sdk/examples/x/x.gpr "
                   & "/sdk/examples/x/src/main.adb --relocate-build-tree=" & Scratch_Dir
                   & " --root-dir=/ -cargs -gnatc -gnatef", "check command: " & Cmd);
         end;
         Check (Command_For (Act_Check) = "", "no check without a file");
         Ada.Environment_Variables.Set ("GPR_PROJECT_PATH", "before");
         Push_Environment;
         Check (Ada.Environment_Variables.Value ("GPR_PROJECT_PATH") = "/a:/b"
                and then not Ada.Environment_Variables.Exists ("GPR_FILE"),
                "Push sets the variables (not GPR_FILE)");
         Pop_Environment;
         Check (Ada.Environment_Variables.Value ("GPR_PROJECT_PATH") = "before",
                "Pop restores them");
         Set_Profile ("full");
         Check (not Environment_Loaded, "a profile change forgets the environment");
         Set_Profile ("embedded");
      end;
      Set_Template (Act_Build, "./x build {example} --verbose{profile_opt}");
      Check (Command_For (Act_Build) = "./x build gpio0_blink --verbose -P embedded",
             "a changed template");
      Set_Template (Act_Build, Default_Template (Act_Build));
      Check (Template (Act_Build) = Default_Template (Act_Build), "back to the default");
      Check (Locate_Source ("main.adb") /= "", "a source found in the project");
      Check (not Examples.Is_Empty, "the SDK lists its examples");

      --  A library's host test suite: the same SDK, built natively.
      Detect (SDK & "/libs/esp32s3_hal/test/dns_host");
      Check (Kind = SDK_Example and then Suite = "dns_host" and then Example = ""
             and then Target = Target_Native, "inside a host suite: that suite, native");
      Check (Command_For (Act_Build) = "./x --machine test host dns_host", "suite build");
      Check (Command_For (Act_Env) = "./x env dns_host", "suite environment");
      Check (Command_For (Act_Flash) = "" and then Command_For (Act_Monitor) = "",
             "nothing to flash natively");
      Check (Main_Source = SDK & "/libs/esp32s3_hal/test/dns_host/dns_host.adb",
             "the suite's main from its .gpr");
      Check (Host_Suites.Contains ("chain_host"), "suites from every library");
      Set_Example ("gpio0_blink");
      Check (Suite = "" and then Target = Target_Esp32s3
             and then Command_For (Act_Build) = "./x --machine build gpio0_blink",
             "choosing an example leaves the suite");
      Set_Suite ("p384_host");
      Check (Target = Target_Native and then Name = "p384_host", "and back");

      --  This IDE's own crate inside the SDK is a crate, not the SDK.
      Detect (SDK & "/ide/turbo-ada");
      Check (Kind = Alire_Crate and then Name = "turbo-ada" and then Target = Target_Native,
             "a crate inside the SDK repository is that crate, native");
   end Project_Tests;

begin
   Buffer_Tests;
   Message_Tests;
   Syntax_Tests;
   JSON_Tests;
   LSP_Helper_Tests;
   Machine_Line_Tests;
   Project_Tests (if Ada.Command_Line.Argument_Count > 0
                  then Ada.Command_Line.Argument (1) else "");
   Put_Line (Natural'Image (Checks) & " checks," & Natural'Image (Failures) & " failed");
   if Failures > 0 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Tada_Host;
