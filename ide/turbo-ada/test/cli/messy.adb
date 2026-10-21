with Ada.Text_IO; use Ada.Text_IO;
procedure Messy is
X : Integer:=1;
   Y:Integer   :=  2;
begin
if X>0 then Put_Line("pos"); end if;
      for I in 1..3 loop X:=X+I; end loop;
Put_Line (Integer'Image(X+Y));
end Messy;
