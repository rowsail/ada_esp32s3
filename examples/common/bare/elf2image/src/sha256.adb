package body SHA256 is

   type W_Array is array (0 .. 63) of Unsigned_32;

   K : constant W_Array :=
     (16#428a2f98#,
      16#71374491#,
      16#b5c0fbcf#,
      16#e9b5dba5#,
      16#3956c25b#,
      16#59f111f1#,
      16#923f82a4#,
      16#ab1c5ed5#,
      16#d807aa98#,
      16#12835b01#,
      16#243185be#,
      16#550c7dc3#,
      16#72be5d74#,
      16#80deb1fe#,
      16#9bdc06a7#,
      16#c19bf174#,
      16#e49b69c1#,
      16#efbe4786#,
      16#0fc19dc6#,
      16#240ca1cc#,
      16#2de92c6f#,
      16#4a7484aa#,
      16#5cb0a9dc#,
      16#76f988da#,
      16#983e5152#,
      16#a831c66d#,
      16#b00327c8#,
      16#bf597fc7#,
      16#c6e00bf3#,
      16#d5a79147#,
      16#06ca6351#,
      16#14292967#,
      16#27b70a85#,
      16#2e1b2138#,
      16#4d2c6dfc#,
      16#53380d13#,
      16#650a7354#,
      16#766a0abb#,
      16#81c2c92e#,
      16#92722c85#,
      16#a2bfe8a1#,
      16#a81a664b#,
      16#c24b8b70#,
      16#c76c51a3#,
      16#d192e819#,
      16#d6990624#,
      16#f40e3585#,
      16#106aa070#,
      16#19a4c116#,
      16#1e376c08#,
      16#2748774c#,
      16#34b0bcb5#,
      16#391c0cb3#,
      16#4ed8aa4a#,
      16#5b9cca4f#,
      16#682e6ff3#,
      16#748f82ee#,
      16#78a5636f#,
      16#84c87814#,
      16#8cc70208#,
      16#90befffa#,
      16#a4506ceb#,
      16#bef9a3f7#,
      16#c67178f2#);

   function Rotr (X : Unsigned_32; N : Natural) return Unsigned_32
   is (Rotate_Right (X, N));

   function Hash (Data : Stream_Element_Array) return Digest is
      H : array (0 .. 7) of Unsigned_32 :=
        (16#6a09e667#,
         16#bb67ae85#,
         16#3c6ef372#,
         16#a54ff53a#,
         16#510e527f#,
         16#9b05688c#,
         16#1f83d9ab#,
         16#5be0cd19#);

      Bit_Len : constant Unsigned_64 := Unsigned_64 (Data'Length) * 8;
      --  padded length: data + 0x80 + zeros + 8-byte length, multiple of 64
      Total   : constant Natural := ((Data'Length + 1 + 8 + 63) / 64) * 64;
      Msg     : array (0 .. Total - 1) of Unsigned_8 := (others => 0);
   begin
      for I in 0 .. Data'Length - 1 loop
         Msg (I) := Unsigned_8 (Data (Data'First + Stream_Element_Offset (I)));
      end loop;
      Msg (Data'Length) := 16#80#;
      for I in 0 .. 7 loop
         --  64-bit big-endian length
         Msg (Total - 1 - I) := Unsigned_8 (Shift_Right (Bit_Len, 8 * I) and 16#FF#);
      end loop;

      for Blk in 0 .. (Total / 64) - 1 loop
         declare
            W                       : W_Array;
            A, B, C, D, E, F, G, HH : Unsigned_32;
            S0, S1, T1, T2, Ch, Maj : Unsigned_32;
            Base                    : constant Natural := Blk * 64;
         begin
            for T in 0 .. 15 loop
               W (T) :=
                 Shift_Left (Unsigned_32 (Msg (Base + T * 4)), 24)
                 or Shift_Left (Unsigned_32 (Msg (Base + T * 4 + 1)), 16)
                 or Shift_Left (Unsigned_32 (Msg (Base + T * 4 + 2)), 8)
                 or Unsigned_32 (Msg (Base + T * 4 + 3));
            end loop;
            for T in 16 .. 63 loop
               S0 :=
                 Rotr (W (T - 15), 7) xor Rotr (W (T - 15), 18) xor Shift_Right (W (T - 15), 3);
               S1 := Rotr (W (T - 2), 17) xor Rotr (W (T - 2), 19) xor Shift_Right (W (T - 2), 10);
               W (T) := W (T - 16) + S0 + W (T - 7) + S1;
            end loop;

            A := H (0);
            B := H (1);
            C := H (2);
            D := H (3);
            E := H (4);
            F := H (5);
            G := H (6);
            HH := H (7);

            for T in 0 .. 63 loop
               S1 := Rotr (E, 6) xor Rotr (E, 11) xor Rotr (E, 25);
               Ch := (E and F) xor ((not E) and G);
               T1 := HH + S1 + Ch + K (T) + W (T);
               S0 := Rotr (A, 2) xor Rotr (A, 13) xor Rotr (A, 22);
               Maj := (A and B) xor (A and C) xor (B and C);
               T2 := S0 + Maj;
               HH := G;
               G := F;
               F := E;
               E := D + T1;
               D := C;
               C := B;
               B := A;
               A := T1 + T2;
            end loop;

            H (0) := H (0) + A;
            H (1) := H (1) + B;
            H (2) := H (2) + C;
            H (3) := H (3) + D;
            H (4) := H (4) + E;
            H (5) := H (5) + F;
            H (6) := H (6) + G;
            H (7) := H (7) + HH;
         end;
      end loop;

      return R : Digest do
         for I in 0 .. 7 loop
            --  big-endian output
            R (I * 4) := Unsigned_8 (Shift_Right (H (I), 24) and 16#FF#);
            R (I * 4 + 1) := Unsigned_8 (Shift_Right (H (I), 16) and 16#FF#);
            R (I * 4 + 2) := Unsigned_8 (Shift_Right (H (I), 8) and 16#FF#);
            R (I * 4 + 3) := Unsigned_8 (H (I) and 16#FF#);
         end loop;
      end return;
   end Hash;

end SHA256;
