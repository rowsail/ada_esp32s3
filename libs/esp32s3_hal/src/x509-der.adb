package body X509.DER is

   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_64;

   procedure Read (Buf : Byte_Array; Pos, Limit : Natural; E : out TLV) is
      Cursor   : Natural := Pos;
      Len_Byte : U8;
      NBytes   : Natural;
      Len      : Natural := 0;
   begin
      E := (Tag => 0, Content => (1, 0), Elem_Last => 0, Valid => False);

      --  The window [Pos .. Limit] must be inside the buffer and non-empty.
      if Limit > Buf'Last or else Pos < Buf'First or else Pos > Limit then
         return;
      end if;

      --  Tag (single-byte only; high-tag-number form is rejected).
      E.Tag := Buf (Cursor);
      if (E.Tag and 16#1F#) = 16#1F# then
         return;
      end if;
      if Cursor >= Limit then
         --  no room for a length byte
         return;
      end if;
      Cursor := Cursor + 1;

      --  Length.
      Len_Byte := Buf (Cursor);
      if Len_Byte < 16#80# then
         --  short form
         Len := Natural (Len_Byte);
      elsif Len_Byte = 16#80# then
         --  indefinite: not allowed in DER
         return;
      else
         --  long form: Len_Byte-0x80 length octets
         NBytes := Natural (Len_Byte and 16#7F#);
         if NBytes > 4 or else NBytes > Limit - Cursor then
            return;
         end if;
         --  Accumulate in 64-bit: a 4-byte length (e.g. 84 FF FF FF FF) reaches
         --  2**32-1, which overflows the 31-bit Natural on the last * 256 and
         --  raises Constraint_Error BEFORE the window check below could reject it
         --  (an attacker-controlled DoS on any parsed cert).  Reject a length that
         --  cannot fit a Natural here, then narrow.
         declare
            Len64 : Interfaces.Unsigned_64 := 0;
         begin
            for K in 1 .. NBytes loop
               Len64 := Len64 * 256 + Interfaces.Unsigned_64 (Buf (Cursor + K));
            end loop;
            if Len64 > Interfaces.Unsigned_64 (Natural'Last) then
               return;
            end if;
            Len := Natural (Len64);
         end;
         Cursor := Cursor + NBytes;
      end if;

      --  Content range: starts just after the length field.
      if Len = 0 then
         E.Content := (First => Cursor + 1, Last => Cursor);   --  empty
         E.Elem_Last := Cursor;
      else
         --  Need Cursor + Len <= Limit (overflow-safe form).
         if Len > Limit - Cursor then
            return;
         end if;
         E.Content := (First => Cursor + 1, Last => Cursor + Len);
         E.Elem_Last := Cursor + Len;
      end if;
      E.Valid := True;
   end Read;

end X509.DER;
