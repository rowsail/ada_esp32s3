with Ada.Streams.Stream_IO;
with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with Ada.Wide_Wide_Characters.Handling;
with Ada.Directories;
with Ada.Unchecked_Deallocation;

package body Turbo.Buffers is

   use type Ada.Containers.Count_Type;
   use type Ada.Directories.File_Kind;

   function Is_Word_Char (C : Wide_Wide_Character) return Boolean is
     (Ada.Wide_Wide_Characters.Handling.Is_Alphanumeric (C) or else C = '_');

   procedure Clear (B : in out Buffer) is
   begin
      B.Lines.Clear;
      B.Lines.Append (Null_Unbounded_Wide_Wide_String);
      B.Undo_Stack.Clear;
      B.Redo_Stack.Clear;
      B.Changes := 0;
      B.Typing := False;
      B.Open_Group := 0;
      B.Group_Depth := 0;
      B.Is_CRLF := False;
      B.Edits := B.Edits + 1;
   end Clear;

   type String_Access is access String;
   procedure Free is new Ada.Unchecked_Deallocation (String, String_Access);

   overriding procedure Initialize (B : in out Buffer) is
   begin
      B.Clear;
   end Initialize;

   function Decode (Raw : String) return Wide_Wide_String is
   begin
      return Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Decode (Raw);
   exception
      when others =>
         --  Not UTF-8: read it as Latin-1, so nothing is lost on a re-save
         --  that does not touch those lines... except their encoding.
         declare
            W : Wide_Wide_String (Raw'Range);
         begin
            for I in Raw'Range loop
               W (I) := Wide_Wide_Character'Val (Character'Pos (Raw (I)));
            end loop;
            return W;
         end;
   end Decode;

   procedure Load (B : in out Buffer; File_Name : String; Ok : out Boolean) is
      use Ada.Streams.Stream_IO;
      F    : File_Type;
      Size : Natural;
   begin
      B.Clear;
      Ok := False;
      if not Ada.Directories.Exists (File_Name)
        or else Ada.Directories.Kind (File_Name) /= Ada.Directories.Ordinary_File
      then
         return;
      end if;
      Size := Natural (Ada.Directories.Size (File_Name));
      Open (F, In_File, File_Name);
      declare
         Raw_Ptr : String_Access := new String (1 .. Size);  --  not the stack
         Raw     : String renames Raw_Ptr.all;
         Last    : Natural := 0;
         Start   : Positive;
      begin
         if Size > 0 then
            String'Read (Stream (F), Raw);
         end if;
         Close (F);
         Last := Size;
         --  Strip a UTF-8 byte order mark.
         Start := 1;
         if Size >= 3 and then Raw (1 .. 3) =
           Character'Val (16#EF#) & Character'Val (16#BB#) & Character'Val (16#BF#)
         then
            Start := 4;
         end if;
         declare
            W         : constant Wide_Wide_String := Decode (Raw (Start .. Last));
            Line_From : Positive := W'First;
            CR        : constant Wide_Wide_Character := Wide_Wide_Character'Val (13);
         begin
            B.Lines.Clear;
            for I in W'Range loop
               if W (I) = LF then
                  if I > Line_From and then W (I - 1) = CR then
                     B.Is_CRLF := True;
                     B.Lines.Append (To_Unbounded_Wide_Wide_String
                                       (W (Line_From .. I - 2)));
                  else
                     B.Lines.Append (To_Unbounded_Wide_Wide_String
                                       (W (Line_From .. I - 1)));
                  end if;
                  Line_From := I + 1;
               end if;
            end loop;
            --  The text after the last LF is the last line (empty when the
            --  file ends in a newline, which Save puts back).
            B.Lines.Append (To_Unbounded_Wide_Wide_String
                              (W (Line_From .. W'Last)));
         end;
         Free (Raw_Ptr);
      end;
      Ok := True;
   exception
      when others =>
         if Is_Open (F) then
            Close (F);
         end if;
         B.Clear;
         Ok := False;
   end Load;

   procedure Save (B : in out Buffer; File_Name : String; Ok : out Boolean) is
      use Ada.Streams.Stream_IO;
      F   : File_Type;
      EOL : constant String :=
        (if B.Is_CRLF then Character'Val (13) & Character'Val (10)
         else (1 => Character'Val (10)));
   begin
      Ok := False;
      Create (F, Out_File, File_Name);
      for I in 1 .. B.Line_Count loop
         declare
            S : constant String :=
              Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode (B.Line (I));
         begin
            String'Write (Stream (F), S);
            if I < B.Line_Count then
               String'Write (Stream (F), EOL);
            end if;
         end;
      end loop;
      Close (F);
      B.Set_Unmodified;
      Ok := True;
   exception
      when others =>
         if Is_Open (F) then
            Close (F);
         end if;
   end Save;

   function Line_Count (B : Buffer) return Positive is
     (Positive (B.Lines.Length));

   function Line (B : Buffer; N : Positive) return Wide_Wide_String is
     (To_Wide_Wide_String (B.Lines (N)));

   function Line_Length (B : Buffer; N : Positive) return Natural is
     (Length (B.Lines (N)));

   function Last_Position (B : Buffer) return Position is
     ((B.Line_Count, B.Line_Length (B.Line_Count) + 1));

   function Clamp (B : Buffer; P : Position) return Position is
      L : constant Positive := Positive'Min (P.Line, B.Line_Count);
   begin
      return (L, Positive'Min (P.Col, B.Line_Length (L) + 1));
   end Clamp;

   function Text (B : Buffer; From, To : Position) return Wide_Wide_String is
      R : Unbounded_Wide_Wide_String;
   begin
      if not (From < To) then
         return "";
      end if;
      if From.Line = To.Line then
         return Slice (B.Lines (From.Line), From.Col, To.Col - 1);
      end if;
      Append (R, Slice (B.Lines (From.Line), From.Col,
                        B.Line_Length (From.Line)));
      for L in From.Line + 1 .. To.Line - 1 loop
         Append (R, LF);
         Append (R, B.Lines (L));
      end loop;
      Append (R, LF);
      Append (R, Slice (B.Lines (To.Line), 1, To.Col - 1));
      return To_Wide_Wide_String (R);
   end Text;

   function All_Text (B : Buffer) return Wide_Wide_String is
     (B.Text ((1, 1), B.Last_Position));

   --  Undo recording

   procedure Record_Op
     (B : in out Buffer; Kind : Op_Kind; Pos : Position; S : Wide_Wide_String)
   is
      Group : Natural;
   begin
      if B.Replaying then
         return;
      end if;
      B.Redo_Stack.Clear;
      if B.Open_Group /= 0 then
         Group := B.Open_Group;
      else
         Group := B.Next_Group;
         B.Next_Group := B.Next_Group + 1;
      end if;
      B.Undo_Stack.Append
        (Op'(Kind   => Kind,
          Pos    => Pos,
          Text   => To_Unbounded_Wide_Wide_String (S),
          Group  => Group,
          Cursor => (if B.Open_Group /= 0 then B.Group_Cursor else Pos)));
      B.Changes := B.Changes + 1;
   end Record_Op;

   procedure Raw_Insert
     (B : in out Buffer; At_Pos : Position; S : Wide_Wide_String;
      After : out Position)
   is
      P    : constant Position := B.Clamp (At_Pos);
      Head : constant Wide_Wide_String :=
        Slice (B.Lines (P.Line), 1, P.Col - 1);
      Tail : constant Wide_Wide_String :=
        Slice (B.Lines (P.Line), P.Col, B.Line_Length (P.Line));
      From : Positive := S'First;
      Row  : Positive := P.Line;
      First_Piece : Boolean := True;
   begin
      B.Edits := B.Edits + 1;
      for I in S'Range loop
         if S (I) = LF then
            if First_Piece then
               B.Lines.Replace_Element
                 (Row, To_Unbounded_Wide_Wide_String (Head & S (From .. I - 1)));
               First_Piece := False;
            else
               B.Lines.Insert
                 (Row, To_Unbounded_Wide_Wide_String (S (From .. I - 1)));
            end if;
            Row := Row + 1;
            From := I + 1;
         end if;
      end loop;
      if First_Piece then
         B.Lines.Replace_Element
           (Row, To_Unbounded_Wide_Wide_String (Head & S (From .. S'Last) & Tail));
         After := (Row, Head'Length + (S'Last - From + 1) + 1);
      else
         B.Lines.Insert
           (Row, To_Unbounded_Wide_Wide_String (S (From .. S'Last) & Tail));
         After := (Row, (S'Last - From + 1) + 1);
      end if;
   end Raw_Insert;

   procedure Raw_Delete (B : in out Buffer; From, To : Position) is
      Head : constant Wide_Wide_String := Slice (B.Lines (From.Line), 1, From.Col - 1);
      Tail : constant Wide_Wide_String :=
        Slice (B.Lines (To.Line), To.Col, B.Line_Length (To.Line));
   begin
      B.Edits := B.Edits + 1;
      B.Lines.Replace_Element
        (From.Line, To_Unbounded_Wide_Wide_String (Head & Tail));
      if To.Line > From.Line then
         B.Lines.Delete (From.Line + 1, Ada.Containers.Count_Type (To.Line - From.Line));
      end if;
   end Raw_Delete;

   procedure Insert
     (B : in out Buffer; At_Pos : Position; S : Wide_Wide_String;
      After : out Position)
   is
      P : constant Position := B.Clamp (At_Pos);
      Typed : constant Boolean :=
        S'Length = 1 and then S (S'First) /= LF and then B.Open_Group = 0;
   begin
      if S'Length = 0 then
         After := P;
         return;
      end if;
      --  Merge a run of typed characters into one undo step, broken at a
      --  word boundary or when the cursor jumped.
      if Typed and then B.Typing and then not B.Replaying
        and then not B.Undo_Stack.Is_Empty
      then
         declare
            Last : Op := B.Undo_Stack.Last_Element;
         begin
            if Last.Kind = Op_Insert
              and then Last.Pos.Line = P.Line
              and then Last.Pos.Col + Length (Last.Text) = P.Col
              and then not (Is_Word_Char (S (S'First)) xor
                            Is_Word_Char (Element (Last.Text, Length (Last.Text))))
            then
               Raw_Insert (B, P, S, After);
               Append (Last.Text, S);
               B.Undo_Stack.Replace_Element (B.Undo_Stack.Last_Index, Last);
               B.Redo_Stack.Clear;
               --  Changes counts undo steps, and this is not a new one.
               return;
            end if;
         end;
      end if;
      Raw_Insert (B, P, S, After);
      Record_Op (B, Op_Insert, P, S);
      B.Typing := Typed;
   end Insert;

   procedure Delete (B : in out Buffer; From, To : Position) is
      F : constant Position := B.Clamp (From);
      T : constant Position := B.Clamp (To);
   begin
      if not (F < T) then
         return;
      end if;
      Record_Op (B, Op_Delete, F, B.Text (F, T));
      Raw_Delete (B, F, T);
      B.Typing := False;
   end Delete;

   function Modified (B : Buffer) return Boolean is (B.Changes /= 0);

   function Edit_Count (B : Buffer) return Natural is (B.Edits);

   procedure Set_Unmodified (B : in out Buffer) is
   begin
      B.Changes := 0;
      B.Typing := False;   --  typing after a save is a new undo step
   end Set_Unmodified;

   function CRLF (B : Buffer) return Boolean is (B.Is_CRLF);

   procedure Begin_Group (B : in out Buffer; Cursor : Position) is
   begin
      if B.Group_Depth = 0 then
         B.Open_Group := B.Next_Group;
         B.Next_Group := B.Next_Group + 1;
         B.Group_Cursor := Cursor;
      end if;
      B.Group_Depth := B.Group_Depth + 1;
      B.Typing := False;
   end Begin_Group;

   procedure End_Group (B : in out Buffer) is
   begin
      if B.Group_Depth > 0 then
         B.Group_Depth := B.Group_Depth - 1;
         if B.Group_Depth = 0 then
            B.Open_Group := 0;
         end if;
      end if;
      B.Typing := False;
   end End_Group;

   procedure Break_Typing (B : in out Buffer) is
   begin
      B.Typing := False;
   end Break_Typing;

   function Can_Undo (B : Buffer) return Boolean is (not B.Undo_Stack.Is_Empty);
   function Can_Redo (B : Buffer) return Boolean is (not B.Redo_Stack.Is_Empty);

   function End_Of (P : Position; S : Unbounded_Wide_Wide_String) return Position is
      Row  : Positive := P.Line;
      Col  : Positive := P.Col;
   begin
      for I in 1 .. Length (S) loop
         if Element (S, I) = LF then
            Row := Row + 1;
            Col := 1;
         else
            Col := Col + 1;
         end if;
      end loop;
      return (Row, Col);
   end End_Of;

   procedure Undo (B : in out Buffer; Cursor : out Position) is
      Group : Natural;
      Ignore : Position;
   begin
      Cursor := (1, 1);
      if B.Undo_Stack.Is_Empty then
         return;
      end if;
      B.Typing := False;
      Group := B.Undo_Stack.Last_Element.Group;
      while not B.Undo_Stack.Is_Empty
        and then B.Undo_Stack.Last_Element.Group = Group
      loop
         declare
            O : constant Op := B.Undo_Stack.Last_Element;
         begin
            B.Undo_Stack.Delete_Last;
            case O.Kind is
               when Op_Insert =>
                  Raw_Delete (B, O.Pos, End_Of (O.Pos, O.Text));
               when Op_Delete =>
                  Raw_Insert (B, O.Pos, To_Wide_Wide_String (O.Text), Ignore);
            end case;
            B.Redo_Stack.Append (O);
            B.Changes := B.Changes - 1;
            Cursor := O.Cursor;
         end;
      end loop;
      Cursor := B.Clamp (Cursor);
   end Undo;

   procedure Redo (B : in out Buffer; Cursor : out Position) is
      Group : Natural;
   begin
      Cursor := (1, 1);
      if B.Redo_Stack.Is_Empty then
         return;
      end if;
      B.Typing := False;
      Group := B.Redo_Stack.Last_Element.Group;
      while not B.Redo_Stack.Is_Empty
        and then B.Redo_Stack.Last_Element.Group = Group
      loop
         declare
            O : constant Op := B.Redo_Stack.Last_Element;
         begin
            B.Redo_Stack.Delete_Last;
            case O.Kind is
               when Op_Insert =>
                  Raw_Insert (B, O.Pos, To_Wide_Wide_String (O.Text), Cursor);
               when Op_Delete =>
                  Raw_Delete (B, O.Pos, End_Of (O.Pos, O.Text));
                  Cursor := O.Pos;
            end case;
            B.Undo_Stack.Append (O);
            B.Changes := B.Changes + 1;
         end;
      end loop;
      Cursor := B.Clamp (Cursor);
   end Redo;

   function Find
     (B          : Buffer;
      Pattern    : Wide_Wide_String;
      From       : Position;
      Forward    : Boolean;
      Match_Case : Boolean;
      Whole_Word : Boolean;
      Found      : out Position) return Boolean
   is
      use Ada.Wide_Wide_Characters.Handling;

      function Fold (S : Wide_Wide_String) return Wide_Wide_String is
        (if Match_Case then S else To_Lower (S));

      P : constant Wide_Wide_String := Fold (Pattern);

      function Match_At (L : Wide_Wide_String; I : Positive) return Boolean is
      begin
         if I + P'Length - 1 > L'Last
           or else L (I .. I + P'Length - 1) /= P
         then
            return False;
         end if;
         if Whole_Word then
            if I > L'First and then Is_Word_Char (L (I - 1)) then
               return False;
            end if;
            if I + P'Length <= L'Last and then Is_Word_Char (L (I + P'Length)) then
               return False;
            end if;
         end if;
         return True;
      end Match_At;

      Start : constant Position := B.Clamp (From);
   begin
      Found := Start;
      if P'Length = 0 then
         return False;
      end if;
      if Forward then
         for Row in Start.Line .. B.Line_Count loop
            declare
               L : constant Wide_Wide_String := Fold (B.Line (Row));
               First_Col : constant Positive :=
                 (if Row = Start.Line then Start.Col else 1);
            begin
               for I in First_Col .. L'Last loop
                  if Match_At (L, I) then
                     Found := (Row, I);
                     return True;
                  end if;
               end loop;
            end;
         end loop;
      else
         for Row in reverse 1 .. Start.Line loop
            declare
               L : constant Wide_Wide_String := Fold (B.Line (Row));
               Last_Col : constant Integer :=
                 (if Row = Start.Line then Start.Col - 1 else L'Last);
            begin
               for I in reverse 1 .. Integer'Min (Last_Col, L'Last) loop
                  if Match_At (L, I) then
                     Found := (Row, I);
                     return True;
                  end if;
               end loop;
            end;
         end loop;
      end if;
      return False;
   end Find;

end Turbo.Buffers;
