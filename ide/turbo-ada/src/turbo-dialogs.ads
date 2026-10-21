--  Modal dialogs in the Turbo Vision style: a gray box with a double frame,
--  blue input lines, cyan check-box and radio clusters, green buttons with a
--  drop shadow.  Tab moves between controls, Alt+letter (or the letter
--  alone, away from an input line) jumps to a labelled control, Enter
--  presses the default button, Esc cancels.
--
--  A dialog is built from controls, then Run until a button ends it.  The
--  file dialog, the find dialog and the rest are built this way below.

with Ada.Containers.Indefinite_Vectors;
with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Ada.Strings.Wide_Wide_Unbounded;

package Turbo.Dialogs is

   package String_Vectors is new Ada.Containers.Indefinite_Vectors
     (Positive, String);

   subtype String_List is String_Vectors.Vector;

   Cancel_Code    : constant Integer := -1;
   List_Activated : constant Integer := -2;  --  Enter / double-click in a list
   List_Changed   : constant Integer := -3;  --  a Notify list moved

   type Dialog is tagged limited private;

   procedure Init (D : in out Dialog; Title : String; W, H : Positive);
   --  Centred on the screen.  Control coordinates are relative to the
   --  dialog's top-left corner (the frame is at 0).

   procedure Add_Text (D : in out Dialog; X, Y : Natural; Text : String);
   --  Static text; LF starts a new line.

   procedure Add_Label
     (D : in out Dialog; X, Y : Natural; Text : String; For_Control : Positive);
   --  "~T~ext to find": the hot letter focuses For_Control.

   function Add_Input
     (D : in out Dialog; X, Y : Natural; W : Positive; Value : String)
      return Positive;

   function Add_Check
     (D : in out Dialog; X, Y : Natural; W : Positive; Label : String;
      Checked : Boolean) return Positive;

   function Add_Radio
     (D : in out Dialog; X, Y : Natural; W : Positive; Labels : String;
      Selected : Positive) return Positive;
   --  Labels separated by '|': "~F~orward|~B~ackward".

   function Add_Button
     (D : in out Dialog; X, Y : Natural; W : Positive; Label : String;
      Code : Integer; Default : Boolean := False) return Positive;

   function Add_List
     (D : in out Dialog; X, Y : Natural; W, H : Positive;
      Notify : Boolean := False) return Positive;

   procedure Add_Button
     (D : in out Dialog; X, Y : Natural; W : Positive; Label : String;
      Code : Integer; Default : Boolean := False);
   --  For when the id is not needed.

   procedure Set_Items (D : in out Dialog; Id : Positive; Items : String_List);
   procedure Set_List_Index (D : in out Dialog; Id : Positive; Index : Natural);
   procedure Set_Value (D : in out Dialog; Id : Positive; Value : String);
   procedure Focus (D : in out Dialog; Id : Positive);

   function Run (D : in out Dialog) return Integer;
   --  The code of the button pressed, or one of the negative codes above.
   --  Run again to continue (the state is kept).

   function Value (D : Dialog; Id : Positive) return String;
   function Checked (D : Dialog; Id : Positive) return Boolean;
   function Radio_Value (D : Dialog; Id : Positive) return Positive;
   function List_Index (D : Dialog; Id : Positive) return Natural;
   function List_Item (D : Dialog; Id : Positive) return String;
   function Focused (D : Dialog) return Natural;

   --  Stock dialogs

   type Buttons is (OK_Only, OK_Cancel, Yes_No, Yes_No_Cancel);
   type Answer is (Ans_OK, Ans_Yes, Ans_No, Ans_Cancel);

   function Message_Box
     (Title, Text : String; Kind : Buttons := OK_Only) return Answer;
   procedure Message_Box (Title, Text : String);

   function Input_Box
     (Title, Label : String;
      Value        : in out Ada.Strings.Unbounded.Unbounded_String;
      Width        : Positive := 40) return Boolean;

   type Find_Options is record
      Text       : Ada.Strings.Wide_Wide_Unbounded.Unbounded_Wide_Wide_String;
      New_Text   : Ada.Strings.Wide_Wide_Unbounded.Unbounded_Wide_Wide_String;
      Match_Case : Boolean := False;
      Whole_Word : Boolean := False;
      Backward   : Boolean := False;
      From_Top   : Boolean := False;   --  "Entire scope"
      Prompt     : Boolean := True;
      Change_All : Boolean := False;
      Replacing  : Boolean := False;
   end record;

   function Find_Dialog (Opt : in out Find_Options; Replace : Boolean)
                         return Boolean;

   function Open_File_Dialog
     (Title    : String;
      Start    : String;
      Result   : out Ada.Strings.Unbounded.Unbounded_String;
      Wildcard : String := "*.ad?") return Boolean;
   --  Turbo's file dialog: a name line (accepting a path, a directory or a
   --  wildcard), the matching files with the directories after them, and an
   --  information line for the highlighted entry.

   function Choose
     (Title, Label : String;
      Items        : String_List;
      Index        : in out Positive;
      Width        : Positive := 50;
      Ok_Label     : String := "~O~K") return Boolean;
   --  Pick one from a list.

   procedure Show_Busy (Title, Text : String);
   --  Draw a box with no buttons and return (for "Searching..." moments).

private

   type Control_Kind is (Static, Label, Input, Check, Radio, Button, List);

   type Control is record
      Kind     : Control_Kind := Static;
      X, Y     : Natural := 0;
      W, H     : Positive := 1;
      Text     : Ada.Strings.Unbounded.Unbounded_String;      --  labels
      Value    : Ada.Strings.Wide_Wide_Unbounded.Unbounded_Wide_Wide_String;
      Cur      : Positive := 1;       --  input: cursor; radio/list: choice
      Scroll   : Natural := 0;        --  input: first char shown; list: top
      Select_All : Boolean := False;  --  input: typing replaces everything
      On       : Boolean := False;    --  check box
      Code     : Integer := 0;        --  button
      Default  : Boolean := False;
      Target   : Natural := 0;        --  label -> control
      Notify   : Boolean := False;
      Items    : String_List;
      Typed_At : Duration := 0.0;     --  list: when Value (the typed
                                      --  prefix) last grew
   end record;

   package Control_Vectors is new Ada.Containers.Vectors (Positive, Control);

   type Dialog is tagged limited record
      Title    : Ada.Strings.Unbounded.Unbounded_String;
      X, Y     : Integer := 1;
      W, H     : Positive := 10;
      Controls : Control_Vectors.Vector;
      Focus    : Natural := 0;
      Last_Click_Item : Integer := -1;
      Last_Click_Time : Duration := 0.0;
   end record;

end Turbo.Dialogs;
