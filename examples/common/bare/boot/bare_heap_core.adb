with Ada.Unchecked_Conversion;

package body Bare_Heap_Core is

   use type System.Address;

   Align : constant Storage_Count := 16;

   --  In-arena block header (kept ahead of each payload).
   type Header is record
      Size : Storage_Count;     --  payload bytes (excl. header), 16-aligned
      Next : System.Address;    --  next block by ascending address
      Used : Boolean;
   end record;
   type Header_Acc is access all Header;
   function To_Hdr is new Ada.Unchecked_Conversion (System.Address, Header_Acc);

   function Round_Up (X : Storage_Count) return Storage_Count
   is (((X + (Align - 1)) / Align) * Align);

   Hdr_Sz : constant Storage_Count :=
     Round_Up (Storage_Count (Header'Object_Size / System.Storage_Unit));

   Head      : System.Address := System.Null_Address;
   Base_Addr : System.Address := System.Null_Address;
   Top_Addr  : System.Address := System.Null_Address;
   Inited    : Boolean := False;

   function Align_Down (A : Integer_Address) return Integer_Address
   is (A / Integer_Address (Align) * Integer_Address (Align));
   function Align_Up (A : Integer_Address) return Integer_Address
   is (Align_Down (A + Integer_Address (Align) - 1));

   -----------
   -- Ready --
   -----------

   function Ready return Boolean
   is (Inited);

   ----------
   -- Init --
   ----------

   procedure Init (Base : System.Address; Size : Storage_Count) is
      B    : constant System.Address := To_Address (Align_Up (To_Integer (Base)));
      Topa : constant System.Address :=
        To_Address (Align_Down (To_Integer (Base) + Integer_Address (Size)));
      H    : constant Header_Acc := To_Hdr (B);
   begin
      Head := B;
      Base_Addr := B;
      Top_Addr := Topa;
      H.Size := Storage_Count (To_Integer (Topa) - To_Integer (B)) - Hdr_Sz;
      H.Next := System.Null_Address;
      H.Used := False;
      Inited := True;
   end Init;

   --------------
   -- Allocate --
   --------------

   function Allocate (N : Storage_Count) return System.Address is
      Want : constant Storage_Count := Round_Up (N);
      Cur  : System.Address := Head;
      B    : Header_Acc;
   begin
      if N = 0 or else not Inited then
         return System.Null_Address;
      end if;
      while Cur /= System.Null_Address loop
         B := To_Hdr (Cur);
         if not B.Used and then B.Size >= Want then
            if B.Size >= Want + Hdr_Sz + Align then
               --  split off a remainder
               declare
                  NB_Addr : constant System.Address := Cur + (Hdr_Sz + Want);
                  NB      : constant Header_Acc := To_Hdr (NB_Addr);
               begin
                  NB.Size := B.Size - Want - Hdr_Sz;
                  NB.Next := B.Next;
                  NB.Used := False;
                  B.Size := Want;
                  B.Next := NB_Addr;
               end;
            end if;
            B.Used := True;
            return Cur + Hdr_Sz;
         end if;
         Cur := B.Next;
      end loop;
      return System.Null_Address;                       --  out of memory
   end Allocate;

   ----------------
   -- Deallocate --
   ----------------

   procedure Deallocate (P : System.Address) is
      B  : constant Header_Acc := (if P = System.Null_Address then null else To_Hdr (P - Hdr_Sz));
      C  : System.Address := Head;
      Cb : Header_Acc;
      Nb : Header_Acc;
   begin
      if B = null then
         return;
      end if;
      B.Used := False;
      while C /= System.Null_Address loop
         --  full forward coalesce
         Cb := To_Hdr (C);
         loop
            exit when Cb.Next = System.Null_Address;
            Nb := To_Hdr (Cb.Next);
            exit when Cb.Used or else Nb.Used;
            Cb.Size := Cb.Size + Hdr_Sz + Nb.Size;
            Cb.Next := Nb.Next;
         end loop;
         C := Cb.Next;
      end loop;
   end Deallocate;

   ----------------
   -- Reallocate --
   ----------------

   function Reallocate (P : System.Address; N : Storage_Count) return System.Address is
      B  : Header_Acc;
      Np : System.Address;
   begin
      if P = System.Null_Address then
         return Allocate (N);
      end if;
      if N = 0 then
         Deallocate (P);
         return System.Null_Address;
      end if;
      B := To_Hdr (P - Hdr_Sz);
      if B.Size >= Round_Up (N) then
         return P;                                       --  fits in place

      end if;
      Np := Allocate (N);
      if Np /= System.Null_Address then
         declare
            Src : Storage_Array (1 .. B.Size)
            with Import, Address => P;
            Dst : Storage_Array (1 .. B.Size)
            with Import, Address => Np;
         begin
            Dst := Src;
         end;
         Deallocate (P);
      end if;
      return Np;
   end Reallocate;

   ---------------------
   -- Invariants_Hold --
   ---------------------

   function Invariants_Hold return Boolean is
      C        : System.Address := Head;
      Prev_End : System.Address := Base_Addr;
      Cb, Nb   : Header_Acc;
   begin
      if not Inited or else Head /= Base_Addr then
         return False;
      end if;
      while C /= System.Null_Address loop
         Cb := To_Hdr (C);
         --  contiguous from the previous block's end, within the arena
         if C /= Prev_End
           or else To_Integer (C) < To_Integer (Base_Addr)
           or else To_Integer (C + (Hdr_Sz + Cb.Size)) > To_Integer (Top_Addr)
         then
            return False;
         end if;
         if Cb.Next /= System.Null_Address then
            if To_Integer (Cb.Next) <= To_Integer (C) then
               return False;                             --  must strictly ascend

            end if;
            Nb := To_Hdr (Cb.Next);
            if not Cb.Used and then not Nb.Used then
               return False;                             --  adjacent free => not coalesced

            end if;
         end if;
         Prev_End := C + (Hdr_Sz + Cb.Size);
         C := Cb.Next;
      end loop;
      return Prev_End = Top_Addr;                        --  last block ends at top
   end Invariants_Hold;

end Bare_Heap_Core;
