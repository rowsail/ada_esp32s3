package body ESP32S3.AES.GCM is

   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_64;

   subtype Blk is ESP32S3.AES.Block;            --  16-byte block

   function AES_E (Key : Key_Bytes; B : Blk) return Blk
   is (ESP32S3.AES.Encrypt_ECB (Key, B));

   ---------------------------------------------------------------------------
   --  GHASH: multiplication in GF(2^128), reduction poly x^128+x^7+x^2+x+1
   --  (NIST SP 800-38D, the bit-by-bit "shift-right" algorithm).
   ---------------------------------------------------------------------------

   function GF_Mul (X, H : Blk) return Blk with SPARK_Mode => On is
      Z   : Blk := (others => 0);   --  spec Z: the running GF(2^128) product
      V   : Blk := H;               --  spec V: H shifted right one bit per step
      Lsb : U8;                     --  bit shifted out of V this step
   begin
      for I in 0 .. 127 loop
         --  Branchless: derive a 0x00/0xFF mask from bit i of X (MSB first) and
         --  conditionally XOR via the mask, rather than an `if bit then ...`.  The
         --  bits here come from the secret hash subkey H, so a data-dependent
         --  branch (or a conditional reduction below) leaks it through timing.
         declare
            B1   : constant U8 :=
              Interfaces.Shift_Right (X (I / 8), 7 - (I mod 8)) and 1;
            Mask : constant U8 := U8'(0) - B1;         --  0 -> 0x00, 1 -> 0xFF
         begin
            for J in Blk'Range loop
               Z (J) := Z (J) xor (V (J) and Mask);
            end loop;
         end;
         --  V := V >> 1 (across the 16 bytes, big-endian), then reduce if a 1 fell out
         Lsb := V (15) and 1;
         for J in reverse 1 .. 15 loop
            V (J) :=
              Interfaces.Shift_Right (V (J), 1) or Interfaces.Shift_Left (V (J - 1) and 1, 7);
         end loop;
         V (0) := Interfaces.Shift_Right (V (0), 1);
         V (0) := V (0) xor (16#E1# and (U8'(0) - Lsb));   --  reduce iff a 1 fell out
      end loop;
      return Z;
   end GF_Mul;

   --  Y := (Y xor B) * H
   procedure GHASH_Block (Y : in out Blk; B : Blk; H : Blk) with SPARK_Mode => On is
   begin
      for J in Blk'Range loop
         Y (J) := Y (J) xor B (J);
      end loop;
      Y := GF_Mul (Y, H);
   end GHASH_Block;

   --  Fold Data into Y in 16-byte blocks, zero-padding any final partial block.
   procedure GHASH_Bytes (Y : in out Blk; Data : Byte_Array; H : Blk)
     with SPARK_Mode => On, Pre => Data'Length <= 2 ** 24
   is
      Off : Natural := 0;
      B   : Blk;
   begin
      while Off < Data'Length loop
         B := (others => 0);
         for J in 0 .. Natural'Min (15, Data'Length - Off - 1) loop
            B (J) := Data (Data'First + Off + J);
         end loop;
         GHASH_Block (Y, B, H);
         Off := Off + 16;
      end loop;
   end GHASH_Bytes;

   --  The trailing length block: bit-lengths of AAD and ciphertext, 64-bit BE each.
   procedure GHASH_Lengths (Y : in out Blk; AAD_Len, C_Len : Natural; H : Blk)
     with SPARK_Mode => On
   is
      L      : Blk := (others => 0);
      A_Bits : constant Interfaces.Unsigned_64 := Interfaces.Unsigned_64 (AAD_Len) * 8;
      C_Bits : constant Interfaces.Unsigned_64 := Interfaces.Unsigned_64 (C_Len) * 8;
   begin
      for J in 0 .. 7 loop
         L (7 - J) := U8 (Interfaces.Shift_Right (A_Bits, 8 * J) and 16#FF#);
         L (15 - J) := U8 (Interfaces.Shift_Right (C_Bits, 8 * J) and 16#FF#);
      end loop;
      GHASH_Block (Y, L, H);
   end GHASH_Lengths;

   ---------------------------------------------------------------------------
   --  Counter mode
   ---------------------------------------------------------------------------

   --  Increment the low 32 bits (bytes 12..15, big-endian) of a counter block.
   procedure Inc32 (CB : in out Blk) with SPARK_Mode => On is
   begin
      for J in reverse 12 .. 15 loop
         CB (J) := CB (J) + 1;
         exit when CB (J) /= 0;
      end loop;
   end Inc32;

   --  Cipher := Plain xor AES-CTR keystream starting at inc32 (J0).
   procedure CTR (Key : Key_Bytes; J0 : Blk; Src : Byte_Array; Dst : out Byte_Array) is
      CB  : Blk := J0;   --  spec CB: the running counter block
      KS  : Blk;         --  spec KS: the AES keystream block for CB
      Off : Natural := 0;
   begin
      while Off < Src'Length loop
         Inc32 (CB);
         KS := AES_E (Key, CB);
         for J in 0 .. Natural'Min (15, Src'Length - Off - 1) loop
            Dst (Dst'First + Off + J) := Src (Src'First + Off + J) xor KS (J);
         end loop;
         Off := Off + 16;
      end loop;
   end CTR;

   --  Build the GCM hash subkey H and pre-counter J0 (96-bit IV => IV||0^31||1).
   procedure Setup (Key : Key_Bytes; IV : Nonce; H, J0, E_J0 : out Blk) is
   begin
      H := AES_E (Key, Blk'(others => 0));
      J0 := (others => 0);
      for J in 0 .. 11 loop
         J0 (J) := IV (IV'First + J);
      end loop;
      J0 (15) := 1;
      E_J0 := AES_E (Key, J0);
   end Setup;

   ---------------------------------------------------------------------------
   --  Public AEAD
   ---------------------------------------------------------------------------

   procedure Encrypt
     (Key    : Key_Bytes;
      IV     : Nonce;
      AAD    : Byte_Array;
      Plain  : Byte_Array;
      Cipher : out Byte_Array;
      Tag    : out Auth_Tag)
   is
      H, J0, E_J0 : Blk;
      Y           : Blk := (others => 0);
   begin
      Setup (Key, IV, H, J0, E_J0);
      CTR (Key, J0, Plain, Cipher);
      GHASH_Bytes (Y, AAD, H);
      GHASH_Bytes (Y, Cipher, H);
      GHASH_Lengths (Y, AAD'Length, Plain'Length, H);
      for J in Blk'Range loop
         Tag (Tag'First + J) := Y (J) xor E_J0 (J);
      end loop;
   end Encrypt;

   procedure Decrypt
     (Key    : Key_Bytes;
      IV     : Nonce;
      AAD    : Byte_Array;
      Cipher : Byte_Array;
      Tag    : Auth_Tag;
      Plain  : out Byte_Array;
      Ok     : out Boolean)
   is
      H, J0, E_J0 : Blk;
      Y           : Blk := (others => 0);
      Diff        : U8 := 0;
   begin
      Plain := (others => 0);
      Setup (Key, IV, H, J0, E_J0);
      GHASH_Bytes (Y, AAD, H);
      GHASH_Bytes (Y, Cipher, H);
      GHASH_Lengths (Y, AAD'Length, Cipher'Length, H);
      for J in Blk'Range loop
         --  constant-time tag compare
         Diff := Diff or ((Y (J) xor E_J0 (J)) xor Tag (Tag'First + J));
      end loop;
      Ok := Diff = 0;
      if Ok then
         CTR (Key, J0, Cipher, Plain);
      end if;
   end Decrypt;

end ESP32S3.AES.GCM;
