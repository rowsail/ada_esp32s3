with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Wide_Wide_Characters.Handling;

package body Turbo.Syntax is

   use Ada.Wide_Wide_Characters.Handling;

   function Language_Of (File_Name : String) return Language is
      use Ada.Characters.Handling;
      Ext  : constant String := To_Lower (Ada.Directories.Extension (File_Name));
      Base : constant String := To_Lower (Ada.Directories.Simple_Name (File_Name));
   begin
      if Ext = "ads" or else Ext = "adb" or else Ext = "ada" or else Ext = "gpr"
        or else Ext = "adc"
      then
         return Ada_Lang;
      elsif Ext = "sh" or else Ext = "toml" or else Ext = "cfg"
        or else Ext = "ini" or else Ext = "py" or else Ext = "yml"
        or else Ext = "yaml" or else Ext = "rules" or else Base = "makefile"
        or else Base = "x" or else Base = "esp32-ada"
      then
         return Shell_Lang;
      elsif Ext = "c" or else Ext = "h" or else Ext = "s" or else Ext = "ld"
        or else Ext = "cpp" or else Ext = "hpp" or else Ext = "cc"
      then
         return C_Lang;
      else
         return Plain;
      end if;
   end Language_Of;

   type Word is access constant Wide_Wide_String;
   type Word_List is array (Positive range <>) of Word;

   function "+" (S : Wide_Wide_String) return Word is (new Wide_Wide_String'(S));

   Ada_Keywords : constant Word_List :=
     [+"abort", +"abs", +"abstract", +"accept", +"access", +"aliased", +"all",
      +"and", +"array", +"at", +"begin", +"body", +"case", +"constant",
      +"declare", +"delay", +"delta", +"digits", +"do", +"else", +"elsif",
      +"end", +"entry", +"exception", +"exit", +"for", +"function",
      +"generic", +"goto", +"if", +"in", +"interface", +"is", +"limited",
      +"loop", +"mod", +"new", +"not", +"null", +"of", +"or", +"others",
      +"out", +"overriding", +"package", +"parallel", +"pragma", +"private",
      +"procedure", +"protected", +"raise", +"range", +"record", +"rem",
      +"renames", +"requeue", +"return", +"reverse", +"select", +"separate",
      +"some", +"subtype", +"synchronized", +"tagged", +"task", +"terminate",
      +"then", +"type", +"until", +"use", +"when", +"while", +"with", +"xor",
      --  GPR project files
      +"project", +"extends", +"external", +"aggregate", +"library",
      +"abstract"];

   C_Keywords : constant Word_List :=
     [+"auto", +"break", +"case", +"char", +"const", +"continue", +"default",
      +"do", +"double", +"else", +"enum", +"extern", +"float", +"for",
      +"goto", +"if", +"inline", +"int", +"long", +"register", +"return",
      +"short", +"signed", +"sizeof", +"static", +"struct", +"switch",
      +"typedef", +"union", +"unsigned", +"void", +"volatile", +"while",
      +"bool", +"true", +"false", +"NULL"];

   Shell_Keywords : constant Word_List :=
     [+"if", +"then", +"else", +"elif", +"fi", +"for", +"while", +"do",
      +"done", +"case", +"esac", +"in", +"function", +"return", +"local",
      +"export", +"set", +"exit", +"true", +"false", +"source"];

   function In_List (L : Word_List; W : Wide_Wide_String; Fold : Boolean)
                     return Boolean
   is
      Key : constant Wide_Wide_String := (if Fold then To_Lower (W) else W);
   begin
      for K of L loop
         if K.all = Key then
            return True;
         end if;
      end loop;
      return False;
   end In_List;

   function Is_Ada_Keyword (Word : Wide_Wide_String) return Boolean is
     (In_List (Ada_Keywords, Word, Fold => True));

   function Is_Ident_Start (C : Wide_Wide_Character) return Boolean is
     (Is_Letter (C) or else C = '_');

   function Is_Ident_Char (C : Wide_Wide_Character) return Boolean is
     (Is_Alphanumeric (C) or else C = '_');

   procedure Classify_Ada (Line : Wide_Wide_String; Classes : out Class_Array) is
      I         : Integer := Line'First;
      Prev_Sig  : Wide_Wide_Character := ' ';   --  last non-blank character
      After_Pragma : Boolean := False;
   begin
      Classes := [others => Normal];
      while I <= Line'Last loop
         declare
            C : constant Wide_Wide_Character := Line (I);
         begin
            if C = '-' and then I < Line'Last and then Line (I + 1) = '-' then
               Classes (I .. Line'Last) := [others => Comment];
               return;
            elsif C = '"' then
               declare
                  J : Integer := I + 1;
               begin
                  while J <= Line'Last loop
                     if Line (J) = '"' then
                        if J < Line'Last and then Line (J + 1) = '"' then
                           J := J + 2;           --  "" inside a string
                        else
                           exit;
                        end if;
                     else
                        J := J + 1;
                     end if;
                  end loop;
                  J := Integer'Min (J, Line'Last);
                  Classes (I .. J) := [others => String_Lit];
                  I := J + 1;
                  Prev_Sig := '"';
               end;
            elsif C = ''' then
               --  A character literal 'x', unless the tick follows a name or
               --  a closing parenthesis (then it is an attribute: X'First,
               --  T'(...)).
               if I + 2 <= Line'Last and then Line (I + 2) = '''
                 and then not (Is_Ident_Char (Prev_Sig) or else Prev_Sig = ')')
               then
                  Classes (I .. I + 2) := [others => String_Lit];
                  I := I + 3;
                  Prev_Sig := ''';
               else
                  I := I + 1;
                  Prev_Sig := ' ';                --  so 'Access reads as a name
               end if;
            elsif Is_Digit (C) and then not Is_Ident_Char (Prev_Sig) then
               declare
                  J : Integer := I;
               begin
                  --  Digits, underscores, based literals 16#FF#, exponents,
                  --  a decimal point (but not the .. of a range).
                  while J <= Line'Last
                    and then (Is_Hexadecimal_Digit (Line (J))
                              or else Line (J) = '_' or else Line (J) = '#'
                              or else (Line (J) = '.'
                                       and then J < Line'Last
                                       and then Is_Digit (Line (J + 1)))
                              or else ((Line (J) = '+' or else Line (J) = '-')
                                       and then J > I
                                       and then (Line (J - 1) = 'e'
                                                 or else Line (J - 1) = 'E')))
                  loop
                     J := J + 1;
                  end loop;
                  Classes (I .. J - 1) := [others => Number];
                  Prev_Sig := '0';
                  I := J;
               end;
            elsif Is_Ident_Start (C) then
               declare
                  J : Integer := I;
               begin
                  while J <= Line'Last and then Is_Ident_Char (Line (J)) loop
                     J := J + 1;
                  end loop;
                  if After_Pragma then
                     Classes (I .. J - 1) := [others => Directive];
                     After_Pragma := False;
                  elsif Prev_Sig /= '''
                    and then In_List (Ada_Keywords, Line (I .. J - 1), True)
                  then
                     Classes (I .. J - 1) := [others => Keyword];
                     After_Pragma := To_Lower (Line (I .. J - 1)) = "pragma";
                  end if;
                  Prev_Sig := 'a';
                  I := J;
               end;
            else
               if C /= ' ' and then C /= Wide_Wide_Character'Val (9) then
                  Prev_Sig := C;
               end if;
               I := I + 1;
            end if;
         end;
      end loop;
   end Classify_Ada;

   procedure Classify_Hash
     (Line : Wide_Wide_String; Classes : out Class_Array; Words : Word_List)
   is
      I     : Integer := Line'First;
      Quote : Wide_Wide_Character;
   begin
      Classes := [others => Normal];
      while I <= Line'Last loop
         declare
            C : constant Wide_Wide_Character := Line (I);
         begin
            if C = '#' and then (I = Line'First or else Line (I - 1) = ' '
                                 or else Line (I - 1) = Wide_Wide_Character'Val (9))
            then
               Classes (I .. Line'Last) := [others => Comment];
               return;
            elsif C = '"' or else C = ''' then
               Quote := C;
               declare
                  J : Integer := I + 1;
               begin
                  while J <= Line'Last and then Line (J) /= Quote loop
                     if Line (J) = '\' then
                        J := J + 1;
                     end if;
                     J := J + 1;
                  end loop;
                  J := Integer'Min (J, Line'Last);
                  Classes (I .. J) := [others => String_Lit];
                  I := J + 1;
               end;
            elsif C = '[' and then I = Line'First then
               --  A TOML table header.
               Classes (I .. Line'Last) := [others => Directive];
               return;
            elsif Is_Ident_Start (C) then
               declare
                  J : Integer := I;
               begin
                  while J <= Line'Last and then Is_Ident_Char (Line (J)) loop
                     J := J + 1;
                  end loop;
                  if In_List (Words, Line (I .. J - 1), False) then
                     Classes (I .. J - 1) := [others => Keyword];
                  end if;
                  I := J;
               end;
            elsif Is_Digit (C) then
               declare
                  J : Integer := I;
               begin
                  while J <= Line'Last and then Is_Alphanumeric (Line (J)) loop
                     J := J + 1;
                  end loop;
                  Classes (I .. J - 1) := [others => Number];
                  I := J;
               end;
            else
               I := I + 1;
            end if;
         end;
      end loop;
   end Classify_Hash;

   procedure Classify_C (Line : Wide_Wide_String; Classes : out Class_Array) is
      I : Integer := Line'First;
   begin
      Classes := [others => Normal];
      --  Leading # is a preprocessor line.
      for J in Line'Range loop
         exit when Line (J) /= ' ' and then Line (J) /= Wide_Wide_Character'Val (9);
         null;
      end loop;
      while I <= Line'Last loop
         declare
            C : constant Wide_Wide_Character := Line (I);
         begin
            if C = '/' and then I < Line'Last and then Line (I + 1) = '/' then
               Classes (I .. Line'Last) := [others => Comment];
               return;
            elsif C = '/' and then I < Line'Last and then Line (I + 1) = '*' then
               declare
                  J : Integer := I + 2;
               begin
                  while J < Line'Last
                    and then not (Line (J) = '*' and then Line (J + 1) = '/')
                  loop
                     J := J + 1;
                  end loop;
                  J := Integer'Min (J + 1, Line'Last);
                  Classes (I .. J) := [others => Comment];
                  I := J + 1;
               end;
            elsif C = '*' and then I = Line'First then
               --  The body of a /* ... */ block, by convention.
               Classes (I .. Line'Last) := [others => Comment];
               return;
            elsif C = '#' then
               declare
                  J : Integer := I + 1;
               begin
                  while J <= Line'Last and then Is_Ident_Char (Line (J)) loop
                     J := J + 1;
                  end loop;
                  Classes (I .. J - 1) := [others => Directive];
                  I := J;
               end;
            elsif C = '"' or else C = ''' then
               declare
                  J : Integer := I + 1;
               begin
                  while J <= Line'Last and then Line (J) /= C loop
                     if Line (J) = '\' then
                        J := J + 1;
                     end if;
                     J := J + 1;
                  end loop;
                  J := Integer'Min (J, Line'Last);
                  Classes (I .. J) := [others => String_Lit];
                  I := J + 1;
               end;
            elsif Is_Ident_Start (C) then
               declare
                  J : Integer := I;
               begin
                  while J <= Line'Last and then Is_Ident_Char (Line (J)) loop
                     J := J + 1;
                  end loop;
                  if In_List (C_Keywords, Line (I .. J - 1), False) then
                     Classes (I .. J - 1) := [others => Keyword];
                  end if;
                  I := J;
               end;
            elsif Is_Digit (C) then
               declare
                  J : Integer := I;
               begin
                  while J <= Line'Last
                    and then (Is_Alphanumeric (Line (J)) or else Line (J) = '.')
                  loop
                     J := J + 1;
                  end loop;
                  Classes (I .. J - 1) := [others => Number];
                  I := J;
               end;
            else
               I := I + 1;
            end if;
         end;
      end loop;
   end Classify_C;

   procedure Classify
     (Lang : Language; Line : Wide_Wide_String; Classes : out Class_Array) is
   begin
      case Lang is
         when Plain      => Classes := [others => Normal];
         when Ada_Lang   => Classify_Ada (Line, Classes);
         when Shell_Lang => Classify_Hash (Line, Classes, Shell_Keywords);
         when C_Lang     => Classify_C (Line, Classes);
      end case;
   end Classify;

end Turbo.Syntax;
