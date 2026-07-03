--  Native host test for the LISP core: read S-expression text and print it back,
--  checking the round-trip, plus symbol interning identity.  No hardware.
with Ada.Text_IO; use Ada.Text_IO;
with Lisp;        use Lisp;
with Lisp.Reader;
with Lisp.Eval;

procedure Lisp_Test is
   Passed, Failed : Natural := 0;

   procedure RT (Input, Want : String) is
      Got : constant String := Print (Lisp.Reader.Read (Input));
   begin
      if Got = Want then
         Passed := Passed + 1;
         Put_Line ("  ok   " & Input & "  ->  " & Got);
      else
         Failed := Failed + 1;
         Put_Line ("  FAIL " & Input & "  ->  " & Got & "  (want " & Want & ")");
      end if;
   end RT;

   --  Read, evaluate (global env), print; compare.
   procedure E (Input, Want : String) is
      Got : constant String := Print (Lisp.Eval.Eval_Top (Lisp.Reader.Read (Input)));
   begin
      if Got = Want then
         Passed := Passed + 1;
         Put_Line ("  ok   " & Input & "  =>  " & Got);
      else
         Failed := Failed + 1;
         Put_Line ("  FAIL " & Input & "  =>  " & Got & "  (want " & Want & ")");
      end if;
   exception
      when Lisp_Error =>
         Failed := Failed + 1;
         Put_Line ("  FAIL " & Input & "  => <error>");
   end E;

   procedure Check (Label : String; Cond : Boolean) is
   begin
      if Cond then
         Passed := Passed + 1;
         Put_Line ("  ok   " & Label);
      else
         Failed := Failed + 1;
         Put_Line ("  FAIL " & Label);
      end if;
   end Check;
begin
   Lisp.Eval.Init;   --  build the global environment
   Put_Line ("reader / printer round-trips:");
   RT ("42", "42");
   RT ("-5", "-5");
   RT ("+7", "7");
   RT ("#t", "#t");
   RT ("#f", "#f");
   RT ("foo", "foo");
   RT ("()", "()");
   RT ("(+ 1 2)", "(+ 1 2)");
   RT ("(a (b c) d)", "(a (b c) d)");
   RT ("(1 . 2)", "(1 . 2)");
   RT ("(1 2 . 3)", "(1 2 . 3)");
   RT ("'x", "(quote x)");
   RT ("'(1 2)", "(quote (1 2))");
   RT ("  ( a   b ) ; trailing comment", "(a b)");
   RT ("(- 4)", "(- 4)");          --  '-' alone is the symbol, not a number
   RT ("(define x 10)", "(define x 10)");

   New_Line;
   Put_Line ("symbol interning:");
   Check ("(intern x) = (intern x)", Intern ("x") = Intern ("x"));
   Check ("(intern x) /= (intern y)", Intern ("x") /= Intern ("y"));
   Check ("nil is the empty list", Is_Nil (Lisp.Reader.Read ("()")));

   New_Line;
   Put_Line ("evaluator:");
   E ("(+ 1 2 3)", "6");
   E ("(* 2 3 4)", "24");
   E ("(- 10 3 2)", "5");
   E ("(- 5)", "-5");
   E ("(/ 20 2 5)", "2");
   E ("(< 1 2)", "#t");
   E ("(> 1 2)", "#f");
   E ("(if (< 1 2) 'yes 'no)", "yes");
   E ("(if #f 1 2)", "2");
   E ("(quote (a b))", "(a b)");
   E ("(car '(1 2 3))", "1");
   E ("(cdr '(1 2 3))", "(2 3)");
   E ("(cons 1 2)", "(1 . 2)");
   E ("(list 1 2 3)", "(1 2 3)");
   E ("(null? '())", "#t");
   E ("(length '(a b c))", "3");
   E ("(eq? 'a 'a)", "#t");
   E ("((lambda (x) (* x x)) 7)", "49");
   E ("(let ((a 3) (b 4)) (+ a b))", "7");
   E ("(cond ((< 2 1) 'a) ((> 2 1) 'b) (else 'c))", "b");
   E ("(and 1 2 3)", "3");
   E ("(and 1 #f 3)", "#f");
   E ("(or #f 2 3)", "2");
   E ("(begin (define x 5) (+ x 1))", "6");
   E ("(begin (set! x 42) x)", "42");
   E ("(begin (define (sq n) (* n n)) (sq 9))", "81");
   E ("(begin (define (adder n) (lambda (k) (+ k n))) (define a5 (adder 5)) (a5 10))", "15");
   E ("(begin (define (fact n) (if (< n 2) 1 (* n (fact (- n 1))))) (fact 6))", "720");

   New_Line;
   Put_Line ("garbage collection:");
   declare
      procedure Run (Input : String) is
         Ignored : constant Ref := Lisp.Eval.Eval_Top (Lisp.Reader.Read (Input));
         pragma Unreferenced (Ignored);
      begin
         null;
      end Run;
      Before, Reclaimed : Natural;
   begin
      Run ("(define (dbl x) (* x 2))");               --  survives GC (global env)
      for I in 1 .. 500 loop
         Run ("(dbl 21)");
      end loop;   --  make garbage
      Before := Cells_Used;
      Reclaimed := GC (Lisp.Eval.Global_Env);
      Check ("GC reclaims garbage", Reclaimed > 0);
      Check ("GC shrinks in-use set", Cells_Used < Before);
      E ("(dbl 21)", "42");                           --  definition survived GC
      E ("(+ 1 2)", "3");                             --  interpreter still works
   end;

   New_Line;
   Put_Line ("tail calls:");
   declare
      procedure Run (Input : String) is
         Ignored : constant Ref := Lisp.Eval.Eval_Top (Lisp.Reader.Read (Input));
         pragma Unreferenced (Ignored);
      begin
         null;
      end Run;
   begin
      Run ("(define (cnt n) (if (= n 0) 'done (cnt (- n 1))))");
      Run ("(define (sm n acc) (if (= n 0) acc (sm (- n 1) (+ acc n))))");
      E ("(cnt 8000)", "done");        --  deep tail recursion -> constant stack
      E ("(sm 1000 0)", "500500");     --  tail-recursive accumulator
   end;

   New_Line;
   Put_Line ("floats:");
   RT ("1.5", "1.5");
   RT ("-2.5", "-2.5");
   RT ("3.0", "3.");
   RT ("0.25", "0.25");
   RT ("1e3", "1000.");
   RT ("2.5e-1", "0.25");
   E ("(+ 1.5 2.5)", "4.");            --  float add
   E ("(+ 1 2.5)", "3.5");             --  int + float -> float (contagion)
   E ("(* 2 3.0)", "6.");
   E ("(/ 7.0 2)", "3.5");             --  float divide
   E ("(/ 7 2)", "3");                 --  int divide unchanged
   E ("(- 5.0 1 1)", "3.");
   E ("(< 1 2.5)", "#t");              --  mixed comparison
   E ("(= 2.0 2)", "#t");
   E ("(eq? 1.5 1.5)", "#t");
   E ("(+ 1 2)", "3");                 --  pure-int path still integer

   New_Line;
   Put_Line ("strings and chars:");
   RT ("""hello""", """hello""");
   RT ("""a\""b""", """a\""b""");      --  embedded escaped quote
   RT ("#\a", "#\a");
   RT ("#\space", "#\space");
   E ("(string? ""hi"")", "#t");
   E ("(string? 5)", "#f");
   E ("(string-length ""hello"")", "5");
   E ("(string-append ""foo"" ""bar"" ""!"")", """foobar!""");
   E ("(string=? ""ab"" ""ab"")", "#t");
   E ("(string=? ""ab"" ""ac"")", "#f");
   E ("(string-ref ""abc"" 1)", "#\b");
   E ("(substring ""hello world"" 0 5)", """hello""");
   E ("(char? (string-ref ""x"" 0))", "#t");
   E ("(char->integer #\A)", "65");
   E ("(integer->char 66)", "#\B");
   E ("(list->string (list #\h #\i))", """hi""");
   E ("(string->list ""ab"")", "(#\a #\b)");
   E ("(number->string 42)", """42""");
   E ("(number->string 1.5)", """1.5""");

   New_Line;
   Put_Line ("added builtins:");
   E ("(equal? (list 1 2) (list 1 2))", "#t");
   E ("(equal? (list 1 2) (list 1 3))", "#f");
   E ("(equal? ""ab"" ""ab"")", "#t");
   E ("(eq? (list 1) (list 1))", "#f");
   E ("(apply + (list 1 2 3))", "6");
   E ("(apply + 1 2 (list 3 4))", "10");
   E ("(apply cons (list 1 2))", "(1 . 2)");
   E ("(map (lambda (x) (* x x)) (list 1 2 3))", "(1 4 9)");
   E ("(map + (list 1 2 3) (list 10 20 30))", "(11 22 33)");
   E ("(append (list 1 2) (list 3 4))", "(1 2 3 4)");
   E ("(append)", "()");
   E ("(append (list 1) (list 2) (list 3))", "(1 2 3)");
   E ("(reverse (list 1 2 3))", "(3 2 1)");
   E ("(assoc 2 (list (list 1 'a) (list 2 'b)))", "(2 b)");
   E ("(assoc 9 (list (list 1 'a)))", "#f");
   E ("(member 2 (list 1 2 3))", "(2 3)");
   E ("(member 9 (list 1 2))", "#f");
   E ("(quotient 17 5)", "3");
   E ("(quotient -17 5)", "-3");
   E ("(modulo 17 5)", "2");
   E ("(modulo -17 5)", "3");
   E ("(modulo 17 -5)", "-3");
   E ("(abs -5)", "5");
   E ("(abs -2.5)", "2.5");
   E ("(number? 5)", "#t");
   E ("(number? 1.5)", "#t");
   E ("(number? 'x)", "#f");
   E ("(number? ""s"")", "#f");
   E ("(zero? 0)", "#t");
   E ("(zero? 0.0)", "#t");
   E ("(zero? 3)", "#f");
   E ("(cadr (list 1 2 3))", "2");
   E ("(caddr (list 1 2 3))", "3");
   E ("(symbol? 'x)", "#t");
   E ("(symbol? 5)", "#f");
   E ("(procedure? car)", "#t");
   E ("(procedure? (lambda (x) x))", "#t");
   E ("(procedure? 5)", "#f");
   E ("(even? 4)", "#t");
   E ("(even? -4)", "#t");
   E ("(even? 3)", "#f");
   E ("(odd? 3)", "#t");
   E ("(odd? -3)", "#t");
   E ("(remainder 17 5)", "2");
   E ("(remainder -17 5)", "-2");
   E ("(remainder 17 -5)", "2");
   E ("(filter even? (list 1 2 3 4 5 6))", "(2 4 6)");
   E ("(filter (lambda (x) (> x 2)) (list 1 2 3 4))", "(3 4)");
   E ("(fold-left - 0 (list 1 2 3))", "-6");
   E ("(fold-left + 0 (list 1 2 3 4))", "10");
   E ("(fold-right - 0 (list 1 2 3))", "2");
   E ("(fold-right cons (list) (list 1 2 3))", "(1 2 3)");
   E ("(list-ref (list 10 20 30) 1)", "20");
   E ("(list-tail (list 1 2 3 4) 2)", "(3 4)");

   New_Line;
   Put_Line
     ("Lisp core:"
      & Natural'Image (Passed)
      & " passed,"
      & Natural'Image (Failed)
      & " failed  (cells used:"
      & Natural'Image (Cells_Used)
      & ")");
   if Failed > 0 then
      raise Program_Error with "lisp core test failed";
   end if;
end Lisp_Test;
