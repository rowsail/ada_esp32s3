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
      E : Ref := Env;
   begin
      while Is_Cons (E) loop
         declare
            Frame : Ref := Car (E);
         begin
            while Is_Cons (Frame) loop
               if Car (Car (Frame)) = Sym then
                  return Cdr (Car (Frame));
               end if;
               Frame := Cdr (Frame);
            end loop;
         end;
         E := Cdr (E);
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
      E : Ref := Env;
   begin
      while Is_Cons (E) loop
         declare
            Frame : Ref := Car (E);
         begin
            while Is_Cons (Frame) loop
               if Car (Car (Frame)) = Sym then
                  Car (Frame).Cdr := Val;
                  return;
               end if;
               Frame := Cdr (Frame);
            end loop;
         end;
         E := Cdr (E);
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

   function Prim_Add (Args : Ref) return Ref is
      Sum : Long_Long_Integer := 0;
      P   : Ref := Args;
   begin
      while Is_Cons (P) loop
         Sum := Sum + Int_Value (Car (P));
         P := Cdr (P);
      end loop;
      return Make_Int (Sum);
   end Prim_Add;

   function Prim_Mul (Args : Ref) return Ref is
      Prod : Long_Long_Integer := 1;
      P    : Ref := Args;
   begin
      while Is_Cons (P) loop
         Prod := Prod * Int_Value (Car (P));
         P := Cdr (P);
      end loop;
      return Make_Int (Prod);
   end Prim_Mul;

   function Prim_Sub (Args : Ref) return Ref is
      P : Ref := Args;
   begin
      if Is_Nil (P) then
         return Make_Int (0);
      end if;
      declare
         Acc : Long_Long_Integer := Int_Value (Car (P));
      begin
         P := Cdr (P);
         if Is_Nil (P) then
            return Make_Int (-Acc);
         end if;     --  unary negate
         while Is_Cons (P) loop
            Acc := Acc - Int_Value (Car (P));
            P := Cdr (P);
         end loop;
         return Make_Int (Acc);
      end;
   end Prim_Sub;

   function Prim_Div (Args : Ref) return Ref is
      Acc : Long_Long_Integer := Int_Value (Arg1 (Args));
      P   : Ref := Cdr (Args);
   begin
      while Is_Cons (P) loop
         declare
            D : constant Long_Long_Integer := Int_Value (Car (P));
         begin
            if D = 0 then
               raise Lisp_Error with "division by zero";
            end if;
            Acc := Acc / D;
         end;
         P := Cdr (P);
      end loop;
      return Make_Int (Acc);
   end Prim_Div;

   function Prim_Num_Eq (Args : Ref) return Ref
   is (Make_Bool (Int_Value (Arg1 (Args)) = Int_Value (Arg2 (Args))));
   function Prim_Lt (Args : Ref) return Ref
   is (Make_Bool (Int_Value (Arg1 (Args)) < Int_Value (Arg2 (Args))));
   function Prim_Gt (Args : Ref) return Ref
   is (Make_Bool (Int_Value (Arg1 (Args)) > Int_Value (Arg2 (Args))));
   function Prim_Le (Args : Ref) return Ref
   is (Make_Bool (Int_Value (Arg1 (Args)) <= Int_Value (Arg2 (Args))));
   function Prim_Ge (Args : Ref) return Ref
   is (Make_Bool (Int_Value (Arg1 (Args)) >= Int_Value (Arg2 (Args))));

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
      A : constant Ref := Arg1 (Args);
      B : constant Ref := Arg2 (Args);
   begin
      if A = B then
         return Lisp_True;
      end if;
      if A /= null and then B /= null and then A.K = B.K then
         case A.K is
            when K_Int  =>
               return Make_Bool (A.I = B.I);

            when K_Bool =>
               return Make_Bool (A.B = B.B);

            when K_Nil  =>
               return Lisp_True;

            when others =>
               null;
         end case;
      end if;
      return Lisp_False;
   end Prim_Eq;

   function Prim_Length (Args : Ref) return Ref is
      N : Long_Long_Integer := 0;
      P : Ref := Arg1 (Args);
   begin
      while Is_Cons (P) loop
         N := N + 1;
         P := Cdr (P);
      end loop;
      return Make_Int (N);
   end Prim_Length;

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
      P       : Ref := Car (Args);              --  the binding list
   begin
      while Is_Cons (P) loop
         declare
            B : constant Ref := Car (P);        --  (var expr)
         begin
            Define (Car (B), Eval (Arg2 (B), Env), New_Env);   --  expr in outer env
         end;
         P := Cdr (P);
      end loop;
      return Eval_Seq (Cdr (Args), New_Env);
   end Eval_Let;

   function Eval_Cond (Clauses, Env : Ref) return Ref is
      P : Ref := Clauses;
   begin
      while Is_Cons (P) loop
         declare
            Clause : constant Ref := Car (P);
            Test   : constant Ref := Car (Clause);
         begin
            if Test = S_Else then
               return Eval_Seq (Cdr (Clause), Env);
            end if;
            declare
               TV : constant Ref := Eval (Test, Env);
            begin
               if Is_Truthy (TV) then
                  return (if Is_Nil (Cdr (Clause)) then TV else Eval_Seq (Cdr (Clause), Env));
               end if;
            end;
         end;
         P := Cdr (P);
      end loop;
      return Nil;
   end Eval_Cond;

   function Eval_And (Args, Env : Ref) return Ref is
      Result : Ref := Lisp_True;
      P      : Ref := Args;
   begin
      while Is_Cons (P) loop
         Result := Eval (Car (P), Env);
         if not Is_Truthy (Result) then
            return Result;
         end if;
         P := Cdr (P);
      end loop;
      return Result;
   end Eval_And;

   function Eval_Or (Args, Env : Ref) return Ref is
      P : Ref := Args;
   begin
      while Is_Cons (P) loop
         declare
            V : constant Ref := Eval (Car (P), Env);
         begin
            if Is_Truthy (V) then
               return V;
            end if;
         end;
         P := Cdr (P);
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
      P      : Ref := Body_List;
   begin
      while Is_Cons (P) loop
         Result := Eval (Car (P), Env);
         P := Cdr (P);
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
            when K_Int | K_Bool | K_Nil | K_Prim | K_Closure =>
               return Cur_Expr;

            when K_Symbol                                    =>
               return Lookup (Cur_Expr, Cur_Env);

            when K_Cons                                      =>
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
                        V : constant Ref := Eval (Arg2 (Args), Cur_Env);
                     begin
                        Set_Var (Car (Args), V, Cur_Env);
                        return V;
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
                        P : Ref := Args;
                     begin
                        while Is_Cons (Cdr (P)) loop
                           declare
                              X : constant Ref := Eval (Car (P), Cur_Env);
                              pragma Unreferenced (X);
                           begin
                              null;
                           end;
                           P := Cdr (P);
                        end loop;
                        Cur_Expr := Car (P);                  --  tail: loop
                     end;
                  else
                     --  application
                     declare
                        Fn : constant Ref := Eval (Op, Cur_Env);
                        A  : constant Ref := Eval_Args (Args, Cur_Env);
                     begin
                        if Fn = null then
                           raise Lisp_Error with "cannot apply nil";
                        end if;
                        case Fn.K is
                           when K_Prim    =>
                              return Fn.Fn (A);

                           when K_Closure =>
                              declare
                                 New_Env : constant Ref := Cons (Nil, Fn.Env);
                                 P       : Ref := Fn.Params;
                                 AA      : Ref := A;
                              begin
                                 while Is_Cons (P) loop
                                    if not Is_Cons (AA) then
                                       raise Lisp_Error with "too few arguments";
                                    end if;
                                    Define (Car (P), Car (AA), New_Env);
                                    P := Cdr (P);
                                    AA := Cdr (AA);
                                 end loop;
                                 if Is_Nil (Fn.Code) then
                                    return Nil;
                                 end if;
                                 declare
                                    B : Ref := Fn.Code;
                                 begin
                                    while Is_Cons (Cdr (B)) loop
                                       declare
                                          X : constant Ref := Eval (Car (B), New_Env);
                                          pragma Unreferenced (X);
                                       begin
                                          null;
                                       end;
                                       B := Cdr (B);
                                    end loop;
                                    Cur_Env := New_Env;
                                    Cur_Expr := Car (B);      --  tail call: loop, no growth
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
   end Init;

end Lisp.Eval;
