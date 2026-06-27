with System;
with Interfaces;               use Interfaces;
with Ada.Unchecked_Conversion;
with Ada.IO_Exceptions;

package body ESP32S3.Block_Dev.WL is

   SPB : constant := Sectors_Per_Block;        --  512-byte sectors per 4 KB block
   Cfg_Blocks : constant := 2;                 --  ping-pong config blocks

   --  Config record layout inside a 512-byte sector (little-endian).
   Magic   : constant Unsigned_32 := 16#57_4C_42_31#;   --  "WLB1"
   Version : constant Unsigned_16 := 1;
   Off_Magic    : constant := 0;
   Off_Version  : constant := 4;
   Off_SPB      : constant := 6;
   Off_Rate     : constant := 8;
   Off_D        : constant := 12;
   Off_L        : constant := 16;
   Off_Move     : constant := 20;
   Off_Access   : constant := 28;
   Off_Sequence : constant := 32;
   Off_CRC      : constant := 40;               --  CRC over bytes 0 .. 39

   type Volume_Access is access all Volume;
   function To_Volume is
     new Ada.Unchecked_Conversion (System.Address, Volume_Access);

   ----------------------------------------------------------------------------
   --  Little-endian field access + CRC-32 over a config sector
   ----------------------------------------------------------------------------

   procedure Put_U16 (S : in out Sector; Off : Natural; V : Unsigned_16) is
   begin
      S (Off)     := Unsigned_8 (V and 16#FF#);
      S (Off + 1) := Unsigned_8 (Shift_Right (V, 8) and 16#FF#);
   end Put_U16;

   procedure Put_U32 (S : in out Sector; Off : Natural; V : Unsigned_32) is
   begin
      for I in 0 .. 3 loop
         S (Off + I) := Unsigned_8 (Shift_Right (V, 8 * I) and 16#FF#);
      end loop;
   end Put_U32;

   procedure Put_U64 (S : in out Sector; Off : Natural; V : Unsigned_64) is
   begin
      for I in 0 .. 7 loop
         S (Off + I) := Unsigned_8 (Shift_Right (V, 8 * I) and 16#FF#);
      end loop;
   end Put_U64;

   function Get_U16 (S : Sector; Off : Natural) return Unsigned_16 is
     (Unsigned_16 (S (Off)) or Shift_Left (Unsigned_16 (S (Off + 1)), 8));

   function Get_U32 (S : Sector; Off : Natural) return Unsigned_32 is
      R : Unsigned_32 := 0;
   begin
      for I in 0 .. 3 loop
         R := R or Shift_Left (Unsigned_32 (S (Off + I)), 8 * I);
      end loop;
      return R;
   end Get_U32;

   function Get_U64 (S : Sector; Off : Natural) return Unsigned_64 is
      R : Unsigned_64 := 0;
   begin
      for I in 0 .. 7 loop
         R := R or Shift_Left (Unsigned_64 (S (Off + I)), 8 * I);
      end loop;
      return R;
   end Get_U64;

   --  CRC-32 (IEEE 802.3, reflected, poly 0xEDB88820) over S (0 .. Len - 1).
   function CRC32 (S : Sector; Len : Natural) return Unsigned_32 is
      C : Unsigned_32 := 16#FFFF_FFFF#;
   begin
      for I in 0 .. Len - 1 loop
         C := C xor Unsigned_32 (S (I));
         for K in 1 .. 8 loop
            if (C and 1) = 1 then
               C := Shift_Right (C, 1) xor 16#EDB8_8320#;
            else
               C := Shift_Right (C, 1);
            end if;
         end loop;
      end loop;
      return C xor 16#FFFF_FFFF#;
   end CRC32;

   ----------------------------------------------------------------------------
   --  Geometry / mapping
   ----------------------------------------------------------------------------

   --  Physical 512-byte sector of config copy Slot (0 or 1): sector 0 of the
   --  config block just past the data+spare region.
   function Cfg_Sector (V : Volume; Slot : Natural) return Sector_Index is
     (Sector_Index (V.Data_Blocks + Slot) * SPB);

   --  Map a logical 4 KB block (0 .. L-1) to its physical block (0 .. D-1):
   --     phys = (t + ((lb - t) mod L)) mod D
   --  computed with non-negative modular steps.  Never returns the hole.
   function Phys_Block (V : Volume; LB : Natural) return Natural is
      D     : constant Unsigned_64 := Unsigned_64 (V.Data_Blocks);
      L     : constant Unsigned_64 := Unsigned_64 (V.Logical);
      T_L   : constant Unsigned_64 := V.Move_Steps mod L;
      T_D   : constant Unsigned_64 := V.Move_Steps mod D;
      K     : constant Unsigned_64 := (Unsigned_64 (LB) + L - T_L) mod L;
   begin
      return Natural ((T_D + K) mod D);
   end Phys_Block;

   --  Physical sector for a logical sector.
   function Phys_Sector (V : Volume; LS : Sector_Index) return Sector_Index is
      LB  : constant Natural := Natural (LS / SPB);
      Off : constant Sector_Index := LS mod SPB;
   begin
      return Sector_Index (Phys_Block (V, LB)) * SPB + Off;
   end Phys_Sector;

   ----------------------------------------------------------------------------
   --  Config persistence
   ----------------------------------------------------------------------------

   --  Write the current state to the next ping-pong config slot (Sequence++).
   procedure Persist (V : in out Volume) is
      Rec  : Sector := (others => 0);
      Slot : Natural;
   begin
      V.Sequence := V.Sequence + 1;
      Slot := Natural (V.Sequence mod 2);
      Put_U32 (Rec, Off_Magic,    Magic);
      Put_U16 (Rec, Off_Version,  Version);
      Put_U16 (Rec, Off_SPB,      Unsigned_16 (SPB));
      Put_U32 (Rec, Off_Rate,     Unsigned_32 (V.Update_Rate));
      Put_U32 (Rec, Off_D,        Unsigned_32 (V.Data_Blocks));
      Put_U32 (Rec, Off_L,        Unsigned_32 (V.Logical));
      Put_U64 (Rec, Off_Move,     V.Move_Steps);
      Put_U32 (Rec, Off_Access,   Unsigned_32 (V.Access_Count));
      Put_U64 (Rec, Off_Sequence, V.Sequence);
      Put_U32 (Rec, Off_CRC,      CRC32 (Rec, Off_CRC));
      Write_Sector (V.Lower, Cfg_Sector (V, Slot), Rec);
   end Persist;

   --  Parse a config sector for THIS volume's geometry.  Returns its sequence in
   --  Seq and True if it is a valid record matching the attached geometry.
   function Parse (V : Volume; Rec : Sector; Seq : out Unsigned_64) return Boolean
   is
   begin
      Seq := 0;
      if Get_U32 (Rec, Off_Magic) /= Magic
        or else Get_U16 (Rec, Off_Version) /= Version
        or else Get_U16 (Rec, Off_SPB) /= Unsigned_16 (SPB)
        or else Get_U32 (Rec, Off_D) /= Unsigned_32 (V.Data_Blocks)
        or else Get_U32 (Rec, Off_L) /= Unsigned_32 (V.Logical)
        or else Get_U32 (Rec, Off_CRC) /= CRC32 (Rec, Off_CRC)
      then
         return False;
      end if;
      Seq := Get_U64 (Rec, Off_Sequence);
      return True;
   end Parse;

   ----------------------------------------------------------------------------
   --  The move
   ----------------------------------------------------------------------------

   --  Advance one step: copy the single block at src into the hole at dst, then
   --  commit the new Move_Steps.  Crash-safe: the source is untouched until the
   --  config commit, so an interrupted move is redone from the older config (see
   --  the package comment).
   procedure Do_Move (V : in out Volume) is
      D    : constant Unsigned_64 := Unsigned_64 (V.Data_Blocks);
      T    : constant Unsigned_64 := V.Move_Steps;
      Src  : constant Sector_Index := Sector_Index (T mod D) * SPB;
      Dst  : constant Sector_Index := Sector_Index ((T + D - 1) mod D) * SPB;
      Buf  : Sector;
   begin
      for Off in Sector_Index range 0 .. SPB - 1 loop
         Read_Sector  (V.Lower, Src + Off, Buf);
         Write_Sector (V.Lower, Dst + Off, Buf);
      end loop;
      V.Move_Steps := T + 1;          --  committed by the Persist that follows
   end Do_Move;

   ----------------------------------------------------------------------------
   --  Block_Dev vtable
   ----------------------------------------------------------------------------

   procedure Do_Read (Ctx : System.Address; LBA : Sector_Index; Data : out Sector)
   is
      V : constant Volume_Access := To_Volume (Ctx);
   begin
      if LBA >= Logical_Sectors (V.all) then
         raise Ada.IO_Exceptions.Device_Error with "WL: read LBA out of range";
      end if;
      Read_Sector (V.Lower, Phys_Sector (V.all, LBA), Data);
   end Do_Read;

   procedure Do_Write (Ctx : System.Address; LBA : Sector_Index; Data : Sector) is
      V : constant Volume_Access := To_Volume (Ctx);
   begin
      if LBA >= Logical_Sectors (V.all) then
         raise Ada.IO_Exceptions.Device_Error with "WL: write LBA out of range";
      end if;
      Write_Sector (V.Lower, Phys_Sector (V.all, LBA), Data);

      V.Access_Count := V.Access_Count + 1;
      if V.Access_Count >= V.Update_Rate then
         Do_Move (V.all);
         V.Access_Count := 0;
         Persist (V.all);             --  commits the move (highest valid seq wins)
      end if;
   end Do_Write;

   function Do_Count (Ctx : System.Address) return Sector_Index is
     (Logical_Sectors (To_Volume (Ctx).all));

   ----------------------------------------------------------------------------
   --  Public operations
   ----------------------------------------------------------------------------

   procedure Attach (V           : in out Volume;
                     Lower       : Device;
                     Update_Rate : Positive := 16)
   is
      Phys_Blocks : constant Sector_Index := Sector_Count (Lower) / SPB;
   begin
      if Phys_Blocks < Cfg_Blocks + 2 then
         raise Constraint_Error
           with "WL: medium too small (need >= 4 erase blocks)";
      end if;
      V.Lower        := Lower;
      V.Data_Blocks  := Natural (Phys_Blocks) - Cfg_Blocks;   --  D
      V.Logical      := V.Data_Blocks - 1;                    --  L = D - 1
      V.Update_Rate  := Update_Rate;
      V.Move_Steps   := 0;
      V.Access_Count := 0;
      V.Sequence     := 0;
      V.Mounted      := False;
   end Attach;

   procedure Mount (V : in out Volume; Formatted : out Boolean) is
      Rec  : Sector;
      Seq  : Unsigned_64;
      Best : Unsigned_64 := 0;
      Got  : Boolean := False;
   begin
      for Slot in 0 .. 1 loop
         Read_Sector (V.Lower, Cfg_Sector (V, Slot), Rec);
         if Parse (V, Rec, Seq) and then (not Got or else Seq > Best) then
            Best           := Seq;
            V.Move_Steps   := Get_U64 (Rec, Off_Move);
            V.Access_Count := Natural (Get_U32 (Rec, Off_Access));
            V.Sequence     := Seq;
            Got            := True;
         end if;
      end loop;
      V.Mounted := Got;
      Formatted := Got;
   end Mount;

   procedure Format (V : in out Volume) is
   begin
      V.Move_Steps   := 0;
      V.Access_Count := 0;
      V.Sequence     := 0;
      Persist (V);              --  first record, sequence 1
      V.Mounted := True;
   end Format;

   function Logical_Sectors (V : Volume) return Sector_Index is
     (Sector_Index (V.Logical) * SPB);

   function Move_Count (V : Volume) return Unsigned_64 is (V.Move_Steps);

   function Make (V : not null access Volume) return Device is
   begin
      return (Ctx   => V.all'Address,
              Read  => Do_Read'Access,
              Write => (if V.Lower.Write /= null then Do_Write'Access else null),
              Count => Do_Count'Access);
   end Make;

end ESP32S3.Block_Dev.WL;
