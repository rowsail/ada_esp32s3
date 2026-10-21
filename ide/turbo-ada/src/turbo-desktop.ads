--  The desktop: the stack of windows between the menu bar and the status
--  line, and the drawing of the whole screen.

with Turbo.Commands;
with Turbo.Windows;

package Turbo.Desktop is

   use Turbo.Windows;

   function Area return Rect;
   --  Rows 2 .. Height-1, the full width.

   procedure Add (W : Window_Access);
   --  On top, active, numbered with the lowest free number.

   procedure Remove (W : Window_Access);

   procedure Activate (W : Window_Access);
   --  Bring to the top.

   function Active return Window_Access;
   function Count return Natural;
   function Nth (N : Positive) return Window_Access;
   --  Bottom (1) to top (Count).

   function Window_At (X, Y : Integer) return Window_Access;
   --  The topmost window under the point, or null.

   function With_Number (N : Positive) return Window_Access;

   procedure Next_Window;
   procedure Prev_Window;
   procedure Tile;
   procedure Cascade;

   procedure Draw;
   --  The whole screen: background, windows, menu bar, status line.

   procedure Draw_Background_Only;
   --  Everything but the status line hint (used under menus and dialogs).

   --  The status line

   type Label_Access is access constant String;

   type Status_Item is record
      Label : Label_Access;             --  "~F1~ Help"
      Cmd   : Turbo.Commands.Command;
   end record;

   type Status_Items is array (Positive range <>) of Status_Item;

   procedure Set_Status (Items : Status_Items);
   procedure Set_Status_Message (Text : String; Busy : Boolean := False);
   --  A message replaces the items until cleared with "".

   procedure Set_Status_Right (Text : String);
   --  Shown at the right end of the status line (the project name).

   function Status_Command_At (X : Integer) return Turbo.Commands.Command;

end Turbo.Desktop;
