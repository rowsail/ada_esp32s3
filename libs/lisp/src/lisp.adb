package body Lisp is

   --  Singletons -- canonical, outside the arena so they always stay valid.
   Nil_Obj   : aliased Object := (Mark => False, K => K_Nil);
   True_Obj  : aliased Object := (Mark => False, K => K_Bool, B => True);
   False_Obj : aliased Object := (Mark => False, K => K_Bool, B => False);

   function Nil return Ref
   is (Nil_Obj'Access);
   function Lisp_True return Ref
   is (True_Obj'Access);
   function Lisp_False return Ref
   is (False_Obj'Access);
   function Make_Bool (V : Boolean) return Ref
   is (if V then True_Obj'Access else False_Obj'Access);

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

   function Print (O : Ref) return String is

      function Print_List (P : Ref) return String is
      begin
         if Is_Nil (Cdr (P)) then
            return Print (Car (P));
         elsif Is_Cons (Cdr (P)) then
            return Print (Car (P)) & " " & Print_List (Cdr (P));
         else
            return Print (Car (P)) & " . " & Print (Cdr (P));   -- improper list
         end if;
      end Print_List;

   begin
      if O = null then
         return "()";
      end if;
      case O.K is
         when K_Nil     =>
            return "()";

         when K_Bool    =>
            return (if O.B then "#t" else "#f");

         when K_Int     =>
            return Int_Image (O.I);

         when K_Symbol  =>
            return Name_Of (O.Sym);

         when K_Cons    =>
            return "(" & Print_List (O) & ")";

         when K_Prim    =>
            return "#<primitive " & Name_Of (O.Fn_Name) & ">";

         when K_Closure =>
            return "#<closure>";
      end case;
   end Print;

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

         when others    =>
            null;               --  no outgoing arena references
      end case;
   end Mark_Obj;

   function GC (Root : Ref) return Natural is
      Reclaimed : Natural := 0;
   begin
      if Arena = null then
         return 0;
      end if;
      Mark_Obj (Root);
      Free_Head := 0;
      In_Use := 0;
      for I in Arena'Range loop
         --  sweep
         if Arena (I).Mark then
            Arena (I).Mark := False;            --  live: keep, clear the bit
            In_Use := In_Use + 1;
         else
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
         Build_Free_List;
      end if;
   end Reset;

end Lisp;
