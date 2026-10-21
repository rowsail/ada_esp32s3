--  The window base type: a framed, numbered, movable, zoomable rectangle on
--  the desktop.  Edit, message and help windows extend it.

with Turbo.Events;

package Turbo.Windows is

   type Rect is record
      X, Y : Integer := 1;      --  top-left corner, frame included
      W, H : Integer := 10;
   end record;

   type Frame_Colors is record
      Frame, Frame_Idle, Icon, Scroll : Attribute;
   end record;

   type Hit_Kind is
     (Outside, Close_Box, Zoom_Box, Title_Bar, Resize_Corner,
      V_Scroll_Up, V_Scroll_Down, V_Scroll_Page_Up, V_Scroll_Page_Down,
      H_Scroll_Left, H_Scroll_Right, H_Scroll_Page_Left, H_Scroll_Page_Right,
      Border, Inside);

   type Window is abstract tagged limited record
      Bounds  : Rect;
      Normal  : Rect;               --  the bounds to go back to after Zoom
      Zoomed  : Boolean := False;
      Number  : Natural := 0;       --  1 .. 9 shown on the frame; 0 = none
   end record;

   type Window_Access is access all Window'Class;

   function Title (W : Window) return Wide_Wide_String is abstract;

   procedure Draw (W : in out Window; Active : Boolean) is abstract;
   --  The whole window, frame included.  Set the cursor if Active.

   procedure Handle_Event
     (W       : in out Window;
      E       : Turbo.Events.Event;
      Handled : out Boolean) is abstract;
   --  A key or a mouse event inside the interior (or on a scroll bar).

   function Min_Width (W : Window) return Positive is (24);
   function Min_Height (W : Window) return Positive is (6);

   function Interior (W : Window'Class) return Rect;

   function Hit (W : Window'Class; X, Y : Integer) return Hit_Kind;

   procedure Draw_Frame
     (W        : Window'Class;
      Active   : Boolean;
      Colors   : Frame_Colors;
      V_Pos, V_Total, V_Page : Natural := 0;
      H_Pos, H_Total, H_Page : Natural := 0;
      Indicator : Wide_Wide_String := "");
   --  Totals of 0 mean no scroll bar.  Indicator is the editor's "12:5"
   --  (with "*" when modified) in the bottom-left of the frame.

   procedure Move_To (W : in out Window'Class; R : Rect);
   --  Set the bounds, kept on the desktop and at least the minimum size.

   procedure Toggle_Zoom (W : in out Window'Class; Desk : Rect);

end Turbo.Windows;
