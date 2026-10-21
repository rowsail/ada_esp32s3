--  Input events, decoded from the terminal's byte stream.
--
--  Everything arrives as xterm-style sequences (on Windows too: see
--  term_c.c), so there is one decoder.  A letter typed with Ctrl or Alt is a
--  Char_Key carrying the lower-case letter and the modifier, which is how the
--  WordStar and Turbo bindings (Ctrl-K B, Alt-X, ...) are written down.

with Ada.Strings.Wide_Wide_Unbounded;

package Turbo.Events is

   type Key_Code is
     (No_Key, Char_Key,
      Enter, Tab, Backspace, Escape,
      Up, Down, Left, Right, Home, End_Key, Page_Up, Page_Down,
      Insert, Delete,
      F1, F2, F3, F4, F5, F6, F7, F8, F9, F10, F11, F12);

   subtype Function_Key is Key_Code range F1 .. F12;

   type Mouse_Action is (Press, Release, Drag, Wheel_Up, Wheel_Down);

   type Event_Kind is (None, Key, Mouse, Paste, Resize);

   type Event is record
      Kind   : Event_Kind := None;
      Code   : Key_Code := No_Key;
      Ch     : Wide_Wide_Character := ' ';
      Shift  : Boolean := False;
      Ctrl   : Boolean := False;
      Alt    : Boolean := False;
      Action : Mouse_Action := Press;
      Button : Natural := 0;          --  0 left, 1 middle, 2 right
      X, Y   : Natural := 0;          --  1-based screen column / row
      Text   : Ada.Strings.Wide_Wide_Unbounded.Unbounded_Wide_Wide_String;
   end record;

   function Get (Timeout_Ms : Integer) return Event;
   --  The next event, or one of Kind None after Timeout_Ms.

   procedure Push_Back (E : Event);
   --  The next Get returns E (one deep: for a menu handing on the key that
   --  closed it).

   --  Readable tests for the bindings.

   function Is_Ctrl (E : Event; Letter : Character) return Boolean;
   function Is_Alt (E : Event; Letter : Character) return Boolean;
   function Is_Key
     (E     : Event;
      Code  : Key_Code;
      Shift : Boolean := False;
      Ctrl  : Boolean := False;
      Alt   : Boolean := False) return Boolean;
   --  Exact match, modifiers included.

   function Is_Plain_Char (E : Event) return Boolean;
   --  A printable character with no Ctrl/Alt: something to insert.

   function Describe (E : Event) return String;
   --  "Ctrl-K", "Alt-F9", ... for diagnostics and the help screen.

end Turbo.Events;
