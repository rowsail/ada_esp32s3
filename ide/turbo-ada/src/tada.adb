--  tada: Turbo Ada, the command.
--
--    tada [-C DIR] [FILE ...]
--
--  Opens the FILEs (or the files open last time), in the project found from
--  DIR (default: the current directory).

with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Turbo.App;
with Turbo.Dialogs;
with Turbo.Term;

procedure Tada is
   use Ada.Command_Line;
   use Ada.Strings.Unbounded;
   Files : Turbo.Dialogs.String_List;
   Dir   : constant String := Ada.Directories.Current_Directory;
   K     : Positive := 1;
   Start : Unbounded_String := To_Unbounded_String (Dir);
begin
   while K <= Argument_Count loop
      declare
         A : constant String := Argument (K);
      begin
         if A = "-h" or else A = "--help" then
            Ada.Text_IO.Put_Line ("usage: tada [-C DIR] [FILE ...]");
            Ada.Text_IO.Put_Line ("A Turbo C++ style IDE for Ada, Alire and the ESP32-S3 SDK.");
            return;
         elsif A = "-v" or else A = "--version" then
            Ada.Text_IO.Put_Line ("Turbo Ada " & Turbo.Version);
            return;
         elsif A = "-C" and then K < Argument_Count then
            K := K + 1;
            Start := To_Unbounded_String (Ada.Directories.Full_Name (Argument (K)));
            Ada.Directories.Set_Directory (To_String (Start));
         else
            Files.Append (Ada.Directories.Full_Name (A));
         end if;
      end;
      K := K + 1;
   end loop;

   Turbo.App.Run (Files, To_String (Start));
exception
   when Turbo.Term.Not_A_Terminal =>
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "tada: needs an interactive terminal (on Windows: Windows 10 1809+"
         & " console or Windows Terminal)");
      Set_Exit_Status (Failure);
end Tada;
