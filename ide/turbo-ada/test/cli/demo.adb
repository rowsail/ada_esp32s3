with Ada.Text_IO; use Ada.Text_IO;

procedure Demo is
   Total : Integer := 0;

   procedure Add (N : Integer) is
   begin
      Total := Total + N * N;
   end Add;

begin
   Put_Line ("Sum of squares");
   for I in 1 .. 3 loop
      Add (I);
      Put_Line ("I =" & I'Image & "  Total =" & Total'Image);
   end loop;
   Put_Line ("Done");
end Demo;
