--  Host harness: run the pure-Ada ext4 FS against a file-backed block device.
--  Usage:  ext4_host <image> <scenario>
--    scenario = one : create file + mkdir, single commit
--    scenario = two : create file + commit, THEN mkdir + commit  (drift repro)
with Ada.Command_Line; use Ada.Command_Line;
with Ada.Direct_IO;
with Ada.Text_IO; use Ada.Text_IO;
with System;
with Interfaces; use Interfaces;
with ESP32S3.Block_Dev;
with ESP32S3.Ext4;       use ESP32S3.Ext4;
with ESP32S3.Ext4.FS;
with ESP32S3.Ext4.Inode;
with ESP32S3.Ext4.Bitmap;   --  Phantom_Free_Count tripwire (double-free guard)

procedure Ext4_Host is
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
      Count => FCount'Unrestricted_Access);

   M        : ESP32S3.Ext4.FS.Mount;
   Scenario : constant String := (if Argument_Count >= 2 then Argument (2) else "two");

   procedure Make_File (Path, Name : String) is
      N    : Inode_Number;
      Data : Byte_Array (0 .. 9) := (others => Character'Pos ('A'));
   begin
      N := M.Create_File (Path, Name);
      M.Write_File (N, Data);
   end Make_File;

   --  A 1 MiB file (single-indirect, heavy cache eviction) like the battery's.
   Big_Size : constant := 1024 * 1024;
   type Big_Ptr is access Byte_Array;
   procedure Make_Big (Path, Name : String) is
      N   : Inode_Number;
      Big : Big_Ptr := new Byte_Array (0 .. Big_Size - 1);
   begin
      for I in Big'Range loop
         Big (I) := U8 (I mod 251);
      end loop;
      N := M.Create_File (Path, Name);
      M.Write_File (N, Big.all);
   end Make_Big;
begin
   DIO.Open (F, DIO.Inout_File, Argument (1));
   M.Open (Dev, Read_Only => False, Cache_Blocks => 16);

   if Scenario = "one" then
      Make_File ("/", "f1.txt");
      M.Mkdir ("/", "d1");
      M.Commit;
      M.Close;
   elsif Scenario = "two" then           --  two commits, one session
      Make_File ("/", "f1.txt");
      M.Commit;
      M.Mkdir ("/", "d1");
      M.Commit;
      M.Close;
   elsif Scenario = "rerun" then
      --  session A writes a file (like the single-file test); session B
      --  (re-open) unlinks it + commits, then mkdir + commits (like the
      --  battery's cleanup followed by its operations).
      Make_File ("/", "ada_write.txt");
      M.Commit;
      M.Close;                           --  end session A

      M.Open (Dev, Read_Only => False, Cache_Blocks => 16);   --  session B
      M.Unlink ("/", "ada_write.txt");
      M.Commit;                          --  cleanup transaction
      Make_File ("/", "ada_write.txt");
      M.Mkdir ("/", "ada_dir");
      M.Commit;                          --  operations transaction
      M.Close;
   end if;

   if Scenario = "dirty_battery" then
      --  EXACT device repro: a prior session writes ada_write.txt (the
      --  single-file test), THEN the full battery runs on that dirty card.
      Make_File ("/", "ada_write.txt");
      M.Commit;
      M.Close;
      M.Open (Dev, Read_Only => False, Cache_Blocks => 16);
   end if;

   if Scenario = "battery" or else Scenario = "dirty_battery" then
      --  Faithful mirror of examples/esp32s3_ext4_write: cleanup commit, then
      --  the full op set (incl. the 1 MiB file) committed once.
      begin
         M.Unlink ("/", "ada_write.txt");   --  cleanup of the leftover (if any)
      exception
         when others => null;
      end;
      M.Commit;
      Make_File ("/", "ada_write.txt");
      M.Mkdir ("/", "ada_dir");
      Make_File ("/ada_dir", "inside.txt");
      Make_Big ("/", "ada_big.bin");
      M.Link ("/ada_write.txt", "/", "ada_hard.txt");
      M.Symlink ("/", "ada_link", "ada_write.txt");
      Make_File ("/", "ada_tmp.txt");
      M.Rename ("/", "ada_tmp.txt", "/", "ada_renamed.txt");
      Make_File ("/", "ada_del.txt");
      M.Unlink ("/", "ada_del.txt");
      M.Commit;
      M.Close;
   end if;

   DIO.Close (F);

   --  TRIPWIRE: with the idempotent Free, a double-free no longer drifts the free
   --  count (so e2fsck stays clean) -- so assert it here instead, or a real
   --  double-free bug would pass silently.  On a coherent file-backed image this
   --  is always 0; >0 means a genuine FS double-free bug.
   if Bitmap.Phantom_Free_Count > 0 then
      Put_Line ("[host] scenario=" & Scenario & " *** PHANTOM FREES:"
                & Natural'Image (Bitmap.Phantom_Free_Count) & " (double-free bug) ***");
      Set_Exit_Status (Failure);
   end if;
   Put_Line ("[host] scenario=" & Scenario & " done");
end Ext4_Host;
