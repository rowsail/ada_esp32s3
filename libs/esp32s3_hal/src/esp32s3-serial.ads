with System;

--  Character-output multiplexer: a thin redirection layer so console-style
--  output -- ESP32S3.Log, and anything else routed through here -- can be sent
--  to ANY serial device without the producer knowing which.  The default is the
--  built-in USB Serial/JTAG console (ESP32S3.Console); Set_Output switches it to,
--  e.g., a UART (see ESP32S3.UART.Text).
--
--  A device is a tiny vtable -- Write a string, Flush -- plus an opaque Ctx that
--  carries the device's own state (e.g. a held UART Session), so one vtable can
--  serve many instances.  ZFP-safe (no tasking/exceptions/heap).  The vtable
--  procedures must be LIBRARY-LEVEL (No_Implicit_Dynamic_Code bars 'Access of a
--  nested one -- no trampolines).
package ESP32S3.Serial is

   type Write_Proc is access procedure (Ctx : System.Address; S : String);
   type Flush_Proc is access procedure (Ctx : System.Address);

   --  A character-output device.  Ctx is handed back to Write/Flush.
   type Device is record
      Write : Write_Proc     := null;
      Flush : Flush_Proc     := null;
      Ctx   : System.Address := System.Null_Address;
   end record;

   --  Symmetric INPUT side of the mux.  A Read_Proc fetches at most one character
   --  WITHOUT blocking: Available is True and C holds the byte when one was ready,
   --  False (C = NUL) when none is.  The vtable procedure must be LIBRARY-LEVEL
   --  (No_Implicit_Dynamic_Code bars 'Access of a nested one).
   type Read_Proc is access procedure
     (Ctx : System.Address; C : out Character; Available : out Boolean);

   --  A character-input device.  Ctx is handed back to Read.
   type In_Device is record
      Read : Read_Proc      := null;
      Ctx  : System.Address := System.Null_Address;
   end record;

   --  Redirect all output to D.  Flushes the previous device first so nothing is
   --  stranded in its buffer.  Default at startup is the USB Serial/JTAG console.
   procedure Set_Output (D : Device);

   --  The currently selected device, and the default console device -- so a
   --  caller can save/restore: Old := Output;  ...  Set_Output (Old);  or revert
   --  with Set_Output (Console_Device).
   function Output return Device;
   function Console_Device return Device;

   --  Output primitives -- dispatch to the active device.
   procedure Write (S : String);
   procedure Put (C : Character);
   procedure Flush;

   --  Redirect all console INPUT to D.  Default at startup is the USB Serial/JTAG
   --  console; switch to, e.g., a UART with ESP32S3.UART.Text.As_Input_Device.
   procedure Set_Input (D : In_Device);

   --  The currently selected input device, and the default console input device
   --  (for save/restore, symmetric with Output / Console_Device).
   function Input return In_Device;
   function Console_In_Device return In_Device;

   --  Input primitive -- dispatch to the active input device.  Non-blocking:
   --  Available is False (C = NUL) when no character is ready.
   procedure Get (C : out Character; Available : out Boolean);

end ESP32S3.Serial;
