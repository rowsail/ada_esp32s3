with X509.DER;

package body X509 is

   use type Interfaces.Unsigned_8;

   --  Read the element at P within [.. Limit]; require Valid and (if Want /= 0) a
   --  matching tag.  Clears Ok on failure and short-circuits once Ok is False.
   procedure Expect (Buf : Byte_Array; P, Limit : Natural; Want : U8;
                     E : out DER.TLV; Ok : in out Boolean) is
   begin
      E := (Valid => False, others => <>);
      if not Ok then
         return;
      end if;
      DER.Read (Buf, P, Limit, E);
      if not E.Valid or else (Want /= 0 and then E.Tag /= Want) then
         Ok := False;
      end if;
   end Expect;

   --  All the v3 extensions we read live under arc 2.5.29 ("55 1D .."), so a
   --  3-byte OID whose last byte selects the extension: subjectAltName .17 (0x11),
   --  keyUsage .15 (0x0F), basicConstraints .19 (0x13), extKeyUsage .37 (0x25).
   function Is_Ext_OID (Cert : Byte_Array; S : Slice; Last_Byte : U8)
                        return Boolean is
     (Length (S) = 3
      and then Cert (S.First) = 16#55#
      and then Cert (S.First + 1) = 16#1D#
      and then Cert (S.First + 2) = Last_Byte);

   --  Known OBJECT IDENTIFIER values (DER content bytes, after tag+length).
   OID_RSA_Enc      : constant Byte_Array :=          --  1.2.840.113549.1.1.1
     (16#2A#, 16#86#, 16#48#, 16#86#, 16#F7#, 16#0D#, 16#01#, 16#01#, 16#01#);
   OID_EC_PubKey    : constant Byte_Array :=          --  1.2.840.10045.2.1
     (16#2A#, 16#86#, 16#48#, 16#CE#, 16#3D#, 16#02#, 16#01#);
   OID_P256_Curve   : constant Byte_Array :=          --  1.2.840.10045.3.1.7 prime256v1
     (16#2A#, 16#86#, 16#48#, 16#CE#, 16#3D#, 16#03#, 16#01#, 16#07#);
   OID_RSA_SHA256   : constant Byte_Array :=          --  1.2.840.113549.1.1.11
     (16#2A#, 16#86#, 16#48#, 16#86#, 16#F7#, 16#0D#, 16#01#, 16#01#, 16#0B#);
   OID_ECDSA_SHA256 : constant Byte_Array :=          --  1.2.840.10045.4.3.2
     (16#2A#, 16#86#, 16#48#, 16#CE#, 16#3D#, 16#04#, 16#03#, 16#02#);
   OID_ECDSA_SHA384 : constant Byte_Array :=          --  1.2.840.10045.4.3.3
     (16#2A#, 16#86#, 16#48#, 16#CE#, 16#3D#, 16#04#, 16#03#, 16#03#);
   OID_RSA_SHA384   : constant Byte_Array :=          --  1.2.840.113549.1.1.12
     (16#2A#, 16#86#, 16#48#, 16#86#, 16#F7#, 16#0D#, 16#01#, 16#01#, 16#0C#);
   OID_RSA_SHA512   : constant Byte_Array :=          --  1.2.840.113549.1.1.13
     (16#2A#, 16#86#, 16#48#, 16#86#, 16#F7#, 16#0D#, 16#01#, 16#01#, 16#0D#);
   OID_Ed25519      : constant Byte_Array :=          --  1.3.101.112 id-Ed25519
     (16#2B#, 16#65#, 16#70#);
   OID_Server_Auth  : constant Byte_Array :=          --  1.3.6.1.5.5.7.3.1 id-kp-serverAuth
     (16#2B#, 16#06#, 16#01#, 16#05#, 16#05#, 16#07#, 16#03#, 16#01#);
   OID_Client_Auth  : constant Byte_Array :=          --  1.3.6.1.5.5.7.3.2 id-kp-clientAuth
     (16#2B#, 16#06#, 16#01#, 16#05#, 16#05#, 16#07#, 16#03#, 16#02#);
   OID_Any_EKU      : constant Byte_Array :=          --  2.5.29.37.0 anyExtendedKeyUsage
     (16#55#, 16#1D#, 16#25#, 16#00#);

   --  Do the OID content bytes at Slice S equal OID?
   function OID_Match (Cert : Byte_Array; S : Slice; OID : Byte_Array) return Boolean
   is
   begin
      if Length (S) /= OID'Length then
         return False;
      end if;
      for I in 0 .. OID'Length - 1 loop
         if Cert (S.First + I) /= OID (OID'First + I) then
            return False;
         end if;
      end loop;
      return True;
   end OID_Match;

   --  GeneralNames ::= SEQUENCE OF GeneralName; collect dNSName ([2], tag 0x82).
   procedure Parse_SAN (Cert : Byte_Array; First, Last : Natural;
                        Result : in out Certificate) is
      Seq, Name : DER.TLV;
      P : Natural;
   begin
      DER.Read (Cert, First, Last, Seq);
      if not Seq.Valid or else Seq.Tag /= 16#30# then
         return;
      end if;
      P := Seq.Content.First;
      while P <= Seq.Content.Last loop
         DER.Read (Cert, P, Seq.Content.Last, Name);
         exit when not Name.Valid;
         if Name.Tag = 16#82# and then Result.SAN_Count < Max_SAN then
            Result.SAN_Count := Result.SAN_Count + 1;
            Result.SAN (Result.SAN_Count) := Name.Content;
         end if;
         P := Name.Elem_Last + 1;
      end loop;
   end Parse_SAN;

   --  BasicConstraints ::= SEQUENCE { cA BOOLEAN DEFAULT FALSE, pathLen INTEGER OPT }
   procedure Parse_Basic_Constraints (Cert : Byte_Array; First, Last : Natural;
                                      Result : in out Certificate) is
      Seq, T : DER.TLV;
      P : Natural;
   begin
      Result.BC_Present := True;
      DER.Read (Cert, First, Last, Seq);
      if not Seq.Valid or else Seq.Tag /= 16#30# then
         return;                       --  empty/odd: cA stays FALSE (not a CA)
      end if;
      P := Seq.Content.First;
      DER.Read (Cert, P, Seq.Content.Last, T);
      if T.Valid and then T.Tag = 16#01# and then Length (T.Content) = 1 then
         Result.Is_CA := Cert (T.Content.First) /= 0;       --  cA BOOLEAN
         P := T.Elem_Last + 1;
         DER.Read (Cert, P, Seq.Content.Last, T);
      end if;
      if T.Valid and then T.Tag = 16#02#                    --  pathLenConstraint INTEGER
        and then Length (T.Content) in 1 .. 2
      then
         declare
            V : Integer := 0;
         begin
            for I in T.Content.First .. T.Content.Last loop
               V := V * 256 + Integer (Cert (I));
            end loop;
            Result.Path_Len := V;
         end;
      end if;
   end Parse_Basic_Constraints;

   --  KeyUsage ::= BIT STRING.  Content is [unused-bits][data..]; KeyUsage bit N
   --  is bit (7-N) of data byte N/8 -- digitalSignature = 0, keyCertSign = 5.
   procedure Parse_Key_Usage (Cert : Byte_Array; First, Last : Natural;
                              Result : in out Certificate) is
      BS : DER.TLV;
      Bits0 : U8;
   begin
      Result.KU_Present := True;
      DER.Read (Cert, First, Last, BS);
      if not BS.Valid or else BS.Tag /= 16#03# or else Length (BS.Content) < 2 then
         return;
      end if;
      Bits0 := Cert (BS.Content.First + 1);                 --  first data byte
      Result.KU_Digital_Sig := (Bits0 and 16#80#) /= 0;     --  bit 0
      Result.KU_Cert_Sign   := (Bits0 and 16#04#) /= 0;     --  bit 5
   end Parse_Key_Usage;

   --  ExtKeyUsage ::= SEQUENCE OF KeyPurposeId (OID).
   procedure Parse_EKU (Cert : Byte_Array; First, Last : Natural;
                        Result : in out Certificate) is
      Seq, Purpose : DER.TLV;
      P : Natural;
   begin
      Result.EKU_Present := True;
      DER.Read (Cert, First, Last, Seq);
      if not Seq.Valid or else Seq.Tag /= 16#30# then
         return;
      end if;
      P := Seq.Content.First;
      while P <= Seq.Content.Last loop
         DER.Read (Cert, P, Seq.Content.Last, Purpose);
         exit when not Purpose.Valid;
         if Purpose.Tag = 16#06# then
            if OID_Match (Cert, Purpose.Content, OID_Server_Auth) then
               Result.EKU_Server := True;
            elsif OID_Match (Cert, Purpose.Content, OID_Client_Auth) then
               Result.EKU_Client := True;
            elsif OID_Match (Cert, Purpose.Content, OID_Any_EKU) then
               Result.EKU_Server := True;
               Result.EKU_Client := True;
            end if;
         end if;
         P := Purpose.Elem_Last + 1;
      end loop;
   end Parse_EKU;

   --  Extensions ::= SEQUENCE OF Extension { extnID OID, [critical], extnValue }.
   procedure Parse_Extensions (Cert : Byte_Array; First, Last : Natural;
                               Result : in out Certificate) is
      Seq, Ext, OID, Val : DER.TLV;
      P, EP : Natural;
   begin
      DER.Read (Cert, First, Last, Seq);
      if not Seq.Valid or else Seq.Tag /= 16#30# then
         return;
      end if;
      P := Seq.Content.First;
      while P <= Seq.Content.Last loop
         DER.Read (Cert, P, Seq.Content.Last, Ext);
         exit when not Ext.Valid or else Ext.Tag /= 16#30#;
         EP := Ext.Content.First;
         DER.Read (Cert, EP, Ext.Content.Last, OID);
         if OID.Valid and then OID.Tag = 16#06# then
            --  Skip the optional critical BOOLEAN, then take extnValue OCTET STRING.
            EP := OID.Elem_Last + 1;
            DER.Read (Cert, EP, Ext.Content.Last, Val);
            if Val.Valid and then Val.Tag = 16#01# then    --  optional critical BOOLEAN
               EP := Val.Elem_Last + 1;
               DER.Read (Cert, EP, Ext.Content.Last, Val);
            end if;
            if Val.Valid and then Val.Tag = 16#04# then    --  extnValue OCTET STRING
               if Is_Ext_OID (Cert, OID.Content, 16#11#) then        --  subjectAltName
                  Parse_SAN (Cert, Val.Content.First, Val.Content.Last, Result);
               elsif Is_Ext_OID (Cert, OID.Content, 16#13#) then     --  basicConstraints
                  Parse_Basic_Constraints
                    (Cert, Val.Content.First, Val.Content.Last, Result);
               elsif Is_Ext_OID (Cert, OID.Content, 16#0F#) then     --  keyUsage
                  Parse_Key_Usage (Cert, Val.Content.First, Val.Content.Last, Result);
               elsif Is_Ext_OID (Cert, OID.Content, 16#25#) then     --  extKeyUsage
                  Parse_EKU (Cert, Val.Content.First, Val.Content.Last, Result);
               end if;
            end if;
         end if;
         P := Ext.Elem_Last + 1;
      end loop;
   end Parse_Extensions;

   procedure Parse (Cert : Byte_Array; Result : out Certificate) is
      Ok : Boolean := True;
      Outer, Tbs, E, Validity, SPKI, Bits, RSASeq, SigAlg, OID, SigVal : DER.TLV;
      P, L : Natural;
   begin
      Result := (Valid => False, others => <>);
      if Cert'Length < 2 then
         return;
      end if;

      --  Certificate ::= SEQUENCE { tbsCertificate, signatureAlgorithm, signature }
      Expect (Cert, Cert'First, Cert'Last, 16#30#, Outer, Ok);
      if not Ok then
         return;
      end if;

      --  tbsCertificate (the whole element is the signed region).
      Expect (Cert, Outer.Content.First, Outer.Content.Last, 16#30#, Tbs, Ok);
      if not Ok then
         return;
      end if;
      Result.TBS := (First => Outer.Content.First, Last => Tbs.Elem_Last);

      P := Tbs.Content.First;
      L := Tbs.Content.Last;

      --  version [0] EXPLICIT -- optional.
      DER.Read (Cert, P, L, E);
      if E.Valid and then E.Tag = 16#A0# then
         P := E.Elem_Last + 1;
      end if;

      --  serialNumber INTEGER
      Expect (Cert, P, L, 16#02#, E, Ok);
      Result.Serial := E.Content;
      P := E.Elem_Last + 1;

      --  signature AlgorithmIdentifier  (skip)
      Expect (Cert, P, L, 16#30#, E, Ok);
      P := E.Elem_Last + 1;

      --  issuer Name  (skip)
      Expect (Cert, P, L, 16#30#, E, Ok);
      P := E.Elem_Last + 1;

      --  validity SEQUENCE { notBefore Time, notAfter Time }
      Expect (Cert, P, L, 16#30#, Validity, Ok);
      if Ok then
         declare
            VP : Natural := Validity.Content.First;
            VL : constant Natural := Validity.Content.Last;
            NB, NA : DER.TLV;
         begin
            Expect (Cert, VP, VL, 0, NB, Ok);
            Result.Not_Before := NB.Content;  Result.NB_Tag := NB.Tag;
            VP := NB.Elem_Last + 1;
            Expect (Cert, VP, VL, 0, NA, Ok);
            Result.Not_After := NA.Content;   Result.NA_Tag := NA.Tag;
         end;
      end if;
      P := Validity.Elem_Last + 1;

      --  subject Name  (skip)
      Expect (Cert, P, L, 16#30#, E, Ok);
      P := E.Elem_Last + 1;

      --  subjectPublicKeyInfo SEQUENCE { algorithm, subjectPublicKey BIT STRING }
      Expect (Cert, P, L, 16#30#, SPKI, Ok);
      if Ok then
         declare
            SP    : Natural := SPKI.Content.First;
            SL    : constant Natural := SPKI.Content.Last;
            AlgId : DER.TLV;
         begin
            Expect (Cert, SP, SL, 16#30#, AlgId, Ok);     --  algorithm SEQUENCE
            --  Classify the key algorithm from the first OID inside it.
            declare
               AP   : Natural := AlgId.Content.First;
               Alg, Curve : DER.TLV;
            begin
               Expect (Cert, AP, AlgId.Content.Last, 16#06#, Alg, Ok);
               if Ok then
                  if OID_Match (Cert, Alg.Content, OID_RSA_Enc) then
                     Result.Key_Kind := Key_RSA;
                  elsif OID_Match (Cert, Alg.Content, OID_EC_PubKey) then
                     --  EC: the next OID is the named curve; require prime256v1.
                     AP := Alg.Elem_Last + 1;
                     Expect (Cert, AP, AlgId.Content.Last, 16#06#, Curve, Ok);
                     if Ok and then OID_Match (Cert, Curve.Content, OID_P256_Curve) then
                        Result.Key_Kind := Key_EC_P256;
                     else
                        Ok := False;                       --  unsupported curve
                     end if;
                  elsif OID_Match (Cert, Alg.Content, OID_Ed25519) then
                     Result.Key_Kind := Key_Ed25519;       --  no params / no curve
                  else
                     Ok := False;                          --  unsupported key type
                  end if;
               end if;
            end;
            SP := AlgId.Elem_Last + 1;
            Expect (Cert, SP, SL, 16#03#, Bits, Ok);      --  subjectPublicKey BIT STRING

            if Ok and then Result.Key_Kind = Key_RSA
              and then Length (Bits.Content) >= 2
            then
               --  Skip the BIT STRING's unused-bits byte; parse RSAPublicKey.
               Expect (Cert, Bits.Content.First + 1, Bits.Content.Last, 16#30#, RSASeq, Ok);
               if Ok then
                  declare
                     RP : Natural := RSASeq.Content.First;
                     RL : constant Natural := RSASeq.Content.Last;
                     M, Ex : DER.TLV;
                  begin
                     Expect (Cert, RP, RL, 16#02#, M, Ok);   --  modulus INTEGER
                     Result.RSA_Modulus := M.Content;
                     RP := M.Elem_Last + 1;
                     Expect (Cert, RP, RL, 16#02#, Ex, Ok);  --  publicExponent INTEGER
                     Result.RSA_Exponent := Ex.Content;
                  end;
               end if;

            elsif Ok and then Result.Key_Kind = Key_EC_P256
              and then Length (Bits.Content) >= 66
              and then Cert (Bits.Content.First + 1) = 16#04#   --  uncompressed point
            then
               --  BIT STRING content = unused-bits(1) || 0x04 || X(32) || Y(32).
               Result.EC_X := (First => Bits.Content.First + 2,
                               Last  => Bits.Content.First + 33);
               Result.EC_Y := (First => Bits.Content.First + 34,
                               Last  => Bits.Content.First + 65);

            elsif Ok and then Result.Key_Kind = Key_Ed25519
              and then Length (Bits.Content) >= 33
            then
               --  BIT STRING content = unused-bits(1) || 32-byte Ed25519 public key.
               Result.Ed_Pub := (First => Bits.Content.First + 1,
                                 Last  => Bits.Content.First + 32);
            else
               Ok := False;
            end if;
         end;
      end if;

      --  extensions [3] EXPLICIT -- optional; we pull subjectAltName dNSNames.
      if Ok then
         P := SPKI.Elem_Last + 1;
         DER.Read (Cert, P, L, E);
         if E.Valid and then E.Tag = 16#A3# then
            Parse_Extensions (Cert, E.Content.First, E.Content.Last, Result);
         end if;
      end if;

      --  signatureAlgorithm SEQUENCE { OID ... }
      P := Tbs.Elem_Last + 1;
      Expect (Cert, P, Outer.Content.Last, 16#30#, SigAlg, Ok);
      Expect (Cert, SigAlg.Content.First, SigAlg.Content.Last, 16#06#, OID, Ok);
      Result.Sig_Alg_OID := OID.Content;
      if Ok then
         if OID_Match (Cert, OID.Content, OID_RSA_SHA256) then
            Result.Sig_Kind := Sig_RSA_SHA256;
         elsif OID_Match (Cert, OID.Content, OID_RSA_SHA384) then
            Result.Sig_Kind := Sig_RSA_SHA384;
         elsif OID_Match (Cert, OID.Content, OID_RSA_SHA512) then
            Result.Sig_Kind := Sig_RSA_SHA512;
         elsif OID_Match (Cert, OID.Content, OID_ECDSA_SHA256) then
            Result.Sig_Kind := Sig_ECDSA_SHA256;
         elsif OID_Match (Cert, OID.Content, OID_ECDSA_SHA384) then
            Result.Sig_Kind := Sig_ECDSA_SHA384;
         elsif OID_Match (Cert, OID.Content, OID_Ed25519) then
            Result.Sig_Kind := Sig_Ed25519;
         end if;
      end if;
      P := SigAlg.Elem_Last + 1;

      --  signatureValue BIT STRING (drop the leading unused-bits byte).
      Expect (Cert, P, Outer.Content.Last, 16#03#, SigVal, Ok);
      if Ok and then Length (SigVal.Content) >= 1 then
         Result.Signature := (First => SigVal.Content.First + 1, Last => SigVal.Content.Last);
      else
         Ok := False;
      end if;

      Result.Valid := Ok;
   end Parse;

   ---------------------------------------------------------------------------
   --  Validity dates
   ---------------------------------------------------------------------------

   --  Parse an ASN.1 Time (UTCTime YYMMDDHHMMSSZ or GeneralizedTime
   --  YYYYMMDDHHMMSSZ) at slice S into a packed Time_64.  False if malformed.
   function Parse_Time (Cert : Byte_Array; S : Slice; Tag : U8; T : out Time_64)
                        return Boolean
   is
      F    : constant Natural := S.First;
      L    : constant Natural := Length (S);
      Base : Natural;
      Year, Mon, Day, Hr, Mi, Sc : Natural;

      function Is_Digit (Off : Natural) return Boolean is
        (Cert (F + Off) in 16#30# .. 16#39#);
      function D (Off : Natural) return Natural is
        (Natural (Cert (F + Off)) - 16#30#);
      function Two (Off : Natural) return Natural is (D (Off) * 10 + D (Off + 1));
   begin
      T := 0;
      if Tag = 16#17# then                        --  UTCTime (13: YYMMDDHHMMSSZ)
         if L /= 13 or else Cert (F + 12) /= 16#5A# then
            return False;
         end if;
         for K in 0 .. 11 loop
            if not Is_Digit (K) then return False; end if;
         end loop;
         Year := (if Two (0) < 50 then 2000 + Two (0) else 1900 + Two (0));
         Base := 2;
      elsif Tag = 16#18# then                      --  GeneralizedTime (15)
         if L /= 15 or else Cert (F + 14) /= 16#5A# then
            return False;
         end if;
         for K in 0 .. 13 loop
            if not Is_Digit (K) then return False; end if;
         end loop;
         Year := D (0) * 1000 + D (1) * 100 + D (2) * 10 + D (3);
         Base := 4;
      else
         return False;
      end if;
      Mon := Two (Base);      Day := Two (Base + 2);
      Hr  := Two (Base + 4);  Mi  := Two (Base + 6);  Sc := Two (Base + 8);
      if Mon not in 1 .. 12 or else Day not in 1 .. 31
        or else Hr > 23 or else Mi > 59 or else Sc > 60
      then
         return False;
      end if;
      T := Pack_Time (Year, Mon, Day, Hr, Mi, Sc);
      return True;
   end Parse_Time;

   function Valid_At (Cert : Byte_Array; C : Certificate; Now : Time_64)
                      return Boolean
   is
      NB, NA : Time_64;
   begin
      if not Parse_Time (Cert, C.Not_Before, C.NB_Tag, NB)
        or else not Parse_Time (Cert, C.Not_After, C.NA_Tag, NA)
      then
         return False;
      end if;
      return Now >= NB and then Now <= NA;
   end Valid_At;

   ---------------------------------------------------------------------------
   --  Hostname matching (subjectAltName dNSName)
   ---------------------------------------------------------------------------

   function Lower (B : U8) return U8 is
     (if B in 16#41# .. 16#5A# then B + 16#20# else B);

   --  Case-insensitive equality of Cert[BF..BL] (ASCII bytes) and Host[HF..HL].
   function Eq_CI (Cert : Byte_Array; BF, BL : Natural;
                   Host : String; HF, HL : Natural) return Boolean is
   begin
      if BL < BF or else HL < HF or else BL - BF /= HL - HF then
         return False;
      end if;
      for K in 0 .. BL - BF loop
         if Lower (Cert (BF + K)) /= Lower (U8 (Character'Pos (Host (HF + K)))) then
            return False;
         end if;
      end loop;
      return True;
   end Eq_CI;

   function Name_Matches (Cert : Byte_Array; S : Slice; Host : String)
                          return Boolean
   is
      function Has_Dot (From, To : Natural) return Boolean is
      begin
         for I in From .. To loop
            if Cert (I) = 16#2E# then return True; end if;
         end loop;
         return False;
      end Has_Dot;
   begin
      if Length (S) = 0 or else Host'Length = 0 then
         return False;
      end if;

      --  Wildcard "*." : match exactly one leftmost label of Host, and only where
      --  the remainder still has two labels (a dot).
      if Length (S) >= 2
        and then Cert (S.First) = 16#2A# and then Cert (S.First + 1) = 16#2E#
      then
         declare
            Dot : Natural := 0;
         begin
            for I in Host'Range loop
               if Host (I) = '.' then Dot := I; exit; end if;
            end loop;
            if Dot = 0 or else Dot = Host'First then        --  no / empty leftmost label
               return False;
            end if;
            return Eq_CI (Cert, S.First + 1, S.Last, Host, Dot, Host'Last)
                   and then Has_Dot (S.First + 2, S.Last);
         end;
      else
         return Eq_CI (Cert, S.First, S.Last, Host, Host'First, Host'Last);
      end if;
   end Name_Matches;

   function Host_Matches (Cert : Byte_Array; C : Certificate; Host : String)
                          return Boolean is
   begin
      for I in 1 .. C.SAN_Count loop
         if Name_Matches (Cert, C.SAN (I), Host) then
            return True;
         end if;
      end loop;
      return False;
   end Host_Matches;

end X509;
