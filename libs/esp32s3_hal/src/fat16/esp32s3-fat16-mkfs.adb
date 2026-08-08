with Ada.IO_Exceptions;

package body ESP32S3.Fat16.Mkfs is

   use type ESP32S3.Block_Dev.Sector_Index;

   package Blocks renames ESP32S3.Block_Dev;

   Sector_Bytes : constant := 512;
   Slot_Bytes   : constant := 32;

   --  Where partition 1 starts.  1 MiB is the modern convention and it is a
   --  multiple of every erase unit we might meet, so the alignment work below
   --  only has to worry about the filesystem's own metadata.
   Partition_Alignment : constant Blocks.Sector_Index := 2048;

   --  512 root entries is the universal FAT16 choice: exactly 32 sectors, and
   --  more root files than this volume is ever going to hold.
   Root_Entries : constant := 512;
   Root_Sectors : constant := Root_Entries * Slot_Bytes / Sector_Bytes;

   --  4 KB clusters match the NOR erase unit.  Doubling from here is only for
   --  media too large to address otherwise, halving only for media too small.
   Preferred_Cluster_Sectors : constant := 8;

   Min_Clusters : constant := 4085;    --  below this the table would be FAT12
   Max_Clusters : constant := 65524;   --  above it, FAT32

   ---------------------------------------------------------------------------

   procedure Put_16
     (Data   : in out Blocks.Sector;
      Offset : Natural;
      Value  : Interfaces.Unsigned_16) is
   begin
      Data (Offset) := Interfaces.Unsigned_8 (Value and 16#FF#);
      Data (Offset + 1) :=
        Interfaces.Unsigned_8 (Interfaces.Shift_Right (Value, 8) and 16#FF#);
   end Put_16;

   procedure Put_32
     (Data   : in out Blocks.Sector;
      Offset : Natural;
      Value  : Interfaces.Unsigned_32) is
   begin
      for I in 0 .. 3 loop
         Data (Offset + I) :=
           Interfaces.Unsigned_8
             (Interfaces.Shift_Right (Value, 8 * I) and 16#FF#);
      end loop;
   end Put_32;

   procedure Put_Text
     (Data : in out Blocks.Sector; Offset : Natural; Text : String) is
   begin
      for I in Text'Range loop
         Data (Offset + I - Text'First) := Character'Pos (Text (I));
      end loop;
   end Put_Text;

   --  The label as FAT stores it: 11 bytes, blank padded, upper case.
   function Padded_Label (Text : String) return String is
      Result : String (1 .. Max_Label_Length) := (others => ' ');
      Count  : constant Natural := Natural'Min (Text'Length, Max_Label_Length);
   begin
      for I in 1 .. Count loop
         declare
            C : constant Character := Text (Text'First + I - 1);
         begin
            Result (I) :=
              (if C in 'a' .. 'z'
               then Character'Val (Character'Pos (C) - 32)
               else C);
         end;
      end loop;
      return Result;
   end Padded_Label;

   ---------------------------------------------------------------------------

   procedure Format
     (Device               : ESP32S3.Block_Dev.Device;
      Status               : out Status_Kind;
      Label                : String := "NO NAME";
      Serial_Number        : Interfaces.Unsigned_32 := 16#4553_5033#;
      With_Partition_Table : Boolean := True)
   is
      Total_Sectors : Blocks.Sector_Index;
      Part_Start    : Blocks.Sector_Index := 0;
      Part_Sectors  : Blocks.Sector_Index;

      Cluster_Sectors : Natural := Preferred_Cluster_Sectors;
      Reserved        : Natural := 8;
      Fat_Sectors     : Natural := 1;
      Clusters        : Natural := 0;

      Data : Blocks.Sector;
      Text : constant String := Padded_Label (Label);

      --  Solve the circular constraint between the table's size and the
      --  cluster count it has to describe: each pass sizes the table for the
      --  clusters the previous pass allowed, which converges downward.
      procedure Size_The_Table is
         Metadata  : Natural;
         Available : Blocks.Sector_Index;
         Needed    : Natural;
      begin
         Fat_Sectors := 1;
         for Pass in 1 .. 8 loop
            Metadata := Reserved + 2 * Fat_Sectors + Root_Sectors;
            exit when Blocks.Sector_Index (Metadata) >= Part_Sectors;

            Available := Part_Sectors - Blocks.Sector_Index (Metadata);
            Clusters := Natural (Available) / Cluster_Sectors;
            Needed := ((Clusters + 2) * 2 + Sector_Bytes - 1) / Sector_Bytes;
            exit when Needed <= Fat_Sectors;
            Fat_Sectors := Needed;
         end loop;
      end Size_The_Table;

      procedure Write (LBA : Blocks.Sector_Index; Content : Blocks.Sector) is
      begin
         Blocks.Write_Sector (Device, LBA, Content);
      end Write;

   begin
      Status := Ok;

      if not Blocks.Writable (Device) then
         Status := Device_Failed;
         return;
      end if;

      Total_Sectors := Blocks.Sector_Count (Device);

      if With_Partition_Table then
         if Total_Sectors <= Partition_Alignment then
            Status := Unsupported;
            return;
         end if;
         Part_Start := Partition_Alignment;
      end if;
      Part_Sectors := Total_Sectors - Part_Start;

      --  Pick a cluster size the volume can actually be described with:
      --  grow it while there are too many clusters, shrink it while too few.
      loop
         Size_The_Table;
         exit when Clusters in Min_Clusters .. Max_Clusters;

         if Clusters > Max_Clusters then
            exit when Cluster_Sectors >= 64;
            Cluster_Sectors := Cluster_Sectors * 2;
         else
            exit when Cluster_Sectors = 1;
            Cluster_Sectors := Cluster_Sectors / 2;
         end if;
      end loop;

      if Clusters not in Min_Clusters .. Max_Clusters then
         Status := Unsupported;
         return;
      end if;

      --  Pad the reserved region so the DATA area begins on a cluster
      --  boundary measured from the partition start -- which, the partition
      --  itself being 1 MiB aligned, makes it erase-unit aligned on the flash.
      declare
         Metadata : constant Natural :=
           Reserved + 2 * Fat_Sectors + Root_Sectors;
         Slack    : constant Natural :=
           (Cluster_Sectors - Metadata mod Cluster_Sectors)
           mod Cluster_Sectors;
      begin
         if Slack > 0 then
            Reserved := Reserved + Slack;
            Size_The_Table;
            if Clusters not in Min_Clusters .. Max_Clusters then
               Status := Unsupported;
               return;
            end if;
         end if;
      end;

      --  ---- partition table ------------------------------------------------
      if With_Partition_Table then
         Data := (others => 0);
         --  Entry 1 at offset 446: bootable flag off, type 0x0E (FAT16 LBA).
         --  The CHS fields are the "too big to express" pattern every modern
         --  tool writes; nothing on this path reads them.
         Data (446) := 16#00#;
         Data (447) := 16#FE#;
         Data (448) := 16#FF#;
         Data (449) := 16#FF#;
         Data (450) := 16#0E#;
         Data (451) := 16#FE#;
         Data (452) := 16#FF#;
         Data (453) := 16#FF#;
         Put_32 (Data, 454, Interfaces.Unsigned_32 (Part_Start));
         Put_32 (Data, 458, Interfaces.Unsigned_32 (Part_Sectors));
         Put_16 (Data, 510, 16#AA55#);
         Write (0, Data);
      end if;

      --  ---- boot sector / BPB ----------------------------------------------
      Data := (others => 0);
      Data (0) := 16#EB#;              --  jmp short +0x3C; nop -- the shape
      Data (1) := 16#3C#;              --  every FAT checker expects to see
      Data (2) := 16#90#;
      Put_Text (Data, 3, "MSWIN4.1");  --  OEM name: the most-tested value
      Put_16 (Data, 11, Sector_Bytes);
      Data (13) := Interfaces.Unsigned_8 (Cluster_Sectors);
      Put_16 (Data, 14, Interfaces.Unsigned_16 (Reserved));
      Data (16) := 2;                  --  two copies of the table
      Put_16 (Data, 17, Root_Entries);
      Put_16
        (Data,
         19,
         (if Part_Sectors <= 16#FFFF#
          then Interfaces.Unsigned_16 (Part_Sectors)
          else 0));
      Data (21) := 16#F8#;             --  media descriptor: fixed disk
      Put_16 (Data, 22, Interfaces.Unsigned_16 (Fat_Sectors));
      Put_16
        (Data, 24, 63);           --  sectors per track  (geometry fiction,
      Put_16 (Data, 26, 255);          --  heads              kept plausible)
      Put_32 (Data, 28, Interfaces.Unsigned_32 (Part_Start));
      Put_32
        (Data,
         32,
         (if Part_Sectors > 16#FFFF#
          then Interfaces.Unsigned_32 (Part_Sectors)
          else 0));
      Data (36) := 16#80#;             --  BIOS drive number
      Data (38) := 16#29#;             --  extended boot signature: the three
      Put_32 (Data, 39, Serial_Number);   --  fields below are present
      Put_Text (Data, 43, Text);
      Put_Text (Data, 54, "FAT16   ");
      Put_16 (Data, 510, 16#AA55#);
      Write (Part_Start, Data);

      --  ---- the two allocation tables --------------------------------------
      --  Entry 0 repeats the media descriptor, entry 1 is the end-of-chain
      --  marker; both are conventions, not data.  Everything after is free.
      Blocks.Erase_Sectors
        (Device,
         Part_Start + Blocks.Sector_Index (Reserved),
         Blocks.Sector_Index (2 * Fat_Sectors + Root_Sectors));

      for Copy in 0 .. 1 loop
         declare
            Base : constant Blocks.Sector_Index :=
              Part_Start + Blocks.Sector_Index (Reserved + Copy * Fat_Sectors);
         begin
            Data := (others => 0);
            Data (0) := 16#F8#;
            Data (1) := 16#FF#;
            Data (2) := 16#FF#;
            Data (3) := 16#FF#;
            Write (Base, Data);

            Data := (others => 0);
            for S in 1 .. Fat_Sectors - 1 loop
               Write (Base + Blocks.Sector_Index (S), Data);
            end loop;
         end;
      end loop;

      --  ---- root directory -------------------------------------------------
      declare
         Root_Base : constant Blocks.Sector_Index :=
           Part_Start + Blocks.Sector_Index (Reserved + 2 * Fat_Sectors);
      begin
         Data := (others => 0);
         --  The label lives in the root directory as well as in the boot
         --  sector; Windows shows this one.
         Put_Text (Data, 0, Text);
         Data (11) := 16#08#;          --  volume-id attribute
         Write (Root_Base, Data);

         Data := (others => 0);
         for S in 1 .. Root_Sectors - 1 loop
            Write (Root_Base + Blocks.Sector_Index (S), Data);
         end loop;
      end;

   exception
      when Ada.IO_Exceptions.Device_Error =>
         Status := Device_Failed;
   end Format;

end ESP32S3.Fat16.Mkfs;

