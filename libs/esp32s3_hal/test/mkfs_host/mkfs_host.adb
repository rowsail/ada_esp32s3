--  Host test for the on-device ext4 formatter (ESP32S3.Ext4.Mkfs).
--  Usage:  mkfs_host <image> <scenario>
--    format : just format the (truncated) image -- run.sh then runs e2fsck
--    mount  : format, then mount with OUR FS read-only and list the root
--    rw     : format, mount read-write, create a file + mkdir + commit
--  In every case run.sh cross-checks the image with the host's e2fsck.
with Ada.Command_Line; use Ada.Command_Line;
with Ada.Direct_IO;
with Ada.Text_IO; use Ada.Text_IO;
with System;
with Interfaces; use Interfaces;
with ESP32S3.Block_Dev;
with ESP32S3.Ext4;        use ESP32S3.Ext4;
with ESP32S3.Ext4.Mkfs;
with ESP32S3.Ext4.FS;
with ESP32S3.Ext4.Inode;

procedure Mkfs_Host is
   package DIO is new Ada.Direct_IO (ESP32S3.Block_Dev.Sector);
   F : DIO.File_Type;

   use type ESP32S3.Block_Dev.Sector_Index;

   procedure FRead (Ctx : System.Address;
                    LBA : ESP32S3.Block_Dev.Sector_Index;
                    Data : out ESP32S3.Block_Dev.Sector) is
      pragma Unreferenced (Ctx);
   begin
      DIO.Read (F, Data, DIO.Positive_Count (LBA + 1));
   end FRead;

   procedure FWrite (Ctx : System.Address;
                     LBA : ESP32S3.Block_Dev.Sector_Index;
                     Data : ESP32S3.Block_Dev.Sector) is
      pragma Unreferenced (Ctx);
   begin
      DIO.Write (F, Data, DIO.Positive_Count (LBA + 1));
   end FWrite;

   function FCount (Ctx : System.Address)
      return ESP32S3.Block_Dev.Sector_Index is
      pragma Unreferenced (Ctx);
   begin
      return ESP32S3.Block_Dev.Sector_Index (DIO.Size (F));
   end FCount;

   Dev : constant ESP32S3.Block_Dev.Device :=
     (Ctx   => System.Null_Address,
      Read  => FRead'Unrestricted_Access,
      Write => FWrite'Unrestricted_Access,
      Count => FCount'Unrestricted_Access,
      Erase => null);

   Scenario : constant String := (if Argument_Count >= 2 then Argument (2) else "format");
   --  Optional 3rd arg "journal" formats a journaled volume.
   Want_Journal : constant Boolean :=
     Argument_Count >= 3 and then Argument (3) = "journal";
   M        : ESP32S3.Ext4.FS.Mount;
begin
   DIO.Open (F, DIO.Inout_File, Argument (1));

   ESP32S3.Ext4.Mkfs.Format
     (Dev, Volume_Label => "ADAFLASH", Journal => Want_Journal);
   Put_Line ("mkfs_host: formatted " & DIO.Size (F)'Image & " sectors"
             & (if Want_Journal then " (journaled)" else ""));

   if Scenario = "mount" then
      M.Open (Dev, Read_Only => True);
      Put_Line ("mkfs_host: mounted (block size" & M.Block_Size'Image & "); root:");
      declare
         Root : constant Inode_Number := M.Lookup ("/");
         Info : ESP32S3.Ext4.Inode.Info;
         procedure Show (Name : String; Ino : Inode_Number; FT : U8) is
            pragma Unreferenced (FT);
         begin
            Put_Line ("    " & Name & " -> inode" & Ino'Image);
         end Show;
      begin
         M.Stat (Root, Info);
         M.Iterate (Info, Show'Access);
      end;
      M.Close;

   elsif Scenario = "rw" then
      M.Open (Dev, Read_Only => False);
      declare
         N    : Inode_Number;
         Data : Byte_Array (0 .. 24) := (others => Character'Pos ('Z'));
      begin
         N := M.Create_File ("/", "hello.txt");
         M.Write_File (N, Data);
         M.Mkdir ("/", "sub");
         M.Commit;
      end;
      M.Close;
      Put_Line ("mkfs_host: wrote /hello.txt + mkdir /sub, committed");
   end if;
end Mkfs_Host;
