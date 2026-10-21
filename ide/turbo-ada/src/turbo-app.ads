--  The application: start-up, the event loop, and what every command does.

with Turbo.Dialogs;

package Turbo.App is

   procedure Run (Files : Turbo.Dialogs.String_List; Start_Dir : String);
   --  Files given on the command line are opened; with none, the files
   --  open at the end of the last session come back.

end Turbo.App;
