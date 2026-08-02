--  GT911 capacitive-touch driver demo on the bare-metal ESP32-S3 (no FreeRTOS,
--  no IDF).
--
--  What it demonstrates
--    The reusable ESP32S3.GT911 driver (a Goodix GT911: 5-point capacitive
--    touch controller over I2C), on the Waveshare ESP32-S3-Touch-LCD-7.  It:
--      * Releases the panel reset lines via the board's CH422G I/O expander
--        (the GT911 RST pin is expander IO1 -- until it goes high the chip
--        stays in reset and ACKs nothing).
--      * Sets the GT911 up on I2C0 (SDA=IO8, SCL=IO9, INT=IO4) and identifies
--        it: product ID ("911"), firmware version, configured output range.
--      * Then polls Read_Touches at 50 Hz and reports every fresh coordinate
--        report: each finger's track id, X / Y position and contact size, and
--        the all-fingers-lifted release.
--
--  Build & run
--    ./x run esp32s3_gt911             --  embedded profile (build.sh sets it)
--
--  Output
--    [gt911] GT911 5-point touch demo
--    [gt911]   I2C0 SDA=IO8 SCL=IO9 INT=IO4; reset via CH422G IO1
--    [gt911] product id : "911" fw 0x1060
--    [gt911] output range : 800 x 480
--    [gt911] touch: n=1  id 0 @ ( 400, 240) size 21     ...one line per report
--    [gt911] release                                    ...all fingers lifted
--
--  Hardware
--    Waveshare ESP32-S3-Touch-LCD-7: GT911 at 0x5D on I2C0 (SDA=IO8, SCL=IO9),
--    INT on IO4, RST on CH422G expander pin IO1 (same bus).  Writing 0x1E to
--    the expander's IO byte releases touch + LCD reset and turns the backlight
--    on -- the value the board's LCD demos use.
with Interfaces;    use Interfaces;
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.CH422G;
with ESP32S3.GT911;
with ESP32S3.Log; use ESP32S3.Log;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   package CH422G renames ESP32S3.CH422G;
   package GT911 renames ESP32S3.GT911;
   use type CH422G.Status;
   use type GT911.Status;
   use type GT911.Point_Count;

   --  I2C0 pins this board wires BOTH the CH422G expander and the GT911 to.
   I2C_Sda_Pin : constant := 8;
   I2C_Scl_Pin : constant := 9;

   --  The GT911 INT line (unused by this polling demo, but recorded so the
   --  .Interrupts child could arm it).
   Touch_Int_Pin : constant := 4;

   --  Expander IO byte that wakes the panel: IO1 = touch RST high, IO2 =
   --  backlight on, IO3 = LCD RST high, IO4 = SD card deselected.
   Panel_Wake : constant CH422G.IO_Value := 16#1E#;

   --  Report one fresh coordinate report.
   procedure Put_Report (State : GT911.Touch_State) is
   begin
      if State.Count = 0 then
         Put_Line ("[gt911] release");
         return;
      end if;
      Put ("[gt911] touch: n=");
      Put (Integer (State.Count));
      for P in 1 .. State.Count loop
         declare
            Pt : GT911.Touch_Point renames State.Points (GT911.Point_Index (P));
         begin
            Put ("  id ");
            Put (Integer (Pt.Id));
            Put (" @ (");
            Put (Integer (Pt.X), Width => 4);
            Put (",");
            Put (Integer (Pt.Y), Width => 4);
            Put (") size ");
            Put (Integer (Pt.Size));
         end;
      end loop;
      New_Line;
   end Put_Report;

   Expander     : CH422G.Device;
   Touch        : GT911.Device;
   State        : GT911.Touch_State;
   Touch_Status : GT911.Status;
   Was_Touching : Boolean := False;
begin
   delay until Clock + Milliseconds (200);
   Put_Line ("[gt911] GT911 5-point touch demo");
   Put_Line ("[gt911]   I2C0 SDA=IO8 SCL=IO9 INT=IO4; reset via CH422G IO1");

   --  Release the panel resets (GT911 RST is expander IO1).  The expander
   --  powers up with all IOs as inputs, so until this write the touch chip
   --  may be held in reset.
   declare
      Expander_Session : CH422G.Session;
      Expander_Status  : CH422G.Status;
   begin
      CH422G.Setup (Expander, Sda => I2C_Sda_Pin, Scl => I2C_Scl_Pin);
      CH422G.Acquire (Expander_Session, Expander);
      CH422G.Configure (Expander_Session, IO_Dir => CH422G.Outputs, Result => Expander_Status);
      if Expander_Status = CH422G.OK then
         CH422G.Write_IO (Expander_Session, Panel_Wake, Expander_Status);
      end if;
      Put_Line
        (if Expander_Status = CH422G.OK
         then "[gt911] panel resets released (expander IO = 0x1E)"
         else "[gt911] CH422G bus error -- is this the right board?");
      CH422G.Release (Expander_Session);
   end;

   --  The GT911 samples its address strap and boots ~50 ms after RST rises.
   delay until Clock + Milliseconds (120);

   GT911.Setup
     (Touch, Sda => I2C_Sda_Pin, Scl => I2C_Scl_Pin, Int_Pin => Touch_Int_Pin);

   --  Identify the chip: product ID + firmware + configured output range.
   declare
      Id      : GT911.Product_Id;
      Version : Unsigned_16;
      W, H    : Unsigned_16;
   begin
      GT911.Read_Product_Id (Touch, Id, Touch_Status);
      if Touch_Status /= GT911.OK then
         Put_Line ("[gt911] no ACK at 0x5D -- touch chip not responding");
      else
         Put ("[gt911] product id : """);
         for C of Id loop
            if C in ' ' .. '~' then
               Put (C);
            end if;
         end loop;
         Put ("""");
         GT911.Read_Firmware_Version (Touch, Version, Touch_Status);
         if Touch_Status = GT911.OK then
            Put (" fw 0x");
            Put_Hex (Unsigned_32 (Version), 4);
         end if;
         New_Line;
         GT911.Read_Resolution (Touch, W, H, Touch_Status);
         if Touch_Status = GT911.OK then
            Put ("[gt911] output range : ");
            Put (Integer (W));
            Put (" x ");
            Put (Integer (H));
            New_Line;
         end if;
      end if;
   end;

   --  Poll for coordinate reports.  50 Hz comfortably beats the chip's ~100 Hz
   --  scan without saturating the bus; a fresh report with Count = 0 is the
   --  all-fingers-lifted event (printed once).
   loop
      delay until Clock + Milliseconds (20);
      GT911.Read_Touches (Touch, State, Touch_Status);
      if Touch_Status = GT911.OK and then State.Fresh then
         if State.Count > 0 then
            Put_Report (State);
            Was_Touching := True;
         elsif Was_Touching then
            Put_Report (State);
            Was_Touching := False;
         end if;
      end if;
   end loop;
end Main;
