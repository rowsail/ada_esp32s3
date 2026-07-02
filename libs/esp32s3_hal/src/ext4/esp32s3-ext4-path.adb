with ESP32S3.Ext4.Inode;
with ESP32S3.Ext4.Dir;

package body ESP32S3.Ext4.Path is

   function Resolve
     (V : in out Volume.Context; Path : String) return Inode_Number
   is
      Cur   : Inode_Number := Root_Inode;
      Cur_I : Inode.Info;
      I     : Integer := Path'First;
   begin
      Inode.Read (V, Cur, Cur_I);

      while I <= Path'Last loop
         --  Skip run of '/'.
         while I <= Path'Last and then Path (I) = '/' loop
            I := I + 1;
         end loop;
         exit when I > Path'Last;

         --  Component spans [Start .. J-1].
         declare
            Start : constant Integer := I;
            J     : Integer := I;
         begin
            while J <= Path'Last and then Path (J) /= '/' loop
               J := J + 1;
            end loop;
            I := J;

            declare
               Comp : constant String := Path (Start .. J - 1);
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
                     raise Name_Error
                       with "no such file or directory: " & Comp;
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
