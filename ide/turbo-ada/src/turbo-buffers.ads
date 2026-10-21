--  The text of one file: a vector of lines, two primitive edits (insert a
--  string, delete a range) that everything else is built from, and undo/redo
--  as the record of those two edits.

with Ada.Containers.Vectors;
with Ada.Finalization;
with Ada.Strings.Wide_Wide_Unbounded;

package Turbo.Buffers is

   use Ada.Strings.Wide_Wide_Unbounded;

   subtype Line_Text is Unbounded_Wide_Wide_String;

   type Position is record
      Line : Positive := 1;
      Col  : Positive := 1;          --  character index, 1 .. length + 1
   end record;

   function "<" (A, B : Position) return Boolean is
     (A.Line < B.Line or else (A.Line = B.Line and then A.Col < B.Col));

   LF : constant Wide_Wide_Character := Wide_Wide_Character'Val (10);

   type Buffer is tagged limited private;

   procedure Clear (B : in out Buffer);

   procedure Load (B : in out Buffer; File_Name : String; Ok : out Boolean);
   --  UTF-8 (Latin-1 if the file is not valid UTF-8).  CRLF files are
   --  remembered as such and saved back as CRLF.

   procedure Save (B : in out Buffer; File_Name : String; Ok : out Boolean);

   function Line_Count (B : Buffer) return Positive;
   function Line (B : Buffer; N : Positive) return Wide_Wide_String;
   function Line_Length (B : Buffer; N : Positive) return Natural;

   function Last_Position (B : Buffer) return Position;

   function Clamp (B : Buffer; P : Position) return Position;
   --  The nearest position that exists.

   function Text (B : Buffer; From, To : Position) return Wide_Wide_String;
   --  From inclusive, To exclusive; lines joined with LF.

   function All_Text (B : Buffer) return Wide_Wide_String;

   procedure Insert
     (B : in out Buffer; At_Pos : Position; S : Wide_Wide_String;
      After : out Position);
   --  S may contain LF.  After is just past the inserted text.

   procedure Delete (B : in out Buffer; From, To : Position);

   function Modified (B : Buffer) return Boolean;
   procedure Set_Unmodified (B : in out Buffer);

   function CRLF (B : Buffer) return Boolean;

   --  Undo

   procedure Begin_Group (B : in out Buffer; Cursor : Position);
   procedure End_Group (B : in out Buffer);
   --  Edits between the two undo as one.  Cursor is where to put the
   --  cursor back on undo.

   procedure Break_Typing (B : in out Buffer);
   --  Consecutive single-character inserts merge into one undo step (a word
   --  at a time, like Turbo C++); this ends the current run.

   function Can_Undo (B : Buffer) return Boolean;
   function Can_Redo (B : Buffer) return Boolean;

   procedure Undo (B : in out Buffer; Cursor : out Position);
   procedure Redo (B : in out Buffer; Cursor : out Position);

   --  Search

   function Find
     (B          : Buffer;
      Pattern    : Wide_Wide_String;
      From       : Position;
      Forward    : Boolean;
      Match_Case : Boolean;
      Whole_Word : Boolean;
      Found      : out Position) return Boolean;
   --  Within a line only (patterns do not span line ends).

private

   package Line_Vectors is new Ada.Containers.Vectors (Positive, Line_Text);

   type Op_Kind is (Op_Insert, Op_Delete);

   type Op is record
      Kind   : Op_Kind;
      Pos    : Position;
      Text   : Unbounded_Wide_Wide_String;
      Group  : Natural;               --  ops with one group id undo together
      Cursor : Position;              --  where the cursor was before
   end record;

   package Op_Vectors is new Ada.Containers.Vectors (Positive, Op);

   type Buffer is new Ada.Finalization.Limited_Controlled with record
      Lines       : Line_Vectors.Vector;
      Undo_Stack  : Op_Vectors.Vector;
      Redo_Stack  : Op_Vectors.Vector;
      Next_Group  : Positive := 1;
      Open_Group  : Natural := 0;     --  0 = none open
      Group_Depth : Natural := 0;
      Group_Cursor : Position;
      Typing      : Boolean := False; --  last op was a typed character
      Changes     : Integer := 0;     --  edits since the last save (undo -1)
      Is_CRLF     : Boolean := False;
      Replaying   : Boolean := False;
   end record;

   overriding procedure Initialize (B : in out Buffer);
   --  A new buffer holds one empty line, never none.

end Turbo.Buffers;
