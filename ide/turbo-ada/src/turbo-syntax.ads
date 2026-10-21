--  Per-line syntax highlighting.
--
--  Ada has no block comments, so an Ada line can be classified on its own:
--  no state carried from line to line, nothing to re-scan after an edit.
--  The other languages an Ada/ESP32 project touches (shell scripts, TOML,
--  linker scripts, C glue) get a lighter treatment.

package Turbo.Syntax is

   type Language is (Plain, Ada_Lang, Shell_Lang, C_Lang);

   function Language_Of (File_Name : String) return Language;
   --  .ads .adb .ada .gpr -> Ada; .sh .toml .cfg .ini .py Makefile -> Shell
   --  (hash comments); .c .h .S .ld -> C.

   type Token_Class is (Normal, Keyword, Comment, String_Lit, Number, Directive);

   type Class_Array is array (Positive range <>) of Token_Class;

   procedure Classify
     (Lang : Language; Line : Wide_Wide_String; Classes : out Class_Array)
     with Pre => Classes'First = Line'First and then Classes'Last = Line'Last;

   function Is_Ada_Keyword (Word : Wide_Wide_String) return Boolean;

end Turbo.Syntax;
