--  ext4 WRITE battery for the pure-Ada filesystem (ESP32S3.Ext4) over SDMMC, on
--  a board where the SD card's DAT3/CD is driven by a CH422G expander (IO4).
--
--  It mounts read-write and exercises the write API as one journaled transaction:
--    * create a regular file + write it
--    * mkdir a subdirectory + create a file inside it
--    * write a 1 MiB file (forces the single-indirect block map, >12 blocks)
--    * hard link        (two names -> one inode, nlink=2)
--    * symbolic link    (fast/inline symlink)
--    * rename / move
--    * delete (unlink)
--  Each step is asserted on-device; the card then passes 'e2fsck -f' clean on a
--  host, where the tree, the symlink target and the big-file pattern verify.
--
--  The card MUST be whole-device and NON-metadata_csum:
--     mkfs.ext4 -F -O ^metadata_csum /dev/sdX
--  Writing a metadata_csum volume is refused (Read_Only) and reported.
--
--  Wiring:  SDMMC 1-bit CLK=IO12 CMD=IO11 D0=IO13 ; DAT3 via CH422G (I2C0
--  SDA=IO8 SCL=IO9, IO4).
with System;
with Interfaces;   use Interfaces;
with Interfaces.C; use Interfaces.C;
with Ada.Real_Time; use Ada.Real_Time;
with Ada.Exceptions; use Ada.Exceptions;
with Ada.Unchecked_Deallocation;

with ESP32S3.CH422G;
with ESP32S3.SDMMC;
with ESP32S3.Block_Dev;
with ESP32S3.Block_Dev.SDMMC_Source;
with ESP32S3.Ext4;       use ESP32S3.Ext4;
with ESP32S3.Ext4.FS;
with ESP32S3.Ext4.Inode;
with ESP32S3.Ext4.Bitmap;   --  Phantom_Free_Count tripwire

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   package CH renames ESP32S3.CH422G;
   package SD renames ESP32S3.SDMMC;
   use type CH.Status;
   use type SD.Status;

   procedure Banner;  pragma Import (C, Banner, "native_w_banner");
   procedure Card_R (Ok : int);   pragma Import (C, Card_R, "native_w_card");
   procedure Mount_R (Ok : int);  pragma Import (C, Mount_R, "native_w_mount");
   procedure Write_R (Ok : int; Msg : System.Address);
                      pragma Import (C, Write_R, "native_w_write");
   procedure Step_C (S : System.Address);  pragma Import (C, Step_C, "native_w_step");
   procedure Check_C (L : System.Address; Ok : int);
                      pragma Import (C, Check_C, "native_w_check");
   procedure Done;  pragma Import (C, Done, "native_w_done");

   Dev_CH : CH.Device;
   ExS    : CH.Session;
   ESt    : CH.Status;
   SDC    : aliased SD.Card;
   St     : SD.Status;

   --  A 1 MiB file exercises the single-indirect block map (>12 direct blocks).
   Big_Size : constant := 1024 * 1024;
   type Byte_Array_Ptr is access ESP32S3.Ext4.Byte_Array;
   procedure Free is new Ada.Unchecked_Deallocation
     (ESP32S3.Ext4.Byte_Array, Byte_Array_Ptr);

   function Pat (I : Natural) return U8 is (U8 (I mod 251));   --  big-file byte

   --  NUL-terminate Str for the C %s glue (non-printables -> '.').
   function Cstr (Str : String) return String is
      R : String (1 .. Str'Length + 1);
   begin
      for I in 1 .. Str'Length loop
         declare
            Ch : constant Character := Str (Str'First + I - 1);
         begin
            R (I) := (if Character'Pos (Ch) in 32 .. 126 then Ch else '.');
         end;
      end loop;
      R (R'Last) := Character'Val (0);
      return R;
   end Cstr;

   procedure Step (S : String) is
      M : aliased constant String := Cstr (S);
   begin
      Step_C (M'Address);
   end Step;

   procedure Check (Label : String; Ok : Boolean) is
      M : aliased constant String := Cstr (Label);
   begin
      Check_C (M'Address, Boolean'Pos (Ok));
   end Check;

   procedure Report_Error (Msg : String) is
      M : aliased constant String := Cstr (Msg);
   begin
      Write_R (0, M'Address);
   end Report_Error;

   --  Fill Data with text Str (caller sizes Data to Str'Length).
   procedure Fill (Data : out Byte_Array; Str : String) is
   begin
      for K in Str'Range loop
         Data (Data'First + (K - Str'First)) := Character'Pos (Str (K));
      end loop;
   end Fill;

begin
   delay until Clock + Milliseconds (200);
   Banner;

   --  CH422G: drive DAT3/CD (IO4) high.
   CH.Setup (Dev_CH, Sda => 8, Scl => 9);
   CH.Acquire (ExS, Dev_CH);
   CH.Write_IO (ExS, 16#10#, ESt);
   if ESt = CH.OK then
      CH.Configure (ExS, IO_Dir => CH.Outputs, OC_Mode => CH.Push_Pull,
                    Result => ESt);
   end if;

   --  SDMMC: 1-bit, High Speed.
   SD.Setup (SDC, On => SD.Slot1, Clk => 12, Cmd => 11, D0 => 13,
             Width => SD.Width_1, Data_Clock_Hz => 50_000_000,
             High_Speed => True);
   SD.Initialize (SDC, St);
   Card_R (Boolean'Pos (St = SD.OK));
   if St /= SD.OK then
      Done;
      loop delay until Clock + Seconds (3600); end loop;
   end if;

   declare
      BD : constant ESP32S3.Block_Dev.Device :=
             ESP32S3.Block_Dev.SDMMC_Source.Make (SDC'Access);
      M  : ESP32S3.Ext4.FS.Mount;

      --  True if Path resolves.  These helpers reference M but are only ever
      --  CALLED directly (never 'Access'd), so no nested-subprogram trampoline.
      function Exists (Path : String) return Boolean is
         Ino : ESP32S3.Ext4.Inode_Number;
         pragma Unreferenced (Ino);
      begin
         Ino := M.Lookup (Path);
         return True;
      exception
         when Name_Error => return False;
      end Exists;

      function Ino_Of (Path : String) return ESP32S3.Ext4.Inode_Number is
      begin
         return M.Lookup (Path);
      exception
         when Name_Error => return 0;
      end Ino_Of;

      --  Best-effort removal so the battery is re-runnable without reformat.
      procedure Try_Unlink (Dir, Name : String) is
      begin
         M.Unlink (Dir, Name);
      exception
         when others => null;
      end Try_Unlink;

      procedure Try_Rmdir (Dir, Name : String) is
      begin
         M.Rmdir (Dir, Name);
      exception
         when others => null;
      end Try_Rmdir;
   begin
      M.Open (BD, Read_Only => False, Cache_Blocks => 16);
      Mount_R (1);
      Bitmap.Reset_Phantom_Free_Count;   --  arm the stale-read / double-free tripwire

      --  0. Remove any leftovers from a previous run.
      Step ("cleanup");
      Try_Unlink ("/", "ada_write.txt");
      Try_Unlink ("/", "ada_hard.txt");
      Try_Unlink ("/", "ada_link");
      Try_Unlink ("/", "ada_renamed.txt");
      Try_Unlink ("/", "ada_big.bin");
      Try_Unlink ("/", "ada_del.txt");
      Try_Unlink ("/", "ada_tmp.txt");
      Try_Unlink ("/ada_dir", "inside.txt");
      Try_Rmdir ("/", "ada_dir");
      M.Commit;

      --  1. A small regular file (the hard-link + symlink target).
      Step ("create /ada_write.txt");
      declare
         Text : constant String :=
           "Written by ESP32-S3 pure-Ada ext4 over SDMMC!" & ASCII.LF;
         Data : Byte_Array (0 .. Text'Length - 1);
      begin
         Fill (Data, Text);
         M.Write_File (M.Create_File ("/", "ada_write.txt"), Data);
      end;
      Check ("create file", Exists ("/ada_write.txt"));

      --  2. A subdirectory with a file inside it.
      Step ("mkdir /ada_dir + file inside");
      M.Mkdir ("/", "ada_dir");
      declare
         Text : constant String := "inside a subdirectory" & ASCII.LF;
         Data : Byte_Array (0 .. Text'Length - 1);
      begin
         Fill (Data, Text);
         M.Write_File (M.Create_File ("/ada_dir", "inside.txt"), Data);
      end;
      declare
         DI : Inode.Info;
      begin
         M.Stat (M.Lookup ("/ada_dir"), DI);
         Check ("mkdir (is a directory)", Inode.Is_Dir (DI));
      end;
      Check ("file inside dir", Exists ("/ada_dir/inside.txt"));

      --  3. A 1 MiB file -> single-indirect block map.
      Step ("write big file /ada_big.bin (1 MiB)");
      declare
         Big  : Byte_Array_Ptr := new Byte_Array (0 .. Big_Size - 1);
         BI   : Inode.Info;
         Buf  : Byte_Array (0 .. 127);
         Last : Natural;
         Ok   : Boolean := True;
      begin
         for I in Big'Range loop
            Big (I) := Pat (I);
         end loop;
         M.Write_File (M.Create_File ("/", "ada_big.bin"), Big.all);
         Free (Big);

         M.Stat (M.Lookup ("/ada_big.bin"), BI);
         Ok := BI.Size = U64 (Big_Size);
         M.Read_File (BI, 0, Buf, Last);                 --  head
         Ok := Ok and then Last = Buf'Length;
         for K in 0 .. Last - 1 loop
            Ok := Ok and then Buf (K) = Pat (K);
         end loop;
         M.Read_File (BI, U64 (Big_Size - 128), Buf, Last);   --  tail
         Ok := Ok and then Last = Buf'Length;
         for K in 0 .. Last - 1 loop
            Ok := Ok and then Buf (K) = Pat (Big_Size - 128 + K);
         end loop;
         Check ("big file size + head/tail pattern", Ok);
      end;

      --  4. Hard link -> same inode, nlink=2.
      Step ("hard link /ada_hard.txt -> /ada_write.txt");
      M.Link ("/ada_write.txt", "/", "ada_hard.txt");
      declare
         I1 : constant Inode_Number := Ino_Of ("/ada_write.txt");
         I2 : constant Inode_Number := Ino_Of ("/ada_hard.txt");
         HI : Inode.Info;
      begin
         M.Stat (I1, HI);
         Check ("hard link (same inode, nlink=2)",
                I1 /= 0 and then I1 = I2 and then HI.Links = 2);
      end;

      --  5. Symbolic link (target "ada_write.txt" -> 13 bytes, fast symlink).
      Step ("symlink /ada_link -> ada_write.txt");
      M.Symlink ("/", "ada_link", "ada_write.txt");
      declare
         LI : Inode.Info;
      begin
         M.Stat (M.Lookup ("/ada_link"), LI);
         Check ("symlink (is a symlink, size=13)",
                Inode.Is_Symlink (LI) and then LI.Size = 13);
      end;

      --  6. Rename / move.
      Step ("rename /ada_tmp.txt -> /ada_renamed.txt");
      declare
         Text : constant String := "rename me" & ASCII.LF;
         Data : Byte_Array (0 .. Text'Length - 1);
      begin
         Fill (Data, Text);
         M.Write_File (M.Create_File ("/", "ada_tmp.txt"), Data);
      end;
      M.Rename ("/", "ada_tmp.txt", "/", "ada_renamed.txt");
      Check ("rename (old gone, new present)",
             not Exists ("/ada_tmp.txt") and then Exists ("/ada_renamed.txt"));

      --  7. Delete (unlink).
      Step ("delete /ada_del.txt");
      declare
         Text : constant String := "delete me" & ASCII.LF;
         Data : Byte_Array (0 .. Text'Length - 1);
      begin
         Fill (Data, Text);
         M.Write_File (M.Create_File ("/", "ada_del.txt"), Data);
      end;
      M.Unlink ("/", "ada_del.txt");
      Check ("delete (gone)", not Exists ("/ada_del.txt"));

      --  Commit the whole battery as one journaled transaction.
      Step ("commit");
      M.Commit;

      --  TRIPWIRE: the idempotent Free keeps the free count consistent with the
      --  bitmap on an already-clear bit (a double-free, or a stale/incoherent read
      --  from a flaky card) -- but we surface it rather than mask it.  0 on a
      --  healthy card; >0 means stale cleanup reads (suspect the SD card).
      Check ("no phantom frees (count consistent with bitmap)",
             Bitmap.Phantom_Free_Count = 0);
      Write_R (1, System.Null_Address);

   exception
      when ESP32S3.Ext4.Read_Only =>
         Report_Error
           ("metadata_csum volume -- reformat: mkfs.ext4 -O ^metadata_csum");
      when E : others =>
         Report_Error (Exception_Name (E));
   end;

   Done;
   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
