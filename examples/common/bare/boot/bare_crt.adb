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
         --  skip leading blanks
         C := Load (S + I);
         exit when C /= Ch_Sp and then C /= Ch_HT;
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

   procedure Hal_Log_Cstr (S : System.Address)
   with Import, Convention => C, External_Name => "hal_log_cstr";

   function Write
     (Fd : Interfaces.C.int; Buf : System.Address; N : Interfaces.C.unsigned)
      return Interfaces.C.int
   is
      pragma Unreferenced (Fd);
      Len : constant Natural := Natural (N);
      --  Copy into a NUL-terminated buffer and emit with one "%s" (console text
      --  has no embedded NUL; a NUL byte would truncate, as for any "%s").
      Tmp : String (1 .. Len + 1);
   begin
      for I in 0 .. Len - 1 loop
         Tmp (I + 1) := Character'Val (Integer (Load (Buf + Storage_Offset (I))));
      end loop;
      Tmp (Len + 1) := ASCII.NUL;
      Hal_Log_Cstr (Tmp'Address);
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
