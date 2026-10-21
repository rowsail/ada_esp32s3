--  Every action the IDE can take, whether it comes from a menu, a hot key or
--  the status line.

package Turbo.Commands is

   pragma Pure;

   type Command is
     (Cmd_None,
      --  System menu
      Cmd_About, Cmd_Repaint, Cmd_Alr_Update, Cmd_Alr_Show, Cmd_Alr_Deps,
      --  File
      Cmd_New, Cmd_Open, Cmd_Save, Cmd_Save_As, Cmd_Save_All, Cmd_Change_Dir,
      Cmd_Shell, Cmd_Quit,
      --  Edit
      Cmd_Undo, Cmd_Redo, Cmd_Cut, Cmd_Copy, Cmd_Paste, Cmd_Clear,
      Cmd_Select_All, Cmd_Show_Clipboard,
      --  Search
      Cmd_Find, Cmd_Replace, Cmd_Search_Again, Cmd_Goto_Line,
      Cmd_Prev_Msg, Cmd_Next_Msg, Cmd_Find_Spec_Body,
      --  Language server
      Cmd_Definition, Cmd_References, Cmd_Symbols, Cmd_Go_Back, Cmd_Rename,
      Cmd_Complete, Cmd_Hover, Cmd_Diagnostics,
      --  Run
      Cmd_Run, Cmd_Flash, Cmd_Monitor, Cmd_Debug, Cmd_Kill_OpenOCD,
      Cmd_User_Screen,
      --  Compile
      Cmd_Check_File, Cmd_Make, Cmd_Build_All, Cmd_Clean, Cmd_Memory, Cmd_Stack,
      Cmd_Analyze, Cmd_Test,
      --  Project
      Cmd_Open_Project, Cmd_New_Project, Cmd_Project_Info, Cmd_Edit_Manifest,
      Cmd_Edit_Gpr, Cmd_Board_Config,
      --  Options
      Cmd_Opt_Target, Cmd_Opt_Commands, Cmd_Opt_Editor, Cmd_Opt_Server,
      Cmd_Opt_Save,
      --  Window
      Cmd_Zoom, Cmd_Tile, Cmd_Cascade, Cmd_Next_Window, Cmd_Prev_Window,
      Cmd_Close, Cmd_Close_All, Cmd_Size_Move, Cmd_Message_Window,
      Cmd_Window_List,
      --  Help
      Cmd_Help_Contents, Cmd_Help_Keys, Cmd_Help_Project,
      Cmd_Grep);

end Turbo.Commands;
