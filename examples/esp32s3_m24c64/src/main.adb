--  M24C64 I2C EEPROM driver demo on the bare-metal ESP32-S3 (no FreeRTOS, no IDF)
--  ====================================================================
--  What it demonstrates:  the reusable HAL driver (ESP32S3.M24C64) against a real
--  ST M24C64 64-Kbit EEPROM on the I2C bus.  Four steps:
--    strap   print the slave address the A0/A1/A2 straps select, and -- if the
--            part does not answer there -- probe all eight strap combinations so
--            a mis-strapped board reports the address it actually found.
--    boot    a one-byte counter in the last cell, incremented and written back
--            every run: proves the data really is non-volatile across resets.
--    page    write a 40-byte pattern at 0x0110 and read it back.  That start
--            address sits 16 bytes into a page, so the payload crosses a 32-byte
--            page boundary AND exceeds the 29-byte I2C write segment -- the two
--            splits the driver has to get right.
--    dump    the first 16 bytes of the pattern, as read back from the part.
--  No interrupt: the EEPROM is read and written on request.  Report goes through
--  the ROM printf glue (ESP32S3.Log); the Ada driver does all the I2C work.
--
--  Build & run:  ./x run esp32s3_m24c64
--    The driver uses the controlled I2C Session (finalization), so this runs on
--    the embedded profile (build.sh sets ESP32S3_RTS_PROFILE=embedded), not the
--    default light-tasking.
--  Output:  a banner, "(M24C64 present)", the boot count (one higher each reset),
--    "[rom] page-crossing write/read: PASS", and a hex dump.  If the part does not
--    ACK, the demo prints the strap scan and stops.
--  Hardware:  one M24C64 on I2C0 -- SDA = IO41, SCL = IO40, VCC/VSS to 3V3/GND,
--    WC (write control) to GND so writes are enabled, A0/A1/A2 to GND (address
--    0x50).  Tie any of A0/A1/A2 high and pass A0/A1/A2 => High to Setup.
with Ada.Real_Time; use Ada.Real_Time;
with Interfaces;    use Interfaces;

with ESP32S3.I2C;
with ESP32S3.M24C64;
with ESP32S3.Log; use ESP32S3.Log;

--  Pull the SMP slave-start entry into the link closure (glue.c calls it after
--  elaboration); core 1 just idles -- the demo runs on core 0.
with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   package EEPROM renames ESP32S3.M24C64;
   package Bus renames ESP32S3.I2C;
   use type EEPROM.Status;
   use type EEPROM.Pin_State;
   use type Bus.Byte;         --  "+", "xor", "=" on the EEPROM's data bytes
   use type Bus.Byte_Array;   --  "=" for the read-back comparison

   --  Board wiring of the M24C64 on I2C0 (handed to Setup; the driver hard-codes
   --  no pins).
   Rom_Sda_Pin : constant := 41;   --  IO41 = I2C0 data
   Rom_Scl_Pin : constant := 40;   --  IO40 = I2C0 clock

   --  How A0/A1/A2 are tied on this board: all to GND -> slave address 0x50.
   Strap_A0 : constant EEPROM.Pin_State := EEPROM.Low;
   Strap_A1 : constant EEPROM.Pin_State := EEPROM.Low;
   Strap_A2 : constant EEPROM.Pin_State := EEPROM.Low;

   --  Let the console settle before the first line so the banner is not eaten by
   --  boot chatter.
   Console_Settle : constant Time_Span := Milliseconds (200);

   --  Parking delay for the idle loops once the demo has nothing left to do.
   Idle_Park : constant Time_Span := Seconds (3600);

   --  A one-byte reset counter parked in the very last cell of the array.
   Boot_Count_Cell : constant EEPROM.Memory_Address := EEPROM.Capacity - 1;

   --  The page-crossing exercise: 0x110 is 16 bytes into a 32-byte page, and 40
   --  bytes is longer than one page and longer than one 29-byte I2C write.
   Pattern_Start  : constant EEPROM.Memory_Address := 16#0110#;
   Pattern_Length : constant := 40;
   Dump_Length    : constant := 16;

   Rom     : EEPROM.Device;
   Result  : EEPROM.Status;
   Counter : Bus.Byte;

   Pattern  : Bus.Byte_Array (0 .. Pattern_Length - 1);
   Readback : Bus.Byte_Array (0 .. Pattern_Length - 1) := (others => 0);

   --  Report a failed operation and park: nothing that follows can be trusted.
   procedure Fail (Step : String; Why : EEPROM.Status) is
   begin
      Put ("[rom] ");
      Put (Step);
      Put_Line
        (case Why is
           when EEPROM.OK            => " ok",
           when EEPROM.Bus_Error     => " failed: no ACK (check wiring/power/WC)",
           when EEPROM.Write_Timeout => " failed: write cycle never finished");
      loop
         delay until Clock + Idle_Park;
      end loop;
   end Fail;

   --  Which of the eight strap combinations answers?  Only reached when the
   --  configured address is silent, so it is the wiring diagnostic.
   procedure Scan_Straps is
      Found : Natural := 0;
   begin
      for A2 in EEPROM.Pin_State loop
         for A1 in EEPROM.Pin_State loop
            for A0 in EEPROM.Pin_State loop
               declare
                  Probe : EEPROM.Device;
               begin
                  EEPROM.Setup
                    (Probe, Sda => Rom_Sda_Pin, Scl => Rom_Scl_Pin,
                     A0 => A0, A1 => A1, A2 => A2);
                  if EEPROM.Is_Present (Probe) then
                     Found := Found + 1;
                     Put ("[rom]   a part answers at 0x");
                     Put_Hex (Unsigned_32 (EEPROM.Device_Address (A0, A1, A2)), 2);
                     Put ("  (A2=");
                     Put (if A2 = EEPROM.High then "1" else "0");
                     Put (" A1=");
                     Put (if A1 = EEPROM.High then "1" else "0");
                     Put (" A0=");
                     Put (if A0 = EEPROM.High then "1" else "0");
                     Put_Line (")");
                  end if;
               end;
            end loop;
         end loop;
      end loop;

      if Found = 0 then
         Put_Line ("[rom]   nothing answers on the bus -- check SDA/SCL/power.");
      end if;
   end Scan_Straps;

begin
   delay until Clock + Console_Settle;
   Put_Line ("[rom] M24C64 EEPROM driver demo (SDA=IO41 SCL=IO40)");

   EEPROM.Setup
     (Rom, Sda => Rom_Sda_Pin, Scl => Rom_Scl_Pin,
      A0 => Strap_A0, A1 => Strap_A1, A2 => Strap_A2);

   --  strap: the address the straps select, and a presence probe at it.
   Put ("[rom] address: 0x");
   Put_Hex (Unsigned_32 (EEPROM.Address (Rom)), 2);
   Put ("  ");
   if EEPROM.Is_Present (Rom) then
      Put_Line ("(M24C64 present)");
   else
      Put_Line ("(no ACK!)");
      Put_Line ("[rom] scanning all A2/A1/A0 straps:");
      Scan_Straps;
      loop
         delay until Clock + Idle_Park;
      end loop;
   end if;

   --  boot: read, increment, write back, read back.  A brand-new part reads
   --  0xFF, so the first run reports 0.
   EEPROM.Read_Byte (Rom, Boot_Count_Cell, Counter, Result);
   if Result /= EEPROM.OK then
      Fail ("boot-count read", Result);
   end if;
   if Counter = 16#FF# then
      Counter := 0;   --  erased cell: start counting
   end if;

   Counter := Counter + 1;
   EEPROM.Write_Byte (Rom, Boot_Count_Cell, Counter, Result);
   if Result /= EEPROM.OK then
      Fail ("boot-count write", Result);
   end if;

   EEPROM.Read_Byte (Rom, Boot_Count_Cell, Counter, Result);
   if Result /= EEPROM.OK then
      Fail ("boot-count verify", Result);
   end if;
   Put ("[rom] boot count: ");
   Put (Integer (Counter));
   Put_Line ("  (rises by one on every reset)");

   --  page: a 40-byte pattern at 0x0110 -- crosses a page boundary and a write
   --  segment.  Vary it with the boot count so a stale read-back cannot pass.
   for I in Pattern'Range loop
      Pattern (I) := Counter xor Bus.Byte ((16#5A# + I * 7) mod 256);
   end loop;

   EEPROM.Write (Rom, Pattern_Start, Pattern, Result);
   if Result /= EEPROM.OK then
      Fail ("pattern write", Result);
   end if;

   EEPROM.Read (Rom, Pattern_Start, Readback, Result);
   if Result /= EEPROM.OK then
      Fail ("pattern read", Result);
   end if;

   Put ("[rom] page-crossing write/read: ");
   Put_Line (if Readback = Pattern then "PASS" else "FAIL");

   --  dump: the head of what came back off the part.
   Put ("[rom] 0x");
   Put_Hex (Unsigned_32 (Pattern_Start), 4);
   Put (":");
   for I in 0 .. Dump_Length - 1 loop
      Put (' ');
      Put_Hex (Unsigned_32 (Readback (I)), 2);
   end loop;
   New_Line;

   Put_Line ("[rom] done.");

   loop
      delay until Clock + Idle_Park;
   end loop;
end Main;
