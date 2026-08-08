--  Host driver for ESP32S3.Esp_Loader.  The protocol is transport-agnostic, so
--  on the host we wire the Link's four callbacks to the process's own file
--  descriptors and let a simulated ESP32 ROM (fake_rom.py) sit on the other
--  side of the pipes:
--
--     stdout (fd 1)  bytes to the "target"      Send
--     stdin  (fd 0)  bytes from the "target"    Receive   (poll for the timeout)
--     stderr (fd 2)  control lines, as text     Assert_Reset / Assert_Boot /
--                                               Set_Baud
--
--  Putting the control lines on a separate stream is what lets the simulator
--  check that the target was actually reset into its download loader before it
--  answers a SYNC -- the part a loopback test would silently skip.
--
--     esp_loader_test <scenario> [<image-file>]
--
--  Exit status 0 when the scenario's expected outcome happened, 1 otherwise.

with Ada.Command_Line;
with Ada.Streams.Stream_IO;
with Interfaces.C;
with System;

with ESP32S3.Esp_Loader;

procedure Esp_Loader_Test is

   use type Interfaces.C.int;
   use type Interfaces.C.long;
   use type Interfaces.Unsigned_32;

   package Loader renames ESP32S3.Esp_Loader;
   use type Loader.Status_Kind;

   ---------------------------------------------------------------------------
   --  Raw descriptor I/O.  Host-only glue, exactly as the esp_flash host tool
   --  does it -- the library itself never sees a file descriptor.
   ---------------------------------------------------------------------------

   POLLIN : constant Interfaces.C.short := 1;

   type Pollfd is record
      Fd              : Interfaces.C.int;
      Events, Revents : Interfaces.C.short;
   end record
   with Convention => C;

   function C_Read
     (Fd : Interfaces.C.int; Buf : System.Address; N : Interfaces.C.size_t)
      return Interfaces.C.long
   with Import, Convention => C, External_Name => "read";

   function C_Write
     (Fd : Interfaces.C.int; Buf : System.Address; N : Interfaces.C.size_t)
      return Interfaces.C.long
   with Import, Convention => C, External_Name => "write";

   function C_Poll
     (Fds     : System.Address;
      N       : Interfaces.C.unsigned_long;
      Timeout : Interfaces.C.int) return Interfaces.C.int
   with Import, Convention => C, External_Name => "poll";

   procedure Write_All (Fd : Interfaces.C.int; Data : Loader.Byte_Array) is
      Sent    : Natural := 0;
      Written : Interfaces.C.long;
   begin
      while Sent < Data'Length loop
         Written :=
           C_Write
             (Fd,
              Data (Data'First + Sent)'Address,
              Interfaces.C.size_t (Data'Length - Sent));
         exit when Written <= 0;
         Sent := Sent + Natural (Written);
      end loop;
   end Write_All;

   procedure Say (Text : String) is
      Line : Loader.Byte_Array (1 .. Text'Length + 1);
   begin
      for I in Text'Range loop
         Line (I - Text'First + 1) := Character'Pos (Text (I));
      end loop;
      Line (Line'Last) := Character'Pos (ASCII.LF);
      Write_All (2, Line);
   end Say;

   ---------------------------------------------------------------------------
   --  The Link
   ---------------------------------------------------------------------------

   procedure Send (Ctx : System.Address; Data : Loader.Byte_Array) is
      pragma Unreferenced (Ctx);
   begin
      Write_All (1, Data);
   end Send;

   procedure Receive
     (Ctx        : System.Address;
      Into       : out Loader.Byte_Array;
      Last       : out Natural;
      Timeout_Ms : Natural)
   is
      pragma Unreferenced (Ctx);
      Watch : aliased Pollfd := (Fd => 0, Events => POLLIN, Revents => 0);
      Ready : Interfaces.C.int;
      Got   : Interfaces.C.long;
   begin
      Last := Into'First - 1;
      Ready := C_Poll (Watch'Address, 1, Interfaces.C.int (Timeout_Ms));
      if Ready <= 0 then
         return;
      end if;
      Got :=
        C_Read
          (0, Into (Into'First)'Address, Interfaces.C.size_t (Into'Length));
      if Got > 0 then
         Last := Into'First + Natural (Got) - 1;
      end if;
   end Receive;

   procedure Assert_Reset (Ctx : System.Address; Asserted : Boolean) is
      pragma Unreferenced (Ctx);
   begin
      Say ("RESET " & (if Asserted then "1" else "0"));
   end Assert_Reset;

   procedure Assert_Boot (Ctx : System.Address; Asserted : Boolean) is
      pragma Unreferenced (Ctx);
   begin
      Say ("BOOT " & (if Asserted then "1" else "0"));
   end Assert_Boot;

   procedure Set_Baud (Ctx : System.Address; Baud : Positive) is
      pragma Unreferenced (Ctx);
   begin
      Say ("BAUD" & Positive'Image (Baud));
   end Set_Baud;

   Wire : constant Loader.Link :=
     (Ctx          => System.Null_Address,
      Send         => Send'Unrestricted_Access,
      Receive      => Receive'Unrestricted_Access,
      Assert_Reset => Assert_Reset'Unrestricted_Access,
      Assert_Boot  => Assert_Boot'Unrestricted_Access,
      Set_Baud     => Set_Baud'Unrestricted_Access);

   ---------------------------------------------------------------------------

   Target : Loader.Session;
   Status : Loader.Status_Kind;
   Failed : Boolean := False;

   procedure Expect (What : String; Got, Want : Loader.Status_Kind) is
   begin
      if Got = Want then
         Say ("OK " & What & " = " & Loader.Status_Kind'Image (Got));
      else
         Say
           ("FAIL "
            & What
            & " = "
            & Loader.Status_Kind'Image (Got)
            & ", wanted "
            & Loader.Status_Kind'Image (Want));
         Failed := True;
      end if;
   end Expect;

   function Argument (N : Positive) return String
   is (if Ada.Command_Line.Argument_Count >= N
       then Ada.Command_Line.Argument (N)
       else "");

   Scenario : constant String := Argument (1);

begin
   if Scenario = "" then
      Say ("usage: esp_loader_test <scenario> [<image>]");
      Ada.Command_Line.Set_Exit_Status (2);
      return;
   end if;

   ---------------------------------------------------------------------------
   --  A target that never answers must be given up on, not waited on forever.
   if Scenario = "silent" then
      Loader.Connect (Target, Wire, Status);
      Expect ("connect", Status, Loader.No_Response);
      Ada.Command_Line.Set_Exit_Status (if Failed then 1 else 0);
      return;
   end if;

   Loader.Connect (Target, Wire, Status);
   Expect ("connect", Status, Loader.Ok);
   if Status /= Loader.Ok then
      Ada.Command_Line.Set_Exit_Status (1);
      return;
   end if;
   Say ("CHIP " & Loader.Chip_Name (Loader.Chip (Target)));

   if Scenario = "detect" then
      Ada.Command_Line.Set_Exit_Status (if Failed then 1 else 0);
      return;
   end if;

   ---------------------------------------------------------------------------
   if Scenario = "regread" then
      declare
         Magic : Interfaces.Unsigned_32;
      begin
         Loader.Read_Register (Target, 16#4000_1000#, Magic, Status);
         Expect ("read_register", Status, Loader.Ok);
         if Magic /= 16#9# then
            Say ("FAIL magic =" & Interfaces.Unsigned_32'Image (Magic));
            Failed := True;
         else
            Say ("OK magic =" & Interfaces.Unsigned_32'Image (Magic));
         end if;
      end;

   ---------------------------------------------------------------------------
   elsif Scenario = "baud" then
      Loader.Set_Baud (Target, 921_600, Status);
      Expect ("set_baud", Status, Loader.Ok);

   ---------------------------------------------------------------------------
   elsif Scenario = "md5" then
      declare
         Digest : Loader.Digest_Text;
      begin
         Loader.Read_Md5 (Target, 16#1_0000#, 16#400#, Digest, Status);
         Expect ("read_md5", Status, Loader.Ok);
         Say ("MD5 " & Digest);
      end;

   ---------------------------------------------------------------------------
   elsif Scenario = "refuse" then
      Loader.Configure_Flash (Target, 4 * 1024 * 1024, Status);
      Expect ("configure_flash", Status, Loader.Ok);
      Loader.Begin_Image (Target, 16#1_0000#, 1024, Status);
      Expect ("begin_image refused", Status, Loader.Target_Refused);

   ---------------------------------------------------------------------------
   elsif Scenario = "short" then
      Loader.Configure_Flash (Target, 4 * 1024 * 1024, Status);
      Expect ("configure_flash", Status, Loader.Ok);
      Loader.Begin_Image (Target, 16#1_0000#, 4096, Status);
      Expect ("begin_image", Status, Loader.Ok);
      declare
         Partial : constant Loader.Byte_Array (1 .. 100) := (others => 16#A5#);
      begin
         Loader.Write (Target, Partial, Status);
         Expect ("write", Status, Loader.Ok);
      end;
      Loader.End_Image (Target, Status);
      Expect ("end_image short", Status, Loader.Wrong_Length);

   ---------------------------------------------------------------------------
   elsif Scenario = "overrun" then
      Loader.Configure_Flash (Target, 4 * 1024 * 1024, Status);
      Expect ("configure_flash", Status, Loader.Ok);
      Loader.Begin_Image (Target, 16#1_0000#, 64, Status);
      Expect ("begin_image", Status, Loader.Ok);
      declare
         Too_Much : constant Loader.Byte_Array (1 .. 65) := (others => 16#5A#);
      begin
         Loader.Write (Target, Too_Much, Status);
         Expect
           ("write past the declared length", Status, Loader.Wrong_Length);
      end;

   ---------------------------------------------------------------------------
   elsif Scenario = "flash" then
      declare
         use Ada.Streams.Stream_IO;
         Source : File_Type;
         Chunk  : Loader.Byte_Array (1 .. 3_000);   --  deliberately not a
         --  multiple of the 1 KB block, so
         --  every boundary case is crossed
         Length : Interfaces.Unsigned_32;
         Fill   : Natural;
      begin
         Open (Source, In_File, Argument (2));
         Length := Interfaces.Unsigned_32 (Size (Source));

         Loader.Configure_Flash (Target, 4 * 1024 * 1024, Status);
         Expect ("configure_flash", Status, Loader.Ok);

         Loader.Begin_Image (Target, 16#1_0000#, Length, Status);
         Expect ("begin_image", Status, Loader.Ok);

         while Status = Loader.Ok
           and then Interfaces.Unsigned_32 (Index (Source) - 1) < Length
         loop
            Fill := 0;
            while Fill < Chunk'Length
              and then Interfaces.Unsigned_32 (Index (Source) - 1) < Length
            loop
               Fill := Fill + 1;
               Interfaces.Unsigned_8'Read (Stream (Source), Chunk (Fill));
            end loop;
            Loader.Write (Target, Chunk (1 .. Fill), Status);
         end loop;
         Expect ("write", Status, Loader.Ok);
         Close (Source);

         Loader.End_Image (Target, Status);
         Expect ("end_image", Status, Loader.Ok);

         if Loader.Remaining (Target) /= 0 then
            Say ("FAIL bytes still owed");
            Failed := True;
         end if;

         Loader.Finish (Target, Run => True, Status => Status);
         Expect ("finish", Status, Loader.Ok);
      end;

   ---------------------------------------------------------------------------
   else
      Say ("unknown scenario " & Scenario);
      Ada.Command_Line.Set_Exit_Status (2);
      return;
   end if;

   Ada.Command_Line.Set_Exit_Status (if Failed then 1 else 0);

exception
   when others =>
      Say ("FAIL exception");
      Ada.Command_Line.Set_Exit_Status (1);
end Esp_Loader_Test;

