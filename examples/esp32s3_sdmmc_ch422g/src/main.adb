--  SD card on the bare-metal ESP32-S3 (no FreeRTOS, no IDF), on a board where
--  the SD card's DAT3/CD line is not wired to the SoC but to a CH422G I2C
--  expander pin.  Two reusable HAL drivers together:
--
--    * ESP32S3.CH422G (I2C0, SDA=IO8 SCL=IO9) drives the card's DAT3/CD high via
--      its IO4 pin -- needed so the card enters/stays in SD mode and is enabled.
--      The CH422G's IO direction is GLOBAL, so to make IO4 an output the whole
--      IO bank becomes outputs; we drive IO4 high and every other IO pin low.
--      We load the output register BEFORE enabling outputs, so DAT3 is already
--      high the instant the bank switches to outputs (no glitch).  DAT3 is set
--      once and never toggled during transfers, so the slow I2C path is fine.
--
--    * ESP32S3.SDMMC then talks to the card in 1-bit mode on CLK=IO12, CMD=IO11,
--      D0=IO13 (DAT1/2/3 not wired to the SoC).
--
--  READ-ONLY on the card: it identifies the card, decodes its CID/CSD/SCR
--  (maker, product, serial, date, capacity, spec version, capabilities),
--  negotiates High-Speed mode (50 MHz), and reads block 0 (checking the 0x55AA
--  boot signature) -- it never writes, so no card content can be lost.
with System;
with Interfaces;   use Interfaces;
with Interfaces.C; use Interfaces.C;
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.CH422G;
with ESP32S3.SDMMC;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   package CH renames ESP32S3.CH422G;
   package SD renames ESP32S3.SDMMC;
   use type CH.Status;
   use type SD.Status;

   procedure Banner;  pragma Import (C, Banner, "native_sd_banner");
   procedure Exio_R (Ok : int);  pragma Import (C, Exio_R, "native_sd_exio");
   procedure Init_R (Status, Kind : int);
                     pragma Import (C, Init_R, "native_sd_init");
   procedure Read_R (Status, B0, B1, B2, B3, Sig_Ok : int);
                     pragma Import (C, Read_R, "native_sd_read");
   procedure Id_C (Mid : int; Oem, Pnm : System.Address;
                   Rmaj, Rmin : int; Serial : unsigned; Year, Month : int);
                     pragma Import (C, Id_C, "native_sd_id");
   procedure Cap_C (Mb : unsigned);  pragma Import (C, Cap_C, "native_sd_cap");
   procedure Caps_C (Max_Mhz : int; Ccc : unsigned; Rbl : int;
                     Spec_Maj, Spec_Min, Bus4, Hs : int);
                     pragma Import (C, Caps_C, "native_sd_caps");
   procedure Speed_C (Active_Mhz, Hs_Active : int);
                     pragma Import (C, Speed_C, "native_sd_speed");
   procedure Done;  pragma Import (C, Done, "native_sd_done");

   --  Replace non-printable bytes (CID strings are ASCII, but be safe).
   function Clean (S : String) return String is
      R : String := S;
   begin
      for I in R'Range loop
         if Character'Pos (R (I)) not in 32 .. 126 then
            R (I) := '?';
         end if;
      end loop;
      return R;
   end Clean;

   Dev : CH.Device;
   ExS : CH.Session;
   ESt : CH.Status;

   C   : SD.Card;
   St  : SD.Status;
   Blk : SD.Block;
begin
   delay until Clock + Milliseconds (200);
   Banner;

   --  1) CH422G: drive DAT3/CD (IO4) high.  Load the IO output register first
   --     (IO4=1, all other IO low), THEN enable outputs, so DAT3 never glitches
   --     low.  The Session is held for the whole run (the output latches anyway).
   CH.Setup (Dev, Sda => 8, Scl => 9);
   CH.Acquire (ExS, Dev);
   CH.Write_IO (ExS, 16#10#, ESt);                 --  IO4 high, IO0-3/5-7 low
   if ESt = CH.OK then
      CH.Configure (ExS, IO_Dir => CH.Outputs, OC_Mode => CH.Push_Pull,
                    Result => ESt);                --  enable outputs -> DAT3 high
   end if;
   Exio_R (Boolean'Pos (ESt = CH.OK));

   --  2) SDMMC: 1-bit bus on CLK=IO12, CMD=IO11, D0=IO13 (D1/D2/D3 not wired).
   SD.Setup (C, On => SD.Slot1, Clk => 12, Cmd => 11, D0 => 13,
             Width => SD.Width_1,
             Init_Clock_Hz => 400_000, Data_Clock_Hz => 50_000_000,
             High_Speed => True);   --  negotiate the fastest the card allows

   SD.Initialize (C, St);
   Init_R (int (SD.Status'Pos (St)), int (SD.Card_Kind'Pos (SD.Kind (C))));

   --  Decoded identity (CID) + capacity (CSD).
   if St = SD.OK then
      declare
         Id   : constant SD.Card_Id := SD.Identity (C);
         Cap  : constant Interfaces.Unsigned_64 := SD.Capacity_Blocks (C);
         Caps : constant SD.Card_Caps := SD.Capabilities (C);
         Oem  : aliased constant String := Clean (Id.OEM) & Character'Val (0);
         Pnm  : aliased constant String := Clean (Id.Product) & Character'Val (0);
      begin
         Id_C (int (Id.Manufacturer), Oem'Address, Pnm'Address,
               int (Id.Revision_Major), int (Id.Revision_Minor),
               unsigned (Id.Serial), int (Id.Mfg_Year), int (Id.Mfg_Month));
         Cap_C (unsigned (Cap / 2048));     --  blocks -> MB
         Caps_C (int (Caps.Max_Speed_MHz), unsigned (Caps.Command_Classes),
                 int (Caps.Read_Block_Len), int (Caps.Spec_Major),
                 int (Caps.Spec_Minor), Boolean'Pos (Caps.Supports_4bit),
                 Boolean'Pos (Caps.High_Speed));
         Speed_C (int (SD.Active_Clock_Hz (C) / 1_000_000),
                  Boolean'Pos (SD.High_Speed_Active (C)));
      end;
   end if;

   --  3) Read block 0 and check the boot signature (read-only).
   if St = SD.OK then
      SD.Read_Block (C, 0, Blk, St);
      Read_R (int (SD.Status'Pos (St)),
              int (Blk (0)), int (Blk (1)), int (Blk (2)), int (Blk (3)),
              Boolean'Pos (St = SD.OK
                           and then Blk (510) = 16#55# and then Blk (511) = 16#AA#));
   end if;

   Done;

   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
