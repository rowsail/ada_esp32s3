--  Test 1: the tiny-delay storm.  Tasks issue randomized zero-length,
--  overdue and sub-millisecond "delay until"s -- the load shape behind the
--  CXD8002 resume-recursion bug and the systimer alarm-miss bug -- mixed
--  with short busy-spins so the tick preempts at random instruction
--  boundaries.  Two tasks share a priority to exercise FIFO-within-
--  priorities; one runs on the second core.

package Stress_Storm is

   task Storm_1 with
     Priority => 12, CPU => 1,
     Storage_Size => 4096, Secondary_Stack_Size => 512;

   task Storm_2 with
     Priority => 12, CPU => 1,
     Storage_Size => 4096, Secondary_Stack_Size => 512;

   task Storm_3 with
     Priority => 13, CPU => 1,
     Storage_Size => 4096, Secondary_Stack_Size => 512;

   task Storm_4 with
     Priority => 12, CPU => 2,
     Storage_Size => 4096, Secondary_Stack_Size => 512;

end Stress_Storm;
