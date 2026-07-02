with Ada.Text_IO; use Ada.Text_IO;

package body Resources is

   overriding
   procedure Initialize (R : in out Resource) is
      pragma Unreferenced (R);
   begin
      Put_Line ("    [resource initialized]");
   end Initialize;

   overriding
   procedure Finalize (R : in out Resource) is
   begin
      Put_Line ("    [resource" & Integer'Image (R.Id) & " finalized]");
   end Finalize;

   procedure Set_Id (R : in out Resource; Id : Integer) is
   begin
      R.Id := Id;
   end Set_Id;

end Resources;
