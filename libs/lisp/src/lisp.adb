package body Lisp is

   --  Singletons -- canonical, outside the resettable arena so they stay valid.
   Nil_Obj   : aliased Object := (K => K_Nil);
   True_Obj  : aliased Object := (K => K_Bool, B => True);
   False_Obj : aliased Object := (K => K_Bool, B => False);

   function Nil        return Ref is (Nil_Obj'Access);
   function Lisp_True  return Ref is (True_Obj'Access);
   function Lisp_False return Ref is (False_Obj'Access);
   function Make_Bool  (V : Boolean) return Ref is
     (if V then True_Obj'Access else False_Obj'Access);

   --------------------------------------------------------------------------
   --  The cell arena: a uniform pool, bump-allocated.  No GC yet.
   --------------------------------------------------------------------------
   type Cell_Array is array (Positive range <>) of aliased Object;
   type Cell_Array_Access is access Cell_Array;
   Arena      : Cell_Array_Access := null;     --  heap-allocated (PSRAM on the board)
   Arena_Size : Natural := 0;
   Next       : Natural := 0;

   function Cells_Used return Natural is (Next);

   procedure Init (Cells : Positive := 200_000) is
   begin
      Arena      := new Cell_Array (1 .. Cells);
      Arena_Size := Cells;
      Next       := 0;
   end Init;

   function Alloc (Template : Object) return Ref is
   begin
      if Arena = null then
         Init;                                 --  lazy default (host convenience)
      end if;
      if Next >= Arena_Size then
         raise Lisp_Error with "arena exhausted (no GC yet)";
      end if;
      Next := Next + 1;
      Arena (Next) := Template;
      return Arena (Next)'Access;
   end Alloc;

   function Cons (A, D : Ref) return Ref is
     (Alloc ((K => K_Cons, Car => A, Cdr => D)));

   function Make_Int (V : Long_Long_Integer) return Ref is
     (Alloc ((K => K_Int, I => V)));

   function Make_Closure (Params, Code, Env : Ref) return Ref is
     (Alloc ((K => K_Closure, Params => Params, Code => Code, Env => Env)));

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
      Obj  : aliased Object := (K => K_Symbol, Sym => 0);
   end record;
   Symbols : array (1 .. 1024) of Sym_Entry;   --  static (internal RAM); keep modest
   N_Sym   : Natural := 0;

   function Intern (Name : String) return Ref is
      L : constant Natural := Natural'Min (Name'Length, Max_Name);
   begin
      for I in 1 .. N_Sym loop
         if Symbols (I).Len = Name'Length
           and then Symbols (I).Name (1 .. Symbols (I).Len) = Name
         then
            return Symbols (I).Obj'Access;
         end if;
      end loop;
      if N_Sym >= Symbols'Last then
         raise Lisp_Error with "symbol table full";
      end if;
      N_Sym := N_Sym + 1;
      Symbols (N_Sym).Len := L;
      Symbols (N_Sym).Name (1 .. L) := Name (Name'First .. Name'First + L - 1);
      Symbols (N_Sym).Obj := (K => K_Symbol, Sym => Symbol_Id (N_Sym));
      return Symbols (N_Sym).Obj'Access;
   end Intern;

   function Name_Of (Id : Symbol_Id) return String is
     (Symbols (Natural (Id)).Name (1 .. Symbols (Natural (Id)).Len));

   function Make_Prim (Name : String; Fn : Prim_Fn) return Ref is
      Sym : constant Ref := Intern (Name);   --  canonical symbol for the name
   begin
      return Alloc ((K => K_Prim, Fn => Fn, Fn_Name => Sym.Sym));
   end Make_Prim;

   function Symbol_Name (O : Ref) return String is (Name_Of (O.Sym));

   --------------------------------------------------------------------------
   --  Accessors / predicates
   --------------------------------------------------------------------------
   function Is_Nil    (O : Ref) return Boolean is (O = null or else O.K = K_Nil);
   function Is_Cons   (O : Ref) return Boolean is (O /= null and then O.K = K_Cons);
   function Is_Symbol (O : Ref) return Boolean is (O /= null and then O.K = K_Symbol);

   function Is_Truthy (O : Ref) return Boolean is
     (not (Is_Nil (O) or else (O.K = K_Bool and then not O.B)));

   function Car (O : Ref) return Ref is
   begin
      if not Is_Cons (O) then raise Lisp_Error with "car of non-pair"; end if;
      return O.Car;
   end Car;

   function Cdr (O : Ref) return Ref is
   begin
      if not Is_Cons (O) then raise Lisp_Error with "cdr of non-pair"; end if;
      return O.Cdr;
   end Cdr;

   --------------------------------------------------------------------------
   --  Printer
   --------------------------------------------------------------------------
   function Int_Image (V : Long_Long_Integer) return String is
      S : constant String := Long_Long_Integer'Image (V);
   begin
      return (if V < 0 then S else S (S'First + 1 .. S'Last));  -- drop leading space
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
      if O = null then return "()"; end if;
      case O.K is
         when K_Nil     => return "()";
         when K_Bool    => return (if O.B then "#t" else "#f");
         when K_Int     => return Int_Image (O.I);
         when K_Symbol  => return Name_Of (O.Sym);
         when K_Cons    => return "(" & Print_List (O) & ")";
         when K_Prim    => return "#<primitive " & Name_Of (O.Fn_Name) & ">";
         when K_Closure => return "#<closure>";
      end case;
   end Print;

   procedure Reset is
   begin
      Next := 0;
   end Reset;

end Lisp;
