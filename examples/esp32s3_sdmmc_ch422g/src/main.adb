--  What it demonstrates
--    Reading an SD card on the bare-metal ESP32-S3 on a board where the card's
--    DAT3/CD line is wired not to the SoC but to a CH422G I2C expander pin, so
--    two reusable HAL drivers work together:
--      * ESP32S3.CH422G drives the card's DAT3/CD high via its IO4 pin -- needed
--        so the card enters/stays in SD mode.  The CH422G's IO direction is
--        GLOBAL, so making IO4 an output turns the whole bank to outputs; we load
--        the output register (IO4 high, the rest low) BEFORE enabling outputs, so
--        DAT3 is already high the instant the bank switches to drive (no glitch).
--        DAT3 is set once and never toggled, so the slow I2C path is fine.
--      * ESP32S3.SDMMC then talks to the card in 1-bit mode (DAT1/2/3 not wired).
--    READ-ONLY: it identifies the card, decodes CID/CSD/SCR (maker, product,
--    serial, date, capacity, spec version, capabilities), negotiates High-Speed
--    (50 MHz), and reads block 0 (checking the 0x55AA boot signature) -- it never
--    writes, so no card content can be lost.
--
--  Build & run
--    ./x run esp32s3_sdmmc_ch422g   (embedded profile; build.sh sets it)
--
--  Output
--    The expander result, the card identity/capacity/capabilities, and the
--    block-0 boot-signature check, printed over the ROM esp_rom_printf glue.
--
--  Hardware
--    An SD card in the slot.  I2C0 to the CH422G on SDA=IO8 / SCL=IO9; SDMMC
--    1-bit bus on CLK=IO12, CMD=IO11, D0=IO13.
with Interfaces;    use Interfaces;
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.CH422G;
with ESP32S3.SDMMC;
with ESP32S3.Text_IO;   use ESP32S3.Text_IO;   --  buffered console (no rom-printf)

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   package CH422G renames ESP32S3.CH422G;
   package SDMMC  renames ESP32S3.SDMMC;
   use type CH422G.Status;
   use type SDMMC.Status;

   package Nat_IO is new Integer_IO (Natural);

   --  Decimal with no field padding (like C "%d"/"%u").
   procedure Put_Nat (V : Natural) is
   begin
      Nat_IO.Put (V, Width => 1);
   end Put_Nat;

   --  Bare lowercase hex, zero-padded to at least Min_Digits (like C "%0Nx"),
   --  extending left for further significant nibbles (Text_IO's Modular_IO only
   --  offers the Ada based-literal form "16#EF#", not a bare "ef").
   Hex_Digit : constant array (0 .. 15) of Character := "0123456789abcdef";
   procedure Put_Hex (V : Unsigned_64; Min_Digits : Positive := 1) is
      Buf   : String (1 .. 16);
      X     : Unsigned_64 := V;
      First : Natural := Buf'Last;   --  leftmost significant nibble (0 -> last one)
   begin
      for I in reverse Buf'Range loop
         Buf (I) := Hex_Digit (Natural (X and 16#F#));
         X := Shift_Right (X, 4);
      end loop;
      for I in Buf'Range loop        --  find the first non-zero nibble
         if Buf (I) /= '0' then First := I; exit; end if;
      end loop;
      if Buf'Last - First + 1 < Min_Digits then   --  but keep at least Min_Digits
         First := Buf'Last - Min_Digits + 1;
      end if;
      Put (Buf (First .. Buf'Last));
   end Put_Hex;

   --  Replace non-printable bytes (CID strings are ASCII, but be safe).
   function Clean (S : String) return String is
      Result : String := S;
   begin
      for I in Result'Range loop
         if Character'Pos (Result (I)) not in 32 .. 126 then
            Result (I) := '?';
         end if;
      end loop;
      return Result;
   end Clean;

   --  Console reporters, formerly esp_rom_printf natives in glue.c, now pure Ada
   --  over the buffered ESP32S3.Text_IO console.

   procedure Banner is
   begin
      Put_Line ("[sd] SD card via SDMMC 1-bit, DAT3/CD held high by CH422G IO4");
      Put_Line ("[sd]   SDMMC: CLK=IO12 CMD=IO11 D0=IO13   CH422G: I2C0 SDA=8 SCL=9");
   end Banner;

   procedure Report_Exio (Ok : Boolean) is
   begin
      Put_Line ("[sd] CH422G IO bank -> 0x10 (DAT3 high) : "
                & (if Ok then "OK" else "I2C error"));
   end Report_Exio;

   procedure Report_Init (Status : SDMMC.Status; Kind : SDMMC.Card_Kind) is
   begin
      Put ("[sd] init: ");
      Put (SDMMC.Status'Image (Status));
      Put ("   card: ");
      Put_Line (case Kind is
                   when SDMMC.Unknown => "Unknown",
                   when SDMMC.SDSC    => "SDSC",
                   when SDMMC.SDHC    => "SDHC/SDXC");
   end Report_Init;

   procedure Report_Id (Id : SDMMC.Card_Id) is
   begin
      Put ("[sd] CID: mfr=0x");    Put_Hex (Unsigned_64 (Id.Manufacturer));
      Put ("  oem=");              Put (Clean (Id.OEM));
      Put ("  name=");             Put (Clean (Id.Product));
      Put ("  rev ");              Put_Nat (Id.Revision_Major);
      Put (".");                   Put_Nat (Id.Revision_Minor);
      New_Line;
      Put ("[sd]      serial=0x"); Put_Hex (Unsigned_64 (Id.Serial));
      Put ("  manufactured ");     Put_Nat (Id.Mfg_Year);
      Put ("-");                   Put_Nat (Id.Mfg_Month);
      New_Line;
   end Report_Id;

   procedure Report_Cap (Mb : Natural) is
   begin
      Put ("[sd] capacity: ");  Put_Nat (Mb);
      Put (" MB  (~");          Put_Nat (Mb / 1024);
      Put (".");                Put_Nat ((Mb mod 1024) * 10 / 1024);
      Put_Line (" GB)");
   end Report_Cap;

   procedure Report_Caps (Caps : SDMMC.Card_Caps) is
   begin
      Put ("[sd] caps: spec ");  Put_Nat (Caps.Spec_Major);
      Put (".");                 Put_Nat (Caps.Spec_Minor);
      Put ("  default-speed max ");  Put_Nat (Caps.Max_Speed_MHz);
      Put (" MHz  High-Speed ");  Put (if Caps.High_Speed then "yes" else "no");
      Put ("  4-bit ");           Put (if Caps.Supports_4bit then "yes" else "no");
      New_Line;
      Put ("[sd]        cmd-classes 0x");
      Put_Hex (Unsigned_64 (Caps.Command_Classes) and 16#FFF#);
      Put ("  read-block ");     Put_Nat (Caps.Read_Block_Len);
      Put_Line (" B");
   end Report_Caps;

   procedure Report_Speed (Active_Mhz : Natural; Hs_Active : Boolean) is
   begin
      Put ("[sd] running: ");  Put_Nat (Active_Mhz);
      Put (" MHz  (High Speed ");  Put (if Hs_Active then "ON" else "off");
      Put_Line (")");
   end Report_Speed;

   procedure Report_Read (Status : SDMMC.Status; B : SDMMC.Block; Sig_OK : Boolean)
   is
   begin
      if Status /= SDMMC.OK then
         Put_Line ("[sd] read block 0: " & SDMMC.Status'Image (Status));
         return;
      end if;
      Put ("[sd] read block 0: OK   first bytes = ");
      Put_Hex (Unsigned_64 (B (0)), 2);  Put (" ");
      Put_Hex (Unsigned_64 (B (1)), 2);  Put (" ");
      Put_Hex (Unsigned_64 (B (2)), 2);  Put (" ");
      Put_Hex (Unsigned_64 (B (3)), 2);
      Put_Line ("   boot sig 0x55AA: " & (if Sig_OK then "present" else "absent"));
   end Report_Read;

   procedure Done is
   begin
      Put_Line ("[sd] done.");
   end Done;

   --  The CH422G I2C expander that drives the card's DAT3/CD line.
   Expander         : CH422G.Device;
   Expander_Session : CH422G.Session;
   Expander_Status  : CH422G.Status;

   --  The SD card and a scratch block for the boot-sector read.
   Card        : SDMMC.Card;
   Card_Status : SDMMC.Status;
   Block       : SDMMC.Block;
begin
   delay until Clock + Milliseconds (200);
   Banner;

   --  1) CH422G: drive DAT3/CD (IO4) high.  Load the IO output register first
   --     (IO4=1, all other IO low), THEN enable outputs, so DAT3 never glitches
   --     low.  The Session is held for the whole run (the output latches anyway).
   CH422G.Setup (Expander, Sda => 8, Scl => 9);
   CH422G.Acquire (Expander_Session, Expander);
   CH422G.Write_IO (Expander_Session, 16#10#, Expander_Status);   --  IO4 high, rest low
   if Expander_Status = CH422G.OK then
      CH422G.Configure (Expander_Session,
                        IO_Dir => CH422G.Outputs, OC_Mode => CH422G.Push_Pull,
                        Result => Expander_Status);   --  enable outputs -> DAT3 high
   end if;
   Report_Exio (Expander_Status = CH422G.OK);

   --  2) SDMMC: 1-bit bus on CLK=IO12, CMD=IO11, D0=IO13 (D1/D2/D3 not wired).
   SDMMC.Setup (Card, On => SDMMC.Slot1, Clk => 12, Cmd => 11, D0 => 13,
                Width => SDMMC.Width_1,
                Init_Clock_Hz => 400_000, Data_Clock_Hz => 50_000_000,
                High_Speed => True);   --  negotiate the fastest the card allows

   SDMMC.Initialize (Card, Card_Status);
   Report_Init (Card_Status, SDMMC.Kind (Card));

   --  Decoded identity (CID) + capacity (CSD).
   if Card_Status = SDMMC.OK then
      declare
         Id   : constant SDMMC.Card_Id := SDMMC.Identity (Card);
         Cap  : constant Interfaces.Unsigned_64 := SDMMC.Capacity_Blocks (Card);
         Caps : constant SDMMC.Card_Caps := SDMMC.Capabilities (Card);
      begin
         Report_Id (Id);
         Report_Cap (Natural (Cap / 2048));    --  blocks -> MB
         Report_Caps (Caps);
         Report_Speed (Natural (SDMMC.Active_Clock_Hz (Card) / 1_000_000),
                       SDMMC.High_Speed_Active (Card));
      end;
   end if;

   --  3) Read block 0 and check the boot signature (read-only).
   if Card_Status = SDMMC.OK then
      SDMMC.Read_Block (Card, 0, Block, Card_Status);
      Report_Read (Card_Status, Block,
                   Sig_OK => Card_Status = SDMMC.OK
                             and then Block (510) = 16#55#
                             and then Block (511) = 16#AA#);
   end if;

   Done;

   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
