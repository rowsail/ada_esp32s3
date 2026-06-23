--  CH422G I2C I/O-expander driver demo on the bare-metal ESP32-S3 (no FreeRTOS,
--  no IDF).  READ-ONLY: it never drives a pin, so it cannot disturb whatever the
--  CH422G's outputs are wired to on the board.
--
--    * Setup the device on I2C0 (SDA=IO8, SCL=IO9) and Acquire it (held for the
--      whole run -- the two-level lock, like the RTC).
--    * Probe the chip (address-only ACK on the config command address 0x24).
--    * Then once a second read IO0..IO7 (RD-IO, address 0x26) and report them.
--
--  The CH422G powers up with IO0..IO7 as inputs (I/O-expansion mode), so reads
--  reflect the external pin levels without configuring anything.  (The driver's
--  Configure / Write_IO / Write_OC are available but deliberately unused here.)
with Interfaces.C; use Interfaces.C;
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.CH422G;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   package CH renames ESP32S3.CH422G;
   use type CH.Status;

   procedure Banner;  pragma Import (C, Banner, "native_ch_banner");
   procedure Present_C (Ok : int);
                      pragma Import (C, Present_C, "native_ch_present");
   procedure Read_C (IO, Ok : int);
                      pragma Import (C, Read_C, "native_ch_read");

   Dev : CH.Device;
   S   : CH.Session;
   V   : CH.IO_Value;
   St  : CH.Status;
begin
   delay until Clock + Milliseconds (200);
   Banner;

   CH.Setup (Dev, Sda => 8, Scl => 9);   --  I2C0, 400 kHz
   CH.Acquire (S, Dev);

   Present_C (Boolean'Pos (CH.Present (S)));

   loop
      delay until Clock + Seconds (1);
      CH.Read_IO (S, V, St);
      Read_C (int (V), Boolean'Pos (St = CH.OK));
   end loop;
end Main;
