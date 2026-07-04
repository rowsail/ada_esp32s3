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

   --  Capture display / write / newline output for the text-output tests.
   Cap_Buf : String (1 .. 4096);
   Cap_Len : Natural := 0;
   procedure Capture (S : String) is
   begin
      if Cap_Len + S'Length <= Cap_Buf'Last then
         Cap_Buf (Cap_Len + 1 .. Cap_Len + S'Length) := S;
         Cap_Len := Cap_Len + S'Length;
      end if;
   end Capture;

   --  Evaluate Input and compare the CAPTURED output (CR/LF shown as \r \n).
   procedure D (Input, Want : String) is
      Got : String (1 .. Cap_Buf'Length * 2);
      N   : Natural := 0;
   begin
      Cap_Len := 0;
      declare
         Ignored : constant Ref := Lisp.Eval.Eval_Top (Lisp.Reader.Read (Input));
         pragma Unreferenced (Ignored);
      begin
         null;
      end;
      for I in 1 .. Cap_Len loop
         if Cap_Buf (I) = ASCII.CR then
            Got (N + 1 .. N + 2) := "\r";
            N := N + 2;
         elsif Cap_Buf (I) = ASCII.LF then
            Got (N + 1 .. N + 2) := "\n";
            N := N + 2;
         else
            N := N + 1;
            Got (N) := Cap_Buf (I);
         end if;
      end loop;
      if Got (1 .. N) = Want then
         Passed := Passed + 1;
         Put_Line ("  ok   " & Input & "  ||  " & Got (1 .. N));
      else
         Failed := Failed + 1;
         Put_Line ("  FAIL " & Input & "  ||  [" & Got (1 .. N) & "]  (want [" & Want & "])");
      end if;
   end D;
   --  Canned input source, for the terminal-port (read) test.
   Feed_Buf : String (1 .. 256);
   Feed_Len : Natural := 0;
   Feed_Pos : Natural := 0;
   procedure Feed_In (C : out Character; Ok : out Boolean) is
   begin
      if Feed_Pos < Feed_Len then
         Feed_Pos := Feed_Pos + 1;
         C := Feed_Buf (Feed_Pos);
         Ok := True;
      else
         C := ASCII.NUL;
         Ok := False;
      end if;
   end Feed_In;
   procedure Set_Feed (S : String) is
   begin
      Feed_Len := S'Length;
      Feed_Buf (1 .. Feed_Len) := S;
      Feed_Pos := 0;
   end Set_Feed;
begin
   Lisp.Eval.Init;   --  build the global environment
   Lisp.Set_Output (Capture'Unrestricted_Access);   --  capture display/write output
   Lisp.Set_Input (Feed_In'Unrestricted_Access);    --  canned terminal input
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
   E ("(gcd 12 18)", "6");
   E ("(gcd 12 18 24)", "6");
   E ("(gcd -12 8)", "4");
   E ("(gcd)", "0");
   E ("(lcm 4 6)", "12");
   E ("(lcm 4 6 8)", "24");
   E ("(lcm)", "1");
   E ("(expt 2 10)", "1024");
   E ("(expt 2 0)", "1");
   E ("(expt 2.0 3)", "8.");
   E ("(expt 2 -2)", "0.25");
   E ("(sort (list 3 1 2) <)", "(1 2 3)");
   E ("(sort (list 5 3 8 1 9 2 7) <)", "(1 2 3 5 7 8 9)");
   E ("(sort (list 3 1 2) >)", "(3 2 1)");
   E ("(let ((p (cons 1 2))) (set-car! p 9) p)", "(9 . 2)");
   E ("(let ((p (cons 1 2))) (set-cdr! p 9) p)", "(1 . 9)");
   E ("(let ((p (list 1))) (set-cdr! p (list 2 3)) p)", "(1 2 3)");

   New_Line;
   Put_Line ("vectors:");
   E ("(vector? (vector 1 2 3))", "#t");
   E ("(vector? (list 1 2))", "#f");
   E ("(vector 1 2 3)", "#(1 2 3)");
   E ("(make-vector 3 0)", "#(0 0 0)");
   E ("(make-vector 0 0)", "#()");
   E ("(vector-length (vector 1 2 3 4))", "4");
   E ("(vector-ref (vector 10 20 30) 1)", "20");
   E ("(let ((v (vector 1 2 3))) (vector-set! v 1 99) v)", "#(1 99 3)");
   E ("(vector->list (vector 1 2 3))", "(1 2 3)");
   E ("(list->vector (list 1 2 3))", "#(1 2 3)");
   E ("(let ((v (make-vector 3 0))) (vector-fill! v 7) v)", "#(7 7 7)");
   E ("#(1 2 3)", "#(1 2 3)");                      --  reader literal, self-evaluating
   E ("#(1 (2 3) ""x"")", "#(1 (2 3) ""x"")");      --  nested / mixed elements
   E ("(equal? (vector 1 2) (vector 1 2))", "#t");
   E ("(equal? (vector 1 2) (vector 1 3))", "#f");
   E ("(eq? (vector 1) (vector 1))", "#f");         --  distinct objects

   --  GC integration: a vector reachable from Root survives; unreachable vector
   --  backings are freed by the sweep (no leak, no double-free on a later GC).
   declare
      Root : constant Ref := Lisp.Eval.Eval_Top (Lisp.Reader.Read ("(define gv (vector 1 2 3))"));
      pragma Unreferenced (Root);
      R1   : constant Natural := Lisp.GC (Lisp.Eval.Global_Env);
      pragma Unreferenced (R1);
      R2   : constant Natural := Lisp.GC (Lisp.Eval.Global_Env);   --  again: no double-free
      pragma Unreferenced (R2);
   begin
      E ("(vector-ref gv 2)", "3");                 --  gv survived two collections
   end;

   New_Line;
   Put_Line ("hash tables:");
   E ("(hash-table? (make-hash-table))", "#t");
   E ("(hash-table? (list))", "#f");
   E ("(let ((h (make-hash-table))) (hash-set! h 'a 1) (hash-ref h 'a))", "1");
   E ("(let ((h (make-hash-table))) (hash-set! h 'a 1) (hash-set! h 'a 2) (hash-ref h 'a))", "2");
   E ("(let ((h (make-hash-table))) (hash-ref h 'x))", "#f");
   E ("(let ((h (make-hash-table))) (hash-ref h 'x 99))", "99");
   E ("(let ((h (make-hash-table))) (hash-set! h ""k"" 42) (hash-ref h ""k""))", "42");
   E ("(let ((h (make-hash-table))) (hash-set! h (list 1 2) 'v) (hash-ref h (list 1 2)))", "v");
   E
     ("(let ((h (make-hash-table))) (hash-set! h 'a 1) (hash-set! h 'b 2) "
      & "(hash-table-count h))",
      "2");
   E
     ("(let ((h (make-hash-table))) (hash-set! h 'a 1) (hash-remove! h 'a) (hash-ref h 'a))",
      "#f");
   E
     ("(let ((h (make-hash-table))) (hash-set! h 1 'a) (hash-set! h 2 'b) "
      & "(sort (hash-table-keys h) <))",
      "(1 2)");
   E ("(let ((h (make-hash-table 4))) (hash-set! h 1 'a) (hash-set! h 5 'b) (hash-ref h 5))", "b");

   New_Line;
   Put_Line ("display / write / newline:");
   D ("(display 42)", "42");
   D ("(display ""hi"")", "hi");                        --  display: no quotes
   D ("(write ""hi"")", """hi""");                      --  write: quoted
   D ("(display #\a)", "a");                            --  display char: raw
   D ("(write #\a)", "#\a");                            --  write char: #\ form
   D ("(display (list 1 ""x"" #\y))", "(1 x y)");       --  strings/chars raw inside
   D ("(write (list 1 ""x"" #\y))", "(1 ""x"" #\y)");   --  quoted inside
   D ("(newline)", "\r\n");
   D ("(begin (display ""a"") (newline) (display ""b""))", "a\r\nb");
   D ("(write-char #\Z)", "Z");
   D ("(write-string ""hello"")", "hello");
   E ("(display 5)", "");                               --  returns unspecified (prints empty)

   New_Line;
   Put_Line ("read / ports:");
   E ("(read-from-string ""42"")", "42");
   E ("(read-from-string ""(+ 1 2)"")", "(+ 1 2)");     --  datum, unevaluated
   E ("(read-from-string ""hello"")", "hello");
   E ("(read-from-string ""\""hi\"""")", """hi""");     --  a string datum
   E ("(input-port? (open-input-string ""x""))", "#t");
   E ("(input-port? 5)", "#f");
   E ("(eof-object? (eof-object))", "#t");
   E ("(eof-object? 5)", "#f");
   E ("(let ((p (open-input-string ""1 2 3""))) (list (read p) (read p) (read p)))", "(1 2 3)");
   E ("(let ((p (open-input-string ""1""))) (list (read p) (eof-object? (read p))))", "(1 #t)");
   E
     ("(let ((p (open-input-string ""ab""))) "
      & "(list (read-char p) (read-char p) (eof-object? (read-char p))))",
      "(#\a #\b #t)");
   E
     ("(let ((p (open-input-string ""xy""))) (list (peek-char p) (read-char p) (read-char p)))",
      "(#\x #\x #\y)");
   E ("(let ((p (open-input-string ""hello\nworld""))) (read-line p))", """hello""");
   --  Terminal port: read pulls from the input source, refilling a line at a time.
   Set_Feed ("7 foo (a b)" & ASCII.CR);
   E ("(list (read) (read) (read))", "(7 foo (a b))");

   New_Line;
   Put_Line ("eval / numeric / predicates:");
   E ("(eval (read-from-string ""(+ 1 2)""))", "3");    --  read + eval close the loop
   E ("(eval (list '* 6 7))", "42");
   E ("(begin (define s 0) (for-each (lambda (x) (set! s (+ s x))) (list 1 2 3 4)) s)", "10");
   E ("(min 3 1 2)", "1");
   E ("(max 3 1 2)", "3");
   E ("(positive? 5)", "#t");
   E ("(negative? -3)", "#t");
   E ("(positive? 0)", "#f");
   E ("(boolean? #t)", "#t");
   E ("(boolean? 5)", "#f");
   E ("(eqv? 2 2)", "#t");
   E ("(eqv? 'a 'a)", "#t");
   E ("(eqv? (list 1) (list 1))", "#f");
   E ("(sqrt 9.0)", "3.");
   E ("(sqrt 2.0)", "1.414214");
   E ("(cos 0.0)", "1.");
   E ("(exp 0.0)", "1.");
   E ("(floor 3.7)", "3.");
   E ("(ceiling 3.2)", "4.");
   E ("(round 3.5)", "4.");
   E ("(truncate 3.9)", "3.");
   E ("(floor 5)", "5");
   E ("(bitwise-and 12 10)", "8");
   E ("(bitwise-or 12 10)", "14");
   E ("(bitwise-xor 12 10)", "6");
   E ("(bitwise-not 0)", "-1");
   E ("(arithmetic-shift 1 4)", "16");
   E ("(arithmetic-shift 16 -2)", "4");

   New_Line;
   Put_Line ("chars / strings / lists / vectors:");
   E ("(char=? #\a #\a)", "#t");
   E ("(char<? #\a #\b)", "#t");
   E ("(char-upcase #\a)", "#\A");
   E ("(char-downcase #\A)", "#\a");
   E ("(char-alphabetic? #\a)", "#t");
   E ("(char-numeric? #\5)", "#t");
   E ("(char-whitespace? #\space)", "#t");
   E ("(string<? ""abc"" ""abd"")", "#t");
   E ("(string-upcase ""abc"")", """ABC""");
   E ("(string-downcase ""ABC"")", """abc""");
   E ("(make-string 3 #\x)", """xxx""");
   E ("(string #\a #\b #\c)", """abc""");
   E ("(symbol->string 'hello)", """hello""");
   E ("(eq? (string->symbol ""x"") 'x)", "#t");
   E ("(string->number ""42"")", "42");
   E ("(string->number ""3.14"")", "3.14");
   E ("(string->number ""foo"")", "#f");
   E ("(memq 'b (list 'a 'b 'c))", "(b c)");
   E ("(assq 'b (list (list 'a 1) (list 'b 2)))", "(b 2)");
   E ("(caar (list (list 1 2) 3))", "1");
   E ("(cddr (list 1 2 3 4))", "(3 4)");
   E ("(cadddr (list 1 2 3 4))", "4");
   E ("(list-copy (list 1 2 3))", "(1 2 3)");
   E ("(let ((a (list 1 2))) (eq? a (list-copy a)))", "#f");
   E ("(vector-map (lambda (x) (* x x)) (vector 1 2 3))", "#(1 4 9)");
   E
     ("(begin (define t 0) (vector-for-each (lambda (x) (set! t (+ t x))) (vector 1 2 3)) t)",
      "6");

   New_Line;
   Put_Line ("special forms:");
   E ("((lambda args args) 1 2 3)", "(1 2 3)");             --  variadic (bare symbol)
   E ("((lambda (a . rest) rest) 1 2 3)", "(2 3)");         --  dotted rest
   E ("((lambda (a . rest) a) 1 2 3)", "1");
   E ("(begin (define (f a . rest) (list a rest)) (f 1 2 3))", "(1 (2 3))");
   E ("(begin (define (g . xs) (length xs)) (g 1 2 3 4))", "4");
   E ("(let* ((a 1) (b (+ a 1))) (+ a b))", "3");           --  sequential let
   E
     ("(letrec ((ev (lambda (n) (if (= n 0) #t (od (- n 1))))) "
      & "(od (lambda (n) (if (= n 0) #f (ev (- n 1)))))) (ev 10))",
      "#t");   --  mutual rec
   E ("(let loop ((i 0) (acc 0)) (if (= i 5) acc (loop (+ i 1) (+ acc i))))", "10");
   E ("(when (> 5 3) 'yes)", "yes");
   E ("(when (< 5 3) 'yes)", "");                           --  false -> unspecified
   E ("(when #t 1 2 3)", "3");
   E ("(unless (< 5 3) 'ok)", "ok");
   E ("(case 2 ((1) 'one) ((2 3) 'two-three) (else 'other))", "two-three");
   E ("(case 9 ((1) 'a) (else 'z))", "z");
   E ("(case 'x ((a b) 1) ((x y) 2))", "2");
   E ("(do ((i 0 (+ i 1)) (acc 0 (+ acc i))) ((= i 5) acc))", "10");
   E ("(do ((i 0 (+ i 1))) ((= i 3) 'done))", "done");
   E ("`(1 2 3)", "(1 2 3)");                               --  quasiquote (no unquote)
   E ("`(1 ,(+ 1 1) 3)", "(1 2 3)");                        --  unquote
   E ("`(1 ,@(list 2 3) 4)", "(1 2 3 4)");                  --  unquote-splicing
   E ("(let ((x 5)) `(a ,x b))", "(a 5 b)");

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
