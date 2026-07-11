with Ada.Text_IO; use Ada.Text_IO;
with Interfaces;   use Interfaces;
with Ada.Unchecked_Conversion;

--  Native equivalence check for the register bit-field records introduced in the
--  drivers (Stage 5 of the "de-C-ify" cleanup).  Each record + representation
--  clause here mirrors the one in the driver body; we prove -- exhaustively over
--  the input space -- that the record encodes bit-for-bit the same value the old
--  hand arithmetic produced.  If a bit position is ever wrong, this fails HERE
--  (natively) instead of silently misbehaving on the board.
procedure Repcheck is
   Fails : Natural := 0;

   ------------------------------------------------------------------
   --  ESP32S3.I2C.Engine  --  COMD command word (UInt14)
   --  byte_num[0..7] ack_check[8] ack_exp[9] ack_val[10] op[11..13]
   ------------------------------------------------------------------
   --  Mirror the driver exactly: 14-bit record, all bits defined (no padding
   --  holes), converted to a 14-bit modular type -- so the check is bit-faithful.
   type U14 is mod 2 ** 14;
   type I2C_Op is mod 2 ** 3;
   type I2C_Cmd is record
      Byte_Num  : Unsigned_8;
      Ack_Check : Boolean;
      Ack_Exp   : Boolean;
      Ack_Val   : Boolean;
      Op        : I2C_Op;
   end record;
   for I2C_Cmd use record
      Byte_Num  at 0 range 0 .. 7;
      Ack_Check at 0 range 8 .. 8;
      Ack_Exp   at 0 range 9 .. 9;
      Ack_Val   at 0 range 10 .. 10;
      Op        at 0 range 11 .. 13;
   end record;
   for I2C_Cmd'Size use 14;
   function UC_Raw is new Ada.Unchecked_Conversion (I2C_Cmd, U14);
   function UC_I2C (C : I2C_Cmd) return Unsigned_16 is (Unsigned_16 (UC_Raw (C)));

   function I2C_Old (Op, Bytes : Natural; AC, AE, AV : Boolean) return Unsigned_16 is
     (Unsigned_16 (Bytes)
      + (if AC then 2 ** 8  else 0)
      + (if AE then 2 ** 9  else 0)
      + (if AV then 2 ** 10 else 0)
      + Unsigned_16 (Op) * 2 ** 11);

   procedure Check_I2C is
   begin
      for Op in 0 .. 7 loop
         for Bytes in 0 .. 255 loop
            for AC in Boolean loop
               for AE in Boolean loop
                  for AV in Boolean loop
                     if UC_I2C ((Unsigned_8 (Bytes), AC, AE, AV, I2C_Op (Op)))
                        /= I2C_Old (Op, Bytes, AC, AE, AV)
                     then
                        Fails := Fails + 1;
                     end if;
                  end loop;
               end loop;
            end loop;
         end loop;
      end loop;
      Put_Line ("  i2c COMD word ......... "
                & (if Fails = 0 then "PASS (16384 cases)" else "FAIL"));
   end Check_I2C;

   ------------------------------------------------------------------
   --  ESP32S3.TWAI.Engine  --  CAN frame-info byte
   --  DLC[0..3] reserved[4..5]=0 RTR[6]=remote FF[7]=extended
   ------------------------------------------------------------------
   type DLC4  is mod 2 ** 4;
   type Rsvd2 is mod 2 ** 2;
   type TWAI_Info is record
      Length   : DLC4;
      Reserved : Rsvd2;
      Remote   : Boolean;
      Extended : Boolean;
   end record;
   for TWAI_Info use record
      Length   at 0 range 0 .. 3;
      Reserved at 0 range 4 .. 5;
      Remote   at 0 range 6 .. 6;
      Extended at 0 range 7 .. 7;
   end record;
   for TWAI_Info'Size use 8;
   function UC_TWAI  is new Ada.Unchecked_Conversion (TWAI_Info, Unsigned_8);
   function UC_TWAIr is new Ada.Unchecked_Conversion (Unsigned_8, TWAI_Info);

   function TWAI_Old (Ext, Rmt : Boolean; Len : Natural) return Unsigned_8 is
     ((if Ext then 16#80# else 0) or (if Rmt then 16#40# else 0)
      or Unsigned_8 (Len));

   procedure Check_TWAI is
      Build_Fail, Parse_Fail : Natural := 0;
   begin
      --  Build direction: record -> byte matches the old OR of masks.
      for Ext in Boolean loop
         for Rmt in Boolean loop
            for Len in 0 .. 8 loop        --  Data_Length range
               if UC_TWAI ((DLC4 (Len), 0, Rmt, Ext))
                  /= TWAI_Old (Ext, Rmt, Len)
               then
                  Build_Fail := Build_Fail + 1;
               end if;
            end loop;
         end loop;
      end loop;
      --  Parse direction: byte -> record fields match the old mask tests, for
      --  every possible received byte (0 .. 255).
      for B in 0 .. 255 loop
         declare
            R : constant TWAI_Info := UC_TWAIr (Unsigned_8 (B));
         begin
            if R.Extended /= ((Unsigned_8 (B) and 16#80#) /= 0)
              or else R.Remote /= ((Unsigned_8 (B) and 16#40#) /= 0)
              or else Natural (R.Length) /= Natural (Unsigned_8 (B) and 16#0F#)
            then
               Parse_Fail := Parse_Fail + 1;
            end if;
         end;
      end loop;
      Fails := Fails + Build_Fail + Parse_Fail;
      Put_Line ("  twai frame-info build . "
                & (if Build_Fail = 0 then "PASS (18 cases)" else "FAIL"));
      Put_Line ("  twai frame-info parse . "
                & (if Parse_Fail = 0 then "PASS (256 cases)" else "FAIL"));
   end Check_TWAI;

   ------------------------------------------------------------------
   --  ESP32S3.W5500  --  SPI control byte
   --  OM[0..1]=0 (VDM)  RWB[2]=write  BSB[3..7]=block select
   ------------------------------------------------------------------
   type OM2  is mod 2 ** 2;
   type BSB5 is mod 2 ** 5;
   type W5500_Ctrl is record
      OM  : OM2;
      RWB : Boolean;
      BSB : BSB5;
   end record;
   for W5500_Ctrl use record
      OM  at 0 range 0 .. 1;
      RWB at 0 range 2 .. 2;
      BSB at 0 range 3 .. 7;
   end record;
   for W5500_Ctrl'Size use 8;
   function UC_W5500 is new Ada.Unchecked_Conversion (W5500_Ctrl, Unsigned_8);

   function W5500_Old (Blk : Natural; Write : Boolean) return Unsigned_8 is
     (Unsigned_8 (Blk) * 8 + (if Write then 4 else 0));

   procedure Check_W5500 is
      F : Natural := 0;
   begin
      for Blk in 0 .. 31 loop
         for Write in Boolean loop
            if UC_W5500 ((0, Write, BSB5 (Blk))) /= W5500_Old (Blk, Write) then
               F := F + 1;
            end if;
         end loop;
      end loop;
      Fails := Fails + F;
      Put_Line ("  w5500 control byte .... "
                & (if F = 0 then "PASS (64 cases)" else "FAIL"));
   end Check_W5500;

   ------------------------------------------------------------------
   --  ESP32S3.W5500.Sockets  --  IPv4 -> multicast MAC (Open_UDP_Multicast)
   --  01:00:5E : (octet1 and 0x7F) : octet2 : octet3.  Checked against the
   --  STANDARD mappings (a known-answer test, not a re-derivation): this catches
   --  masking the wrong octet or the wrong bit.
   ------------------------------------------------------------------
   type Octet is mod 2 ** 8;
   type Mac6  is array (0 .. 5) of Octet;

   --  The driver's derivation, mirrored.
   function Mcast_Mac (O0, O1, O2, O3 : Octet) return Mac6 is
     (16#01#, 16#00#, 16#5E#, O1 and 16#7F#, O2, O3);

   procedure Check_W5500_Mcast is
      F : Natural := 0;
      procedure Expect (O0, O1, O2, O3 : Octet; M : Mac6) is
      begin
         if Mcast_Mac (O0, O1, O2, O3) /= M then
            F := F + 1;
         end if;
      end Expect;
   begin
      --  224.0.0.1 (all-hosts), 224.0.0.251 (mDNS), 239.255.255.250 (SSDP),
      --  and a case where the second-octet high bit must be dropped (233.130..).
      Expect (224, 0,   0,   1,   (16#01#, 16#00#, 16#5E#, 16#00#, 16#00#, 16#01#));
      Expect (224, 0,   0,   251, (16#01#, 16#00#, 16#5E#, 16#00#, 16#00#, 16#FB#));
      Expect (239, 255, 255, 250, (16#01#, 16#00#, 16#5E#, 16#7F#, 16#FF#, 16#FA#));
      Expect (233, 130, 1,   2,   (16#01#, 16#00#, 16#5E#, 16#02#, 16#01#, 16#02#));
      Fails := Fails + F;
      Put_Line ("  w5500 multicast MAC ... "
                & (if F = 0 then "PASS (4 cases)" else "FAIL"));
   end Check_W5500_Mcast;

   ------------------------------------------------------------------
   --  ESP32S3.PCNT  --  16-bit counter sign extension
   ------------------------------------------------------------------
   function To_S16 is new Ada.Unchecked_Conversion (Unsigned_16, Integer_16);

   function PCNT_Old (Raw : Natural) return Integer is
     (if Raw >= 32_768 then Raw - 65_536 else Raw);

   procedure Check_PCNT is
      F : Natural := 0;
   begin
      for Raw in 0 .. 65_535 loop
         if Integer (To_S16 (Unsigned_16 (Raw))) /= PCNT_Old (Raw) then
            F := F + 1;
         end if;
      end loop;
      Fails := Fails + F;
      Put_Line ("  pcnt sign extension ... "
                & (if F = 0 then "PASS (65536 cases)" else "FAIL"));
   end Check_PCNT;

   ------------------------------------------------------------------
   --  ESP32S3.SDMMC  --  RINTSTS read overlay (named-field view of the
   --  DesignWare raw-interrupt-status register) vs the old bit masks.
   ------------------------------------------------------------------
   type RINTSTS_Bits is record
      Resp_Err, Cmd_Done, Data_Over, RCRC, DCRC,
      RTO, DRTO, HTO, FRUN, EBE : Boolean;
   end record;
   for RINTSTS_Bits use record
      Resp_Err  at 0 range  1 ..  1;
      Cmd_Done  at 0 range  2 ..  2;
      Data_Over at 0 range  3 ..  3;
      RCRC      at 0 range  6 ..  6;
      DCRC      at 0 range  7 ..  7;
      RTO       at 0 range  8 ..  8;
      DRTO      at 0 range  9 ..  9;
      HTO       at 0 range 10 .. 10;
      FRUN      at 0 range 11 .. 11;
      EBE       at 0 range 15 .. 15;
   end record;
   for RINTSTS_Bits'Size use 32;
   function To_RINT is new Ada.Unchecked_Conversion (Unsigned_32, RINTSTS_Bits);

   procedure Check_RINTSTS is
      F : Natural := 0;
      function Bit (W : Natural; M : Unsigned_32) return Boolean is
        ((Unsigned_32 (W) and M) /= 0);
   begin
      --  Every RINTSTS bit lives in the low 16, so all patterns are exhausted.
      for W in 0 .. 65535 loop
         declare
            B : constant RINTSTS_Bits := To_RINT (Unsigned_32 (W));
         begin
            if B.Resp_Err  /= Bit (W, 16#0002#) or else
               B.Cmd_Done  /= Bit (W, 16#0004#) or else
               B.Data_Over /= Bit (W, 16#0008#) or else
               B.RCRC      /= Bit (W, 16#0040#) or else
               B.DCRC      /= Bit (W, 16#0080#) or else
               B.RTO       /= Bit (W, 16#0100#) or else
               B.DRTO      /= Bit (W, 16#0200#) or else
               B.HTO       /= Bit (W, 16#0400#) or else
               B.FRUN      /= Bit (W, 16#0800#) or else
               B.EBE       /= Bit (W, 16#8000#)
            then
               F := F + 1;
            end if;
         end;
      end loop;
      Fails := Fails + F;
      Put_Line ("  sdmmc RINTSTS overlay . "
                & (if F = 0 then "PASS (65536 cases)" else "FAIL"));
   end Check_RINTSTS;

begin
   Put_Line ("Register bit-field rep-clause equivalence check:");
   Check_I2C;
   Check_RINTSTS;
   Check_TWAI;
   Check_W5500;
   Check_W5500_Mcast;
   Check_PCNT;
   if Fails = 0 then
      Put_Line ("All rep-clause encoders match the old arithmetic.");
   else
      Put_Line ("FAILURES:" & Fails'Image);
   end if;
end Repcheck;
