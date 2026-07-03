package body Lisp.Eval is

   --  Forward declarations for the mutually-recursive evaluator pieces (Eval
   --  itself is already declared in the spec).
   function Eval_Args (Args, Env : Ref) return Ref;
   function Eval_Seq (Body_List, Env : Ref) return Ref;

   --  Special-form symbols, interned once (compared by identity).
   S_Quote, S_If, S_Define, S_Lambda, S_Let, S_Cond, S_Begin, S_Set, S_And, S_Or, S_Else : Ref;

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
   end Eval_Let;

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
         return Cons (Eval (Car (Args), Env), Eval_Args (Cdr (Args), Env));
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
            when K_Int | K_Float | K_Char | K_String | K_Bool | K_Nil | K_Prim | K_Closure =>
               return Cur_Expr;

            when K_Symbol                                                                  =>
               return Lookup (Cur_Expr, Cur_Env);

            when K_Cons                                                                    =>
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
                                 New_Env      : constant Ref := Cons (Nil, Fn.Env);
                                 Param_Cursor : Ref := Fn.Params;
                                 Arg_Cursor   : Ref := Arg_Values;
                              begin
                                 while Is_Cons (Param_Cursor) loop
                                    if not Is_Cons (Arg_Cursor) then
                                       raise Lisp_Error with "too few arguments";
                                    end if;
                                    Define (Car (Param_Cursor), Car (Arg_Cursor), New_Env);
                                    Param_Cursor := Cdr (Param_Cursor);
                                    Arg_Cursor := Cdr (Arg_Cursor);
                                 end loop;
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
   end Init;

end Lisp.Eval;
