--  The colour scheme, by role.  These are the Turbo C++ 3.0 / Turbo Vision
--  defaults: the dotted blue-on-gray desktop, black-on-gray menus with red
--  hot letters and a green bar, yellow-on-blue edit windows, gray dialogs
--  with green buttons, cyan message and help windows.

package Turbo.Theme is


   Desktop          : constant Attribute := Blue / Light_Gray;

   Menu_Normal      : constant Attribute := Black / Light_Gray;
   Menu_Hot         : constant Attribute := Red / Light_Gray;
   Menu_Selected    : constant Attribute := Black / Green;
   Menu_Sel_Hot     : constant Attribute := Red / Green;
   Menu_Disabled    : constant Attribute := Dark_Gray / Light_Gray;

   Status_Normal    : constant Attribute := Black / Light_Gray;
   Status_Hot       : constant Attribute := Red / Light_Gray;
   Status_Busy      : constant Attribute := White / Red;

   --  Edit windows (Turbo Vision "blue window")

   Edit_Frame       : constant Attribute := White / Blue;
   Edit_Frame_Idle  : constant Attribute := Light_Gray / Blue;
   Edit_Icon        : constant Attribute := Light_Green / Blue;
   Edit_Scroll      : constant Attribute := Blue / Cyan;
   Edit_Text        : constant Attribute := Yellow / Blue;
   Edit_Keyword     : constant Attribute := White / Blue;
   Edit_Comment     : constant Attribute := Light_Gray / Blue;
   Edit_String      : constant Attribute := Light_Cyan / Blue;
   Edit_Number      : constant Attribute := Light_Cyan / Blue;
   Edit_Pragma      : constant Attribute := Light_Green / Blue;
   Edit_Selected    : constant Attribute := Blue / Light_Gray;
   Edit_Error_Line  : constant Attribute := White / Red;
   Edit_Match       : constant Attribute := Black / Cyan;

   --  Message, output and help windows ("cyan window")

   Msg_Frame        : constant Attribute := White / Cyan;
   Msg_Frame_Idle   : constant Attribute := Black / Cyan;
   Msg_Icon         : constant Attribute := Light_Green / Cyan;
   Msg_Scroll       : constant Attribute := Cyan / Blue;
   Msg_Text         : constant Attribute := Black / Cyan;
   Msg_Error        : constant Attribute := Red / Cyan;
   Msg_Warning      : constant Attribute := Blue / Cyan;
   Msg_Selected     : constant Attribute := White / Blue;
   Help_Keyword     : constant Attribute := Yellow / Cyan;
   Help_Heading     : constant Attribute := White / Cyan;

   --  Dialogs ("gray dialog")

   Dialog_Frame     : constant Attribute := White / Light_Gray;
   Dialog_Icon      : constant Attribute := Light_Green / Light_Gray;
   Dialog_Text      : constant Attribute := Black / Light_Gray;
   Label_Normal     : constant Attribute := Black / Light_Gray;
   Label_Focused    : constant Attribute := White / Light_Gray;
   Label_Hot        : constant Attribute := Yellow / Light_Gray;
   Button_Normal    : constant Attribute := Black / Green;
   Button_Default   : constant Attribute := Light_Cyan / Green;
   Button_Focused   : constant Attribute := White / Green;
   Button_Hot       : constant Attribute := Yellow / Green;
   Button_Shadow    : constant Attribute := Black / Light_Gray;
   Cluster_Normal   : constant Attribute := Black / Cyan;
   Cluster_Focused  : constant Attribute := White / Cyan;
   Cluster_Hot      : constant Attribute := Yellow / Cyan;
   Input_Normal     : constant Attribute := White / Blue;
   Input_Selected   : constant Attribute := White / Green;
   Input_Arrow      : constant Attribute := Light_Green / Blue;
   List_Normal      : constant Attribute := Black / Cyan;
   List_Focused     : constant Attribute := White / Green;
   List_Selected    : constant Attribute := Yellow / Cyan;
   List_Divider     : constant Attribute := Blue / Cyan;
   Info_Pane        : constant Attribute := Yellow / Blue;

   --  The "Compiling" box (Turbo C++ shows it in the dialog colours)

   Progress_Bar     : constant Attribute := Yellow / Light_Gray;

end Turbo.Theme;
