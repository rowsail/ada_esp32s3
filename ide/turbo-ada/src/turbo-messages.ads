--  The message window: what a build printed, with the compiler's
--  "file:line:col: message" lines picked out so Enter (or Alt-F8 from
--  anywhere) jumps to the source.

with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Ada.Strings.Wide_Wide_Unbounded;
with Turbo.Events;
with Turbo.Windows;

package Turbo.Messages is

   type Msg_Kind is (Info, Header, Error, Warning, Note);

   type Message is record
      Kind : Msg_Kind := Info;
      Text : Ada.Strings.Wide_Wide_Unbounded.Unbounded_Wide_Wide_String;
      File : Ada.Strings.Unbounded.Unbounded_String;   --  as printed
      Line : Natural := 0;                              --  0 = no location
      Col  : Natural := 0;
   end record;

   function Parse (Raw : String) return Message;
   --  One line of tool output (UTF-8, escapes already stripped).

   type Jump_Handler is access procedure
     (File : String; Line, Col : Positive; Focus : Boolean);

   type Message_Window is new Turbo.Windows.Window with private;
   type Message_Window_Access is access all Message_Window'Class;

   function Create return Message_Window_Access;

   overriding function Title (W : Message_Window) return Wide_Wide_String;
   overriding procedure Draw (W : in out Message_Window; Active : Boolean);
   overriding procedure Handle_Event
     (W : in out Message_Window; E : Turbo.Events.Event; Handled : out Boolean);

   procedure Clear (W : in out Message_Window);
   procedure Add_Line (W : in out Message_Window; Raw : String);
   --  Lines from ./x --machine ("@x stage ...", "@x diag ...") are read for
   --  what they say; the protocol and result lines are not shown.

   function Stage_Of (Raw : String) return String;
   --  "2/4 compile ..." for an "@x stage" line, else "".
   procedure Add (W : in out Message_Window; Kind : Msg_Kind; Text : String);

   procedure Add_Location
     (W : in out Message_Window; File : String; Line, Col : Positive;
      Text : Wide_Wide_String; Kind : Msg_Kind := Info);
   --  A found-text line (Grep): a location that is not a diagnostic.

   function Errors (W : Message_Window) return Natural;
   function Warnings (W : Message_Window) return Natural;
   function Line_Count (W : Message_Window) return Natural;

   procedure Set_Jump_Handler (W : in out Message_Window; H : Jump_Handler);

   function Step (W : in out Message_Window; Forward : Boolean) return Boolean;
   --  Select the next (previous) message that has a location and jump to
   --  it, leaving the focus in the editor.  False when there is none.

   function First_Error (W : in out Message_Window) return Boolean;
   --  Select and jump to the first error (after a failed build).

   procedure Follow_Tail (W : in out Message_Window);
   --  Scroll so the last line is in view (while a build is running).

private

   package Message_Vectors is new Ada.Containers.Vectors (Positive, Message);

   type Message_Window is new Turbo.Windows.Window with record
      Items    : Message_Vectors.Vector;
      Sel      : Natural := 0;
      Top      : Positive := 1;
      Left     : Natural := 0;
      N_Errors : Natural := 0;
      N_Warn   : Natural := 0;
      Jump     : Jump_Handler;
   end record;

end Turbo.Messages;
