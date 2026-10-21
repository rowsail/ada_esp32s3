--  A read-only text window in the help colours: the help screens, the
--  clipboard, project information.
--
--  Markup, one level deep: a line starting "# " is a heading; text between
--  braces {like this} is a highlighted key or keyword.

with Ada.Containers.Indefinite_Vectors;
with Ada.Strings.Unbounded;
with Turbo.Events;
with Turbo.Windows;

package Turbo.Viewers is

   type Viewer is new Turbo.Windows.Window with private;
   type Viewer_Access is access all Viewer'Class;

   function Create (Title : String; Text : String) return Viewer_Access;
   --  Text is UTF-8, lines separated by LF.

   procedure Set_Text (V : in out Viewer; Text : String);

   overriding function Title (V : Viewer) return Wide_Wide_String;
   overriding procedure Draw (V : in out Viewer; Active : Boolean);
   overriding procedure Handle_Event
     (V : in out Viewer; E : Turbo.Events.Event; Handled : out Boolean);

private

   package Line_Vectors is new Ada.Containers.Indefinite_Vectors
     (Positive, Wide_Wide_String);

   type Viewer is new Turbo.Windows.Window with record
      Name  : Ada.Strings.Unbounded.Unbounded_String;
      Lines : Line_Vectors.Vector;
      Top   : Positive := 1;
      Left  : Natural := 0;
   end record;

end Turbo.Viewers;
