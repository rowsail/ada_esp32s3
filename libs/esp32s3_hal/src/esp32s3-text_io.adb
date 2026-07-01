with Ada.Unchecked_Deallocation;
with ESP32S3.Ext4;         --  moved here from the spec: the ext4 backing is a
with ESP32S3.Ext4.Inode;   --  body-only concern, so console-only clients of the
with ESP32S3.Ext4.VFS;     --  spec do not drag the filesystem into their closure.
with ESP32S3.Ext4.FS;
with ESP32S3.Serial;

package body ESP32S3.Text_IO is

   use ESP32S3.Ext4;
   use type ESP32S3.Ext4.U64;
   use type ESP32S3.Ext4.VFS.Mount_Ref;

   --  The control block carries everything mutable about an open file, so the
   --  File_Type handle (a pointer to it) lets every I/O op take File as `in`.
   type Control_Block is record
      Kind     : File_Kind                  := Closed;
      FS       : ESP32S3.Ext4.VFS.Mount_Ref := null;
      Node     : ESP32S3.Ext4.Inode_Number  := 0;
      Info     : ESP32S3.Ext4.Inode.Info;
      Mode     : File_Mode                  := In_File;
      Offset   : ESP32S3.Ext4.U64           := 0;
      Column   : Positive                   := 1;
      Line_No  : Positive                   := 1;
      Page_No  : Positive                   := 1;
      Line_Len : Natural                    := 0;   --  0 = unbounded (no wrap)
      Page_Len : Natural                    := 0;
      Sync     : Boolean                    := False;  --  commit after every write?
      Name_Len : Natural                    := 0;
      Name_Buf : String (1 .. Name_Max)     := (others => ' ');
      Form_Len : Natural                    := 0;
      Form_Buf : String (1 .. 64)           := (others => ' ');
      --  One-character pushback for CONSOLE input.  The console RX read is
      --  consuming (reading the FIFO pops a byte), but Peek must not consume, so
      --  a peeked console byte is stashed here until Advance consumes it.
      Have_LA  : Boolean                    := False;
      LA_Char  : Character                  := ASCII.NUL;
   end record;

   procedure Free is new Ada.Unchecked_Deallocation (Control_Block, CB_Access);

   Page_Mark : constant Character := ASCII.FF;

   Std_Out : aliased File_Type;
   Std_Err : aliased File_Type;
   Std_In  : aliased File_Type;
   Cur_Out : File_Access;
   Cur_Err : File_Access;
   Cur_In  : File_Access;

   function Standard_Output return File_Access is (Std_Out'Access);
   function Standard_Error  return File_Access is (Std_Err'Access);
   function Standard_Input  return File_Access is (Std_In'Access);
   function Current_Output  return File_Access is (Cur_Out);
   function Current_Error   return File_Access is (Cur_Err);
   function Current_Input   return File_Access is (Cur_In);
   procedure Set_Output (File : File_Access) is begin Cur_Out := File; end Set_Output;
   procedure Set_Error  (File : File_Access) is begin Cur_Err := File; end Set_Error;
   procedure Set_Input  (File : File_Access) is begin Cur_In  := File; end Set_Input;
   procedure Set_Output (File : File_Type) is
   begin Cur_Out := File'Unrestricted_Access; end Set_Output;
   procedure Set_Error (File : File_Type) is
   begin Cur_Err := File'Unrestricted_Access; end Set_Error;
   procedure Set_Input (File : File_Type) is
   begin Cur_In := File'Unrestricted_Access; end Set_Input;

   --  Reach the control block, raising Status_Error if the file is not open.
   function CB (File : File_Type) return CB_Access is
   begin
      if File.CB = null or else File.CB.Kind = Closed then
         raise ESP32S3.Ext4.Status_Error;
      end if;
      return File.CB;
   end CB;

   ----------------------------------------------------------------------------
   --  Low-level helpers
   ----------------------------------------------------------------------------

   function Spaces (N : Natural) return String is (1 .. N => ' ');

   function Digit_Val (C : Character) return Integer is
     (case C is
        when '0' .. '9' => Character'Pos (C) - Character'Pos ('0'),
        when 'A' .. 'F' => Character'Pos (C) - Character'Pos ('A') + 10,
        when 'a' .. 'f' => Character'Pos (C) - Character'Pos ('a') + 10,
        when others     => -1);

   procedure Require_Read (B : CB_Access) is
   begin
      --  Reading is allowed from a disk file OR the console, but only when the
      --  file was opened for input (Standard_Input is a Console/In_File file).
      if B.Mode /= In_File
        or else (B.Kind /= Disk and then B.Kind /= Console)
      then
         raise ESP32S3.Ext4.Mode_Error;
      end if;
   end Require_Read;

   --  Push raw bytes to the device (console -> Serial, disk -> Append). No
   --  position tracking; callers update Column/Line.
   procedure Raw_Write (B : CB_Access; S : String) is
   begin
      case B.Kind is
         when Console =>
            ESP32S3.Serial.Write (S);
         when Disk =>
            if B.Mode = In_File then raise ESP32S3.Ext4.Mode_Error; end if;
            declare
               Chunk : Byte_Array (0 .. 255);
               N     : Natural := 0;
            begin
               for I in S'Range loop
                  Chunk (N) := U8 (Character'Pos (S (I)));
                  N := N + 1;
                  if N = Chunk'Length then
                     B.FS.Append (B.Node, Chunk (0 .. N - 1)); N := 0;
                  end if;
               end loop;
               if N > 0 then B.FS.Append (B.Node, Chunk (0 .. N - 1)); end if;
            end;
            if B.Sync then B.FS.Commit; end if;   --  "sync=yes": durable per write
         when Closed =>
            raise ESP32S3.Ext4.Status_Error;
      end case;
   end Raw_Write;

   --  Emit one line terminator and advance the position.
   procedure Emit_New_Line (B : CB_Access) is
   begin
      Raw_Write (B, (1 => ASCII.LF));
      B.Column  := 1;
      B.Line_No := B.Line_No + 1;
   end Emit_New_Line;

   --  Write one character with auto-wrap (when Line_Len > 0) and tracking.
   procedure Put_Char (B : CB_Access; C : Character) is
   begin
      if C = ASCII.LF then
         Emit_New_Line (B);
      else
         if B.Line_Len > 0 and then B.Column > B.Line_Len then
            Emit_New_Line (B);
         end if;
         Raw_Write (B, (1 => C));
         B.Column := B.Column + 1;
      end if;
   end Put_Char;

   procedure Write_Tracked (B : CB_Access; S : String) is
   begin
      if B.Line_Len = 0 then
         --  Fast path: one device write, then bump the position by the content.
         Raw_Write (B, S);
         for I in S'Range loop
            if S (I) = ASCII.LF then
               B.Column := 1; B.Line_No := B.Line_No + 1;
            else
               B.Column := B.Column + 1;
            end if;
         end loop;
      else
         for I in S'Range loop
            Put_Char (B, S (I));
         end loop;
      end if;
   end Write_Tracked;

   --  Peek the next input byte without consuming it.  Non-blocking for BOTH
   --  backings: on the console it returns the pushback byte if one is stashed,
   --  otherwise it takes at most one byte off the RX FIFO and stashes it (so a
   --  later Advance consumes exactly that byte); Avail is False when the FIFO is
   --  momentarily empty.  Blocking input is layered on top (see Await).
   procedure Peek (B : CB_Access; C : out Character; Avail : out Boolean) is
      One : Byte_Array (0 .. 0);
      Cnt : Natural;
   begin
      if B.Kind = Console then
         if B.Have_LA then
            C := B.LA_Char; Avail := True;
         else
            ESP32S3.Serial.Get (C, Avail);
            if Avail then B.Have_LA := True; B.LA_Char := C; end if;
         end if;
         return;
      end if;
      if B.Offset >= B.Info.Size then
         C := ASCII.NUL; Avail := False; return;
      end if;
      B.FS.Read_File (B.Info, B.Offset, One, Cnt);
      if Cnt = 0 then
         C := ASCII.NUL; Avail := False;
      else
         C := Character'Val (Natural (One (0))); Avail := True;
      end if;
   end Peek;

   --  Bump the column / line / page counters for one consumed character.
   procedure Bump_Pos (B : CB_Access; C : Character) is
   begin
      if C = ASCII.LF then
         B.Column := 1; B.Line_No := B.Line_No + 1;
      elsif C = Page_Mark then
         B.Column := 1; B.Line_No := 1; B.Page_No := B.Page_No + 1;
      else
         B.Column := B.Column + 1;
      end if;
   end Bump_Pos;

   --  Consume the next input byte, tracking column / line / page.
   procedure Advance (B : CB_Access) is
      C : Character; Av : Boolean;
   begin
      if B.Kind = Console then
         --  Callers Peek (filling the pushback) before Advance; consume it.
         if not B.Have_LA then
            Peek (B, C, Av);
            if not Av then return;   --  nothing to consume
            end if;
         end if;
         Bump_Pos (B, B.LA_Char);
         B.Have_LA := False;
         return;
      end if;
      Peek (B, C, Av);
      if Av then Bump_Pos (B, C); end if;
      B.Offset := B.Offset + 1;
   end Advance;

   --  Blocking single-character console read: spin until a byte arrives, then
   --  consume it.  This is where console input BLOCKS (Peek itself never does),
   --  so an interactive Get / Get_Line waits for the user the way a terminal
   --  read would.  Used only for Console files; disk input has real EOF instead.
   procedure Await (B : CB_Access; C : out Character) is
      Av : Boolean;
   begin
      loop
         Peek (B, C, Av);
         exit when Av;
      end loop;
      Advance (B);
   end Await;

   procedure Skip_Blanks (B : CB_Access) is
      C : Character; Av : Boolean;
   begin
      loop
         Peek (B, C, Av);
         exit when not Av;
         exit when C /= ' ' and then C /= ASCII.HT
                   and then C /= ASCII.LF and then C /= ASCII.CR;
         Advance (B);
      end loop;
   end Skip_Blanks;

   function Get_Integer (B : CB_Access) return Long_Long_Integer is
      C    : Character; Av : Boolean;
      Neg  : Boolean := False;
      V    : Long_Long_Integer := 0;
      Base : Long_Long_Integer := 10;
   begin
      Require_Read (B);
      Skip_Blanks (B);
      Peek (B, C, Av);
      if Av and then (C = '-' or else C = '+') then Neg := C = '-'; Advance (B); end if;
      loop
         Peek (B, C, Av);
         exit when not Av or else Digit_Val (C) < 0 or else Digit_Val (C) > 9;
         V := V * 10 + Long_Long_Integer (Digit_Val (C));
         Advance (B);
      end loop;
      Peek (B, C, Av);
      if Av and then C = '#' then
         Base := V; V := 0; Advance (B);
         loop
            Peek (B, C, Av);
            exit when not Av or else C = '#';
            V := V * Base + Long_Long_Integer (Digit_Val (C));
            Advance (B);
         end loop;
         Peek (B, C, Av);
         if Av and then C = '#' then Advance (B); end if;
      end if;
      return (if Neg then -V else V);
   end Get_Integer;

   function Based_Image (V : Long_Long_Integer; Base : Number_Base) return String is
      Digs : constant String := "0123456789ABCDEF";
      Tmp  : String (1 .. 72);
      P    : Natural := Tmp'Last + 1;
      N    : Long_Long_Integer := abs V;
      Bv   : constant Long_Long_Integer := Long_Long_Integer (Base);
   begin
      loop
         P := P - 1;
         Tmp (P) := Digs (Integer (N mod Bv) + 1);
         N := N / Bv;
         exit when N = 0;
      end loop;
      declare
         Body_Str : constant String := Tmp (P .. Tmp'Last);
         Sign     : constant String := (if V < 0 then "-" else "");
      begin
         if Base = 10 then
            return Sign & Body_Str;
         else
            declare
               Pre : constant String :=
                 (if Base < 10
                  then (1 => Character'Val (Character'Pos ('0') + Base))
                  else "1" & (1 => Character'Val (Character'Pos ('0') + (Base - 10))));
            begin
               return Sign & Pre & "#" & Body_Str & "#";
            end;
         end if;
      end;
   end Based_Image;

   procedure Put_Number (B : CB_Access; S : String; Width : Field) is
   begin
      if Width > S'Length then
         Write_Tracked (B, Spaces (Width - S'Length) & S);   --  right-justify
      else
         Write_Tracked (B, S);
      end if;
   end Put_Number;

   --  Right-justify S into the whole of To (RM Put-to-String); Layout_Error if
   --  S does not fit.
   procedure Right_Justify (To : out String; S : String) is
   begin
      if S'Length > To'Length then raise Layout_Error; end if;
      To := Spaces (To'Length - S'Length) & S;
   end Right_Justify;

   --  Parse a signed integer (decimal, or Base#digits#) out of a String. Last is
   --  the index of the last character used; Data_Error if no number is present.
   procedure Scan_Integer (From : String; V : out Long_Long_Integer; Last : out Natural)
   is
      I       : Natural := From'First;
      Neg     : Boolean := False;
      Base    : Long_Long_Integer := 10;
      Started : Boolean := False;
   begin
      V := 0; Last := From'First - 1;
      while I <= From'Last and then (From (I) = ' ' or else From (I) = ASCII.HT) loop
         I := I + 1;
      end loop;
      if I <= From'Last and then (From (I) = '-' or else From (I) = '+') then
         Neg := From (I) = '-'; I := I + 1;
      end if;
      while I <= From'Last and then Digit_Val (From (I)) in 0 .. 9 loop
         V := V * 10 + Long_Long_Integer (Digit_Val (From (I)));
         Last := I; I := I + 1; Started := True;
      end loop;
      if I <= From'Last and then From (I) = '#' then
         Base := V; V := 0; Last := I; I := I + 1;
         while I <= From'Last and then From (I) /= '#' loop
            V := V * Base + Long_Long_Integer (Digit_Val (From (I)));
            Last := I; I := I + 1;
         end loop;
         if I <= From'Last and then From (I) = '#' then Last := I; end if;
         Started := True;
      end if;
      if not Started then raise ESP32S3.Ext4.Data_Error; end if;
      if Neg then V := -V; end if;
   end Scan_Integer;

   --  Build "[-]whole.frac" from a value pre-split into a non-negative integer
   --  part and an A-digit fractional part. Used by Fixed_IO / Decimal_IO.
   function Scaled_Image (Neg : Boolean; Whole, Frac : Long_Long_Integer; A : Field)
      return String
   is
      FS : String (1 .. A) := (others => '0');
      T  : Long_Long_Integer := Frac;
   begin
      for K in reverse FS'Range loop
         FS (K) := Character'Val (Character'Pos ('0') + Integer (T mod 10));
         T := T / 10;
      end loop;
      if A > 0 then
         return (if Neg then "-" else "") & Based_Image (Whole, 10) & "." & FS;
      else
         return (if Neg then "-" else "") & Based_Image (Whole, 10);
      end if;
   end Scaled_Image;

   --  Parse a real literal out of a String as mantissa M and power P (the value
   --  is +/- M * 10**P); Last is the index of the last character used.
   procedure Scan_Real_Str (From : String; M : out Long_Long_Integer; P : out Integer;
                            Neg : out Boolean; Last : out Natural)
   is
      I       : Natural := From'First;
      D       : Natural := 0;
      E       : Integer := 0;
      ENeg    : Boolean := False;
      Started : Boolean := False;
   begin
      M := 0; P := 0; Neg := False; Last := From'First - 1;
      while I <= From'Last and then (From (I) = ' ' or else From (I) = ASCII.HT) loop
         I := I + 1;
      end loop;
      if I <= From'Last and then (From (I) = '-' or else From (I) = '+') then
         Neg := From (I) = '-'; I := I + 1;
      end if;
      while I <= From'Last and then Digit_Val (From (I)) in 0 .. 9 loop
         M := M * 10 + Long_Long_Integer (Digit_Val (From (I)));
         Last := I; I := I + 1; Started := True;
      end loop;
      if I <= From'Last and then From (I) = '.' then
         Last := I; I := I + 1;
         while I <= From'Last and then Digit_Val (From (I)) in 0 .. 9 loop
            M := M * 10 + Long_Long_Integer (Digit_Val (From (I)));
            D := D + 1; Last := I; I := I + 1; Started := True;
         end loop;
      end if;
      if I <= From'Last and then (From (I) = 'e' or else From (I) = 'E') then
         I := I + 1;
         if I <= From'Last and then (From (I) = '-' or else From (I) = '+') then
            ENeg := From (I) = '-'; I := I + 1;
         end if;
         while I <= From'Last and then Digit_Val (From (I)) in 0 .. 9 loop
            E := E * 10 + Digit_Val (From (I)); Last := I; I := I + 1;
         end loop;
         if ENeg then E := -E; end if;
      end if;
      if not Started then raise ESP32S3.Ext4.Data_Error; end if;
      P := E - D;
   end Scan_Real_Str;

   --  Collect a numeric token from a file into Buf (sign, digits, '.', exponent).
   procedure Read_Number_Token (B : CB_Access; Buf : out String; Len : out Natural) is
      C  : Character; Av : Boolean;
      procedure Take is
      begin
         if Len < Buf'Length then Len := Len + 1; Buf (Buf'First + Len - 1) := C; end if;
         Advance (B);
      end Take;
   begin
      Require_Read (B);
      Skip_Blanks (B);
      Len := 0;
      Peek (B, C, Av);
      if Av and then (C = '-' or else C = '+') then Take; end if;
      loop
         Peek (B, C, Av);
         exit when not Av or else (Digit_Val (C) not in 0 .. 9 and then C /= '.');
         Take;
      end loop;
      Peek (B, C, Av);
      if Av and then (C = 'e' or else C = 'E') then
         Take;
         Peek (B, C, Av);
         if Av and then (C = '-' or else C = '+') then Take; end if;
         loop
            Peek (B, C, Av);
            exit when not Av or else Digit_Val (C) not in 0 .. 9;
            Take;
         end loop;
      end if;
   end Read_Number_Token;

   function To_Lower (S : String) return String is
      Case_Delta : constant := Character'Pos ('a') - Character'Pos ('A');
      R : String := S;
   begin
      for I in R'Range loop
         if R (I) in 'A' .. 'Z' then
            R (I) := Character'Val (Character'Pos (R (I)) + Case_Delta);
         end if;
      end loop;
      return R;
   end To_Lower;

   procedure Set_Name (B : CB_Access; Nm : String) is
      N : constant Natural := Natural'Min (Nm'Length, Name_Max);
   begin
      B.Name_Len := N;
      B.Name_Buf (1 .. N) := Nm (Nm'First .. Nm'First + N - 1);
   end Set_Name;

   procedure Set_Form (B : CB_Access; F : String) is
      N : constant Natural := Natural'Min (F'Length, B.Form_Buf'Length);
   begin
      B.Form_Len := N;
      B.Form_Buf (1 .. N) := F (F'First .. F'First + N - 1);
   end Set_Form;

   --  Validate an implementation-defined Form string and extract its options.
   --  Comma-separated tokens; "sync=yes" / "sync=no" recognised; "" allowed;
   --  anything else raises Use_Error.
   procedure Parse_Form (F : String; Sync : out Boolean) is
      I : Natural := F'First;
   begin
      Sync := False;
      while I <= F'Last loop
         declare
            J : Natural := I;
         begin
            while J <= F'Last and then F (J) /= ',' loop J := J + 1; end loop;
            declare
               A : Natural := I;
               Z : Natural := J - 1;
            begin
               while A <= Z and then F (A) = ' ' loop A := A + 1; end loop;
               while Z >= A and then F (Z) = ' ' loop Z := Z - 1; end loop;
               declare
                  Tok : constant String := F (A .. Z);
               begin
                  if    Tok = ""         then null;
                  elsif Tok = "sync=yes" then Sync := True;
                  elsif Tok = "sync=no"  then Sync := False;
                  else  raise ESP32S3.Ext4.Use_Error;
                  end if;
               end;
            end;
            I := J + 1;
         end;
      end loop;
   end Parse_Form;

   procedure Locate (Nm        : String;
                     FS        : out ESP32S3.Ext4.VFS.Mount_Ref;
                     Sub_First : out Natural;
                     Sub_Last  : out Natural)
   is
      Found, Is_Root : Boolean;
   begin
      ESP32S3.Ext4.VFS.Resolve (Nm, FS, Sub_First, Sub_Last, Found, Is_Root);
      if not Found or else FS = null then
         raise ESP32S3.Ext4.Name_Error;
      end if;
   end Locate;

   procedure Split (Path : String; Dir_Last, Name_First : out Natural) is
      L : Natural := Path'First;
   begin
      for I in Path'Range loop
         if Path (I) = '/' then L := I; end if;
      end loop;
      Name_First := L + 1;
      Dir_Last   := (if L = Path'First then Path'First else L - 1);
   end Split;

   --  Ensure a control block exists, freshly reset.
   procedure New_CB (File : in out File_Type) is
   begin
      if File.CB = null then
         File.CB := new Control_Block;
      else
         File.CB.all := (others => <>);   --  reset to defaults
      end if;
   end New_CB;

   procedure Open_For_Write (B : CB_Access; Nm : String;
                             Mode : File_Mode; Truncate : Boolean)
   is
      FS     : ESP32S3.Ext4.VFS.Mount_Ref;
      SF, SL : Natural;
   begin
      Locate (Nm, FS, SF, SL);
      declare
         Sub                  : constant String := Nm (SF .. SL);
         Dir_Last, Name_First : Natural;
         N                    : Inode_Number;
      begin
         begin
            N := FS.Lookup (Sub);
            if Truncate then FS.Truncate (N, 0); end if;
         exception
            when others =>
               Split (Sub, Dir_Last, Name_First);
               N := FS.Create_File
                      (Sub (Sub'First .. Dir_Last), Sub (Name_First .. Sub'Last));
         end;
         B.Kind := Disk; B.FS := FS; B.Node := N; B.Mode := Mode; B.Offset := 0;
      end;
      Set_Name (B, Nm);
   end Open_For_Write;

   ----------------------------------------------------------------------------
   --  File management
   ----------------------------------------------------------------------------

   procedure Create (File : in out File_Type; Name : String;
                     Mode : File_Mode := Out_File; Form : String := "")
   is
      Sync : Boolean;
   begin
      Parse_Form (Form, Sync);                     --  validate before creating
      New_CB (File);
      Open_For_Write (File.CB, Name,
                      (if Mode = In_File then Out_File else Mode), Truncate => True);
      File.CB.Sync := Sync;
      Set_Form (File.CB, Form);
   end Create;

   procedure Open (File : in out File_Type; Name : String; Mode : File_Mode;
                   Form : String := "")
   is
      FS     : ESP32S3.Ext4.VFS.Mount_Ref;
      SF, SL : Natural;
      Sync   : Boolean;
   begin
      Parse_Form (Form, Sync);                     --  validate before opening
      New_CB (File);
      case Mode is
         when In_File =>
            Locate (Name, FS, SF, SL);
            File.CB.Kind   := Disk;
            File.CB.FS     := FS;
            File.CB.Node   := FS.Lookup (Name (SF .. SL));
            FS.Stat (File.CB.Node, File.CB.Info);
            File.CB.Mode   := In_File;
            File.CB.Offset := 0;
            Set_Name (File.CB, Name);
         when Out_File =>
            Open_For_Write (File.CB, Name, Out_File, Truncate => True);
         when Append_File =>
            Open_For_Write (File.CB, Name, Append_File, Truncate => False);
      end case;
      File.CB.Sync := Sync;
      Set_Form (File.CB, Form);
   end Open;

   procedure Close_CB (B : CB_Access) is
   begin
      if B.Kind = Disk then
         if B.Mode /= In_File and then B.FS /= null then B.FS.Commit; end if;
      end if;
      B.Kind := Closed; B.FS := null;
   end Close_CB;

   procedure Close (File : in out File_Type) is
   begin
      if File.CB /= null then Close_CB (File.CB); end if;
   end Close;

   procedure Delete (File : in out File_Type) is
      B  : constant CB_Access := CB (File);
      Nm : constant String := B.Name_Buf (1 .. B.Name_Len);
      FS : ESP32S3.Ext4.VFS.Mount_Ref;
      SF, SL : Natural;
   begin
      if B.Kind /= Disk then
         raise ESP32S3.Ext4.Use_Error;     --  cannot delete the console
      end if;
      Close (File);                         --  close (commits any pending writes)
      Locate (Nm, FS, SF, SL);
      declare
         Sub                  : constant String := Nm (SF .. SL);
         Dir_Last, Name_First : Natural;
      begin
         Split (Sub, Dir_Last, Name_First);
         FS.Unlink (Sub (Sub'First .. Dir_Last), Sub (Name_First .. Sub'Last));
         FS.Commit;
      end;
   end Delete;

   procedure Reset (File : in out File_Type) is
      B : constant CB_Access := CB (File);
   begin
      if B.Kind = Disk and then B.Mode = In_File then
         B.FS.Stat (B.Node, B.Info);
         B.Offset := 0; B.Column := 1; B.Line_No := 1; B.Page_No := 1;
      end if;
   end Reset;

   --  Re-open the file with a new mode (e.g. an Out_File written then re-read as
   --  In_File), preserving its name and form. Console files just reset position.
   procedure Reset (File : in out File_Type; Mode : File_Mode) is
      B  : constant CB_Access := CB (File);
   begin
      if B.Kind /= Disk then
         B.Column := 1; B.Line_No := 1; B.Page_No := 1;
         return;
      end if;
      declare
         Nm : constant String := B.Name_Buf (1 .. B.Name_Len);
         Fm : constant String := B.Form_Buf (1 .. B.Form_Len);
      begin
         Close (File);
         Open (File, Nm, Mode, Fm);
      end;
   end Reset;

   function Is_Open (File : File_Type) return Boolean is
     (File.CB /= null and then File.CB.Kind /= Closed);
   function Mode (File : File_Type) return File_Mode is (CB (File).Mode);
   function Name (File : File_Type) return String is
     (CB (File).Name_Buf (1 .. CB (File).Name_Len));
   function Form (File : File_Type) return String is
     (CB (File).Form_Buf (1 .. CB (File).Form_Len));

   procedure Flush (File : File_Type) is
      B : constant CB_Access := CB (File);
   begin
      case B.Kind is
         when Console => ESP32S3.Serial.Flush;
         when Disk    =>
            if B.Mode /= In_File and then B.FS /= null then B.FS.Commit; end if;
         when Closed  => null;
      end case;
   end Flush;

   procedure Flush is begin Flush (Cur_Out.all); end Flush;

   ----------------------------------------------------------------------------
   --  Layout
   ----------------------------------------------------------------------------

   procedure Set_Line_Length (File : File_Type; To : Count) is
   begin CB (File).Line_Len := Natural (To); end Set_Line_Length;
   procedure Set_Line_Length (To : Count) is begin Set_Line_Length (Cur_Out.all, To); end Set_Line_Length;
   procedure Set_Page_Length (File : File_Type; To : Count) is
   begin CB (File).Page_Len := Natural (To); end Set_Page_Length;
   procedure Set_Page_Length (To : Count) is begin Set_Page_Length (Cur_Out.all, To); end Set_Page_Length;

   function Line_Length (File : File_Type) return Count is (Count (CB (File).Line_Len));
   function Line_Length return Count is (Line_Length (Cur_Out.all));
   function Page_Length (File : File_Type) return Count is (Count (CB (File).Page_Len));
   function Page_Length return Count is (Page_Length (Cur_Out.all));

   function Col  (File : File_Type) return Positive_Count is (Positive_Count (CB (File).Column));
   function Col  return Positive_Count is (Col (Cur_Out.all));
   function Line (File : File_Type) return Positive_Count is (Positive_Count (CB (File).Line_No));
   function Line return Positive_Count is (Line (Cur_Out.all));
   function Page (File : File_Type) return Positive_Count is (Positive_Count (CB (File).Page_No));
   function Page return Positive_Count is (Page (Cur_Out.all));

   procedure New_Line (File : File_Type; Spacing : Positive_Count := 1) is
      B : constant CB_Access := CB (File);
   begin
      for I in 1 .. Spacing loop
         Emit_New_Line (B);
      end loop;
   end New_Line;
   procedure New_Line (Spacing : Positive_Count := 1) is
   begin New_Line (Cur_Out.all, Spacing); end New_Line;

   procedure New_Page (File : File_Type) is
      B : constant CB_Access := CB (File);
   begin
      Raw_Write (B, (1 => Page_Mark));
      B.Column := 1; B.Line_No := 1; B.Page_No := B.Page_No + 1;
   end New_Page;
   procedure New_Page is begin New_Page (Cur_Out.all); end New_Page;

   procedure Set_Col (File : File_Type; To : Positive_Count) is
      B : constant CB_Access := CB (File);
      T : constant Positive := Positive (To);
   begin
      if B.Mode = In_File and then (B.Kind = Disk or else B.Kind = Console) then
         while B.Column < T loop                          --  input: skip forward
            declare C : Character; Av : Boolean; begin
               Peek (B, C, Av);
               exit when not Av or else C = ASCII.LF;
               Advance (B);
            end;
         end loop;
      else                                                --  output: pad with spaces
         if T > B.Column then
            Write_Tracked (B, Spaces (T - B.Column));
         elsif T < B.Column then
            Emit_New_Line (B);
            Write_Tracked (B, Spaces (T - 1));
         end if;
      end if;
   end Set_Col;
   procedure Set_Col (To : Positive_Count) is begin Set_Col (Cur_Out.all, To); end Set_Col;

   procedure Set_Line (File : File_Type; To : Positive_Count) is
      B : constant CB_Access := CB (File);
      T : constant Positive := Positive (To);
   begin
      if B.Mode = In_File and then (B.Kind = Disk or else B.Kind = Console) then
         --  Input: skip lines FORWARD until the line number reaches T (a stream
         --  has no backward seek; a target at/behind the current line is a no-op).
         --  A live console has no seekable line index, so it is a plain no-op.
         if B.Kind = Disk then
            while B.Line_No < T and then B.Offset < B.Info.Size loop
               Skip_Line (File);
            end loop;
         end if;
      elsif T > B.Line_No then
         New_Line (File, Positive_Count (T - B.Line_No));      --  forward
      elsif T < B.Line_No then
         New_Page (File);                                      --  can't go back:
         if T > 1 then                                         --  new page, then
            New_Line (File, Positive_Count (T - 1));           --  down to line T
         end if;
      end if;
   end Set_Line;
   procedure Set_Line (To : Positive_Count) is begin Set_Line (Cur_Out.all, To); end Set_Line;

   ----------------------------------------------------------------------------
   --  Character / string output
   ----------------------------------------------------------------------------

   procedure Put (File : File_Type; Item : Character) is
   begin Put_Char (CB (File), Item); end Put;
   procedure Put (Item : Character) is begin Put (Cur_Out.all, Item); end Put;

   procedure Put (File : File_Type; Item : String) is
   begin Write_Tracked (CB (File), Item); end Put;
   procedure Put (Item : String) is begin Put (Cur_Out.all, Item); end Put;

   procedure Put_Line (File : File_Type; Item : String) is
      B : constant CB_Access := CB (File);
   begin Write_Tracked (B, Item); Emit_New_Line (B); end Put_Line;
   procedure Put_Line (Item : String) is begin Put_Line (Cur_Out.all, Item); end Put_Line;

   ----------------------------------------------------------------------------
   --  Input
   ----------------------------------------------------------------------------

   procedure Get (File : File_Type; Item : out Character) is
      B : constant CB_Access := CB (File);
      C : Character; Av : Boolean;
   begin
      Require_Read (B);
      if B.Kind = Console then Await (B, Item); return; end if;
      Peek (B, C, Av);
      if not Av then raise ESP32S3.Ext4.End_Error; end if;
      Advance (B);
      Item := C;
   end Get;
   procedure Get (Item : out Character) is begin Get (Cur_In.all, Item); end Get;

   procedure Look_Ahead (File : File_Type; Item : out Character; End_Of_Line : out Boolean)
   is
      B : constant CB_Access := CB (File);
      C : Character; Av : Boolean;
   begin
      Require_Read (B);
      Peek (B, C, Av);
      if not Av or else C = ASCII.LF then
         End_Of_Line := True; Item := ' ';
      else
         End_Of_Line := False; Item := C;
      end if;
   end Look_Ahead;

   procedure Get_Immediate (File : File_Type; Item : out Character) is
      B : constant CB_Access := CB (File); C : Character; Av : Boolean;
   begin
      Require_Read (B);
      if B.Kind = Console then Await (B, Item); return; end if;
      Peek (B, C, Av);
      if not Av then raise ESP32S3.Ext4.End_Error; end if;
      Advance (B); Item := C;
   end Get_Immediate;
   procedure Get_Immediate (Item : out Character) is
   begin Get_Immediate (Cur_In.all, Item); end Get_Immediate;

   procedure Get_Immediate (File : File_Type; Item : out Character; Available : out Boolean)
   is
      B : constant CB_Access := CB (File); C : Character; Av : Boolean;
   begin
      Require_Read (B);
      Peek (B, C, Av);
      if Av then
         Advance (B); Item := C; Available := True;
      else
         Item := ASCII.NUL; Available := False;
      end if;
   end Get_Immediate;
   procedure Get_Immediate (Item : out Character; Available : out Boolean) is
   begin Get_Immediate (Cur_In.all, Item, Available); end Get_Immediate;

   --  Consume a trailing LF that pairs with a just-read CR (CR-LF line ends), so
   --  the next read does not see a stray empty line.  Console only; non-blocking.
   procedure Swallow_LF_After_CR (B : CB_Access) is
      C : Character; Av : Boolean;
   begin
      Peek (B, C, Av);
      if Av and then C = ASCII.LF then Advance (B); end if;
   end Swallow_LF_After_CR;

   procedure Get_Line (File : File_Type; Item : out String; Last : out Natural) is
      B : constant CB_Access := CB (File);
      C : Character; Av : Boolean;
   begin
      Require_Read (B);
      if B.Kind = Console then
         --  Interactive line read: block for characters until an end-of-line.
         --  Terminals over USB-serial/UART send CR (or CR-LF) for Enter, so treat
         --  CR and LF alike and absorb the LF of a CR-LF pair.
         Last := Item'First - 1;
         while Last < Item'Last loop
            Await (B, C);
            if C = ASCII.CR then Swallow_LF_After_CR (B); exit; end if;
            exit when C = ASCII.LF;
            Last := Last + 1;
            Item (Last) := C;
         end loop;
         return;
      end if;
      if B.Offset >= B.Info.Size then raise ESP32S3.Ext4.End_Error; end if;
      Last := Item'First - 1;
      while Last < Item'Last loop
         Peek (B, C, Av);
         exit when not Av;
         Advance (B);
         exit when C = ASCII.LF;
         Last := Last + 1;
         Item (Last) := C;
      end loop;
   end Get_Line;
   procedure Get_Line (Item : out String; Last : out Natural) is
   begin Get_Line (Cur_In.all, Item, Last); end Get_Line;

   function Get_Line (File : File_Type) return String is
      type Str_Ptr is access String;
      procedure Free is new Ada.Unchecked_Deallocation (String, Str_Ptr);
      B   : constant CB_Access := CB (File);
      Buf : Str_Ptr := new String (1 .. 64);
      Len : Natural := 0;
      C   : Character; Av : Boolean;
      Is_Con : constant Boolean := B.Kind = Console;
   begin
      Require_Read (B);
      if not Is_Con and then B.Offset >= B.Info.Size then
         Free (Buf); raise ESP32S3.Ext4.End_Error;
      end if;
      loop
         if Is_Con then
            Await (B, C);                    --  block for the next char
            if C = ASCII.CR then Swallow_LF_After_CR (B); exit; end if;
            exit when C = ASCII.LF;
         else
            Peek (B, C, Av);
            exit when not Av;
            Advance (B);
            exit when C = ASCII.LF;
         end if;
         if Len = Buf'Length then            --  grow (double)
            declare
               Bigger : constant Str_Ptr := new String (1 .. Buf'Length * 2);
            begin
               Bigger (1 .. Len) := Buf (1 .. Len);
               Free (Buf); Buf := Bigger;
            end;
         end if;
         Len := Len + 1; Buf (Len) := C;
      end loop;
      return R : constant String := Buf (1 .. Len) do
         Free (Buf);
      end return;
   end Get_Line;

   function Get_Line return String is (Get_Line (Cur_In.all));

   procedure Skip_Line (File : File_Type; Spacing : Positive_Count := 1) is
      B : constant CB_Access := CB (File);
      C : Character; Av : Boolean;
   begin
      Require_Read (B);
      if B.Kind = Console then
         for S in 1 .. Spacing loop
            loop
               Await (B, C);
               if C = ASCII.CR then Swallow_LF_After_CR (B); exit; end if;
               exit when C = ASCII.LF;
            end loop;
         end loop;
         return;
      end if;
      for S in 1 .. Spacing loop
         if B.Offset >= B.Info.Size then raise ESP32S3.Ext4.End_Error; end if;
         loop
            Peek (B, C, Av);
            exit when not Av;
            Advance (B);
            exit when C = ASCII.LF;
         end loop;
      end loop;
   end Skip_Line;
   procedure Skip_Line (Spacing : Positive_Count := 1) is
   begin Skip_Line (Cur_In.all, Spacing); end Skip_Line;

   procedure Skip_Page (File : File_Type) is
      B : constant CB_Access := CB (File);
      C : Character; Av : Boolean;
   begin
      Require_Read (B);
      loop
         Peek (B, C, Av);
         exit when not Av;
         Advance (B);
         exit when C = Page_Mark;
      end loop;
   end Skip_Page;
   procedure Skip_Page is begin Skip_Page (Cur_In.all); end Skip_Page;

   function End_Of_File (File : File_Type) return Boolean is
      B : constant CB_Access := CB (File);
   begin
      if B.Kind = Disk and then B.Mode = In_File then
         return B.Offset >= B.Info.Size;
      elsif B.Kind = Console and then B.Mode = In_File then
         return False;   --  the console is an endless stream: never at end-of-file
      else
         raise ESP32S3.Ext4.Mode_Error;
      end if;
   end End_Of_File;
   function End_Of_File return Boolean is (End_Of_File (Cur_In.all));

   function End_Of_Line (File : File_Type) return Boolean is
      B : constant CB_Access := CB (File);
      C : Character; Av : Boolean;
   begin
      Require_Read (B);
      Peek (B, C, Av);
      return (not Av) or else C = ASCII.LF;
   end End_Of_Line;
   function End_Of_Line return Boolean is (End_Of_Line (Cur_In.all));

   function End_Of_Page (File : File_Type) return Boolean is
      B : constant CB_Access := CB (File);
      C : Character; Av : Boolean;
   begin
      Require_Read (B);
      Peek (B, C, Av);
      return (not Av) or else C = Page_Mark;
   end End_Of_Page;
   function End_Of_Page return Boolean is (End_Of_Page (Cur_In.all));

   ----------------------------------------------------------------------------
   --  Numeric / enumeration generics
   ----------------------------------------------------------------------------

   package body Integer_IO is
      procedure Put (File : File_Type; Item : Num;
                     Width : Field := Default_Width; Base : Number_Base := Default_Base) is
      begin Put_Number (CB (File), Based_Image (Long_Long_Integer (Item), Base), Width); end Put;
      procedure Put (Item : Num;
                     Width : Field := Default_Width; Base : Number_Base := Default_Base) is
      begin Put (Cur_Out.all, Item, Width, Base); end Put;
      procedure Get (File : File_Type; Item : out Num) is
      begin Item := Num (Get_Integer (CB (File))); end Get;
      procedure Get (Item : out Num) is begin Get (Cur_In.all, Item); end Get;
      procedure Put (To : out String; Item : Num; Base : Number_Base := Default_Base) is
      begin Right_Justify (To, Based_Image (Long_Long_Integer (Item), Base)); end Put;
      procedure Get (From : String; Item : out Num; Last : out Positive) is
         V : Long_Long_Integer; L : Natural;
      begin Scan_Integer (From, V, L); Item := Num (V); Last := L; end Get;
   end Integer_IO;

   package body Modular_IO is
      procedure Put (File : File_Type; Item : Num;
                     Width : Field := Default_Width; Base : Number_Base := Default_Base) is
      begin Put_Number (CB (File), Based_Image (Long_Long_Integer (Item), Base), Width); end Put;
      procedure Put (Item : Num;
                     Width : Field := Default_Width; Base : Number_Base := Default_Base) is
      begin Put (Cur_Out.all, Item, Width, Base); end Put;
      procedure Get (File : File_Type; Item : out Num) is
      begin Item := Num (Get_Integer (CB (File))); end Get;
      procedure Get (Item : out Num) is begin Get (Cur_In.all, Item); end Get;
      procedure Put (To : out String; Item : Num; Base : Number_Base := Default_Base) is
      begin Right_Justify (To, Based_Image (Long_Long_Integer (Item), Base)); end Put;
      procedure Get (From : String; Item : out Num; Last : out Positive) is
         V : Long_Long_Integer; L : Natural;
      begin Scan_Integer (From, V, L); Item := Num (V); Last := L; end Get;
   end Modular_IO;

   package body Float_IO is

      --  Format Item with Aft fractional digits, rounded. Exp = 0 -> fixed point
      --  (sign + integer part + '.' + Aft digits). Exp > 0 -> scientific: a
      --  mantissa normalised to [1,10) + 'E' + signed exponent of >= Exp digits.
      function Float_Image (Item : Num; Aft : Field; Exp : Field) return String is
         A    : constant Field   := Field'Min (Aft, 18);
         Neg  : constant Boolean := Item < 0.0;
         Sign : constant String  := (if Neg then "-" else "");
         M    : Num := abs Item;

         function Frac_Digits (Frac : Num; Carry : out Boolean) return String is
            Scale : Long_Long_Integer := 1;
         begin
            for I in 1 .. A loop Scale := Scale * 10; end loop;
            declare
               Sd : Long_Long_Integer := Long_Long_Integer (Num'Rounding (Frac * Num (Scale)));
               R  : String (1 .. A) := (others => '0');
               T  : Long_Long_Integer;
            begin
               if Sd >= Scale then Carry := True; Sd := Sd - Scale; else Carry := False; end if;
               T := Sd;
               for K in reverse R'Range loop
                  R (K) := Character'Val (Character'Pos ('0') + Integer (T mod 10));
                  T := T / 10;
               end loop;
               return R;
            end;
         end Frac_Digits;

      begin
         if Exp = 0 then
            declare
               IP : Long_Long_Integer := Long_Long_Integer (Num'Truncation (M));
               Cy : Boolean;
               FS : constant String := Frac_Digits (M - Num (IP), Cy);
            begin
               if Cy then IP := IP + 1; end if;
               return Sign & Based_Image (IP, 10) & (if A > 0 then "." & FS else "");
            end;
         else
            declare
               E : Integer := 0;
            begin
               if M /= 0.0 then
                  while M >= 10.0 loop M := M / 10.0; E := E + 1; end loop;
                  while M < 1.0  loop M := M * 10.0; E := E - 1; end loop;
               end if;
               declare
                  Lead : Long_Long_Integer := Long_Long_Integer (Num'Truncation (M));
                  Cy   : Boolean;
                  FS   : constant String := Frac_Digits (M - Num (Lead), Cy);
               begin
                  if Cy then
                     Lead := Lead + 1;
                     if Lead >= 10 then Lead := 1; E := E + 1; end if;
                  end if;
                  declare
                     Mant  : constant String :=
                       Based_Image (Lead, 10) & (if A > 0 then "." & FS else "");
                     ESign : constant String := (if E < 0 then "-" else "+");
                     EDig  : constant String := Based_Image (Long_Long_Integer (abs E), 10);
                     EW    : constant Field  := Field'Max (Exp, 1);
                     EPad  : constant String :=
                       (if EDig'Length < EW then (1 .. EW - EDig'Length => '0') else "") & EDig;
                  begin
                     return Sign & Mant & "E" & ESign & EPad;
                  end;
               end;
            end;
         end if;
      end Float_Image;

      procedure Put (File : File_Type; Item : Num;
                     Fore : Field := Default_Fore; Aft : Field := Default_Aft;
                     Exp  : Field := Default_Exp)
      is
         B   : constant CB_Access := CB (File);
         S   : constant String    := Float_Image (Item, Aft, Exp);
         Dot : Natural := S'Last + 1;
      begin
         for I in S'Range loop
            if S (I) = '.' then Dot := I; exit; end if;
         end loop;
         declare
            Int_Len : constant Natural := Dot - S'First;     --  chars before the point
         begin
            if Fore > Int_Len then
               Write_Tracked (B, Spaces (Fore - Int_Len) & S);
            else
               Write_Tracked (B, S);
            end if;
         end;
      end Put;

      procedure Put (Item : Num;
                     Fore : Field := Default_Fore; Aft : Field := Default_Aft;
                     Exp  : Field := Default_Exp) is
      begin Put (Cur_Out.all, Item, Fore, Aft, Exp); end Put;

      procedure Put (To : out String; Item : Num;
                     Aft : Field := Default_Aft; Exp : Field := Default_Exp) is
      begin Right_Justify (To, Float_Image (Item, Aft, Exp)); end Put;

      procedure Get (File : File_Type; Item : out Num) is
         B   : constant CB_Access := CB (File);
         C   : Character; Av : Boolean;
         Neg : Boolean := False;
         V   : Num := 0.0;
      begin
         Require_Read (B);
         Skip_Blanks (B);
         Peek (B, C, Av);
         if Av and then (C = '-' or else C = '+') then Neg := C = '-'; Advance (B); end if;
         loop
            Peek (B, C, Av);
            exit when not Av or else Digit_Val (C) < 0 or else Digit_Val (C) > 9;
            V := V * 10.0 + Num (Digit_Val (C)); Advance (B);
         end loop;
         Peek (B, C, Av);
         if Av and then C = '.' then
            Advance (B);
            declare Scale : Num := 0.1; begin
               loop
                  Peek (B, C, Av);
                  exit when not Av or else Digit_Val (C) < 0 or else Digit_Val (C) > 9;
                  V := V + Num (Digit_Val (C)) * Scale; Scale := Scale / 10.0; Advance (B);
               end loop;
            end;
         end if;
         Peek (B, C, Av);
         if Av and then (C = 'e' or else C = 'E') then
            Advance (B);
            declare ENeg : Boolean := False; E : Natural := 0; begin
               Peek (B, C, Av);
               if Av and then (C = '-' or else C = '+') then ENeg := C = '-'; Advance (B); end if;
               loop
                  Peek (B, C, Av);
                  exit when not Av or else Digit_Val (C) < 0 or else Digit_Val (C) > 9;
                  E := E * 10 + Digit_Val (C); Advance (B);
               end loop;
               for I in 1 .. E loop
                  if ENeg then V := V / 10.0; else V := V * 10.0; end if;
               end loop;
            end;
         end if;
         Item := (if Neg then -V else V);
      end Get;
      procedure Get (Item : out Num) is begin Get (Cur_In.all, Item); end Get;

      procedure Get (From : String; Item : out Num; Last : out Positive) is
         I       : Natural := From'First;
         Neg     : Boolean := False;
         V       : Num     := 0.0;
         Started : Boolean := False;
         LN      : Natural := From'First - 1;
      begin
         while I <= From'Last and then (From (I) = ' ' or else From (I) = ASCII.HT) loop
            I := I + 1;
         end loop;
         if I <= From'Last and then (From (I) = '-' or else From (I) = '+') then
            Neg := From (I) = '-'; I := I + 1;
         end if;
         while I <= From'Last and then Digit_Val (From (I)) in 0 .. 9 loop
            V := V * 10.0 + Num (Digit_Val (From (I))); LN := I; I := I + 1; Started := True;
         end loop;
         if I <= From'Last and then From (I) = '.' then
            LN := I; I := I + 1;
            declare Scale : Num := 0.1; begin
               while I <= From'Last and then Digit_Val (From (I)) in 0 .. 9 loop
                  V := V + Num (Digit_Val (From (I))) * Scale; Scale := Scale / 10.0;
                  LN := I; I := I + 1; Started := True;
               end loop;
            end;
         end if;
         if I <= From'Last and then (From (I) = 'e' or else From (I) = 'E') then
            I := I + 1;
            declare ENeg : Boolean := False; E : Natural := 0; begin
               if I <= From'Last and then (From (I) = '-' or else From (I) = '+') then
                  ENeg := From (I) = '-'; I := I + 1;
               end if;
               while I <= From'Last and then Digit_Val (From (I)) in 0 .. 9 loop
                  E := E * 10 + Digit_Val (From (I)); LN := I; I := I + 1;
               end loop;
               for K in 1 .. E loop
                  if ENeg then V := V / 10.0; else V := V * 10.0; end if;
               end loop;
            end;
         end if;
         if not Started then raise ESP32S3.Ext4.Data_Error; end if;
         Item := (if Neg then -V else V);
         Last := LN;
      end Get;
   end Float_IO;

   package body Enumeration_IO is
      procedure Put (File : File_Type; Item : Enum;
                     Width : Field := Default_Width; Set : Type_Set := Default_Setting)
      is
         B   : constant CB_Access := CB (File);
         Img : constant String := Enum'Image (Item);
         S   : constant String := (if Set = Lower_Case then To_Lower (Img) else Img);
      begin
         if Width > S'Length then
            Write_Tracked (B, S & Spaces (Width - S'Length));   --  enums: left-justify
         else
            Write_Tracked (B, S);
         end if;
      end Put;
      procedure Put (Item : Enum;
                     Width : Field := Default_Width; Set : Type_Set := Default_Setting) is
      begin Put (Cur_Out.all, Item, Width, Set); end Put;

      procedure Get (File : File_Type; Item : out Enum) is
         B   : constant CB_Access := CB (File);
         C   : Character; Av : Boolean;
         Buf : String (1 .. 64); L : Natural := 0;
      begin
         Require_Read (B);
         Skip_Blanks (B);
         loop
            Peek (B, C, Av);
            exit when not Av;
            exit when C not in 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '_';
            if L < Buf'Last then L := L + 1; Buf (L) := C; end if;
            Advance (B);
         end loop;
         begin
            Item := Enum'Value (Buf (1 .. L));
         exception
            when others => raise ESP32S3.Ext4.Data_Error;
         end;
      end Get;
      procedure Get (Item : out Enum) is begin Get (Cur_In.all, Item); end Get;
   end Enumeration_IO;

   package body Fixed_IO is
      function Image (Item : Num; Aft : Field) return String is
         A      : constant Field      := Field'Min (Aft, 15);
         Neg    : constant Boolean    := Item < 0.0;
         X      : constant Long_Float := abs (Long_Float (Item));  --  range-safe
         FScale : Long_Float          := 1.0;
         IScale : Long_Long_Integer   := 1;
      begin
         for I in 1 .. A loop FScale := FScale * 10.0; IScale := IScale * 10; end loop;
         declare
            Scaled : constant Long_Long_Integer :=
              Long_Long_Integer (Long_Float'Rounding (X * FScale));
         begin
            return Scaled_Image (Neg, Scaled / IScale, Scaled mod IScale, A);
         end;
      end Image;

      procedure Set_Value (Item : out Num; M : Long_Long_Integer; P : Integer; Neg : Boolean) is
         X : Long_Float := Long_Float (M);
      begin
         if P >= 0 then
            for I in 1 .. P loop X := X * 10.0; end loop;
         else
            for I in 1 .. (-P) loop X := X / 10.0; end loop;
         end if;
         Item := Num (if Neg then -X else X);   --  range-checked at the end
      end Set_Value;

      procedure Put (File : File_Type; Item : Num;
                     Fore : Field := Default_Fore; Aft : Field := Default_Aft;
                     Exp  : Field := Default_Exp)
      is
         pragma Unreferenced (Exp);
         B   : constant CB_Access := CB (File);
         S   : constant String    := Image (Item, Aft);
         Dot : Natural := S'Last + 1;
      begin
         for I in S'Range loop if S (I) = '.' then Dot := I; exit; end if; end loop;
         declare Int_Len : constant Natural := Dot - S'First; begin
            if Fore > Int_Len then Write_Tracked (B, Spaces (Fore - Int_Len) & S);
            else Write_Tracked (B, S); end if;
         end;
      end Put;
      procedure Put (Item : Num; Fore : Field := Default_Fore; Aft : Field := Default_Aft;
                     Exp : Field := Default_Exp) is
      begin Put (Cur_Out.all, Item, Fore, Aft, Exp); end Put;
      procedure Put (To : out String; Item : Num; Aft : Field := Default_Aft;
                     Exp : Field := Default_Exp) is
         pragma Unreferenced (Exp);
      begin Right_Justify (To, Image (Item, Aft)); end Put;

      procedure Get (File : File_Type; Item : out Num) is
         B   : constant CB_Access := CB (File);
         Buf : String (1 .. 40); Len : Natural;
         M   : Long_Long_Integer; P : Integer; Neg : Boolean; L : Natural;
      begin
         Read_Number_Token (B, Buf, Len);
         Scan_Real_Str (Buf (1 .. Len), M, P, Neg, L);
         Set_Value (Item, M, P, Neg);
      end Get;
      procedure Get (Item : out Num) is begin Get (Cur_In.all, Item); end Get;
      procedure Get (From : String; Item : out Num; Last : out Positive) is
         M : Long_Long_Integer; P : Integer; Neg : Boolean; L : Natural;
      begin
         Scan_Real_Str (From, M, P, Neg, L);
         Set_Value (Item, M, P, Neg); Last := L;
      end Get;
   end Fixed_IO;

   package body Decimal_IO is
      function Image (Item : Num; Aft : Field) return String is
         A      : constant Field      := Field'Min (Aft, 15);
         Neg    : constant Boolean    := Item < 0.0;
         X      : constant Long_Float := abs (Long_Float (Item));  --  range-safe
         FScale : Long_Float          := 1.0;
         IScale : Long_Long_Integer   := 1;
      begin
         for I in 1 .. A loop FScale := FScale * 10.0; IScale := IScale * 10; end loop;
         declare
            Scaled : constant Long_Long_Integer :=
              Long_Long_Integer (Long_Float'Rounding (X * FScale));
         begin
            return Scaled_Image (Neg, Scaled / IScale, Scaled mod IScale, A);
         end;
      end Image;

      procedure Set_Value (Item : out Num; M : Long_Long_Integer; P : Integer; Neg : Boolean) is
         X : Long_Float := Long_Float (M);
      begin
         if P >= 0 then
            for I in 1 .. P loop X := X * 10.0; end loop;
         else
            for I in 1 .. (-P) loop X := X / 10.0; end loop;
         end if;
         Item := Num (if Neg then -X else X);   --  range-checked at the end
      end Set_Value;

      procedure Put (File : File_Type; Item : Num;
                     Fore : Field := Default_Fore; Aft : Field := Default_Aft;
                     Exp  : Field := Default_Exp)
      is
         pragma Unreferenced (Exp);
         B   : constant CB_Access := CB (File);
         S   : constant String    := Image (Item, Aft);
         Dot : Natural := S'Last + 1;
      begin
         for I in S'Range loop if S (I) = '.' then Dot := I; exit; end if; end loop;
         declare Int_Len : constant Natural := Dot - S'First; begin
            if Fore > Int_Len then Write_Tracked (B, Spaces (Fore - Int_Len) & S);
            else Write_Tracked (B, S); end if;
         end;
      end Put;
      procedure Put (Item : Num; Fore : Field := Default_Fore; Aft : Field := Default_Aft;
                     Exp : Field := Default_Exp) is
      begin Put (Cur_Out.all, Item, Fore, Aft, Exp); end Put;
      procedure Put (To : out String; Item : Num; Aft : Field := Default_Aft;
                     Exp : Field := Default_Exp) is
         pragma Unreferenced (Exp);
      begin Right_Justify (To, Image (Item, Aft)); end Put;

      procedure Get (File : File_Type; Item : out Num) is
         B   : constant CB_Access := CB (File);
         Buf : String (1 .. 40); Len : Natural;
         M   : Long_Long_Integer; P : Integer; Neg : Boolean; L : Natural;
      begin
         Read_Number_Token (B, Buf, Len);
         Scan_Real_Str (Buf (1 .. Len), M, P, Neg, L);
         Set_Value (Item, M, P, Neg);
      end Get;
      procedure Get (Item : out Num) is begin Get (Cur_In.all, Item); end Get;
      procedure Get (From : String; Item : out Num; Last : out Positive) is
         M : Long_Long_Integer; P : Integer; Neg : Boolean; L : Natural;
      begin
         Scan_Real_Str (From, M, P, Neg, L);
         Set_Value (Item, M, P, Neg); Last := L;
      end Get;
   end Decimal_IO;

   ----------------------------------------------------------------------------
   --  Finalization
   ----------------------------------------------------------------------------

   overriding procedure Finalize (File : in out File_Type) is
   begin
      if File.CB /= null then
         begin
            Close_CB (File.CB);
         exception
            when others => null;
         end;
         Free (File.CB);
      end if;
   end Finalize;

begin
   Std_Out.CB := new Control_Block'(Kind => Console, Mode => Out_File, others => <>);
   Std_Err.CB := new Control_Block'(Kind => Console, Mode => Out_File, others => <>);
   Std_In.CB  := new Control_Block'(Kind => Console, Mode => In_File,  others => <>);
   Cur_Out := Std_Out'Access;
   Cur_Err := Std_Err'Access;
   Cur_In  := Std_In'Access;
end ESP32S3.Text_IO;
