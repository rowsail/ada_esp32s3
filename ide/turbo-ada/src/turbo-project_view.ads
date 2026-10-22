--  The Project window: the project as a tree, in two views (Tab switches).
--
--    Folders   the project directory, folders first; a folder opens and
--              closes with Enter (or Right / Left), read when first opened
--    Sources   the Ada (and C) sources the project builds from, grouped by
--              project: the root project's own and each one it withs (the
--              SDK libraries, Alire dependencies).  Once the program is
--              built these are its closure, the files it really needs;
--              before that, every source in the projects' source dirs.
--
--  Enter on a file opens it (through the Open handler); a click selects, a
--  click on the selected line acts as Enter.  The Sources view is filled
--  by the application (Set_Sources), which runs the GPR tools for it: the
--  window asks with Take_Sources_Request, the first time and on Ctrl-R.

with Ada.Containers.Indefinite_Vectors;
with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Turbo.Events;
with Turbo.Windows;

package Turbo.Project_View is

   type Open_Handler is access procedure (Path : String);

   type View_Kind is (Folders, Sources);

   type Project_Window is new Turbo.Windows.Window with private;
   type Project_Window_Access is access all Project_Window'Class;

   function Create return Project_Window_Access;

   overriding function Title (W : Project_Window) return Wide_Wide_String;
   overriding procedure Draw (W : in out Project_Window; Active : Boolean);
   overriding procedure Handle_Event
     (W : in out Project_Window; E : Turbo.Events.Event; Handled : out Boolean);
   overriding function Min_Width (W : Project_Window) return Positive is (20);

   procedure Set_Open_Handler (W : in out Project_Window; H : Open_Handler);

   procedure Set_Root (W : in out Project_Window; Dir : String);
   --  The Folders view's top (the project directory); the Sources view is
   --  emptied, to be asked for again.

   function View (W : Project_Window) return View_Kind;
   procedure Set_View (W : in out Project_Window; V : View_Kind);

   --  The Sources view

   package Path_Vectors is new Ada.Containers.Indefinite_Vectors (Positive, String);

   type Source_Group is record
      Name  : Ada.Strings.Unbounded.Unbounded_String;   --  the project's
      Dir   : Ada.Strings.Unbounded.Unbounded_String;   --  its directory
      Files : Path_Vectors.Vector;                      --  full paths
   end record;

   package Group_Vectors is new Ada.Containers.Vectors (Positive, Source_Group);

   procedure Set_Sources
     (W : in out Project_Window; Groups : Group_Vectors.Vector; Note : String);
   --  Note heads the view: where the list came from, or why it is empty.

   function Take_Sources_Request (W : in out Project_Window) return Boolean;
   --  True once when the Sources view needs (re)filling.

   procedure Refresh (W : in out Project_Window);
   --  Ctrl-R: re-read the open folders; ask for the sources again.

private

   type Node_Kind is (Note, Folder, File, Group);

   type Node is record
      Kind     : Node_Kind := Note;
      Text     : Ada.Strings.Unbounded.Unbounded_String;   --  as shown
      Path     : Ada.Strings.Unbounded.Unbounded_String;   --  a folder's or file's
      Depth    : Natural := 0;
      Expanded : Boolean := False;
   end record;

   package Node_Vectors is new Ada.Containers.Vectors (Positive, Node);

   type View_State is record
      Nodes : Node_Vectors.Vector;
      Sel   : Natural := 0;
      Top   : Positive := 1;
   end record;

   type View_States is array (View_Kind) of View_State;

   type Project_Window is new Turbo.Windows.Window with record
      Views        : View_States;
      Current      : View_Kind := Folders;
      Root         : Ada.Strings.Unbounded.Unbounded_String;
      Open         : Open_Handler;
      Want_Sources : Boolean := False;
      Have_Sources : Boolean := False;
      Groups       : Group_Vectors.Vector;   --  for re-expanding
   end record;

end Turbo.Project_View;
