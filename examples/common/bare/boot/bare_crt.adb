with System.Storage_Elements; use System.Storage_Elements;

package body Bare_Crt is

   use type Interfaces.C.unsigned;

   --  Byte (char) at an address (overlay; -gnatp, no checks).
   function Load (A : System.Address) return Storage_Element is
      B : Storage_Element
      with Import, Address => A;
   begin
      return B;
   end Load;

   Ch_0  : constant Storage_Element := Character'Pos ('0');
   Ch_9  : constant Storage_Element := Character'Pos ('9');
   Ch_Sp : constant Storage_Element := Character'Pos (' ');
   Ch_HT : constant Storage_Element := Character'Pos (ASCII.HT);
   Ch_LF : constant Storage_Element := Character'Pos (ASCII.LF);
   Ch_VT : constant Storage_Element := Character'Pos (ASCII.VT);
   Ch_FF : constant Storage_Element := Character'Pos (ASCII.FF);
   Ch_CR : constant Storage_Element := Character'Pos (ASCII.CR);

   ------------
   -- Strlen --
   ------------

   function Strlen (S : System.Address) return Interfaces.C.size_t is
      N : Storage_Offset := 0;
   begin
      while Load (S + N) /= 0 loop
         N := N + 1;
      end loop;
      return Interfaces.C.size_t (N);
   end Strlen;

   ------------
   -- Strcmp --
   ------------

   function Strcmp (A, B : System.Address) return Interfaces.C.int is
      I      : Storage_Offset := 0;
      Ca, Cb : Storage_Element;
   begin
      loop
         Ca := Load (A + I);
         Cb := Load (B + I);
         if Ca /= Cb or else Ca = 0 then
            return Interfaces.C.int (Integer (Ca) - Integer (Cb));
         end if;
         I := I + 1;
      end loop;
   end Strcmp;

   ----------
   -- Atoi --
   ----------

   function Atoi (S : System.Address) return Interfaces.C.int is
      I    : Storage_Offset := 0;
      Sign : Integer := 1;
      V    : Integer := 0;
      C    : Storage_Element;
   begin
      loop
         --  skip leading whitespace (C isspace: space, \t \n \v \f \r)
         C := Load (S + I);
         exit when C /= Ch_Sp and then C /= Ch_HT and then C /= Ch_LF
           and then C /= Ch_VT and then C /= Ch_FF and then C /= Ch_CR;
         I := I + 1;
      end loop;
      C := Load (S + I);                      --  optional sign
      if C = Character'Pos ('-') then
         Sign := -1;
         I := I + 1;
      elsif C = Character'Pos ('+') then
         I := I + 1;
      end if;
      loop
         --  digits
         C := Load (S + I);
         exit when C < Ch_0 or else C > Ch_9;
         V := V * 10 + (Integer (C) - Integer (Ch_0));
         I := I + 1;
      end loop;
      return Interfaces.C.int (Sign * V);
   end Atoi;

   ------------
   -- Getenv --
   ------------

   function Getenv (Name : System.Address) return System.Address is
      pragma Unreferenced (Name);
   begin
      return System.Null_Address;
   end Getenv;

   -----------
   -- Write --
   -----------

   --  ROM console output: the chip mask-ROM printf (esp_rom_printf), imported
   --  directly the way the RTS's System.Text_IO does -- a ROM ABI symbol, not
   --  linked C.  A "%s" format prints the string verbatim.  This replaces the
   --  former hal_log_cstr shim in bare_log.c (now removed): one fewer C file, same
   --  bytes on the wire.
   procedure Rom_Printf (Format : System.Address; Item : System.Address)
   with Import, Convention => C, External_Name => "esp_rom_printf";

   Str_Fmt : constant String := "%s" & ASCII.NUL;

   function Write
     (Fd : Interfaces.C.int; Buf : System.Address; N : Interfaces.C.unsigned)
      return Interfaces.C.int
   is
      pragma Unreferenced (Fd);
      Len : constant Natural := Natural (N);
      --  Emit in fixed-size NUL-terminated chunks: a dynamic String (1 .. Len+1)
      --  put the whole payload on the (16 KB) task stack, so a large write could
      --  overflow it.  Chunking bounds stack use to Chunk+1 bytes regardless of N.
      --  (Console text has no embedded NUL; a NUL byte truncates, as for any "%s".)
      Chunk : constant := 128;
      Tmp   : String (1 .. Chunk + 1);
      Done  : Natural := 0;
      This  : Natural;
   begin
      while Done < Len loop
         This := Natural'Min (Chunk, Len - Done);
         for I in 0 .. This - 1 loop
            Tmp (I + 1) :=
              Character'Val (Integer (Load (Buf + Storage_Offset (Done + I))));
         end loop;
         Tmp (This + 1) := ASCII.NUL;
         Rom_Printf (Str_Fmt'Address, Tmp'Address);
         Done := Done + This;
      end loop;
      return Interfaces.C.int (N);
   end Write;

   ----------------
   -- Abort_Exec --
   ----------------

   procedure Esp_Restart
   with Import, Convention => C, External_Name => "esp_restart";

   procedure Abort_Exec is
   begin
      Esp_Restart;
      loop
         null;
      end loop;
   end Abort_Exec;

   -----------------------
   -- Register_Eh_Frames --
   -----------------------

   Eh_Frame_Start : Storage_Element
   with Import, Convention => C, External_Name => "__eh_frame_start";

   procedure Register_Frame (Fde : System.Address)
   with Import, Convention => C, External_Name => "__register_frame";

   procedure Register_Eh_Frames is
   begin
      Register_Frame (Eh_Frame_Start'Address);
   end Register_Eh_Frames;

end Bare_Crt;
