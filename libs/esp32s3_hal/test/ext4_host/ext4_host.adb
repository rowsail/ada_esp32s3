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
      Count => FCount'Unrestricted_Access,
      Erase => null);

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

   --  Append Bytes bytes to inode N in 8 KB chunks; byte at offset O = O mod 251.
   procedure Build (N : Inode_Number; Bytes : Natural) is
      Chunk : Byte_Array (0 .. 8191);
      Done  : Natural := 0;
   begin
      while Done < Bytes loop
         declare
            This : constant Natural := Natural'Min (8192, Bytes - Done);
         begin
            for K in 0 .. This - 1 loop
               Chunk (K) := U8 ((Done + K) mod 251);
            end loop;
            M.Append (N, Chunk (0 .. This - 1));
            Done := Done + This;
         end;
      end loop;
   end Build;

   --  Re-read inode N and confirm its size + every byte = (offset) mod 251.
   function Verify (N : Inode_Number; Bytes : Natural) return Boolean is
      Info : Inode.Info;
      Got  : Byte_Array (0 .. 8191);
      Last : Natural;
      Off  : Natural := 0;
      Ok   : Boolean := True;
   begin
      M.Stat (N, Info);
      if Info.Size /= U64 (Bytes) then
         Ok := False;
      end if;
      while Off < Bytes loop
         M.Read_File (Info, U64 (Off), Got, Last);
         exit when Last = 0;
         for K in 0 .. Last - 1 loop
            if Got (K) /= U8 ((Off + K) mod 251) then
               Ok := False;
            end if;
         end loop;
         Off := Off + Last;
      end loop;
      return Ok and then Off = Bytes;
   end Verify;
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
   elsif Scenario = "stream" then
      --  Build a file with many small, block-crossing Appends (well into the
      --  single-indirect range), then read every byte back and check it.
      declare
         N     : constant Inode_Number := M.Create_File ("/", "stream.bin");
         Chunk : constant := 137;          --  odd size -> crosses block bounds
         Count : constant := 1500;         --  ~200 KB -> > 12 blocks (indirect)
         Buf   : Byte_Array (0 .. Chunk - 1);
         Pos   : Natural := 0;
      begin
         for C in 1 .. Count loop
            for K in Buf'Range loop
               Buf (K) := U8 ((Pos + K) mod 251);
            end loop;
            M.Append (N, Buf);
            Pos := Pos + Chunk;
         end loop;
         M.Commit;

         declare
            Info : Inode.Info;
            Got  : Byte_Array (0 .. 4095);
            Last : Natural;
            Off  : Natural := 0;
            Ok   : Boolean := True;
         begin
            M.Stat (N, Info);
            if Info.Size /= U64 (Pos) then
               Ok := False;
            end if;
            while Off < Pos loop
               M.Read_File (Info, U64 (Off), Got, Last);
               exit when Last = 0;
               for K in 0 .. Last - 1 loop
                  if Got (K) /= U8 ((Off + K) mod 251) then
                     Ok := False;
                  end if;
               end loop;
               Off := Off + Last;
            end loop;
            Put_Line ("stream:" & Pos'Image & " bytes via Append, readback "
                      & (if Ok and then Off = Pos then "OK" else "MISMATCH"));
            if not (Ok and then Off = Pos) then
               Set_Exit_Status (Failure);
            end if;
         end;
      end;
      M.Close;
   elsif Scenario = "dindirect" then
      --  Create a > 4 MiB file via Append (into the DOUBLE-indirect map) and
      --  read it back; leaves it in place for e2fsck to validate the structure.
      declare
         MB5 : constant := 5 * 1024 * 1024;
         N   : constant Inode_Number := M.Create_File ("/", "big.bin");
         Ok  : Boolean;
      begin
         Build (N, MB5);
         M.Commit;
         Ok := Verify (N, MB5);
         Put_Line ("dindirect: 5 MB via Append (double-indirect), readback "
                   & (if Ok then "OK" else "MISMATCH"));
         if not Ok then
            Set_Exit_Status (Failure);
         end if;
      end;
      M.Close;
   elsif Scenario = "dtrunc" then
      --  Build a double-indirect file, then truncate it WITHIN the double region
      --  and down into the single region; verify the surviving prefix each time.
      declare
         N   : constant Inode_Number := M.Create_File ("/", "big.bin");
         Ok1, Ok2 : Boolean;
      begin
         Build (N, 5 * 1024 * 1024);
         M.Truncate (N, 4_500_000);          --  partial double-indirect
         Ok1 := Verify (N, 4_500_000);
         M.Truncate (N, 100_000);            --  down to single-indirect
         Ok2 := Verify (N, 100_000);
         M.Commit;
         Put_Line ("dtrunc: truncate double->single, readback "
                   & (if Ok1 and then Ok2 then "OK" else "MISMATCH"));
         if not (Ok1 and then Ok2) then
            Set_Exit_Status (Failure);
         end if;
      end;
      M.Close;
   elsif Scenario = "dunlink" then
      --  Create a double-indirect file then unlink it -- exercises the free path
      --  for the whole double-indirect tree; e2fsck confirms no leaked blocks.
      declare
         N : constant Inode_Number := M.Create_File ("/", "big.bin");
      begin
         Build (N, 5 * 1024 * 1024);
      end;
      M.Commit;
      M.Unlink ("/", "big.bin");
      M.Commit;
      Put_Line ("dunlink: 5 MB double-indirect file created + unlinked");
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
