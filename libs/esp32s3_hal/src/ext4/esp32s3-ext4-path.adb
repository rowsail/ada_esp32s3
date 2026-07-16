with ESP32S3.Ext4.Inode;
with ESP32S3.Ext4.Dir;
with ESP32S3.Ext4.Path_Scan;

package body ESP32S3.Ext4.Path is

   function Resolve (V : in out Volume.Context; Path : String) return Inode_Number is
      Cur   : Inode_Number := Root_Inode;
      Cur_I : Inode.Info;
      I     : Integer := Path'First;
   begin
      Inode.Read (V, Cur, Cur_I);

      while I <= Path'Last loop
         --  Next '/'-separated component (the scan is proved in-bounds; see
         --  ESP32S3.Ext4.Path_Scan).
         declare
            C : constant Path_Scan.Component := Path_Scan.Next_Component (Path, I);
         begin
            I := C.Next;
            exit when C.Last < C.First;        --  only '/' left -- done

            declare
               Comp : constant String := Path (C.First .. C.Last);
               Next : Inode_Number;
            begin
               if Comp = "." then
                  null;                              --  stay put

               else
                  if not Inode.Is_Dir (Cur_I) then
                     raise Use_Error with "path component is not a directory";
                  end if;
                  Next := Dir.Lookup (V, Cur_I, Comp);
                  if Next = 0 then
                     raise Name_Error with "no such file or directory: " & Comp;
                  end if;
                  Cur := Next;
                  Inode.Read (V, Cur, Cur_I);
               end if;
            end;
         end;
      end loop;

      return Cur;
   end Resolve;

end ESP32S3.Ext4.Path;
