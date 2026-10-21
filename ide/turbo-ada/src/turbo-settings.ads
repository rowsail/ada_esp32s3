--  Editor preferences (the Options | Environment | Editor dialog).

package Turbo.Settings is

   Tab_Size      : Positive := 8;      --  how a TAB character displays
   Indent_Size   : Positive := 3;      --  what the Tab key inserts (GNAT style)
   Auto_Indent   : Boolean := True;
   Insert_Mode   : Boolean := True;
   Backup_Files  : Boolean := False;   --  NAME.ADB -> NAME.ADB.BAK on save
   Trim_Trailing : Boolean := True;    --  strip trailing blanks on save
   Show_Shadows  : Boolean := True;

end Turbo.Settings;
