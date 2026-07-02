--  The reader: parse S-expression text into Lisp objects.

package Lisp.Reader is

   --  Read one complete object from Source, starting at Pos and advancing Pos
   --  past it.  Returns null at end of input (only whitespace/comments left).
   --  Raises Lisp_Error on malformed input.
   function Read (Source : String; Pos : in out Natural) return Ref;

   --  Read a single complete object from a whole string.
   function Read (Source : String) return Ref;

end Lisp.Reader;
