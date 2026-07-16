package body Tlsf_Math with SPARK_Mode => On is

   Two : constant Unsigned_64 := 2;

   ---------
   -- FLS --
   ---------

   function FLS (X : Unsigned_64) return Integer is
      V : Unsigned_64 := X;
      N : Integer := -1;
   begin
      while V /= 0 loop
         pragma Loop_Invariant (N in -1 .. 62);
         pragma Loop_Invariant (V = Shift_Right (X, N + 1));
         pragma Loop_Invariant (if N >= 0 then Two ** N <= X);
         pragma Loop_Variant (Decreases => V);
         V := Shift_Right (V, 1);
         N := N + 1;
      end loop;
      return N;
   end FLS;

   ---------
   -- FFS --
   ---------

   function FFS (X : Unsigned_32) return Integer is
      V : Unsigned_32 := X;
      N : Integer := 0;
   begin
      if V = 0 then
         return -1;
      end if;
      while (V and 1) = 0 loop
         pragma Loop_Invariant (N in 0 .. 31);
         pragma Loop_Invariant (V /= 0);
         pragma Loop_Invariant (V = Shift_Right (X, N));
         pragma Loop_Variant (Decreases => V);
         V := Shift_Right (V, 1);
         N := N + 1;
      end loop;
      return N;
   end FFS;

   --------------
   -- Round_Up --
   --------------

   function Round_Up (X : Storage_Count) return Storage_Count
   is (((X + (Align - 1)) / Align) * Align);

   -------------
   -- Mapping --
   -------------

   procedure Mapping (Size : Storage_Count; FL, SL : out Integer) is
      S : constant Unsigned_64 := Unsigned_64 (Size);
   begin
      if Size < Small_Block then
         FL := 0;
         SL := Integer (S / Unsigned_64 (Small_Block / SL_Count));
      else
         declare
            F : constant Integer := FLS (S);
         begin
            --  Size in [Small_Block, Max_Size] => F in [FL_Shift, 32], so
            --  FL = F - (FL_Shift - 1) is in [1, FL_Count - 1] and the shift
            --  amount F - SL_Log2 is non-negative.
            SL := Integer
              (Shift_Right (S, F - SL_Log2) and Unsigned_64 (SL_Count - 1));
            FL := F - FL_Shift + 1;
         end;
      end if;
   end Mapping;

   --------------------
   -- Mapping_Search --
   --------------------

   procedure Mapping_Search (Size : in out Storage_Count; FL, SL : out Integer)
   is
   begin
      if Size >= Small_Block then
         declare
            F : constant Integer := FLS (Unsigned_64 (Size));
         begin
            --  Size in [Small_Block, 2**32]: FLS's post gives 2**F <= Size <= 2**32
            --  and Size < 2**(F+1) with Size >= 2**FL_Shift, so F is in
            --  [FL_Shift, 32] and the shift amount F - SL_Log2 is in [4, 27].
            pragma Assert (F >= FL_Shift);
            --  2**F <= Size <= 2**32 (transitivity), hence F <= 32.
            pragma Assert (Unsigned_64'(2) ** F <= Unsigned_64 (Size));
            pragma Assert (Unsigned_64 (Size) <= Unsigned_64'(2) ** 32);
            pragma Assert (Unsigned_64'(2) ** F <= Unsigned_64'(2) ** 32);
            pragma Assert (F <= 32);
            pragma Assert (F - SL_Log2 in 4 .. 27);
            declare
               Round : constant Storage_Count :=
                 Storage_Count (Shift_Left (Unsigned_64'(1), F - SL_Log2)) - 1;
            begin
               --  Shift_Left (1, k) with k in [4, 27] is 2**k <= 2**27, so the
               --  rounding increment is <= 2**27 - 1 and Size stays <= Max_Size.
               pragma Assert (Round <= 2 ** 27 - 1);
               Size := Size + Round;
            end;
         end;
      end if;
      pragma Assert (Long_Long_Integer (Size) <= Max_Size);
      Mapping (Size, FL, SL);
   end Mapping_Search;

end Tlsf_Math;
