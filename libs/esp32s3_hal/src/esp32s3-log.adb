with Interfaces;     use Interfaces;
with ESP32S3.Serial;

package body ESP32S3.Log is

   --  Output goes through ESP32S3.Serial -- the device multiplexer -- so it lands
   --  on whichever serial device is currently selected (the backpressured USB
   --  Serial/JTAG console by default, or a UART after ESP32S3.Serial.Set_Output).
   --  Serial.Write takes a plain slice, so nothing here needs NUL-termination.

   ---------
   -- Put --
   ---------

   procedure Put (S : String) is
   begin
      Serial.Write (S);
   end Put;

   procedure Put (C : Character) is
   begin
      Serial.Put (C);
   end Put;

   --------------
   -- New_Line --
   --------------

   procedure New_Line is
   begin
      Serial.Put (ASCII.LF);
   end New_Line;

   --------------
   -- Put_Line --
   --------------

   procedure Put_Line (S : String := "") is
   begin
      Put (S);
      New_Line;
   end Put_Line;

   ---------
   -- Put --
   ---------

   procedure Put (N : Integer; Width : Natural := 0; Pad : Character := ' ') is
      Digits_Buf : String (1 .. 11);            --  up to 10 digits
      D_First    : Natural := Digits_Buf'Last + 1;
      Neg        : constant Boolean := N < 0;
      U          : Long_Long_Integer := Long_Long_Integer (N);
   begin
      if Neg then
         U := -U;                                --  in 64-bit: safe for Integer'First
      end if;
      loop                                       --  digits, least-significant first
         D_First := D_First - 1;
         Digits_Buf (D_First) :=
           Character'Val (Character'Pos ('0') + Integer (U mod 10));
         U := U / 10;
         exit when U = 0;
      end loop;

      declare
         Digs     : constant String  := Digits_Buf (D_First .. Digits_Buf'Last);
         Sign_Len : constant Natural := (if Neg then 1 else 0);
         Body_Len : constant Natural := Sign_Len + Digs'Length;
         Pad_Len  : constant Natural :=
           (if Width > Body_Len then Width - Body_Len else 0);
         Out_Buf  : String (1 .. Body_Len + Pad_Len);
         P        : Natural := 0;
      begin
         if Pad = '0' then
            if Neg then P := P + 1; Out_Buf (P) := '-'; end if;
            for I in 1 .. Pad_Len loop P := P + 1; Out_Buf (P) := '0'; end loop;
         else
            for I in 1 .. Pad_Len loop P := P + 1; Out_Buf (P) := Pad; end loop;
            if Neg then P := P + 1; Out_Buf (P) := '-'; end if;
         end if;
         Out_Buf (P + 1 .. P + Digs'Length) := Digs;
         P := P + Digs'Length;
         Serial.Write (Out_Buf (1 .. P));
      end;
   end Put;

   ------------------
   -- Put_Unsigned --
   ------------------

   procedure Put_Unsigned (N : Interfaces.Unsigned_32) is
      Digits_Buf : String (1 .. 10);            --  up to 10 digits (2^32-1)
      D_First    : Natural := Digits_Buf'Last + 1;
      V          : Unsigned_32 := N;
   begin
      loop
         D_First := D_First - 1;
         Digits_Buf (D_First) :=
           Character'Val (Character'Pos ('0') + Integer (V mod 10));
         V := V / 10;
         exit when V = 0;
      end loop;
      Serial.Write (Digits_Buf (D_First .. Digits_Buf'Last));
   end Put_Unsigned;

   -------------
   -- Put_Hex --
   -------------

   procedure Put_Hex (N : Interfaces.Unsigned_32; Width : Natural := 0) is
      Hex        : constant array (0 .. 15) of Character := "0123456789abcdef";
      Digits_Buf : String (1 .. 8);
      D_First    : Natural := Digits_Buf'Last + 1;
      V          : Unsigned_32 := N;
   begin
      loop
         D_First := D_First - 1;
         Digits_Buf (D_First) := Hex (Integer (V and 16#F#));
         V := Shift_Right (V, 4);
         exit when V = 0;
      end loop;

      declare
         Digs    : constant String  := Digits_Buf (D_First .. Digits_Buf'Last);
         Pad_Len : constant Natural :=
           (if Width > Digs'Length then Width - Digs'Length else 0);
         Out_Buf : String (1 .. Digs'Length + Pad_Len);
      begin
         for I in 1 .. Pad_Len loop
            Out_Buf (I) := '0';
         end loop;
         Out_Buf (Pad_Len + 1 .. Pad_Len + Digs'Length) := Digs;
         Serial.Write (Out_Buf);
      end;
   end Put_Hex;

   ---------------
   -- Put_Fixed --
   ---------------

   --  Emit a NON-NEGATIVE Long_Long_Integer's digits.  Put_Fixed handles the sign
   --  itself, but its whole part can exceed Integer'Last -- Numer = Integer'First
   --  with Denom = 1 gives Whole = 2**31 -- so Integer (Whole) would overflow.
   procedure Put_Nonneg (N : Long_Long_Integer) is
      Buf   : String (1 .. 20);         --  Long_Long_Integer is <= 19 digits
      First : Natural := Buf'Last + 1;
      U     : Long_Long_Integer := N;
   begin
      loop
         First := First - 1;
         Buf (First) := Character'Val (Character'Pos ('0') + Integer (U mod 10));
         U := U / 10;
         exit when U = 0;
      end loop;
      Put (Buf (First .. Buf'Last));
   end Put_Nonneg;

   procedure Put_Fixed (Numer : Integer; Denom : Positive; Decimals : Natural := 2)
   is
      Neg   : constant Boolean           := Numer < 0;
      M     : constant Long_Long_Integer := abs (Long_Long_Integer (Numer));
      D     : constant Long_Long_Integer := Long_Long_Integer (Denom);
      Whole : constant Long_Long_Integer := M / D;
      Rem_M : constant Long_Long_Integer := M mod D;
      Scale : Long_Long_Integer := 1;
   begin
      for I in 1 .. Decimals loop
         Scale := Scale * 10;
      end loop;
      if Neg then
         Put ("-");
      end if;
      Put_Nonneg (Whole);              --  LLI: avoids the Integer (Whole) overflow
      if Decimals > 0 then
         Put (".");
         Put (Integer ((Rem_M * Scale) / D), Width => Decimals, Pad => '0');
      end if;
   end Put_Fixed;

end ESP32S3.Log;
