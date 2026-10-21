with Ada.Characters.Handling;
with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Containers.Indefinite_Ordered_Maps;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Hash;
with Ada.Strings.Maps;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with GNAT.OS_Lib;
with Turbo.Term;

package body Turbo.Projects is

   use Ada.Directories;
   use Ada.Strings.Unbounded;
   use type GNAT.OS_Lib.String_Access;

   package Option_Maps is new Ada.Containers.Indefinite_Ordered_Maps
     (String, String);

   package Path_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (String, String, Ada.Strings.Hash, "=");

   The_Kind    : Project_Kind := No_Project;
   The_Root    : Unbounded_String;
   The_Dir     : Unbounded_String;
   The_Example : Unbounded_String;
   The_Suite   : Unbounded_String;
   The_Port    : Unbounded_String;
   The_Console : Unbounded_String;
   The_Profile : Unbounded_String;
   Templates   : array (Target_Kind, Action) of Unbounded_String;  --  "" = default
   Options     : Option_Maps.Map;
   Desktop     : String_List;
   Sources     : Path_Maps.Map;
   Scanned     : Boolean := False;

   function Exists_File (P : String) return Boolean is
     (Exists (P) and then Kind (P) = Ordinary_File);

   function Exists_Dir (P : String) return Boolean is
     (Exists (P) and then Kind (P) = Directory);

   function Parent (P : String) return String is
   begin
      return Containing_Directory (P);
   exception
      when others => return P;
   end Parent;

   function Is_SDK_Root (D : String) return Boolean is
     (Exists_File (Compose (D, "x")) and then Exists_Dir (Compose (D, "examples"))
      and then Exists_Dir (Compose (D, "crates")));

   function Kind return Project_Kind is (The_Kind);
   function Root return String is (To_String (The_Root));
   function Dir return String is (To_String (The_Dir));
   function Example return String is (To_String (The_Example));
   function Suite return String is (To_String (The_Suite));

   function Target return Target_Kind is
     (if (The_Kind = SDK_Example and then The_Suite /= Null_Unbounded_String)
        or else The_Kind = Alire_Crate or else The_Kind = No_Project
      then Target_Native else Target_Esp32s3);

   function Target_Image return String is
     (case Target is
         when Target_Esp32s3 => "ESP32-S3",
         when Target_Native  => "native");
   function Port return String is (To_String (The_Port));
   function Console return String is (To_String (The_Console));
   function Profile return String is (To_String (The_Profile));

   function Kind_Image return String is
     (case The_Kind is
         when No_Project  => "no project",
         when SDK_Example =>
           (if The_Suite /= Null_Unbounded_String then "ESP32-S3 SDK host test (native)"
            else "ESP32-S3 SDK example"),
         when Standalone  => "esp32-ada project",
         when Alire_Crate => "Alire crate");

   function Name return String is
   begin
      case The_Kind is
         when No_Project  => return "";
         when SDK_Example =>
            return (if Suite /= "" then Suite
                    elsif Example = "" then "(no example chosen)" else Example);
         when others =>
            return Simple_Name (Dir);
      end case;
   end Name;

   --  Examples

   function Full_Example_Dir (Short : String) return String is
   begin
      if Exists_Dir (Compose (Compose (Root, "examples"), Short)) then
         return Compose (Compose (Root, "examples"), Short);
      end if;
      return Compose (Compose (Root, "examples"), "esp32s3_" & Short);
   end Full_Example_Dir;

   function Examples return String_List is
      Names  : Option_Maps.Map;     --  sorted, via the ordered map
      S      : Search_Type;
      E      : Directory_Entry_Type;
      Result : String_List;
   begin
      if The_Kind /= SDK_Example then
         return Result;
      end if;
      Start_Search (S, Compose (Root, "examples"), "",
                    [Directory => True, others => False]);
      while More_Entries (S) loop
         Get_Next_Entry (S, E);
         declare
            N : constant String := Simple_Name (E);
         begin
            if N /= "." and then N /= ".."
              and then Exists_File (Compose (Full_Name (E), "build.sh"))
            then
               declare
                  Short : constant String :=
                    (if N'Length > 8 and then N (N'First .. N'First + 7) = "esp32s3_"
                     then N (N'First + 8 .. N'Last) else N);
               begin
                  Names.Include (Short, N);
               end;
            end if;
         end;
      end loop;
      End_Search (S);
      for C in Names.Iterate loop
         Result.Append (Option_Maps.Key (C));
      end loop;
      return Result;
   exception
      when others =>
         return Result;
   end Examples;

   Profile_Cache_Key   : Unbounded_String;
   Profile_Cache_Value : Unbounded_String;

   function Read_Profile (Example : String) return String;

   function Example_Profile (Example : String) return String is
   begin
      if To_String (Profile_Cache_Key) /= Example
        or else Profile_Cache_Value = Null_Unbounded_String
      then
         Profile_Cache_Value := To_Unbounded_String (Read_Profile (Example));
         Profile_Cache_Key := To_Unbounded_String (Example);
      end if;
      return To_String (Profile_Cache_Value);
   end Example_Profile;

   function Read_Profile (Example : String) return String is
      use Ada.Text_IO;
      F    : File_Type;
      Key  : constant String := "ESP32S3_RTS_PROFILE=";
      Path : constant String := Compose (Full_Example_Dir (Example), "build.sh");
   begin
      if not Exists_File (Path) then
         return "light-tasking";
      end if;
      Open (F, In_File, Path);
      while not End_Of_File (F) loop
         declare
            L : constant String := Get_Line (F);
            K : constant Natural := Ada.Strings.Fixed.Index (L, Key);
         begin
            if K > 0 then
               declare
                  Last : Natural := K + Key'Length;
               begin
                  while Last <= L'Last
                    and then (L (Last) in 'a' .. 'z' or else L (Last) = '-')
                  loop
                     Last := Last + 1;
                  end loop;
                  Close (F);
                  return L (K + Key'Length .. Last - 1);
               end;
            end if;
         end;
      end loop;
      Close (F);
      return "light-tasking";
   exception
      when others =>
         if Is_Open (F) then
            Close (F);
         end if;
         return "light-tasking";
   end Read_Profile;

   procedure Set_Example (Example : String) is
   begin
      if Example /= To_String (The_Example) or else The_Suite /= Null_Unbounded_String then
         Forget_Environment;
      end if;
      The_Example := To_Unbounded_String (Example);
      if Example /= "" then
         The_Suite := Null_Unbounded_String;
      end if;
      if The_Kind = SDK_Example and then Example /= "" then
         The_Dir := To_Unbounded_String (Full_Example_Dir (Example));
      end if;
   end Set_Example;

   function Suite_Dirs return String_List is
   --  libs/<lib>/test/<suite> for every suite with a run.sh, sorted.
      Result : String_List;
      Sorted : Option_Maps.Map;
      L, T   : Search_Type;
      E, F   : Directory_Entry_Type;
   begin
      if The_Kind /= SDK_Example or else not Exists_Dir (Compose (Root, "libs")) then
         return Result;
      end if;
      Start_Search (L, Compose (Root, "libs"), "", [Directory => True, others => False]);
      while More_Entries (L) loop
         Get_Next_Entry (L, E);
         declare
            Test : constant String := Compose (Full_Name (E), "test");
         begin
            if Simple_Name (E) /= "." and then Simple_Name (E) /= ".." and then Exists_Dir (Test)
            then
               Start_Search (T, Test, "", [Directory => True, others => False]);
               while More_Entries (T) loop
                  Get_Next_Entry (T, F);
                  if Exists_File (Compose (Full_Name (F), "run.sh")) then
                     Sorted.Include (Simple_Name (F), Full_Name (F));
                  end if;
               end loop;
               End_Search (T);
            end if;
         end;
      end loop;
      End_Search (L);
      for C in Sorted.Iterate loop
         Result.Append (Option_Maps.Element (C));
      end loop;
      return Result;
   exception
      when others => return Result;
   end Suite_Dirs;

   function Host_Suites return String_List is
      Result : String_List;
   begin
      for D of Suite_Dirs loop
         Result.Append (Simple_Name (D));
      end loop;
      return Result;
   end Host_Suites;

   procedure Set_Suite (Suite : String) is
   begin
      for D of Suite_Dirs loop
         if Simple_Name (D) = Suite then
            if Suite /= To_String (The_Suite) then
               Forget_Environment;
            end if;
            The_Suite := To_Unbounded_String (Suite);
            The_Example := Null_Unbounded_String;
            The_Dir := To_Unbounded_String (D);
            return;
         end if;
      end loop;
   end Set_Suite;

   procedure Set_Port (Port : String) is
   begin
      The_Port := To_Unbounded_String (Ada.Strings.Fixed.Trim (Port, Ada.Strings.Both));
   end Set_Port;

   procedure Set_Console (Console : String) is
   begin
      The_Console := To_Unbounded_String (Ada.Strings.Fixed.Trim (Console, Ada.Strings.Both));
      if To_String (The_Console) = "jtag" then
         The_Console := Null_Unbounded_String;     --  the default, spelt out
      end if;
   end Set_Console;

   procedure Set_Profile (Profile : String) is
   begin
      Forget_Environment;
      The_Profile := To_Unbounded_String
        (if Profile = "auto" or else Profile = "default" then "" else Profile);
   end Set_Profile;

   --  Detection

   procedure Reset is
   begin
      The_Kind := No_Project;
      The_Root := Null_Unbounded_String;
      The_Dir := Null_Unbounded_String;
      The_Example := Null_Unbounded_String;
      The_Suite := Null_Unbounded_String;
      The_Port := Null_Unbounded_String;
      The_Console := Null_Unbounded_String;
      The_Profile := Null_Unbounded_String;
      Templates := [others => [others => Null_Unbounded_String]];
      Options.Clear;
      Desktop.Clear;
      Sources.Clear;
      Scanned := False;
      Forget_Environment;
   end Reset;

   function Suite_Of (Start, SDK : String) return String is
   --  The suite name when Start is in SDK/libs/<lib>/test/<suite>[/...].
      Libs : constant String := SDK & "/libs/";
   begin
      if Start'Length <= Libs'Length
        or else Start (Start'First .. Start'First + Libs'Length - 1) /= Libs
      then
         return "";
      end if;
      declare
         Rest  : constant String := Start (Start'First + Libs'Length .. Start'Last) & "/";
         S1    : constant Natural := Ada.Strings.Fixed.Index (Rest, "/");
         After : constant String := Rest (S1 + 1 .. Rest'Last);
      begin
         if After'Length > 5 and then After (After'First .. After'First + 4) = "test/" then
            declare
               Name_Part : constant String := After (After'First + 5 .. After'Last);
               S2        : constant Natural := Ada.Strings.Fixed.Index (Name_Part, "/");
               Name      : constant String := Name_Part (Name_Part'First .. S2 - 1);
            begin
               if Name /= ""
                 and then Exists_File (Libs & Rest (Rest'First .. S1 - 1) & "/test/" & Name
                                       & "/run.sh")
               then
                  return Name;
               end if;
            end;
         end if;
      end;
      return "";
   end Suite_Of;

   procedure Detect (Start_Dir : String) is
      Start      : constant String := Full_Name (Start_Dir);
      D          : Unbounded_String := To_Unbounded_String (Start);
      SDK        : Unbounded_String;
      Nearest    : Unbounded_String;      --  innermost standalone/crate
      Near_Kind  : Project_Kind := No_Project;
   begin
      Reset;
      loop
         declare
            Here : constant String := To_String (D);
         begin
            if Near_Kind = No_Project then
               if Exists_File (Compose (Here, "build.sh"))
                 and then Exists_File (Compose (Here, "app.gpr"))
               then
                  Nearest := D;
                  Near_Kind := Standalone;
               elsif Exists_File (Compose (Here, "alire.toml")) then
                  Nearest := D;
                  Near_Kind := Alire_Crate;
               end if;
            end if;
            if Is_SDK_Root (Here) then
               SDK := D;
               exit;
            end if;
            exit when Parent (Here) = Here;
            D := To_Unbounded_String (Parent (Here));
         end;
      end loop;

      if SDK /= Null_Unbounded_String then
         declare
            Ex_Root : constant String := Compose (To_String (SDK), "examples");
         begin
            --  Inside examples/<name>: that example.  Inside some other
            --  crate in the repository (this IDE, a tool): that crate.
            --  Anywhere else in the repository: the SDK, example to choose.
            if Suite_Of (Start, To_String (SDK)) /= "" then
               --  Inside libs/<lib>/test/<suite>: that host test suite.
               The_Kind := SDK_Example;
               The_Root := SDK;
               The_Dir := SDK;
               Set_Suite (Suite_Of (Start, To_String (SDK)));
            elsif Start'Length > Ex_Root'Length
              and then Start (Start'First .. Start'First + Ex_Root'Length - 1) = Ex_Root
            then
               declare
                  Rest  : constant String := Start (Start'First + Ex_Root'Length + 1 .. Start'Last);
                  Slash : constant Natural :=
                    Ada.Strings.Fixed.Index (Rest, Ada.Strings.Maps.To_Set ("/\"));
                  Ex    : constant String :=
                    (if Slash = 0 then Rest else Rest (Rest'First .. Slash - 1));
               begin
                  The_Kind := SDK_Example;
                  The_Root := SDK;
                  The_Dir := SDK;
                  if Exists_File (Compose (Compose (Ex_Root, Ex), "build.sh")) then
                     Set_Example
                       ((if Ex'Length > 8 and then Ex (Ex'First .. Ex'First + 7) = "esp32s3_"
                         then Ex (Ex'First + 8 .. Ex'Last) else Ex));
                  end if;
               end;
            elsif Near_Kind /= No_Project and then Nearest /= SDK then
               The_Kind := Near_Kind;
               The_Root := Nearest;
               The_Dir := Nearest;
            else
               The_Kind := SDK_Example;
               The_Root := SDK;
               The_Dir := SDK;
            end if;
         end;
      elsif Near_Kind /= No_Project then
         The_Kind := Near_Kind;
         The_Root := Nearest;
         The_Dir := Nearest;
      else
         The_Kind := No_Project;
         The_Root := To_Unbounded_String (Start);
         The_Dir := To_Unbounded_String (Start);
      end if;

      declare
         Keep_Example : constant String := Example;
         Keep_Suite   : constant String := Suite;
      begin
         Load_Options;
         --  Where we started wins over what was open last time.
         if Keep_Example /= "" then
            Set_Example (Keep_Example);
         elsif Keep_Suite /= "" then
            Set_Suite (Keep_Suite);
         end if;
      end;
   end Detect;

   procedure Open_Directory (Dir : String) is
   begin
      Detect (Dir);
   end Open_Directory;

   --  Commands

   function Esp32_Ada return String is
   begin
      if GNAT.OS_Lib.Locate_Exec_On_Path ("esp32-ada") /= null then
         return "esp32-ada";
      elsif Ada.Environment_Variables.Exists ("ESP32S3_ADA_SDK") then
         return Ada.Environment_Variables.Value ("ESP32S3_ADA_SDK")
           & "/tools/bin/esp32-ada";
      end if;
      return "esp32-ada";
   end Esp32_Ada;

   function Ports_Command return String is
     (case The_Kind is
         when SDK_Example => (if Target = Target_Native then "" else "./x ports --json"),
         when Standalone  => Esp32_Ada & " ports --json",
         when others      => "");

   function Has_Board return Boolean is
     (case The_Kind is
         when SDK_Example => Target = Target_Esp32s3 and then Example /= "",
         when Standalone  => True,
         when others      => False);

   function Debug_Server_Command return String is
     (if not Has_Board then ""
      else (if The_Kind = Standalone then Esp32_Ada else "./x") & " debug-server"
           & (if Port = "" then "" else " -p " & Port));

   function Debug_Info_Command return String is
     (if not Has_Board then ""
      elsif The_Kind = Standalone then Esp32_Ada & " debug-info"
      else "./x debug-info " & Example);

   function Debug_Tools_Command return String is
     (if not Has_Board then ""
      else (if The_Kind = Standalone then Esp32_Ada else "./x") & " get-debug-tools");

   function Setup_Command (Check_Only : Boolean := False) return String is
      Verb : constant String :=
        (if Check_Only then "setup-toolchain --check" else "--machine setup-toolchain");
   begin
      return
        (case The_Kind is
            when SDK_Example => "./x " & Verb,
            when Standalone  => Esp32_Ada & " " & Verb,
            when others      => "");
   end Setup_Command;

   function Label (A : Action) return String is
     (case A is
         when Act_Build        => "Build",
         when Act_Check        => "Check file",
         when Act_Env          => "Environment",
         when Act_Clean        => "Clean",
         when Act_Flash        => "Flash",
         when Act_Run          => "Run",
         when Act_Monitor      => "Monitor",
         when Act_Debug        => "Debug",
         when Act_Kill_OpenOCD => "Kill OpenOCD",
         when Act_Memory       => "Memory",
         when Act_Stack        => "Stack",
         when Act_Analyze      => "Analyze",
         when Act_Test         => "Test",
         when Act_Board        => "Board",
         when Act_Alr_Update   => "alr update",
         when Act_Alr_Show     => "alr show",
         when Act_Alr_Deps     => "alr with");

   Check_Template : constant String :=
     "gprbuild -c -u -f -q -P {gpr} {file} --relocate-build-tree={tmp} --root-dir={fsroot} -cargs -gnatc -gnatef";
   --  Errors only (-gnatc), full paths in them (-gnatef), and the objects in
   --  a scratch tree, so the real build's obj/ never sees a -gnatc unit.

   function Default_Template (A : Action) return String is
   begin
      if The_Kind = SDK_Example and then The_Suite /= Null_Unbounded_String then
         --  A host test suite: the native toolchain, through the suite's own
         --  run.sh (which builds, then runs it).
         return
           (case A is
               when Act_Build   => "./x --machine test host {suite}",
               when Act_Check   => Check_Template,
               when Act_Env     => "./x env {suite}",
               when Act_Run     => "bash {dir}/run.sh",
               when Act_Test    => "./x --machine test host",
               when Act_Analyze => "./x --machine analyze",
               when others      => "");
      end if;
      case The_Kind is
         when SDK_Example =>
            return
              (case A is
                  when Act_Build        => "./x --machine build {example}{profile_opt}",
                  when Act_Check        => Check_Template,
                  when Act_Env          => "./x env {example}{profile_opt}",
                  when Act_Clean        => "./x --machine clean {example}",
                  when Act_Flash        => "./x --machine flash {example}{port_opt}{profile_opt}",
                  when Act_Run          => "./x run {example}{port_opt}{console_opt}{profile_opt}",
                  when Act_Monitor      => "./x monitor{port_opt}{console_opt}",
                  when Act_Debug        => "./x debug {example}{port_opt}",
                  when Act_Kill_OpenOCD => "./x --machine kill-openocd",
                  when Act_Memory       => "./x --machine mem {example}",
                  when Act_Stack        => "./x --machine stack {example} --top 20",
                  when Act_Analyze      => "./x --machine analyze",
                  when Act_Test         => "./x --machine test host",
                  when Act_Board        => "./x --machine config {example}",
                  when Act_Alr_Update   => "alr -n update",
                  when Act_Alr_Show     => "alr -n show",
                  when Act_Alr_Deps     => "alr -n with");
         when Standalone =>
            declare
               E : constant String := Esp32_Ada;
            begin
               return
                 (case A is
                     when Act_Build        => E & " --machine build{profile_opt}",
                     when Act_Check        => Check_Template,
                     when Act_Env          => E & " env{profile_opt}",
                     when Act_Clean        => E & " --machine clean",
                     when Act_Flash        => E & " --machine flash{port_opt}{profile_opt}",
                     when Act_Run          => E & " run{port_opt}{console_opt}{profile_opt}",
                     when Act_Monitor      => E & " monitor{port_opt}{console_opt}",
                     when Act_Debug        => E & " debug{port_opt}",
                     when Act_Kill_OpenOCD => E & " --machine kill-openocd",
                     when Act_Board        => E & " --machine config",
                     when Act_Alr_Update   => "alr -n update",
                     when Act_Alr_Show     => "alr -n show",
                     when Act_Alr_Deps     => "alr -n with",
                     when others           => "");
            end;
         when Alire_Crate =>
            return
              (case A is
                  when Act_Build      => "alr -n build",
                  when Act_Check      => Check_Template,
                  when Act_Env        => "alr -n printenv --unix",
                  when Act_Clean      => "alr -n clean",
                  when Act_Run        => "alr -n run",
                  when Act_Test       => "alr -n test",
                  when Act_Alr_Update => "alr -n update",
                  when Act_Alr_Show   => "alr -n show",
                  when Act_Alr_Deps   => "alr -n with",
                  when others         => "");
         when No_Project =>
            return "";
      end case;
   end Default_Template;

   function Template (A : Action) return String is
     (if Templates (Target, A) = Null_Unbounded_String then Default_Template (A)
      else To_String (Templates (Target, A)));

   procedure Set_Template (A : Action; T : String) is
   begin
      if T = Default_Template (A) then
         Templates (Target, A) := Null_Unbounded_String;
      else
         Templates (Target, A) := To_Unbounded_String (T);
      end if;
   end Set_Template;

   function Replace_All (S, Key, By : String) return String is
      K : constant Natural := Ada.Strings.Fixed.Index (S, Key);
   begin
      if K = 0 then
         return S;
      end if;
      return S (S'First .. K - 1) & By
        & Replace_All (S (K + Key'Length .. S'Last), Key, By);
   end Replace_All;

   function Command_For (A : Action; File : String := "") return String is
      T : constant String := Template (A);
      R : Unbounded_String;

      procedure Sub (Key, By : String) is
      begin
         R := To_Unbounded_String (Replace_All (To_String (R), Key, By));
      end Sub;

      function FS_Root return String is
      --  The file-system root above the project: "/" or "C:".
         D : constant String := Dir;
      begin
         if D'Length >= 2 and then D (D'First + 1) = ':' then
            return D (D'First .. D'First + 1) & "";
         end if;
         return "/";
      end FS_Root;
   begin
      if T = "" then
         return "";
      end if;
      if The_Kind = SDK_Example and then Example = ""
        and then Ada.Strings.Fixed.Index (T, "{example}") > 0
      then
         return "";
      end if;
      if Ada.Strings.Fixed.Index (T, "{file}") > 0 and then File = "" then
         return "";
      end if;
      R := To_Unbounded_String (T);
      Sub ("{port_opt}", (if Port = "" then "" else " -p " & Port));
      Sub ("{console_opt}", (if Console = "" then "" else " -c " & Console));
      Sub ("{profile_opt}", (if Profile = "" then "" else " -P " & Profile));
      Sub ("{example}", Example);
      Sub ("{suite}", Suite);
      Sub ("{port}", Port);
      Sub ("{console}", Console);
      Sub ("{profile}", Profile);
      Sub ("{gpr}", Main_Gpr);
      Sub ("{tmp}", Scratch_Dir);
      Sub ("{fsroot}", FS_Root);
      Sub ("{dir}", Dir);
      Sub ("{root}", Root);
      Sub ("{file}", File);
      return To_String (R);
   end Command_For;

   function Working_Dir (A : Action) return String is
   begin
      if A in Act_Alr_Update | Act_Alr_Show | Act_Alr_Deps | Act_Check then
         return Dir;                 --  the example's own alire.toml / .gpr
      end if;
      return Root;
   end Working_Dir;

   --  The compile environment

   package Env_Maps is new Ada.Containers.Indefinite_Ordered_Maps (String, String);

   Env        : Env_Maps.Map;
   Env_Loaded : Boolean := False;

   type Saved_Var is record
      Existed : Boolean;
      Value   : Unbounded_String;
   end record;
   package Saved_Maps is new Ada.Containers.Indefinite_Ordered_Maps (String, Saved_Var);
   Saved : Saved_Maps.Map;

   procedure Set_Environment (Lines : String_List) is
   begin
      Env.Clear;
      for L of Lines loop
         declare
            T  : constant String := Ada.Strings.Fixed.Trim (L, Ada.Strings.Both);
            S  : constant String :=
              (if T'Length > 7 and then T (T'First .. T'First + 6) = "export "
               then T (T'First + 7 .. T'Last) else T);
            Eq : constant Natural := Ada.Strings.Fixed.Index (S, "=");
         begin
            if Eq > S'First
              and then (for all C of S (S'First .. Eq - 1) =>
                          C in 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '_')
            then
               declare
                  V : constant String := S (Eq + 1 .. S'Last);
               begin
                  Env.Include
                    (S (S'First .. Eq - 1),
                     (if V'Length >= 2 and then V (V'First) = '"' and then V (V'Last) = '"'
                      then V (V'First + 1 .. V'Last - 1) else V));
               end;
            end if;
         end;
      end loop;
      Env_Loaded := True;
   end Set_Environment;

   function Environment_Loaded return Boolean is (Env_Loaded);

   procedure Forget_Environment is
   begin
      Env.Clear;
      Env_Loaded := False;
   end Forget_Environment;

   function Env_Value (Key : String) return String is
     (if Env.Contains (Key) then Env.Element (Key) else "");

   procedure Push_Environment is
      use Ada.Environment_Variables;
   begin
      Saved.Clear;
      for C in Env.Iterate loop
         declare
            K : constant String := Env_Maps.Key (C);
         begin
            --  GPR_FILE and PROJECT_DIR describe the project; they are not
            --  variables any tool reads.
            if K /= "GPR_FILE" and then K /= "PROJECT_DIR" then
               Saved.Include
                 (K, (Ada.Environment_Variables.Exists (K),
                      To_Unbounded_String
                        (if Ada.Environment_Variables.Exists (K) then Value (K) else "")));
               Set (K, Env_Maps.Element (C));
            end if;
         end;
      end loop;
   end Push_Environment;

   procedure Pop_Environment is
      use Ada.Environment_Variables;
   begin
      for C in Saved.Iterate loop
         if Saved_Maps.Element (C).Existed then
            Set (Saved_Maps.Key (C), To_String (Saved_Maps.Element (C).Value));
         else
            Clear (Saved_Maps.Key (C));
         end if;
      end loop;
      Saved.Clear;
   end Pop_Environment;

   function Main_Gpr return String is
     (if Env_Value ("GPR_FILE") /= "" then Env_Value ("GPR_FILE") else Gpr_File);

   function Scratch_Dir return String is
      Base : constant String :=
        (if Ada.Environment_Variables.Exists ("TMPDIR")
         then Ada.Environment_Variables.Value ("TMPDIR")
         elsif Ada.Environment_Variables.Exists ("TEMP")
         then Ada.Environment_Variables.Value ("TEMP")
         else "/tmp");
   begin
      return Compose (Base, "turbo_ada_check");
   end Scratch_Dir;

   function Is_Interactive (A : Action) return Boolean is
     (A in Act_Run | Act_Monitor | Act_Debug);

   function Shell_Program return String is
   begin
      if Term.Is_Windows then
         declare
            Bash : GNAT.OS_Lib.String_Access :=
              GNAT.OS_Lib.Locate_Exec_On_Path ("bash");
         begin
            if Bash /= null then
               GNAT.OS_Lib.Free (Bash);
               return "bash";
            end if;
            return "cmd.exe";
         end;
      end if;
      return "/bin/sh";
   end Shell_Program;

   function Shell_Flag return String is
     (if Shell_Program = "cmd.exe" then "/c" else "-c");

   --  Source lookup

   procedure Scan (D : String; Depth : Natural) is
      S : Search_Type;
      E : Directory_Entry_Type;
   begin
      if Depth > 12 then
         return;
      end if;
      Start_Search (S, D, "");
      while More_Entries (S) loop
         Get_Next_Entry (S, E);
         declare
            N : constant String := Simple_Name (E);
         begin
            if N = "." or else N = ".." then
               null;
            elsif Kind (E) = Directory then
               if N (N'First) /= '.' and then N /= "obj" and then N /= "alire"
                 and then N /= "build" and then N /= "node_modules"
                 and then N /= "book" and then N /= "docs"
               then
                  Scan (Full_Name (E), Depth + 1);
               end if;
            elsif Kind (E) = Ordinary_File then
               declare
                  Ext : constant String :=
                    Ada.Characters.Handling.To_Lower (Extension (N));
               begin
                  if Ext = "adb" or else Ext = "ads" or else Ext = "gpr"
                    or else Ext = "c" or else Ext = "h" or else Ext = "s"
                    or else Ext = "ld" or else Ext = "toml"
                  then
                     --  The first one found wins; the project directory is
                     --  scanned first, so its files beat same-named ones
                     --  elsewhere in the SDK.
                     if not Sources.Contains (N) then
                        Sources.Insert (N, Full_Name (E));
                     end if;
                  end if;
               end;
            end if;
         end;
      end loop;
      End_Search (S);
   exception
      when others =>
         null;
   end Scan;

   function Locate_Source (File : String) return String is
      Simple : constant String :=
        (declare
            Slash : constant Natural :=
              Natural'Max (Ada.Strings.Fixed.Index (File, "/", Ada.Strings.Backward),
                           Ada.Strings.Fixed.Index (File, "\", Ada.Strings.Backward));
         begin
            File (Slash + 1 .. File'Last));
   begin
      if File'Length = 0 then
         return "";
      end if;
      if Exists_File (File) then
         return Full_Name (File);
      end if;
      if Exists_File (Compose (Dir, File)) then
         return Full_Name (Compose (Dir, File));
      elsif Exists_File (Compose (Root, File)) then
         return Full_Name (Compose (Root, File));
      elsif Exists_File (Compose (Compose (Dir, "src"), File)) then
         return Full_Name (Compose (Compose (Dir, "src"), File));
      end if;
      if not Scanned then
         Scan (Dir, 0);
         if Root /= Dir then
            Scan (Compose (Root, "libs"), 0);
            Scan (Compose (Root, "crates"), 0);
            Scan (Compose (Root, "examples"), 0);
         end if;
         Scanned := True;
      end if;
      if Sources.Contains (Simple) then
         return Sources.Element (Simple);
      end if;
      return "";
   exception
      when others => return "";
   end Locate_Source;

   function Manifest return String is
     (if Exists_File (Compose (Dir, "alire.toml")) then Compose (Dir, "alire.toml")
      else "");

   function Main_Source return String is
      Src : constant String := Compose (Dir, "src");
   begin
      if Suite /= "" then
         --  The first name in the suite's "for Main use (...)".
         declare
            use Ada.Text_IO;
            F    : File_Type;
            Gpr  : constant String := Gpr_File;
         begin
            if Gpr /= "" then
               Open (F, In_File, Gpr);
               while not End_Of_File (F) loop
                  declare
                     L : constant String := Get_Line (F);
                     M : constant Natural := Ada.Strings.Fixed.Index (L, "for Main use");
                     Q : constant Natural :=
                       (if M = 0 then 0 else Ada.Strings.Fixed.Index (L (M .. L'Last), """"));
                     Q2 : constant Natural :=
                       (if Q = 0 then 0 else Ada.Strings.Fixed.Index (L (Q + 1 .. L'Last), """"));
                  begin
                     if Q2 > Q + 1 and then Exists_File (Compose (Dir, L (Q + 1 .. Q2 - 1))) then
                        Close (F);
                        return Compose (Dir, L (Q + 1 .. Q2 - 1));
                     end if;
                  end;
               end loop;
               Close (F);
            end if;
         exception
            when others =>
               if Is_Open (F) then
                  Close (F);
               end if;
         end;
      end if;
      if Exists_File (Compose (Src, "main.adb")) then
         return Compose (Src, "main.adb");
      elsif Exists_File (Compose (Src, Simple_Name (Dir) & ".adb")) then
         return Compose (Src, Simple_Name (Dir) & ".adb");
      end if;
      return "";
   exception
      when others => return "";
   end Main_Source;

   function Gpr_File return String is
      S : Search_Type;
      E : Directory_Entry_Type;
   begin
      if Exists_File (Compose (Dir, "app.gpr")) then
         return Compose (Dir, "app.gpr");
      end if;
      Start_Search (S, Dir, "*.gpr", [Ordinary_File => True, others => False]);
      if More_Entries (S) then
         Get_Next_Entry (S, E);
         End_Search (S);
         return Full_Name (E);
      end if;
      End_Search (S);
      return "";
   exception
      when others => return "";
   end Gpr_File;

   --  Options file

   function Options_File return String is
     (Compose (Root, ".turbo_ada"));

   procedure Load_Options is
      use Ada.Text_IO;
      F : File_Type;
   begin
      Options.Clear;
      Desktop.Clear;
      if Root = "" or else not Exists_File (Options_File) then
         return;
      end if;
      Open (F, In_File, Options_File);
      while not End_Of_File (F) loop
         declare
            L  : constant String := Get_Line (F);
            Eq : constant Natural := Ada.Strings.Fixed.Index (L, "=");
         begin
            if L'Length > 0 and then L (L'First) /= '#' and then Eq > 0 then
               declare
                  K : constant String := L (L'First .. Eq - 1);
                  V : constant String := L (Eq + 1 .. L'Last);
               begin
                  if K = "example" then
                     Set_Example (V);
                  elsif K = "suite" then
                     Set_Suite (V);
                  elsif K = "port" then
                     Set_Port (V);
                  elsif K = "console" then
                     Set_Console (V);
                  elsif K = "profile" then
                     Set_Profile (V);
                  elsif K = "desktop" then
                     Desktop.Append (V);
                  elsif K'Length > 4 and then K (K'First .. K'First + 3) = "cmd." then
                     declare
                        Native : constant Boolean :=
                          K'Length > 11 and then K (K'First .. K'First + 10) = "cmd.native.";
                        Name   : constant String :=
                          (if Native then K (K'First + 11 .. K'Last) else K (K'First + 4 .. K'Last));
                     begin
                        for A in Action loop
                           if Ada.Characters.Handling.To_Lower (Action'Image (A)) = "act_" & Name then
                              Templates ((if Native then Target_Native else Target_Esp32s3), A) :=
                                To_Unbounded_String (V);
                           end if;
                        end loop;
                     end;
                  else
                     Options.Include (K, V);
                  end if;
               end;
            end if;
         end;
      end loop;
      Close (F);
   exception
      when others =>
         if Is_Open (F) then
            Close (F);
         end if;
   end Load_Options;

   procedure Save_Options (Open_Files : String_List) is
      use Ada.Text_IO;
      F : File_Type;
   begin
      if Root = "" then
         return;
      end if;
      Create (F, Out_File, Options_File);
      Put_Line (F, "# Turbo Ada options and desktop (safe to delete)");
      if Example /= "" then
         Put_Line (F, "example=" & Example);
      end if;
      if Suite /= "" then
         Put_Line (F, "suite=" & Suite);
      end if;
      if Port /= "" then
         Put_Line (F, "port=" & Port);
      end if;
      if Console /= "" then
         Put_Line (F, "console=" & Console);
      end if;
      if Profile /= "" then
         Put_Line (F, "profile=" & Profile);
      end if;
      for T in Target_Kind loop
         for A in Action loop
            if Templates (T, A) /= Null_Unbounded_String then
               declare
                  Img : constant String :=
                    Ada.Characters.Handling.To_Lower (Action'Image (A));
               begin
                  Put_Line (F, "cmd." & (if T = Target_Native then "native." else "")
                            & Img (Img'First + 4 .. Img'Last) & "="
                            & To_String (Templates (T, A)));
               end;
            end if;
         end loop;
      end loop;
      for C in Options.Iterate loop
         Put_Line (F, Option_Maps.Key (C) & "=" & Option_Maps.Element (C));
      end loop;
      for P of Open_Files loop
         Put_Line (F, "desktop=" & P);
      end loop;
      Close (F);
      Desktop := Open_Files;
   exception
      when others =>
         if Is_Open (F) then
            Close (F);
         end if;
   end Save_Options;

   function Saved_Desktop return String_List is (Desktop);

   function Get_Option (Key : String; Default : String := "") return String is
     (if Options.Contains (Key) then Options.Element (Key) else Default);

   procedure Set_Option (Key, Value : String) is
   begin
      Options.Include (Key, Value);
   end Set_Option;

end Turbo.Projects;
