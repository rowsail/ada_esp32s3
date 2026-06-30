with Ada.Finalization;
with ESP32S3.Ext4;
with ESP32S3.Ext4.Inode;
with ESP32S3.Ext4.VFS;

--  Pure-Ada text I/O tracking a large subset of Ada.Text_IO -- over ext4 files
--  AND the console, with NO Interfaces.C_Streams and no C glue.
--
--  File_Type is a handle to a heap control block (the RM representation), so all
--  I/O operations take File as `in` and the block tracks position: column, line
--  and page, plus an optional line length for automatic wrapping. Console
--  Standard_Output / Standard_Error route to ESP32S3.Serial; ext4 files are named
--  by a VFS path ("/flash/log.txt").
--
--  Errors are ordinary Ada exceptions (ESP32S3.Ext4 renames Ada.IO_Exceptions):
--  Name_Error, Mode_Error, End_Error, Status_Error, Data_Error. With no store
--  mounted, Open/Create on a volume path raise Name_Error -- catchable.
--
--  Not RM-conformant in the corners: no Get_Immediate / Fixed_IO / Decimal_IO, no
--  numeric String variants, Float output is fixed-point (no scientific), and the
--  page model is minimal (form-feed terminator). Controlled: auto-Close (commit)
--  on scope exit; needs the embedded/full profiles.
package ESP32S3.Text_IO is

   subtype Field       is Natural;
   subtype Number_Base is Integer range 2 .. 16;
   type Type_Set is (Lower_Case, Upper_Case);

   --  Raised by the Put (To : out String; ...) variants when the value does not
   --  fit in the target string (the only Text_IO exception not in Ext4).
   Layout_Error : exception;

   type Count is range 0 .. Integer'Last;
   subtype Positive_Count is Count range 1 .. Count'Last;

   type File_Mode is (In_File, Out_File, Append_File);
   type File_Type is limited private;
   type File_Access is access all File_Type;

   --  Standard / current files (console) ----------------------------------------
   function Standard_Output return File_Access;
   function Standard_Error  return File_Access;
   function Standard_Input  return File_Access;
   function Current_Output  return File_Access;
   function Current_Input   return File_Access;
   procedure Set_Output (File : File_Access);
   procedure Set_Input  (File : File_Access);

   --  File management -----------------------------------------------------------
   procedure Create (File : in out File_Type; Name : String; Mode : File_Mode := Out_File);
   procedure Open   (File : in out File_Type; Name : String; Mode : File_Mode);
   procedure Close  (File : in out File_Type);
   procedure Reset  (File : in out File_Type);
   function Is_Open (File : File_Type) return Boolean;
   function Mode    (File : File_Type) return File_Mode;
   function Name    (File : File_Type) return String;
   procedure Flush  (File : File_Type);
   procedure Flush;

   --  Layout: line length (auto-wrap) and page length ---------------------------
   procedure Set_Line_Length (File : File_Type; To : Count);
   procedure Set_Line_Length (To : Count);
   procedure Set_Page_Length (File : File_Type; To : Count);
   procedure Set_Page_Length (To : Count);
   function Line_Length (File : File_Type) return Count;
   function Line_Length return Count;
   function Page_Length (File : File_Type) return Count;
   function Page_Length return Count;

   --  Column / line / page position ---------------------------------------------
   function Col  (File : File_Type) return Positive_Count;
   function Col  return Positive_Count;
   function Line (File : File_Type) return Positive_Count;
   function Line return Positive_Count;
   function Page (File : File_Type) return Positive_Count;
   function Page return Positive_Count;
   procedure Set_Col (File : File_Type; To : Positive_Count);
   procedure Set_Col (To : Positive_Count);
   procedure Set_Line (File : File_Type; To : Positive_Count);
   procedure Set_Line (To : Positive_Count);

   --  Line / page control -------------------------------------------------------
   procedure New_Line (File : File_Type; Spacing : Positive_Count := 1);
   procedure New_Line (Spacing : Positive_Count := 1);
   procedure New_Page (File : File_Type);
   procedure New_Page;
   procedure Skip_Line (File : File_Type; Spacing : Positive_Count := 1);
   procedure Skip_Line (Spacing : Positive_Count := 1);
   procedure Skip_Page (File : File_Type);
   procedure Skip_Page;
   function End_Of_Line (File : File_Type) return Boolean;
   function End_Of_Line return Boolean;
   function End_Of_Page (File : File_Type) return Boolean;
   function End_Of_Page return Boolean;
   function End_Of_File (File : File_Type) return Boolean;
   function End_Of_File return Boolean;

   --  Character I/O -------------------------------------------------------------
   procedure Put (File : File_Type; Item : Character);
   procedure Put (Item : Character);
   procedure Get (File : File_Type; Item : out Character);
   procedure Get (Item : out Character);
   procedure Look_Ahead (File : File_Type; Item : out Character; End_Of_Line : out Boolean);
   --  Read the next character without skipping line terminators. The Available
   --  form sets it False (Item undefined) when no character is ready.
   procedure Get_Immediate (File : File_Type; Item : out Character);
   procedure Get_Immediate (Item : out Character);
   procedure Get_Immediate (File : File_Type; Item : out Character; Available : out Boolean);
   procedure Get_Immediate (Item : out Character; Available : out Boolean);

   --  String / line I/O ---------------------------------------------------------
   procedure Put (File : File_Type; Item : String);
   procedure Put (Item : String);
   procedure Put_Line (File : File_Type; Item : String);
   procedure Put_Line (Item : String);
   procedure Get_Line (File : File_Type; Item : out String; Last : out Natural);
   procedure Get_Line (Item : out String; Last : out Natural);

   --  Numeric / enumeration generics --------------------------------------------
   generic
      type Num is range <>;
   package Integer_IO is
      Default_Width : Field       := 0;
      Default_Base  : Number_Base := 10;
      procedure Put (File  : File_Type; Item : Num;
                     Width : Field := Default_Width; Base : Number_Base := Default_Base);
      procedure Put (Item  : Num;
                     Width : Field := Default_Width; Base : Number_Base := Default_Base);
      procedure Get (File : File_Type; Item : out Num);
      procedure Get (Item : out Num);
      procedure Put (To : out String; Item : Num; Base : Number_Base := Default_Base);
      procedure Get (From : String; Item : out Num; Last : out Positive);
   end Integer_IO;

   generic
      type Num is mod <>;
   package Modular_IO is
      Default_Width : Field       := 0;
      Default_Base  : Number_Base := 10;
      procedure Put (File  : File_Type; Item : Num;
                     Width : Field := Default_Width; Base : Number_Base := Default_Base);
      procedure Put (Item  : Num;
                     Width : Field := Default_Width; Base : Number_Base := Default_Base);
      procedure Get (File : File_Type; Item : out Num);
      procedure Get (Item : out Num);
      procedure Put (To : out String; Item : Num; Base : Number_Base := Default_Base);
      procedure Get (From : String; Item : out Num; Last : out Positive);
   end Modular_IO;

   generic
      type Num is digits <>;
   package Float_IO is
      Default_Fore : Field := 2;
      Default_Aft  : Field := Num'Digits - 1;
      Default_Exp  : Field := 0;
      procedure Put (File : File_Type; Item : Num;
                     Fore : Field := Default_Fore; Aft : Field := Default_Aft;
                     Exp  : Field := Default_Exp);
      procedure Put (Item : Num;
                     Fore : Field := Default_Fore; Aft : Field := Default_Aft;
                     Exp  : Field := Default_Exp);
      procedure Get (File : File_Type; Item : out Num);
      procedure Get (Item : out Num);
      procedure Put (To : out String; Item : Num;
                     Aft : Field := Default_Aft; Exp : Field := Default_Exp);
      procedure Get (From : String; Item : out Num; Last : out Positive);
   end Float_IO;

   generic
      type Enum is (<>);
   package Enumeration_IO is
      Default_Width   : Field    := 0;
      Default_Setting : Type_Set := Upper_Case;
      procedure Put (File  : File_Type; Item : Enum;
                     Width : Field := Default_Width; Set : Type_Set := Default_Setting);
      procedure Put (Item  : Enum;
                     Width : Field := Default_Width; Set : Type_Set := Default_Setting);
      procedure Get (File : File_Type; Item : out Enum);
      procedure Get (Item : out Enum);
   end Enumeration_IO;

private

   type File_Kind is (Closed, Console, Disk);
   Name_Max : constant := 128;

   type Control_Block;
   type CB_Access is access Control_Block;

   type File_Type is new Ada.Finalization.Limited_Controlled with record
      CB : CB_Access := null;
   end record;

   overriding procedure Finalize (File : in out File_Type);

end ESP32S3.Text_IO;
