with Interfaces;              use Interfaces;
with System;
with System.Storage_Elements; use System.Storage_Elements;
with System.Machine_Code;     use System.Machine_Code;

package body Intr_Vector_Test is

   --  ROM console printf, for Log (the fire path prints from the fragile handler
   --  context, so it keeps the always-available ROM printf).
   procedure Rom_Printf (Fmt : System.Address; N : Interfaces.C.int);
   pragma Import (C, Rom_Printf, "esp_rom_printf");
   Log_Fmt : constant String := "[intr] %d" & ASCII.LF & ASCII.NUL;

   --  Interrupt-matrix source -> CPU-int map registers (5-bit fields), and the
   --  SYSTEM FROM_CPU registers (assert = 1 / clear = 0).
   From_CPU0_Map : Unsigned_32
     with Volatile, Import, Address => To_Address (16#600C_213C#);
   From_CPU1_Map : Unsigned_32
     with Volatile, Import, Address => To_Address (16#600C_2140#);
   Sys_From_CPU0 : Unsigned_32
     with Volatile, Import, Address => To_Address (16#600C_0030#);
   Sys_From_CPU1 : Unsigned_32
     with Volatile, Import, Address => To_Address (16#600C_0034#);

   -----------
   -- Setup --
   -----------

   procedure Setup is
   begin
      From_CPU0_Map := 19;   --  FROM_CPU_0 -> L2 (CPU_INT 19)
      From_CPU1_Map := 23;   --  FROM_CPU_1 -> L3 (CPU_INT 23)
   end Setup;

   procedure Fire_L2  is begin Sys_From_CPU0 := 1; end Fire_L2;
   procedure Fire_L3  is begin Sys_From_CPU1 := 1; end Fire_L3;
   procedure Clear_L2 is begin Sys_From_CPU0 := 0; end Clear_L2;
   procedure Clear_L3 is begin Sys_From_CPU1 := 0; end Clear_L3;

   ------------
   -- Get_TP --
   ------------

   function Get_TP return Interfaces.C.unsigned is
      V : Unsigned_32;
   begin
      Asm ("rur.threadptr %0",
           Outputs  => Unsigned_32'Asm_Output ("=r", V),
           Volatile => True);
      return Interfaces.C.unsigned (V);
   end Get_TP;

   ------------
   -- Set_TP --
   ------------

   procedure Set_TP (V : Interfaces.C.unsigned) is
   begin
      Asm ("wur.threadptr %0",
           Inputs   => Unsigned_32'Asm_Input ("r", Unsigned_32 (V)),
           Volatile => True);
   end Set_TP;

   ---------
   -- Log --
   ---------

   procedure Log (Marker : Interfaces.C.int) is
   begin
      Rom_Printf (Log_Fmt'Address, Marker);
   end Log;

end Intr_Vector_Test;
