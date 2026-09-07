package body ESP32S3.Ext4.Path_Scan
  with SPARK_Mode => On
is

   --------------------
   -- Next_Component --
   --------------------

   function Next_Component (Path : String; From : Positive) return Component is
      Start : Positive := From;   --  first non-'/' at or after From
      Stop  : Positive;           --  first '/' at or after Start (or Path'Last + 1)
   begin
      --  Skip a run of '/'.  The second invariant is what the Post's "everything
      --  skipped was a separator" clause is built from; the variant gives
      --  termination, and with it the Post's progress clause.
      while Start <= Path'Last and then Path (Start) = '/' loop
         pragma Loop_Invariant (Start >= From and then Start <= Path'Last);
         pragma Loop_Invariant (for all K in From .. Start - 1 => Path (K) = '/');
         pragma Loop_Variant (Increases => Start);
         Start := Start + 1;
      end loop;

      --  Take the run of non-'/'.  Likewise the second invariant carries "the
      --  component holds no separator" out to the Post.
      Stop := Start;
      while Stop <= Path'Last and then Path (Stop) /= '/' loop
         pragma Loop_Invariant (Stop >= Start and then Stop <= Path'Last);
         pragma Loop_Invariant (for all K in Start .. Stop - 1 => Path (K) /= '/');
         pragma Loop_Variant (Increases => Stop);
         Stop := Stop + 1;
      end loop;

      return (First => Start, Last => Stop - 1, Next => Stop);
   end Next_Component;

end ESP32S3.Ext4.Path_Scan;
