--  Host driver for ESP32S3.Fat16: it plugs an image file into the
--  ESP32S3.Block_Dev seam and exposes each library operation as a command, so
--  run_tests.sh can drive it and cross-check the results against the host's
--  own dosfstools and against an independent Python writer.
--
--     fat16_test format <image> [label]     lay down an empty volume
--     fat16_test info   <image>             geometry + label + free space
--     fat16_test list   <image> [path]      one line per directory entry
--     fat16_test cat    <image> <path> <to> extract a file byte for byte
--     fat16_test readall <image> <path> <to> the same, via Read_File
--
--  Exit status is 0 on success, 1 on a library error, 2 on misuse.

with Ada.Command_Line;
with Ada.Exceptions;
with Ada.Direct_IO;
with Ada.Streams.Stream_IO;
with Ada.Text_IO;
with Interfaces;
with System;

with ESP32S3.Block_Dev;
with ESP32S3.Fat16;
with ESP32S3.Fat16.Mkfs;

procedure Fat16_Test is

   --  Renamed for brevity: every reference below reads Fat16.X.
   package Fat16 renames ESP32S3.Fat16;
   package Mkfs renames ESP32S3.Fat16.Mkfs;

   use type Interfaces.Unsigned_32;

   use type ESP32S3.Block_Dev.Sector_Index;
   use type Fat16.Status_Kind;

   package IO renames Ada.Text_IO;
   package Blocks renames ESP32S3.Block_Dev;
   package Sector_IO is new Ada.Direct_IO (Blocks.Sector);

   Image : Sector_IO.File_Type;

   ---------------------------------------------------------------------------
   --  The image file as a block device.  Direct_IO indexes from 1, LBAs from 0.
   ---------------------------------------------------------------------------

   procedure Image_Read
     (Ctx : System.Address; LBA : Blocks.Sector_Index; Data : out Blocks.Sector)
   is
      pragma Unreferenced (Ctx);
   begin
      Sector_IO.Read (Image, Data, Sector_IO.Positive_Count (LBA + 1));
   end Image_Read;

   procedure Image_Write
     (Ctx : System.Address; LBA : Blocks.Sector_Index; Data : Blocks.Sector)
   is
      pragma Unreferenced (Ctx);
   begin
      Sector_IO.Write (Image, Data, Sector_IO.Positive_Count (LBA + 1));
   end Image_Write;

   function Image_Count (Ctx : System.Address) return Blocks.Sector_Index is
      pragma Unreferenced (Ctx);
   begin
      return Blocks.Sector_Index (Sector_IO.Size (Image));
   end Image_Count;

   --  Supplied so the reader's multi-sector path is the one under test here,
   --  rather than Block_Dev's per-sector fallback.
   procedure Image_Read_Run
     (Ctx   : System.Address;
      First : Blocks.Sector_Index;
      Data  : out Blocks.Sector_Run)
   is
      pragma Unreferenced (Ctx);
      Count : constant Natural := Data'Length / 512;
   begin
      for I in 0 .. Count - 1 loop
         declare
            One : Blocks.Sector
              with Import, Address => Data (Data'First + I * 512)'Address;
         begin
            Sector_IO.Read
              (Image, One, Sector_IO.Positive_Count (First + Blocks.Sector_Index (I) + 1));
         end;
      end loop;
   end Image_Read_Run;

   Device : constant Blocks.Device :=
     (Ctx       => System.Null_Address,
      Read      => Image_Read'Unrestricted_Access,
      Write     => Image_Write'Unrestricted_Access,
      Count     => Image_Count'Unrestricted_Access,
      Erase     => null,
      Read_Run  => Image_Read_Run'Unrestricted_Access,
      Write_Run => null);

   ---------------------------------------------------------------------------

   Volume : Fat16.Volume;
   Status : Fat16.Status_Kind;

   function Argument (N : Positive) return String
   is (if Ada.Command_Line.Argument_Count >= N
       then Ada.Command_Line.Argument (N) else "");

   procedure Fail (Message : String) is
   begin
      IO.Put_Line (IO.Standard_Error, "fat16_test: " & Message);
      Ada.Command_Line.Set_Exit_Status (1);
   end Fail;

   procedure Open_Image (Mode : Sector_IO.File_Mode) is
   begin
      Sector_IO.Open (Image, Mode, Argument (2));
   end Open_Image;

   procedure Mount_Image is
   begin
      Fat16.Mount (Volume, Device, Status);
      if Status /= Fat16.Ok then
         Fail ("mount: " & Fat16.Status_Kind'Image (Status));
      end if;
   end Mount_Image;

   Command : constant String := Argument (1);

begin
   if Command = "" or else Argument (2) = "" then
      IO.Put_Line (IO.Standard_Error,
                   "usage: fat16_test format|info|list|cat <image> ...");
      Ada.Command_Line.Set_Exit_Status (2);
      return;
   end if;

   ---------------------------------------------------------------------------
   if Command = "format" then
      Open_Image (Sector_IO.Inout_File);
      if Argument (3) = "" then
         Mkfs.Format (Device, Status);
      else
         Mkfs.Format (Device, Status, Label => Argument (3));
      end if;
      Sector_IO.Close (Image);
      if Status /= Fat16.Ok then
         Fail ("format: " & Fat16.Status_Kind'Image (Status));
      end if;

   ---------------------------------------------------------------------------
   elsif Command = "info" then
      Open_Image (Sector_IO.In_File);
      Mount_Image;
      if Status = Fat16.Ok then
         IO.Put_Line ("label         " & Fat16.Label (Volume));
         IO.Put_Line ("cluster_bytes"
                      & Natural'Image (Fat16.Cluster_Bytes (Volume)));
         IO.Put_Line ("clusters     "
                      & Natural'Image (Fat16.Cluster_Count (Volume)));
         IO.Put_Line ("total_bytes  "
                      & Interfaces.Unsigned_64'Image (Fat16.Total_Bytes (Volume)));
         IO.Put_Line ("free_bytes   "
                      & Interfaces.Unsigned_64'Image (Fat16.Free_Bytes (Volume)));
      end if;
      Sector_IO.Close (Image);

   ---------------------------------------------------------------------------
   elsif Command = "list" then
      Open_Image (Sector_IO.In_File);
      Mount_Image;
      if Status = Fat16.Ok then
         declare
            Scan  : Fat16.Search;
            Item  : Fat16.Directory_Entry;
            Found : Boolean;
            Path  : constant String :=
              (if Argument (3) = "" then "/" else Argument (3));
         begin
            Fat16.Start_Search (Volume, Path, Scan, Status);
            if Status /= Fat16.Ok then
               Fail ("search: " & Fat16.Status_Kind'Image (Status));
            else
               loop
                  Fat16.Next_Entry (Volume, Scan, Item, Found);
                  exit when not Found;
                  IO.Put_Line
                    ((if Fat16.Is_Directory (Item) then "DIR  " else "FILE ")
                     & Interfaces.Unsigned_32'Image (Fat16.Size (Item))
                     & " " & Fat16.Name (Item));
               end loop;
            end if;
         end;
      end if;
      Sector_IO.Close (Image);

   ---------------------------------------------------------------------------
   elsif Command = "cat" then
      if Argument (3) = "" or else Argument (4) = "" then
         IO.Put_Line (IO.Standard_Error, "usage: fat16_test cat <image> <path> <out>");
         Ada.Command_Line.Set_Exit_Status (2);
         return;
      end if;

      Open_Image (Sector_IO.In_File);
      Mount_Image;
      if Status = Fat16.Ok then
         declare
            The_File : Fat16.File;
            Output   : Ada.Streams.Stream_IO.File_Type;
         begin
            Fat16.Open (Volume, Argument (3), The_File, Status);
            if Status /= Fat16.Ok then
               Fail ("open: " & Fat16.Status_Kind'Image (Status));
            else
               Ada.Streams.Stream_IO.Create
                 (Output, Ada.Streams.Stream_IO.Out_File, Argument (4));
               declare
                  --  Deliberately not a multiple of the sector or cluster
                  --  size, so every read after the first starts mid-sector
                  --  and the unaligned path is exercised too.
                  Buffer : Fat16.Byte_Array (1 .. 5_000);
                  Last   : Natural;
                  Total  : Interfaces.Unsigned_32 := 0;
               begin
                  loop
                     Fat16.Read (Volume, The_File, Buffer, Last);
                     exit when Last < Buffer'First;
                     for I in Buffer'First .. Last loop
                        Interfaces.Unsigned_8'Write
                          (Ada.Streams.Stream_IO.Stream (Output), Buffer (I));
                     end loop;
                     Total := Total + Interfaces.Unsigned_32 (Last - Buffer'First + 1);
                  end loop;
                  Ada.Streams.Stream_IO.Close (Output);
                  if Total /= Fat16.Size (The_File) then
                     Fail ("short read:" & Interfaces.Unsigned_32'Image (Total)
                           & " of" & Interfaces.Unsigned_32'Image
                                       (Fat16.Size (The_File)));
                  end if;
               end;
            end if;
         end;
      end if;
      Sector_IO.Close (Image);

   ---------------------------------------------------------------------------
   elsif Command = "readall" then
      if Argument (3) = "" or else Argument (4) = "" then
         IO.Put_Line (IO.Standard_Error,
                      "usage: fat16_test readall <image> <path> <out>");
         Ada.Command_Line.Set_Exit_Status (2);
         return;
      end if;

      Open_Image (Sector_IO.In_File);
      Mount_Image;
      if Status = Fat16.Ok then
         declare
            --  One buffer, one call: the way the programmer will pull a
            --  firmware image out before handing it to the target.
            Whole  : Fat16.Byte_Array (1 .. 2 * 1024 * 1024);
            Last   : Natural;
            Output : Ada.Streams.Stream_IO.File_Type;
         begin
            Fat16.Read_File (Volume, Argument (3), Whole, Last, Status);
            if Status /= Fat16.Ok then
               Fail ("read_file: " & Fat16.Status_Kind'Image (Status));
            else
               Ada.Streams.Stream_IO.Create
                 (Output, Ada.Streams.Stream_IO.Out_File, Argument (4));
               for I in Whole'First .. Last loop
                  Interfaces.Unsigned_8'Write
                    (Ada.Streams.Stream_IO.Stream (Output), Whole (I));
               end loop;
               Ada.Streams.Stream_IO.Close (Output);
            end if;
         end;
      end if;
      Sector_IO.Close (Image);

   ---------------------------------------------------------------------------
   else
      IO.Put_Line (IO.Standard_Error, "fat16_test: unknown command " & Command);
      Ada.Command_Line.Set_Exit_Status (2);
   end if;

exception
   when Error : others =>
      IO.Put_Line (IO.Standard_Error,
                   "fat16_test: " & Ada.Exceptions.Exception_Information (Error));
      Ada.Command_Line.Set_Exit_Status (1);
end Fat16_Test;
