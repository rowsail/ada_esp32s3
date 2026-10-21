--  tada_host: checks for the parts of Turbo Ada that do not need a screen.

with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Turbo.Buffers;
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
      Check (Command_For (Act_Build) = "./x build gpio0_blink", "x build");
      Set_Port ("/dev/ttyUSB1");
      Set_Profile ("embedded");
      Check (Command_For (Act_Flash) = "./x flash gpio0_blink -p /dev/ttyUSB1", "x flash -p");
      Check (Command_For (Act_Run) = "./x run gpio0_blink -p /dev/ttyUSB1 -P embedded",
             "x run -p -P");
      Set_Template (Act_Build, "./x build {example} --verbose{profile_opt}");
      Check (Command_For (Act_Build) = "./x build gpio0_blink --verbose -P embedded",
             "a changed template");
      Set_Template (Act_Build, Default_Template (Act_Build));
      Check (Template (Act_Build) = Default_Template (Act_Build), "back to the default");
      Check (Locate_Source ("main.adb") /= "", "a source found in the project");
      Check (not Examples.Is_Empty, "the SDK lists its examples");

      --  This IDE's own crate inside the SDK is a crate, not the SDK.
      Detect (SDK & "/ide/turbo-ada");
      Check (Kind = Alire_Crate and then Name = "turbo-ada",
             "a crate inside the SDK repository is that crate");
   end Project_Tests;

begin
   Buffer_Tests;
   Message_Tests;
   Syntax_Tests;
   Project_Tests (if Ada.Command_Line.Argument_Count > 0
                  then Ada.Command_Line.Argument (1) else "");
   Put_Line (Natural'Image (Checks) & " checks," & Natural'Image (Failures) & " failed");
   if Failures > 0 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Tada_Host;
