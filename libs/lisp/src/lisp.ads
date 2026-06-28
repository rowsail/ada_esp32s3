--  A small LISP, written in pure Ada.  This package is the heart: the one value
--  type, the cell arena it lives in, interned symbols, and the printer.  The
--  reader is Lisp.Reader and the evaluator is Lisp.Eval.
--
--  Every object is a variant record sized to its largest case, so all objects are
--  the same size and live as uniform cells in a bump-allocated arena (garbage
--  collection comes later -- for now the arena only grows).  References between
--  objects are Ref values into that arena.
package Lisp is

   type Object;
   type Ref is access all Object;

   type Kind is (K_Nil, K_Bool, K_Int, K_Symbol, K_Cons, K_Prim, K_Closure);

   type Symbol_Id is new Natural;

   --  A primitive is a library-level Ada function over the (already evaluated)
   --  argument list -- closure-free, so it obeys No_Implicit_Dynamic_Code.
   type Prim_Fn is access function (Args : Ref) return Ref;

   type Object (K : Kind := K_Nil) is record
      case K is
         when K_Nil     => null;
         when K_Bool    => B : Boolean;
         when K_Int     => I : Long_Long_Integer;
         when K_Symbol  => Sym : Symbol_Id;
         when K_Cons    => Car, Cdr : Ref;
         when K_Prim    => Fn : Prim_Fn; Fn_Name : Symbol_Id;
         when K_Closure => Params, Code, Env : Ref;
      end case;
   end record;

   --  Raised on any LISP-level error (bad syntax, unbound symbol, type error).
   Lisp_Error : exception;

   --------------------------------------------------------------------------
   --  Singletons and constructors
   --------------------------------------------------------------------------
   function Nil        return Ref;
   function Lisp_True  return Ref;
   function Lisp_False return Ref;

   function Cons      (A, D : Ref) return Ref;
   function Make_Int  (V : Long_Long_Integer) return Ref;
   function Make_Bool (V : Boolean) return Ref;
   function Intern    (Name : String) return Ref;   --  the canonical symbol object

   function Make_Prim    (Name : String; Fn : Prim_Fn) return Ref;
   function Make_Closure (Params, Code, Env : Ref) return Ref;

   --  Integer value of an Int object (Lisp_Error if it is not one).
   function Int_Value (O : Ref) return Long_Long_Integer;

   --------------------------------------------------------------------------
   --  Accessors and predicates
   --------------------------------------------------------------------------
   function Car (O : Ref) return Ref;               --  Lisp_Error if not a cons
   function Cdr (O : Ref) return Ref;
   function Cadr (O : Ref) return Ref is (Car (Cdr (O)));

   function Is_Nil    (O : Ref) return Boolean;
   function Is_Cons   (O : Ref) return Boolean;
   function Is_Symbol (O : Ref) return Boolean;
   function Is_Truthy (O : Ref) return Boolean;     --  everything but #f and ()

   function Symbol_Name (O : Ref) return String;

   --------------------------------------------------------------------------
   --  Rendering and arena control
   --------------------------------------------------------------------------
   function Print (O : Ref) return String;          --  object as text

   --  Allocate the cell arena (Cells objects).  On the board call this once, after
   --  PSRAM/heap are up, with a board-appropriate size; the arena is heap-allocated
   --  so it lands in the PSRAM heap rather than internal SRAM.  Auto-runs with the
   --  default size on first use if not called.
   procedure Init (Cells : Positive := 200_000);

   procedure Reset;                                 --  empty the arena (tests)
   function  Cells_Used return Natural;

end Lisp;
