with Interfaces.C;

--  L2/L3 device-interrupt-vector regression-test glue, shared by
--  esp32s3_intr_levels and esp32s3_full_intr (was the identical glue.c in each).
--
--  Fires the L2 and L3 interrupt vectors with NO external wiring, via the
--  FROM_CPU interrupt-matrix sources (the same mechanism as the cross-core
--  poke): route FROM_CPU_0 -> CPU_INT 19 (Device_L2_0, level 2) and FROM_CPU_1
--  -> CPU_INT 23 (Device_L3_0, level 3); assert by writing the SYSTEM FROM_CPU
--  register, and the attached Ada handler clears it.  (L5 = the always-firing
--  tick; L4 has no vector on this port.)  Also reads/writes THREADPTR for the
--  per-task-TLS corruption check.  Pure Ada: direct volatile register access +
--  System.Machine_Code, no HAL dependency.

package Intr_Vector_Test is

   --  Route FROM_CPU_0 -> CPU_INT 19 (L2) and FROM_CPU_1 -> CPU_INT 23 (L3).
   --  The CPU ints are enabled when the Ada handlers attach.
   procedure Setup;

   --  Assert / clear the L2 and L3 device-interrupt sources.
   procedure Fire_L2;
   procedure Fire_L3;
   procedure Clear_L2;
   procedure Clear_L3;

   --  THREADPTR (per-task TLS) read / write -- the corruption sentinel check.
   function Get_TP return Interfaces.C.unsigned;
   procedure Set_TP (V : Interfaces.C.unsigned);

   --  One "[intr] <n>" line over the ROM console.
   procedure Log (Marker : Interfaces.C.int);

end Intr_Vector_Test;
