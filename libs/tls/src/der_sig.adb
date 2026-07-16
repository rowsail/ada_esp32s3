package body Der_Sig with SPARK_Mode => On is

   use type Interfaces.Unsigned_8;

   ------------------
   -- Read_Integer --
   ------------------

   procedure Read_Integer
     (Buf     : Bytes;
      Pos     : in out Natural;
      Last    : Natural;
      Out_Val : out Bytes;
      Ok      : in out Boolean)
   is
      Len, First, Vlen : Natural;
      Width            : constant Natural := Out_Val'Length;
   begin
      Out_Val := (others => 0);

      --  tag byte must be present (Pos, Pos+1 in the window) and be 0x02.
      if not Ok or else Pos + 1 > Last or else Buf (Pos) /= 16#02# then
         Ok := False;
         return;
      end if;

      Len := Natural (Buf (Pos + 1));     --  short-form length (r, s are < 128 B)
      Pos := Pos + 2;

      --  the Len value bytes must fit inside the window.
      if Len = 0 or else Pos + Len - 1 > Last then
         Ok := False;
         return;
      end if;

      --  drop leading zero bytes; First + Vlen stays at the value's end.
      First := Pos;
      Vlen  := Len;
      while Vlen > 0 and then Buf (First) = 0 loop
         pragma Loop_Invariant (First + Vlen = Pos + Len);
         pragma Loop_Invariant (First >= Pos and then Vlen <= Len);
         pragma Loop_Variant (Decreases => Vlen);
         First := First + 1;
         Vlen  := Vlen - 1;
      end loop;

      if Vlen > Width then                --  value wider than the field
         Ok := False;
         return;
      end if;

      --  right-align the Vlen significant bytes into Out_Val.
      for I in 0 .. Vlen - 1 loop
         pragma Loop_Invariant (First + Vlen = Pos + Len);
         Out_Val (Width - Vlen + I) := Buf (First + I);
      end loop;

      Pos := Pos + Len;
   end Read_Integer;

end Der_Sig;
