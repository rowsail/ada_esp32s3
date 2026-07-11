--  I2C FRAM driver demo on the bare-metal ESP32-S3 (no FreeRTOS, no IDF)
--  ====================================================================
--  What it demonstrates: the reusable HAL driver family ESP32S3.FRAM_I2C against
--  an I2C FRAM (here a Fujitsu MB85RC256V, 256 Kbit / 32 KiB) on the I2C bus.
--  FRAM differs from the 24C EEPROM in two ways the demo leans on:
--    id      Read_Device_ID -- FRAM reports its manufacturer/density/product over
--            the reserved-slave sequence, the self-report the 24C parts lack.
--    write   no page boundary and no program cycle, so a large pattern goes down
--            in one transaction with nothing to ACK-poll.
--  Plus the same non-volatile boot counter the EEPROM demo uses.
--
--  Build & run:  ./x run esp32s3_fram   (embedded profile -- controlled I2C Session)
--  Hardware:  one MB85RC256V (or any part in the catalogue -- change the `with`
--    and the rename) on I2C0: SDA = IO41, SCL = IO40, WP to GND to allow writes,
--    A0/A1/A2 to GND (address 0x50).  With no FRAM fitted the demo reports "no
--    ACK" and stops -- the driver code is exercised at compile time regardless.
with Ada.Real_Time; use Ada.Real_Time;
with Interfaces;    use Interfaces;

with ESP32S3.I2C;
with ESP32S3.FRAM_I2C.Kbit_256;
with ESP32S3.Log; use ESP32S3.Log;

--  Compiles every part instance in both FRAM families (I2C + SPI), so the whole
--  catalogue is build-checked, not just the one part this demo drives.
with Fram_Coverage;
pragma Warnings (Off, Fram_Coverage);

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   package FRAM renames ESP32S3.FRAM_I2C.Kbit_256;
   package Bus  renames ESP32S3.I2C;
   use type FRAM.Status;
   use type Bus.Byte;
   use type Bus.Byte_Array;

   Sda_Pin : constant := 41;   --  IO41 = I2C0 data
   Scl_Pin : constant := 40;   --  IO40 = I2C0 clock

   Console_Settle : constant Time_Span := Milliseconds (200);
   Idle_Park      : constant Time_Span := Seconds (3600);

   --  Non-volatile boot counter in the last cell.
   Boot_Cell : constant FRAM.Memory_Address := FRAM.Capacity - 1;

   --  A pattern that spans more than the 32-byte I2C FIFO in a single FRAM write
   --  (no page boundary, so this is one transaction).
   Pattern_Start  : constant FRAM.Memory_Address := 16#0100#;
   Pattern_Length : constant := 100;
   Dump_Length    : constant := 16;

   Ram      : FRAM.Device;
   Result   : FRAM.Status;
   Counter  : Bus.Byte;
   Pattern  : Bus.Byte_Array (0 .. Pattern_Length - 1);
   Readback : Bus.Byte_Array (0 .. Pattern_Length - 1) := (others => 0);

   procedure Park is
   begin
      loop delay until Clock + Idle_Park; end loop;
   end Park;

   procedure Fail (Step : String) is
   begin
      Put_Line ("[fram] " & Step & " failed: no ACK (check wiring/power/WP)");
      Park;
   end Fail;

begin
   delay until Clock + Console_Settle;
   Put_Line ("[fram] I2C FRAM driver demo -- Kbit_256 (SDA=IO41 SCL=IO40)");
   Put ("[fram] capacity: ");
   Put (Integer (FRAM.Capacity));
   Put_Line (" bytes");

   FRAM.Setup (Ram, Sda => Sda_Pin, Scl => Scl_Pin);

   Put ("[fram] address: 0x");
   Put_Hex (Unsigned_32 (FRAM.Address (Ram)), 2);
   Put ("  ");
   if FRAM.Is_Present (Ram) then
      Put_Line ("(FRAM present)");
   else
      Put_Line ("(no ACK -- no FRAM fitted?)");
      Park;
   end if;

   --  id: the self-report the EEPROM cannot do.
   declare
      ID : FRAM.Device_ID;
   begin
      FRAM.Read_Device_ID (Ram, ID, Result);
      if Result = FRAM.OK then
         Put ("[fram] device id: manufacturer 0x");
         Put_Hex (Unsigned_32 (ID.Manufacturer), 3);
         Put ("  density 0x");
         Put_Hex (Unsigned_32 (ID.Density), 1);
         Put ("  product 0x");
         Put_Hex (Unsigned_32 (ID.Product), 2);
         New_Line;
         if ID.Manufacturer = FRAM.Fujitsu_Manufacturer then
            Put_Line ("[fram]   -> Fujitsu");
         elsif ID.Manufacturer = FRAM.Cypress_Manufacturer then
            Put_Line ("[fram]   -> Cypress/Infineon");
         end if;
      else
         Put_Line ("[fram] device id: not reported");
      end if;
   end;

   --  identify (informational): which vendor answered the Device ID, if any.  The
   --  geometry is fixed at compile time by the Kbit_256 instance -- not verified.
   Put_Line ("[fram] vendor: " & FRAM.Vendor'Image (FRAM.Identify (Ram)));

   --  boot: read/increment/write-back the counter (fresh FRAM may hold anything).
   FRAM.Read_Byte (Ram, Boot_Cell, Counter, Result);
   if Result /= FRAM.OK then Fail ("boot-count read"); end if;
   Counter := Counter + 1;
   FRAM.Write_Byte (Ram, Boot_Cell, Counter, Result);
   if Result /= FRAM.OK then Fail ("boot-count write"); end if;
   Put ("[fram] boot count: ");
   Put (Integer (Counter));
   Put_Line ("  (rises by one on every reset)");

   --  write: a 100-byte pattern in one page-less transaction, then read back.
   for I in Pattern'Range loop
      Pattern (I) := Counter xor Bus.Byte ((16#5A# + I * 7) mod 256);
   end loop;
   FRAM.Write (Ram, Pattern_Start, Pattern, Result);
   if Result /= FRAM.OK then Fail ("pattern write"); end if;
   FRAM.Read (Ram, Pattern_Start, Readback, Result);
   if Result /= FRAM.OK then Fail ("pattern read"); end if;
   Put ("[fram] 100-byte write/read: ");
   Put_Line (if Readback = Pattern then "PASS" else "FAIL");

   Put ("[fram] 0x");
   Put_Hex (Unsigned_32 (Pattern_Start), 4);
   Put (":");
   for I in 0 .. Dump_Length - 1 loop
      Put (' ');
      Put_Hex (Unsigned_32 (Readback (I)), 2);
   end loop;
   New_Line;

   Put_Line ("[fram] done.");
   Park;
end Main;
