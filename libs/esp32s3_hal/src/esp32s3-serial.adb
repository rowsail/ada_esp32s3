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

   function Console_Device return Device
   is (The_Console);
   function Output return Device
   is (Current);

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

   --  Input side of the mux.  Symmetric with the output side above: a default
   --  device bound to the USB Serial/JTAG console, redirectable with Set_Input.
   procedure Console_Read
     (Ctx : System.Address; C : out Character; Available : out Boolean)
   is
      pragma Unreferenced (Ctx);
   begin
      ESP32S3.Console.Read (C, Available);
   end Console_Read;

   The_Console_In : constant In_Device :=
     (Read => Console_Read'Access, Ctx => System.Null_Address);

   Current_In : In_Device := The_Console_In;

   function Console_In_Device return In_Device
   is (The_Console_In);
   function Input return In_Device
   is (Current_In);

   procedure Set_Input (D : In_Device) is
   begin
      Current_In := D;
   end Set_Input;

   procedure Get (C : out Character; Available : out Boolean) is
   begin
      if Current_In.Read /= null then
         Current_In.Read (Current_In.Ctx, C, Available);
      else
         C := ASCII.NUL;
         Available := False;
      end if;
   end Get;

   --  Bridge the runtime console (Ada.Text_IO -> System.Text_IO) into this mux,
   --  so Put_Line and friends land on the same device as ESP32S3.Log and follow
   --  Set_Output.  We install a per-character sink the runtime calls; until then
   --  (and in programs that never pull in this package) System.Text_IO keeps its
   --  ROM-printf path.  The sink must be library-level (No_Implicit_Dynamic_Code).
   type Console_Hook is access procedure (C : Character);
   pragma Convention (C, Console_Hook);

   procedure Install_Console_Hook (H : Console_Hook)
   with
     Import,
     Convention    => C,
     External_Name => "__esp32s3_install_console_hook";

   procedure Text_IO_Sink (C : Character)
   with Convention => C;
   procedure Text_IO_Sink (C : Character) is
   begin
      Put (C);   --  -> the currently selected device
   end Text_IO_Sink;

begin
   Install_Console_Hook (Text_IO_Sink'Access);
end ESP32S3.Serial;
