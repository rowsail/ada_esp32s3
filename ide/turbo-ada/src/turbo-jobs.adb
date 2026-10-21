with Ada.Calendar;
with Ada.Directories;
with Ada.Streams.Stream_IO;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with GNAT.OS_Lib;
with Turbo.Projects;
with Turbo.Term;

package body Turbo.Jobs is

   use Ada.Strings.Unbounded;
   use GNAT.OS_Lib;
   use type Ada.Calendar.Time;

   protected State is
      procedure Set_Done (Ok : Boolean);
      procedure Reset;
      function Done return Boolean;
      function Ok return Boolean;
   private
      Is_Done : Boolean := True;
      Is_Ok   : Boolean := True;
   end State;

   protected body State is
      procedure Set_Done (Ok : Boolean) is
      begin
         Is_Done := True;
         Is_Ok := Ok;
      end Set_Done;

      procedure Reset is
      begin
         Is_Done := False;
         Is_Ok := False;
      end Reset;

      function Done return Boolean is (Is_Done);
      function Ok return Boolean is (Is_Ok);
   end State;

   --  Wait_Process reaps whichever child ends; there is only ever one.
   task Waiter is
      entry Watch;
   end Waiter;

   task body Waiter is
      Pid     : Process_Id;
      Success : Boolean;
   begin
      loop
         select
            accept Watch;
         or
            terminate;
         end select;
         Wait_Process (Pid, Success);
         State.Set_Done (Success);
      end loop;
   end Waiter;

   Job_Pid    : Process_Id := Invalid_Pid;
   Log_Name   : Unbounded_String;
   Read_Pos   : Natural := 0;           --  bytes of the log consumed
   Partial    : Unbounded_String;       --  a line still being written
   Started_At : Ada.Calendar.Time := Ada.Calendar.Clock;
   Have_Job   : Boolean := False;
   Reported   : Boolean := True;

   function Temp_Dir return String is
      function Try (Var : String) return String is
         V : GNAT.OS_Lib.String_Access := Getenv (Var);
      begin
         return R : constant String :=
           (if V.all /= "" and then Ada.Directories.Exists (V.all) then V.all else "")
         do
            Free (V);
         end return;
      end Try;
      T : constant String := Try ("TMPDIR");
   begin
      if T /= "" then
         return T;
      elsif Try ("TEMP") /= "" then
         return Try ("TEMP");
      elsif Try ("TMP") /= "" then
         return Try ("TMP");
      end if;
      return (if Term.Is_Windows then "." else "/tmp");
   end Temp_Dir;

   procedure Start (Command, Dir : String; Ok : out Boolean) is
      Old  : constant String := Ada.Directories.Current_Directory;
      Args : Argument_List :=
        [new String'(Projects.Shell_Flag), new String'(Command)];
      Shell : GNAT.OS_Lib.String_Access := Locate_Exec_On_Path (Projects.Shell_Program);
   begin
      Ok := False;
      if Have_Job and then not State.Done then
         return;
      end if;
      if Shell = null then
         Shell := new String'(Projects.Shell_Program);
      end if;
      declare
         Me : constant String := Integer'Image (Pid_To_Integer (Current_Process_Id));
      begin
         Log_Name := To_Unbounded_String
           (Ada.Directories.Compose
              (Temp_Dir, "turbo_ada_" & Me (Me'First + 1 .. Me'Last) & ".log"));
      end;
      Read_Pos := 0;
      Partial := Null_Unbounded_String;

      Ada.Directories.Set_Directory (Dir);
      State.Reset;
      Job_Pid := Non_Blocking_Spawn
        (Shell.all, Args, Output_File => To_String (Log_Name), Err_To_Out => True);
      Ada.Directories.Set_Directory (Old);
      for A of Args loop
         Free (A);
      end loop;
      Free (Shell);

      if Job_Pid = Invalid_Pid then
         State.Set_Done (False);
         return;
      end if;
      Have_Job := True;
      Reported := False;
      Started_At := Ada.Calendar.Clock;
      Waiter.Watch;
      Ok := True;
   exception
      when others =>
         Ada.Directories.Set_Directory (Old);
         State.Set_Done (False);
   end Start;

   function Running return Boolean is (Have_Job and then not Reported);

   function Clean (S : String) return String is
   --  Remove ANSI escape sequences and apply carriage returns (a progress
   --  bar redrawing itself leaves only its last state).
      R    : Unbounded_String;
      I    : Natural := S'First;
   begin
      while I <= S'Last loop
         declare
            C : constant Character := S (I);
         begin
            if C = Character'Val (27) then
               I := I + 1;
               if I <= S'Last and then S (I) = '[' then
                  I := I + 1;
                  while I <= S'Last and then S (I) not in '@' .. '~' loop
                     I := I + 1;
                  end loop;
               elsif I <= S'Last and then S (I) = ']' then
                  while I <= S'Last and then S (I) /= Character'Val (7) loop
                     I := I + 1;
                  end loop;
               end if;
            elsif C = Character'Val (13) then
               if I < S'Last then
                  R := Null_Unbounded_String;
               end if;
            elsif C = Character'Val (9) then
               Append (R, (1 .. 8 - Length (R) mod 8 => ' '));
            elsif C >= ' ' then
               Append (R, C);
            end if;
         end;
         I := I + 1;
      end loop;
      return To_String (R);
   end Clean;

   procedure Poll (Lines : out Turbo.Dialogs.String_List; Finished : out Boolean) is
      use Ada.Streams.Stream_IO;
      Done_Now : constant Boolean := State.Done;   --  sample BEFORE reading
      F        : File_Type;
   begin
      Lines.Clear;
      Finished := False;
      if not Have_Job or else Reported then
         return;
      end if;
      if Ada.Directories.Exists (To_String (Log_Name)) then
         begin
            Open (F, In_File, To_String (Log_Name));
            declare
               Size : constant Natural := Natural (Ada.Streams.Stream_IO.Size (F));
            begin
               if Size > Read_Pos then
                  declare
                     Buf : String (1 .. Size - Read_Pos);
                  begin
                     Set_Index (F, Positive_Count (Read_Pos + 1));
                     String'Read (Stream (F), Buf);
                     Read_Pos := Size;
                     for C of Buf loop
                        if C = Character'Val (10) then
                           Lines.Append (Clean (To_String (Partial)));
                           Partial := Null_Unbounded_String;
                        else
                           Append (Partial, C);
                        end if;
                     end loop;
                  end;
               end if;
            end;
            Close (F);
         exception
            when others =>
               if Is_Open (F) then
                  Close (F);
               end if;
         end;
      end if;
      if Done_Now then
         if Length (Partial) > 0 then
            Lines.Append (Clean (To_String (Partial)));
            Partial := Null_Unbounded_String;
         end if;
         Finished := True;
         Reported := True;
         begin
            Ada.Directories.Delete_File (To_String (Log_Name));
         exception
            when others => null;
         end;
      end if;
   end Poll;

   function Succeeded return Boolean is (State.Ok);

   procedure Cancel is
   begin
      if Have_Job and then not State.Done then
         Kill_Process_Tree (Job_Pid, Hard_Kill => True);
      end if;
   end Cancel;

   function Elapsed return Duration is (Ada.Calendar.Clock - Started_At);

   procedure Run_Foreground
     (Command, Dir : String; Success : out Boolean)
   is
      use Ada.Text_IO;
      Old   : constant String := Ada.Directories.Current_Directory;
      Args  : Argument_List :=
        [new String'(Projects.Shell_Flag), new String'(Command)];
      Shell : GNAT.OS_Lib.String_Access := Locate_Exec_On_Path (Projects.Shell_Program);
      Code  : Integer;
   begin
      if Shell = null then
         Shell := new String'(Projects.Shell_Program);
      end if;
      Term.Suspend;
      Put_Line ("--- Turbo Ada: " & Command);
      Flush;
      Ada.Directories.Set_Directory (Dir);
      Code := Spawn (Shell.all, Args);
      Ada.Directories.Set_Directory (Old);
      Success := Code = 0;
      for A of Args loop
         Free (A);
      end loop;
      Free (Shell);
      New_Line;
      Put ("--- " & (if Success then "done" else "exit status" & Code'Image)
           & ". Press any key to return to Turbo Ada...");
      Flush;
      Term.Wait_Key;
      Term.Resume;
   exception
      when others =>
         Ada.Directories.Set_Directory (Old);
         Term.Resume;
         Success := False;
   end Run_Foreground;

end Turbo.Jobs;
