--  The menu bar and its pull-downs, laid out as Turbo C++ 3.0 laid them
--  out, with the Ada / Alire / ESP32 actions in the places the C ones were.

with Turbo.Commands;

package Turbo.Menus is

   use Turbo.Commands;

   type Enabled_Func is access function (C : Command) return Boolean;
   type Redraw_Proc is access procedure;

   procedure Set_Hooks (Enabled : Enabled_Func; Background : Redraw_Proc);
   --  Enabled grays out what cannot run now; Background repaints the
   --  desktop under an open menu.

   procedure Draw_Bar (Selected : Natural := 0);

   function Menu_Count return Positive;

   function Menu_For_Alt (Ch : Wide_Wide_Character) return Natural;
   --  Alt-F -> the File menu; 0 when no menu has that hot letter.
   --  Alt-Space opens the system menu.

   function Menu_At (X : Integer) return Natural;
   --  The menu whose title is at column X of the bar, or 0.

   function Execute (Start : Positive; Open : Boolean;
                     Mouse_Down : Boolean := False) return Command;
   --  Run the menu bar modally from menu Start (open or just highlighted).
   --  Mouse_Down: entered by a mouse press on the bar, so a release over
   --  an item chooses it.  Returns Cmd_None when cancelled.

   function Key_Text (C : Command) return String;
   --  The short-cut shown beside a command ("F9", "Alt-X"), or "".

end Turbo.Menus;
