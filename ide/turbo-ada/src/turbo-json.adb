with Ada.Strings.Fixed;

package body Turbo.JSON is

   use Ada.Strings.Unbounded;

   Syntax_Error : exception;

   procedure Parse (Doc : in out Document; Text : String; Ok : out Boolean) is
      I : Natural := Text'First;

      procedure Skip_Blanks is
      begin
         while I <= Text'Last
           and then Text (I) in ' ' | ASCII.HT | ASCII.LF | ASCII.CR
         loop
            I := I + 1;
         end loop;
      end Skip_Blanks;

      procedure Expect (C : Character) is
      begin
         Skip_Blanks;
         if I > Text'Last or else Text (I) /= C then
            raise Syntax_Error;
         end if;
         I := I + 1;
      end Expect;

      function New_Node (K : Kind) return Value is
         N : Node;
      begin
         N.K := K;
         Doc.Nodes.Append (N);
         return Value (Doc.Nodes.Length);
      end New_Node;

      procedure Add_Child (Parent, Child : Value) is
         P : Node := Doc.Nodes (Positive (Parent));
      begin
         if P.First = No_Value then
            P.First := Child;
         else
            declare
               L : Node := Doc.Nodes (Positive (P.Last));
            begin
               L.Next := Child;
               Doc.Nodes.Replace_Element (Positive (P.Last), L);
            end;
         end if;
         P.Last := Child;
         P.Count := P.Count + 1;
         Doc.Nodes.Replace_Element (Positive (Parent), P);
      end Add_Child;

      procedure Put_UTF8 (S : in out Unbounded_String; Code : Natural) is
      begin
         if Code < 16#80# then
            Append (S, Character'Val (Code));
         elsif Code < 16#800# then
            Append (S, Character'Val (16#C0# + Code / 64));
            Append (S, Character'Val (16#80# + Code mod 64));
         elsif Code < 16#10000# then
            Append (S, Character'Val (16#E0# + Code / 4096));
            Append (S, Character'Val (16#80# + (Code / 64) mod 64));
            Append (S, Character'Val (16#80# + Code mod 64));
         else
            Append (S, Character'Val (16#F0# + Code / 262144));
            Append (S, Character'Val (16#80# + (Code / 4096) mod 64));
            Append (S, Character'Val (16#80# + (Code / 64) mod 64));
            Append (S, Character'Val (16#80# + Code mod 64));
         end if;
      end Put_UTF8;

      function Hex4 return Natural is
         N : Natural := 0;
      begin
         if I + 3 > Text'Last then
            raise Syntax_Error;
         end if;
         for K in I .. I + 3 loop
            N := N * 16 +
              (case Text (K) is
                  when '0' .. '9' => Character'Pos (Text (K)) - Character'Pos ('0'),
                  when 'a' .. 'f' => Character'Pos (Text (K)) - Character'Pos ('a') + 10,
                  when 'A' .. 'F' => Character'Pos (Text (K)) - Character'Pos ('A') + 10,
                  when others => raise Syntax_Error);
         end loop;
         I := I + 4;
         return N;
      end Hex4;

      function Read_String return Unbounded_String is
         S : Unbounded_String;
      begin
         Expect ('"');
         loop
            if I > Text'Last then
               raise Syntax_Error;
            end if;
            declare
               C : constant Character := Text (I);
            begin
               I := I + 1;
               exit when C = '"';
               if C = '\' then
                  if I > Text'Last then
                     raise Syntax_Error;
                  end if;
                  declare
                     E : constant Character := Text (I);
                  begin
                     I := I + 1;
                     case E is
                        when '"' | '\' | '/' => Append (S, E);
                        when 'b' => Append (S, ASCII.BS);
                        when 'f' => Append (S, ASCII.FF);
                        when 'n' => Append (S, ASCII.LF);
                        when 'r' => Append (S, ASCII.CR);
                        when 't' => Append (S, ASCII.HT);
                        when 'u' =>
                           declare
                              Code : Natural := Hex4;
                           begin
                              if Code in 16#D800# .. 16#DBFF#
                                and then I + 1 <= Text'Last
                                and then Text (I) = '\' and then Text (I + 1) = 'u'
                              then
                                 I := I + 2;
                                 declare
                                    Low : constant Natural := Hex4;
                                 begin
                                    Code := 16#10000# + (Code - 16#D800#) * 1024
                                      + (Low - 16#DC00#);
                                 end;
                              end if;
                              Put_UTF8 (S, Code);
                           end;
                        when others => raise Syntax_Error;
                     end case;
                  end;
               else
                  Append (S, C);
               end if;
            end;
         end loop;
         return S;
      end Read_String;

      function Read_Value return Value is
         V : Value;
      begin
         Skip_Blanks;
         if I > Text'Last then
            raise Syntax_Error;
         end if;
         case Text (I) is
            when '{' =>
               I := I + 1;
               V := New_Node (J_Object);
               Skip_Blanks;
               if I <= Text'Last and then Text (I) = '}' then
                  I := I + 1;
                  return V;
               end if;
               loop
                  declare
                     Name  : constant Unbounded_String := Read_String;
                     Child : Value;
                  begin
                     Expect (':');
                     Child := Read_Value;
                     declare
                        N : Node := Doc.Nodes (Positive (Child));
                     begin
                        N.Name := Name;
                        Doc.Nodes.Replace_Element (Positive (Child), N);
                     end;
                     Add_Child (V, Child);
                  end;
                  Skip_Blanks;
                  exit when I <= Text'Last and then Text (I) = '}';
                  Expect (',');
               end loop;
               I := I + 1;
            when '[' =>
               I := I + 1;
               V := New_Node (J_Array);
               Skip_Blanks;
               if I <= Text'Last and then Text (I) = ']' then
                  I := I + 1;
                  return V;
               end if;
               loop
                  Add_Child (V, Read_Value);
                  Skip_Blanks;
                  exit when I <= Text'Last and then Text (I) = ']';
                  Expect (',');
               end loop;
               I := I + 1;
            when '"' =>
               V := New_Node (J_String);
               declare
                  S : constant Unbounded_String := Read_String;
                  N : Node := Doc.Nodes (Positive (V));
               begin
                  N.Text := S;
                  Doc.Nodes.Replace_Element (Positive (V), N);
               end;
            when 't' | 'f' | 'n' =>
               declare
                  function Word (W : String) return Boolean is
                    (I + W'Length - 1 <= Text'Last
                     and then Text (I .. I + W'Length - 1) = W);
               begin
                  if Word ("true") or else Word ("false") then
                     V := New_Node (J_Bool);
                     declare
                        N : Node := Doc.Nodes (Positive (V));
                     begin
                        N.Bool := Text (I) = 't';
                        Doc.Nodes.Replace_Element (Positive (V), N);
                     end;
                     I := I + (if Text (I) = 't' then 4 else 5);
                  elsif Word ("null") then
                     V := New_Node (J_Null);
                     I := I + 4;
                  else
                     raise Syntax_Error;
                  end if;
               end;
            when '-' | '0' .. '9' =>
               declare
                  Start : constant Positive := I;
               begin
                  while I <= Text'Last
                    and then Text (I) in '-' | '+' | '.' | 'e' | 'E' | '0' .. '9'
                  loop
                     I := I + 1;
                  end loop;
                  V := New_Node (J_Number);
                  declare
                     N : Node := Doc.Nodes (Positive (V));
                  begin
                     N.Text := To_Unbounded_String (Text (Start .. I - 1));
                     Doc.Nodes.Replace_Element (Positive (V), N);
                  end;
               end;
            when others =>
               raise Syntax_Error;
         end case;
         return V;
      end Read_Value;

      Top : Value;
   begin
      Doc.Nodes.Clear;
      Top := Read_Value;
      Ok := Top = 1;
   exception
      when others =>
         Doc.Nodes.Clear;
         Ok := False;
   end Parse;

   function Root (Doc : Document) return Value is
     (if Doc.Nodes.Is_Empty then No_Value else 1);

   function Kind_Of (Doc : Document; V : Value) return Kind is
     (if V = No_Value then J_Null else Doc.Nodes (Positive (V)).K);

   function Get (Doc : Document; V : Value; Key : String) return Value is
      C : Value;
   begin
      if V = No_Value or else Doc.Nodes (Positive (V)).K /= J_Object then
         return No_Value;
      end if;
      C := Doc.Nodes (Positive (V)).First;
      while C /= No_Value loop
         if Doc.Nodes (Positive (C)).Name = Key then
            return C;
         end if;
         C := Doc.Nodes (Positive (C)).Next;
      end loop;
      return No_Value;
   end Get;

   function Length (Doc : Document; V : Value) return Natural is
     (if V = No_Value or else Doc.Nodes (Positive (V)).K /= J_Array then 0
      else Doc.Nodes (Positive (V)).Count);

   function Element (Doc : Document; V : Value; N : Positive) return Value is
      C : Value;
   begin
      if N > Length (Doc, V) then
         return No_Value;
      end if;
      C := Doc.Nodes (Positive (V)).First;
      for K in 2 .. N loop
         C := Doc.Nodes (Positive (C)).Next;
      end loop;
      return C;
   end Element;

   function Key (Doc : Document; V : Value) return String is
     (if V = No_Value then "" else To_String (Doc.Nodes (Positive (V)).Name));

   function First_Member (Doc : Document; V : Value) return Value is
     (if V = No_Value or else Doc.Nodes (Positive (V)).K not in J_Object | J_Array
      then No_Value else Doc.Nodes (Positive (V)).First);

   function Next_Member (Doc : Document; V : Value) return Value is
     (if V = No_Value then No_Value else Doc.Nodes (Positive (V)).Next);

   function To_String (Doc : Document; V : Value; Default : String := "") return String is
   begin
      if V = No_Value then
         return Default;
      end if;
      case Doc.Nodes (Positive (V)).K is
         when J_String | J_Number => return To_String (Doc.Nodes (Positive (V)).Text);
         when J_Bool => return (if Doc.Nodes (Positive (V)).Bool then "true" else "false");
         when others => return Default;
      end case;
   end To_String;

   function To_Integer (Doc : Document; V : Value; Default : Integer := 0) return Integer is
   begin
      if Kind_Of (Doc, V) /= J_Number then
         return Default;
      end if;
      declare
         T   : constant String := To_String (Doc.Nodes (Positive (V)).Text);
         Dot : constant Natural := Ada.Strings.Fixed.Index (T, ".");
      begin
         return Integer'Value (if Dot = 0 then T else T (T'First .. Dot - 1));
      end;
   exception
      when others => return Default;
   end To_Integer;

   function To_Boolean (Doc : Document; V : Value; Default : Boolean := False) return Boolean is
     (if Kind_Of (Doc, V) = J_Bool then Doc.Nodes (Positive (V)).Bool else Default);

   function Path (Doc : Document; V : Value; P : String) return Value is
      Dot : constant Natural := Ada.Strings.Fixed.Index (P, ".");
   begin
      if Dot = 0 then
         return Get (Doc, V, P);
      end if;
      return Path (Doc, Get (Doc, V, P (P'First .. Dot - 1)), P (Dot + 1 .. P'Last));
   end Path;

   function Quote (S : String) return String is
      R : Unbounded_String := To_Unbounded_String ("""");
      Hex : constant String := "0123456789abcdef";
   begin
      for C of S loop
         case C is
            when '"' => Append (R, "\""");
            when '\' => Append (R, "\\");
            when ASCII.LF => Append (R, "\n");
            when ASCII.CR => Append (R, "\r");
            when ASCII.HT => Append (R, "\t");
            when Character'Val (0) .. Character'Val (8) | Character'Val (11)
               | Character'Val (12) | Character'Val (14) .. Character'Val (31) =>
               Append (R, "\u00" & Hex (Character'Pos (C) / 16 + 1)
                       & Hex (Character'Pos (C) mod 16 + 1));
            when others => Append (R, C);
         end case;
      end loop;
      Append (R, '"');
      return To_String (R);
   end Quote;

   function Image (N : Integer) return String is
     (Ada.Strings.Fixed.Trim (Integer'Image (N), Ada.Strings.Left));

end Turbo.JSON;
