package body Boot_Glue is

   --  ROM console (variadic; the fixed arities we use).  Format strings are kept
   --  local to each subprogram so this ZFP unit needs no elaboration.
   function P1 (F : System.Address) return Integer
     with Import, Convention => C, External_Name => "esp_rom_printf";
   function P3 (F : System.Address; A, B, C : System.Address) return Integer
     with Import, Convention => C, External_Name => "esp_rom_printf";
   Ign : Integer;

   ----------------
   -- Abort_Boot --
   ----------------

   procedure Abort_Boot is
      Msg : constant String := "[boot] abort()" & ASCII.LF & ASCII.NUL;
   begin
      Ign := P1 (Msg'Address);
      loop
         null;
      end loop;
   end Abort_Boot;

   -----------------
   -- Assert_Fail --
   -----------------

   procedure Assert_Fail
     (File : System.Address; Line : Integer; Func, Expr : System.Address)
   is
      pragma Unreferenced (Line);
      Msg : constant String :=
        "[boot] assert %s: %s (%s)" & ASCII.LF & ASCII.NUL;
   begin
      Ign := P3 (Msg'Address, File, Func, Expr);
      Abort_Boot;
   end Assert_Fail;

end Boot_Glue;
