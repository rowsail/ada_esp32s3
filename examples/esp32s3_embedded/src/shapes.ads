--  A small LIBRARY-LEVEL tagged hierarchy with a dispatching operation.
--
--  Because the type is declared at library level, GNAT places its dispatch
--  table in flash (.flash.rodata), so dispatching works on the ESP32-S3.  The
--  same hierarchy declared inside a subprogram would instead get a dispatch
--  table built on the (non-executable) DRAM stack and would fault when called
--  -- see the runtime-profiles note in the repository README.  Declaring
--  tagged/controlled types at library level (the usual Ada style) avoids that.

package Shapes is

   type Shape is abstract tagged null record;

   function Name (S : Shape) return String is abstract;
   function Area (S : Shape) return Integer is abstract;

   type Circle is new Shape with record
      Radius : Integer;
   end record;
   overriding
   function Name (S : Circle) return String;
   overriding
   function Area (S : Circle) return Integer;

   type Rectangle is new Shape with record
      Width  : Integer;
      Height : Integer;
   end record;
   overriding
   function Name (S : Rectangle) return String;
   overriding
   function Area (S : Rectangle) return Integer;

end Shapes;
