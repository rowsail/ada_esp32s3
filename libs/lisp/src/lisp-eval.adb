with Ada.Numerics.Elementary_Functions;
with Ada.Unchecked_Conversion;
with Interfaces; use Interfaces;
with Lisp.Reader;

package body Lisp.Eval is

   package EF renames Ada.Numerics.Elementary_Functions;   --  math for sqrt/expt/...

   function To_U64 is new Ada.Unchecked_Conversion (Long_Long_Integer, Interfaces.Unsigned_64);
   function To_I64 is new Ada.Unchecked_Conversion (Interfaces.Unsigned_64, Long_Long_Integer);

   --  Forward declarations for the mutually-recursive evaluator pieces (Eval
   --  itself is already declared in the spec).
   function Eval_Args (Args, Env : Ref) return Ref;
   function Eval_Seq (Body_List, Env : Ref) return Ref;

   --  Special-form symbols, interned once (compared by identity).
   S_Quote, S_If, S_Define, S_Lambda, S_Let, S_Cond, S_Begin, S_Set, S_And, S_Or, S_Else : Ref;
   S_Let_Star, S_Letrec, S_When, S_Unless, S_Case, S_Do                                  : Ref;
   S_Quasi, S_Unquote, S_Unquote_Splice                                                  : Ref;

   G_Env : Ref;
   function Global_Env return Ref
   is (G_Env);
   function Eval_Top (Expr : Ref) return Ref
   is (Eval (Expr, G_Env));

   --------------------------------------------------------------------------
   --  Environments: Env = (frame . parent); frame = a-list of (sym . value).
   --------------------------------------------------------------------------
   function Lookup (Sym, Env : Ref) return Ref is
      Env_Cursor : Ref := Env;   --  walks the env chain outward
   begin
      while Is_Cons (Env_Cursor) loop
         declare
            Frame : Ref := Car (Env_Cursor);
         begin
            while Is_Cons (Frame) loop
               if Car (Car (Frame)) = Sym then
                  return Cdr (Car (Frame));
               end if;
               Frame := Cdr (Frame);
            end loop;
         end;
         Env_Cursor := Cdr (Env_Cursor);
      end loop;
      raise Lisp_Error with "unbound symbol: " & Symbol_Name (Sym);
   end Lookup;

   --  Bind Sym to Val in Env's own (innermost) frame.
   procedure Define (Sym, Val, Env : Ref) is
   begin
      Env.Car := Cons (Cons (Sym, Val), Env.Car);
   end Define;

   --  Mutate the nearest existing binding of Sym.
   procedure Set_Var (Sym, Val, Env : Ref) is
      Env_Cursor : Ref := Env;   --  walks the env chain outward
   begin
      while Is_Cons (Env_Cursor) loop
         declare
            Frame : Ref := Car (Env_Cursor);
         begin
            while Is_Cons (Frame) loop
               if Car (Car (Frame)) = Sym then
                  Car (Frame).Cdr := Val;
                  return;
               end if;
               Frame := Cdr (Frame);
            end loop;
         end;
         Env_Cursor := Cdr (Env_Cursor);
      end loop;
      raise Lisp_Error with "set! of unbound: " & Symbol_Name (Sym);
   end Set_Var;

   --------------------------------------------------------------------------
   --  Primitive helpers + the primitives themselves (library-level functions).
   --------------------------------------------------------------------------
   function Arg1 (A : Ref) return Ref
   is (Car (A));
   function Arg2 (A : Ref) return Ref
   is (Car (Cdr (A)));

   --  Numeric tower: integers stay integers; the moment a float appears, the
   --  running result promotes to float (int + float -> float).
   function As_Float (O : Ref) return Float
   is (if Is_Float (O) then Float_Value (O) else Float (Int_Value (O)));

   function Prim_Add (Args : Ref) return Ref is
      ISum      : Long_Long_Integer := 0;
      FSum      : Float := 0.0;
      Any_Float : Boolean := False;
      Cursor    : Ref := Args;
   begin
      while Is_Cons (Cursor) loop
         declare
            O : constant Ref := Car (Cursor);
         begin
            if Is_Float (O) and then not Any_Float then
               FSum := Float (ISum);
               Any_Float := True;
            end if;
            if Any_Float then
               FSum := FSum + As_Float (O);
            else
               ISum := ISum + Int_Value (O);
            end if;
         end;
         Cursor := Cdr (Cursor);
      end loop;
      return (if Any_Float then Make_Float (FSum) else Make_Int (ISum));
   end Prim_Add;

   function Prim_Mul (Args : Ref) return Ref is
      IProd     : Long_Long_Integer := 1;
      FProd     : Float := 1.0;
      Any_Float : Boolean := False;
      Cursor    : Ref := Args;
   begin
      while Is_Cons (Cursor) loop
         declare
            O : constant Ref := Car (Cursor);
         begin
            if Is_Float (O) and then not Any_Float then
               FProd := Float (IProd);
               Any_Float := True;
            end if;
            if Any_Float then
               FProd := FProd * As_Float (O);
            else
               IProd := IProd * Int_Value (O);
            end if;
         end;
         Cursor := Cdr (Cursor);
      end loop;
      return (if Any_Float then Make_Float (FProd) else Make_Int (IProd));
   end Prim_Mul;

   function Prim_Sub (Args : Ref) return Ref is
      Cursor : Ref := Args;
   begin
      if Is_Nil (Cursor) then
         return Make_Int (0);
      end if;
      declare
         First     : constant Ref := Car (Cursor);
         IAcc      : Long_Long_Integer := (if Is_Float (First) then 0 else Int_Value (First));
         FAcc      : Float := (if Is_Float (First) then Float_Value (First) else 0.0);
         Any_Float : Boolean := Is_Float (First);
      begin
         Cursor := Cdr (Cursor);
         if Is_Nil (Cursor) then
            --  unary negate
            return (if Any_Float then Make_Float (-FAcc) else Make_Int (-IAcc));
         end if;
         while Is_Cons (Cursor) loop
            declare
               O : constant Ref := Car (Cursor);
            begin
               if Is_Float (O) and then not Any_Float then
                  FAcc := Float (IAcc);
                  Any_Float := True;
               end if;
               if Any_Float then
                  FAcc := FAcc - As_Float (O);
               else
                  IAcc := IAcc - Int_Value (O);
               end if;
            end;
            Cursor := Cdr (Cursor);
         end loop;
         return (if Any_Float then Make_Float (FAcc) else Make_Int (IAcc));
      end;
   end Prim_Sub;

   function Prim_Div (Args : Ref) return Ref is
      First     : constant Ref := Arg1 (Args);
      IAcc      : Long_Long_Integer := (if Is_Float (First) then 0 else Int_Value (First));
      FAcc      : Float := (if Is_Float (First) then Float_Value (First) else 0.0);
      Any_Float : Boolean := Is_Float (First);
      Cursor    : Ref := Cdr (Args);
   begin
      while Is_Cons (Cursor) loop
         declare
            O : constant Ref := Car (Cursor);
         begin
            if Is_Float (O) and then not Any_Float then
               FAcc := Float (IAcc);
               Any_Float := True;
            end if;
            if Any_Float then
               FAcc := FAcc / As_Float (O);          --  float divide (IEEE)

            else
               declare
                  D : constant Long_Long_Integer := Int_Value (O);
               begin
                  if D = 0 then
                     raise Lisp_Error with "division by zero";
                  end if;
                  IAcc := IAcc / D;                   --  integer divide (truncating)
               end;
            end if;
         end;
         Cursor := Cdr (Cursor);
      end loop;
      return (if Any_Float then Make_Float (FAcc) else Make_Int (IAcc));
   end Prim_Div;

   --  Comparisons: compare as floats if either side is a float, else as integers.
   function Both_Int (A, B : Ref) return Boolean
   is (not (Is_Float (A) or else Is_Float (B)));

   function Prim_Num_Eq (Args : Ref) return Ref
   is (if Both_Int (Arg1 (Args), Arg2 (Args))
       then Make_Bool (Int_Value (Arg1 (Args)) = Int_Value (Arg2 (Args)))
       else Make_Bool (As_Float (Arg1 (Args)) = As_Float (Arg2 (Args))));
   function Prim_Lt (Args : Ref) return Ref
   is (if Both_Int (Arg1 (Args), Arg2 (Args))
       then Make_Bool (Int_Value (Arg1 (Args)) < Int_Value (Arg2 (Args)))
       else Make_Bool (As_Float (Arg1 (Args)) < As_Float (Arg2 (Args))));
   function Prim_Gt (Args : Ref) return Ref
   is (if Both_Int (Arg1 (Args), Arg2 (Args))
       then Make_Bool (Int_Value (Arg1 (Args)) > Int_Value (Arg2 (Args)))
       else Make_Bool (As_Float (Arg1 (Args)) > As_Float (Arg2 (Args))));
   function Prim_Le (Args : Ref) return Ref
   is (if Both_Int (Arg1 (Args), Arg2 (Args))
       then Make_Bool (Int_Value (Arg1 (Args)) <= Int_Value (Arg2 (Args)))
       else Make_Bool (As_Float (Arg1 (Args)) <= As_Float (Arg2 (Args))));
   function Prim_Ge (Args : Ref) return Ref
   is (if Both_Int (Arg1 (Args), Arg2 (Args))
       then Make_Bool (Int_Value (Arg1 (Args)) >= Int_Value (Arg2 (Args)))
       else Make_Bool (As_Float (Arg1 (Args)) >= As_Float (Arg2 (Args))));

   function Prim_Car (Args : Ref) return Ref
   is (Car (Arg1 (Args)));
   function Prim_Cdr (Args : Ref) return Ref
   is (Cdr (Arg1 (Args)));
   function Prim_Cons (Args : Ref) return Ref
   is (Cons (Arg1 (Args), Arg2 (Args)));
   function Prim_List (Args : Ref) return Ref
   is (Args);    --  already evaluated
   function Prim_Null (Args : Ref) return Ref
   is (Make_Bool (Is_Nil (Arg1 (Args))));
   function Prim_Pair (Args : Ref) return Ref
   is (Make_Bool (Is_Cons (Arg1 (Args))));
   function Prim_Not (Args : Ref) return Ref
   is (Make_Bool (not Is_Truthy (Arg1 (Args))));

   function Prim_Eq (Args : Ref) return Ref is
      Left  : constant Ref := Arg1 (Args);
      Right : constant Ref := Arg2 (Args);
   begin
      if Left = Right then
         return Lisp_True;
      end if;
      if Left /= null and then Right /= null and then Left.K = Right.K then
         case Left.K is
            when K_Int   =>
               return Make_Bool (Left.I = Right.I);

            when K_Float =>
               return Make_Bool (Left.F = Right.F);

            when K_Char  =>
               return Make_Bool (Left.Ch = Right.Ch);

            when K_Bool  =>
               return Make_Bool (Left.B = Right.B);

            when K_Nil   =>
               return Lisp_True;

            when others  =>
               null;
         end case;
      end if;
      return Lisp_False;
   end Prim_Eq;

   function Prim_Length (Args : Ref) return Ref is
      Count  : Long_Long_Integer := 0;
      Cursor : Ref := Arg1 (Args);
   begin
      while Is_Cons (Cursor) loop
         Count := Count + 1;
         Cursor := Cdr (Cursor);
      end loop;
      return Make_Int (Count);
   end Prim_Length;

   --------------------------------------------------------------------------
   --  Strings (stored as char cons-chains) and characters.
   --------------------------------------------------------------------------
   function Prim_Is_String (Args : Ref) return Ref
   is (Make_Bool (Is_String (Arg1 (Args))));
   function Prim_Is_Char (Args : Ref) return Ref
   is (Make_Bool (Is_Char (Arg1 (Args))));

   function Prim_Str_Len (Args : Ref) return Ref
   is (Make_Int (Long_Long_Integer (Str_Value (Arg1 (Args))'Length)));

   function Concat (Args : Ref) return String
   is (if Is_Nil (Args) then "" else Str_Value (Car (Args)) & Concat (Cdr (Args)));

   function Prim_Str_Append (Args : Ref) return Ref
   is (Make_String (Concat (Args)));

   function Prim_Str_Eq (Args : Ref) return Ref
   is (Make_Bool (Str_Value (Arg1 (Args)) = Str_Value (Arg2 (Args))));

   function Prim_Str_Ref (Args : Ref) return Ref is
      S : constant String := Str_Value (Arg1 (Args));
      K : constant Long_Long_Integer := Int_Value (Arg2 (Args));
   begin
      if K < 0 or else K >= Long_Long_Integer (S'Length) then
         raise Lisp_Error with "string-ref: index out of range";
      end if;
      return Make_Char (S (S'First + Natural (K)));
   end Prim_Str_Ref;

   function Prim_Substring (Args : Ref) return Ref is
      S  : constant String := Str_Value (Arg1 (Args));
      Lo : constant Long_Long_Integer := Int_Value (Arg2 (Args));
      Hi : constant Long_Long_Integer := Int_Value (Car (Cdr (Cdr (Args))));
   begin
      if Lo < 0 or else Hi > Long_Long_Integer (S'Length) or else Lo > Hi then
         raise Lisp_Error with "substring: index out of range";
      end if;
      return Make_String (S (S'First + Natural (Lo) .. S'First + Natural (Hi) - 1));
   end Prim_Substring;

   function Prim_Char_To_Int (Args : Ref) return Ref
   is (Make_Int (Long_Long_Integer (Character'Pos (Char_Value (Arg1 (Args))))));

   function Prim_Int_To_Char (Args : Ref) return Ref is
      V : constant Long_Long_Integer := Int_Value (Arg1 (Args));
   begin
      if V < 0 or else V > 255 then
         raise Lisp_Error with "integer->char: out of range";
      end if;
      return Make_Char (Character'Val (Integer (V)));
   end Prim_Int_To_Char;

   function Prim_Str_To_List (Args : Ref) return Ref is
      S      : constant String := Str_Value (Arg1 (Args));
      Result : Ref := Nil;
   begin
      for I in reverse S'Range loop
         Result := Cons (Make_Char (S (I)), Result);
      end loop;
      return Result;
   end Prim_Str_To_List;

   function Prim_List_To_Str (Args : Ref) return Ref is
      Cursor : Ref := Arg1 (Args);
      Len    : Natural := 0;
      P      : Ref := Cursor;
   begin
      while Is_Cons (P) loop
         Len := Len + 1;
         P := Cdr (P);
      end loop;
      return R : Ref do
         declare
            Buf : String (1 .. Len);
         begin
            P := Cursor;
            for I in 1 .. Len loop
               Buf (I) := Char_Value (Car (P));
               P := Cdr (P);
            end loop;
            R := Make_String (Buf);
         end;
      end return;
   end Prim_List_To_Str;

   function Prim_Num_To_Str (Args : Ref) return Ref
   is (Make_String (Print (Arg1 (Args))));

   --------------------------------------------------------------------------
   --  List / equality / numeric helpers and the procedures built on them.
   --------------------------------------------------------------------------
   function Is_Number (O : Ref) return Boolean
   is (O /= null and then (O.K = K_Int or else O.K = K_Float));

   --  Deep structural equality (equal?): recurse through pairs, compare leaves
   --  by value (strings by content), everything else by identity.
   function Equal (A, B : Ref) return Boolean is
   begin
      if A = B then
         return True;
      elsif A = null or else B = null then
         return Is_Nil (A) and then Is_Nil (B);
      elsif A.K /= B.K then
         return False;
      end if;
      case A.K is
         when K_Int    =>
            return A.I = B.I;

         when K_Float  =>
            return A.F = B.F;

         when K_Char   =>
            return A.Ch = B.Ch;

         when K_Bool   =>
            return A.B = B.B;

         when K_Nil    =>
            return True;

         when K_Symbol =>
            return A.Sym = B.Sym;

         when K_String =>
            return Str_Value (A) = Str_Value (B);

         when K_Cons   =>
            return Equal (A.Car, B.Car) and then Equal (A.Cdr, B.Cdr);

         when K_Vector =>
            if A.Vec = null or else B.Vec = null then
               return A.Vec = B.Vec;
            elsif A.Vec'Length /= B.Vec'Length then
               return False;
            else
               for I in A.Vec'Range loop
                  if not Equal (A.Vec (I), B.Vec (I)) then
                     return False;
                  end if;
               end loop;
               return True;
            end if;

         when others   =>
            return False;   --  Prim / Closure: identity, already ruled out
      end case;
   end Equal;

   --  Reverse a proper list.
   function Rev (L : Ref) return Ref is
      Result : Ref := Nil;
      Cursor : Ref := L;
   begin
      while Is_Cons (Cursor) loop
         Result := Cons (Car (Cursor), Result);
         Cursor := Cdr (Cursor);
      end loop;
      return Result;
   end Rev;

   --  Copy list A, ending it with B (append of two).
   function Append2 (A, B : Ref) return Ref
   is (if Is_Nil (A) then B else Cons (Car (A), Append2 (Cdr (A), B)));

   --  Apply a function object to an already-evaluated argument list.  Shares the
   --  evaluator's semantics (Eval_Seq for a closure body); used by apply and map.
   --  Unlike Eval's inline path it does not tail-loop -- fine for these callers.
   --  Bind a lambda's parameter list to the argument values in Env.  Supports a
   --  trailing rest parameter -- a dotted tail (a b . rest) or a bare symbol
   --  (args) -- which receives the list of the remaining arguments.
   procedure Bind_Params (Params, Arg_Values, Env : Ref) is
      P : Ref := Params;
      A : Ref := Arg_Values;
   begin
      while Is_Cons (P) loop
         if not Is_Cons (A) then
            raise Lisp_Error with "too few arguments";
         end if;
         Define (Car (P), Car (A), Env);
         P := Cdr (P);
         A := Cdr (A);
      end loop;
      if Is_Symbol (P) then
         Define (P, A, Env);
      end if;
   end Bind_Params;

   function Apply (Fn, Args : Ref) return Ref is
   begin
      if Fn = null then
         raise Lisp_Error with "cannot apply nil";
      end if;
      case Fn.K is
         when K_Prim    =>
            return Fn.Fn (Args);

         when K_Closure =>
            declare
               New_Env : constant Ref := Cons (Nil, Fn.Env);
            begin
               Bind_Params (Fn.Params, Args, New_Env);
               return Eval_Seq (Fn.Code, New_Env);
            end;

         when others    =>
            raise Lisp_Error with "not applicable: " & Print (Fn);
      end case;
   end Apply;

   function Prim_Equal (Args : Ref) return Ref
   is (Make_Bool (Equal (Arg1 (Args), Arg2 (Args))));

   function Prim_Reverse (Args : Ref) return Ref
   is (Rev (Arg1 (Args)));

   function Prim_Cadr (Args : Ref) return Ref
   is (Car (Cdr (Arg1 (Args))));
   function Prim_Caddr (Args : Ref) return Ref
   is (Car (Cdr (Cdr (Arg1 (Args)))));

   function Prim_Is_Number (Args : Ref) return Ref
   is (Make_Bool (Is_Number (Arg1 (Args))));

   function Prim_Is_Zero (Args : Ref) return Ref is
      O : constant Ref := Arg1 (Args);
   begin
      return Make_Bool (if Is_Float (O) then Float_Value (O) = 0.0 else Int_Value (O) = 0);
   end Prim_Is_Zero;

   function Prim_Abs (Args : Ref) return Ref is
      O : constant Ref := Arg1 (Args);
   begin
      return
        (if Is_Float (O) then Make_Float (abs Float_Value (O)) else Make_Int (abs Int_Value (O)));
   end Prim_Abs;

   function Prim_Quotient (Args : Ref) return Ref is
      B : constant Long_Long_Integer := Int_Value (Arg2 (Args));
   begin
      if B = 0 then
         raise Lisp_Error with "quotient: division by zero";
      end if;
      return Make_Int (Int_Value (Arg1 (Args)) / B);      --  truncates toward zero
   end Prim_Quotient;

   function Prim_Modulo (Args : Ref) return Ref is
      B : constant Long_Long_Integer := Int_Value (Arg2 (Args));
   begin
      if B = 0 then
         raise Lisp_Error with "modulo: division by zero";
      end if;
      return Make_Int (Int_Value (Arg1 (Args)) mod B);    --  sign of the divisor
   end Prim_Modulo;

   function Prim_Remainder (Args : Ref) return Ref is
      B : constant Long_Long_Integer := Int_Value (Arg2 (Args));
   begin
      if B = 0 then
         raise Lisp_Error with "remainder: division by zero";
      end if;
      return Make_Int (Int_Value (Arg1 (Args)) rem B);    --  sign of the dividend
   end Prim_Remainder;

   function Prim_Is_Even (Args : Ref) return Ref
   is (Make_Bool (Int_Value (Arg1 (Args)) mod 2 = 0));
   function Prim_Is_Odd (Args : Ref) return Ref
   is (Make_Bool (Int_Value (Arg1 (Args)) mod 2 /= 0));

   function Prim_Is_Symbol (Args : Ref) return Ref
   is (Make_Bool (Is_Symbol (Arg1 (Args))));

   function Prim_Is_Procedure (Args : Ref) return Ref is
      O : constant Ref := Arg1 (Args);
   begin
      return Make_Bool (O /= null and then (O.K = K_Prim or else O.K = K_Closure));
   end Prim_Is_Procedure;

   --  append: copy every list but the last, which is shared (may be improper).
   function Prim_Append (Args : Ref) return Ref is
   begin
      if Is_Nil (Args) then
         return Nil;
      elsif Is_Nil (Cdr (Args)) then
         return Car (Args);
      else
         return Append2 (Car (Args), Prim_Append (Cdr (Args)));
      end if;
   end Prim_Append;

   function Prim_Assoc (Args : Ref) return Ref is
      Key    : constant Ref := Arg1 (Args);
      Cursor : Ref := Arg2 (Args);
   begin
      while Is_Cons (Cursor) loop
         if Is_Cons (Car (Cursor)) and then Equal (Car (Car (Cursor)), Key) then
            return Car (Cursor);
         end if;
         Cursor := Cdr (Cursor);
      end loop;
      return Lisp_False;
   end Prim_Assoc;

   function Prim_Member (Args : Ref) return Ref is
      X      : constant Ref := Arg1 (Args);
      Cursor : Ref := Arg2 (Args);
   begin
      while Is_Cons (Cursor) loop
         if Equal (Car (Cursor), X) then
            return Cursor;
         end if;
         Cursor := Cdr (Cursor);
      end loop;
      return Lisp_False;
   end Prim_Member;

   --  apply: (apply f a b ... lst) -- the last argument is spliced in.
   function Splice (R : Ref) return Ref
   is (if Is_Nil (R)
       then Nil
       elsif Is_Nil (Cdr (R))
       then Car (R)
       else Cons (Car (R), Splice (Cdr (R))));

   function Prim_Apply (Args : Ref) return Ref
   is (Apply (Arg1 (Args), Splice (Cdr (Args))));

   --  map: (map f lst1 lst2 ...) -- apply f across the lists until one runs out.
   function List_Cars (L : Ref) return Ref
   is (if Is_Nil (L) then Nil else Cons (Car (Car (L)), List_Cars (Cdr (L))));
   function List_Cdrs (L : Ref) return Ref
   is (if Is_Nil (L) then Nil else Cons (Cdr (Car (L)), List_Cdrs (Cdr (L))));
   function All_Cons (L : Ref) return Boolean
   is (Is_Nil (L) or else (Is_Cons (Car (L)) and then All_Cons (Cdr (L))));

   function Prim_Map (Args : Ref) return Ref is
      Fn     : constant Ref := Arg1 (Args);
      Lists  : Ref := Cdr (Args);
      Result : Ref := Nil;
   begin
      if Is_Nil (Lists) then
         return Nil;
      end if;
      while All_Cons (Lists) loop
         Result := Cons (Apply (Fn, List_Cars (Lists)), Result);
         Lists := List_Cdrs (Lists);
      end loop;
      return Rev (Result);
   end Prim_Map;

   --  (filter pred lst) -- keep the elements for which pred is truthy.
   function Prim_Filter (Args : Ref) return Ref is
      Pred   : constant Ref := Arg1 (Args);
      Cursor : Ref := Arg2 (Args);
      Result : Ref := Nil;
   begin
      while Is_Cons (Cursor) loop
         if Is_Truthy (Apply (Pred, Cons (Car (Cursor), Nil))) then
            Result := Cons (Car (Cursor), Result);
         end if;
         Cursor := Cdr (Cursor);
      end loop;
      return Rev (Result);
   end Prim_Filter;

   --  (fold-left proc init lst) -- proc is (proc acc elem), left to right.
   function Prim_Fold_Left (Args : Ref) return Ref is
      Proc   : constant Ref := Arg1 (Args);
      Acc    : Ref := Arg2 (Args);
      Cursor : Ref := Car (Cdr (Cdr (Args)));
   begin
      while Is_Cons (Cursor) loop
         Acc := Apply (Proc, Cons (Acc, Cons (Car (Cursor), Nil)));
         Cursor := Cdr (Cursor);
      end loop;
      return Acc;
   end Prim_Fold_Left;

   --  (fold-right proc init lst) -- proc is (proc elem acc); done by folding the
   --  reversed list, so it stays iterative (no per-element Ada recursion).
   function Prim_Fold_Right (Args : Ref) return Ref is
      Proc   : constant Ref := Arg1 (Args);
      Acc    : Ref := Arg2 (Args);
      Cursor : Ref := Rev (Car (Cdr (Cdr (Args))));
   begin
      while Is_Cons (Cursor) loop
         Acc := Apply (Proc, Cons (Car (Cursor), Cons (Acc, Nil)));
         Cursor := Cdr (Cursor);
      end loop;
      return Acc;
   end Prim_Fold_Right;

   --  (list-tail lst k) -- drop the first k elements.
   function Prim_List_Tail (Args : Ref) return Ref is
      Cursor : Ref := Arg1 (Args);
      K      : Long_Long_Integer := Int_Value (Arg2 (Args));
   begin
      while K > 0 loop
         if not Is_Cons (Cursor) then
            raise Lisp_Error with "list-tail: index out of range";
         end if;
         Cursor := Cdr (Cursor);
         K := K - 1;
      end loop;
      return Cursor;
   end Prim_List_Tail;

   --  (list-ref lst k) -- the k-th element (0-based).
   function Prim_List_Ref (Args : Ref) return Ref is
      Tail : constant Ref := Prim_List_Tail (Args);
   begin
      if not Is_Cons (Tail) then
         raise Lisp_Error with "list-ref: index out of range";
      end if;
      return Car (Tail);
   end Prim_List_Ref;

   --------------------------------------------------------------------------
   --  Integer number theory, exponent, sort, and pair mutation.
   --------------------------------------------------------------------------
   function GCD2 (A, B : Long_Long_Integer) return Long_Long_Integer is
      X : Long_Long_Integer := abs A;
      Y : Long_Long_Integer := abs B;
      T : Long_Long_Integer;
   begin
      while Y /= 0 loop
         T := X mod Y;
         X := Y;
         Y := T;
      end loop;
      return X;
   end GCD2;

   function Prim_Gcd (Args : Ref) return Ref is
      Result : Long_Long_Integer := 0;   --  (gcd) = 0; (gcd a) = |a|
      Cursor : Ref := Args;
   begin
      while Is_Cons (Cursor) loop
         Result := GCD2 (Result, Int_Value (Car (Cursor)));
         Cursor := Cdr (Cursor);
      end loop;
      return Make_Int (Result);
   end Prim_Gcd;

   function Prim_Lcm (Args : Ref) return Ref is
      Result : Long_Long_Integer := 1;   --  (lcm) = 1
      Cursor : Ref := Args;
   begin
      while Is_Cons (Cursor) loop
         declare
            V : constant Long_Long_Integer := Int_Value (Car (Cursor));
            G : constant Long_Long_Integer := GCD2 (Result, V);
         begin
            Result := (if G = 0 then 0 else abs (Result / G * V));   --  divide first
         end;
         Cursor := Cdr (Cursor);
      end loop;
      return Make_Int (Result);
   end Prim_Lcm;

   --  Fast exponentiation (square-and-multiply).
   function Int_Pow (Base, Exp : Long_Long_Integer) return Long_Long_Integer is
      Result : Long_Long_Integer := 1;
      B      : Long_Long_Integer := Base;
      E      : Long_Long_Integer := Exp;
   begin
      while E > 0 loop
         if E mod 2 = 1 then
            Result := Result * B;
         end if;
         E := E / 2;
         if E > 0 then
            B := B * B;
         end if;
      end loop;
      return Result;
   end Int_Pow;

   function Float_Pow (Base : Float; Exp : Long_Long_Integer) return Float is
      Result : Float := 1.0;
      B      : Float := Base;
      E      : Long_Long_Integer := abs Exp;
   begin
      while E > 0 loop
         if E mod 2 = 1 then
            Result := Result * B;
         end if;
         E := E / 2;
         if E > 0 then
            B := B * B;
         end if;
      end loop;
      return (if Exp < 0 then 1.0 / Result else Result);
   end Float_Pow;

   --  (expt base exp): exact integer when base and exp are non-negative integers;
   --  otherwise a float (a negative integer exponent, or any float operand).
   function Prim_Expt (Args : Ref) return Ref is
      Base : constant Ref := Arg1 (Args);
      Exp  : constant Ref := Arg2 (Args);
   begin
      if Is_Float (Exp) then
         return Make_Float (EF."**" (As_Float (Base), Float_Value (Exp)));
      elsif Is_Float (Base) then
         return Make_Float (Float_Pow (Float_Value (Base), Int_Value (Exp)));
      else
         declare
            E : constant Long_Long_Integer := Int_Value (Exp);
         begin
            if E >= 0 then
               return Make_Int (Int_Pow (Int_Value (Base), E));
            else
               return Make_Float (Float_Pow (Float (Int_Value (Base)), E));
            end if;
         end;
      end if;
   exception
      when Lisp_Error =>
         raise;
      when others =>
         raise Lisp_Error with "expt: domain error or overflow";
   end Prim_Expt;

   --  Stable merge sort over a list: (sort lst less?).
   function Sort_Merge (A0, B0, Less : Ref) return Ref is
      A   : Ref := A0;
      B   : Ref := B0;
      Acc : Ref := Nil;
   begin
      while Is_Cons (A) and then Is_Cons (B) loop
         --  take B only when it is strictly less, so equal keys keep A first (stable)
         if Is_Truthy (Apply (Less, Cons (Car (B), Cons (Car (A), Nil)))) then
            Acc := Cons (Car (B), Acc);
            B := Cdr (B);
         else
            Acc := Cons (Car (A), Acc);
            A := Cdr (A);
         end if;
      end loop;
      while Is_Cons (A) loop
         Acc := Cons (Car (A), Acc);
         A := Cdr (A);
      end loop;
      while Is_Cons (B) loop
         Acc := Cons (Car (B), Acc);
         B := Cdr (B);
      end loop;
      return Rev (Acc);
   end Sort_Merge;

   function Sort_List (L, Less : Ref) return Ref is
      N : Natural := 0;
      P : Ref := L;
   begin
      while Is_Cons (P) loop
         N := N + 1;
         P := Cdr (P);
      end loop;
      if N < 2 then
         return L;
      end if;
      declare
         Front : Ref := Nil;              --  first half, copied (reversed then Rev'd)
         Q     : Ref := L;
      begin
         for I in 1 .. N / 2 loop
            Front := Cons (Car (Q), Front);
            Q := Cdr (Q);
         end loop;
         return Sort_Merge (Sort_List (Rev (Front), Less), Sort_List (Q, Less), Less);
      end;
   end Sort_List;

   function Prim_Sort (Args : Ref) return Ref
   is (Sort_List (Arg1 (Args), Arg2 (Args)));

   function Prim_Set_Car (Args : Ref) return Ref is
      P : constant Ref := Arg1 (Args);
   begin
      if not Is_Cons (P) then
         raise Lisp_Error with "set-car!: not a pair";
      end if;
      P.Car := Arg2 (Args);
      return Arg2 (Args);
   end Prim_Set_Car;

   function Prim_Set_Cdr (Args : Ref) return Ref is
      P : constant Ref := Arg1 (Args);
   begin
      if not Is_Cons (P) then
         raise Lisp_Error with "set-cdr!: not a pair";
      end if;
      P.Cdr := Arg2 (Args);
      return Arg2 (Args);
   end Prim_Set_Cdr;

   --------------------------------------------------------------------------
   --  Vectors (a K_Vector cell over a heap-allocated element array).
   --------------------------------------------------------------------------
   function Prim_Is_Vector (Args : Ref) return Ref
   is (Make_Bool (Is_Vector (Arg1 (Args))));

   function Prim_Make_Vector (Args : Ref) return Ref is
      N    : constant Long_Long_Integer := Int_Value (Arg1 (Args));
      Fill : Ref := Make_Int (0);
   begin
      if N < 0 then
         raise Lisp_Error with "make-vector: negative length";
      end if;
      if Is_Cons (Cdr (Args)) then
         Fill := Arg2 (Args);
      end if;
      return Make_Vector (Natural (N), Fill);
   end Prim_Make_Vector;

   function Prim_Vector (Args : Ref) return Ref is
      N : Natural := 0;
      P : Ref := Args;
   begin
      while Is_Cons (P) loop
         N := N + 1;
         P := Cdr (P);
      end loop;
      declare
         V : constant Ref := Make_Vector (N, Nil);
         I : Natural := 0;
      begin
         P := Args;
         while Is_Cons (P) loop
            Vector_Set (V, I, Car (P));
            I := I + 1;
            P := Cdr (P);
         end loop;
         return V;
      end;
   end Prim_Vector;

   function Prim_List_To_Vector (Args : Ref) return Ref
   is (Prim_Vector (Arg1 (Args)));

   function Prim_Vector_Ref (Args : Ref) return Ref is
      I : constant Long_Long_Integer := Int_Value (Arg2 (Args));
   begin
      if I < 0 then
         raise Lisp_Error with "vector-ref: negative index";
      end if;
      return Vector_Ref (Arg1 (Args), Natural (I));
   end Prim_Vector_Ref;

   function Prim_Vector_Set (Args : Ref) return Ref is
      V : constant Ref := Arg1 (Args);
      I : constant Long_Long_Integer := Int_Value (Arg2 (Args));
   begin
      if I < 0 then
         raise Lisp_Error with "vector-set!: negative index";
      end if;
      Vector_Set (V, Natural (I), Car (Cdr (Cdr (Args))));
      return V;
   end Prim_Vector_Set;

   function Prim_Vector_Length (Args : Ref) return Ref
   is (Make_Int (Long_Long_Integer (Vector_Length (Arg1 (Args)))));

   function Prim_Vector_To_List (Args : Ref) return Ref is
      V      : constant Ref := Arg1 (Args);
      N      : constant Natural := Vector_Length (V);
      Result : Ref := Nil;
   begin
      for K in 1 .. N loop
         Result := Cons (Vector_Ref (V, N - K), Result);   --  N-K: N-1 down to 0
      end loop;
      return Result;
   end Prim_Vector_To_List;

   function Prim_Vector_Fill (Args : Ref) return Ref is
      V : constant Ref := Arg1 (Args);
      X : constant Ref := Arg2 (Args);
      N : constant Natural := Vector_Length (V);
   begin
      for K in 1 .. N loop
         Vector_Set (V, K - 1, X);
      end loop;
      return V;
   end Prim_Vector_Fill;

   --------------------------------------------------------------------------
   --  Hash tables: a bucket vector of (key . value) alists, keyed by equal?.
   --------------------------------------------------------------------------
   Hash_Prime : constant := 1_000_003;

   --  A hash consistent with equal? (equal keys hash the same); structural for
   --  pairs/vectors, bounded in depth so a cyclic key cannot loop.
   function Hash_Value (O : Ref; Depth : Natural := 0) return Natural is
   begin
      if O = null or else Depth > 6 then
         return 0;
      end if;
      case O.K is
         when K_Nil    =>
            return 17;

         when K_Bool   =>
            return (if O.B then 1 else 2);

         when K_Int    =>
            return Natural (O.I mod Hash_Prime);

         when K_Char   =>
            return Character'Pos (O.Ch);

         when K_Symbol =>
            return Natural (O.Sym) mod Hash_Prime;

         when K_Float  =>
            return
              (if abs O.F < 1.0e9
               then Natural (Long_Long_Integer (Float'Truncation (abs O.F)) mod Hash_Prime)
               else 3);

         when K_String =>
            declare
               H : Long_Long_Integer := 0;
            begin
               for C of Str_Value (O) loop
                  H := (H * 31 + Character'Pos (C)) mod Hash_Prime;
               end loop;
               return Natural (H);
            end;

         when K_Cons   =>
            return
              (Hash_Value (O.Car, Depth + 1) * 31 + Hash_Value (O.Cdr, Depth + 1) + 7)
              mod Hash_Prime;

         when K_Vector =>
            declare
               H : Natural := (if O.Vec = null then 0 else O.Vec'Length);
            begin
               if O.Vec /= null and then O.Vec'Length > 0 then
                  H := (H * 31 + Hash_Value (O.Vec (O.Vec'First), Depth + 1)) mod Hash_Prime;
               end if;
               return H;
            end;

         when others   =>
            return 5;   --  Prim / Closure / Hash: matched by identity only
      end case;
   end Hash_Value;

   function Bucket_Index (H, Key : Ref) return Natural is
      B : constant Natural := Vector_Length (Hash_Buckets (H));
   begin
      if B = 0 then
         raise Lisp_Error with "hash table has no buckets";
      end if;
      return Hash_Value (Key) mod B;
   end Bucket_Index;

   function Prim_Is_Hash (Args : Ref) return Ref
   is (Make_Bool (Is_Hash (Arg1 (Args))));

   function Prim_Make_Hash (Args : Ref) return Ref is
      Buckets : Natural := 97;
   begin
      if Is_Cons (Args) then
         declare
            N : constant Long_Long_Integer := Int_Value (Arg1 (Args));
         begin
            if N > 0 then
               Buckets := Natural (N);
            end if;
         end;
      end if;
      return Make_Hash (Make_Vector (Buckets, Nil));
   end Prim_Make_Hash;

   function Prim_Hash_Set (Args : Ref) return Ref is
      H      : constant Ref := Arg1 (Args);
      Key    : constant Ref := Arg2 (Args);
      Val    : constant Ref := Car (Cdr (Cdr (Args)));
      BV     : constant Ref := Hash_Buckets (H);
      Idx    : constant Natural := Bucket_Index (H, Key);
      Bucket : constant Ref := Vector_Ref (BV, Idx);
      Cursor : Ref := Bucket;
   begin
      while Is_Cons (Cursor) loop
         if Equal (Car (Car (Cursor)), Key) then
            Car (Cursor).Cdr := Val;                          --  update existing entry
            return H;
         end if;
         Cursor := Cdr (Cursor);
      end loop;
      Vector_Set (BV, Idx, Cons (Cons (Key, Val), Bucket));   --  prepend a new entry
      return H;
   end Prim_Hash_Set;

   function Prim_Hash_Ref (Args : Ref) return Ref is
      H      : constant Ref := Arg1 (Args);
      Key    : constant Ref := Arg2 (Args);
      Cursor : Ref := Vector_Ref (Hash_Buckets (H), Bucket_Index (H, Key));
   begin
      while Is_Cons (Cursor) loop
         if Equal (Car (Car (Cursor)), Key) then
            return Cdr (Car (Cursor));
         end if;
         Cursor := Cdr (Cursor);
      end loop;
      if Is_Cons (Cdr (Cdr (Args))) then
         --  optional default
         return Car (Cdr (Cdr (Args)));
      else
         return Lisp_False;
      end if;
   end Prim_Hash_Ref;

   function Prim_Hash_Remove (Args : Ref) return Ref is
      H      : constant Ref := Arg1 (Args);
      Key    : constant Ref := Arg2 (Args);
      BV     : constant Ref := Hash_Buckets (H);
      Idx    : constant Natural := Bucket_Index (H, Key);
      Prev   : Ref := Nil;
      Cursor : Ref := Vector_Ref (BV, Idx);
   begin
      while Is_Cons (Cursor) loop
         if Equal (Car (Car (Cursor)), Key) then
            if Is_Nil (Prev) then
               Vector_Set (BV, Idx, Cdr (Cursor));            --  remove the head entry

            else
               Prev.Cdr := Cdr (Cursor);                      --  splice it out
            end if;
            return H;
         end if;
         Prev := Cursor;
         Cursor := Cdr (Cursor);
      end loop;
      return H;
   end Prim_Hash_Remove;

   function Prim_Hash_Count (Args : Ref) return Ref is
      BV    : constant Ref := Hash_Buckets (Arg1 (Args));
      Total : Long_Long_Integer := 0;
   begin
      for K in 1 .. Vector_Length (BV) loop
         declare
            Cursor : Ref := Vector_Ref (BV, K - 1);
         begin
            while Is_Cons (Cursor) loop
               Total := Total + 1;
               Cursor := Cdr (Cursor);
            end loop;
         end;
      end loop;
      return Make_Int (Total);
   end Prim_Hash_Count;

   function Prim_Hash_Keys (Args : Ref) return Ref is
      BV     : constant Ref := Hash_Buckets (Arg1 (Args));
      Result : Ref := Nil;
   begin
      for K in 1 .. Vector_Length (BV) loop
         declare
            Cursor : Ref := Vector_Ref (BV, K - 1);
         begin
            while Is_Cons (Cursor) loop
               Result := Cons (Car (Car (Cursor)), Result);
               Cursor := Cdr (Cursor);
            end loop;
         end;
      end loop;
      return Result;
   end Prim_Hash_Keys;

   function Prim_Hash_Values (Args : Ref) return Ref is
      BV     : constant Ref := Hash_Buckets (Arg1 (Args));
      Result : Ref := Nil;
   begin
      for K in 1 .. Vector_Length (BV) loop
         declare
            Cursor : Ref := Vector_Ref (BV, K - 1);
         begin
            while Is_Cons (Cursor) loop
               Result := Cons (Cdr (Car (Cursor)), Result);
               Cursor := Cdr (Cursor);
            end loop;
         end;
      end loop;
      return Result;
   end Prim_Hash_Values;

   --------------------------------------------------------------------------
   --  Text output.  display renders human-readable (strings unquoted), write
   --  machine-readable (strings quoted); both return the unspecified value so the
   --  REPL's result echo stays clean.  newline emits CR/LF (the terminal wants it).
   --------------------------------------------------------------------------
   function Prim_Display (Args : Ref) return Ref is
   begin
      Emit (Display_Str (Arg1 (Args)));
      return Unspecified;
   end Prim_Display;

   function Prim_Write (Args : Ref) return Ref is
   begin
      Emit (Print (Arg1 (Args)));
      return Unspecified;
   end Prim_Write;

   function Prim_Newline (Args : Ref) return Ref is
      pragma Unreferenced (Args);
   begin
      Emit (ASCII.CR & ASCII.LF);
      return Unspecified;
   end Prim_Newline;

   function Prim_Write_Char (Args : Ref) return Ref is
   begin
      Emit ((1 => Char_Value (Arg1 (Args))));
      return Unspecified;
   end Prim_Write_Char;

   function Prim_Write_String (Args : Ref) return Ref is
   begin
      Emit (Str_Value (Arg1 (Args)));
      return Unspecified;
   end Prim_Write_String;

   --------------------------------------------------------------------------
   --  Input: read / read-char / peek-char / read-line over string or terminal
   --  ports.  read reuses Lisp.Reader over the port's buffer, refilling the
   --  terminal port a line at a time until a datum is complete.
   --------------------------------------------------------------------------
   function Port_Of (Args : Ref) return Ref is
   begin
      if Is_Cons (Args) then
         if not Is_Port (Arg1 (Args)) then
            raise Lisp_Error with "expected an input port";
         end if;
         return Arg1 (Args);
      else
         return Current_Input;
      end if;
   end Port_Of;

   --  True when text is not obviously incomplete (so a parse failure is a real
   --  syntax error, not "type more"): all parens closed and no open string.
   function Complete_Enough (S : String) return Boolean is
      Depth  : Integer := 0;
      In_Str : Boolean := False;
      I      : Natural := S'First;
   begin
      while I <= S'Last loop
         declare
            C : constant Character := S (I);
         begin
            if In_Str then
               if C = '\' and then I < S'Last then
                  I := I + 1;
               elsif C = '"' then
                  In_Str := False;
               end if;
            else
               case C is
                  when '"'    =>
                     In_Str := True;

                  when '('    =>
                     Depth := Depth + 1;

                  when ')'    =>
                     Depth := Depth - 1;

                  when ';'    =>
                     while I < S'Last and then S (I + 1) /= ASCII.LF loop
                        I := I + 1;
                     end loop;

                  when others =>
                     null;
               end case;
            end if;
         end;
         I := I + 1;
      end loop;
      return Depth <= 0 and then not In_Str;
   end Complete_Enough;

   function Prim_Read_Char (Args : Ref) return Ref is
      C : constant Integer := Port_Get (Port_Of (Args));
   begin
      return (if C < 0 then Eof_Object else Make_Char (Character'Val (C)));
   end Prim_Read_Char;

   function Prim_Peek_Char (Args : Ref) return Ref is
      C : constant Integer := Port_Peek (Port_Of (Args));
   begin
      return (if C < 0 then Eof_Object else Make_Char (Character'Val (C)));
   end Prim_Peek_Char;

   function Prim_Read_Line (Args : Ref) return Ref is
      P   : constant Ref := Port_Of (Args);
      Buf : String (1 .. 2048);
      N   : Natural := 0;
      C   : Integer := Port_Get (P);
   begin
      if C < 0 then
         return Eof_Object;                        --  end of input, no line

      end if;
      while C >= 0 and then Character'Val (C) /= ASCII.LF and then Character'Val (C) /= ASCII.CR
      loop
         if N < Buf'Last then
            N := N + 1;
            Buf (N) := Character'Val (C);
         end if;
         C := Port_Get (P);
      end loop;
      return Make_String (Buf (1 .. N));
   end Prim_Read_Line;

   function Prim_Read (Args : Ref) return Ref is
      P : constant Ref := Port_Of (Args);
   begin
      loop
         declare
            Content : constant String := Port_Buffer (P);
            Pos0    : constant Natural := Port_Position (P);
         begin
            if Pos0 >= Content'Length then
               if not Port_Refill (P) then
                  return Eof_Object;
               end if;
            else
               declare
                  RPos : Natural := Content'First + Pos0;
               begin
                  declare
                     D : constant Ref := Lisp.Reader.Read (Content, RPos);
                  begin
                     if D /= null then
                        Port_Advance (P, RPos - Content'First);
                        return D;
                     else
                        Port_Advance (P, Content'Length);   --  only whitespace
                        if not Port_Refill (P) then
                           return Eof_Object;
                        end if;
                     end if;
                  end;
               exception
                  when Lisp_Error =>
                     if Complete_Enough (Content (Content'First + Pos0 .. Content'Last))
                       or else not Port_Refill (P)
                     then
                        raise;                       --  real syntax error, or EOF mid-form

                     end if;
                     --  otherwise: incomplete but we got more input -- loop and retry
               end;
            end if;
         end;
      end loop;
   end Prim_Read;

   function Prim_Open_Input_String (Args : Ref) return Ref is
   begin
      if not Is_String (Arg1 (Args)) then
         raise Lisp_Error with "open-input-string: expected a string";
      end if;
      return Make_String_Port (Arg1 (Args));
   end Prim_Open_Input_String;

   function Prim_Read_From_String (Args : Ref) return Ref
   is (Prim_Read (Cons (Prim_Open_Input_String (Args), Nil)));

   function Prim_Eof_Object (Args : Ref) return Ref is
      pragma Unreferenced (Args);
   begin
      return Eof_Object;
   end Prim_Eof_Object;

   function Prim_Current_Input (Args : Ref) return Ref is
      pragma Unreferenced (Args);
   begin
      return Current_Input;
   end Prim_Current_Input;

   function Prim_Is_Eof (Args : Ref) return Ref
   is (Make_Bool (Is_Eof (Arg1 (Args))));
   function Prim_Is_Port (Args : Ref) return Ref
   is (Make_Bool (Is_Port (Arg1 (Args))));

   --------------------------------------------------------------------------
   --  eval, iteration, errors.
   --------------------------------------------------------------------------
   function Prim_Eval (Args : Ref) return Ref
   is (Eval (Arg1 (Args), G_Env));   --  evaluate the datum in the global environment

   function Prim_For_Each (Args : Ref) return Ref is
      Fn    : constant Ref := Arg1 (Args);
      Lists : Ref := Cdr (Args);
   begin
      while All_Cons (Lists) loop
         declare
            Ignored : constant Ref := Apply (Fn, List_Cars (Lists));
            pragma Unreferenced (Ignored);
         begin
            null;
         end;
         Lists := List_Cdrs (Lists);
      end loop;
      return Unspecified;
   end Prim_For_Each;

   function Prim_Error (Args : Ref) return Ref is
      function Join (A : Ref) return String
      is (if Is_Nil (A)
          then ""
          elsif Is_Nil (Cdr (A))
          then Display_Str (Car (A))
          else Display_Str (Car (A)) & " " & Join (Cdr (A)));
   begin
      raise Lisp_Error with Join (Args);
      return Unspecified;   --  unreachable
   end Prim_Error;

   --------------------------------------------------------------------------
   --  Numeric: min/max, sign tests, and the FPU transcendentals / rounding.
   --------------------------------------------------------------------------
   function Prim_Min (Args : Ref) return Ref is
      Best   : Ref := Arg1 (Args);
      Cursor : Ref := Cdr (Args);
   begin
      while Is_Cons (Cursor) loop
         if As_Float (Car (Cursor)) < As_Float (Best) then
            Best := Car (Cursor);
         end if;
         Cursor := Cdr (Cursor);
      end loop;
      return Best;
   end Prim_Min;

   function Prim_Max (Args : Ref) return Ref is
      Best   : Ref := Arg1 (Args);
      Cursor : Ref := Cdr (Args);
   begin
      while Is_Cons (Cursor) loop
         if As_Float (Car (Cursor)) > As_Float (Best) then
            Best := Car (Cursor);
         end if;
         Cursor := Cdr (Cursor);
      end loop;
      return Best;
   end Prim_Max;

   function Prim_Positive (Args : Ref) return Ref
   is (Make_Bool (As_Float (Arg1 (Args)) > 0.0));
   function Prim_Negative (Args : Ref) return Ref
   is (Make_Bool (As_Float (Arg1 (Args)) < 0.0));
   function Prim_Is_Boolean (Args : Ref) return Ref
   is (Make_Bool (Arg1 (Args) /= null and then Arg1 (Args).K = K_Bool));

   function Prim_Sqrt (Args : Ref) return Ref
   is (Make_Float (EF.Sqrt (As_Float (Arg1 (Args)))));
   function Prim_Sin (Args : Ref) return Ref
   is (Make_Float (EF.Sin (As_Float (Arg1 (Args)))));
   function Prim_Cos (Args : Ref) return Ref
   is (Make_Float (EF.Cos (As_Float (Arg1 (Args)))));
   function Prim_Tan (Args : Ref) return Ref
   is (Make_Float (EF.Tan (As_Float (Arg1 (Args)))));
   function Prim_Exp (Args : Ref) return Ref
   is (Make_Float (EF.Exp (As_Float (Arg1 (Args)))));
   function Prim_Log (Args : Ref) return Ref
   is (Make_Float (EF.Log (As_Float (Arg1 (Args)))));

   --  floor / ceiling / round / truncate: leave an integer alone, round a float.
   function Prim_Floor (Args : Ref) return Ref is
      O : constant Ref := Arg1 (Args);
   begin
      return (if Is_Float (O) then Make_Float (Float'Floor (Float_Value (O))) else O);
   end Prim_Floor;
   function Prim_Ceiling (Args : Ref) return Ref is
      O : constant Ref := Arg1 (Args);
   begin
      return (if Is_Float (O) then Make_Float (Float'Ceiling (Float_Value (O))) else O);
   end Prim_Ceiling;
   function Prim_Round (Args : Ref) return Ref is
      O : constant Ref := Arg1 (Args);
   begin
      return (if Is_Float (O) then Make_Float (Float'Rounding (Float_Value (O))) else O);
   end Prim_Round;
   function Prim_Truncate (Args : Ref) return Ref is
      O : constant Ref := Arg1 (Args);
   begin
      return (if Is_Float (O) then Make_Float (Float'Truncation (Float_Value (O))) else O);
   end Prim_Truncate;

   --------------------------------------------------------------------------
   --  Bitwise (on the 64-bit integer, two's complement).
   --------------------------------------------------------------------------
   function Prim_Bit_And (Args : Ref) return Ref is
      Acc    : Interfaces.Unsigned_64 := Interfaces.Unsigned_64'Last;   --  all ones
      Cursor : Ref := Args;
   begin
      while Is_Cons (Cursor) loop
         Acc := Acc and To_U64 (Int_Value (Car (Cursor)));
         Cursor := Cdr (Cursor);
      end loop;
      return Make_Int (To_I64 (Acc));
   end Prim_Bit_And;

   function Prim_Bit_Or (Args : Ref) return Ref is
      Acc    : Interfaces.Unsigned_64 := 0;
      Cursor : Ref := Args;
   begin
      while Is_Cons (Cursor) loop
         Acc := Acc or To_U64 (Int_Value (Car (Cursor)));
         Cursor := Cdr (Cursor);
      end loop;
      return Make_Int (To_I64 (Acc));
   end Prim_Bit_Or;

   function Prim_Bit_Xor (Args : Ref) return Ref is
      Acc    : Interfaces.Unsigned_64 := 0;
      Cursor : Ref := Args;
   begin
      while Is_Cons (Cursor) loop
         Acc := Acc xor To_U64 (Int_Value (Car (Cursor)));
         Cursor := Cdr (Cursor);
      end loop;
      return Make_Int (To_I64 (Acc));
   end Prim_Bit_Xor;

   function Prim_Bit_Not (Args : Ref) return Ref
   is (Make_Int (To_I64 (not To_U64 (Int_Value (Arg1 (Args))))));

   function Prim_Ash (Args : Ref) return Ref is
      N : constant Interfaces.Unsigned_64 := To_U64 (Int_Value (Arg1 (Args)));
      C : constant Long_Long_Integer := Int_Value (Arg2 (Args));
   begin
      if C >= 0 then
         return Make_Int (To_I64 (Interfaces.Shift_Left (N, Natural (C))));
      else
         return Make_Int (To_I64 (Interfaces.Shift_Right_Arithmetic (N, Natural (-C))));
      end if;
   end Prim_Ash;

   --------------------------------------------------------------------------
   --  Characters.
   --------------------------------------------------------------------------
   function Prim_Char_Eq (Args : Ref) return Ref
   is (Make_Bool (Char_Value (Arg1 (Args)) = Char_Value (Arg2 (Args))));
   function Prim_Char_Lt (Args : Ref) return Ref
   is (Make_Bool (Char_Value (Arg1 (Args)) < Char_Value (Arg2 (Args))));

   function Up (C : Character) return Character
   is (if C in 'a' .. 'z' then Character'Val (Character'Pos (C) - 32) else C);
   function Down (C : Character) return Character
   is (if C in 'A' .. 'Z' then Character'Val (Character'Pos (C) + 32) else C);

   function Prim_Char_Upcase (Args : Ref) return Ref
   is (Make_Char (Up (Char_Value (Arg1 (Args)))));
   function Prim_Char_Downcase (Args : Ref) return Ref
   is (Make_Char (Down (Char_Value (Arg1 (Args)))));
   function Prim_Char_Alpha (Args : Ref) return Ref
   is (Make_Bool (Char_Value (Arg1 (Args)) in 'a' .. 'z' | 'A' .. 'Z'));
   function Prim_Char_Num (Args : Ref) return Ref
   is (Make_Bool (Char_Value (Arg1 (Args)) in '0' .. '9'));
   function Prim_Char_Space (Args : Ref) return Ref
   is (Make_Bool (Char_Value (Arg1 (Args)) in ' ' | ASCII.HT | ASCII.LF | ASCII.CR));

   --------------------------------------------------------------------------
   --  Strings.
   --------------------------------------------------------------------------
   function Prim_Str_Lt (Args : Ref) return Ref
   is (Make_Bool (Str_Value (Arg1 (Args)) < Str_Value (Arg2 (Args))));

   function Prim_Str_Upcase (Args : Ref) return Ref is
      S : String := Str_Value (Arg1 (Args));
   begin
      for I in S'Range loop
         S (I) := Up (S (I));
      end loop;
      return Make_String (S);
   end Prim_Str_Upcase;

   function Prim_Str_Downcase (Args : Ref) return Ref is
      S : String := Str_Value (Arg1 (Args));
   begin
      for I in S'Range loop
         S (I) := Down (S (I));
      end loop;
      return Make_String (S);
   end Prim_Str_Downcase;

   function Prim_Make_String (Args : Ref) return Ref is
      N  : constant Long_Long_Integer := Int_Value (Arg1 (Args));
      Ch : constant Character := (if Is_Cons (Cdr (Args)) then Char_Value (Arg2 (Args)) else ' ');
   begin
      if N < 0 then
         raise Lisp_Error with "make-string: negative length";
      end if;
      return Make_String (String'(1 .. Natural (N) => Ch));
   end Prim_Make_String;

   function Prim_String (Args : Ref) return Ref is
      N : Natural := 0;
      P : Ref := Args;
   begin
      while Is_Cons (P) loop
         N := N + 1;
         P := Cdr (P);
      end loop;
      return R : Ref do
         declare
            Buf : String (1 .. N);
            I   : Natural := 0;
         begin
            P := Args;
            while Is_Cons (P) loop
               I := I + 1;
               Buf (I) := Char_Value (Car (P));
               P := Cdr (P);
            end loop;
            R := Make_String (Buf);
         end;
      end return;
   end Prim_String;

   function Prim_Str_To_Sym (Args : Ref) return Ref
   is (Intern (Str_Value (Arg1 (Args))));
   function Prim_Sym_To_Str (Args : Ref) return Ref
   is (Make_String (Symbol_Name (Arg1 (Args))));

   function Prim_Str_To_Num (Args : Ref) return Ref is
      D : Ref;
   begin
      begin
         D := Lisp.Reader.Read (Str_Value (Arg1 (Args)));
      exception
         when others =>
            return Lisp_False;
      end;
      if D /= null and then (D.K = K_Int or else D.K = K_Float) then
         return D;
      else
         return Lisp_False;
      end if;
   end Prim_Str_To_Num;

   --------------------------------------------------------------------------
   --  eqv? and the eq-keyed list searches; extra c[ad]r accessors; list-copy.
   --------------------------------------------------------------------------
   function Eqv (A, B : Ref) return Boolean is
   begin
      if A = B then
         return True;
      elsif A = null or else B = null or else A.K /= B.K then
         return False;
      end if;
      case A.K is
         when K_Int   =>
            return A.I = B.I;

         when K_Float =>
            return A.F = B.F;

         when K_Char  =>
            return A.Ch = B.Ch;

         when K_Bool  =>
            return A.B = B.B;

         when others  =>
            return False;
      end case;
   end Eqv;

   function Prim_Eqv (Args : Ref) return Ref
   is (Make_Bool (Eqv (Arg1 (Args), Arg2 (Args))));

   function Prim_Memq (Args : Ref) return Ref is
      X      : constant Ref := Arg1 (Args);
      Cursor : Ref := Arg2 (Args);
   begin
      while Is_Cons (Cursor) loop
         if Eqv (Car (Cursor), X) then
            return Cursor;
         end if;
         Cursor := Cdr (Cursor);
      end loop;
      return Lisp_False;
   end Prim_Memq;

   function Prim_Assq (Args : Ref) return Ref is
      Key    : constant Ref := Arg1 (Args);
      Cursor : Ref := Arg2 (Args);
   begin
      while Is_Cons (Cursor) loop
         if Is_Cons (Car (Cursor)) and then Eqv (Car (Car (Cursor)), Key) then
            return Car (Cursor);
         end if;
         Cursor := Cdr (Cursor);
      end loop;
      return Lisp_False;
   end Prim_Assq;

   function Prim_Caar (Args : Ref) return Ref
   is (Car (Car (Arg1 (Args))));
   function Prim_Cdar (Args : Ref) return Ref
   is (Cdr (Car (Arg1 (Args))));
   function Prim_Cddr (Args : Ref) return Ref
   is (Cdr (Cdr (Arg1 (Args))));
   function Prim_Cdddr (Args : Ref) return Ref
   is (Cdr (Cdr (Cdr (Arg1 (Args)))));
   function Prim_Cadddr (Args : Ref) return Ref
   is (Car (Cdr (Cdr (Cdr (Arg1 (Args))))));

   function Prim_List_Copy (Args : Ref) return Ref is
      function Copy (L : Ref) return Ref
      is (if Is_Cons (L) then Cons (Car (L), Copy (Cdr (L))) else L);
   begin
      return Copy (Arg1 (Args));
   end Prim_List_Copy;

   --------------------------------------------------------------------------
   --  Vector map / for-each.
   --------------------------------------------------------------------------
   function Prim_Vector_Map (Args : Ref) return Ref is
      Fn : constant Ref := Arg1 (Args);
      V  : constant Ref := Arg2 (Args);
      N  : constant Natural := Vector_Length (V);
      R  : constant Ref := Make_Vector (N, Nil);
   begin
      for K in 1 .. N loop
         Vector_Set (R, K - 1, Apply (Fn, Cons (Vector_Ref (V, K - 1), Nil)));
      end loop;
      return R;
   end Prim_Vector_Map;

   function Prim_Vector_For_Each (Args : Ref) return Ref is
      Fn : constant Ref := Arg1 (Args);
      V  : constant Ref := Arg2 (Args);
   begin
      for K in 1 .. Vector_Length (V) loop
         declare
            Ignored : constant Ref := Apply (Fn, Cons (Vector_Ref (V, K - 1), Nil));
            pragma Unreferenced (Ignored);
         begin
            null;
         end;
      end loop;
      return Unspecified;
   end Prim_Vector_For_Each;

   --------------------------------------------------------------------------
   --  Special forms
   --------------------------------------------------------------------------
   function Eval_Define (Args, Env : Ref) return Ref is
      Target : constant Ref := Car (Args);
   begin
      if Is_Symbol (Target) then
         Define (Target, Eval (Arg2 (Args), Env), Env);
         return Target;
      elsif Is_Cons (Target) then
         --  (define (f a b) body...)
         Define (Car (Target), Make_Closure (Cdr (Target), Cdr (Args), Env), Env);
         return Car (Target);
      else
         raise Lisp_Error with "malformed define";
      end if;
   end Eval_Define;

   function Eval_Let (Args, Env : Ref) return Ref is
   begin
      --  Named let: (let name ((v e) ...) body ...) -- a self-recursive procedure.
      if Is_Symbol (Car (Args)) then
         declare
            Name       : constant Ref := Car (Args);
            Bindings   : constant Ref := Arg2 (Args);
            Body_Forms : constant Ref := Cdr (Cdr (Args));
            Loop_Env   : constant Ref := Cons (Nil, Env);
            function Vars (B : Ref) return Ref
            is (if Is_Cons (B) then Cons (Car (Car (B)), Vars (Cdr (B))) else Nil);
            function Inits (B : Ref) return Ref
            is (if Is_Cons (B) then Cons (Eval (Arg2 (Car (B)), Env), Inits (Cdr (B))) else Nil);
            Proc       : constant Ref := Make_Closure (Vars (Bindings), Body_Forms, Loop_Env);
         begin
            Define (Name, Proc, Loop_Env);
            return Apply (Proc, Inits (Bindings));
         end;
      end if;
      declare
         New_Env : constant Ref := Cons (Nil, Env);
         Cursor  : Ref := Car (Args);              --  the binding list
      begin
         while Is_Cons (Cursor) loop
            declare
               Binding : constant Ref := Car (Cursor);   --  (var expr)
            begin
               Define (Car (Binding), Eval (Arg2 (Binding), Env), New_Env);   --  expr in outer env
            end;
            Cursor := Cdr (Cursor);
         end loop;
         return Eval_Seq (Cdr (Args), New_Env);
      end;
   end Eval_Let;

   --  let*: each binding's expression sees the ones before it (one growing frame).
   function Eval_Let_Star (Args, Env : Ref) return Ref is
      New_Env : constant Ref := Cons (Nil, Env);
      Cursor  : Ref := Car (Args);
   begin
      while Is_Cons (Cursor) loop
         declare
            Binding : constant Ref := Car (Cursor);
         begin
            Define (Car (Binding), Eval (Arg2 (Binding), New_Env), New_Env);
         end;
         Cursor := Cdr (Cursor);
      end loop;
      return Eval_Seq (Cdr (Args), New_Env);
   end Eval_Let_Star;

   --  letrec: all names are in scope for every expression (bind first, assign after).
   function Eval_Letrec (Args, Env : Ref) return Ref is
      New_Env : constant Ref := Cons (Nil, Env);
      Cursor  : Ref;
   begin
      Cursor := Car (Args);
      while Is_Cons (Cursor) loop
         Define (Car (Car (Cursor)), Unspecified, New_Env);
         Cursor := Cdr (Cursor);
      end loop;
      Cursor := Car (Args);
      while Is_Cons (Cursor) loop
         declare
            Binding : constant Ref := Car (Cursor);
         begin
            Set_Var (Car (Binding), Eval (Arg2 (Binding), New_Env), New_Env);
         end;
         Cursor := Cdr (Cursor);
      end loop;
      return Eval_Seq (Cdr (Args), New_Env);
   end Eval_Letrec;

   --  case: eval the key, take the clause whose datum list contains it (eqv?).
   function Eval_Case (Args, Env : Ref) return Ref is
      Key     : constant Ref := Eval (Car (Args), Env);
      Clauses : Ref := Cdr (Args);
   begin
      while Is_Cons (Clauses) loop
         declare
            Clause : constant Ref := Car (Clauses);
            Datums : constant Ref := Car (Clause);
            D      : Ref := Datums;
         begin
            if Datums = S_Else then
               return Eval_Seq (Cdr (Clause), Env);
            end if;
            while Is_Cons (D) loop
               if Eqv (Car (D), Key) then
                  return Eval_Seq (Cdr (Clause), Env);
               end if;
               D := Cdr (D);
            end loop;
         end;
         Clauses := Cdr (Clauses);
      end loop;
      return Unspecified;
   end Eval_Case;

   --  do: (do ((var init step) ...) (test result ...) command ...).  Steps are
   --  computed in parallel (all in the current env) before rebinding.
   function Eval_Do (Args, Env : Ref) return Ref is
      Specs       : constant Ref := Car (Args);
      Test_Clause : constant Ref := Arg2 (Args);
      Commands    : constant Ref := Cdr (Cdr (Args));
      Loop_Env    : constant Ref := Cons (Nil, Env);
      S           : Ref;
   begin
      S := Specs;
      while Is_Cons (S) loop
         Define (Car (Car (S)), Eval (Arg2 (Car (S)), Env), Loop_Env);
         S := Cdr (S);
      end loop;
      loop
         if Is_Truthy (Eval (Car (Test_Clause), Loop_Env)) then
            return Eval_Seq (Cdr (Test_Clause), Loop_Env);
         end if;
         declare
            C : Ref := Commands;
         begin
            while Is_Cons (C) loop
               declare
                  Ig : constant Ref := Eval (Car (C), Loop_Env);
                  pragma Unreferenced (Ig);
               begin
                  null;
               end;
               C := Cdr (C);
            end loop;
         end;
         declare
            New_Vals : Ref := Nil;   --  (var . value) pairs, computed before rebinding
         begin
            S := Specs;
            while Is_Cons (S) loop
               declare
                  Step : constant Ref := Cdr (Cdr (Car (S)));
               begin
                  if Is_Cons (Step) then
                     New_Vals :=
                       Cons (Cons (Car (Car (S)), Eval (Car (Step), Loop_Env)), New_Vals);
                  end if;
               end;
               S := Cdr (S);
            end loop;
            while Is_Cons (New_Vals) loop
               Set_Var (Car (Car (New_Vals)), Cdr (Car (New_Vals)), Loop_Env);
               New_Vals := Cdr (New_Vals);
            end loop;
         end;
      end loop;
   end Eval_Do;

   --  quasiquote: copy the template, evaluating unquote (,) and splicing
   --  unquote-splicing (,@); nesting raises/lowers the depth.
   function Eval_Quasi (Template, Env : Ref; Depth : Natural) return Ref is
   begin
      if not Is_Cons (Template) then
         return Template;
      elsif Car (Template) = S_Unquote then
         if Depth = 1 then
            return Eval (Cadr (Template), Env);
         else
            return Cons (S_Unquote, Eval_Quasi (Cdr (Template), Env, Depth - 1));
         end if;
      elsif Car (Template) = S_Quasi then
         return Cons (S_Quasi, Eval_Quasi (Cdr (Template), Env, Depth + 1));
      end if;
      declare
         Head : constant Ref := Car (Template);
      begin
         if Is_Cons (Head) and then Car (Head) = S_Unquote_Splice and then Depth = 1 then
            return Append2 (Eval (Cadr (Head), Env), Eval_Quasi (Cdr (Template), Env, Depth));
         else
            return Cons (Eval_Quasi (Head, Env, Depth), Eval_Quasi (Cdr (Template), Env, Depth));
         end if;
      end;
   end Eval_Quasi;

   function Eval_Cond (Clauses, Env : Ref) return Ref is
      Cursor : Ref := Clauses;
   begin
      while Is_Cons (Cursor) loop
         declare
            Clause : constant Ref := Car (Cursor);
            Test   : constant Ref := Car (Clause);
         begin
            if Test = S_Else then
               return Eval_Seq (Cdr (Clause), Env);
            end if;
            declare
               Test_Value : constant Ref := Eval (Test, Env);
            begin
               if Is_Truthy (Test_Value) then
                  return
                    (if Is_Nil (Cdr (Clause)) then Test_Value else Eval_Seq (Cdr (Clause), Env));
               end if;
            end;
         end;
         Cursor := Cdr (Cursor);
      end loop;
      return Nil;
   end Eval_Cond;

   function Eval_And (Args, Env : Ref) return Ref is
      Result : Ref := Lisp_True;
      Cursor : Ref := Args;
   begin
      while Is_Cons (Cursor) loop
         Result := Eval (Car (Cursor), Env);
         if not Is_Truthy (Result) then
            return Result;
         end if;
         Cursor := Cdr (Cursor);
      end loop;
      return Result;
   end Eval_And;

   function Eval_Or (Args, Env : Ref) return Ref is
      Cursor : Ref := Args;
   begin
      while Is_Cons (Cursor) loop
         declare
            Value : constant Ref := Eval (Car (Cursor), Env);
         begin
            if Is_Truthy (Value) then
               return Value;
            end if;
         end;
         Cursor := Cdr (Cursor);
      end loop;
      return Lisp_False;
   end Eval_Or;

   --------------------------------------------------------------------------
   --  eval / apply
   --------------------------------------------------------------------------
   function Eval_Args (Args, Env : Ref) return Ref is
   begin
      if Is_Nil (Args) then
         return Nil;
      else
         --  Bind the head first so arguments evaluate left to right (Ada leaves the
         --  order of Cons's operands unspecified, which matters once a primitive
         --  such as read or display has side effects).
         declare
            First : constant Ref := Eval (Car (Args), Env);
         begin
            return Cons (First, Eval_Args (Cdr (Args), Env));
         end;
      end if;
   end Eval_Args;

   function Eval_Seq (Body_List, Env : Ref) return Ref is
      Result : Ref := Nil;
      Cursor : Ref := Body_List;
   begin
      while Is_Cons (Cursor) loop
         Result := Eval (Car (Cursor), Env);
         Cursor := Cdr (Cursor);
      end loop;
      return Result;
   end Eval_Seq;

   --  A trampolining evaluator: tail positions (if/begin branches and a closure
   --  call's last body form) update the current (expression, environment) and loop
   --  rather than recursing, so tail-recursive LISP runs in constant Ada stack.
   function Eval (Expr : Ref; Env : Ref) return Ref is
      Cur_Expr : Ref := Expr;
      Cur_Env  : Ref := Env;
   begin
      loop
         if Cur_Expr = null then
            return Nil;
         end if;
         case Cur_Expr.K is
            when K_Int
               | K_Float
               | K_Char
               | K_String
               | K_Vector
               | K_Hash
               | K_Unspec
               | K_Eof
               | K_Port
               | K_Bool
               | K_Nil
               | K_Prim
               | K_Closure =>
               return Cur_Expr;

            when K_Symbol  =>
               return Lookup (Cur_Expr, Cur_Env);

            when K_Cons    =>
               declare
                  Op   : constant Ref := Car (Cur_Expr);
                  Args : constant Ref := Cdr (Cur_Expr);
               begin
                  if Op = S_Quote then
                     return Car (Args);
                  elsif Op = S_Lambda then
                     return Make_Closure (Car (Args), Cdr (Args), Cur_Env);
                  elsif Op = S_Define then
                     return Eval_Define (Args, Cur_Env);
                  elsif Op = S_Let then
                     return Eval_Let (Args, Cur_Env);
                  elsif Op = S_Let_Star then
                     return Eval_Let_Star (Args, Cur_Env);
                  elsif Op = S_Letrec then
                     return Eval_Letrec (Args, Cur_Env);
                  elsif Op = S_Case then
                     return Eval_Case (Args, Cur_Env);
                  elsif Op = S_Do then
                     return Eval_Do (Args, Cur_Env);
                  elsif Op = S_Quasi then
                     return Eval_Quasi (Car (Args), Cur_Env, 1);
                  elsif Op = S_When then
                     if Is_Truthy (Eval (Car (Args), Cur_Env)) then
                        return Eval_Seq (Cdr (Args), Cur_Env);
                     else
                        return Unspecified;
                     end if;
                  elsif Op = S_Unless then
                     if not Is_Truthy (Eval (Car (Args), Cur_Env)) then
                        return Eval_Seq (Cdr (Args), Cur_Env);
                     else
                        return Unspecified;
                     end if;
                  elsif Op = S_Cond then
                     return Eval_Cond (Args, Cur_Env);
                  elsif Op = S_And then
                     return Eval_And (Args, Cur_Env);
                  elsif Op = S_Or then
                     return Eval_Or (Args, Cur_Env);
                  elsif Op = S_Set then
                     declare
                        Value : constant Ref := Eval (Arg2 (Args), Cur_Env);
                     begin
                        Set_Var (Car (Args), Value, Cur_Env);
                        return Value;
                     end;
                  elsif Op = S_If then
                     if Is_Truthy (Eval (Car (Args), Cur_Env)) then
                        Cur_Expr := Arg2 (Args);              --  tail: loop
                     elsif Is_Cons (Cdr (Cdr (Args))) then
                        Cur_Expr := Car (Cdr (Cdr (Args)));   --  tail: loop
                     else
                        return Nil;
                     end if;
                  elsif Op = S_Begin then
                     if Is_Nil (Args) then
                        return Nil;
                     end if;
                     declare
                        Cursor : Ref := Args;
                     begin
                        while Is_Cons (Cdr (Cursor)) loop
                           declare
                              Ignored : constant Ref := Eval (Car (Cursor), Cur_Env);
                              pragma Unreferenced (Ignored);
                           begin
                              null;
                           end;
                           Cursor := Cdr (Cursor);
                        end loop;
                        Cur_Expr := Car (Cursor);             --  tail: loop
                     end;
                  else
                     --  application
                     declare
                        Fn         : constant Ref := Eval (Op, Cur_Env);
                        Arg_Values : constant Ref := Eval_Args (Args, Cur_Env);
                     begin
                        if Fn = null then
                           raise Lisp_Error with "cannot apply nil";
                        end if;
                        case Fn.K is
                           when K_Prim    =>
                              return Fn.Fn (Arg_Values);

                           when K_Closure =>
                              declare
                                 New_Env : constant Ref := Cons (Nil, Fn.Env);
                              begin
                                 Bind_Params (Fn.Params, Arg_Values, New_Env);
                                 if Is_Nil (Fn.Code) then
                                    return Nil;
                                 end if;
                                 declare
                                    Body_Cursor : Ref := Fn.Code;
                                 begin
                                    while Is_Cons (Cdr (Body_Cursor)) loop
                                       declare
                                          Ignored : constant Ref :=
                                            Eval (Car (Body_Cursor), New_Env);
                                          pragma Unreferenced (Ignored);
                                       begin
                                          null;
                                       end;
                                       Body_Cursor := Cdr (Body_Cursor);
                                    end loop;
                                    Cur_Env := New_Env;
                                    Cur_Expr := Car (Body_Cursor);   --  tail call: loop, no growth
                                 end;
                              end;

                           when others    =>
                              raise Lisp_Error with "not applicable: " & Print (Fn);
                        end case;
                     end;
                  end if;
               end;
         end case;
      end loop;
   end Eval;

   --------------------------------------------------------------------------
   --  Build the global environment.
   --------------------------------------------------------------------------
   procedure Reg (Env : Ref; Name : String; Fn : Prim_Fn) is
   begin
      Define (Intern (Name), Make_Prim (Name, Fn), Env);
   end Reg;

   procedure Register_Primitive (Name : String; Fn : Prim_Fn) is
   begin
      Reg (G_Env, Name, Fn);
   end Register_Primitive;

   procedure Init is
   begin
      S_Quote := Intern ("quote");
      S_If := Intern ("if");
      S_Define := Intern ("define");
      S_Lambda := Intern ("lambda");
      S_Let := Intern ("let");
      S_Cond := Intern ("cond");
      S_Begin := Intern ("begin");
      S_Set := Intern ("set!");
      S_And := Intern ("and");
      S_Or := Intern ("or");
      S_Else := Intern ("else");
      S_Let_Star := Intern ("let*");
      S_Letrec := Intern ("letrec");
      S_When := Intern ("when");
      S_Unless := Intern ("unless");
      S_Case := Intern ("case");
      S_Do := Intern ("do");
      S_Quasi := Intern ("quasiquote");
      S_Unquote := Intern ("unquote");
      S_Unquote_Splice := Intern ("unquote-splicing");

      G_Env := Cons (Nil, Nil);
      Reg (G_Env, "+", Prim_Add'Access);
      Reg (G_Env, "-", Prim_Sub'Access);
      Reg (G_Env, "*", Prim_Mul'Access);
      Reg (G_Env, "/", Prim_Div'Access);
      Reg (G_Env, "=", Prim_Num_Eq'Access);
      Reg (G_Env, "<", Prim_Lt'Access);
      Reg (G_Env, ">", Prim_Gt'Access);
      Reg (G_Env, "<=", Prim_Le'Access);
      Reg (G_Env, ">=", Prim_Ge'Access);
      Reg (G_Env, "car", Prim_Car'Access);
      Reg (G_Env, "cdr", Prim_Cdr'Access);
      Reg (G_Env, "cons", Prim_Cons'Access);
      Reg (G_Env, "list", Prim_List'Access);
      Reg (G_Env, "null?", Prim_Null'Access);
      Reg (G_Env, "pair?", Prim_Pair'Access);
      Reg (G_Env, "not", Prim_Not'Access);
      Reg (G_Env, "eq?", Prim_Eq'Access);
      Reg (G_Env, "length", Prim_Length'Access);
      Reg (G_Env, "string?", Prim_Is_String'Access);
      Reg (G_Env, "char?", Prim_Is_Char'Access);
      Reg (G_Env, "string-length", Prim_Str_Len'Access);
      Reg (G_Env, "string-append", Prim_Str_Append'Access);
      Reg (G_Env, "string=?", Prim_Str_Eq'Access);
      Reg (G_Env, "string-ref", Prim_Str_Ref'Access);
      Reg (G_Env, "substring", Prim_Substring'Access);
      Reg (G_Env, "char->integer", Prim_Char_To_Int'Access);
      Reg (G_Env, "integer->char", Prim_Int_To_Char'Access);
      Reg (G_Env, "string->list", Prim_Str_To_List'Access);
      Reg (G_Env, "list->string", Prim_List_To_Str'Access);
      Reg (G_Env, "number->string", Prim_Num_To_Str'Access);
      Reg (G_Env, "equal?", Prim_Equal'Access);
      Reg (G_Env, "apply", Prim_Apply'Access);
      Reg (G_Env, "map", Prim_Map'Access);
      Reg (G_Env, "append", Prim_Append'Access);
      Reg (G_Env, "reverse", Prim_Reverse'Access);
      Reg (G_Env, "assoc", Prim_Assoc'Access);
      Reg (G_Env, "member", Prim_Member'Access);
      Reg (G_Env, "quotient", Prim_Quotient'Access);
      Reg (G_Env, "modulo", Prim_Modulo'Access);
      Reg (G_Env, "abs", Prim_Abs'Access);
      Reg (G_Env, "number?", Prim_Is_Number'Access);
      Reg (G_Env, "zero?", Prim_Is_Zero'Access);
      Reg (G_Env, "symbol?", Prim_Is_Symbol'Access);
      Reg (G_Env, "procedure?", Prim_Is_Procedure'Access);
      Reg (G_Env, "even?", Prim_Is_Even'Access);
      Reg (G_Env, "odd?", Prim_Is_Odd'Access);
      Reg (G_Env, "remainder", Prim_Remainder'Access);
      Reg (G_Env, "cadr", Prim_Cadr'Access);
      Reg (G_Env, "caddr", Prim_Caddr'Access);
      Reg (G_Env, "filter", Prim_Filter'Access);
      Reg (G_Env, "fold-left", Prim_Fold_Left'Access);
      Reg (G_Env, "fold-right", Prim_Fold_Right'Access);
      Reg (G_Env, "list-ref", Prim_List_Ref'Access);
      Reg (G_Env, "list-tail", Prim_List_Tail'Access);
      Reg (G_Env, "gcd", Prim_Gcd'Access);
      Reg (G_Env, "lcm", Prim_Lcm'Access);
      Reg (G_Env, "expt", Prim_Expt'Access);
      Reg (G_Env, "sort", Prim_Sort'Access);
      Reg (G_Env, "set-car!", Prim_Set_Car'Access);
      Reg (G_Env, "set-cdr!", Prim_Set_Cdr'Access);
      Reg (G_Env, "vector?", Prim_Is_Vector'Access);
      Reg (G_Env, "make-vector", Prim_Make_Vector'Access);
      Reg (G_Env, "vector", Prim_Vector'Access);
      Reg (G_Env, "vector-ref", Prim_Vector_Ref'Access);
      Reg (G_Env, "vector-set!", Prim_Vector_Set'Access);
      Reg (G_Env, "vector-length", Prim_Vector_Length'Access);
      Reg (G_Env, "vector->list", Prim_Vector_To_List'Access);
      Reg (G_Env, "list->vector", Prim_List_To_Vector'Access);
      Reg (G_Env, "vector-fill!", Prim_Vector_Fill'Access);
      Reg (G_Env, "hash-table?", Prim_Is_Hash'Access);
      Reg (G_Env, "make-hash-table", Prim_Make_Hash'Access);
      Reg (G_Env, "hash-set!", Prim_Hash_Set'Access);
      Reg (G_Env, "hash-ref", Prim_Hash_Ref'Access);
      Reg (G_Env, "hash-remove!", Prim_Hash_Remove'Access);
      Reg (G_Env, "hash-table-count", Prim_Hash_Count'Access);
      Reg (G_Env, "hash-table-keys", Prim_Hash_Keys'Access);
      Reg (G_Env, "hash-table-values", Prim_Hash_Values'Access);
      Reg (G_Env, "display", Prim_Display'Access);
      Reg (G_Env, "write", Prim_Write'Access);
      Reg (G_Env, "newline", Prim_Newline'Access);
      Reg (G_Env, "write-char", Prim_Write_Char'Access);
      Reg (G_Env, "write-string", Prim_Write_String'Access);
      Reg (G_Env, "read", Prim_Read'Access);
      Reg (G_Env, "read-char", Prim_Read_Char'Access);
      Reg (G_Env, "peek-char", Prim_Peek_Char'Access);
      Reg (G_Env, "read-line", Prim_Read_Line'Access);
      Reg (G_Env, "read-from-string", Prim_Read_From_String'Access);
      Reg (G_Env, "open-input-string", Prim_Open_Input_String'Access);
      Reg (G_Env, "current-input-port", Prim_Current_Input'Access);
      Reg (G_Env, "eof-object", Prim_Eof_Object'Access);
      Reg (G_Env, "eof-object?", Prim_Is_Eof'Access);
      Reg (G_Env, "input-port?", Prim_Is_Port'Access);
      Reg (G_Env, "eval", Prim_Eval'Access);
      Reg (G_Env, "for-each", Prim_For_Each'Access);
      Reg (G_Env, "error", Prim_Error'Access);
      Reg (G_Env, "min", Prim_Min'Access);
      Reg (G_Env, "max", Prim_Max'Access);
      Reg (G_Env, "positive?", Prim_Positive'Access);
      Reg (G_Env, "negative?", Prim_Negative'Access);
      Reg (G_Env, "boolean?", Prim_Is_Boolean'Access);
      Reg (G_Env, "eqv?", Prim_Eqv'Access);
      Reg (G_Env, "sqrt", Prim_Sqrt'Access);
      Reg (G_Env, "sin", Prim_Sin'Access);
      Reg (G_Env, "cos", Prim_Cos'Access);
      Reg (G_Env, "tan", Prim_Tan'Access);
      Reg (G_Env, "exp", Prim_Exp'Access);
      Reg (G_Env, "log", Prim_Log'Access);
      Reg (G_Env, "floor", Prim_Floor'Access);
      Reg (G_Env, "ceiling", Prim_Ceiling'Access);
      Reg (G_Env, "round", Prim_Round'Access);
      Reg (G_Env, "truncate", Prim_Truncate'Access);
      Reg (G_Env, "bitwise-and", Prim_Bit_And'Access);
      Reg (G_Env, "bitwise-or", Prim_Bit_Or'Access);
      Reg (G_Env, "bitwise-xor", Prim_Bit_Xor'Access);
      Reg (G_Env, "bitwise-not", Prim_Bit_Not'Access);
      Reg (G_Env, "arithmetic-shift", Prim_Ash'Access);
      Reg (G_Env, "char=?", Prim_Char_Eq'Access);
      Reg (G_Env, "char<?", Prim_Char_Lt'Access);
      Reg (G_Env, "char-upcase", Prim_Char_Upcase'Access);
      Reg (G_Env, "char-downcase", Prim_Char_Downcase'Access);
      Reg (G_Env, "char-alphabetic?", Prim_Char_Alpha'Access);
      Reg (G_Env, "char-numeric?", Prim_Char_Num'Access);
      Reg (G_Env, "char-whitespace?", Prim_Char_Space'Access);
      Reg (G_Env, "string<?", Prim_Str_Lt'Access);
      Reg (G_Env, "string-upcase", Prim_Str_Upcase'Access);
      Reg (G_Env, "string-downcase", Prim_Str_Downcase'Access);
      Reg (G_Env, "make-string", Prim_Make_String'Access);
      Reg (G_Env, "string", Prim_String'Access);
      Reg (G_Env, "string->symbol", Prim_Str_To_Sym'Access);
      Reg (G_Env, "symbol->string", Prim_Sym_To_Str'Access);
      Reg (G_Env, "string->number", Prim_Str_To_Num'Access);
      Reg (G_Env, "memq", Prim_Memq'Access);
      Reg (G_Env, "assq", Prim_Assq'Access);
      Reg (G_Env, "caar", Prim_Caar'Access);
      Reg (G_Env, "cdar", Prim_Cdar'Access);
      Reg (G_Env, "cddr", Prim_Cddr'Access);
      Reg (G_Env, "cdddr", Prim_Cdddr'Access);
      Reg (G_Env, "cadddr", Prim_Cadddr'Access);
      Reg (G_Env, "list-copy", Prim_List_Copy'Access);
      Reg (G_Env, "vector-map", Prim_Vector_Map'Access);
      Reg (G_Env, "vector-for-each", Prim_Vector_For_Each'Access);
   end Init;

end Lisp.Eval;
