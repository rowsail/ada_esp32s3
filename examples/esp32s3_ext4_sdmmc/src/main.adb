--  What: mount a real ext4 (or ext2/3) SD card with the pure-Ada filesystem
--  (ESP32S3.Ext4) over the SDMMC block driver, then list the root directory and
--  read /hello.txt.  READ-ONLY -- it never writes.  This is the first on-card
--  bring-up of the pure-Ada ext4 FS (previously only host-verified vs e2fsck).
--
--  Build & run:  ./x run esp32s3_ext4_sdmmc
--    Needs the embedded (or full) profile, NOT the default light-tasking: the FS
--    and SDMMC use controlled types + the secondary stack.  build.sh sets
--    ESP32S3_RTS_PROFILE=embedded and a 256 KB heap for the FS block cache.
--
--  Output (each line prefixed "[ext4] "):
--    SD init: OK                       -- card detected and initialised
--    mount: OK   block size = 4096     -- ext4 superblock parsed (4 KB blocks)
--    one line per root-directory entry -- "<type> ino=<n>  <name>"
--    /hello.txt: <n> bytes = "<text>"  -- file contents preview
--    done.
--  A FAILED on SD init / mount, or an "ERROR:" line, means the card is missing
--  or not formatted ext4 whole-device (see Hardware below).
--
--  Hardware:  an SD card formatted ext4 over the WHOLE DEVICE (mkfs.ext4 -F
--  /dev/sdX, NOT a partition) so the superblock lands at the standard LBA 2.
--  SDMMC is wired 1-bit: CLK=IO12, CMD=IO11, D0=IO13.  On this board the card's
--  DAT3/CD line is not on a GPIO but on a CH422G I2C expander (IO4), so it is
--  held high over I2C0 (SDA=IO8, SCL=IO9) before the card is initialised.
with System;
with Interfaces;   use Interfaces;
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.CH422G;
with ESP32S3.SDMMC;
with ESP32S3.Block_Dev;
with ESP32S3.Block_Dev.SDMMC_Source;
with ESP32S3.Ext4;       use ESP32S3.Ext4;
with ESP32S3.Ext4.FS;
with ESP32S3.Ext4.Inode;
with FS_Glue;            use FS_Glue;   --  library-level glue (closure-free cb)

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   package CH422G renames ESP32S3.CH422G;
   package SDMMC  renames ESP32S3.SDMMC;
   use type CH422G.Status;
   use type SDMMC.Status;

   --  Console glue (Banner/Card_R/Mount_R/Entry_R/File_R/Err_R/Done) and Cstr
   --  live in the library-level package FS_Glue so the Iterate callback below
   --  stays closure-free (no GNAT stack trampoline -- see FS_Glue).

   --  CH422G I2C expander pins (this board): the SD DAT3/CD line is on IO4.
   CH422G_Sda_Pin : constant := 8;       --  I2C0 SDA
   CH422G_Scl_Pin : constant := 9;       --  I2C0 SCL

   --  Output-register value that drives the expander's IO4 high.  IO4 is bit 4,
   --  so 2**4 = 16#10#; this holds the card's DAT3/CD asserted (card present).
   CH422G_IO4_High : constant := 16#10#;

   --  SDMMC slot-1 wiring (1-bit bus) and clock.
   SDMMC_Clk_Pin    : constant := 12;
   SDMMC_Cmd_Pin    : constant := 11;
   SDMMC_D0_Pin     : constant := 13;
   SDMMC_Clock_Hz   : constant := 50_000_000;   --  High Speed: 50 MHz

   --  ext4 block cache: 16 blocks (16 x 4 KB) on the heap build.sh sized.
   FS_Cache_Blocks : constant := 16;

   Expander         : CH422G.Device;
   Expander_Session : CH422G.Session;
   Expander_Status  : CH422G.Status;
   Card             : aliased SDMMC.Card;
   Card_Status      : SDMMC.Status;

   --  Let the USB-serial console attach before the first line is printed.
   Startup_Delay : constant Time_Span := Milliseconds (200);

   procedure Stage (Name : String) is
   begin
      Err_R (Name);
   end Stage;
begin
   delay until Clock + Startup_Delay;
   Banner;

   --  CH422G: drive DAT3/CD (IO4) high -- load the output register, then enable
   --  the pins as push-pull outputs.  Order matters: set the value first so the
   --  line is already high the instant the pins switch to drive.
   CH422G.Setup (Expander, Sda => CH422G_Sda_Pin, Scl => CH422G_Scl_Pin);
   CH422G.Acquire (Expander_Session, Expander);
   CH422G.Write_IO (Expander_Session, CH422G_IO4_High, Expander_Status);
   if Expander_Status = CH422G.OK then
      CH422G.Configure (Expander_Session,
                        IO_Dir => CH422G.Outputs, OC_Mode => CH422G.Push_Pull,
                        Result => Expander_Status);
   end if;

   --  SDMMC: 1-bit, High Speed (50 MHz) if the card supports it.
   SDMMC.Setup (Card, On => SDMMC.Slot1,
                Clk => SDMMC_Clk_Pin, Cmd => SDMMC_Cmd_Pin, D0 => SDMMC_D0_Pin,
                Width => SDMMC.Width_1, Data_Clock_Hz => SDMMC_Clock_Hz,
                High_Speed => True);
   SDMMC.Initialize (Card, Card_Status);
   Card_R (Card_Status = SDMMC.OK);

   if Card_Status = SDMMC.OK then
      declare
         Block_Device : constant ESP32S3.Block_Dev.Device :=
                ESP32S3.Block_Dev.SDMMC_Source.Make (Card'Access);
         Mount        : ESP32S3.Ext4.FS.Mount;
      begin
         Mount.Open (Block_Device, Read_Only => True,
                     Cache_Blocks => FS_Cache_Blocks);
         Mount_R (True, Natural (Mount.Block_Size));

         --  List the root directory.
         declare
            Root_Info : ESP32S3.Ext4.Inode.Info;
         begin
            Mount.Stat (Mount.Lookup ("/"), Root_Info);
            Mount.Iterate (Root_Info, Visit'Access);
         end;

         --  Read the start of /hello.txt (if present) for the console preview.
         declare
            --  Read at most this many bytes -- enough to preview the file.
            Preview_Bytes : constant := 96;

            File_Info : ESP32S3.Ext4.Inode.Info;
            Buf       : Byte_Array (0 .. Preview_Bytes - 1);
            Last      : Natural;
         begin
            Mount.Stat (Mount.Lookup ("/hello.txt"), File_Info);
            Mount.Read_File (File_Info, 0, Buf, Last);
            declare
               Text : String (1 .. Last);
            begin
               for K in 0 .. Last - 1 loop
                  Text (K + 1) := Character'Val (Buf (K));
               end loop;
               File_R (True, Last, Clean (Text));
            end;
         exception
            when others =>
               File_R (False, 0, "");
         end;
      exception
         when others =>
            Stage ("mount / list (is the card formatted ext4 whole-device?)");
      end;
   end if;

   Done;

   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
