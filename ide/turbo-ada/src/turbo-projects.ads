--  What "the project" is, and the commands that drive it.
--
--  Turbo Ada adds no build logic of its own.  It recognises three kinds of
--  project and runs the tool that already knows how to build each:
--
--    SDK example  inside the ada_esp32s3 repository: ./x <verb> <example>
--    Standalone   an esp32-ada project (build.sh + app.gpr): esp32-ada <verb>
--    Alire crate  any other alire.toml: alr build / alr run / ...
--
--  Every command is a template the Options | Commands dialog can change,
--  stored with the rest of the options in .turbo_ada in the project (or SDK)
--  directory, along with the files that were open (the "desktop").

with Turbo.Dialogs;

package Turbo.Projects is

   type Project_Kind is (No_Project, SDK_Example, Standalone, Alire_Crate);

   type Action is
     (Act_Build, Act_Clean, Act_Flash, Act_Run, Act_Monitor, Act_Debug,
      Act_Kill_OpenOCD, Act_Memory, Act_Stack, Act_Analyze, Act_Test,
      Act_Board, Act_Alr_Update, Act_Alr_Show, Act_Alr_Deps);

   subtype String_List is Turbo.Dialogs.String_List;

   procedure Detect (Start_Dir : String);
   --  Work out the project from a directory (normally the current one).

   procedure Open_Directory (Dir : String);
   --  Project | Open project on a directory.

   function Kind return Project_Kind;
   function Kind_Image return String;
   function Root return String;      --  the SDK root, or the project dir
   function Dir return String;       --  the project directory itself
   function Name return String;

   --  SDK examples

   function Examples return String_List;     --  short names, sorted
   function Example_Profile (Example : String) return String;
   function Example return String;
   procedure Set_Example (Example : String);

   --  Target options

   function Port return String;              --  "" = the tool's default
   procedure Set_Port (Port : String);
   function Profile return String;           --  "" = the project's own
   procedure Set_Profile (Profile : String);

   --  Commands

   function Label (A : Action) return String;
   function Template (A : Action) return String;
   function Default_Template (A : Action) return String;
   procedure Set_Template (A : Action; T : String);

   function Command_For (A : Action; File : String := "") return String;
   --  The template expanded, or "" when this kind of project has no such
   --  command.

   function Working_Dir (A : Action) return String;

   function Is_Interactive (A : Action) return Boolean;
   --  Run, Monitor and Debug own the terminal; the rest are captured into
   --  the message window.

   function Esp32_Ada return String;
   --  How to run esp32-ada: from PATH, else from $ESP32S3_ADA_SDK.

   --  Shell

   function Shell_Program return String;
   function Shell_Flag return String;

   --  Files

   function Locate_Source (File : String) return String;
   --  A file named in a tool message, found in the project tree; "" if not.

   function Manifest return String;          --  alire.toml, or ""
   function Main_Source return String;
   --  The file to open in a fresh session: src/main.adb, or the crate's
   --  src/<name>.adb, or "".
   function Gpr_File return String;          --  the main .gpr, or ""

   --  Options file

   procedure Load_Options;
   procedure Save_Options (Open_Files : String_List);
   function Saved_Desktop return String_List;
   --  "path:line:col" for each file open when the options were saved.

   function Options_File return String;

   function Get_Option (Key : String; Default : String := "") return String;
   procedure Set_Option (Key, Value : String);
   --  Free-form keys (editor settings and the like) kept in the same file.

end Turbo.Projects;
