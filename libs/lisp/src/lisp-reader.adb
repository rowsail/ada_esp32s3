package body Lisp.Reader is

   function Is_Space (C : Character) return Boolean
   is (C = ' ' or else C = ASCII.HT or else C = ASCII.LF or else C = ASCII.CR);

   function Is_Delim (C : Character) return Boolean
   is (Is_Space (C)
       or else C = '('
       or else C = ')'
       or else C = '''
       or else C = ';'
       or else C = '"');

   function Is_Hex (C : Character) return Boolean
   is (C in '0' .. '9' or else C in 'a' .. 'f' or else C in 'A' .. 'F');

   function Hex_Val (C : Character) return Long_Long_Integer is
   begin
      if C in '0' .. '9' then
         return Long_Long_Integer (Character'Pos (C) - Character'Pos ('0'));
      elsif C in 'a' .. 'f' then
         return Long_Long_Integer (10 + Character'Pos (C) - Character'Pos ('a'));
      else
         return Long_Long_Integer (10 + Character'Pos (C) - Character'Pos ('A'));
      end if;
   end Hex_Val;

   function Read (Source : String; Pos : in out Natural) return Ref is

      procedure Skip_Atmosphere is
      begin
         loop
            while Pos <= Source'Last and then Is_Space (Source (Pos)) loop
               Pos := Pos + 1;
            end loop;
            exit when Pos > Source'Last or else Source (Pos) /= ';';
            while Pos <= Source'Last and then Source (Pos) /= ASCII.LF loop
               Pos := Pos + 1;                              --  comment to EOL
            end loop;
         end loop;
      end Skip_Atmosphere;

      function Read_Obj return Ref;

      --  Read list elements until the matching ')'.  Pos is just past '('.
      function Read_List return Ref is
      begin
         Skip_Atmosphere;
         if Pos > Source'Last then
            raise Lisp_Error with "unterminated list";
         elsif Source (Pos) = ')' then
            Pos := Pos + 1;
            return Nil;
         elsif Source (Pos) = '.' and then (Pos = Source'Last or else Is_Delim (Source (Pos + 1)))
         then
            Pos := Pos + 1;                                 --  dotted tail
            declare
               Tail : constant Ref := Read_Obj;
            begin
               Skip_Atmosphere;
               if Pos > Source'Last or else Source (Pos) /= ')' then
                  raise Lisp_Error with "malformed dotted pair";
               end if;
               Pos := Pos + 1;
               return Tail;
            end;
         else
            declare
               Head : constant Ref := Read_Obj;             --  car
            begin
               return Cons (Head, Read_List);               --  cdr (recurse)
            end;
         end if;
      end Read_List;

      --  Parse the atom Source (First .. Last) as an integer, a float, or a symbol.
      function Atom (First, Last : Natural) return Ref is
         Text : constant String := Source (First .. Last);

         function Digit (C : Character) return Long_Long_Integer
         is (Long_Long_Integer (Character'Pos (C) - Character'Pos ('0')));

         --  Manual float parse (avoids Float'Value quirks): sign, integer part,
         --  optional .fraction, optional e[+-]exponent.  On the hardware FPU.
         function Parse_Float return Float is
            I     : Natural := Text'First;
            Sign  : Float := 1.0;
            Val   : Float := 0.0;
            Scale : Float := 1.0;
            E_Sgn : Integer := 1;
            E     : Integer := 0;
         begin
            if Text (I) = '-' then
               Sign := -1.0;
               I := I + 1;
            elsif Text (I) = '+' then
               I := I + 1;
            end if;
            while I <= Text'Last and then Text (I) in '0' .. '9' loop
               Val := Val * 10.0 + Float (Digit (Text (I)));
               I := I + 1;
            end loop;
            if I <= Text'Last and then Text (I) = '.' then
               I := I + 1;
               while I <= Text'Last and then Text (I) in '0' .. '9' loop
                  Scale := Scale / 10.0;
                  Val := Val + Scale * Float (Digit (Text (I)));
                  I := I + 1;
               end loop;
            end if;
            if I <= Text'Last and then (Text (I) = 'e' or else Text (I) = 'E') then
               I := I + 1;
               if I <= Text'Last and then Text (I) = '-' then
                  E_Sgn := -1;
                  I := I + 1;
               elsif I <= Text'Last and then Text (I) = '+' then
                  I := I + 1;
               end if;
               while I <= Text'Last and then Text (I) in '0' .. '9' loop
                  E := E * 10 + Integer (Digit (Text (I)));
                  I := I + 1;
               end loop;
               declare
                  P : Float := 1.0;
               begin
                  for K in 1 .. E loop
                     P := P * 10.0;
                  end loop;
                  Val := (if E_Sgn > 0 then Val * P else Val / P);
               end;
            end if;
            return Sign * Val;
         end Parse_Float;

         --  Classify: scan for all-digits (int), a '.'/'e' among digits (float),
         --  or neither (symbol).
         I         : Natural := Text'First;
         Has_Digit : Boolean := False;
         Has_Dot   : Boolean := False;
         Has_Exp   : Boolean := False;
         Value     : Long_Long_Integer := 0;
         Sign      : Long_Long_Integer := 1;
      begin
         if Text = "-" or else Text = "+" or else Text = "." then
            return Intern (Text);                           --  operator / dot symbols

         end if;
         if Text (I) = '-' or else Text (I) = '+' then
            I := I + 1;
         end if;
         while I <= Text'Last loop
            declare
               C : constant Character := Text (I);
            begin
               if C in '0' .. '9' then
                  Has_Digit := True;
               elsif C = '.' and then not Has_Dot and then not Has_Exp then
                  Has_Dot := True;
               elsif (C = 'e' or else C = 'E') and then Has_Digit and then not Has_Exp then
                  Has_Exp := True;
                  if I < Text'Last and then (Text (I + 1) = '-' or else Text (I + 1) = '+') then
                     I := I + 1;
                  end if;
               else
                  return Intern (Text);                     --  not a number -> symbol
               end if;
            end;
            I := I + 1;
         end loop;
         if not Has_Digit then
            return Intern (Text);
         elsif Has_Dot or else Has_Exp then
            return Make_Float (Parse_Float);
         end if;
         --  plain integer
         I := Text'First;
         if Text (I) = '-' then
            Sign := -1;
            I := I + 1;
         elsif Text (I) = '+' then
            I := I + 1;
         end if;
         for J in I .. Text'Last loop
            Value := Value * 10 + Digit (Text (J));
         end loop;
         return Make_Int (Sign * Value);
      end Atom;

      function Read_Obj return Ref is
      begin
         Skip_Atmosphere;
         if Pos > Source'Last then
            return null;                                    --  end of input

         end if;
         case Source (Pos) is
            when '('    =>
               Pos := Pos + 1;
               return Read_List;

            when ')'    =>
               raise Lisp_Error with "unexpected )";

            when '''    =>
               Pos := Pos + 1;                              --  'x => (quote x)
               return Cons (Intern ("quote"), Cons (Read_Obj, Nil));

            when '"'    =>
               --  "..." string literal, with \" \\ \n \t escapes.
               declare
                  Buf : String (1 .. Source'Length);        --  can't exceed the input
                  N   : Natural := 0;
               begin
                  Pos := Pos + 1;
                  while Pos <= Source'Last and then Source (Pos) /= '"' loop
                     if Source (Pos) = '\' and then Pos < Source'Last then
                        Pos := Pos + 1;
                        N := N + 1;
                        case Source (Pos) is
                           when 'n'    =>
                              Buf (N) := ASCII.LF;

                           when 't'    =>
                              Buf (N) := ASCII.HT;

                           when others =>
                              Buf (N) := Source (Pos);   --  \" \\ and literal
                        end case;
                     else
                        N := N + 1;
                        Buf (N) := Source (Pos);
                     end if;
                     Pos := Pos + 1;
                  end loop;
                  if Pos > Source'Last then
                     raise Lisp_Error with "unterminated string";
                  end if;
                  Pos := Pos + 1;                            --  consume closing quote
                  return Make_String (Buf (1 .. N));
               end;

            when '#'    =>
               if Pos < Source'Last
                 and then (Source (Pos + 1) = 't' or else Source (Pos + 1) = 'f')
               then
                  declare
                     Is_True : constant Boolean := Source (Pos + 1) = 't';
                  begin
                     Pos := Pos + 2;
                     return Make_Bool (Is_True);
                  end;
               elsif Pos < Source'Last and then Source (Pos + 1) = 'x' then
                  Pos := Pos + 2;                            --  #xFF hex literal
                  declare
                     Value : Long_Long_Integer := 0;
                  begin
                     while Pos <= Source'Last and then Is_Hex (Source (Pos)) loop
                        Value := Value * 16 + Hex_Val (Source (Pos));
                        Pos := Pos + 1;
                     end loop;
                     return Make_Int (Value);
                  end;
               elsif Pos < Source'Last and then Source (Pos + 1) = '\' then
                  --  #\a  #\space  #\newline  #\tab  character literal
                  Pos := Pos + 2;
                  declare
                     First : constant Natural := Pos;
                  begin
                     if Pos <= Source'Last then
                        Pos := Pos + 1;                      --  always take one char

                     end if;
                     while Pos <= Source'Last and then not Is_Delim (Source (Pos)) loop
                        Pos := Pos + 1;                      --  a named char (space/newline)
                     end loop;
                     declare
                        Name : constant String := Source (First .. Pos - 1);
                     begin
                        if Name'Length = 1 then
                           return Make_Char (Name (Name'First));
                        elsif Name = "space" then
                           return Make_Char (' ');
                        elsif Name = "newline" then
                           return Make_Char (ASCII.LF);
                        elsif Name = "tab" then
                           return Make_Char (ASCII.HT);
                        else
                           return Make_Char (Name (Name'First));   --  first char
                        end if;
                     end;
                  end;
               end if;
               raise Lisp_Error with "bad # literal";

            when others =>
               declare
                  First : constant Natural := Pos;
               begin
                  while Pos <= Source'Last and then not Is_Delim (Source (Pos)) loop
                     Pos := Pos + 1;
                  end loop;
                  return Atom (First, Pos - 1);
               end;
         end case;
      end Read_Obj;

   begin
      return Read_Obj;
   end Read;

   function Read (Source : String) return Ref is
      Pos : Natural := Source'First;
   begin
      return Read (Source, Pos);
   end Read;

end Lisp.Reader;
