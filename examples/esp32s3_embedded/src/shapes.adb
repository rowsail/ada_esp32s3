package body Shapes is

   --  Area uses an integer "pi" of 3 to keep the demo free of soft-float
   --  formatting; the point is the dispatch, not the arithmetic.

   overriding
   function Name (S : Circle) return String
   is ("circle");
   overriding
   function Area (S : Circle) return Integer
   is (3 * S.Radius * S.Radius);

   overriding
   function Name (S : Rectangle) return String
   is ("rectangle");
   overriding
   function Area (S : Rectangle) return Integer
   is (S.Width * S.Height);

end Shapes;
