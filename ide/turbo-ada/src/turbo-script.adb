with Ada.Calendar;
with Ada.Characters.Handling;
with Ada.Containers.Indefinite_Vectors;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with Ada.Strings.Wide_Wide_Fixed;
with Ada.Text_IO;
with Turbo.GDB;
with Turbo.JSON;
with Turbo.Screen;

package body Turbo.Script is

   use Ada.Strings.Unbounded;
   use type Ada.Calendar.Time;
   use type Turbo.GDB.Session_State;

   package String_Vectors is new Ada.Containers.Indefinite_Vectors (Positive, String);

   ESC : constant Character := Character'Val (27);
   CSI : constant String := ESC & "[";

   Steps   : String_Vectors.Vector;
   Next    : Positive := 1;           --  the step to run
   Keys    : String_Vectors.Vector;   --  key sequences still to hand over
   Gap     : Boolean := False;        --  an empty read after each key
   Waiting : Boolean := False;        --  in a wait / wait-for step
   Until_T : Ada.Calendar.Time;
   Failed  : Natural := 0;

   function Failures return Natural is (Failed);

   Trace : Boolean := False;

   procedure Set_Trace (On : Boolean) is
   begin
      Trace := On;
   end Set_Trace;

   procedure Log (S : String) is
   begin
      if Trace then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "tada-cli: " & S);
      end if;
   end Log;

   function Visible (S : String) return String is
   --  ESC [ 1 9 ~ as "^[[19~", for the trace.
      R : Unbounded_String;
   begin
      for C of S loop
         if Character'Pos (C) < 32 then
            Append (R, "^" & Character'Val (Character'Pos (C) + 64));
         elsif Character'Pos (C) = 127 then
            Append (R, "^?");
         else
            Append (R, C);
         end if;
      end loop;
      return To_String (R);
   end Visible;

   --  Words

   function Lower (S : String) return String renames Ada.Characters.Handling.To_Lower;

   function Verb (Step : String) return String is
      Sp : constant Natural := Ada.Strings.Fixed.Index (Step, " ");
   begin
      return Lower (if Sp = 0 then Step else Step (Step'First .. Sp - 1));
   end Verb;

   function Rest (Step : String) return String is
      Sp : constant Natural := Ada.Strings.Fixed.Index (Step, " ");
   begin
      return (if Sp = 0 then "" else Ada.Strings.Fixed.Trim (Step (Sp + 1 .. Step'Last), Ada.Strings.Both));
   end Rest;

   function Words (S : String) return String_Vectors.Vector is
      R : String_Vectors.Vector;
      I : Natural := S'First;
      J : Natural;
   begin
      while I <= S'Last loop
         if S (I) = ' ' then
            I := I + 1;
         else
            J := I;
            while J < S'Last and then S (J + 1) /= ' ' loop
               J := J + 1;
            end loop;
            R.Append (S (I .. J));
            I := J + 1;
         end if;
      end loop;
      return R;
   end Words;

   --  Keys

   function Img (N : Natural) return String is
     (Ada.Strings.Fixed.Trim (Natural'Image (N), Ada.Strings.Left));

   function Key_Bytes (Name : String) return String is
      Shift, Ctrl, Alt : Boolean := False;
      Base : Unbounded_String := To_Unbounded_String (Name);

      function Strip (Prefix : String) return Boolean is
         B : constant String := To_String (Base);
      begin
         if B'Length > Prefix'Length
           and then Lower (B (B'First .. B'First + Prefix'Length - 1)) = Prefix
         then
            Base := To_Unbounded_String (B (B'First + Prefix'Length .. B'Last));
            return True;
         end if;
         return False;
      end Strip;

      function Mods return Natural is
        (1 + (if Shift then 1 else 0) + (if Alt then 2 else 0) + (if Ctrl then 4 else 0));

      function Tilde (Code : Natural) return String is
        (if Mods = 1 then CSI & Img (Code) & "~"
         else CSI & Img (Code) & ";" & Img (Mods) & "~");

      function Letter (Final : Character; SS3 : Boolean := False) return String is
        (if Mods = 1 then (if SS3 then ESC & "O" & Final else CSI & Final)
         else CSI & "1;" & Img (Mods) & Final);
   begin
      loop
         if Strip ("ctrl-") or else Strip ("c-") then
            Ctrl := True;
         elsif Strip ("alt-") or else Strip ("a-") or else Strip ("m-") then
            Alt := True;
         elsif Strip ("shift-") or else Strip ("s-") then
            Shift := True;
         else
            exit;
         end if;
      end loop;
      declare
         B : constant String := To_String (Base);
         L : constant String := Lower (B);
      begin
         if L'Length in 2 .. 3 and then L (L'First) = 'f'
           and then (for all C of L (L'First + 1 .. L'Last) => C in '0' .. '9')
         then
            declare
               N : constant Natural := Natural'Value (L (L'First + 1 .. L'Last));
            begin
               case N is
                  when 1 => return Letter ('P', SS3 => True);
                  when 2 => return Letter ('Q', SS3 => True);
                  when 3 => return Letter ('R', SS3 => True);
                  when 4 => return Letter ('S', SS3 => True);
                  when 5 => return Tilde (15);
                  when 6 .. 10 => return Tilde (N + 11);
                  when 11 | 12 => return Tilde (N + 12);
                  when others => null;
               end case;
            end;
         elsif L = "up" then return Letter ('A');
         elsif L = "down" then return Letter ('B');
         elsif L = "right" then return Letter ('C');
         elsif L = "left" then return Letter ('D');
         elsif L = "home" then return Letter ('H');
         elsif L = "end" then return Letter ('F');
         elsif L in "ins" | "insert" then return Tilde (2);
         elsif L in "del" | "delete" then return Tilde (3);
         elsif L in "pgup" | "pageup" then return Tilde (5);
         elsif L in "pgdn" | "pagedown" then return Tilde (6);
         elsif L in "enter" | "return" then
            return (if Alt then ESC & "" else "") & Character'Val (13);
         elsif L = "tab" then
            return (if Shift then CSI & "Z" else (1 => ASCII.HT));
         elsif L in "esc" | "escape" then
            return (1 => ESC);
         elsif L in "bksp" | "backspace" then
            return (if Alt then ESC & Character'Val (127)
                    elsif Ctrl then (1 => Character'Val (8))
                    else (1 => Character'Val (127)));
         elsif L = "space" or else B'Length = 1 then
            declare
               C : constant Character := (if L = "space" then ' ' else B (B'First));
            begin
               if Ctrl then
                  if C = ' ' then
                     return (1 => ASCII.NUL);
                  elsif Lower ((1 => C)) (1) in 'a' .. 'z' then
                     return (if Alt then ESC & "" else "")
                       & Character'Val (Character'Pos (Ada.Characters.Handling.To_Upper (C)) - 64);
                  end if;
               elsif Alt then
                  return ESC & C;
               else
                  return (1 => C);
               end if;
            end;
         end if;
      end;
      raise Bad_Step with "unknown key """ & Name & """ (tada-cli keys lists them)";
   end Key_Bytes;

   function Key_Names return String is
     ("F1 .. F12, Enter, Esc, Tab, Backspace (BkSp), Space, Up, Down, Left," & ASCII.LF
      & "Right, Home, End, PgUp, PgDn, Ins, Del, and any single character." & ASCII.LF
      & "Prefixes, combinable: Ctrl- Alt- Shift- (e.g. Ctrl-F9, Alt-X, Shift-Tab," & ASCII.LF
      & "Ctrl-K, Alt-F5).  Names are not case-sensitive.");

   --  Steps

   procedure Add (Step : String) is
      S : constant String := Ada.Strings.Fixed.Trim (Step, Ada.Strings.Both);
      V : constant String := Verb (S);
   begin
      if S = "" or else S (S'First) = '#' then
         return;
      elsif V = "key" then
         if Rest (S) = "" then
            raise Bad_Step with "key: which key?";
         end if;
         for W of Words (Rest (S)) loop
            declare
               Ignore : constant String := Key_Bytes (W);   --  check it now
            begin
               null;
            end;
         end loop;
      elsif V = "wait" then
         declare
            Ignore : constant Duration := Duration'Value (Rest (S));
         begin
            null;
         exception
            when Constraint_Error =>
               raise Bad_Step with "wait: seconds, e.g. wait 1.5";
         end;
      elsif V in "type" | "wait-for" | "expect" | "expect-not" | "echo" then
         if V /= "echo" and then Rest (S) = "" then
            raise Bad_Step with V & ": what text?";
         end if;
      elsif V = "wait-stopped" then
         if Rest (S) /= "" then
            declare
               Ignore : constant Duration := Duration'Value (Rest (S));
            begin
               null;
            exception
               when Constraint_Error =>
                  raise Bad_Step with "wait-stopped [SECONDS]";
            end;
         end if;
      elsif V in "screen" | "quit" then
         if V = "screen" and then Rest (S) not in "" | "json" | "text" then
            raise Bad_Step with "screen [text|json]";
         end if;
      else
         raise Bad_Step with "unknown step """ & S & """";
      end if;
      Steps.Append (S);
   end Add;

   procedure Load (File : String) is
      use Ada.Text_IO;
      F : File_Type;
   begin
      if File = "-" then
         while not End_Of_File (Standard_Input) loop
            Add (Get_Line (Standard_Input));
         end loop;
      else
         Open (F, In_File, File);
         while not End_Of_File (F) loop
            Add (Get_Line (F));
         end loop;
         Close (F);
      end if;
   end Load;

   --  The screen

   function Row_Text (Y : Positive) return String is
      W : Wide_Wide_String (1 .. Screen.Width);
   begin
      for X in W'Range loop
         W (X) := Screen.Get (X, Y).Ch;
      end loop;
      return Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode
        (Ada.Strings.Wide_Wide_Fixed.Trim (W, Ada.Strings.Right));
   end Row_Text;

   function Screen_Text return String is
      R : Unbounded_String;
   begin
      for Y in 1 .. Screen.Height loop
         Append (R, Row_Text (Y) & ASCII.LF);
      end loop;
      return To_String (R);
   end Screen_Text;

   function On_Screen (Text : String) return Boolean is
   begin
      for Y in 1 .. Screen.Height loop
         if Ada.Strings.Fixed.Index (Row_Text (Y), Text) > 0 then
            return True;
         end if;
      end loop;
      return False;
   end On_Screen;

   function Color_Name (C : Color) return String is
      S : String := Lower (Color'Image (C));
   begin
      for K in S'Range loop
         if K = S'First or else S (K - 1) = '_' then
            S (K) := Ada.Characters.Handling.To_Upper (S (K));
         end if;
      end loop;
      return S;
   end Color_Name;

   procedure Put_Screen (Json : Boolean := False) is
      use Ada.Text_IO;
   begin
      if not Json then
         Put (Screen_Text);
         return;
      end if;
      --  {"width":80,"height":25,"rows":[{"text":"...","runs":[{"x":1,"len":4,
      --  "fg":"White","bg":"Blue"},...]},...]}: a run per stretch of one colour.
      Put ("{""width"":" & Img (Screen.Width) & ",""height"":" & Img (Screen.Height)
           & ",""rows"":[");
      for Y in 1 .. Screen.Height loop
         Put ((if Y > 1 then "," else "") & ASCII.LF & "{""text"":" & Turbo.JSON.Quote (Row_Text (Y))
              & ",""runs"":[");
         declare
            X     : Positive := 1;
            First : Boolean := True;
         begin
            while X <= Screen.Width loop
               declare
                  A : constant Attribute := Screen.Get (X, Y).A;
                  N : Positive := 1;
               begin
                  while X + N <= Screen.Width and then Screen.Get (X + N, Y).A = A loop
                     N := N + 1;
                  end loop;
                  Put ((if First then "" else ",") & "{""x"":" & Img (X) & ",""len"":" & Img (N)
                       & ",""fg"":""" & Color_Name (A.Fg) & """,""bg"":""" & Color_Name (A.Bg) & """}");
                  First := False;
                  X := X + N;
               end;
            end loop;
         end;
         Put ("]}");
      end loop;
      Put_Line ("]}");
   end Put_Screen;

   procedure Fail (Why : String) is
      use Ada.Text_IO;
   begin
      Failed := Failed + 1;
      Put_Line (Standard_Error, "tada-cli: FAILED: " & Why);
      Put_Line (Standard_Error, "--- the screen ---");
      Put (Standard_Error, Screen_Text);
      Put_Line (Standard_Error, "------------------");
   end Fail;

   --  The virtual terminal's input

   Slice : constant Duration := 0.05;   --  how long a wait sleeps per read

   function Hand_Over (Buf : out Term.Byte_Array; S : String) return Natural is
      N : constant Natural := Natural'Min (S'Length, Buf'Length);
   begin
      for K in 1 .. N loop
         Buf (Buf'First + K - 1) := S (S'First + K - 1);
      end loop;
      Gap := True;
      return N;
   end Hand_Over;

   function Source (Buf : out Term.Byte_Array; Timeout_Ms : Integer) return Natural is
   begin
      Buf := [others => ' '];
      loop
         if Gap then
            --  A read with nothing: the key is taken alone (an Esc is not
            --  the start of Alt-something), and the IDE redraws.
            Gap := False;
            return 0;
         elsif not Keys.Is_Empty
           and then Term.Polling and then Keys.First_Element not in (1 => ESC) | (1 => ASCII.ETX)
         then
            --  The IDE is busy and only looking for Esc: hold the key back.
            delay Slice;
            return 0;
         elsif Keys.Is_Empty and then Next <= Steps.Last_Index and then Term.Polling
           and then Verb (Steps (Next)) not in "wait" | "wait-for" | "screen" | "echo" | "key"
         then
            --  Checks are of the IDE at rest, not of a build box on the way.
            delay Slice;
            return 0;
         elsif not Keys.Is_Empty then
            declare
               K : constant String := Keys.First_Element;
            begin
               Keys.Delete_First;
               Log ("  read" & Integer'Image (Timeout_Ms) & " ms -> " & Visible (K));
               return Hand_Over (Buf, K);
            end;
         elsif Next > Steps.Last_Index then
            raise Term.Script_Ended;
         end if;
         declare
            S : constant String := Steps (Next);
            V : constant String := Verb (S);
            R : constant String := Rest (S);
         begin
            if not Waiting then
               Log ("step " & Img (Next) & ": " & S);
            end if;
            if V = "key" then
               for W of Words (R) loop
                  Keys.Append (Key_Bytes (W));
               end loop;
               Next := Next + 1;
            elsif V = "type" then
               Keys.Append (R);
               Next := Next + 1;
            elsif V = "wait" or else V = "wait-for" then
               declare
                  --  wait-for TEXT [SECONDS]: a number at the end is the limit.
                  Last  : constant Natural := Ada.Strings.Fixed.Index (R, " ", Ada.Strings.Backward);
                  Limit : Duration := 30.0;
                  Text  : Unbounded_String := To_Unbounded_String (R);
               begin
                  if V = "wait-for" and then Last > 0 then
                     begin
                        Limit := Duration'Value (R (Last + 1 .. R'Last));
                        Text := To_Unbounded_String (R (R'First .. Last - 1));
                     exception
                        when Constraint_Error => null;    --  part of the text
                     end;
                  end if;
                  if not Waiting then
                     Waiting := True;
                     Until_T := Ada.Calendar.Clock
                       + (if V = "wait" then Duration'Value (R) else Limit);
                  end if;
                  if V = "wait-for" and then On_Screen (To_String (Text)) then
                     Waiting := False;
                     Next := Next + 1;
                  elsif Ada.Calendar.Clock >= Until_T then
                     Waiting := False;
                     if V = "wait-for" then
                        Fail ("timed out waiting for """ & To_String (Text) & """");
                        raise Term.Script_Ended;      --  the rest would not mean much
                     end if;
                     Next := Next + 1;
                  else
                     delay Slice;
                     return 0;       --  the IDE gets on with it meanwhile
                  end if;
               end;
            elsif V = "wait-stopped" then
               if not Waiting then
                  Waiting := True;
                  Until_T := Ada.Calendar.Clock + (if R = "" then 30.0 else Duration'Value (R));
               end if;
               if Turbo.GDB.State /= Turbo.GDB.Running then
                  --  Stopped (and, the IDE having asked for input since, shown)
                  --  or no session at all.
                  Waiting := False;
                  Next := Next + 1;
               elsif Ada.Calendar.Clock >= Until_T then
                  Waiting := False;
                  Fail ("the program did not stop");
                  raise Term.Script_Ended;
               else
                  delay Slice;
                  return 0;
               end if;
            elsif V = "expect" then
               if not On_Screen (R) then
                  Fail ("expected """ & R & """ on the screen");
               end if;
               Next := Next + 1;
            elsif V = "expect-not" then
               if On_Screen (R) then
                  Fail ("did not expect """ & R & """ on the screen");
               end if;
               Next := Next + 1;
            elsif V = "screen" then
               Put_Screen (Json => R = "json");
               Next := Next + 1;
            elsif V = "echo" then
               Ada.Text_IO.Put_Line (R);
               Next := Next + 1;
            elsif V = "quit" then
               Next := Steps.Last_Index + 1;
               raise Term.Script_Ended;
            end if;
         end;
      end loop;
   end Source;

end Turbo.Script;
