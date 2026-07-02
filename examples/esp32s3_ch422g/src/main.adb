--  CH422G I2C I/O-expander driver demo on the bare-metal ESP32-S3 (no FreeRTOS,
--  no IDF).
--
--  What it demonstrates
--    The reusable ESP32S3.CH422G driver (a WCH CH422G: 8 bidirectional pins
--    IO0..IO7 + 4 output-only pins OC0..OC3 over I2C).  READ-ONLY: it never
--    drives a pin, so it cannot disturb whatever the CH422G's outputs are wired
--    to on the board.  It:
--      * Sets the device up on I2C0 (SDA=IO8, SCL=IO9) and Acquires it (held for
--        the whole run -- the two-level lock, like the RTC).
--      * Probes the chip (address-only ACK on the config command address 0x24).
--      * Then once a second reads IO0..IO7 (RD-IO, address 0x26) and reports them.
--
--    The CH422G powers up with IO0..IO7 as inputs (I/O-expansion mode), so reads
--    reflect the external pin levels without configuring anything.  (The driver's
--    Configure / Write_IO / Write_OC are available but deliberately unused here.)
--
--  Build & run
--    ./x run esp32s3_ch422g            --  embedded profile (build.sh sets it)
--
--  Output
--    [ch422g] CH422G I2C I/O expander demo (read-only)
--    [ch422g]   I2C0 SDA=IO8 SCL=IO9; addrs 0x24/0x23/0x38/0x26
--    [ch422g] probe 0x24 : ACK (present)
--    [ch422g] IO inputs = 0x9f  IO7..IO0 = 10011111
--    ...the last line repeats once a second with the live IO0..IO7 levels.
--
--  Hardware
--    I2C0 on SDA=IO8, SCL=IO9.  One CH422G on the bus (no address straps), at the
--    function-specific 7-bit addresses 0x24 (config) / 0x23 (OC out) / 0x38 (IO
--    out) / 0x26 (IO in).  Its IO0..IO7 pins read back whatever they are wired to.
with Interfaces;    use Interfaces;
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.CH422G;
with ESP32S3.Log; use ESP32S3.Log;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   package CH422G renames ESP32S3.CH422G;
   use type CH422G.Status;

   --  I2C0 pins this board wires the CH422G to (note: different from the
   --  TCA9555 board's SDA=IO8/SCL=IO7).
   I2C_Sda_Pin : constant := 8;
   I2C_Scl_Pin : constant := 9;

   --  The CH422G has 8 bidirectional IO pins (IO0..IO7), reported MSB-first.
   IO_Pin_Count : constant := 8;

   --  Report one IO read: "0x%02x" then the eight bits IO7..IO0.
   procedure Put_Read (Inputs : CH422G.IO_Value; Ok : Boolean) is
   begin
      if not Ok then
         Put_Line ("[ch422g] read IO : bus error");
         return;
      end if;
      Put ("[ch422g] IO inputs = 0x");
      Put_Hex (Unsigned_32 (Inputs), 2);
      Put ("  IO7..IO0 = ");
      for Bit in reverse 0 .. IO_Pin_Count - 1 loop
         Put (Integer (Shift_Right (Unsigned_32 (Inputs), Bit) and 1));
      end loop;
      New_Line;
   end Put_Read;

   Expander         : CH422G.Device;
   Expander_Session : CH422G.Session;
   Inputs           : CH422G.IO_Value;
   Expander_Status  : CH422G.Status;
begin
   delay until Clock + Milliseconds (200);
   Put_Line ("[ch422g] CH422G I2C I/O expander demo (read-only)");
   Put_Line ("[ch422g]   I2C0 SDA=IO8 SCL=IO9; addrs 0x24/0x23/0x38/0x26");

   CH422G.Setup (Expander, Sda => I2C_Sda_Pin, Scl => I2C_Scl_Pin);  --  I2C0, 400 kHz
   CH422G.Acquire (Expander_Session, Expander);

   Put ("[ch422g] probe 0x24 : ");
   Put_Line (if CH422G.Present (Expander_Session) then "ACK (present)" else "no ACK");

   loop
      delay until Clock + Seconds (1);
      CH422G.Read_IO (Expander_Session, Inputs, Expander_Status);
      Put_Read (Inputs, Expander_Status = CH422G.OK);
   end loop;
end Main;
