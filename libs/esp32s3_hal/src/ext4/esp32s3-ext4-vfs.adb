with ESP32S3.Ext4.Path_Scan;

package body ESP32S3.Ext4.VFS is

   type Entry_Rec is record
      Name : String (1 .. 32);
      Len  : Natural := 0;
      FS   : Mount_Ref;
   end record;

   Table : array (1 .. Max_Mounts) of Entry_Rec;
   N     : Natural := 0;

   ----------
   -- Add  --
   ----------

   procedure Add (Name : String; FS : Mount_Ref) is
   begin
      if N < Max_Mounts then
         N := N + 1;
         Table (N).Len := Natural'Min (Name'Length, 32);
         Table (N).Name (1 .. Table (N).Len) :=
           Name (Name'First .. Name'First + Table (N).Len - 1);
         Table (N).FS := FS;
      end if;
   end Add;

   function Count return Natural
   is (N);

   function Name (I : Positive) return String
   is (Table (I).Name (1 .. Table (I).Len));

   -------------
   -- Resolve --
   -------------

   procedure Resolve
     (Path      : String;
      FS        : out Mount_Ref;
      Sub_First : out Natural;
      Sub_Last  : out Natural;
      Found     : out Boolean;
      Is_Root   : out Boolean)
   is
   begin
      FS := null;
      Found := False;
      Is_Root := False;
      Sub_First := Path'First;
      Sub_Last := Path'First - 1;        --  empty by default

      if Path'Length = 0 or else Path = "/" then
         Is_Root := True;
         return;
      end if;

      --  Leading component = the run of non-'/' characters after the first '/'
      --  (the scan is proved in-bounds; see ESP32S3.Ext4.Path_Scan).  The
      --  remainder begins at C.Next ("/x/y", or empty at the mount point).
      declare
         C : constant Path_Scan.Component := Path_Scan.Next_Component (Path, Path'First);
      begin
         for I in 1 .. N loop
            if Path (C.First .. C.Last) = Table (I).Name (1 .. Table (I).Len) then
               FS := Table (I).FS;
               Found := True;
               Sub_First := C.Next;
               Sub_Last := Path'Last;
               return;
            end if;
         end loop;
      end;
   end Resolve;

end ESP32S3.Ext4.VFS;
