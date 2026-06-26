with Ada.Text_IO;               use Ada.Text_IO;
with Ada.Exceptions;            use Ada.Exceptions;
with Ada.Real_Time;             use Ada.Real_Time;
with Ada.Unchecked_Deallocation;

with Shapes;                    use Shapes;
with Resources;                 use Resources;

--  Pull the SMP slave-start entry (__gnat_start_slave_cpus, called from glue.c
--  after elaboration) into the link closure so core 1 is brought up.
with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

--  Embedded-profile demonstration.
--
--  This program exercises the three runtime features that the `embedded`
--  profile (ESP32S3_RTS_PROFILE=embedded) enables over the default
--  light-tasking profile on the ESP32-S3:
--
--    1. dispatching calls on a library-level tagged hierarchy (Shapes);
--    2. controlled-type finalization, on scope exit AND for a heap object
--       freed with Unchecked_Deallocation (Resources);
--    3. exception propagation across a frame, reporting the exception's real
--       name and message (needs ZCX unwinding + the exception table).
--
--  build.sh selects the embedded profile; the light-tasking profile
--  omits these for code size (a raised exception would reset the board, and
--  finalization is restricted away).  Expected console transcript:
--
--    === ESP32-S3 embedded profile demo ===
--    [1] tagged dispatching:
--        circle area = 75
--        rectangle area = 24
--        circle area = 12
--    [2] controlled finalization:
--        [resource initialized]
--        (R in scope)
--        [resource 1 finalized]
--        [resource initialized]
--        (P on heap)
--        [resource 2 finalized]
--    [3] exception propagation:
--        caught MAIN.MY_ERROR (deliberate)
--    === demo complete; environment task now idles ===
procedure Main is

   type Shape_Access    is access all Shape'Class;
   type Resource_Access is access Resource;
   procedure Free is new Ada.Unchecked_Deallocation (Resource, Resource_Access);

   --  Heap-allocated, library-level tagged objects -> dispatch tables in flash.
   Gallery : constant array (Positive range <>) of Shape_Access :=
     (new Circle'(Radius => 5),
      new Rectangle'(Width => 4, Height => 6),
      new Circle'(Radius => 2));

   My_Error : exception;

begin
   --  Give the USB-serial-JTAG host time to (re)attach after the reset-to-run
   --  re-enumeration before we print, so the opening lines are not missed.
   delay until Clock + Milliseconds (200);

   New_Line;
   Put_Line ("=== ESP32-S3 embedded profile demo ===");

   --  (1) Dispatching over a class-wide array.
   Put_Line ("[1] tagged dispatching:");
   for S of Gallery loop
      Put_Line ("    " & Name (S.all) & " area =" & Integer'Image (Area (S.all)));
   end loop;

   --  (2) Controlled finalization -- scope exit, then a freed heap object.
   Put_Line ("[2] controlled finalization:");
   declare
      R : Resource;
   begin
      Set_Id (R, 1);
      Put_Line ("    (R in scope)");
   end;  --  Finalize (R) runs here

   declare
      P : Resource_Access := new Resource;
   begin
      Set_Id (P.all, 2);
      Put_Line ("    (P on heap)");
      Free (P);            --  Finalize (P.all) runs here
   end;

   --  (3) Exception propagation across a frame, with name + message.
   Put_Line ("[3] exception propagation:");
   begin
      raise My_Error with "deliberate";
   exception
      when E : others =>
         Put_Line ("    caught " & Exception_Name (E)
                   & " (" & Exception_Message (E) & ")");
   end;

   Put_Line ("=== demo complete; environment task now idles ===");

   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
