with Interfaces.C;
with System.Storage_Elements; use System.Storage_Elements;

--  The pure request-size arithmetic of the malloc/free glue (Bare_Heap), split
--  out with SPARK contracts so gnatprove can machine-check that no size request
--  can wrap into a smaller allocation than the caller asked for -- the classic
--  malloc/calloc integer-overflow class.  Bare_Heap's body proper takes the
--  spinlock (inline asm) and hands raw addresses to Tlsf_Core, both outside
--  SPARK's model; THIS is the pure size math it calls first.
package Heap_Guard with SPARK_Mode => On is

   subtype Size_T is Interfaces.C.size_t;
   use type Interfaces.C.size_t;

   --  Largest byte count the Storage_Count-based allocator can size without
   --  wrapping.  size_t (Storage_Count'Last) is exact on both 32- and 64-bit
   --  (Storage_Count'Last <= size_t'Last on every target).
   Max_Request : constant Size_T := Size_T (Storage_Count'Last);

   --  A single malloc/realloc request is serviceable iff it is representable as
   --  a Storage_Count, i.e. the later Storage_Count (N) conversion cannot wrap.
   function Request_Fits (N : Size_T) return Boolean
   is (N <= Max_Request)
     with Post => Request_Fits'Result = (N <= Max_Request);

   --  calloc element-array sizing.  Ok is set iff Count elements of Elem bytes
   --  neither overflow size_t nor exceed Max_Request; then Total is that product
   --  (the Storage_Count multiplication is proved not to overflow).  Otherwise
   --  Ok is False and Total is 0 -- so a wrapping request can never yield a live
   --  but under-sized buffer.  Count = 0 or Elem = 0 is a valid 0-byte request
   --  (handled before any conversion, so a huge Count with Elem = 0 cannot wrap
   --  the Storage_Count (Count) cast).
   procedure Array_Bytes
     (Count, Elem : Size_T; Total : out Storage_Count; Ok : out Boolean)
     with Post =>
       (if Count = 0 or else Elem = 0
          then Ok and then Total = 0
        elsif Count <= Size_T'Last / Elem and then Count * Elem <= Max_Request
          then Ok and then Total = Storage_Count (Count * Elem)
        else (not Ok) and then Total = 0);

end Heap_Guard;
