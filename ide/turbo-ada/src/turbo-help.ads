--  The help screens.  Markup: "# " starts a heading line, {braces} mark a
--  key or a command.

package Turbo.Help is

   function Contents return String;
   function Keys return String;
   function Project_Commands return String;
   function About return String;

end Turbo.Help;
