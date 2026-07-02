with System.Storage_Elements; use System.Storage_Elements;

package body Bare_Mem is

   subtype Off is Storage_Offset;

   --  Single-byte load/store at an address (overlay; -gnatp, no checks).
   function Load (A : System.Address) return Storage_Element is
      B : Storage_Element
      with Import, Address => A;
   begin
      return B;
   end Load;

   procedure Store (A : System.Address; V : Storage_Element) is
      B : Storage_Element
      with Import, Address => A;
   begin
      B := V;
   end Store;

   ------------
   -- Memcpy --
   ------------

   function Memcpy (Dest, Src : System.Address; N : Interfaces.C.size_t) return System.Address is
   begin
      for I in 0 .. Off (N) - 1 loop
         Store (Dest + I, Load (Src + I));
      end loop;
      return Dest;
   end Memcpy;

   -------------
   -- Memmove --
   -------------

   --  Overlap-safe: copy backwards when Dest is above Src.
   function Memmove (Dest, Src : System.Address; N : Interfaces.C.size_t) return System.Address is
   begin
      if To_Integer (Dest) < To_Integer (Src) then
         for I in 0 .. Off (N) - 1 loop
            Store (Dest + I, Load (Src + I));
         end loop;
      else
         for I in reverse 0 .. Off (N) - 1 loop
            Store (Dest + I, Load (Src + I));
         end loop;
      end if;
      return Dest;
   end Memmove;

   ------------
   -- Memset --
   ------------

   function Memset
     (Dest : System.Address; C : Interfaces.C.int; N : Interfaces.C.size_t) return System.Address
   is
      V : constant Storage_Element := Storage_Element (Integer (C) mod 256);
   begin
      for I in 0 .. Off (N) - 1 loop
         Store (Dest + I, V);
      end loop;
      return Dest;
   end Memset;

   ------------
   -- Memcmp --
   ------------

   function Memcmp (S1, S2 : System.Address; N : Interfaces.C.size_t) return Interfaces.C.int is
      A, B : Storage_Element;
   begin
      for I in 0 .. Off (N) - 1 loop
         A := Load (S1 + I);
         B := Load (S2 + I);
         if A /= B then
            return Interfaces.C.int (Integer (A) - Integer (B));
         end if;
      end loop;
      return 0;
   end Memcmp;

end Bare_Mem;
