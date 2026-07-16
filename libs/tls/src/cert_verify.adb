with ESP32S3.RSA;
with SPARKNaCl;
with SPARKNaCl.Hashing.SHA256;
with SPARKNaCl.Hashing.SHA384;
with SPARKNaCl.Hashing.SHA512;
with SPARKNaCl.Sign;
with P256;
with P384;
with Der_Sig;   --  SPARK-proved untrusted DER-INTEGER (ECDSA r/s) parse

package body Cert_Verify is

   use type X509.U8;
   subtype U8 is X509.U8;
   subtype Byte_Array is X509.Byte_Array;

   --  DigestInfo prefixes (DER of the digest algorithm + the OCTET STRING header)
   --  that precede the hash in a PKCS#1 v1.5 block -- one per SHA variant.
   DI_SHA256 : constant Byte_Array :=
     (16#30#,
      16#31#,
      16#30#,
      16#0D#,
      16#06#,
      16#09#,
      16#60#,
      16#86#,
      16#48#,
      16#01#,
      16#65#,
      16#03#,
      16#04#,
      16#02#,
      16#01#,
      16#05#,
      16#00#,
      16#04#,
      16#20#);
   DI_SHA384 : constant Byte_Array :=
     (16#30#,
      16#41#,
      16#30#,
      16#0D#,
      16#06#,
      16#09#,
      16#60#,
      16#86#,
      16#48#,
      16#01#,
      16#65#,
      16#03#,
      16#04#,
      16#02#,
      16#02#,
      16#05#,
      16#00#,
      16#04#,
      16#30#);
   DI_SHA512 : constant Byte_Array :=
     (16#30#,
      16#51#,
      16#30#,
      16#0D#,
      16#06#,
      16#09#,
      16#60#,
      16#86#,
      16#48#,
      16#01#,
      16#65#,
      16#03#,
      16#04#,
      16#02#,
      16#03#,
      16#05#,
      16#00#,
      16#04#,
      16#40#);

   --  Big-endian bytes -> little-endian 32-bit words (word 0 least significant).
   --  W may hold more words than B fills; the high words are zeroed.
   procedure BE_To_Words (B : Byte_Array; W : out ESP32S3.RSA.Word_Array) is
      use ESP32S3.RSA;
   begin
      for J in 0 .. W'Length - 1 loop
         declare
            Byte_Pos : constant Integer := Integer (B'Last) - 4 * J;   --  LSB of word J
            Acc      : Word := 0;
         begin
            if Byte_Pos >= Integer (B'First) then
               Acc := Acc + Word (B (Byte_Pos));
            end if;
            if Byte_Pos - 1 >= Integer (B'First) then
               Acc := Acc + Word (B (Byte_Pos - 1)) * 16#100#;
            end if;
            if Byte_Pos - 2 >= Integer (B'First) then
               Acc := Acc + Word (B (Byte_Pos - 2)) * 16#1_0000#;
            end if;
            if Byte_Pos - 3 >= Integer (B'First) then
               Acc := Acc + Word (B (Byte_Pos - 3)) * 16#100_0000#;
            end if;
            W (W'First + J) := Acc;
         end;
      end loop;
   end BE_To_Words;

   --  Little-endian words -> big-endian bytes (EM'Length must be 4 * W'Length).
   procedure Words_To_BE (W : ESP32S3.RSA.Word_Array; EM : out Byte_Array) is
      use ESP32S3.RSA;
   begin
      for J in 0 .. W'Length - 1 loop
         declare
            Word_Val : constant Word := W (W'First + J);
            Byte_Pos : constant Natural := EM'Last - 4 * J;       --  LSB of word J
         begin
            EM (Byte_Pos) := U8 (Word_Val mod 16#100#);
            EM (Byte_Pos - 1) := U8 ((Word_Val / 16#100#) mod 16#100#);
            EM (Byte_Pos - 2) := U8 ((Word_Val / 16#1_0000#) mod 16#100#);
            EM (Byte_Pos - 3) := U8 ((Word_Val / 16#100_0000#) mod 16#100#);
         end;
      end loop;
   end Words_To_BE;

   --  Big-endian SHA digests of Data, as Byte_Array (full length per variant).
   function SHA256_BA (Data : Byte_Array) return Byte_Array is
      Msg    : SPARKNaCl.Byte_Seq (0 .. SPARKNaCl.N32 (Data'Length - 1));
      Digest : SPARKNaCl.Hashing.SHA256.Digest;
      Result : Byte_Array (0 .. 31);
   begin
      for I in 0 .. Data'Length - 1 loop
         Msg (SPARKNaCl.N32 (I)) := SPARKNaCl.Byte (Data (Data'First + I));
      end loop;
      Digest := SPARKNaCl.Hashing.SHA256.Hash (Msg);
      for I in Result'Range loop
         Result (I) := U8 (Digest (SPARKNaCl.Index_32 (I)));
      end loop;
      return Result;
   end SHA256_BA;

   function SHA384_BA (Data : Byte_Array) return Byte_Array is
      Msg    : SPARKNaCl.Byte_Seq (0 .. SPARKNaCl.N32 (Data'Length - 1));
      Digest : SPARKNaCl.Hashing.SHA384.Digest;
      Result : Byte_Array (0 .. 47);
   begin
      for I in 0 .. Data'Length - 1 loop
         Msg (SPARKNaCl.N32 (I)) := SPARKNaCl.Byte (Data (Data'First + I));
      end loop;
      Digest := SPARKNaCl.Hashing.SHA384.Hash (Msg);
      for I in Result'Range loop
         Result (I) := U8 (Digest (SPARKNaCl.Index_48 (I)));
      end loop;
      return Result;
   end SHA384_BA;

   function SHA512_BA (Data : Byte_Array) return Byte_Array is
      Msg    : SPARKNaCl.Byte_Seq (0 .. SPARKNaCl.N32 (Data'Length - 1));
      Digest : SPARKNaCl.Hashing.SHA512.Digest;
      Result : Byte_Array (0 .. 63);
   begin
      for I in 0 .. Data'Length - 1 loop
         Msg (SPARKNaCl.N32 (I)) := SPARKNaCl.Byte (Data (Data'First + I));
      end loop;
      Digest := SPARKNaCl.Hashing.SHA512.Hash (Msg);
      for I in Result'Range loop
         Result (I) := U8 (Digest (SPARKNaCl.Index_64 (I)));
      end loop;
      return Result;
   end SHA512_BA;

   --  RSASSA-PKCS1-v1.5 verify with a precomputed digest Hash and its matching
   --  DigestInfo prefix DI: recover EM = Signature^Exponent mod Modulus and
   --  constant-time compare it to 00 01 FF..FF 00 || DI || Hash.
   function RSA_PKCS1_Core (Hash, DI, Signature, Modulus, Exponent : Byte_Array) return Boolean is
      M_First : Natural := Modulus'First;
   begin
      --  Drop a single leading 0x00 (DER positive-sign byte) from the modulus.
      if Modulus'Length >= 1 and then Modulus (Modulus'First) = 0 then
         M_First := Modulus'First + 1;
      end if;
      declare
         K : constant Natural :=
           (if Modulus'Last >= M_First then Modulus'Last - M_First + 1 else 0);
      begin
         --  k a whole number of words, RSA-sized, and big enough for the block
         --  (00 01 || >=8 FF || 00 || DigestInfo || hash).
         if K = 0
           or else K mod 4 /= 0
           or else K > 512
           or else Signature'Length /= K
           or else K < 11 + DI'Length + Hash'Length
         then
            return False;
         end if;
         declare
            use ESP32S3.RSA;
            Word_Count   : constant Natural := K / 4;
            Mod_Words    : Word_Array (0 .. Word_Count - 1);   --  modulus n
            Sig_Words    : Word_Array (0 .. Word_Count - 1);   --  signature
            Exp_Words    : Word_Array (0 .. Word_Count - 1);   --  public exponent e
            Result_Words : Word_Array (0 .. Word_Count - 1);   --  sig^e mod n
            Ok           : Boolean;
            EM           : Byte_Array (0 .. K - 1);            --  encoded message (RFC 8017)
            Expected     : Byte_Array (0 .. K - 1);            --  block EM must equal
            PS_Len       : constant Natural :=
              K - 3 - (DI'Length + Hash'Length);               --  PKCS#1 padding-string length
            Diff         : U8 := 0;
            Pos          : Natural;
         begin
            BE_To_Words (Modulus (M_First .. Modulus'Last), Mod_Words);
            BE_To_Words (Signature, Sig_Words);
            BE_To_Words (Exponent, Exp_Words);
            Mod_Exp (Sig_Words, Exp_Words, Mod_Words, Result_Words, Ok);  --  EM = sig^e mod n
            if not Ok then
               return False;
            end if;
            Words_To_BE (Result_Words, EM);

            Expected (0) := 16#00#;
            Expected (1) := 16#01#;
            Pos := 2;
            for I in 0 .. PS_Len - 1 loop
               Expected (Pos + I) := 16#FF#;
            end loop;
            Pos := Pos + PS_Len;
            Expected (Pos) := 16#00#;
            Pos := Pos + 1;
            for I in DI'Range loop
               Expected (Pos) := DI (I);
               Pos := Pos + 1;
            end loop;
            for I in Hash'Range loop
               Expected (Pos) := Hash (I);
               Pos := Pos + 1;
            end loop;

            for I in EM'Range loop
               --  constant-time compare
               Diff := Diff or (EM (I) xor Expected (I));
            end loop;
            return Diff = 0;
         end;
      end;
   end RSA_PKCS1_Core;

   function RSA_PKCS1_SHA256 (TBS, Signature, Modulus, Exponent : Byte_Array) return Boolean
   is (RSA_PKCS1_Core (SHA256_BA (TBS), DI_SHA256, Signature, Modulus, Exponent));

   function RSA_PKCS1_SHA384 (TBS, Signature, Modulus, Exponent : Byte_Array) return Boolean
   is (RSA_PKCS1_Core (SHA384_BA (TBS), DI_SHA384, Signature, Modulus, Exponent));

   function RSA_PKCS1_SHA512 (TBS, Signature, Modulus, Exponent : Byte_Array) return Boolean
   is (RSA_PKCS1_Core (SHA512_BA (TBS), DI_SHA512, Signature, Modulus, Exponent));

   ---------------------------------------------------------------------------
   --  RSASSA-PSS (MGF1-SHA-256, salt length 32).  SHA256_BA is defined above.
   ---------------------------------------------------------------------------

   --  MGF1 with SHA-256.
   function MGF1 (Seed : Byte_Array; Mask_Len : Natural) return Byte_Array is
      Mask : Byte_Array (0 .. Mask_Len - 1);
      Pos  : Natural := 0;
      Cnt  : Natural := 0;
   begin
      while Pos < Mask_Len loop
         declare
            In_Buf : Byte_Array (0 .. Seed'Length + 3);
            H      : Byte_Array (0 .. 31);
         begin
            for I in 0 .. Seed'Length - 1 loop
               In_Buf (I) := Seed (Seed'First + I);
            end loop;
            In_Buf (Seed'Length) := U8 ((Cnt / 16#100_0000#) mod 256);
            In_Buf (Seed'Length + 1) := U8 ((Cnt / 16#1_0000#) mod 256);
            In_Buf (Seed'Length + 2) := U8 ((Cnt / 16#100#) mod 256);
            In_Buf (Seed'Length + 3) := U8 (Cnt mod 256);
            H := SHA256_BA (In_Buf);
            for I in 0 .. 31 loop
               if Pos + I < Mask_Len then
                  Mask (Pos + I) := H (I);
               end if;
            end loop;
            Pos := Pos + 32;
            Cnt := Cnt + 1;
         end;
      end loop;
      return Mask;
   end MGF1;

   function RSA_PSS_SHA256 (Message, Signature, Modulus, Exponent : Byte_Array) return Boolean is
      M_First : Natural := Modulus'First;
   begin
      if Modulus'Length >= 1 and then Modulus (Modulus'First) = 0 then
         M_First := Modulus'First + 1;
      end if;
      declare
         K : constant Natural :=
           (if Modulus'Last >= M_First then Modulus'Last - M_First + 1 else 0);
      begin
         if K = 0 or else K mod 4 /= 0 or else K > 512 or else Signature'Length /= K then
            return False;
         end if;
         declare
            use ESP32S3.RSA;
            Word_Count   : constant Natural := K / 4;
            Mod_Words    : Word_Array (0 .. Word_Count - 1);   --  modulus n
            Sig_Words    : Word_Array (0 .. Word_Count - 1);   --  signature
            Exp_Words    : Word_Array (0 .. Word_Count - 1);   --  public exponent e
            Result_Words : Word_Array (0 .. Word_Count - 1);   --  sig^e mod n
            Ok           : Boolean;
            EMb          : Byte_Array (0 .. K - 1);   --  encoded message EM (RFC 8017)
            hLen         : constant := 32;            --  SHA-256 digest length
            sLen         : constant := 32;            --  salt length
            Top_Bits     : Natural := 0;              --  bit width of the modulus top byte
            Top_Byte     : U8 := Modulus (M_First);
         begin
            BE_To_Words (Modulus (M_First .. Modulus'Last), Mod_Words);
            BE_To_Words (Signature, Sig_Words);
            BE_To_Words (Exponent, Exp_Words);
            Mod_Exp (Sig_Words, Exp_Words, Mod_Words, Result_Words, Ok);  --  EM = sig^e mod n
            if not Ok then
               return False;
            end if;
            Words_To_BE (Result_Words, EMb);
            while Top_Byte /= 0 loop
               Top_Bits := Top_Bits + 1;
               Top_Byte := Top_Byte / 2;
            end loop;
            declare
               ModBits  : constant Natural := (K - 1) * 8 + Top_Bits;
               EmBits   : constant Natural := ModBits - 1;
               EmLen    : constant Natural := (EmBits + 7) / 8;
               LeadBits : constant Natural := 8 * EmLen - EmBits;
               EM_Off   : constant Natural := K - EmLen;
               DBLen    : constant Natural := EmLen - hLen - 1;
               ZeroN    : constant Natural := EmLen - hLen - sLen - 2;
               mHash    : constant Byte_Array := SHA256_BA (Message);
               H        : Byte_Array (0 .. hLen - 1);
            begin
               if EmLen < hLen + sLen + 2 or else EM_Off + EmLen /= K then
                  return False;
               end if;
               if EMb (EM_Off + EmLen - 1) /= 16#BC# then
                  --  trailer
                  return False;
               end if;
               if LeadBits > 0 and then (EMb (EM_Off) and U8 (16#100# - 2**(8 - LeadBits))) /= 0
               then
                  return False;
               end if;
               for I in 0 .. hLen - 1 loop
                  H (I) := EMb (EM_Off + DBLen + I);
               end loop;
               declare
                  DBMask : constant Byte_Array := MGF1 (H, DBLen);
                  DB     : Byte_Array (0 .. DBLen - 1);
                  Salt   : Byte_Array (0 .. sLen - 1);
                  Mp     : Byte_Array (0 .. 8 + hLen + sLen - 1) := (others => 0);
                  Hp     : Byte_Array (0 .. hLen - 1);
                  Good   : Boolean := True;
               begin
                  for I in 0 .. DBLen - 1 loop
                     DB (I) := EMb (EM_Off + I) xor DBMask (I);
                  end loop;
                  if LeadBits > 0 then
                     DB (0) := DB (0) and U8 (2**(8 - LeadBits) - 1);
                  end if;
                  for I in 0 .. ZeroN - 1 loop
                     if DB (I) /= 0 then
                        Good := False;
                     end if;
                  end loop;
                  if DB (ZeroN) /= 16#01# then
                     --  PS || 0x01 || salt
                     Good := False;
                  end if;
                  if not Good then
                     return False;
                  end if;
                  for I in 0 .. sLen - 1 loop
                     Salt (I) := DB (DBLen - sLen + I);
                  end loop;
                  --  M' = (0x00)*8 || mHash || salt ; H' = SHA-256(M')
                  for I in 0 .. hLen - 1 loop
                     Mp (8 + I) := mHash (I);
                  end loop;
                  for I in 0 .. sLen - 1 loop
                     Mp (8 + hLen + I) := Salt (I);
                  end loop;
                  Hp := SHA256_BA (Mp);
                  for I in 0 .. hLen - 1 loop
                     if Hp (I) /= H (I) then
                        return False;
                     end if;
                  end loop;
                  return True;
               end;
            end;
         end;
      end;
   end RSA_PSS_SHA256;

   ---------------------------------------------------------------------------
   --  ECDSA / P-256
   ---------------------------------------------------------------------------

   --  SHA-384 of Data, left-truncated to 32 bytes (ECDSA uses the leftmost
   --  256 bits of the digest with a 256-bit group order).
   function SHA384_BA_32 (Data : Byte_Array) return Byte_Array is
      Msg    : SPARKNaCl.Byte_Seq (0 .. SPARKNaCl.N32 (Data'Length - 1));
      Digest : SPARKNaCl.Hashing.SHA384.Digest;
      Result : Byte_Array (0 .. 31);
   begin
      for I in 0 .. Data'Length - 1 loop
         Msg (SPARKNaCl.N32 (I)) := SPARKNaCl.Byte (Data (Data'First + I));
      end loop;
      Digest := SPARKNaCl.Hashing.SHA384.Hash (Msg);
      for I in 0 .. 31 loop
         Result (I) := U8 (Digest (SPARKNaCl.Index_32 (I)));
      end loop;
      return Result;
   end SHA384_BA_32;

   function To_P256 (B : Byte_Array) return P256.Bytes_32 is
      Result : P256.Bytes_32;
   begin
      for I in 0 .. 31 loop
         Result (I) := P256.Byte (B (B'First + I));
      end loop;
      return Result;
   end To_P256;

   --  Read a DER INTEGER at Pos (tag 0x02), big-endian, into a 32-byte right-aligned
   --  value (leading zero sign byte dropped, short values left-padded).  Advances Pos.
   procedure DER_Int
     (Buf   : Byte_Array;
      Pos   : in out Natural;
      Last  : Natural;
      Out32 : out P256.Bytes_32;
      Ok    : in out Boolean)
   is
      Tmp : Der_Sig.Bytes (0 .. 31);
   begin
      Der_Sig.Read_Integer (Der_Sig.Bytes (Buf), Pos, Last, Tmp, Ok);
      Out32 := P256.Bytes_32 (Tmp);
   end DER_Int;

   --  Verify ECDSA(SHA-256/384)/P-256 of Hash32 with signature Sig_DER under
   --  (Pub_X, Pub_Y).  Sig_DER = SEQUENCE { r INTEGER, s INTEGER }.
   function ECDSA_Core (Hash32 : Byte_Array; Sig_DER, Pub_X, Pub_Y : Byte_Array) return Boolean is
      Pos      : Natural;
      Ok       : Boolean := True;
      R32, S32 : P256.Bytes_32;   --  the signature's r and s components (32-byte big-endian)
   begin
      if Sig_DER'Length < 8
        or else Pub_X'Length /= 32
        or else Pub_Y'Length /= 32
        or else Sig_DER (Sig_DER'First) /= 16#30#
      then
         return False;
      end if;
      Pos := Sig_DER'First + 2;                      --  past SEQUENCE tag + length
      DER_Int (Sig_DER, Pos, Sig_DER'Last, R32, Ok);
      DER_Int (Sig_DER, Pos, Sig_DER'Last, S32, Ok);
      if not Ok then
         return False;
      end if;
      return P256.Verify (To_P256 (Pub_X), To_P256 (Pub_Y), To_P256 (Hash32), R32, S32);
   end ECDSA_Core;

   function ECDSA_P256_SHA256 (Message, Sig_DER, Pub_X, Pub_Y : X509.Byte_Array) return Boolean
   is (ECDSA_Core (SHA256_BA (Message), Sig_DER, Pub_X, Pub_Y));

   function ECDSA_P256_SHA384 (Message, Sig_DER, Pub_X, Pub_Y : X509.Byte_Array) return Boolean
   is (ECDSA_Core (SHA384_BA_32 (Message), Sig_DER, Pub_X, Pub_Y));

   ---------------------------------------------------------------------------
   --  ECDSA/P-384.  Mirrors ECDSA_Core, widened to 48-byte values; the digest
   --  is the full 48-byte SHA-384 (no truncation).
   ---------------------------------------------------------------------------
   function To_P384 (B : Byte_Array) return P384.Bytes_48 is
      Result : P384.Bytes_48;
   begin
      for I in 0 .. 47 loop
         Result (I) := P384.Byte (B (B'First + I));
      end loop;
      return Result;
   end To_P384;

   --  Read a DER INTEGER into a 48-byte right-aligned big-endian value.
   procedure DER_Int_48
     (Buf   : Byte_Array;
      Pos   : in out Natural;
      Last  : Natural;
      Out48 : out P384.Bytes_48;
      Ok    : in out Boolean)
   is
      Tmp : Der_Sig.Bytes (0 .. 47);
   begin
      Der_Sig.Read_Integer (Der_Sig.Bytes (Buf), Pos, Last, Tmp, Ok);
      Out48 := P384.Bytes_48 (Tmp);
   end DER_Int_48;

   function ECDSA_P384_SHA384 (Message, Sig_DER, Pub_X, Pub_Y : X509.Byte_Array) return Boolean
   is
      Hash48   : constant Byte_Array := SHA384_BA (Message);
      Pos      : Natural;
      Ok       : Boolean := True;
      R48, S48 : P384.Bytes_48;
   begin
      if Sig_DER'Length < 8
        or else Pub_X'Length /= 48
        or else Pub_Y'Length /= 48
        or else Sig_DER (Sig_DER'First) /= 16#30#
      then
         return False;
      end if;
      Pos := Sig_DER'First + 2;                      --  past SEQUENCE tag + length
      DER_Int_48 (Sig_DER, Pos, Sig_DER'Last, R48, Ok);
      DER_Int_48 (Sig_DER, Pos, Sig_DER'Last, S48, Ok);
      if not Ok then
         return False;
      end if;
      return P384.Verify
        (To_P384 (Pub_X), To_P384 (Pub_Y), To_P384 (Hash48), R48, S48);
   end ECDSA_P384_SHA384;

   ---------------------------------------------------------------------------
   --  Ed25519 (RFC 8032)
   ---------------------------------------------------------------------------

   --  Detached verify: NaCl exposes the combined form (signature || message), so
   --  reconstruct SM = Signature || Message, run Open (which cryptographically
   --  verifies), and confirm it recovered exactly Message.
   function Ed25519_Verify (Message, Signature, Pub_Key : X509.Byte_Array) return Boolean is
      use type SPARKNaCl.I32;
      use type SPARKNaCl.Byte;
      PKB : SPARKNaCl.Bytes_32;
      PK  : SPARKNaCl.Sign.Signing_PK;
   begin
      if Signature'Length /= 64 or else Pub_Key'Length /= 32 or else Message'Length = 0 then
         return False;
      end if;
      for I in 0 .. 31 loop
         PKB (SPARKNaCl.Index_32 (I)) := SPARKNaCl.Byte (Pub_Key (Pub_Key'First + I));
      end loop;
      SPARKNaCl.Sign.PK_From_Bytes (PKB, PK);

      declare
         Total  : constant Natural := 64 + Message'Length;
         SM     : SPARKNaCl.Byte_Seq (0 .. SPARKNaCl.N32 (Total - 1));
         M      : SPARKNaCl.Byte_Seq (0 .. SPARKNaCl.N32 (Total - 1));
         Status : Boolean;
         MLen   : SPARKNaCl.I32;
      begin
         for I in 0 .. 63 loop
            SM (SPARKNaCl.N32 (I)) := SPARKNaCl.Byte (Signature (Signature'First + I));
         end loop;
         for I in 0 .. Message'Length - 1 loop
            SM (SPARKNaCl.N32 (64 + I)) := SPARKNaCl.Byte (Message (Message'First + I));
         end loop;
         SPARKNaCl.Sign.Open (M, Status, MLen, SM, PK);
         if not Status or else MLen /= SPARKNaCl.I32 (Message'Length) then
            return False;
         end if;
         for I in 0 .. Message'Length - 1 loop
            if M (SPARKNaCl.N32 (I)) /= SPARKNaCl.Byte (Message (Message'First + I)) then
               return False;
            end if;
         end loop;
         return True;
      end;
   end Ed25519_Verify;

end Cert_Verify;
