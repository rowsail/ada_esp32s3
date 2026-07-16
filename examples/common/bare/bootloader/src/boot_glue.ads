--  Freestanding abort/__assert_func the ZFP bootloader needs -- a failed runtime
--  check or a ROM assert lands here.  Replaces the C stubs that were in
--  psram_glue.c (mem* now come from the shared Ada Bare_Mem).  Exported under the
--  exact C names GCC and the ROM expect; each prints via esp_rom_printf and spins.
with System;

package Boot_Glue is

   procedure Abort_Boot
     with No_Return, Export, Convention => C, External_Name => "abort";

   --  C: void __assert_func(const char *file, int line, const char *fn,
   --                        const char *expr)
   procedure Assert_Fail
     (File : System.Address; Line : Integer; Func, Expr : System.Address)
     with No_Return, Export, Convention => C, External_Name => "__assert_func";

end Boot_Glue;
