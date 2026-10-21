--  A Language Server Protocol client, for the Ada Language Server.
--
--  The server is a child process talking JSON-RPC over its stdin/stdout.  A
--  reader task turns its output into whole messages; the main loop calls
--  Poll to take them in.  Notifications (diagnostics, progress) update the
--  state below; requests the IDE makes are synchronous with a timeout and a
--  cancel hook, because each one answers a key the user just pressed.
--
--  Positions are as LSP has them: 0-based lines, and characters counted in
--  UTF-16 code units (To_Char / To_Col convert from and to the editor's
--  1-based code-point columns).

with Ada.Containers.Indefinite_Ordered_Maps;
with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Turbo.JSON;

package Turbo.LSP is

   type Server_State is (Off, Running, Failed);

   function State return Server_State;
   function Is_Running return Boolean is (State = Running);

   function Status_Text return String;
   --  A few words for the status line: "ALS", "ALS 59%", "ALS failed".

   function Last_Error return String;

   function Find_Server (Configured : String) return String;
   --  The server executable: Configured if set, else ada_language_server
   --  on PATH, in ~/.alire/bin, or inside an installed VS Code Ada
   --  extension.  "" when there is none.

   procedure Start
     (Executable   : String;
      Project_File : String;
      Root_Dir     : String;
      Ok           : out Boolean);
   --  Spawn and initialize the server (the caller sets up the environment
   --  the project needs first: PATH, GPR_PROJECT_PATH, ...).

   procedure Stop;
   --  Polite shutdown, then make sure the process is gone.

   procedure Poll;
   --  Take in what the server sent: diagnostics, progress, its requests.

   --  Documents (Text is UTF-8)

   function Is_Open (Path : String) return Boolean;
   procedure Open_Document (Path : String; Version : Natural; Text : String);
   procedure Change_Document (Path : String; Version : Natural; Text : String);
   procedure Save_Document (Path : String);
   procedure Close_Document (Path : String);
   function Sent_Version (Path : String) return Integer;
   --  The version last sent for Path; -1 if it is not open.

   --  Diagnostics

   type Diagnostic is record
      Line, Char         : Natural := 0;     --  start
      End_Line, End_Char : Natural := 0;
      Severity           : Positive := 1;    --  1 error .. 4 hint
      Message            : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   package Diagnostic_Vectors is new Ada.Containers.Vectors (Positive, Diagnostic);

   function Diagnostics_For (Path : String) return Diagnostic_Vectors.Vector;

   package Path_Maps is new Ada.Containers.Indefinite_Ordered_Maps
     (String, Diagnostic_Vectors.Vector, "<", Diagnostic_Vectors."=");

   function All_Diagnostics return Path_Maps.Map;

   function Diagnostics_Changed return Boolean;
   --  True once after any publishDiagnostics arrived.

   --  Requests

   type Cancel_Func is access function return Boolean;

   type Response is tagged limited record
      Doc    : Turbo.JSON.Document;
      Result : Turbo.JSON.Value := Turbo.JSON.No_Value;
      Ok     : Boolean := False;
      Error  : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   procedure Request
     (Method  : String;
      Params  : String;
      R       : in out Response;
      Cancel  : Cancel_Func := null;
      Timeout : Duration := 15.0);
   --  Params is JSON text.  R.Ok is False on an error reply, a timeout, or
   --  when Cancel returned True (the request is then cancelled server-side).

   --  Helpers

   function URI (Path : String) return String;
   function Path_Of (URI : String) return String;

   function Text_Document (Path : String) return String;
   --  {"uri": ...}

   function Position_Params (Path : String; Line, Char : Natural) return String;
   --  {"textDocument": {...}, "position": {...}}

   function To_Char (Line : Wide_Wide_String; Col : Positive) return Natural;
   --  The UTF-16 offset of 1-based code-point column Col.

   function To_Col (Line : Wide_Wide_String; Char : Natural) return Positive;

end Turbo.LSP;
