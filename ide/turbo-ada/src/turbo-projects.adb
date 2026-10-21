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
   The_Port    : Unbounded_String;
   The_Profile : Unbounded_String;
   Templates   : array (Action) of Unbounded_String;  --  "" = default
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
   function Port return String is (To_String (The_Port));
   function Profile return String is (To_String (The_Profile));

   function Kind_Image return String is
     (case The_Kind is
         when No_Project  => "no project",
         when SDK_Example => "ESP32-S3 SDK example",
         when Standalone  => "esp32-ada project",
         when Alire_Crate => "Alire crate");

   function Name return String is
   begin
      case The_Kind is
         when No_Project  => return "";
         when SDK_Example =>
            return (if Example = "" then "(no example chosen)" else Example);
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
      The_Example := To_Unbounded_String (Example);
      if The_Kind = SDK_Example and then Example /= "" then
         The_Dir := To_Unbounded_String (Full_Example_Dir (Example));
      end if;
   end Set_Example;

   procedure Set_Port (Port : String) is
   begin
      The_Port := To_Unbounded_String (Ada.Strings.Fixed.Trim (Port, Ada.Strings.Both));
   end Set_Port;

   procedure Set_Profile (Profile : String) is
   begin
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
      The_Port := Null_Unbounded_String;
      The_Profile := Null_Unbounded_String;
      Templates := [others => Null_Unbounded_String];
      Options.Clear;
      Desktop.Clear;
      Sources.Clear;
      Scanned := False;
   end Reset;

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
            if Start'Length > Ex_Root'Length
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
      begin
         Load_Options;
         if Keep_Example /= "" then
            Set_Example (Keep_Example);     --  where we started wins
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

   function Label (A : Action) return String is
     (case A is
         when Act_Build        => "Build",
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

   function Default_Template (A : Action) return String is
   begin
      case The_Kind is
         when SDK_Example =>
            return
              (case A is
                  when Act_Build        => "./x build {example}{profile_opt}",
                  when Act_Clean        => "./x clean {example}",
                  when Act_Flash        => "./x flash {example}{port_opt}",
                  when Act_Run          => "./x run {example}{port_opt}{profile_opt}",
                  when Act_Monitor      => "./x monitor{port_opt}",
                  when Act_Debug        => "./x debug {example}{port_opt}",
                  when Act_Kill_OpenOCD => "./x kill-openocd",
                  when Act_Memory       => "./x mem {example}",
                  when Act_Stack        => "./x stack {example} --top 20",
                  when Act_Analyze      => "./x analyze",
                  when Act_Test         => "./x test host",
                  when Act_Board        => "./x config {example}",
                  when Act_Alr_Update   => "alr -n update",
                  when Act_Alr_Show     => "alr -n show",
                  when Act_Alr_Deps     => "alr -n with");
         when Standalone =>
            declare
               E : constant String := Esp32_Ada;
            begin
               return
                 (case A is
                     when Act_Build        => E & " build{profile_opt}",
                     when Act_Clean        => E & " clean",
                     when Act_Flash        => E & " flash{port_opt}",
                     when Act_Run          => E & " run{port_opt}{profile_opt}",
                     when Act_Monitor      => E & " monitor{port_opt}",
                     when Act_Debug        => E & " debug{port_opt}",
                     when Act_Kill_OpenOCD => E & " kill-openocd",
                     when Act_Board        => E & " config",
                     when Act_Alr_Update   => "alr -n update",
                     when Act_Alr_Show     => "alr -n show",
                     when Act_Alr_Deps     => "alr -n with",
                     when others           => "");
            end;
         when Alire_Crate =>
            return
              (case A is
                  when Act_Build      => "alr -n build",
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
     (if Templates (A) = Null_Unbounded_String then Default_Template (A)
      else To_String (Templates (A)));

   procedure Set_Template (A : Action; T : String) is
   begin
      if T = Default_Template (A) then
         Templates (A) := Null_Unbounded_String;
      else
         Templates (A) := To_Unbounded_String (T);
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
   begin
      if T = "" then
         return "";
      end if;
      if The_Kind = SDK_Example and then Example = ""
        and then Ada.Strings.Fixed.Index (T, "{example}") > 0
      then
         return "";
      end if;
      return
        Replace_All
          (Replace_All
             (Replace_All
                (Replace_All
                   (Replace_All
                      (Replace_All
                         (Replace_All
                            (Replace_All (T, "{port_opt}",
                                          (if Port = "" then "" else " -p " & Port)),
                             "{profile_opt}",
                             (if Profile = "" then "" else " -P " & Profile)),
                          "{example}", Example),
                       "{port}", Port),
                    "{profile}", Profile),
                 "{dir}", Dir),
              "{root}", Root),
           "{file}", File);
   end Command_For;

   function Working_Dir (A : Action) return String is
   begin
      if A in Act_Alr_Update | Act_Alr_Show | Act_Alr_Deps then
         return Dir;                 --  the example's own alire.toml
      end if;
      return Root;
   end Working_Dir;

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
                  elsif K = "port" then
                     Set_Port (V);
                  elsif K = "profile" then
                     Set_Profile (V);
                  elsif K = "desktop" then
                     Desktop.Append (V);
                  elsif K'Length > 4 and then K (K'First .. K'First + 3) = "cmd." then
                     for A in Action loop
                        if Ada.Characters.Handling.To_Lower (Action'Image (A))
                          = "act_" & K (K'First + 4 .. K'Last)
                        then
                           Templates (A) := To_Unbounded_String (V);
                        end if;
                     end loop;
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
      if Port /= "" then
         Put_Line (F, "port=" & Port);
      end if;
      if Profile /= "" then
         Put_Line (F, "profile=" & Profile);
      end if;
      for A in Action loop
         if Templates (A) /= Null_Unbounded_String then
            declare
               Img : constant String :=
                 Ada.Characters.Handling.To_Lower (Action'Image (A));
            begin
               Put_Line (F, "cmd." & Img (Img'First + 4 .. Img'Last) & "="
                         & To_String (Templates (A)));
            end;
         end if;
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
