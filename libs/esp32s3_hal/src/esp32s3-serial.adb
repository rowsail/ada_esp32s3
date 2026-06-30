with ESP32S3.Console;

package body ESP32S3.Serial is

   --  Adapters binding the USB Serial/JTAG console to the Device vtable.  The
   --  console is a singleton, so Ctx is unused.
   procedure Console_Write (Ctx : System.Address; S : String) is
      pragma Unreferenced (Ctx);
   begin
      ESP32S3.Console.Write (S);
   end Console_Write;

   procedure Console_Flush (Ctx : System.Address) is
      pragma Unreferenced (Ctx);
   begin
      ESP32S3.Console.Flush;
   end Console_Flush;

   The_Console : constant Device :=
     (Write => Console_Write'Access,
      Flush => Console_Flush'Access,
      Ctx   => System.Null_Address);

   Current : Device := The_Console;

   function Console_Device return Device is (The_Console);
   function Output         return Device is (Current);

   procedure Set_Output (D : Device) is
   begin
      Flush;            --  don't strand bytes in the device we are leaving
      Current := D;
   end Set_Output;

   procedure Write (S : String) is
   begin
      if Current.Write /= null then
         Current.Write (Current.Ctx, S);
      end if;
   end Write;

   procedure Put (C : Character) is
   begin
      Write ((1 => C));
   end Put;

   procedure Flush is
   begin
      if Current.Flush /= null then
         Current.Flush (Current.Ctx);
      end if;
   end Flush;

   --  Bridge the runtime console (Ada.Text_IO -> System.Text_IO) into this mux,
   --  so Put_Line and friends land on the same device as ESP32S3.Log and follow
   --  Set_Output.  We install a per-character sink the runtime calls; until then
   --  (and in programs that never pull in this package) System.Text_IO keeps its
   --  ROM-printf path.  The sink must be library-level (No_Implicit_Dynamic_Code).
   type Console_Hook is access procedure (C : Character);
   pragma Convention (C, Console_Hook);

   procedure Install_Console_Hook (H : Console_Hook)
     with Import, Convention => C,
          External_Name => "__esp32s3_install_console_hook";

   procedure Text_IO_Sink (C : Character) with Convention => C;
   procedure Text_IO_Sink (C : Character) is
   begin
      Put (C);   --  -> the currently selected device
   end Text_IO_Sink;

begin
   Install_Console_Hook (Text_IO_Sink'Access);
end ESP32S3.Serial;
