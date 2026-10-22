with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with GNAT.Expect;
with GNAT.OS_Lib;
with Turbo.Jobs;

package body Turbo.Console is

   use Ada.Strings.Unbounded;
   use Turbo.Pipes;

   Q      : aliased Line_Queue;
   Reader : Line_Reader (Q'Access);
   P      : GNAT.Expect.Process_Descriptor;
   Up     : Boolean := False;
   Pause  : Boolean := False;
   Hold   : Line_Vectors.Vector;
   Done   : Boolean := False;   --  the reader ended and all was taken
   Group  : Boolean := False;   --  stop the command's whole process group

   Max_Held : constant := 20_000;
   --  Past this, a long pause keeps the newest lines.

   procedure Start (Command, Dir : String; Ok : out Boolean; Whole_Group : Boolean := False) is
      Args : GNAT.OS_Lib.Argument_List :=
        [new String'("-c"), new String'("cd " & Shell_Quote (Dir) & " && " & Command)];
   begin
      Stop;
      Spawn (P, Q, Reader, "/bin/sh", Args, Ok);
      for A of Args loop
         GNAT.OS_Lib.Free (A);
      end loop;
      Up := Ok;
      Done := False;
      Group := Whole_Group;
   end Start;

   function Running return Boolean is (Up);

   function Ended return Boolean is (Up and then Done and then Hold.Is_Empty);

   procedure Stop is
   begin
      if Up and then Group then
         --  The shell's children too (alr run's program, a run.sh's): the
         --  spawned shell leads its own process group.
         declare
            Pid  : constant String :=
              Ada.Strings.Fixed.Trim (GNAT.Expect.Process_Id'Image (GNAT.Expect.Get_Pid (P)), Ada.Strings.Left);
            Args : GNAT.OS_Lib.Argument_List :=
              [new String'("-c"), new String'("kill -TERM -- -" & Pid & " 2>/dev/null")];
            Ignore : Integer;
         begin
            Ignore := GNAT.OS_Lib.Spawn ("/bin/sh", Args);
            for A of Args loop
               GNAT.OS_Lib.Free (A);
            end loop;
         end;
      end if;
      if Up then
         Kill (P, Q, Up, 0.0);
      end if;
      Up := False;
      Pause := False;
      Done := False;
      Hold.Clear;
   end Stop;

   procedure Drain is
      Line  : Unbounded_String;
      Found : Boolean;
      Was_Closed : constant Boolean := Q.Closed;   --  sample BEFORE taking
   begin
      loop
         Q.Take (Line, Found);
         exit when not Found;
         if Natural (Hold.Length) >= Max_Held then
            Hold.Delete_First;
         end if;
         Hold.Append (Jobs.Clean (To_String (Line)));
      end loop;
      if Was_Closed then
         Done := True;
      end if;
   end Drain;

   procedure Set_Paused (Paused : Boolean) is
   begin
      Pause := Paused and then Up;
   end Set_Paused;

   function Paused return Boolean is (Pause);

   function Held return Natural is
   begin
      if Up then
         Drain;
      end if;
      return Natural (Hold.Length);
   end Held;

   function Take return Line_Vectors.Vector is
   begin
      if not Up then
         return Line_Vectors.Empty_Vector;
      end if;
      Drain;
      if Pause then
         return Line_Vectors.Empty_Vector;
      end if;
      return R : constant Line_Vectors.Vector := Hold do
         Hold.Clear;
      end return;
   end Take;

end Turbo.Console;
