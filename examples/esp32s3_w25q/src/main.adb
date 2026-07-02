--  Winbond W25Q256FV SPI NOR flash bring-up on the bare-metal ESP32-S3
--  =================================================================
--  What it demonstrates
--    The reusable HAL driver ESP32S3.W25Q on a 32 MB Winbond flash that shares
--    SPI2 with the W5500 Ethernet chip.  The flash's chip select is its OWN
--    GPIO (IO21), driven through the SPI driver's application chip-select
--    callback (the W5500 keeps the host's hardware CS0 on IO39), so two devices
--    coexist on one bus.  The test:
--      1. reads the JEDEC ID and checks it is EF 40 19 (W25Q256FV),
--      2. enters 4-byte address mode (needed for a >16 MB part),
--      3. erases a 4 KB scratch sector and confirms it reads back all-0xFF,
--      4. page-programs a 16-byte pattern and reads it back, byte for byte,
--      5. wraps the flash as a 512-byte-sector Block_Dev and round-trips a full
--         sector twice -- the second write is the bit-complement of the first,
--         which forces the adapter's 4 KB erase read-modify-write path.
--
--  This ERASES + WRITES scratch areas (around 1 MB and 2 MB into the chip).
--  Safe here: the flash is dedicated to this experiment and holds no filesystem.
--
--  Build & run
--    ./x run esp32s3_w25q            --  embedded profile (build.sh sets it)
--    Report prints over USB-Serial-JTAG via ESP32S3.Log.
--
--  Output (with the flash wired)
--    [w25q] bare-metal Winbond SPI-NOR bring-up (SPI2, CS=IO21)
--    [w25q] JEDEC ID: ef 40 19   (W25Q256FV)  PASS
--    [w25q] 4-byte address mode: OK
--    [w25q] after erase: ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff   PASS
--    [w25q] read-back:  a5 5a f0 0f 11 22 33 44 55 66 77 88 99 aa bb cc   PASS
--    [w25q] blockdev write/read A: PASS
--    [w25q] blockdev rewrite B (erase RMW): PASS
--    [w25q] done.
--    With nothing wired it reads 00/FF and prints the JEDEC FAIL line, then stops.
--
--  Hardware
--    W25Q256FV on SPI2: SCLK=GPIO1  MOSI=GPIO4  MISO=GPIO45  CS=GPIO21
--    (3V3, GND; the bus is shared with the W5500, which is left unselected.)
with Interfaces;    use Interfaces;
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.SPI;
with ESP32S3.W25Q;
with ESP32S3.GPIO;
with ESP32S3.Log;
with ESP32S3.Block_Dev;
with ESP32S3.Block_Dev.W25Q_Source;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   package SPI renames ESP32S3.SPI;
   package W25Q renames ESP32S3.W25Q;
   package Log renames ESP32S3.Log;
   package BD renames ESP32S3.Block_Dev;
   package BDW renames ESP32S3.Block_Dev.W25Q_Source;
   use type W25Q.Byte_Array;
   use type BD.Sector;

   --  SPI2 bus pins (shared with the W5500); the flash select is its own GPIO.
   SCLK_Pin : constant := 1;
   MOSI_Pin : constant := 4;
   MISO_Pin : constant := 45;
   CS_Pin   : constant ESP32S3.GPIO.Pin_Id := 21;

   Clock_Hz : constant := 8_000_000;

   --  A scratch sector to erase/program/verify (1 MB in -- arbitrary, since this
   --  dedicated chip holds no filesystem yet).
   Scratch : constant W25Q.Address := 16#10_0000#;

   --  The flash device fully describes itself: SPI2, its own bit clock, and its
   --  chip select on IO21.  The SPI driver applies the clock and drives the CS
   --  GPIO (active-low, held across each command) at Acquire -- no callback.
   Dev : W25Q.Flash := (Host => SPI.SPI2, Clock_Hz => Clock_Hz, CS_Pin => CS_Pin, others => <>);

   ID        : W25Q.JEDEC_ID;
   Mode_OK   : Boolean;
   Pattern   : constant W25Q.Byte_Array (0 .. 15) :=
     (16#A5#,
      16#5A#,
      16#F0#,
      16#0F#,
      16#11#,
      16#22#,
      16#33#,
      16#44#,
      16#55#,
      16#66#,
      16#77#,
      16#88#,
      16#99#,
      16#AA#,
      16#BB#,
      16#CC#);
   Erased    : W25Q.Byte_Array (0 .. 15);
   Read_Back : W25Q.Byte_Array (0 .. 15);

   --  Block-device layer over the same flash (512-byte sectors).
   Capacity : constant W25Q.Address := 32 * 1024 * 1024;     --  W25Q256FV = 32 MB
   BD_LBA   : constant BD.Sector_Index := 16#1000#;          --  2 MB in
   Source   : aliased BDW.Source;
   Device   : BD.Device;
   Pat_A    : BD.Sector;                                     --  written first
   Pat_B    : BD.Sector;                                     --  bit-complement of A
   Got      : BD.Sector;

   procedure Put_Bytes (B : W25Q.Byte_Array) is
   begin
      for X of B loop
         Log.Put (' ');
         Log.Put_Hex (Unsigned_32 (X), 2);
      end loop;
   end Put_Bytes;

   function All_Erased (B : W25Q.Byte_Array) return Boolean is
   begin
      for X of B loop
         if X /= 16#FF# then
            return False;
         end if;
      end loop;
      return True;
   end All_Erased;
begin
   delay until Clock + Milliseconds (200);
   Log.Put_Line ("[w25q] bare-metal Winbond SPI-NOR bring-up (SPI2, CS=IO21)");

   SPI.Setup (SPI.SPI2);
   SPI.Configure_Pins (SPI.SPI2, Sclk => SCLK_Pin, Mosi => MOSI_Pin, Miso => MISO_Pin);

   W25Q.Read_Identification (Dev, ID);
   Log.Put ("[w25q] JEDEC ID:");
   Log.Put (' ');
   Log.Put_Hex (Unsigned_32 (ID.Manufacturer), 2);
   Log.Put (' ');
   Log.Put_Hex (Unsigned_32 (ID.Memory_Type), 2);
   Log.Put (' ');
   Log.Put_Hex (Unsigned_32 (ID.Capacity), 2);

   if ID.Manufacturer = 16#EF# and then ID.Memory_Type = 16#40# and then ID.Capacity = 16#19# then
      Log.Put_Line ("   (W25Q256FV)  PASS");

      W25Q.Initialize (Dev, Mode_OK);
      Log.Put_Line
        ((if Mode_OK
          then "[w25q] 4-byte address mode: OK"
          else "[w25q] 4-byte address mode: FAILED to set"));

      W25Q.Erase_Sector (Dev, Scratch);
      W25Q.Read (Dev, Scratch, Erased);
      Log.Put ("[w25q] after erase:");
      Put_Bytes (Erased);
      Log.Put_Line ((if All_Erased (Erased) then "   PASS" else "   FAIL"));

      W25Q.Program_Page (Dev, Scratch, Pattern);
      W25Q.Read (Dev, Scratch, Read_Back);
      Log.Put ("[w25q] read-back: ");
      Put_Bytes (Read_Back);
      Log.Put_Line ((if Read_Back = Pattern then "   PASS" else "   FAIL"));

      --  Block-device round-trip: present the flash as 512-byte sectors and
      --  exercise both write paths of the adapter -- first write (likely a clear-
      --  only program, or an erase RMW if the block was dirty), then a second
      --  write of the bit-complement, which always forces the 4 KB erase RMW.
      for I in Pat_A'Range loop
         Pat_A (I) := Unsigned_8 (I mod 256);
         Pat_B (I) := not Pat_A (I);
      end loop;
      BDW.Configure (Source, Flash => Dev, Capacity_Bytes => Capacity);
      Device := BDW.Make (Source'Access);

      BD.Write_Sector (Device, BD_LBA, Pat_A);
      BD.Read_Sector (Device, BD_LBA, Got);
      Log.Put_Line
        ((if Got = Pat_A
          then "[w25q] blockdev write/read A: PASS"
          else "[w25q] blockdev write/read A: FAIL"));

      BD.Write_Sector (Device, BD_LBA, Pat_B);    --  forces erase read-modify-write
      BD.Read_Sector (Device, BD_LBA, Got);
      Log.Put_Line
        ((if Got = Pat_B
          then "[w25q] blockdev rewrite B (erase RMW): PASS"
          else "[w25q] blockdev rewrite B (erase RMW): FAIL"));
   else
      Log.Put_Line ("   FAIL (expected EF 40 19 -- check wiring / CS on IO21)");
   end if;

   Log.Put_Line ("[w25q] done.");
   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
