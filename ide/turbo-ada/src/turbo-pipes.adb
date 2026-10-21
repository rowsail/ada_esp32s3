with Ada.Calendar;

package body Turbo.Pipes is

   use type Ada.Calendar.Time;

   protected body Line_Queue is
      procedure Put (Line : String) is
      begin
         Queue.Append (Line);
      end Put;

      procedure Take (Line : out Unbounded_String; Found : out Boolean) is
      begin
         Found := not Queue.Is_Empty;
         if Found then
            Line := To_Unbounded_String (Queue.First_Element);
            Queue.Delete_First;
         end if;
      end Take;

      procedure Set_Closed (Closed : Boolean) is
      begin
         Is_Closed := Closed;
      end Set_Closed;

      function Closed return Boolean is (Is_Closed);

      procedure Clear is
      begin
         Queue.Clear;
      end Clear;
   end Line_Queue;

   task body Line_Reader is
      Input : GNAT.OS_Lib.File_Descriptor;
      Buf   : String (1 .. 8192);
      N     : Integer;
      Acc   : Unbounded_String;
   begin
      loop
         select
            accept Start (Fd : GNAT.OS_Lib.File_Descriptor) do
               Input := Fd;
            end Start;
         or
            terminate;
         end select;
         Acc := Null_Unbounded_String;
         loop
            N := GNAT.OS_Lib.Read (Input, Buf'Address, Buf'Length);
            exit when N <= 0;
            for C of Buf (1 .. N) loop
               if C = ASCII.LF then
                  Q.Put (To_String (Acc));
                  Acc := Null_Unbounded_String;
               elsif C /= ASCII.CR then
                  Append (Acc, C);
               end if;
            end loop;
         end loop;
         if Length (Acc) > 0 then
            Q.Put (To_String (Acc));
         end if;
         Q.Set_Closed (True);
      end loop;
   end Line_Reader;

   procedure Spawn (P : in out GNAT.Expect.Process_Descriptor; Q : in out Line_Queue;
                    Reader : in out Line_Reader; Program : String;
                    Args : GNAT.OS_Lib.Argument_List; Ok : out Boolean) is
   begin
      Q.Clear;
      GNAT.Expect.Non_Blocking_Spawn (P, Program, Args, Buffer_Size => 0, Err_To_Out => True);
      Q.Set_Closed (False);
      Reader.Start (GNAT.Expect.Get_Output_Fd (P));
      Ok := True;
   exception
      when others =>
         Ok := False;
   end Spawn;

   procedure Kill (P : in out GNAT.Expect.Process_Descriptor; Q : in out Line_Queue;
                   Up : in out Boolean; Grace : Duration) is
      Deadline : Ada.Calendar.Time := Ada.Calendar.Clock + Grace;
   begin
      if not Up then
         return;
      end if;
      while not Q.Closed and then Ada.Calendar.Clock < Deadline loop
         delay 0.02;
      end loop;
      if not Q.Closed then
         begin
            GNAT.Expect.Send_Signal (P, 15);
         exception
            when others => null;
         end;
         Deadline := Ada.Calendar.Clock + 2.0;
         while not Q.Closed and then Ada.Calendar.Clock < Deadline loop
            delay 0.02;
         end loop;
      end if;
      if not Q.Closed then
         begin
            GNAT.Expect.Send_Signal (P, 9);
         exception
            when others => null;
         end;
         Deadline := Ada.Calendar.Clock + 2.0;
         while not Q.Closed and then Ada.Calendar.Clock < Deadline loop
            delay 0.02;
         end loop;
      end if;
      begin
         GNAT.Expect.Close (P);
      exception
         when others => null;
      end;
      Q.Clear;
      Up := False;
   end Kill;

   function Shell_Quote (S : String) return String is
      R : Unbounded_String := To_Unbounded_String ("'");
   begin
      for C of S loop
         if C = ''' then
            Append (R, "'\''");
         else
            Append (R, C);
         end if;
      end loop;
      return To_String (R) & "'";
   end Shell_Quote;

end Turbo.Pipes;
