with Ada.Unchecked_Deallocation;
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
      Name_Len : Natural                    := 0;
      Name_Buf : String (1 .. Name_Max)     := (others => ' ');
   end record;

   procedure Free is new Ada.Unchecked_Deallocation (Control_Block, CB_Access);

   Page_Mark : constant Character := ASCII.FF;

   Std_Out : aliased File_Type;
   Std_In  : aliased File_Type;
   Cur_Out : File_Access;
   Cur_In  : File_Access;

   function Standard_Output return File_Access is (Std_Out'Access);
   function Standard_Error  return File_Access is (Std_Out'Access);
   function Standard_Input  return File_Access is (Std_In'Access);
   function Current_Output  return File_Access is (Cur_Out);
   function Current_Input   return File_Access is (Cur_In);
   procedure Set_Output (File : File_Access) is begin Cur_Out := File; end Set_Output;
   procedure Set_Input  (File : File_Access) is begin Cur_In  := File; end Set_Input;

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
      if B.Kind /= Disk or else B.Mode /= In_File then
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

   --  Peek the next input byte without consuming it.
   procedure Peek (B : CB_Access; C : out Character; Avail : out Boolean) is
      One : Byte_Array (0 .. 0);
      Cnt : Natural;
   begin
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

   --  Consume the next input byte, tracking column / line / page.
   procedure Advance (B : CB_Access) is
      C : Character; Av : Boolean;
   begin
      Peek (B, C, Av);
      if Av then
         if C = ASCII.LF then
            B.Column := 1; B.Line_No := B.Line_No + 1;
         elsif C = Page_Mark then
            B.Column := 1; B.Line_No := 1; B.Page_No := B.Page_No + 1;
         else
            B.Column := B.Column + 1;
         end if;
      end if;
      B.Offset := B.Offset + 1;
   end Advance;

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

   function To_Lower (S : String) return String is
      R : String := S;
   begin
      for I in R'Range loop
         if R (I) in 'A' .. 'Z' then
            R (I) := Character'Val (Character'Pos (R (I)) + 32);
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

   procedure Create (File : in out File_Type; Name : String; Mode : File_Mode := Out_File)
   is
   begin
      New_CB (File);
      Open_For_Write (File.CB, Name,
                      (if Mode = In_File then Out_File else Mode), Truncate => True);
   end Create;

   procedure Open (File : in out File_Type; Name : String; Mode : File_Mode) is
      FS     : ESP32S3.Ext4.VFS.Mount_Ref;
      SF, SL : Natural;
   begin
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

   procedure Reset (File : in out File_Type) is
      B : constant CB_Access := CB (File);
   begin
      if B.Kind = Disk and then B.Mode = In_File then
         B.FS.Stat (B.Node, B.Info);
         B.Offset := 0; B.Column := 1; B.Line_No := 1; B.Page_No := 1;
      end if;
   end Reset;

   function Is_Open (File : File_Type) return Boolean is
     (File.CB /= null and then File.CB.Kind /= Closed);
   function Mode (File : File_Type) return File_Mode is (CB (File).Mode);
   function Name (File : File_Type) return String is
     (CB (File).Name_Buf (1 .. CB (File).Name_Len));

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
      if B.Kind = Disk and then B.Mode = In_File then     --  input: skip forward
         while B.Column < T loop
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
      if B.Kind = Disk and then B.Mode = In_File then
         --  Input: skip lines FORWARD until the line number reaches T (a stream
         --  has no backward seek; a target at/behind the current line is a no-op).
         while B.Line_No < T and then B.Offset < B.Info.Size loop
            Skip_Line (File);
         end loop;
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

   procedure Get_Line (File : File_Type; Item : out String; Last : out Natural) is
      B : constant CB_Access := CB (File);
      C : Character; Av : Boolean;
   begin
      Require_Read (B);
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

   procedure Skip_Line (File : File_Type; Spacing : Positive_Count := 1) is
      B : constant CB_Access := CB (File);
      C : Character; Av : Boolean;
   begin
      Require_Read (B);
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
   end Modular_IO;

   package body Float_IO is
      procedure Put (File : File_Type; Item : Num;
                     Fore : Field := Default_Fore; Aft : Field := Default_Aft;
                     Exp  : Field := Default_Exp)
      is
         pragma Unreferenced (Exp);
         B     : constant CB_Access := CB (File);
         A     : constant Field   := Field'Min (Aft, 18);
         Neg   : constant Boolean := Item < 0.0;
         M     : constant Num     := abs Item;
         IP    : Long_Long_Integer := Long_Long_Integer (Num'Truncation (M));
         Scale : Long_Long_Integer := 1;
      begin
         for I in 1 .. A loop Scale := Scale * 10; end loop;
         declare
            Frac : constant Num := M - Num (IP);
            Sd   : Long_Long_Integer := Long_Long_Integer (Num'Rounding (Frac * Num (Scale)));
         begin
            if Sd >= Scale then IP := IP + 1; Sd := Sd - Scale; end if;
            declare
               Int_Str  : constant String := (if Neg then "-" else "") & Based_Image (IP, 10);
               Frac_Str : String (1 .. A) := (others => '0');
               T        : Long_Long_Integer := Sd;
               Lead     : constant String :=
                 (if Fore > Int_Str'Length then Spaces (Fore - Int_Str'Length) else "");
            begin
               for K in reverse Frac_Str'Range loop
                  Frac_Str (K) := Character'Val (Character'Pos ('0') + Integer (T mod 10));
                  T := T / 10;
               end loop;
               if A > 0 then
                  Write_Tracked (B, Lead & Int_Str & "." & Frac_Str);
               else
                  Write_Tracked (B, Lead & Int_Str);
               end if;
            end;
         end;
      end Put;

      procedure Put (Item : Num;
                     Fore : Field := Default_Fore; Aft : Field := Default_Aft;
                     Exp  : Field := Default_Exp) is
      begin Put (Cur_Out.all, Item, Fore, Aft, Exp); end Put;

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
   Std_In.CB  := new Control_Block'(Kind => Console, Mode => In_File,  others => <>);
   Cur_Out := Std_Out'Access;
   Cur_In  := Std_In'Access;
end ESP32S3.Text_IO;
