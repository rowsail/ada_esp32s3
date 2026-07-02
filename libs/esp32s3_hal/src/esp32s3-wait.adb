with Ada.Real_Time; use Ada.Real_Time;

package body ESP32S3.Wait is

   ----------------
   -- Until_True --
   ----------------

   function Until_True
     (Ready   : access function return Boolean;
      Timeout : Time_Span;
      Poll    : Time_Span := Milliseconds (1)) return Boolean
   is
      Deadline : constant Time := Clock + Timeout;
   begin
      loop
         if Ready.all then
            return True;             --  condition holds
         elsif Clock >= Deadline then
            return False;            --  gave up
         end if;
         delay until Clock + Poll;   --  back off; let other tasks run
      end loop;
   end Until_True;

end ESP32S3.Wait;
