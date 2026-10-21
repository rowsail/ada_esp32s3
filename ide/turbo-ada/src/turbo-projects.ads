--  What "the project" is, and the commands that drive it.
--
--  Turbo Ada adds no build logic of its own.  It recognises three kinds of
--  project and runs the tool that already knows how to build each:
--
--    SDK example  inside the ada_esp32s3 repository: ./x <verb> <example>
--                 (ESP32-S3), or one of its libraries' host test suites,
--                 libs/<lib>/test/<suite> (native: built for this machine)
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
     (Act_Build, Act_Check, Act_Clean, Act_Flash, Act_Run, Act_Monitor,
      Act_Debug, Act_Kill_OpenOCD, Act_Memory, Act_Stack, Act_Analyze,
      Act_Test, Act_Board, Act_Alr_Update, Act_Alr_Show, Act_Alr_Deps,
      Act_Env);
   --  Act_Check compiles one file for errors only (gprbuild -gnatc into a
   --  scratch tree); Act_Env prints the environment such a compile, and the
   --  language server, need (./x env, esp32-ada env, alr printenv).

   subtype String_List is Turbo.Dialogs.String_List;

   type Target_Kind is (Target_Esp32s3, Target_Native);

   function Target return Target_Kind;
   --  What the project builds for: an SDK example or esp32-ada project for
   --  the ESP32-S3; a host test suite or an ordinary Alire crate for this
   --  machine.  It follows from the project; there is nothing to set.

   function Target_Image return String;   --  "ESP32-S3" / "native"

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

   --  SDK host test suites (native)

   function Host_Suites return String_List;  --  suite names, sorted
   function Suite return String;              --  "" when an example is open
   procedure Set_Suite (Suite : String);

   --  Target options

   function Port return String;              --  "" = found by USB id
   procedure Set_Port (Port : String);
   --  The chip's USB-Serial/JTAG port: flash, debug, the default console.

   function Console return String;           --  "" = the USB/JTAG port
   procedure Set_Console (Console : String);
   --  Where Run and Monitor read the console: "", "jtag", "uart" (the
   --  board's USB-UART bridge, found by USB id) or a device.

   function Ports_Command return String;
   --  The board ports as the SDK sees them (./x ports --json), or "" for a
   --  project that has no board.
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

   function Debug_Server_Command return String;
   function Debug_Info_Command return String;
   function Debug_Tools_Command return String;
   function Can_Debug return Boolean;
   --  For the IDE's own debugger: OpenOCD alone, pinned to the board
   --  (./x debug-server), the GDB, ELF and Ada main to use (./x debug-info),
   --  and fetching OpenOCD + GDB (./x get-debug-tools).  "" for a project
   --  with no board.  Can_Debug: a board project, or a native one (the
   --  system's gdb on Native_Executable).

   function Native_Executable return String;
   --  A native project's program, as its build left it: the first "for Main
   --  use" unit of the project file (else the main source), looked for in
   --  bin/, the project directory and obj/.  "" when there is none yet.

   function Setup_Command (Check_Only : Boolean := False) return String;
   --  The SDK's one-time toolchain set-up (./x setup-toolchain, or
   --  esp32-ada's): the validated compilers and gprbuild, through alr, and
   --  the xtensa-dynconfig plugin.  Check_Only: report, exit 1 when it is
   --  not ready.  "" for a project that is not built by the SDK.

   function Clipboard_Setup_Command (Check_Only : Boolean := False) return String;
   --  Installs the helper the system clipboard needs here (./x
   --  setup-clipboard, or esp32-ada's), with sudo.  "" outside the SDK.

   --  The project's compile environment (from Act_Env)

   procedure Set_Environment (Lines : String_List);
   --  "KEY=VALUE" or "export KEY="VALUE"" lines.

   function Environment_Loaded return Boolean;
   procedure Forget_Environment;
   function Env_Value (Key : String) return String;

   procedure Push_Environment;
   procedure Pop_Environment;
   --  Around a spawn that needs the environment (the language server, a
   --  file check): set it in this process, then put everything back.  The
   --  build commands do not get it: they set up their own.

   function Main_Gpr return String;
   --  The project file to check and index: GPR_FILE from the environment,
   --  else Gpr_File.

   function Scratch_Dir return String;
   --  Where Act_Check's object tree goes (never the real obj/).

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
