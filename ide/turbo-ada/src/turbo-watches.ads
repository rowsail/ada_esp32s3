--  The Watch window (Turbo C++'s Window | Watch): expressions the debugger
--  evaluates each time the program stops, one per line as "Expr: value".
--
--  Ins adds a watch, Enter edits the selected one, Del deletes it -- asked of
--  the application through Take_Request, as the editor's key sequences are.

with Ada.Containers.Indefinite_Vectors;
with Turbo.Commands;
with Turbo.Events;
with Turbo.Windows;

package Turbo.Watches is

   type Watch_Window is new Turbo.Windows.Window with private;
   type Watch_Window_Access is access all Watch_Window'Class;

   function Create return Watch_Window_Access;

   overriding function Title (W : Watch_Window) return Wide_Wide_String;
   overriding procedure Draw (W : in out Watch_Window; Active : Boolean);
   overriding procedure Handle_Event
     (W : in out Watch_Window; E : Turbo.Events.Event; Handled : out Boolean);

   function Count (W : Watch_Window) return Natural;
   function Expression (W : Watch_Window; K : Positive) return String;
   function Selected (W : Watch_Window) return Natural;   --  0: none

   procedure Add (W : in out Watch_Window; Expression : String);
   procedure Replace (W : in out Watch_Window; K : Positive; Expression : String);
   procedure Delete (W : in out Watch_Window; K : Positive);
   procedure Delete_All (W : in out Watch_Window);

   procedure Set_Value (W : in out Watch_Window; K : Positive; Value : String);
   --  UTF-8, one line (a multi-line value is shown joined).

   function Take_Request (W : in out Watch_Window) return Turbo.Commands.Command;

private

   package String_Vectors is new Ada.Containers.Indefinite_Vectors (Positive, String);

   type Watch_Window is new Turbo.Windows.Window with record
      Exprs   : String_Vectors.Vector;
      Values  : String_Vectors.Vector;
      Sel     : Natural := 0;
      Top     : Positive := 1;
      Left    : Natural := 0;
      Request : Turbo.Commands.Command := Turbo.Commands.Cmd_None;
   end record;

end Turbo.Watches;
