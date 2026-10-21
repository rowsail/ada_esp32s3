--  The edit window: one file, Turbo C++ keys (and the common modern ones),
--  syntax colouring, mouse selection.

with Ada.Strings.Unbounded;
with Ada.Calendar;
with Turbo.Buffers;
with Turbo.Commands;
with Turbo.Events;
with Turbo.Syntax;
with Turbo.Windows;

package Turbo.Editors is

   use Turbo.Buffers;

   type Editor is new Turbo.Windows.Window with private;
   type Editor_Access is access all Editor'Class;

   function Create (File_Name : String; Untitled_Index : Natural)
                    return Editor_Access;
   --  File_Name "" makes NONAMEnn.ADB.  A name that does not exist yet
   --  opens an empty buffer that will be saved under that name.

   overriding function Title (E : Editor) return Wide_Wide_String;
   overriding procedure Draw (E : in out Editor; Active : Boolean);
   overriding procedure Handle_Event
     (E : in out Editor; E_In : Turbo.Events.Event; Handled : out Boolean);

   function Path (E : Editor) return String;
   --  Full path, or "" if untitled.

   function Is_Untitled (E : Editor) return Boolean;
   function Modified (E : Editor) return Boolean;
   function Load_Failed (E : Editor) return Boolean;
   --  The file exists but could not be read.

   procedure Save (E : in out Editor; Ok : out Boolean);
   procedure Save_As (E : in out Editor; File_Name : String; Ok : out Boolean);

   function Cursor (E : Editor) return Position;
   procedure Go_To (E : in out Editor; Line, Col : Positive;
                    Mark_Error : Boolean := False);

   --  Edit menu

   procedure Undo (E : in out Editor);
   procedure Redo (E : in out Editor);
   procedure Cut (E : in out Editor);
   procedure Copy (E : in out Editor);
   procedure Paste (E : in out Editor);
   procedure Clear (E : in out Editor);
   procedure Select_All (E : in out Editor);
   function Can_Undo (E : Editor) return Boolean;
   function Can_Redo (E : Editor) return Boolean;
   function Has_Selection (E : Editor) return Boolean;
   function Selected_Text (E : Editor) return Wide_Wide_String;
   function Word_At_Cursor (E : Editor) return Wide_Wide_String;

   --  Search

   function Find_Next
     (E          : in out Editor;
      Pattern    : Wide_Wide_String;
      Match_Case : Boolean;
      Whole_Word : Boolean;
      Backward   : Boolean;
      From_Top   : Boolean := False) return Boolean;
   --  Select the next match after the cursor (or the selection).

   procedure Replace_Selection (E : in out Editor; Text : Wide_Wide_String);

   procedure Begin_Edit_Group (E : in out Editor);
   procedure End_Edit_Group (E : in out Editor);
   --  Make a replace-all one undo step.

   function Take_Request (E : in out Editor) return Turbo.Commands.Command;
   --  A command asked for by an editor key sequence (Ctrl-Q F is Find,
   --  Ctrl-K S is Save, ...), handed to the application once.

   function Status_Hint (E : Editor) return String;
   --  "^K" while a Ctrl-K/Ctrl-Q prefix is pending, else "".

private

   type Editor is new Turbo.Windows.Window with record
      Buf          : Buffer;
      File_Name    : Ada.Strings.Unbounded.Unbounded_String;
      Untitled     : Ada.Strings.Unbounded.Unbounded_String;
      Lang         : Turbo.Syntax.Language := Turbo.Syntax.Ada_Lang;
      Cur          : Position;
      Sel_A, Sel_B : Position;         --  the block, either order
      Has_Sel      : Boolean := False;
      Persistent   : Boolean := False; --  a Ctrl-K B / K block
      Top          : Positive := 1;    --  first line shown
      Left         : Natural := 0;     --  first visual column shown
      Want_VCol    : Natural := 0;     --  for Up/Down through short lines
      Prefix       : Character := ' '; --  'k' or 'q' after Ctrl-K / Ctrl-Q
      Error_Line   : Natural := 0;
      Mouse_Sel    : Boolean := False;
      Last_Click   : Ada.Calendar.Time := Ada.Calendar.Clock;
      Last_Click_Pos : Position;
      Bad_Load     : Boolean := False;
      Request      : Turbo.Commands.Command := Turbo.Commands.Cmd_None;
   end record;

end Turbo.Editors;
