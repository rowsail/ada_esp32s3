with Ada.Finalization;

--  A LIBRARY-LEVEL controlled type.  Its Initialize/Finalize primitives are
--  dispatched through a flash-resident table, so finalization runs correctly on
--  the ESP32-S3 -- both on scope exit and on Unchecked_Deallocation of a
--  heap-allocated object (verified on hardware).  As with Shapes, keep such
--  types at library level on this target.

package Resources is

   type Resource is new Ada.Finalization.Limited_Controlled with record
      Id : Integer := 0;
   end record;

   overriding
   procedure Initialize (R : in out Resource);
   overriding
   procedure Finalize (R : in out Resource);

   procedure Set_Id (R : in out Resource; Id : Integer);

end Resources;
