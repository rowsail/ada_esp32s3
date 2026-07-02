package body Lisp.Reader is

   function Is_Space (C : Character) return Boolean
   is (C = ' ' or else C = ASCII.HT or else C = ASCII.LF or else C = ASCII.CR);

   function Is_Delim (C : Character) return Boolean
   is (Is_Space (C) or else C = '(' or else C = ')' or else C = ''' or else C = ';');

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

      --  Parse the atom Source (First .. Last) as an integer or a symbol.
      function Atom (First, Last : Natural) return Ref is
         Text   : constant String := Source (First .. Last);
         Value  : Long_Long_Integer := 0;
         Sign   : Long_Long_Integer := 1;
         Cursor : Natural := Text'First;   --  scan position within Text
      begin
         if Text = "-" or else Text = "+" then
            return Intern (Text);                           --  the operator symbol

         end if;
         if Text (Cursor) = '-' then
            Sign := -1;
            Cursor := Cursor + 1;
         elsif Text (Cursor) = '+' then
            Cursor := Cursor + 1;
         end if;
         for J in Cursor .. Text'Last loop
            if Text (J) not in '0' .. '9' then
               return Intern (Text);                        --  not a number

            end if;
            Value :=
              Value * 10 + Long_Long_Integer (Character'Pos (Text (J)) - Character'Pos ('0'));
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
