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
      Kind     : File_Kind := Closed;
      FS       : ESP32S3.Ext4.VFS.Mount_Ref := null;
      Node     : ESP32S3.Ext4.Inode_Number := 0;
      Info     : ESP32S3.Ext4.Inode.Info;
      Mode     : File_Mode := In_File;
      Offset   : ESP32S3.Ext4.U64 := 0;
      Column   : Positive := 1;
      Line_No  : Positive := 1;
      Page_No  : Positive := 1;
      Line_Len : Natural := 0;   --  0 = unbounded (no wrap)
      Page_Len : Natural := 0;
      Sync     : Boolean := False;  --  commit after every write?
      Name_Len : Natural := 0;
      Name_Buf : String (1 .. Name_Max) := (others => ' ');
      Form_Len : Natural := 0;
      Form_Buf : String (1 .. 64) := (others => ' ');
      --  One-character pushback for CONSOLE input.  The console RX read is
      --  consuming (reading the FIFO pops a byte), but Peek must not consume, so
      --  a peeked console byte is stashed here until Advance consumes it.
      Have_LA  : Boolean := False;
      LA_Char  : Character := ASCII.NUL;
   end record;

   procedure Free is new Ada.Unchecked_Deallocation (Control_Block, CB_Access);

   Page_Mark : constant Character := ASCII.FF;

   Std_Out : aliased File_Type;
   Std_Err : aliased File_Type;
   Std_In  : aliased File_Type;
   Cur_Out : File_Access;
   Cur_Err : File_Access;
   Cur_In  : File_Access;

   function Standard_Output return File_Access
   is (Std_Out'Access);
   function Standard_Error return File_Access
   is (Std_Err'Access);
   function Standard_Input return File_Access
   is (Std_In'Access);
   function Current_Output return File_Access
   is (Cur_Out);
   function Current_Error return File_Access
   is (Cur_Err);
   function Current_Input return File_Access
   is (Cur_In);
   procedure Set_Output (File : File_Access) is
   begin
      Cur_Out := File;
   end Set_Output;
   procedure Set_Error (File : File_Access) is
   begin
      Cur_Err := File;
   end Set_Error;
   procedure Set_Input (File : File_Access) is
   begin
      Cur_In := File;
   end Set_Input;
   procedure Set_Output (File : File_Type) is
   begin
      Cur_Out := File'Unrestricted_Access;
   end Set_Output;
   procedure Set_Error (File : File_Type) is
   begin
      Cur_Err := File'Unrestricted_Access;
   end Set_Error;
   procedure Set_Input (File : File_Type) is
   begin
      Cur_In := File'Unrestricted_Access;
   end Set_Input;

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

   function Spaces (N : Natural) return String
   is (1 .. N => ' ');

   function Digit_Val (Ch : Character) return Integer
   is (case Ch is
         when '0' .. '9' => Character'Pos (Ch) - Character'Pos ('0'),
         when 'A' .. 'F' => Character'Pos (Ch) - Character'Pos ('A') + 10,
         when 'a' .. 'f' => Character'Pos (Ch) - Character'Pos ('a') + 10,
         when others     => -1);

   procedure Require_Read (Block : CB_Access) is
   begin
      --  Reading is allowed from a disk file OR the console, but only when the
      --  file was opened for input (Standard_Input is a Console/In_File file).
      if Block.Mode /= In_File or else (Block.Kind /= Disk and then Block.Kind /= Console) then
         raise ESP32S3.Ext4.Mode_Error;
      end if;
   end Require_Read;

   --  Push raw bytes to the device (console -> Serial, disk -> Append). No
   --  position tracking; callers update Column/Line.
   procedure Raw_Write (Block : CB_Access; Text : String) is
   begin
      case Block.Kind is
         when Console =>
            ESP32S3.Serial.Write (Text);

         when Disk    =>
            if Block.Mode = In_File then
               raise ESP32S3.Ext4.Mode_Error;
            end if;
            declare
               Chunk    : Byte_Array (0 .. 255);
               Buffered : Natural := 0;
            begin
               for I in Text'Range loop
                  Chunk (Buffered) := U8 (Character'Pos (Text (I)));
                  Buffered := Buffered + 1;
                  if Buffered = Chunk'Length then
                     Block.FS.Append (Block.Node, Chunk (0 .. Buffered - 1));
                     Buffered := 0;
                  end if;
               end loop;
               if Buffered > 0 then
                  Block.FS.Append (Block.Node, Chunk (0 .. Buffered - 1));
               end if;
            end;
            if Block.Sync then
               Block.FS.Commit;
            end if;   --  "sync=yes": durable per write

         when Closed  =>
            raise ESP32S3.Ext4.Status_Error;
      end case;
   end Raw_Write;

   --  Emit one line terminator and advance the position.
   procedure Emit_New_Line (Block : CB_Access) is
   begin
      Raw_Write (Block, (1 => ASCII.LF));
      Block.Column := 1;
      Block.Line_No := Block.Line_No + 1;
   end Emit_New_Line;

   --  Write one character with auto-wrap (when Line_Len > 0) and tracking.
   procedure Put_Char (Block : CB_Access; Ch : Character) is
   begin
      if Ch = ASCII.LF then
         Emit_New_Line (Block);
      else
         if Block.Line_Len > 0 and then Block.Column > Block.Line_Len then
            Emit_New_Line (Block);
         end if;
         Raw_Write (Block, (1 => Ch));
         Block.Column := Block.Column + 1;
      end if;
   end Put_Char;

   procedure Write_Tracked (Block : CB_Access; Text : String) is
   begin
      if Block.Line_Len = 0 then
         --  Fast path: one device write, then bump the position by the content.
         Raw_Write (Block, Text);
         for I in Text'Range loop
            if Text (I) = ASCII.LF then
               Block.Column := 1;
               Block.Line_No := Block.Line_No + 1;
            else
               Block.Column := Block.Column + 1;
            end if;
         end loop;
      else
         for I in Text'Range loop
            Put_Char (Block, Text (I));
         end loop;
      end if;
   end Write_Tracked;

   --  Peek the next input byte without consuming it.  Non-blocking for BOTH
   --  backings: on the console it returns the pushback byte if one is stashed,
   --  otherwise it takes at most one byte off the RX FIFO and stashes it (so a
   --  later Advance consumes exactly that byte); Avail is False when the FIFO is
   --  momentarily empty.  Blocking input is layered on top (see Await).
   procedure Peek (Block : CB_Access; Ch : out Character; Avail : out Boolean) is
      One_Byte   : Byte_Array (0 .. 0);
      Read_Count : Natural;
   begin
      if Block.Kind = Console then
         if Block.Have_LA then
            Ch := Block.LA_Char;
            Avail := True;
         else
            ESP32S3.Serial.Get (Ch, Avail);
            if Avail then
               Block.Have_LA := True;
               Block.LA_Char := Ch;
            end if;
         end if;
         return;
      end if;
      if Block.Offset >= Block.Info.Size then
         Ch := ASCII.NUL;
         Avail := False;
         return;
      end if;
      Block.FS.Read_File (Block.Info, Block.Offset, One_Byte, Read_Count);
      if Read_Count = 0 then
         Ch := ASCII.NUL;
         Avail := False;
      else
         Ch := Character'Val (Natural (One_Byte (0)));
         Avail := True;
      end if;
   end Peek;

   --  Bump the column / line / page counters for one consumed character.
   procedure Bump_Pos (Block : CB_Access; Ch : Character) is
   begin
      if Ch = ASCII.LF then
         Block.Column := 1;
         Block.Line_No := Block.Line_No + 1;
      elsif Ch = Page_Mark then
         Block.Column := 1;
         Block.Line_No := 1;
         Block.Page_No := Block.Page_No + 1;
      else
         Block.Column := Block.Column + 1;
      end if;
   end Bump_Pos;

   --  Consume the next input byte, tracking column / line / page.
   procedure Advance (Block : CB_Access) is
      Ch    : Character;
      Avail : Boolean;
   begin
      if Block.Kind = Console then
         --  Callers Peek (filling the pushback) before Advance; consume it.
         if not Block.Have_LA then
            Peek (Block, Ch, Avail);
            if not Avail then
               return;   --  nothing to consume

            end if;
         end if;
         Bump_Pos (Block, Block.LA_Char);
         Block.Have_LA := False;
         return;
      end if;
      Peek (Block, Ch, Avail);
      if Avail then
         Bump_Pos (Block, Ch);
      end if;
      Block.Offset := Block.Offset + 1;
   end Advance;

   --  Blocking single-character console read: spin until a byte arrives, then
   --  consume it.  This is where console input BLOCKS (Peek itself never does),
   --  so an interactive Get / Get_Line waits for the user the way a terminal
   --  read would.  Used only for Console files; disk input has real EOF instead.
   procedure Await (Block : CB_Access; Ch : out Character) is
      Avail : Boolean;
   begin
      loop
         Peek (Block, Ch, Avail);
         exit when Avail;
      end loop;
      Advance (Block);
   end Await;

   --  Blocking peek: on a console, spin until a byte is available and return it
   --  WITHOUT consuming (it stays in the pushback for the next Advance).  This is
   --  how the token Gets (integer / real / num / enum) wait for interactive input
   --  the way Ada's Integer_IO.Get blocks -- a human types a digit every ~100 ms,
   --  far slower than the read loop, so a non-blocking peek would truncate the
   --  token after its first character.  On a disk file it is exactly Peek (real
   --  EOF, no spin), so disk parsing is byte-for-byte unchanged.
   procedure Peek_Wait (Block : CB_Access; Ch : out Character; Avail : out Boolean) is
   begin
      if Block.Kind = Console then
         loop
            Peek (Block, Ch, Avail);
            exit when Avail;
         end loop;
      else
         Peek (Block, Ch, Avail);
      end if;
   end Peek_Wait;

   procedure Skip_Blanks (Block : CB_Access) is
      Ch    : Character;
      Avail : Boolean;
   begin
      loop
         Peek_Wait (Block, Ch, Avail);
         exit when not Avail;
         exit when
           Ch /= ' ' and then Ch /= ASCII.HT and then Ch /= ASCII.LF and then Ch /= ASCII.CR;
         Advance (Block);
      end loop;
   end Skip_Blanks;

   function Get_Integer (Block : CB_Access) return Long_Long_Integer is
      Ch       : Character;
      Avail    : Boolean;
      Negative : Boolean := False;
      Value    : Long_Long_Integer := 0;
      Base     : Long_Long_Integer := 10;
   begin
      Require_Read (Block);
      Skip_Blanks (Block);
      Peek_Wait (Block, Ch, Avail);
      if Avail and then (Ch = '-' or else Ch = '+') then
         Negative := Ch = '-';
         Advance (Block);
      end if;
      loop
         Peek_Wait (Block, Ch, Avail);
         exit when not Avail or else Digit_Val (Ch) < 0 or else Digit_Val (Ch) > 9;
         Value := Value * 10 + Long_Long_Integer (Digit_Val (Ch));
         Advance (Block);
      end loop;
      Peek_Wait (Block, Ch, Avail);
      if Avail and then Ch = '#' then
         Base := Value;
         Value := 0;
         Advance (Block);
         loop
            Peek_Wait (Block, Ch, Avail);
            exit when not Avail or else Ch = '#';
            Value := Value * Base + Long_Long_Integer (Digit_Val (Ch));
            Advance (Block);
         end loop;
         Peek_Wait (Block, Ch, Avail);
         if Avail and then Ch = '#' then
            Advance (Block);
         end if;
      end if;
      return (if Negative then -Value else Value);
   end Get_Integer;

   function Based_Image (Value : Long_Long_Integer; Base : Number_Base) return String is
      Digit_Chars : constant String := "0123456789ABCDEF";
      Buffer      : String (1 .. 72);
      Pos         : Natural := Buffer'Last + 1;
      Remaining   : Long_Long_Integer := abs Value;
      Base_Value  : constant Long_Long_Integer := Long_Long_Integer (Base);
   begin
      loop
         Pos := Pos - 1;
         Buffer (Pos) := Digit_Chars (Integer (Remaining mod Base_Value) + 1);
         Remaining := Remaining / Base_Value;
         exit when Remaining = 0;
      end loop;
      declare
         Body_Str : constant String := Buffer (Pos .. Buffer'Last);
         Sign     : constant String := (if Value < 0 then "-" else "");
      begin
         if Base = 10 then
            return Sign & Body_Str;
         else
            declare
               Prefix : constant String :=
                 (if Base < 10
                  then (1 => Character'Val (Character'Pos ('0') + Base))
                  else "1" & (1 => Character'Val (Character'Pos ('0') + (Base - 10))));
            begin
               return Sign & Prefix & "#" & Body_Str & "#";
            end;
         end if;
      end;
   end Based_Image;

   procedure Put_Number (Block : CB_Access; Str : String; Width : Field) is
   begin
      if Width > Str'Length then
         Write_Tracked (Block, Spaces (Width - Str'Length) & Str);   --  right-justify

      else
         Write_Tracked (Block, Str);
      end if;
   end Put_Number;

   --  Right-justify S into the whole of To (RM Put-to-String); Layout_Error if
   --  S does not fit.
   procedure Right_Justify (To : out String; Str : String) is
   begin
      if Str'Length > To'Length then
         raise Layout_Error;
      end if;
      To := Spaces (To'Length - Str'Length) & Str;
   end Right_Justify;

   --  Parse a signed integer (decimal, or Base#digits#) out of a String. Last is
   --  the index of the last character used; Data_Error if no number is present.
   procedure Scan_Integer (From : String; Value : out Long_Long_Integer; Last : out Natural) is
      I        : Natural := From'First;
      Negative : Boolean := False;
      Base     : Long_Long_Integer := 10;
      Started  : Boolean := False;
   begin
      Value := 0;
      Last := From'First - 1;
      while I <= From'Last and then (From (I) = ' ' or else From (I) = ASCII.HT) loop
         I := I + 1;
      end loop;
      if I <= From'Last and then (From (I) = '-' or else From (I) = '+') then
         Negative := From (I) = '-';
         I := I + 1;
      end if;
      while I <= From'Last and then Digit_Val (From (I)) in 0 .. 9 loop
         Value := Value * 10 + Long_Long_Integer (Digit_Val (From (I)));
         Last := I;
         I := I + 1;
         Started := True;
      end loop;
      if I <= From'Last and then From (I) = '#' then
         Base := Value;
         Value := 0;
         Last := I;
         I := I + 1;
         while I <= From'Last and then From (I) /= '#' loop
            Value := Value * Base + Long_Long_Integer (Digit_Val (From (I)));
            Last := I;
            I := I + 1;
         end loop;
         if I <= From'Last and then From (I) = '#' then
            Last := I;
         end if;
         Started := True;
      end if;
      if not Started then
         raise ESP32S3.Ext4.Data_Error;
      end if;
      if Negative then
         Value := -Value;
      end if;
   end Scan_Integer;

   --  Build "[-]whole.frac" from a value pre-split into a non-negative integer
   --  part and an A-digit fractional part. Used by Fixed_IO / Decimal_IO.
   function Scaled_Image
     (Negative : Boolean; Whole, Frac : Long_Long_Integer; Aft : Field) return String
   is
      Frac_Str : String (1 .. Aft) := (others => '0');
      Temp     : Long_Long_Integer := Frac;
   begin
      for K in reverse Frac_Str'Range loop
         Frac_Str (K) := Character'Val (Character'Pos ('0') + Integer (Temp mod 10));
         Temp := Temp / 10;
      end loop;
      if Aft > 0 then
         return (if Negative then "-" else "") & Based_Image (Whole, 10) & "." & Frac_Str;
      else
         return (if Negative then "-" else "") & Based_Image (Whole, 10);
      end if;
   end Scaled_Image;

   --  Parse a real literal out of a String as mantissa M and power P (the value
   --  is +/- M * 10**P); Last is the index of the last character used.
   procedure Scan_Real_Str
     (From     : String;
      Mantissa : out Long_Long_Integer;
      Power    : out Integer;
      Negative : out Boolean;
      Last     : out Natural)
   is
      I            : Natural := From'First;
      Frac_Count   : Natural := 0;
      Exponent     : Integer := 0;
      Exp_Negative : Boolean := False;
      Started      : Boolean := False;
   begin
      Mantissa := 0;
      Power := 0;
      Negative := False;
      Last := From'First - 1;
      while I <= From'Last and then (From (I) = ' ' or else From (I) = ASCII.HT) loop
         I := I + 1;
      end loop;
      if I <= From'Last and then (From (I) = '-' or else From (I) = '+') then
         Negative := From (I) = '-';
         I := I + 1;
      end if;
      while I <= From'Last and then Digit_Val (From (I)) in 0 .. 9 loop
         Mantissa := Mantissa * 10 + Long_Long_Integer (Digit_Val (From (I)));
         Last := I;
         I := I + 1;
         Started := True;
      end loop;
      if I <= From'Last and then From (I) = '.' then
         Last := I;
         I := I + 1;
         while I <= From'Last and then Digit_Val (From (I)) in 0 .. 9 loop
            Mantissa := Mantissa * 10 + Long_Long_Integer (Digit_Val (From (I)));
            Frac_Count := Frac_Count + 1;
            Last := I;
            I := I + 1;
            Started := True;
         end loop;
      end if;
      if I <= From'Last and then (From (I) = 'e' or else From (I) = 'E') then
         I := I + 1;
         if I <= From'Last and then (From (I) = '-' or else From (I) = '+') then
            Exp_Negative := From (I) = '-';
            I := I + 1;
         end if;
         while I <= From'Last and then Digit_Val (From (I)) in 0 .. 9 loop
            Exponent := Exponent * 10 + Digit_Val (From (I));
            Last := I;
            I := I + 1;
         end loop;
         if Exp_Negative then
            Exponent := -Exponent;
         end if;
      end if;
      if not Started then
         raise ESP32S3.Ext4.Data_Error;
      end if;
      Power := Exponent - Frac_Count;
   end Scan_Real_Str;

   --  Collect a numeric token from a file into Buf (sign, digits, '.', exponent).
   procedure Read_Number_Token (Block : CB_Access; Buf : out String; Len : out Natural) is
      Ch    : Character;
      Avail : Boolean;
      procedure Take is
      begin
         if Len < Buf'Length then
            Len := Len + 1;
            Buf (Buf'First + Len - 1) := Ch;
         end if;
         Advance (Block);
      end Take;
   begin
      Require_Read (Block);
      Skip_Blanks (Block);
      Len := 0;
      Peek_Wait (Block, Ch, Avail);
      if Avail and then (Ch = '-' or else Ch = '+') then
         Take;
      end if;
      loop
         Peek_Wait (Block, Ch, Avail);
         exit when not Avail or else (Digit_Val (Ch) not in 0 .. 9 and then Ch /= '.');
         Take;
      end loop;
      Peek_Wait (Block, Ch, Avail);
      if Avail and then (Ch = 'e' or else Ch = 'E') then
         Take;
         Peek_Wait (Block, Ch, Avail);
         if Avail and then (Ch = '-' or else Ch = '+') then
            Take;
         end if;
         loop
            Peek_Wait (Block, Ch, Avail);
            exit when not Avail or else Digit_Val (Ch) not in 0 .. 9;
            Take;
         end loop;
      end if;
   end Read_Number_Token;

   function To_Lower (Str : String) return String is
      Case_Delta : constant := Character'Pos ('a') - Character'Pos ('A');
      Result     : String := Str;
   begin
      for I in Result'Range loop
         if Result (I) in 'A' .. 'Z' then
            Result (I) := Character'Val (Character'Pos (Result (I)) + Case_Delta);
         end if;
      end loop;
      return Result;
   end To_Lower;

   procedure Set_Name (Block : CB_Access; Name_Str : String) is
      Copy_Len : constant Natural := Natural'Min (Name_Str'Length, Name_Max);
   begin
      Block.Name_Len := Copy_Len;
      Block.Name_Buf (1 .. Copy_Len) := Name_Str (Name_Str'First .. Name_Str'First + Copy_Len - 1);
   end Set_Name;

   procedure Set_Form (Block : CB_Access; Form_Str : String) is
      Copy_Len : constant Natural := Natural'Min (Form_Str'Length, Block.Form_Buf'Length);
   begin
      Block.Form_Len := Copy_Len;
      Block.Form_Buf (1 .. Copy_Len) := Form_Str (Form_Str'First .. Form_Str'First + Copy_Len - 1);
   end Set_Form;

   --  Validate an implementation-defined Form string and extract its options.
   --  Comma-separated tokens; "sync=yes" / "sync=no" recognised; "" allowed;
   --  anything else raises Use_Error.
   procedure Parse_Form (Form_Str : String; Sync : out Boolean) is
      I : Natural := Form_Str'First;
   begin
      Sync := False;
      while I <= Form_Str'Last loop
         declare
            J : Natural := I;
         begin
            while J <= Form_Str'Last and then Form_Str (J) /= ',' loop
               J := J + 1;
            end loop;
            declare
               Tok_First : Natural := I;
               Tok_Last  : Natural := J - 1;
            begin
               while Tok_First <= Tok_Last and then Form_Str (Tok_First) = ' ' loop
                  Tok_First := Tok_First + 1;
               end loop;
               while Tok_Last >= Tok_First and then Form_Str (Tok_Last) = ' ' loop
                  Tok_Last := Tok_Last - 1;
               end loop;
               declare
                  Tok : constant String := Form_Str (Tok_First .. Tok_Last);
               begin
                  if Tok = "" then
                     null;
                  elsif Tok = "sync=yes" then
                     Sync := True;
                  elsif Tok = "sync=no" then
                     Sync := False;
                  else
                     raise ESP32S3.Ext4.Use_Error;
                  end if;
               end;
            end;
            I := J + 1;
         end;
      end loop;
   end Parse_Form;

   procedure Locate
     (Name_Str  : String;
      FS        : out ESP32S3.Ext4.VFS.Mount_Ref;
      Sub_First : out Natural;
      Sub_Last  : out Natural)
   is
      Found, Is_Root : Boolean;
   begin
      ESP32S3.Ext4.VFS.Resolve (Name_Str, FS, Sub_First, Sub_Last, Found, Is_Root);
      if not Found or else FS = null then
         raise ESP32S3.Ext4.Name_Error;
      end if;
   end Locate;

   procedure Split (Path : String; Dir_Last, Name_First : out Natural) is
      Last_Slash : Natural := Path'First;
   begin
      for I in Path'Range loop
         if Path (I) = '/' then
            Last_Slash := I;
         end if;
      end loop;
      Name_First := Last_Slash + 1;
      Dir_Last := (if Last_Slash = Path'First then Path'First else Last_Slash - 1);
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

   procedure Open_For_Write
     (Block : CB_Access; Name_Str : String; Mode : File_Mode; Truncate : Boolean)
   is
      FS                  : ESP32S3.Ext4.VFS.Mount_Ref;
      Sub_First, Sub_Last : Natural;
   begin
      Locate (Name_Str, FS, Sub_First, Sub_Last);
      declare
         Sub                  : constant String := Name_Str (Sub_First .. Sub_Last);
         Dir_Last, Name_First : Natural;
         Node                 : Inode_Number;
      begin
         begin
            Node := FS.Lookup (Sub);
            if Truncate then
               FS.Truncate (Node, 0);
            end if;
         exception
            when others =>
               Split (Sub, Dir_Last, Name_First);
               Node := FS.Create_File (Sub (Sub'First .. Dir_Last), Sub (Name_First .. Sub'Last));
         end;
         Block.Kind := Disk;
         Block.FS := FS;
         Block.Node := Node;
         Block.Mode := Mode;
         Block.Offset := 0;
      end;
      Set_Name (Block, Name_Str);
   end Open_For_Write;

   ----------------------------------------------------------------------------
   --  File management
   ----------------------------------------------------------------------------

   procedure Create
     (File : in out File_Type; Name : String; Mode : File_Mode := Out_File; Form : String := "")
   is
      Sync : Boolean;
   begin
      Parse_Form (Form, Sync);                     --  validate before creating
      New_CB (File);
      Open_For_Write
        (File.CB, Name, (if Mode = In_File then Out_File else Mode), Truncate => True);
      File.CB.Sync := Sync;
      Set_Form (File.CB, Form);
   end Create;

   procedure Open (File : in out File_Type; Name : String; Mode : File_Mode; Form : String := "")
   is
      FS                  : ESP32S3.Ext4.VFS.Mount_Ref;
      Sub_First, Sub_Last : Natural;
      Sync                : Boolean;
   begin
      Parse_Form (Form, Sync);                     --  validate before opening
      New_CB (File);
      case Mode is
         when In_File     =>
            Locate (Name, FS, Sub_First, Sub_Last);
            File.CB.Kind := Disk;
            File.CB.FS := FS;
            File.CB.Node := FS.Lookup (Name (Sub_First .. Sub_Last));
            FS.Stat (File.CB.Node, File.CB.Info);
            File.CB.Mode := In_File;
            File.CB.Offset := 0;
            Set_Name (File.CB, Name);

         when Out_File    =>
            Open_For_Write (File.CB, Name, Out_File, Truncate => True);

         when Append_File =>
            Open_For_Write (File.CB, Name, Append_File, Truncate => False);
      end case;
      File.CB.Sync := Sync;
      Set_Form (File.CB, Form);
   end Open;

   procedure Close_CB (Block : CB_Access) is
   begin
      if Block.Kind = Disk then
         if Block.Mode /= In_File and then Block.FS /= null then
            Block.FS.Commit;
         end if;
      end if;
      Block.Kind := Closed;
      Block.FS := null;
   end Close_CB;

   procedure Close (File : in out File_Type) is
   begin
      if File.CB /= null then
         Close_CB (File.CB);
      end if;
   end Close;

   procedure Delete (File : in out File_Type) is
      Block               : constant CB_Access := CB (File);
      Name_Str            : constant String := Block.Name_Buf (1 .. Block.Name_Len);
      FS                  : ESP32S3.Ext4.VFS.Mount_Ref;
      Sub_First, Sub_Last : Natural;
   begin
      if Block.Kind /= Disk then
         raise ESP32S3.Ext4.Use_Error;     --  cannot delete the console

      end if;
      Close (File);                         --  close (commits any pending writes)
      Locate (Name_Str, FS, Sub_First, Sub_Last);
      declare
         Sub                  : constant String := Name_Str (Sub_First .. Sub_Last);
         Dir_Last, Name_First : Natural;
      begin
         Split (Sub, Dir_Last, Name_First);
         FS.Unlink (Sub (Sub'First .. Dir_Last), Sub (Name_First .. Sub'Last));
         FS.Commit;
      end;
   end Delete;

   procedure Reset (File : in out File_Type) is
      Block : constant CB_Access := CB (File);
   begin
      if Block.Kind = Disk and then Block.Mode = In_File then
         Block.FS.Stat (Block.Node, Block.Info);
         Block.Offset := 0;
         Block.Column := 1;
         Block.Line_No := 1;
         Block.Page_No := 1;
      end if;
   end Reset;

   --  Re-open the file with a new mode (e.g. an Out_File written then re-read as
   --  In_File), preserving its name and form. Console files just reset position.
   procedure Reset (File : in out File_Type; Mode : File_Mode) is
      Block : constant CB_Access := CB (File);
   begin
      if Block.Kind /= Disk then
         Block.Column := 1;
         Block.Line_No := 1;
         Block.Page_No := 1;
         return;
      end if;
      declare
         Name_Str : constant String := Block.Name_Buf (1 .. Block.Name_Len);
         Form_Str : constant String := Block.Form_Buf (1 .. Block.Form_Len);
      begin
         Close (File);
         Open (File, Name_Str, Mode, Form_Str);
      end;
   end Reset;

   function Is_Open (File : File_Type) return Boolean
   is (File.CB /= null and then File.CB.Kind /= Closed);
   function Mode (File : File_Type) return File_Mode
   is (CB (File).Mode);
   function Name (File : File_Type) return String
   is (CB (File).Name_Buf (1 .. CB (File).Name_Len));
   function Form (File : File_Type) return String
   is (CB (File).Form_Buf (1 .. CB (File).Form_Len));

   procedure Flush (File : File_Type) is
      Block : constant CB_Access := CB (File);
   begin
      case Block.Kind is
         when Console =>
            ESP32S3.Serial.Flush;

         when Disk    =>
            if Block.Mode /= In_File and then Block.FS /= null then
               Block.FS.Commit;
            end if;

         when Closed  =>
            null;
      end case;
   end Flush;

   procedure Flush is
   begin
      Flush (Cur_Out.all);
   end Flush;

   ----------------------------------------------------------------------------
   --  Layout
   ----------------------------------------------------------------------------

   procedure Set_Line_Length (File : File_Type; To : Count) is
   begin
      CB (File).Line_Len := Natural (To);
   end Set_Line_Length;
   procedure Set_Line_Length (To : Count) is
   begin
      Set_Line_Length (Cur_Out.all, To);
   end Set_Line_Length;
   procedure Set_Page_Length (File : File_Type; To : Count) is
   begin
      CB (File).Page_Len := Natural (To);
   end Set_Page_Length;
   procedure Set_Page_Length (To : Count) is
   begin
      Set_Page_Length (Cur_Out.all, To);
   end Set_Page_Length;

   function Line_Length (File : File_Type) return Count
   is (Count (CB (File).Line_Len));
   function Line_Length return Count
   is (Line_Length (Cur_Out.all));
   function Page_Length (File : File_Type) return Count
   is (Count (CB (File).Page_Len));
   function Page_Length return Count
   is (Page_Length (Cur_Out.all));

   function Col (File : File_Type) return Positive_Count
   is (Positive_Count (CB (File).Column));
   function Col return Positive_Count
   is (Col (Cur_Out.all));
   function Line (File : File_Type) return Positive_Count
   is (Positive_Count (CB (File).Line_No));
   function Line return Positive_Count
   is (Line (Cur_Out.all));
   function Page (File : File_Type) return Positive_Count
   is (Positive_Count (CB (File).Page_No));
   function Page return Positive_Count
   is (Page (Cur_Out.all));

   procedure New_Line (File : File_Type; Spacing : Positive_Count := 1) is
      Block : constant CB_Access := CB (File);
   begin
      for I in 1 .. Spacing loop
         Emit_New_Line (Block);
      end loop;
   end New_Line;
   procedure New_Line (Spacing : Positive_Count := 1) is
   begin
      New_Line (Cur_Out.all, Spacing);
   end New_Line;

   procedure New_Page (File : File_Type) is
      Block : constant CB_Access := CB (File);
   begin
      Raw_Write (Block, (1 => Page_Mark));
      Block.Column := 1;
      Block.Line_No := 1;
      Block.Page_No := Block.Page_No + 1;
   end New_Page;
   procedure New_Page is
   begin
      New_Page (Cur_Out.all);
   end New_Page;

   procedure Set_Col (File : File_Type; To : Positive_Count) is
      Block      : constant CB_Access := CB (File);
      Target_Col : constant Positive := Positive (To);
   begin
      if Block.Mode = In_File and then (Block.Kind = Disk or else Block.Kind = Console) then
         while Block.Column < Target_Col loop
            --  input: skip forward
            declare
               Ch    : Character;
               Avail : Boolean;
            begin
               Peek (Block, Ch, Avail);
               exit when not Avail or else Ch = ASCII.LF;
               Advance (Block);
            end;
         end loop;
      else
         --  output: pad with spaces
         if Target_Col > Block.Column then
            Write_Tracked (Block, Spaces (Target_Col - Block.Column));
         elsif Target_Col < Block.Column then
            Emit_New_Line (Block);
            Write_Tracked (Block, Spaces (Target_Col - 1));
         end if;
      end if;
   end Set_Col;
   procedure Set_Col (To : Positive_Count) is
   begin
      Set_Col (Cur_Out.all, To);
   end Set_Col;

   procedure Set_Line (File : File_Type; To : Positive_Count) is
      Block       : constant CB_Access := CB (File);
      Target_Line : constant Positive := Positive (To);
   begin
      if Block.Mode = In_File and then (Block.Kind = Disk or else Block.Kind = Console) then
         --  Input: skip lines FORWARD until the line number reaches Target_Line (a stream
         --  has no backward seek; a target at/behind the current line is a no-op).
         --  A live console has no seekable line index, so it is a plain no-op.
         if Block.Kind = Disk then
            while Block.Line_No < Target_Line and then Block.Offset < Block.Info.Size loop
               Skip_Line (File);
            end loop;
         end if;
      elsif Target_Line > Block.Line_No then
         New_Line (File, Positive_Count (Target_Line - Block.Line_No));      --  forward
      elsif Target_Line < Block.Line_No then
         New_Page (File);                                      --  can't go back:
         if Target_Line > 1 then
            --  new page, then
            New_Line
              (File, Positive_Count (Target_Line - 1));           --  down to line Target_Line

         end if;
      end if;
   end Set_Line;
   procedure Set_Line (To : Positive_Count) is
   begin
      Set_Line (Cur_Out.all, To);
   end Set_Line;

   ----------------------------------------------------------------------------
   --  Character / string output
   ----------------------------------------------------------------------------

   procedure Put (File : File_Type; Item : Character) is
   begin
      Put_Char (CB (File), Item);
   end Put;
   procedure Put (Item : Character) is
   begin
      Put (Cur_Out.all, Item);
   end Put;

   procedure Put (File : File_Type; Item : String) is
   begin
      Write_Tracked (CB (File), Item);
   end Put;
   procedure Put (Item : String) is
   begin
      Put (Cur_Out.all, Item);
   end Put;

   procedure Put_Line (File : File_Type; Item : String) is
      Block : constant CB_Access := CB (File);
   begin
      Write_Tracked (Block, Item);
      Emit_New_Line (Block);
   end Put_Line;
   procedure Put_Line (Item : String) is
   begin
      Put_Line (Cur_Out.all, Item);
   end Put_Line;

   ----------------------------------------------------------------------------
   --  Input
   ----------------------------------------------------------------------------

   procedure Get (File : File_Type; Item : out Character) is
      Block : constant CB_Access := CB (File);
      Ch    : Character;
      Avail : Boolean;
   begin
      Require_Read (Block);
      if Block.Kind = Console then
         Await (Block, Item);
         return;
      end if;
      Peek (Block, Ch, Avail);
      if not Avail then
         raise ESP32S3.Ext4.End_Error;
      end if;
      Advance (Block);
      Item := Ch;
   end Get;
   procedure Get (Item : out Character) is
   begin
      Get (Cur_In.all, Item);
   end Get;

   procedure Look_Ahead (File : File_Type; Item : out Character; End_Of_Line : out Boolean) is
      Block : constant CB_Access := CB (File);
      Ch    : Character;
      Avail : Boolean;
   begin
      Require_Read (Block);
      Peek (Block, Ch, Avail);
      if not Avail or else Ch = ASCII.LF then
         End_Of_Line := True;
         Item := ' ';
      else
         End_Of_Line := False;
         Item := Ch;
      end if;
   end Look_Ahead;

   procedure Get_Immediate (File : File_Type; Item : out Character) is
      Block : constant CB_Access := CB (File);
      Ch    : Character;
      Avail : Boolean;
   begin
      Require_Read (Block);
      if Block.Kind = Console then
         Await (Block, Item);
         return;
      end if;
      Peek (Block, Ch, Avail);
      if not Avail then
         raise ESP32S3.Ext4.End_Error;
      end if;
      Advance (Block);
      Item := Ch;
   end Get_Immediate;
   procedure Get_Immediate (Item : out Character) is
   begin
      Get_Immediate (Cur_In.all, Item);
   end Get_Immediate;

   procedure Get_Immediate (File : File_Type; Item : out Character; Available : out Boolean) is
      Block : constant CB_Access := CB (File);
      Ch    : Character;
      Avail : Boolean;
   begin
      Require_Read (Block);
      Peek (Block, Ch, Avail);
      if Avail then
         Advance (Block);
         Item := Ch;
         Available := True;
      else
         Item := ASCII.NUL;
         Available := False;
      end if;
   end Get_Immediate;
   procedure Get_Immediate (Item : out Character; Available : out Boolean) is
   begin
      Get_Immediate (Cur_In.all, Item, Available);
   end Get_Immediate;

   --  Consume a trailing LF that pairs with a just-read CR (CR-LF line ends), so
   --  the next read does not see a stray empty line.  Console only; non-blocking.
   procedure Swallow_LF_After_CR (Block : CB_Access) is
      Ch    : Character;
      Avail : Boolean;
   begin
      Peek (Block, Ch, Avail);
      if Avail and then Ch = ASCII.LF then
         Advance (Block);
      end if;
   end Swallow_LF_After_CR;

   procedure Get_Line (File : File_Type; Item : out String; Last : out Natural) is
      Block : constant CB_Access := CB (File);
      Ch    : Character;
      Avail : Boolean;
   begin
      Require_Read (Block);
      if Block.Kind = Console then
         --  Interactive line read: block for characters until an end-of-line.
         --  Terminals over USB-serial/UART send CR (or CR-LF) for Enter, so treat
         --  CR and LF alike and absorb the LF of a CR-LF pair.
         Last := Item'First - 1;
         while Last < Item'Last loop
            Await (Block, Ch);
            if Ch = ASCII.CR then
               Swallow_LF_After_CR (Block);
               exit;
            end if;
            exit when Ch = ASCII.LF;
            Last := Last + 1;
            Item (Last) := Ch;
         end loop;
         return;
      end if;
      if Block.Offset >= Block.Info.Size then
         raise ESP32S3.Ext4.End_Error;
      end if;
      Last := Item'First - 1;
      while Last < Item'Last loop
         Peek (Block, Ch, Avail);
         exit when not Avail;
         Advance (Block);
         exit when Ch = ASCII.LF;
         Last := Last + 1;
         Item (Last) := Ch;
      end loop;
   end Get_Line;
   procedure Get_Line (Item : out String; Last : out Natural) is
   begin
      Get_Line (Cur_In.all, Item, Last);
   end Get_Line;

   function Get_Line (File : File_Type) return String is
      type Str_Ptr is access String;
      procedure Free is new Ada.Unchecked_Deallocation (String, Str_Ptr);
      Block      : constant CB_Access := CB (File);
      Buf        : Str_Ptr := new String (1 .. 64);
      Len        : Natural := 0;
      Ch         : Character;
      Avail      : Boolean;
      Is_Console : constant Boolean := Block.Kind = Console;
   begin
      Require_Read (Block);
      if not Is_Console and then Block.Offset >= Block.Info.Size then
         Free (Buf);
         raise ESP32S3.Ext4.End_Error;
      end if;
      loop
         if Is_Console then
            Await (Block, Ch);                    --  block for the next char
            if Ch = ASCII.CR then
               Swallow_LF_After_CR (Block);
               exit;
            end if;
            exit when Ch = ASCII.LF;
         else
            Peek (Block, Ch, Avail);
            exit when not Avail;
            Advance (Block);
            exit when Ch = ASCII.LF;
         end if;
         if Len = Buf'Length then
            --  grow (double)
            declare
               Bigger : constant Str_Ptr := new String (1 .. Buf'Length * 2);
            begin
               Bigger (1 .. Len) := Buf (1 .. Len);
               Free (Buf);
               Buf := Bigger;
            end;
         end if;
         Len := Len + 1;
         Buf (Len) := Ch;
      end loop;
      return Result : constant String := Buf (1 .. Len) do
         Free (Buf);
      end return;
   end Get_Line;

   function Get_Line return String
   is (Get_Line (Cur_In.all));

   procedure Skip_Line (File : File_Type; Spacing : Positive_Count := 1) is
      Block : constant CB_Access := CB (File);
      Ch    : Character;
      Avail : Boolean;
   begin
      Require_Read (Block);
      if Block.Kind = Console then
         for Line_Index in 1 .. Spacing loop
            loop
               Await (Block, Ch);
               if Ch = ASCII.CR then
                  Swallow_LF_After_CR (Block);
                  exit;
               end if;
               exit when Ch = ASCII.LF;
            end loop;
         end loop;
         return;
      end if;
      for Line_Index in 1 .. Spacing loop
         if Block.Offset >= Block.Info.Size then
            raise ESP32S3.Ext4.End_Error;
         end if;
         loop
            Peek (Block, Ch, Avail);
            exit when not Avail;
            Advance (Block);
            exit when Ch = ASCII.LF;
         end loop;
      end loop;
   end Skip_Line;
   procedure Skip_Line (Spacing : Positive_Count := 1) is
   begin
      Skip_Line (Cur_In.all, Spacing);
   end Skip_Line;

   procedure Skip_Page (File : File_Type) is
      Block : constant CB_Access := CB (File);
      Ch    : Character;
      Avail : Boolean;
   begin
      Require_Read (Block);
      loop
         Peek (Block, Ch, Avail);
         exit when not Avail;
         Advance (Block);
         exit when Ch = Page_Mark;
      end loop;
   end Skip_Page;
   procedure Skip_Page is
   begin
      Skip_Page (Cur_In.all);
   end Skip_Page;

   function End_Of_File (File : File_Type) return Boolean is
      Block : constant CB_Access := CB (File);
   begin
      if Block.Kind = Disk and then Block.Mode = In_File then
         return Block.Offset >= Block.Info.Size;
      elsif Block.Kind = Console and then Block.Mode = In_File then
         return False;   --  the console is an endless stream: never at end-of-file
      else
         raise ESP32S3.Ext4.Mode_Error;
      end if;
   end End_Of_File;
   function End_Of_File return Boolean
   is (End_Of_File (Cur_In.all));

   function End_Of_Line (File : File_Type) return Boolean is
      Block : constant CB_Access := CB (File);
      Ch    : Character;
      Avail : Boolean;
   begin
      Require_Read (Block);
      Peek (Block, Ch, Avail);
      return (not Avail) or else Ch = ASCII.LF;
   end End_Of_Line;
   function End_Of_Line return Boolean
   is (End_Of_Line (Cur_In.all));

   function End_Of_Page (File : File_Type) return Boolean is
      Block : constant CB_Access := CB (File);
      Ch    : Character;
      Avail : Boolean;
   begin
      Require_Read (Block);
      Peek (Block, Ch, Avail);
      return (not Avail) or else Ch = Page_Mark;
   end End_Of_Page;
   function End_Of_Page return Boolean
   is (End_Of_Page (Cur_In.all));

   ----------------------------------------------------------------------------
   --  Numeric / enumeration generics
   ----------------------------------------------------------------------------

   package body Integer_IO is
      procedure Put
        (File  : File_Type;
         Item  : Num;
         Width : Field := Default_Width;
         Base  : Number_Base := Default_Base) is
      begin
         Put_Number (CB (File), Based_Image (Long_Long_Integer (Item), Base), Width);
      end Put;
      procedure Put
        (Item : Num; Width : Field := Default_Width; Base : Number_Base := Default_Base) is
      begin
         Put (Cur_Out.all, Item, Width, Base);
      end Put;
      procedure Get (File : File_Type; Item : out Num) is
      begin
         Item := Num (Get_Integer (CB (File)));
      end Get;
      procedure Get (Item : out Num) is
      begin
         Get (Cur_In.all, Item);
      end Get;
      procedure Put (To : out String; Item : Num; Base : Number_Base := Default_Base) is
      begin
         Right_Justify (To, Based_Image (Long_Long_Integer (Item), Base));
      end Put;
      procedure Get (From : String; Item : out Num; Last : out Positive) is
         Value     : Long_Long_Integer;
         Last_Used : Natural;
      begin
         Scan_Integer (From, Value, Last_Used);
         Item := Num (Value);
         Last := Last_Used;
      end Get;
   end Integer_IO;

   package body Modular_IO is
      procedure Put
        (File  : File_Type;
         Item  : Num;
         Width : Field := Default_Width;
         Base  : Number_Base := Default_Base) is
      begin
         Put_Number (CB (File), Based_Image (Long_Long_Integer (Item), Base), Width);
      end Put;
      procedure Put
        (Item : Num; Width : Field := Default_Width; Base : Number_Base := Default_Base) is
      begin
         Put (Cur_Out.all, Item, Width, Base);
      end Put;
      procedure Get (File : File_Type; Item : out Num) is
      begin
         Item := Num (Get_Integer (CB (File)));
      end Get;
      procedure Get (Item : out Num) is
      begin
         Get (Cur_In.all, Item);
      end Get;
      procedure Put (To : out String; Item : Num; Base : Number_Base := Default_Base) is
      begin
         Right_Justify (To, Based_Image (Long_Long_Integer (Item), Base));
      end Put;
      procedure Get (From : String; Item : out Num; Last : out Positive) is
         Value     : Long_Long_Integer;
         Last_Used : Natural;
      begin
         Scan_Integer (From, Value, Last_Used);
         Item := Num (Value);
         Last := Last_Used;
      end Get;
   end Modular_IO;

   package body Float_IO is

      --  Format Item with Aft fractional digits, rounded. Exp = 0 -> fixed point
      --  (sign + integer part + '.' + Aft digits). Exp > 0 -> scientific: a
      --  mantissa normalised to [1,10) + 'E' + signed exponent of >= Exp digits.
      function Float_Image (Item : Num; Aft : Field; Exp : Field) return String is
         Aft_Clamped : constant Field := Field'Min (Aft, 18);
         Negative    : constant Boolean := Item < 0.0;
         Sign        : constant String := (if Negative then "-" else "");
         Magnitude   : Num := abs Item;

         function Frac_Digits (Frac : Num; Carry : out Boolean) return String is
            Scale : Long_Long_Integer := 1;
         begin
            for I in 1 .. Aft_Clamped loop
               Scale := Scale * 10;
            end loop;
            declare
               Scaled     : Long_Long_Integer :=
                 Long_Long_Integer (Num'Rounding (Frac * Num (Scale)));
               Digits_Str : String (1 .. Aft_Clamped) := (others => '0');
               Temp       : Long_Long_Integer;
            begin
               if Scaled >= Scale then
                  Carry := True;
                  Scaled := Scaled - Scale;
               else
                  Carry := False;
               end if;
               Temp := Scaled;
               for K in reverse Digits_Str'Range loop
                  Digits_Str (K) := Character'Val (Character'Pos ('0') + Integer (Temp mod 10));
                  Temp := Temp / 10;
               end loop;
               return Digits_Str;
            end;
         end Frac_Digits;

      begin
         if Exp = 0 then
            declare
               Int_Part : Long_Long_Integer := Long_Long_Integer (Num'Truncation (Magnitude));
               Carry    : Boolean;
               Frac_Str : constant String := Frac_Digits (Magnitude - Num (Int_Part), Carry);
            begin
               if Carry then
                  Int_Part := Int_Part + 1;
               end if;
               return
                 Sign
                 & Based_Image (Int_Part, 10)
                 & (if Aft_Clamped > 0 then "." & Frac_Str else "");
            end;
         else
            declare
               Exponent : Integer := 0;
            begin
               if Magnitude /= 0.0 then
                  while Magnitude >= 10.0 loop
                     Magnitude := Magnitude / 10.0;
                     Exponent := Exponent + 1;
                  end loop;
                  while Magnitude < 1.0 loop
                     Magnitude := Magnitude * 10.0;
                     Exponent := Exponent - 1;
                  end loop;
               end if;
               declare
                  Lead_Digit : Long_Long_Integer := Long_Long_Integer (Num'Truncation (Magnitude));
                  Carry      : Boolean;
                  Frac_Str   : constant String :=
                    Frac_Digits (Magnitude - Num (Lead_Digit), Carry);
               begin
                  if Carry then
                     Lead_Digit := Lead_Digit + 1;
                     if Lead_Digit >= 10 then
                        Lead_Digit := 1;
                        Exponent := Exponent + 1;
                     end if;
                  end if;
                  declare
                     Mantissa_Str : constant String :=
                       Based_Image (Lead_Digit, 10)
                       & (if Aft_Clamped > 0 then "." & Frac_Str else "");
                     Exp_Sign     : constant String := (if Exponent < 0 then "-" else "+");
                     Exp_Digits   : constant String :=
                       Based_Image (Long_Long_Integer (abs Exponent), 10);
                     Exp_Width    : constant Field := Field'Max (Exp, 1);
                     Exp_Padded   : constant String :=
                       (if Exp_Digits'Length < Exp_Width
                        then (1 .. Exp_Width - Exp_Digits'Length => '0')
                        else "")
                       & Exp_Digits;
                  begin
                     return Sign & Mantissa_Str & "E" & Exp_Sign & Exp_Padded;
                  end;
               end;
            end;
         end if;
      end Float_Image;

      procedure Put
        (File : File_Type;
         Item : Num;
         Fore : Field := Default_Fore;
         Aft  : Field := Default_Aft;
         Exp  : Field := Default_Exp)
      is
         Block   : constant CB_Access := CB (File);
         Str     : constant String := Float_Image (Item, Aft, Exp);
         Dot_Pos : Natural := Str'Last + 1;
      begin
         for I in Str'Range loop
            if Str (I) = '.' then
               Dot_Pos := I;
               exit;
            end if;
         end loop;
         declare
            Int_Len : constant Natural := Dot_Pos - Str'First;     --  chars before the point
         begin
            if Fore > Int_Len then
               Write_Tracked (Block, Spaces (Fore - Int_Len) & Str);
            else
               Write_Tracked (Block, Str);
            end if;
         end;
      end Put;

      procedure Put
        (Item : Num;
         Fore : Field := Default_Fore;
         Aft  : Field := Default_Aft;
         Exp  : Field := Default_Exp) is
      begin
         Put (Cur_Out.all, Item, Fore, Aft, Exp);
      end Put;

      procedure Put
        (To : out String; Item : Num; Aft : Field := Default_Aft; Exp : Field := Default_Exp) is
      begin
         Right_Justify (To, Float_Image (Item, Aft, Exp));
      end Put;

      procedure Get (File : File_Type; Item : out Num) is
         Block    : constant CB_Access := CB (File);
         Ch       : Character;
         Avail    : Boolean;
         Negative : Boolean := False;
         Value    : Num := 0.0;
      begin
         Require_Read (Block);
         Skip_Blanks (Block);
         Peek_Wait (Block, Ch, Avail);
         if Avail and then (Ch = '-' or else Ch = '+') then
            Negative := Ch = '-';
            Advance (Block);
         end if;
         loop
            Peek_Wait (Block, Ch, Avail);
            exit when not Avail or else Digit_Val (Ch) < 0 or else Digit_Val (Ch) > 9;
            Value := Value * 10.0 + Num (Digit_Val (Ch));
            Advance (Block);
         end loop;
         Peek_Wait (Block, Ch, Avail);
         if Avail and then Ch = '.' then
            Advance (Block);
            declare
               Scale : Num := 0.1;
            begin
               loop
                  Peek_Wait (Block, Ch, Avail);
                  exit when not Avail or else Digit_Val (Ch) < 0 or else Digit_Val (Ch) > 9;
                  Value := Value + Num (Digit_Val (Ch)) * Scale;
                  Scale := Scale / 10.0;
                  Advance (Block);
               end loop;
            end;
         end if;
         Peek_Wait (Block, Ch, Avail);
         if Avail and then (Ch = 'e' or else Ch = 'E') then
            Advance (Block);
            declare
               Exp_Negative : Boolean := False;
               Exponent     : Natural := 0;
            begin
               Peek_Wait (Block, Ch, Avail);
               if Avail and then (Ch = '-' or else Ch = '+') then
                  Exp_Negative := Ch = '-';
                  Advance (Block);
               end if;
               loop
                  Peek_Wait (Block, Ch, Avail);
                  exit when not Avail or else Digit_Val (Ch) < 0 or else Digit_Val (Ch) > 9;
                  Exponent := Exponent * 10 + Digit_Val (Ch);
                  Advance (Block);
               end loop;
               for I in 1 .. Exponent loop
                  if Exp_Negative then
                     Value := Value / 10.0;
                  else
                     Value := Value * 10.0;
                  end if;
               end loop;
            end;
         end if;
         Item := (if Negative then -Value else Value);
      end Get;
      procedure Get (Item : out Num) is
      begin
         Get (Cur_In.all, Item);
      end Get;

      procedure Get (From : String; Item : out Num; Last : out Positive) is
         I         : Natural := From'First;
         Negative  : Boolean := False;
         Value     : Num := 0.0;
         Started   : Boolean := False;
         Last_Used : Natural := From'First - 1;
      begin
         while I <= From'Last and then (From (I) = ' ' or else From (I) = ASCII.HT) loop
            I := I + 1;
         end loop;
         if I <= From'Last and then (From (I) = '-' or else From (I) = '+') then
            Negative := From (I) = '-';
            I := I + 1;
         end if;
         while I <= From'Last and then Digit_Val (From (I)) in 0 .. 9 loop
            Value := Value * 10.0 + Num (Digit_Val (From (I)));
            Last_Used := I;
            I := I + 1;
            Started := True;
         end loop;
         if I <= From'Last and then From (I) = '.' then
            Last_Used := I;
            I := I + 1;
            declare
               Scale : Num := 0.1;
            begin
               while I <= From'Last and then Digit_Val (From (I)) in 0 .. 9 loop
                  Value := Value + Num (Digit_Val (From (I))) * Scale;
                  Scale := Scale / 10.0;
                  Last_Used := I;
                  I := I + 1;
                  Started := True;
               end loop;
            end;
         end if;
         if I <= From'Last and then (From (I) = 'e' or else From (I) = 'E') then
            I := I + 1;
            declare
               Exp_Negative : Boolean := False;
               Exponent     : Natural := 0;
            begin
               if I <= From'Last and then (From (I) = '-' or else From (I) = '+') then
                  Exp_Negative := From (I) = '-';
                  I := I + 1;
               end if;
               while I <= From'Last and then Digit_Val (From (I)) in 0 .. 9 loop
                  Exponent := Exponent * 10 + Digit_Val (From (I));
                  Last_Used := I;
                  I := I + 1;
               end loop;
               for K in 1 .. Exponent loop
                  if Exp_Negative then
                     Value := Value / 10.0;
                  else
                     Value := Value * 10.0;
                  end if;
               end loop;
            end;
         end if;
         if not Started then
            raise ESP32S3.Ext4.Data_Error;
         end if;
         Item := (if Negative then -Value else Value);
         Last := Last_Used;
      end Get;
   end Float_IO;

   package body Enumeration_IO is
      procedure Put
        (File  : File_Type;
         Item  : Enum;
         Width : Field := Default_Width;
         Set   : Type_Set := Default_Setting)
      is
         Block : constant CB_Access := CB (File);
         Img   : constant String := Enum'Image (Item);
         Str   : constant String := (if Set = Lower_Case then To_Lower (Img) else Img);
      begin
         if Width > Str'Length then
            Write_Tracked (Block, Str & Spaces (Width - Str'Length));   --  enums: left-justify

         else
            Write_Tracked (Block, Str);
         end if;
      end Put;
      procedure Put
        (Item : Enum; Width : Field := Default_Width; Set : Type_Set := Default_Setting) is
      begin
         Put (Cur_Out.all, Item, Width, Set);
      end Put;

      procedure Get (File : File_Type; Item : out Enum) is
         Block    : constant CB_Access := CB (File);
         Ch       : Character;
         Avail    : Boolean;
         Buf      : String (1 .. 64);
         Len_Used : Natural := 0;
      begin
         Require_Read (Block);
         Skip_Blanks (Block);
         loop
            Peek_Wait (Block, Ch, Avail);
            exit when not Avail;
            exit when Ch not in 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '_';
            if Len_Used < Buf'Last then
               Len_Used := Len_Used + 1;
               Buf (Len_Used) := Ch;
            end if;
            Advance (Block);
         end loop;
         begin
            Item := Enum'Value (Buf (1 .. Len_Used));
         exception
            when others =>
               raise ESP32S3.Ext4.Data_Error;
         end;
      end Get;
      procedure Get (Item : out Enum) is
      begin
         Get (Cur_In.all, Item);
      end Get;
   end Enumeration_IO;

   package body Fixed_IO is
      function Image (Item : Num; Aft : Field) return String is
         Aft_Clamped : constant Field := Field'Min (Aft, 15);
         Negative    : constant Boolean := Item < 0.0;
         Magnitude   : constant Long_Float := abs (Long_Float (Item));  --  range-safe
         FScale      : Long_Float := 1.0;
         IScale      : Long_Long_Integer := 1;
      begin
         for I in 1 .. Aft_Clamped loop
            FScale := FScale * 10.0;
            IScale := IScale * 10;
         end loop;
         declare
            Scaled : constant Long_Long_Integer :=
              Long_Long_Integer (Long_Float'Rounding (Magnitude * FScale));
         begin
            return Scaled_Image (Negative, Scaled / IScale, Scaled mod IScale, Aft_Clamped);
         end;
      end Image;

      procedure Set_Value
        (Item : out Num; Mantissa : Long_Long_Integer; Power : Integer; Negative : Boolean)
      is
         Result : Long_Float := Long_Float (Mantissa);
      begin
         if Power >= 0 then
            for I in 1 .. Power loop
               Result := Result * 10.0;
            end loop;
         else
            for I in 1 .. (-Power) loop
               Result := Result / 10.0;
            end loop;
         end if;
         Item := Num (if Negative then -Result else Result);   --  range-checked at the end
      end Set_Value;

      procedure Put
        (File : File_Type;
         Item : Num;
         Fore : Field := Default_Fore;
         Aft  : Field := Default_Aft;
         Exp  : Field := Default_Exp)
      is
         pragma Unreferenced (Exp);
         Block   : constant CB_Access := CB (File);
         Str     : constant String := Image (Item, Aft);
         Dot_Pos : Natural := Str'Last + 1;
      begin
         for I in Str'Range loop
            if Str (I) = '.' then
               Dot_Pos := I;
               exit;
            end if;
         end loop;
         declare
            Int_Len : constant Natural := Dot_Pos - Str'First;
         begin
            if Fore > Int_Len then
               Write_Tracked (Block, Spaces (Fore - Int_Len) & Str);
            else
               Write_Tracked (Block, Str);
            end if;
         end;
      end Put;
      procedure Put
        (Item : Num;
         Fore : Field := Default_Fore;
         Aft  : Field := Default_Aft;
         Exp  : Field := Default_Exp) is
      begin
         Put (Cur_Out.all, Item, Fore, Aft, Exp);
      end Put;
      procedure Put
        (To : out String; Item : Num; Aft : Field := Default_Aft; Exp : Field := Default_Exp)
      is
         pragma Unreferenced (Exp);
      begin
         Right_Justify (To, Image (Item, Aft));
      end Put;

      procedure Get (File : File_Type; Item : out Num) is
         Block     : constant CB_Access := CB (File);
         Buf       : String (1 .. 40);
         Len       : Natural;
         Mantissa  : Long_Long_Integer;
         Power     : Integer;
         Negative  : Boolean;
         Last_Used : Natural;
      begin
         Read_Number_Token (Block, Buf, Len);
         Scan_Real_Str (Buf (1 .. Len), Mantissa, Power, Negative, Last_Used);
         Set_Value (Item, Mantissa, Power, Negative);
      end Get;
      procedure Get (Item : out Num) is
      begin
         Get (Cur_In.all, Item);
      end Get;
      procedure Get (From : String; Item : out Num; Last : out Positive) is
         Mantissa  : Long_Long_Integer;
         Power     : Integer;
         Negative  : Boolean;
         Last_Used : Natural;
      begin
         Scan_Real_Str (From, Mantissa, Power, Negative, Last_Used);
         Set_Value (Item, Mantissa, Power, Negative);
         Last := Last_Used;
      end Get;
   end Fixed_IO;

   package body Decimal_IO is
      function Image (Item : Num; Aft : Field) return String is
         Aft_Clamped : constant Field := Field'Min (Aft, 15);
         Negative    : constant Boolean := Item < 0.0;
         Magnitude   : constant Long_Float := abs (Long_Float (Item));  --  range-safe
         FScale      : Long_Float := 1.0;
         IScale      : Long_Long_Integer := 1;
      begin
         for I in 1 .. Aft_Clamped loop
            FScale := FScale * 10.0;
            IScale := IScale * 10;
         end loop;
         declare
            Scaled : constant Long_Long_Integer :=
              Long_Long_Integer (Long_Float'Rounding (Magnitude * FScale));
         begin
            return Scaled_Image (Negative, Scaled / IScale, Scaled mod IScale, Aft_Clamped);
         end;
      end Image;

      procedure Set_Value
        (Item : out Num; Mantissa : Long_Long_Integer; Power : Integer; Negative : Boolean)
      is
         Result : Long_Float := Long_Float (Mantissa);
      begin
         if Power >= 0 then
            for I in 1 .. Power loop
               Result := Result * 10.0;
            end loop;
         else
            for I in 1 .. (-Power) loop
               Result := Result / 10.0;
            end loop;
         end if;
         Item := Num (if Negative then -Result else Result);   --  range-checked at the end
      end Set_Value;

      procedure Put
        (File : File_Type;
         Item : Num;
         Fore : Field := Default_Fore;
         Aft  : Field := Default_Aft;
         Exp  : Field := Default_Exp)
      is
         pragma Unreferenced (Exp);
         Block   : constant CB_Access := CB (File);
         Str     : constant String := Image (Item, Aft);
         Dot_Pos : Natural := Str'Last + 1;
      begin
         for I in Str'Range loop
            if Str (I) = '.' then
               Dot_Pos := I;
               exit;
            end if;
         end loop;
         declare
            Int_Len : constant Natural := Dot_Pos - Str'First;
         begin
            if Fore > Int_Len then
               Write_Tracked (Block, Spaces (Fore - Int_Len) & Str);
            else
               Write_Tracked (Block, Str);
            end if;
         end;
      end Put;
      procedure Put
        (Item : Num;
         Fore : Field := Default_Fore;
         Aft  : Field := Default_Aft;
         Exp  : Field := Default_Exp) is
      begin
         Put (Cur_Out.all, Item, Fore, Aft, Exp);
      end Put;
      procedure Put
        (To : out String; Item : Num; Aft : Field := Default_Aft; Exp : Field := Default_Exp)
      is
         pragma Unreferenced (Exp);
      begin
         Right_Justify (To, Image (Item, Aft));
      end Put;

      procedure Get (File : File_Type; Item : out Num) is
         Block     : constant CB_Access := CB (File);
         Buf       : String (1 .. 40);
         Len       : Natural;
         Mantissa  : Long_Long_Integer;
         Power     : Integer;
         Negative  : Boolean;
         Last_Used : Natural;
      begin
         Read_Number_Token (Block, Buf, Len);
         Scan_Real_Str (Buf (1 .. Len), Mantissa, Power, Negative, Last_Used);
         Set_Value (Item, Mantissa, Power, Negative);
      end Get;
      procedure Get (Item : out Num) is
      begin
         Get (Cur_In.all, Item);
      end Get;
      procedure Get (From : String; Item : out Num; Last : out Positive) is
         Mantissa  : Long_Long_Integer;
         Power     : Integer;
         Negative  : Boolean;
         Last_Used : Natural;
      begin
         Scan_Real_Str (From, Mantissa, Power, Negative, Last_Used);
         Set_Value (Item, Mantissa, Power, Negative);
         Last := Last_Used;
      end Get;
   end Decimal_IO;

   ----------------------------------------------------------------------------
   --  Finalization
   ----------------------------------------------------------------------------

   overriding
   procedure Finalize (File : in out File_Type) is
   begin
      if File.CB /= null then
         begin
            Close_CB (File.CB);
         exception
            when others =>
               null;
         end;
         Free (File.CB);
      end if;
   end Finalize;

begin
   Std_Out.CB := new Control_Block'(Kind => Console, Mode => Out_File, others => <>);
   Std_Err.CB := new Control_Block'(Kind => Console, Mode => Out_File, others => <>);
   Std_In.CB := new Control_Block'(Kind => Console, Mode => In_File, others => <>);
   Cur_Out := Std_Out'Access;
   Cur_Err := Std_Err'Access;
   Cur_In := Std_In'Access;
end ESP32S3.Text_IO;
