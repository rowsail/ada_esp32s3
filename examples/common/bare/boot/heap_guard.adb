package body Heap_Guard with SPARK_Mode => On is

   use type Interfaces.C.size_t;

   -----------------
   -- Array_Bytes --
   -----------------

   procedure Array_Bytes
     (Count, Elem : Size_T; Total : out Storage_Count; Ok : out Boolean) is
   begin
      if Count = 0 or else Elem = 0 then
         --  0-byte request: settle it before any Storage_Count conversion, so a
         --  huge Count (with Elem = 0) never casts out of Storage_Count range.
         Ok    := True;
         Total := 0;
      elsif Count > Size_T'Last / Elem or else Count * Elem > Max_Request then
         --  Count <= Size_T'Last / Elem is checked first (short-circuit), so
         --  Count * Elem below cannot wrap size_t.
         Ok    := False;
         Total := 0;
      else
         --  Count * Elem did not wrap size_t (guarded above) and is <= Max_Request
         --  = Storage_Count'Last, so converting the product straight across is
         --  in range -- and avoids a second, harder-to-bound Storage_Count
         --  multiplication.
         Ok    := True;
         Total := Storage_Count (Count * Elem);
      end if;
   end Array_Bytes;

end Heap_Guard;
