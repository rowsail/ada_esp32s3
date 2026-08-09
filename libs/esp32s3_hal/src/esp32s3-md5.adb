package body ESP32S3.MD5 is

   use Interfaces;

   --  RFC 1321's tables, verbatim.  K (i) = floor (2**32 * abs (sin (i+1))),
   --  which is to say: arbitrary on purpose.
   type Word_Table is array (0 .. 63) of Unsigned_32;
   K : constant Word_Table :=
     (16#D76A_A478#, 16#E8C7_B756#, 16#2420_70DB#, 16#C1BD_CEEE#,
      16#F57C_0FAF#, 16#4787_C62A#, 16#A830_4613#, 16#FD46_9501#,
      16#6980_98D8#, 16#8B44_F7AF#, 16#FFFF_5BB1#, 16#895C_D7BE#,
      16#6B90_1122#, 16#FD98_7193#, 16#A679_438E#, 16#49B4_0821#,
      16#F61E_2562#, 16#C040_B340#, 16#265E_5A51#, 16#E9B6_C7AA#,
      16#D62F_105D#, 16#0244_1453#, 16#D8A1_E681#, 16#E7D3_FBC8#,
      16#21E1_CDE6#, 16#C337_07D6#, 16#F4D5_0D87#, 16#455A_14ED#,
      16#A9E3_E905#, 16#FCEF_A3F8#, 16#676F_02D9#, 16#8D2A_4C8A#,
      16#FFFA_3942#, 16#8771_F681#, 16#6D9D_6122#, 16#FDE5_380C#,
      16#A4BE_EA44#, 16#4BDE_CFA9#, 16#F6BB_4B60#, 16#BEBF_BC70#,
      16#289B_7EC6#, 16#EAA1_27FA#, 16#D4EF_3085#, 16#0488_1D05#,
      16#D9D4_D039#, 16#E6DB_99E5#, 16#1FA2_7CF8#, 16#C4AC_5665#,
      16#F429_2244#, 16#432A_FF97#, 16#AB94_23A7#, 16#FC93_A039#,
      16#655B_59C3#, 16#8F0C_CC92#, 16#FFEF_F47D#, 16#8584_5DD1#,
      16#6FA8_7E4F#, 16#FE2C_E6E0#, 16#A301_4314#, 16#4E08_11A1#,
      16#F753_7E82#, 16#BD3A_F235#, 16#2AD7_D2BB#, 16#EB86_D391#);

   type Shift_Table is array (0 .. 63) of Natural;
   S : constant Shift_Table :=
     (7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
      5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20,
      4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
      6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21);

   ---------------------------------------------------------------------------

   procedure Transform (State : in out State_Words; Blk : Block_Bytes) is
      M : array (0 .. 15) of Unsigned_32;
      A : Unsigned_32 := State (0);
      B : Unsigned_32 := State (1);
      C : Unsigned_32 := State (2);
      D : Unsigned_32 := State (3);
      F : Unsigned_32;
      G : Natural;
   begin
      --  The message words are little-endian.
      for I in M'Range loop
         M (I) :=
           Unsigned_32 (Blk (I * 4))
           or Shift_Left (Unsigned_32 (Blk (I * 4 + 1)), 8)
           or Shift_Left (Unsigned_32 (Blk (I * 4 + 2)), 16)
           or Shift_Left (Unsigned_32 (Blk (I * 4 + 3)), 24);
      end loop;

      for I in 0 .. 63 loop
         case I / 16 is
            when 0 =>
               F := (B and C) or ((not B) and D);
               G := I;
            when 1 =>
               F := (D and B) or ((not D) and C);
               G := (5 * I + 1) mod 16;
            when 2 =>
               F := B xor C xor D;
               G := (3 * I + 5) mod 16;
            when others =>
               F := C xor (B or (not D));
               G := (7 * I) mod 16;
         end case;

         F := F + A + K (I) + M (G);
         A := D;
         D := C;
         C := B;
         B := B + Rotate_Left (F, S (I));
      end loop;

      State (0) := State (0) + A;
      State (1) := State (1) + B;
      State (2) := State (2) + C;
      State (3) := State (3) + D;
   end Transform;

   ---------------------------------------------------------------------------

   procedure Reset (C : out Context) is
   begin
      C := (others => <>);
   end Reset;

   procedure Update (C : in out Context; Data : Byte_Array) is
   begin
      for B of Data loop
         C.Buf (C.Fill) := B;
         C.Fill := C.Fill + 1;
         if C.Fill = 64 then
            Transform (C.State, C.Buf);
            C.Fill := 0;
         end if;
      end loop;
      C.Total := C.Total + Unsigned_64 (Data'Length);
   end Update;

   function Hex_Digest (C : Context) return Digest_Text is
      Digits_16 : constant String := "0123456789abcdef";
      Bits      : constant Unsigned_64 := C.Total * 8;
      Work      : Context := C;          --  finalise a copy, not the caller's
      Text      : Digest_Text;
      Pos       : Natural := 0;
   begin
      --  Pad: one 0x80, zeros to fill to 56 mod 64, then the ORIGINAL length
      --  in bits, little-endian, in the last eight bytes of the final block.
      Work.Buf (Work.Fill) := 16#80#;
      Work.Fill := Work.Fill + 1;
      if Work.Fill > 56 then
         while Work.Fill < 64 loop
            Work.Buf (Work.Fill) := 0;
            Work.Fill := Work.Fill + 1;
         end loop;
         Transform (Work.State, Work.Buf);
         Work.Fill := 0;
      end if;
      while Work.Fill < 56 loop
         Work.Buf (Work.Fill) := 0;
         Work.Fill := Work.Fill + 1;
      end loop;
      for I in 0 .. 7 loop
         Work.Buf (56 + I) :=
           Unsigned_8 (Shift_Right (Bits, 8 * I) and 16#FF#);
      end loop;
      Transform (Work.State, Work.Buf);

      --  The digest is the state, little-endian, in lowercase hex.
      for W of Work.State loop
         for I in 0 .. 3 loop
            declare
               Octet : constant Unsigned_32 :=
                 Shift_Right (W, 8 * I) and 16#FF#;
            begin
               Text (Pos * 2 + 1) := Digits_16 (Natural (Octet / 16) + 1);
               Text (Pos * 2 + 2) := Digits_16 (Natural (Octet mod 16) + 1);
               Pos := Pos + 1;
            end;
         end loop;
      end loop;
      return Text;
   end Hex_Digest;

end ESP32S3.MD5;
