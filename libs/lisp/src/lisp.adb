with Ada.Unchecked_Deallocation;

package body Lisp is

   procedure Free_Vec is new Ada.Unchecked_Deallocation (Ref_Array, Ref_Vec);

   --  Singletons -- canonical, outside the arena so they always stay valid.
   Nil_Obj    : aliased Object := (Mark => False, K => K_Nil);
   True_Obj   : aliased Object := (Mark => False, K => K_Bool, B => True);
   False_Obj  : aliased Object := (Mark => False, K => K_Bool, B => False);
   Unspec_Obj : aliased Object := (Mark => False, K => K_Unspec);
   Eof_Obj    : aliased Object := (Mark => False, K => K_Eof);

   --  The one terminal input port, outside the arena; its buffer refills from the
   --  input source a line at a time (Port_Str is a live reference the GC must keep).
   Term_Port : aliased Object :=
     (Mark => False, K => K_Port, Port_Str => null, Port_Pos => 0, Port_Term => True);

   function Nil return Ref
   is (Nil_Obj'Access);
   function Lisp_True return Ref
   is (True_Obj'Access);
   function Lisp_False return Ref
   is (False_Obj'Access);
   function Unspecified return Ref
   is (Unspec_Obj'Access);
   function Eof_Object return Ref
   is (Eof_Obj'Access);
   function Current_Input return Ref
   is (Term_Port'Access);
   function Make_Bool (V : Boolean) return Ref
   is (if V then True_Obj'Access else False_Obj'Access);

   --  Text-output sink for display / write / newline (a no-op until a host sets it).
   Out_Hook : Output_Sink := null;

   procedure Set_Output (Sink : Output_Sink) is
   begin
      Out_Hook := Sink;
   end Set_Output;

   procedure Emit (S : String) is
   begin
      if Out_Hook /= null then
         Out_Hook (S);
      end if;
   end Emit;

   --  Character-input source (a no-op yielding end-of-input until a host sets it).
   In_Hook : Input_Source := null;

   procedure Set_Input (Src : Input_Source) is
   begin
      In_Hook := Src;
   end Set_Input;

   procedure Raw_Get (C : out Character; Ok : out Boolean) is
   begin
      if In_Hook /= null then
         In_Hook (C, Ok);
      else
         C := ASCII.NUL;
         Ok := False;
      end if;
   end Raw_Get;

   --------------------------------------------------------------------------
   --  The cell arena: a uniform pool with a free list.  Free cells are linked
   --  through their Car field; Alloc pops the head; GC rebuilds the list.
   --------------------------------------------------------------------------
   --  Cells are aliased (so 'Access yields a Ref), which makes them constrained by
   --  their discriminant -- a cell's kind cannot be changed through Ref.all.  So
   --  the free list is a separate array of indices, and a cell is (re)written by
   --  direct array assignment Arena (I) := Template (which does permit a kind
   --  change); the sweep only relinks indices, never rewrites a cell.
   type Cell_Array is array (Positive range <>) of aliased Object;
   type Index_Array is array (Positive range <>) of Natural;
   type Cell_Access is access Cell_Array;
   type Index_Access is access Index_Array;
   Arena      : Cell_Access := null;          --  heap-allocated (PSRAM on the board)
   Free_Next  : Index_Access := null;          --  Free_Next (I) = next free index, 0=end
   Free_Head  : Natural := 0;                  --  head index of the free list (0=empty)
   Arena_Size : Natural := 0;
   In_Use     : Natural := 0;

   function Cells_Used return Natural
   is (In_Use);

   procedure Build_Free_List is
   begin
      In_Use := 0;
      Free_Head := 1;
      for I in 1 .. Arena_Size loop
         Free_Next (I) := (if I < Arena_Size then I + 1 else 0);
      end loop;
   end Build_Free_List;

   procedure Init (Cells : Positive := 200_000) is
   begin
      Arena := new Cell_Array (1 .. Cells);
      Free_Next := new Index_Array (1 .. Cells);
      Arena_Size := Cells;
      Build_Free_List;
   end Init;

   function Alloc (Template : Object) return Ref is
      Index : Natural;   --  index of the free cell being handed out
   begin
      if Arena = null then
         Init;                                  --  lazy default (host convenience)

      end if;
      if Free_Head = 0 then
         raise Lisp_Error with "out of memory (arena full this form)";
      end if;
      Index := Free_Head;
      Free_Head := Free_Next (Index);
      Arena (Index) := Template;                     --  direct assignment: kind may change
      In_Use := In_Use + 1;
      return Arena (Index)'Access;
   end Alloc;

   function Cons (A, D : Ref) return Ref
   is (Alloc ((Mark => False, K => K_Cons, Car => A, Cdr => D)));

   function Make_Int (V : Long_Long_Integer) return Ref
   is (Alloc ((Mark => False, K => K_Int, I => V)));

   function Make_Closure (Params, Code, Env : Ref) return Ref
   is (Alloc ((Mark => False, K => K_Closure, Params => Params, Code => Code, Env => Env)));

   function Int_Value (O : Ref) return Long_Long_Integer is
   begin
      if O = null or else O.K /= K_Int then
         raise Lisp_Error with "expected an integer";
      end if;
      return O.I;
   end Int_Value;

   function Make_Float (V : Float) return Ref
   is (Alloc ((Mark => False, K => K_Float, F => V)));

   function Make_Char (C : Character) return Ref
   is (Alloc ((Mark => False, K => K_Char, Ch => C)));

   --  A string is stored as a Nil-terminated cons-chain of char cells, so it is
   --  ordinary arena garbage (no separate pool).  Build it back-to-front.
   function Make_String (S : String) return Ref is
      Chain : Ref := Nil;
   begin
      for I in reverse S'Range loop
         Chain := Cons (Make_Char (S (I)), Chain);
      end loop;
      return Alloc ((Mark => False, K => K_String, Str => Chain));
   end Make_String;

   function Float_Value (O : Ref) return Float is
   begin
      if O = null or else O.K /= K_Float then
         raise Lisp_Error with "expected a float";
      end if;
      return O.F;
   end Float_Value;

   function Char_Value (O : Ref) return Character is
   begin
      if O = null or else O.K /= K_Char then
         raise Lisp_Error with "expected a char";
      end if;
      return O.Ch;
   end Char_Value;

   function Str_Value (O : Ref) return String is
      Len : Natural := 0;
      P   : Ref;
   begin
      if O = null or else O.K /= K_String then
         raise Lisp_Error with "expected a string";
      end if;
      P := O.Str;
      while P /= null and then P.K = K_Cons loop
         Len := Len + 1;
         P := P.Cdr;
      end loop;
      return R : String (1 .. Len) do
         P := O.Str;
         for I in 1 .. Len loop
            R (I) := Char_Value (P.Car);
            P := P.Cdr;
         end loop;
      end return;
   end Str_Value;

   function Is_Float (O : Ref) return Boolean
   is (O /= null and then O.K = K_Float);
   function Is_Char (O : Ref) return Boolean
   is (O /= null and then O.K = K_Char);
   function Is_String (O : Ref) return Boolean
   is (O /= null and then O.K = K_String);
   function Is_Vector (O : Ref) return Boolean
   is (O /= null and then O.K = K_Vector);

   --  The element array is indexed 1 .. N (so N = 0 needs no special case); the
   --  Lisp-visible index is 0-based, mapped by +1 in Vector_Ref / Vector_Set.
   function Make_Vector (N : Natural; Fill : Ref) return Ref is
      V : constant Ref_Vec := new Ref_Array (1 .. N);
   begin
      for I in V'Range loop
         V (I) := Fill;
      end loop;
      return Alloc ((Mark => False, K => K_Vector, Vec => V));
   end Make_Vector;

   function Vector_Length (O : Ref) return Natural is
   begin
      if not Is_Vector (O) then
         raise Lisp_Error with "expected a vector";
      end if;
      return (if O.Vec = null then 0 else O.Vec'Length);
   end Vector_Length;

   function Vector_Ref (O : Ref; I : Natural) return Ref is
   begin
      if not Is_Vector (O) or else O.Vec = null or else I >= O.Vec'Length then
         raise Lisp_Error with "vector-ref: index out of range";
      end if;
      return O.Vec (I + 1);
   end Vector_Ref;

   procedure Vector_Set (O : Ref; I : Natural; X : Ref) is
   begin
      if not Is_Vector (O) or else O.Vec = null or else I >= O.Vec'Length then
         raise Lisp_Error with "vector-set!: index out of range";
      end if;
      O.Vec (I + 1) := X;
   end Vector_Set;

   function Is_Hash (O : Ref) return Boolean
   is (O /= null and then O.K = K_Hash);

   function Make_Hash (Buckets : Ref) return Ref
   is (Alloc ((Mark => False, K => K_Hash, HTable => Buckets)));

   function Hash_Buckets (O : Ref) return Ref is
   begin
      if not Is_Hash (O) then
         raise Lisp_Error with "expected a hash table";
      end if;
      return O.HTable;
   end Hash_Buckets;

   function Is_Eof (O : Ref) return Boolean
   is (O /= null and then O.K = K_Eof);
   function Is_Port (O : Ref) return Boolean
   is (O /= null and then O.K = K_Port);

   function Make_String_Port (S : Ref) return Ref
   is (Alloc ((Mark => False, K => K_Port, Port_Str => S, Port_Pos => 0, Port_Term => False)));

   function Port_Buffer (P : Ref) return String
   is (if not Is_Port (P) or else P.Port_Str = null then "" else Str_Value (P.Port_Str));

   function Port_Position (P : Ref) return Natural
   is (if Is_Port (P) then P.Port_Pos else 0);

   procedure Port_Advance (P : Ref; To : Natural) is
   begin
      if Is_Port (P) then
         P.Port_Pos := To;
      end if;
   end Port_Advance;

   --  Terminal refill: keep any un-consumed tail, read one line (up to CR) from the
   --  source, append it and a newline.  False only when there is nothing left at all.
   function Port_Refill (P : Ref) return Boolean is
      Old  : constant String := Port_Buffer (P);
      Kept : constant String :=
        (if P.Port_Pos >= Old'Length then "" else Old (Old'First + P.Port_Pos .. Old'Last));
      Line : String (1 .. 1024);
      N    : Natural := 0;
      C    : Character;
      Ok   : Boolean;
      Got  : Boolean := False;
   begin
      if not (Is_Port (P) and then P.Port_Term) then
         return False;
      end if;
      loop
         Raw_Get (C, Ok);
         exit when not Ok;                       --  end of input
         Got := True;
         exit when C = ASCII.CR;                 --  end of line
         if C /= ASCII.LF and then N < Line'Last then
            N := N + 1;
            Line (N) := C;
         end if;
      end loop;
      if not Got and then Kept'Length = 0 then
         return False;
      end if;
      P.Port_Str := Make_String (Kept & Line (1 .. N) & ASCII.LF);
      P.Port_Pos := 0;
      return True;
   end Port_Refill;

   function Port_Get (P : Ref) return Integer is
      S : constant String := Port_Buffer (P);
   begin
      if not Is_Port (P) then
         return -1;
      elsif P.Port_Pos >= S'Length then
         return (if Port_Refill (P) then Port_Get (P) else -1);
      end if;
      P.Port_Pos := P.Port_Pos + 1;
      return Character'Pos (S (S'First + P.Port_Pos - 1));
   end Port_Get;

   function Port_Peek (P : Ref) return Integer is
      S : constant String := Port_Buffer (P);
   begin
      if not Is_Port (P) then
         return -1;
      elsif P.Port_Pos >= S'Length then
         return (if Port_Refill (P) then Port_Peek (P) else -1);
      end if;
      return Character'Pos (S (S'First + P.Port_Pos));
   end Port_Peek;

   --------------------------------------------------------------------------
   --  Interned symbols -- stored in their own table (not the arena), so a Reset
   --  of the arena leaves symbol identity intact.
   --------------------------------------------------------------------------
   Max_Name : constant := 32;
   type Sym_Entry is record
      Name : String (1 .. Max_Name);
      Len  : Natural := 0;
      Obj  : aliased Object := (Mark => False, K => K_Symbol, Sym => 0);
   end record;
   Symbols  : array (1 .. 1024) of Sym_Entry;   --  static (internal RAM); keep modest
   N_Sym    : Natural := 0;

   function Intern (Name : String) return Ref is
      Clamped_Len : constant Natural := Natural'Min (Name'Length, Max_Name);
   begin
      for I in 1 .. N_Sym loop
         if Symbols (I).Len = Name'Length and then Symbols (I).Name (1 .. Symbols (I).Len) = Name
         then
            return Symbols (I).Obj'Access;
         end if;
      end loop;
      if N_Sym >= Symbols'Last then
         raise Lisp_Error with "symbol table full";
      end if;
      N_Sym := N_Sym + 1;
      Symbols (N_Sym).Len := Clamped_Len;
      Symbols (N_Sym).Name (1 .. Clamped_Len) := Name (Name'First .. Name'First + Clamped_Len - 1);
      Symbols (N_Sym).Obj := (Mark => False, K => K_Symbol, Sym => Symbol_Id (N_Sym));
      return Symbols (N_Sym).Obj'Access;
   end Intern;

   function Name_Of (Id : Symbol_Id) return String
   is (Symbols (Natural (Id)).Name (1 .. Symbols (Natural (Id)).Len));

   function Make_Prim (Name : String; Fn : Prim_Fn) return Ref is
      Sym : constant Ref := Intern (Name);   --  canonical symbol for the name
   begin
      return Alloc ((Mark => False, K => K_Prim, Fn => Fn, Fn_Name => Sym.Sym));
   end Make_Prim;

   function Symbol_Name (O : Ref) return String
   is (Name_Of (O.Sym));

   --------------------------------------------------------------------------
   --  Accessors / predicates
   --------------------------------------------------------------------------
   function Is_Nil (O : Ref) return Boolean
   is (O = null or else O.K = K_Nil);
   function Is_Cons (O : Ref) return Boolean
   is (O /= null and then O.K = K_Cons);
   function Is_Symbol (O : Ref) return Boolean
   is (O /= null and then O.K = K_Symbol);

   function Is_Truthy (O : Ref) return Boolean
   is (not (Is_Nil (O) or else (O.K = K_Bool and then not O.B)));

   function Car (O : Ref) return Ref is
   begin
      if not Is_Cons (O) then
         raise Lisp_Error with "car of non-pair";
      end if;
      return O.Car;
   end Car;

   function Cdr (O : Ref) return Ref is
   begin
      if not Is_Cons (O) then
         raise Lisp_Error with "cdr of non-pair";
      end if;
      return O.Cdr;
   end Cdr;

   --------------------------------------------------------------------------
   --  Printer
   --------------------------------------------------------------------------
   function Int_Image (V : Long_Long_Integer) return String is
      Str : constant String := Long_Long_Integer'Image (V);
   begin
      return (if V < 0 then Str else Str (Str'First + 1 .. Str'Last));  -- drop leading space
   end Int_Image;

   --  Print a single float: sign, integer part, '.', up to six trimmed fractional
   --  digits (so 3.0 -> "3.", 0.25 -> "0.25").  Falls back to Ada's image for
   --  magnitudes too large for the fixed formatter.
   function Float_Image (V : Float) return String is
      Neg : constant Boolean := V < 0.0;
      U   : constant Float := abs V;
   begin
      if U >= 1.0e9 then
         declare
            S : constant String := Float'Image (V);
         begin
            return (if S (S'First) = ' ' then S (S'First + 1 .. S'Last) else S);
         end;
      end if;
      declare
         Scaled : constant Long_Long_Integer := Long_Long_Integer (Float'Rounding (U * 1.0e6));
         IPart  : constant Long_Long_Integer := Scaled / 1_000_000;
         FPart  : Long_Long_Integer := Scaled mod 1_000_000;
         Buf    : String (1 .. 6);
         N      : Natural := 6;
      begin
         for K in reverse 1 .. 6 loop
            Buf (K) := Character'Val (Character'Pos ('0') + Integer (FPart mod 10));
            FPart := FPart / 10;
         end loop;
         while N > 0 and then Buf (N) = '0' loop
            N := N - 1;
         end loop;
         return (if Neg then "-" else "") & Int_Image (IPart) & "." & Buf (1 .. N);
      end;
   end Float_Image;

   Backslash : constant Character := '\';

   --  A char in #\ notation, naming the common non-printing ones.
   function Char_Image (C : Character) return String is
   begin
      case C is
         when ' '      =>
            return "#\space";

         when ASCII.LF =>
            return "#\newline";

         when ASCII.HT =>
            return "#\tab";

         when others   =>
            return "#\" & C;
      end case;
   end Char_Image;

   --  A string in write notation: double-quoted, with " \ newline tab escaped.
   function String_Image (O : Ref) return String is
      S      : constant String := Str_Value (O);
      Result : String (1 .. 2 * S'Length + 2);
      N      : Natural := 1;
   begin
      Result (1) := '"';
      for C of S loop
         case C is
            when '"'      =>
               Result (N + 1 .. N + 2) := Backslash & '"';
               N := N + 2;

            when '\'      =>
               Result (N + 1 .. N + 2) := Backslash & Backslash;
               N := N + 2;

            when ASCII.LF =>
               Result (N + 1 .. N + 2) := Backslash & 'n';
               N := N + 2;

            when ASCII.HT =>
               Result (N + 1 .. N + 2) := Backslash & 't';
               N := N + 2;

            when others   =>
               N := N + 1;
               Result (N) := C;
         end case;
      end loop;
      N := N + 1;
      Result (N) := '"';
      return Result (1 .. N);
   end String_Image;

   --  Render an object to text.  Readable = True is the write form (strings
   --  quoted-and-escaped, chars in #\ notation); False is the display form (raw).
   function Render (O : Ref; Readable : Boolean) return String is

      function Render_List (P : Ref) return String is
      begin
         if Is_Nil (Cdr (P)) then
            return Render (Car (P), Readable);
         elsif Is_Cons (Cdr (P)) then
            return Render (Car (P), Readable) & " " & Render_List (Cdr (P));
         else
            return Render (Car (P), Readable) & " . " & Render (Cdr (P), Readable);
         end if;
      end Render_List;

      function Render_Vector (V : Ref) return String is
         function Join (I : Natural) return String
         is (if I = V.Vec'Last
             then Render (V.Vec (I), Readable)
             else Render (V.Vec (I), Readable) & " " & Join (I + 1));
      begin
         if V.Vec = null or else V.Vec'Length = 0 then
            return "#()";
         end if;
         return "#(" & Join (V.Vec'First) & ")";
      end Render_Vector;

   begin
      if O = null then
         return "()";
      end if;
      case O.K is
         when K_Nil     =>
            return "()";

         when K_Unspec  =>
            return "";                            --  no visible result

         when K_Bool    =>
            return (if O.B then "#t" else "#f");

         when K_Int     =>
            return Int_Image (O.I);

         when K_Float   =>
            return Float_Image (O.F);

         when K_Char    =>
            return (if Readable then Char_Image (O.Ch) else (1 => O.Ch));

         when K_String  =>
            return (if Readable then String_Image (O) else Str_Value (O));

         when K_Symbol  =>
            return Name_Of (O.Sym);

         when K_Cons    =>
            return "(" & Render_List (O) & ")";

         when K_Prim    =>
            return "#<primitive " & Name_Of (O.Fn_Name) & ">";

         when K_Closure =>
            return "#<closure>";

         when K_Vector  =>
            return Render_Vector (O);

         when K_Hash    =>
            return "#<hash-table>";

         when K_Eof     =>
            return "#<eof>";

         when K_Port    =>
            return "#<input-port>";
      end case;
   end Render;

   function Print (O : Ref) return String
   is (Render (O, True));

   function Display_Str (O : Ref) return String
   is (Render (O, False));

   --------------------------------------------------------------------------
   --  Garbage collection (mark + sweep)
   --------------------------------------------------------------------------
   procedure Mark_Obj (O : Ref) is
   begin
      if O = null or else O.Mark then
         return;                                --  null, or already visited (cycles)

      end if;
      O.Mark := True;
      case O.K is
         when K_Cons    =>
            Mark_Obj (O.Car);
            Mark_Obj (O.Cdr);

         when K_Closure =>
            Mark_Obj (O.Params);
            Mark_Obj (O.Code);
            Mark_Obj (O.Env);

         when K_String  =>
            Mark_Obj (O.Str);   --  the char cons-chain

         when K_Vector  =>
            if O.Vec /= null then
               for I in O.Vec'Range loop
                  Mark_Obj (O.Vec (I));
               end loop;
            end if;

         when K_Hash    =>
            Mark_Obj (O.HTable);   --  the bucket vector (reaches all entries)

         when K_Port    =>
            Mark_Obj (O.Port_Str); --  the input buffer

         when others    =>
            null;               --  no outgoing arena references (Int/Float/Char/...)
      end case;
   end Mark_Obj;

   function GC (Root : Ref) return Natural is
      Reclaimed : Natural := 0;
   begin
      if Arena = null then
         return 0;
      end if;
      Mark_Obj (Root);
      Mark_Obj (Current_Input);   --  the terminal port's pending buffer is a root
      Free_Head := 0;
      In_Use := 0;
      for I in Arena'Range loop
         --  sweep
         if Arena (I).Mark then
            Arena (I).Mark := False;            --  live: keep, clear the bit
            In_Use := In_Use + 1;
         else
            if Arena (I).K = K_Vector and then Arena (I).Vec /= null then
               Free_Vec (Arena (I).Vec);        --  free the backing (nulls Vec too)

            end if;
            Free_Next (I) := Free_Head;          --  free: relink index (no rewrite)
            Free_Head := I;
            Reclaimed := Reclaimed + 1;
         end if;
      end loop;
      return Reclaimed;
   end GC;

   procedure Reset is
   begin
      if Arena /= null then
         for I in Arena'Range loop
            --  Reset orphans every cell; free any
            if Arena (I).K = K_Vector and then Arena (I).Vec /= null then
               Free_Vec (Arena (I).Vec);      --  vector backings first, or they leak

            end if;
         end loop;
         Build_Free_List;
      end if;
   end Reset;

end Lisp;
