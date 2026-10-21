--  Just enough JSON for the Language Server Protocol.
--
--  Reading: Parse fills a Document, an arena of nodes; a Value is an index
--  into it (No_Value when absent), so a message is walked without any
--  allocation to free and a missing field is simply No_Value all the way
--  down: Get (Doc, Get (Doc, Root, "result"), "uri") is safe on any input.
--  Strings come back as UTF-8.
--
--  Writing: messages are built as text with Quote and the small helpers at
--  the end; LSP messages are shallow enough that this reads better than a
--  builder.

with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

package Turbo.JSON is

   type Kind is (J_Null, J_Bool, J_Number, J_String, J_Array, J_Object);

   type Value is new Natural;
   No_Value : constant Value := 0;

   type Document is tagged limited private;

   procedure Parse (Doc : in out Document; Text : String; Ok : out Boolean);

   function Root (Doc : Document) return Value;

   function Kind_Of (Doc : Document; V : Value) return Kind;
   function Is_Present (V : Value) return Boolean is (V /= No_Value);

   function Get (Doc : Document; V : Value; Key : String) return Value;
   --  A member of an object; No_Value if V is not an object or lacks Key.

   function Length (Doc : Document; V : Value) return Natural;
   --  Elements of an array (0 for anything else).

   function Element (Doc : Document; V : Value; N : Positive) return Value;

   function Key (Doc : Document; V : Value) return String;
   --  The member name V was stored under (for walking an object).

   function First_Member (Doc : Document; V : Value) return Value;
   function Next_Member (Doc : Document; V : Value) return Value;

   function To_String (Doc : Document; V : Value; Default : String := "") return String;
   function To_Integer (Doc : Document; V : Value; Default : Integer := 0) return Integer;
   function To_Boolean (Doc : Document; V : Value; Default : Boolean := False) return Boolean;

   function Path (Doc : Document; V : Value; P : String) return Value;
   --  "a.b.c": nested members, for brevity.

   --  Writing

   function Quote (S : String) return String;
   --  S (UTF-8) as a JSON string literal, quotes included.

   function Image (N : Integer) return String;

private

   type Node is record
      K        : Kind := J_Null;
      Name     : Ada.Strings.Unbounded.Unbounded_String;  --  member key
      Text     : Ada.Strings.Unbounded.Unbounded_String;  --  string/number
      Bool     : Boolean := False;
      First    : Value := No_Value;                      --  first child
      Last     : Value := No_Value;
      Next     : Value := No_Value;                      --  next sibling
      Count    : Natural := 0;
   end record;

   package Node_Vectors is new Ada.Containers.Vectors (Positive, Node);

   type Document is tagged limited record
      Nodes : Node_Vectors.Vector;
   end record;

end Turbo.JSON;
