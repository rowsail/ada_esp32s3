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
      --  Skip a run of '/'.
      while Start <= Path'Last and then Path (Start) = '/' loop
         pragma Loop_Invariant (Start >= From and then Start <= Path'Last);
         pragma Loop_Variant (Increases => Start);
         Start := Start + 1;
      end loop;

      --  Take the run of non-'/'.
      Stop := Start;
      while Stop <= Path'Last and then Path (Stop) /= '/' loop
         pragma Loop_Invariant (Stop >= Start and then Stop <= Path'Last);
         pragma Loop_Variant (Increases => Stop);
         Stop := Stop + 1;
      end loop;

      return (First => Start, Last => Stop - 1, Next => Stop);
   end Next_Component;

end ESP32S3.Ext4.Path_Scan;
