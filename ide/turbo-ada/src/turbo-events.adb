with Turbo.Term;
with Ada.Characters.Handling;
with Ada.Strings.Fixed;

package body Turbo.Events is

   use Ada.Strings.Wide_Wide_Unbounded;

   ESC : constant := 27;

   --  A byte queue in front of Term.Read: escape sequences are parsed with
   --  look-ahead, and a read can deliver several keys at once.

   Q_Size : constant := 8192;
   Q      : Term.Byte_Array (1 .. Q_Size);
   Q_Head : Positive := 1;      --  next byte to hand out
   Q_Tail : Natural := 0;       --  last byte filled

   Pushed     : Event;
   Has_Pushed : Boolean := False;

   function Fill (Timeout_Ms : Integer) return Boolean is
      N : Natural;
   begin
      if Q_Head > Q_Tail then
         Q_Head := 1;
         Q_Tail := 0;
      elsif Q_Tail = Q_Size then
         --  Slide what is left down to make room.
         Q (1 .. Q_Tail - Q_Head + 1) := Q (Q_Head .. Q_Tail);
         Q_Tail := Q_Tail - Q_Head + 1;
         Q_Head := 1;
      end if;
      N := Term.Read (Q (Q_Tail + 1 .. Q_Size), Timeout_Ms);
      Q_Tail := Q_Tail + N;
      return N > 0;
   end Fill;

   function Next (Timeout_Ms : Integer) return Integer is
   --  The next byte, or -1 when none arrived in time.
   begin
      if Q_Head > Q_Tail and then not Fill (Timeout_Ms) then
         return -1;
      end if;
      Q_Head := Q_Head + 1;
      return Character'Pos (Q (Q_Head - 1));
   end Next;

   function Peek (Timeout_Ms : Integer) return Integer is
   begin
      if Q_Head > Q_Tail and then not Fill (Timeout_Ms) then
         return -1;
      end if;
      return Character'Pos (Q (Q_Head));
   end Peek;

   --  Escape-sequence continuation bytes arrive in the same write as the ESC
   --  on any real terminal; this is only the wait for a slow link.
   Seq_Timeout : constant := 40;

   function Decode_UTF8 (First : Natural) return Wide_Wide_Character is
      Extra : Natural;
      Code  : Natural;
      B     : Integer;
   begin
      if First < 16#80# then
         return Wide_Wide_Character'Val (First);
      elsif First >= 16#F0# then
         Extra := 3;
         Code := First mod 16#08#;
      elsif First >= 16#E0# then
         Extra := 2;
         Code := First mod 16#10#;
      elsif First >= 16#C0# then
         Extra := 1;
         Code := First mod 16#20#;
      else
         --  A stray continuation byte (Latin-1 terminal?): take it as is.
         return Wide_Wide_Character'Val (First);
      end if;
      for I in 1 .. Extra loop
         B := Peek (Seq_Timeout);
         exit when B < 16#80# or else B >= 16#C0#;
         B := Next (0);
         Code := Code * 64 + B mod 64;
      end loop;
      if Code > 16#10FFFF# then
         Code := 16#FFFD#;
      end if;
      return Wide_Wide_Character'Val (Code);
   end Decode_UTF8;

   procedure Apply_Modifier (E : in out Event; M : Natural) is
   --  xterm: the parameter is 1 + (Shift 1 | Alt 2 | Ctrl 4 | Meta 8).
      Bits : constant Natural := (if M > 0 then M - 1 else 0);
   begin
      E.Shift := E.Shift or else Bits mod 2 = 1;
      E.Alt   := E.Alt or else (Bits / 2) mod 2 = 1 or else (Bits / 8) mod 2 = 1;
      E.Ctrl  := E.Ctrl or else (Bits / 4) mod 2 = 1;
   end Apply_Modifier;

   function Key_Event (Code : Key_Code) return Event is
      E : Event;
   begin
      E.Kind := Key;
      E.Code := Code;
      return E;
   end Key_Event;

   function Read_Paste return Event is
   --  Bytes up to ESC [ 2 0 1 ~, as text with plain LF line ends.
      E    : Event;
      Raw  : Unbounded_Wide_Wide_String;
      B    : Integer;
      Term : constant String := Character'Val (ESC) & "[201~";
      Match : Natural := 0;
      Held  : String (1 .. Term'Length);
   begin
      E.Kind := Paste;
      loop
         B := Next (2_000);
         exit when B < 0;
         if Character'Val (B) = Term (Match + 1) then
            Match := Match + 1;
            Held (Match) := Character'Val (B);
            exit when Match = Term'Length;
         else
            for I in 1 .. Match loop
               Append (Raw, Wide_Wide_Character'Val (Character'Pos (Held (I))));
            end loop;
            Match := 0;
            if B = 13 then
               if Peek (0) = 10 then
                  B := Next (0);
               end if;
               Append (Raw, Wide_Wide_Character'Val (10));
            elsif B = 9 or else B = 10 or else B >= 32 then
               Append (Raw, Decode_UTF8 (B));
            end if;
         end if;
      end loop;
      E.Text := Raw;
      return E;
   end Read_Paste;

   function Parse_CSI return Event is
   --  After ESC [.  Parameters, then a final byte.
      Params  : array (1 .. 8) of Natural := [others => 0];
      N_Param : Natural := 1;
      Priv : Character := ' ';
      B       : Integer;
      Final   : Character;
      E       : Event;
   begin
      B := Peek (Seq_Timeout);
      if B in Character'Pos ('<') | Character'Pos ('?') | Character'Pos ('>')
      then
         Priv := Character'Val (Next (0));
      elsif B = Character'Pos ('[') then
         --  Linux console F1-F5: ESC [ [ A .. E.
         B := Next (0);
         B := Next (Seq_Timeout);
         if B in Character'Pos ('A') .. Character'Pos ('E') then
            return Key_Event (Key_Code'Val
                                (Key_Code'Pos (F1) + B - Character'Pos ('A')));
         end if;
         return E;
      end if;

      loop
         B := Next (Seq_Timeout);
         if B < 0 then
            return E;                            --  truncated: drop it
         end if;
         Final := Character'Val (B);
         case Final is
            when '0' .. '9' =>
               if Params (N_Param) < 100_000 then
                  Params (N_Param) :=
                    Params (N_Param) * 10 + (B - Character'Pos ('0'));
               end if;
            when ';' | ':' =>
               if N_Param < Params'Last then
                  N_Param := N_Param + 1;
               end if;
            when Character'Val (16#20#) .. Character'Val (16#2F#) =>
               null;                             --  intermediates: ignore
            when Character'Val (16#40#) .. Character'Val (16#7E#) =>
               exit;
            when others =>
               return E;
         end case;
      end loop;

      if Priv = '<' and then (Final = 'M' or else Final = 'm') then
         --  SGR mouse: ESC [ < b ; x ; y M (press/drag) or m (release).
         declare
            Btn : constant Natural := Params (1);
         begin
            E.Kind := Mouse;
            E.X := Params (2);
            E.Y := Params (3);
            E.Shift := (Btn / 4) mod 2 = 1;
            E.Alt := (Btn / 8) mod 2 = 1;
            E.Ctrl := (Btn / 16) mod 2 = 1;
            E.Button := Btn mod 4;
            if Btn >= 64 then
               E.Action := (if Btn mod 2 = 0 then Wheel_Up else Wheel_Down);
            elsif (Btn / 32) mod 2 = 1 then
               E.Action := Drag;
            elsif Final = 'm' then
               E.Action := Release;
            else
               E.Action := Press;
            end if;
            return E;
         end;
      elsif Priv /= ' ' then
         return E;                               --  a report we did not ask for
      end if;

      case Final is
         when 'A' => E := Key_Event (Up);
         when 'B' => E := Key_Event (Down);
         when 'C' => E := Key_Event (Right);
         when 'D' => E := Key_Event (Left);
         when 'H' => E := Key_Event (Home);
         when 'F' => E := Key_Event (End_Key);
         when 'P' => E := Key_Event (F1);
         when 'Q' => E := Key_Event (F2);
         when 'R' => E := Key_Event (F3);
         when 'S' => E := Key_Event (F4);
         when 'Z' =>
            E := Key_Event (Tab);
            E.Shift := True;
         when '~' =>
            case Params (1) is
               when 1 | 7  => E := Key_Event (Home);
               when 2      => E := Key_Event (Insert);
               when 3      => E := Key_Event (Delete);
               when 4 | 8  => E := Key_Event (End_Key);
               when 5      => E := Key_Event (Page_Up);
               when 6      => E := Key_Event (Page_Down);
               when 11     => E := Key_Event (F1);
               when 12     => E := Key_Event (F2);
               when 13     => E := Key_Event (F3);
               when 14     => E := Key_Event (F4);
               when 15     => E := Key_Event (F5);
               when 17     => E := Key_Event (F6);
               when 18     => E := Key_Event (F7);
               when 19     => E := Key_Event (F8);
               when 20     => E := Key_Event (F9);
               when 21     => E := Key_Event (F10);
               when 23     => E := Key_Event (F11);
               when 24     => E := Key_Event (F12);
               when 200    => return Read_Paste;
               when others => return E;
            end case;
         when 'u' =>
            --  CSI u ("fixterms"): key code ; modifiers.
            E.Kind := Key;
            case Params (1) is
               when 13 => E.Code := Enter;
               when 9 => E.Code := Tab;
               when 27 => E.Code := Escape;
               when 127 => E.Code := Backspace;
               when 32 .. 126 =>
                  E.Code := Char_Key;
                  E.Ch := Wide_Wide_Character'Val (Params (1));
               when others => return (others => <>);
            end case;
         when others =>
            return E;
      end case;

      if N_Param >= 2 then
         Apply_Modifier (E, Params (2));
      end if;
      return E;
   end Parse_CSI;

   function Parse_SS3 return Event is
   --  After ESC O: the application-keypad forms of F1-F4 and the arrows.
   --  Konsole puts the modifier between ("ESC O 2 Q" is Shift-F2), some
   --  terminals as "ESC O 1;2 Q".
      B : Integer := Next (Seq_Timeout);
      M : Natural := 0;
      E : Event;
   begin
      while B in Character'Pos ('0') .. Character'Pos ('9') | Character'Pos (';') loop
         if B = Character'Pos (';') then
            M := 0;
         else
            M := M * 10 + (B - Character'Pos ('0'));
         end if;
         B := Next (Seq_Timeout);
      end loop;
      case B is
         when Character'Pos ('P') => E := Key_Event (F1);
         when Character'Pos ('Q') => E := Key_Event (F2);
         when Character'Pos ('R') => E := Key_Event (F3);
         when Character'Pos ('S') => E := Key_Event (F4);
         when Character'Pos ('A') => E := Key_Event (Up);
         when Character'Pos ('B') => E := Key_Event (Down);
         when Character'Pos ('C') => E := Key_Event (Right);
         when Character'Pos ('D') => E := Key_Event (Left);
         when Character'Pos ('H') => E := Key_Event (Home);
         when Character'Pos ('F') => E := Key_Event (End_Key);
         when Character'Pos ('M') => E := Key_Event (Enter);
         when others => return (others => <>);
      end case;
      Apply_Modifier (E, M);
      return E;
   end Parse_SS3;

   function From_Byte (B : Natural) return Event is
   --  A key from a single byte (or the start of a UTF-8 sequence).
      E : Event;
   begin
      E.Kind := Key;
      case B is
         when 13 | 10 => E.Code := Enter;
         when 9       => E.Code := Tab;
         when 127 | 8 =>
            --  Some terminals send ^H for Backspace itself, so ^H cannot
            --  safely mean Ctrl-Backspace.
            E.Code := Backspace;
         when 0 =>
            E.Code := Char_Key;
            E.Ch := ' ';
            E.Ctrl := True;
         when 1 .. 7 | 11 | 12 | 14 .. 26 =>
            E.Code := Char_Key;
            E.Ch := Wide_Wide_Character'Val (Character'Pos ('a') + B - 1);
            E.Ctrl := True;
         when 28 .. 31 =>
            E.Kind := None;
         when others =>
            E.Code := Char_Key;
            E.Ch := Decode_UTF8 (B);
      end case;
      return E;
   end From_Byte;

   function Poll (Timeout_Ms : Integer) return Event is
      E : Event;
   begin
      Term.Set_Polling (True);
      E := Get (Timeout_Ms);
      Term.Set_Polling (False);
      return E;
   exception
      when others =>
         Term.Set_Polling (False);
         raise;
   end Poll;

   function Get (Timeout_Ms : Integer) return Event is
      B : Integer;
      E : Event;
   begin
      if Has_Pushed then
         Has_Pushed := False;
         return Pushed;
      end if;

      if Term.Take_Resized then
         return (Kind => Resize, others => <>);
      end if;

      B := Next (Timeout_Ms);
      if B < 0 then
         if Term.Take_Resized then
            return (Kind => Resize, others => <>);
         end if;
         return E;
      end if;

      if B /= ESC then
         return From_Byte (B);
      end if;

      B := Peek (Seq_Timeout);
      if B < 0 then
         return Key_Event (Escape);
      elsif B = Character'Pos ('[') then
         B := Next (0);
         return Parse_CSI;
      elsif B = Character'Pos ('O') then
         B := Next (0);
         return Parse_SS3;
      elsif B = ESC then
         --  ESC ESC [ ...: Alt with a special key (some terminals), or two
         --  presses of Escape.
         B := Next (0);
         if Peek (0) = Character'Pos ('[') then
            B := Next (0);
            E := Parse_CSI;
            E.Alt := True;
            return E;
         end if;
         Push_Back (Key_Event (Escape));
         return Key_Event (Escape);
      else
         --  ESC + key = Alt + key.
         B := Next (0);
         E := From_Byte (B);
         E.Alt := True;
         if E.Code = Char_Key and then not E.Ctrl then
            --  Alt-Shift-letter arrives as ESC + upper case.
            if E.Ch in 'A' .. 'Z' then
               E.Ch := Wide_Wide_Character'Val
                 (Wide_Wide_Character'Pos (E.Ch) + 32);
               E.Shift := True;
            end if;
         end if;
         return E;
      end if;
   end Get;

   procedure Push_Back (E : Event) is
   begin
      Pushed := E;
      Has_Pushed := True;
   end Push_Back;

   function Lower (C : Character) return Wide_Wide_Character is
     (Wide_Wide_Character'Val
        (Character'Pos (Ada.Characters.Handling.To_Lower (C))));

   function Is_Ctrl (E : Event; Letter : Character) return Boolean is
     (E.Kind = Key and then E.Code = Char_Key and then E.Ctrl
      and then not E.Alt and then E.Ch = Lower (Letter));

   function Is_Alt (E : Event; Letter : Character) return Boolean is
     (E.Kind = Key and then E.Code = Char_Key and then E.Alt
      and then not E.Ctrl and then E.Ch = Lower (Letter));

   function Is_Key
     (E     : Event;
      Code  : Key_Code;
      Shift : Boolean := False;
      Ctrl  : Boolean := False;
      Alt   : Boolean := False) return Boolean is
     (E.Kind = Key and then E.Code = Code and then E.Shift = Shift
      and then E.Ctrl = Ctrl and then E.Alt = Alt);

   function Is_Plain_Char (E : Event) return Boolean is
     (E.Kind = Key and then E.Code = Char_Key and then not E.Ctrl
      and then not E.Alt and then Wide_Wide_Character'Pos (E.Ch) >= 32);

   function Describe (E : Event) return String is
      use Ada.Strings.Fixed;
      Mods : constant String :=
        (if E.Ctrl then "Ctrl-" else "") & (if E.Alt then "Alt-" else "")
        & (if E.Shift then "Shift-" else "");
   begin
      case E.Kind is
         when Key =>
            if E.Code = Char_Key then
               if Wide_Wide_Character'Pos (E.Ch) < 128 then
                  return Mods & Ada.Characters.Handling.To_Upper
                    (Character'Val (Wide_Wide_Character'Pos (E.Ch)));
               else
                  return Mods & "U+"
                    & Trim (Natural'Image (Wide_Wide_Character'Pos (E.Ch)),
                            Ada.Strings.Left);
               end if;
            else
               return Mods & Key_Code'Image (E.Code);
            end if;
         when Mouse =>
            return "Mouse " & Mouse_Action'Image (E.Action)
              & Natural'Image (E.X) & "," & Trim (Natural'Image (E.Y),
                                                  Ada.Strings.Left);
         when Paste => return "Paste";
         when Resize => return "Resize";
         when None => return "";
      end case;
   end Describe;

end Turbo.Events;
