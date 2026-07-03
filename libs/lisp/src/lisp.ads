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

   --  A vector's elements live in a separately heap-allocated array (vectors need
   --  O(1) indexing, which the uniform-cell arena can't give); the K_Vector cell
   --  just holds the access.  The GC marks the elements and frees dead backings.
   type Ref_Array is array (Natural range <>) of Ref;
   type Ref_Vec is access Ref_Array;

   type Kind is
     (K_Nil,
      K_Bool,
      K_Int,
      K_Float,
      K_Char,
      K_String,
      K_Symbol,
      K_Cons,
      K_Prim,
      K_Closure,
      K_Vector);

   type Symbol_Id is new Natural;

   --  A primitive is a library-level Ada function over the (already evaluated)
   --  argument list -- closure-free, so it obeys No_Implicit_Dynamic_Code.
   type Prim_Fn is access function (Args : Ref) return Ref;

   type Object (K : Kind := K_Nil) is record
      Mark : Boolean := False;            --  GC mark bit
      case K is
         when K_Nil =>
            null;

         when K_Bool =>
            B : Boolean;

         when K_Int =>
            I : Long_Long_Integer;

         when K_Float =>
            F : Float;                    --  IEEE single, on the hardware FPU

         when K_Char =>
            Ch : Character;

         when K_String =>
            Str : Ref;                    --  head of a cons-chain of K_Char cells

         when K_Symbol =>
            Sym : Symbol_Id;

         when K_Cons =>
            Car, Cdr : Ref;

         when K_Prim =>
            Fn      : Prim_Fn;
            Fn_Name : Symbol_Id;

         when K_Closure =>
            Params, Code, Env : Ref;

         when K_Vector =>
            Vec : Ref_Vec;                --  0-based array of elements (heap)
      end case;
   end record;

   --  Raised on any LISP-level error (bad syntax, unbound symbol, type error).
   Lisp_Error : exception;

   --------------------------------------------------------------------------
   --  Singletons and constructors
   --------------------------------------------------------------------------
   function Nil return Ref;
   function Lisp_True return Ref;
   function Lisp_False return Ref;

   function Cons (A, D : Ref) return Ref;
   function Make_Int (V : Long_Long_Integer) return Ref;
   function Make_Float (V : Float) return Ref;
   function Make_Char (C : Character) return Ref;
   function Make_String (S : String) return Ref;   --  a cons-chain of char cells
   function Make_Bool (V : Boolean) return Ref;
   function Intern (Name : String) return Ref;   --  the canonical symbol object

   function Make_Prim (Name : String; Fn : Prim_Fn) return Ref;
   function Make_Closure (Params, Code, Env : Ref) return Ref;

   --  Integer value of an Int object (Lisp_Error if it is not one).
   function Int_Value (O : Ref) return Long_Long_Integer;

   --  Value accessors for the new leaf types (Lisp_Error on a type mismatch).
   function Float_Value (O : Ref) return Float;
   function Char_Value (O : Ref) return Character;
   function Str_Value (O : Ref) return String;   --  a K_String's chars, as Ada text

   --  Vectors: a K_Vector cell over a heap-allocated element array.
   function Make_Vector (N : Natural; Fill : Ref) return Ref;
   function Vector_Length (O : Ref) return Natural;
   function Vector_Ref (O : Ref; I : Natural) return Ref;   --  Lisp_Error if I >= length
   procedure Vector_Set (O : Ref; I : Natural; X : Ref);

   --------------------------------------------------------------------------
   --  Accessors and predicates
   --------------------------------------------------------------------------
   function Car (O : Ref) return Ref;               --  Lisp_Error if not a cons
   function Cdr (O : Ref) return Ref;
   function Cadr (O : Ref) return Ref
   is (Car (Cdr (O)));

   function Is_Nil (O : Ref) return Boolean;
   function Is_Cons (O : Ref) return Boolean;
   function Is_Symbol (O : Ref) return Boolean;
   function Is_Float (O : Ref) return Boolean;
   function Is_Char (O : Ref) return Boolean;
   function Is_String (O : Ref) return Boolean;
   function Is_Vector (O : Ref) return Boolean;
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

   --  Mark-sweep garbage collection.  Marks everything reachable from Root (and the
   --  singletons), then returns every other cell to the free list.  Call ONLY when
   --  no live object is held solely in an Ada local -- i.e. between top-level forms,
   --  with Root the global environment.  Returns the number of cells reclaimed.
   function GC (Root : Ref) return Natural;

   procedure Reset;                                 --  empty the arena (tests)
   function Cells_Used return Natural;

end Lisp;
