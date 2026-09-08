with X509.DER;

package body X509 with SPARK_Mode => On is

   use type Interfaces.Unsigned_8;

   --  A slice, if it has any content, indexes only real positions of Cert (so
   --  reading Cert (S.First) .. Cert (S.Last) cannot go out of range).  Ghost:
   --  used only to state the preconditions of the slice-reading helpers.
   function In_Buffer (Cert : Byte_Array; S : Slice) return Boolean
   is (Length (S) = 0 or else (S.First >= Cert'First and then S.Last <= Cert'Last))
   with Ghost;

   --  X509.DER.Read is itself proven free of run-time errors, but its spec exposes
   --  no functional postcondition, so nothing about the returned indices reaches
   --  this unit's prover.  This thin wrapper re-checks (at negligible cost) the
   --  bounds DER.Read already guarantees, and folds any element that fails them
   --  back to "invalid", which lets SPARK carry the bounds forward: a valid TLV
   --  ends at or before Limit (<= Buf'Last) and its content lies inside the buffer.
   procedure Read_TLV (Buf : Byte_Array; Pos, Limit : Natural; E : out DER.TLV)
   with
     Post =>
       E.Elem_Last <= Buffer_Index'Last
       and then (if E.Valid
                 then
                   Limit <= Buf'Last
                   and then E.Elem_Last <= Limit
                   and then E.Content.Last <= E.Elem_Last
                   and then E.Content.First >= Buf'First
                   and then E.Content.First <= E.Content.Last + 1)
   is
   begin
      DER.Read (Buf, Pos, Limit, E);
      if not (E.Valid
              and then Limit <= Buf'Last
              and then E.Elem_Last <= Limit
              and then E.Content.Last <= E.Elem_Last
              and then E.Content.First >= Buf'First
              and then E.Content.First <= E.Content.Last + 1)
      then
         E := (Valid => False, Tag => 0, Content => (1, 0), Elem_Last => 0);
      end if;
   end Read_TLV;

   --  Read the element at P within [.. Limit]; require Valid and (if Want /= 0) a
   --  matching tag.  Clears Ok on failure and short-circuits once Ok is False.
   procedure Expect
     (Buf : Byte_Array; P, Limit : Natural; Want : U8; E : out DER.TLV; Ok : in out Boolean)
   with
     Post =>
       E.Elem_Last <= Buffer_Index'Last
       and then (if Ok then E.Valid)
       and then (if E.Valid
                 then
                   Limit <= Buf'Last
                   and then E.Elem_Last <= Limit
                   and then E.Content.Last <= E.Elem_Last
                   and then E.Content.First >= Buf'First
                   and then E.Content.First <= E.Content.Last + 1)
   is
   begin
      E := (Valid => False, others => <>);
      if not Ok then
         return;
      end if;
      Read_TLV (Buf, P, Limit, E);
      if not E.Valid or else (Want /= 0 and then E.Tag /= Want) then
         Ok := False;
      end if;
   end Expect;

   --  All the v3 extensions we read live under arc 2.5.29 ("55 1D .."), so a
   --  3-byte OID whose last byte selects the extension: subjectAltName .17 (0x11),
   --  keyUsage .15 (0x0F), basicConstraints .19 (0x13), extKeyUsage .37 (0x25).
   function Is_Ext_OID (Cert : Byte_Array; S : Slice; Last_Byte : U8) return Boolean
   is (Length (S) = 3
       and then Cert (S.First) = 16#55#
       and then Cert (S.First + 1) = 16#1D#
       and then Cert (S.First + 2) = Last_Byte)
   with Pre => In_Buffer (Cert, S);

   --  Known OBJECT IDENTIFIER values (DER content bytes, after tag+length).
   OID_RSA_Enc      : constant Byte_Array :=          --  1.2.840.113549.1.1.1
     (16#2A#, 16#86#, 16#48#, 16#86#, 16#F7#, 16#0D#, 16#01#, 16#01#, 16#01#);
   OID_EC_PubKey    : constant Byte_Array :=          --  1.2.840.10045.2.1
     (16#2A#, 16#86#, 16#48#, 16#CE#, 16#3D#, 16#02#, 16#01#);
   OID_P256_Curve   : constant Byte_Array :=          --  1.2.840.10045.3.1.7 prime256v1
     (16#2A#, 16#86#, 16#48#, 16#CE#, 16#3D#, 16#03#, 16#01#, 16#07#);
   OID_P384_Curve   : constant Byte_Array :=          --  1.3.132.0.34 secp384r1
     (16#2B#, 16#81#, 16#04#, 16#00#, 16#22#);
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
   with Pre => In_Buffer (Cert, S)
   is
   begin
      if Length (S) /= OID'Length then
         return False;
      end if;
      for I in 0 .. OID'Length - 1 loop
         pragma Loop_Invariant (S.First + I <= S.Last);
         if Cert (S.First + I) /= OID (OID'First + I) then
            return False;
         end if;
      end loop;
      return True;
   end OID_Match;

   --  A BIT STRING that holds whole octets -- a signature or a public key --
   --  starts with an unused-bits count of zero (X.690 8.6.2.2), and has at
   --  least one byte after it.  Accepting any other count would give the same
   --  key or signature 256 encodings, and for the signature that byte sits
   --  outside the region the issuer signed.
   function Whole_Octet_Bits (Cert : Byte_Array; Content : Slice) return Boolean
   is (Length (Content) >= 2
       and then Content.First >= Cert'First
       and then Content.First <= Cert'Last
       and then Cert (Content.First) = 0);

   --  The two copies of an AlgorithmIdentifier every certificate carries: the
   --  one inside tbsCertificate, which the issuer signed, and the outer
   --  signatureAlgorithm beside the signature, which anyone can rewrite.  A
   --  record rather than two Slice parameters, so which is which is written at
   --  the call rather than left to the order of two identical arguments.
   type Alg_Copies is record
      Signed : Slice;
      Outer  : Slice;
   end record;

   --  The two copies, byte for byte.  It checks its own bounds rather than
   --  taking them as a precondition: the slices come from elements parsed out
   --  of attacker-supplied DER, and a guard here is cheaper to be sure of than
   --  an argument that they must already be inside.
   function Same_Content (Cert : Byte_Array; Alg : Alg_Copies) return Boolean is
      A : constant Slice := Alg.Signed;
      B : constant Slice := Alg.Outer;
   begin
      if Length (A) = 0
        or else Length (A) /= Length (B)
        or else A.First < Cert'First or else A.Last > Cert'Last
        or else B.First < Cert'First or else B.Last > Cert'Last
      then
         return False;
      end if;
      for I in 0 .. Length (A) - 1 loop
         pragma Loop_Invariant (A.First + I <= A.Last and then B.First + I <= B.Last);
         pragma Loop_Variant (Increases => I);
         if Cert (A.First + I) /= Cert (B.First + I) then
            return False;
         end if;
      end loop;
      return True;
   end Same_Content;

   --  GeneralNames ::= SEQUENCE OF GeneralName; collect dNSName ([2], tag 0x82).
   procedure Parse_SAN (Cert : Byte_Array; First, Last : Natural; Result : in out Certificate) is
      Seq, Name : DER.TLV;
      Pos       : Natural;
   begin
      Read_TLV (Cert, First, Last, Seq);
      if not Seq.Valid or else Seq.Tag /= 16#30# then
         return;
      end if;
      Pos := Seq.Content.First;
      while Pos <= Seq.Content.Last loop
         Read_TLV (Cert, Pos, Seq.Content.Last, Name);
         exit when not Name.Valid;
         if Name.Tag = 16#82# and then Result.SAN_Count < Max_SAN then
            Result.SAN_Count := Result.SAN_Count + 1;
            Result.SAN (Result.SAN_Count) := Name.Content;
         end if;
         Pos := Name.Elem_Last + 1;
      end loop;
   end Parse_SAN;

   --  BasicConstraints ::= SEQUENCE { cA BOOLEAN DEFAULT FALSE, pathLen INTEGER OPT }
   procedure Parse_Basic_Constraints
     (Cert : Byte_Array; First, Last : Natural; Result : in out Certificate)
   is
      Seq, Field : DER.TLV;
      Pos        : Natural;
   begin
      Result.BC_Present := True;
      Read_TLV (Cert, First, Last, Seq);
      if not Seq.Valid or else Seq.Tag /= 16#30# then
         return;                       --  empty/odd: cA stays FALSE (not a CA)

      end if;
      Pos := Seq.Content.First;
      Read_TLV (Cert, Pos, Seq.Content.Last, Field);
      if Field.Valid and then Field.Tag = 16#01# and then Length (Field.Content) = 1 then
         Result.Is_CA := Cert (Field.Content.First) /= 0;       --  cA BOOLEAN
         Pos := Field.Elem_Last + 1;
         Read_TLV (Cert, Pos, Seq.Content.Last, Field);
      end if;
      if Field.Valid
        and then Field.Tag = 16#02#                --  pathLenConstraint INTEGER
        and then Length (Field.Content) in 1 .. 2
      then
         declare
            Value : Integer := 0;
         begin
            for I in Field.Content.First .. Field.Content.Last loop
               --  At most two bytes (Length in 1 .. 2), so Value stays well below
               --  Integer'Last; before the first byte it is 0, after any byte it
               --  fits two octets -- enough to prove the accumulation cannot
               --  overflow.
               pragma Loop_Invariant
                 (if I > Field.Content.First then Value in 0 .. 16#FFFF# else Value = 0);
               Value := Value * 256 + Integer (Cert (I));
            end loop;
            Result.Path_Len := Value;
         end;
      end if;
   end Parse_Basic_Constraints;

   --  KeyUsage ::= BIT STRING.  Content is [unused-bits][data..]; KeyUsage bit N
   --  is bit (7-N) of data byte N/8 -- digitalSignature = 0, keyCertSign = 5.
   procedure Parse_Key_Usage
     (Cert : Byte_Array; First, Last : Natural; Result : in out Certificate)
   is
      Bit_String : DER.TLV;
      Bits0      : U8;
   begin
      Result.KU_Present := True;
      Read_TLV (Cert, First, Last, Bit_String);
      if not Bit_String.Valid
        or else Bit_String.Tag /= 16#03#
        or else Length (Bit_String.Content) < 2
        --  Unlike a signature or a key, KeyUsage really is a bit string, so a
        --  non-zero unused-bits count is correct here -- but never above 7.
        or else Cert (Bit_String.Content.First) > 7
      then
         return;
      end if;
      Bits0 := Cert (Bit_String.Content.First + 1);         --  first data byte
      Result.KU_Digital_Sig := (Bits0 and 16#80#) /= 0;     --  bit 0
      Result.KU_Cert_Sign := (Bits0 and 16#04#) /= 0;     --  bit 5
   end Parse_Key_Usage;

   --  ExtKeyUsage ::= SEQUENCE OF KeyPurposeId (OID).
   procedure Parse_EKU (Cert : Byte_Array; First, Last : Natural; Result : in out Certificate) is
      Seq, Purpose : DER.TLV;
      Pos          : Natural;
   begin
      Result.EKU_Present := True;
      Read_TLV (Cert, First, Last, Seq);
      if not Seq.Valid or else Seq.Tag /= 16#30# then
         return;
      end if;
      Pos := Seq.Content.First;
      while Pos <= Seq.Content.Last loop
         Read_TLV (Cert, Pos, Seq.Content.Last, Purpose);
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
         Pos := Purpose.Elem_Last + 1;
      end loop;
   end Parse_EKU;

   --  Extensions ::= SEQUENCE OF Extension { extnID OID, [critical], extnValue }.
   procedure Parse_Extensions
     (Cert : Byte_Array; First, Last : Natural; Result : in out Certificate)
   is
      Seq, Ext, OID, Val : DER.TLV;
      Pos, Ext_Pos       : Natural;
   begin
      Read_TLV (Cert, First, Last, Seq);
      if not Seq.Valid or else Seq.Tag /= 16#30# then
         return;
      end if;
      Pos := Seq.Content.First;
      while Pos <= Seq.Content.Last loop
         Read_TLV (Cert, Pos, Seq.Content.Last, Ext);
         exit when not Ext.Valid or else Ext.Tag /= 16#30#;
         Ext_Pos := Ext.Content.First;
         Read_TLV (Cert, Ext_Pos, Ext.Content.Last, OID);
         if OID.Valid and then OID.Tag = 16#06# then
            declare
               Critical   : Boolean := False;
               Recognized : Boolean := False;
            begin
               --  Optional critical BOOLEAN (DER omits it when FALSE); record it,
               --  then take the extnValue OCTET STRING.
               Ext_Pos := OID.Elem_Last + 1;
               Read_TLV (Cert, Ext_Pos, Ext.Content.Last, Val);
               if Val.Valid and then Val.Tag = 16#01# then
                  --  critical BOOLEAN
                  Critical := Length (Val.Content) >= 1 and then Cert (Val.Content.First) /= 0;
                  Ext_Pos := Val.Elem_Last + 1;
                  Read_TLV (Cert, Ext_Pos, Ext.Content.Last, Val);
               end if;
               if Val.Valid and then Val.Tag = 16#04# then
                  --  extnValue OCTET STRING
                  if Is_Ext_OID (Cert, OID.Content, 16#11#) then
                     --  subjectAltName
                     Parse_SAN (Cert, Val.Content.First, Val.Content.Last, Result);
                     Recognized := True;
                  elsif Is_Ext_OID (Cert, OID.Content, 16#13#) then
                     --  basicConstraints
                     Parse_Basic_Constraints (Cert, Val.Content.First, Val.Content.Last, Result);
                     Recognized := True;
                  elsif Is_Ext_OID (Cert, OID.Content, 16#0F#) then
                     --  keyUsage
                     Parse_Key_Usage (Cert, Val.Content.First, Val.Content.Last, Result);
                     Recognized := True;
                  elsif Is_Ext_OID (Cert, OID.Content, 16#25#) then
                     --  extKeyUsage
                     Parse_EKU (Cert, Val.Content.First, Val.Content.Last, Result);
                     Recognized := True;
                  end if;
               end if;

               --  RFC 5280 4.2: reject the certificate if it carries a critical
               --  extension we do not recognize / process.
               if Critical and then not Recognized then
                  Result.Unhandled_Critical := True;
               end if;
            end;
         end if;
         Pos := Ext.Elem_Last + 1;
      end loop;
   end Parse_Extensions;

   --  validity ::= SEQUENCE { notBefore Time, notAfter Time }.  Both are read
   --  with Want = 0: UTCTime and GeneralizedTime are both accepted and the tag
   --  is recorded, because Valid_At needs it to pick the century rule.
   procedure Parse_Validity
     (Cert : Byte_Array; Validity : DER.TLV; Result : in out Certificate; Ok : in out Boolean)
   is
      Pos    : Natural := Validity.Content.First;
      Last   : constant Natural := Validity.Content.Last;
      NB, NA : DER.TLV;
   begin
      Expect (Cert, Pos, Last, 0, NB, Ok);
      Result.Not_Before := NB.Content;
      Result.NB_Tag := NB.Tag;
      Pos := NB.Elem_Last + 1;
      Expect (Cert, Pos, Last, 0, NA, Ok);
      Result.Not_After := NA.Content;
      Result.NA_Tag := NA.Tag;
   end Parse_Validity;

   --  The namedCurve OID inside an EC AlgorithmIdentifier.  Only the two curves
   --  this stack can actually verify with are accepted; anything else clears Ok.
   procedure Classify_EC_Curve
     (Cert : Byte_Array; Curve : DER.TLV; Result : in out Certificate; Ok : in out Boolean) is
   begin
      if Ok and then OID_Match (Cert, Curve.Content, OID_P256_Curve) then
         Result.Key_Kind := Key_EC_P256;
      elsif Ok and then OID_Match (Cert, Curve.Content, OID_P384_Curve) then
         Result.Key_Kind := Key_EC_P384;
      else
         Ok := False;                             --  unsupported curve
      end if;
   end Classify_EC_Curve;

   --  AlgorithmIdentifier ::= SEQUENCE { algorithm OID, parameters ANY }.  Sets
   --  Result.Key_Kind from the OID, and for EC also from the named-curve OID
   --  that follows it.  Anything we cannot verify with clears Ok rather than
   --  leaving Key_Other: a caller that forgot to reject Key_Other would
   --  otherwise treat an unusable key as parsed.
   procedure Classify_Key_Algorithm
     (Cert : Byte_Array; AlgId : DER.TLV; Result : in out Certificate; Ok : in out Boolean)
   is
      Pos        : Natural := AlgId.Content.First;
      Alg, Curve : DER.TLV;
   begin
      Expect (Cert, Pos, AlgId.Content.Last, 16#06#, Alg, Ok);
      if not Ok then
         return;
      end if;

      if OID_Match (Cert, Alg.Content, OID_RSA_Enc) then
         Result.Key_Kind := Key_RSA;
      elsif OID_Match (Cert, Alg.Content, OID_EC_PubKey) then
         --  EC: the named curve is the OID that follows the algorithm OID.
         Pos := Alg.Elem_Last + 1;
         Expect (Cert, Pos, AlgId.Content.Last, 16#06#, Curve, Ok);
         Classify_EC_Curve (Cert, Curve, Result, Ok);
      elsif OID_Match (Cert, Alg.Content, OID_Ed25519) then
         Result.Key_Kind := Key_Ed25519;          --  no params / no curve
      else
         Ok := False;                             --  unsupported key type
      end if;
   end Classify_Key_Algorithm;

   --  RSAPublicKey ::= SEQUENCE { modulus INTEGER, publicExponent INTEGER },
   --  inside the subjectPublicKey BIT STRING after its unused-bits byte.
   procedure Parse_RSA_Public_Key
     (Cert : Byte_Array; Bits : DER.TLV; Result : in out Certificate; Ok : in out Boolean)
   is
      RSASeq : DER.TLV;
   begin
      Expect (Cert, Bits.Content.First + 1, Bits.Content.Last, 16#30#, RSASeq, Ok);
      if not Ok then
         return;
      end if;
      declare
         Pos               : Natural := RSASeq.Content.First;
         Last              : constant Natural := RSASeq.Content.Last;
         Modulus, Exponent : DER.TLV;
      begin
         Expect (Cert, Pos, Last, 16#02#, Modulus, Ok);    --  modulus INTEGER
         Result.RSA_Modulus := Modulus.Content;
         Pos := Modulus.Elem_Last + 1;
         Expect (Cert, Pos, Last, 16#02#, Exponent, Ok);   --  publicExponent
         Result.RSA_Exponent := Exponent.Content;
      end;
   end Parse_RSA_Public_Key;

   --  The subjectPublicKey BIT STRING, once Key_Kind is known.  Its content is
   --  unused-bits(1) || key, so every offset below is measured from
   --  Bits.Content.First + 1.  A shape that does not match the classified kind
   --  clears Ok.
   procedure Parse_Key_Bits
     (Cert : Byte_Array; Bits : DER.TLV; Result : in out Certificate; Ok : in out Boolean) is
   begin
      if not Ok then
         return;
      end if;

      --  A case on the classified kind rather than a chain of and-then guards:
      --  each arm states the shape that kind requires.  Key_Other cannot reach
      --  here -- Classify_Key_Algorithm clears Ok rather than leaving it set.
      --
      --  The two EC arms keep their LITERAL lengths and offsets instead of
      --  sharing a Take_EC_Point (Size) helper.  That is deliberate: SPARK bounds
      --  the index from the literal in the Length guard, and factoring the
      --  coordinate width into a parameter -- or hoisting Bits.Content.First + 1
      --  into a constant above the guard -- each cost proofs that the literal
      --  form discharges for free.
      case Result.Key_Kind is
         when Key_RSA =>
            if Length (Bits.Content) >= 2 then
               Parse_RSA_Public_Key (Cert, Bits, Result, Ok);
            else
               Ok := False;
            end if;

         when Key_EC_P256 =>
            --  unused-bits(1) || 0x04 || X(32) || Y(32)
            if Length (Bits.Content) >= 66
              and then Cert (Bits.Content.First + 1) = 16#04#
            then
               Result.EC_X := (First => Bits.Content.First + 2, Last => Bits.Content.First + 33);
               Result.EC_Y := (First => Bits.Content.First + 34, Last => Bits.Content.First + 65);
            else
               Ok := False;
            end if;

         when Key_EC_P384 =>
            --  unused-bits(1) || 0x04 || X(48) || Y(48)
            if Length (Bits.Content) >= 98
              and then Cert (Bits.Content.First + 1) = 16#04#
            then
               Result.EC_X := (First => Bits.Content.First + 2, Last => Bits.Content.First + 49);
               Result.EC_Y := (First => Bits.Content.First + 50, Last => Bits.Content.First + 97);
            else
               Ok := False;
            end if;

         when Key_Ed25519 =>
            --  unused-bits(1) || 32-byte public key -- no point prefix.
            if Length (Bits.Content) >= 33 then
               Result.Ed_Pub :=
                 (First => Bits.Content.First + 1, Last => Bits.Content.First + 32);
            else
               Ok := False;
            end if;

         when Key_Other =>
            Ok := False;
      end case;
   end Parse_Key_Bits;

   --  subjectPublicKeyInfo ::= SEQUENCE { algorithm AlgorithmIdentifier,
   --                                      subjectPublicKey BIT STRING }
   procedure Parse_Public_Key
     (Cert : Byte_Array; SPKI : DER.TLV; Result : in out Certificate; Ok : in out Boolean)
   is
      Pos   : Natural := SPKI.Content.First;
      Last  : constant Natural := SPKI.Content.Last;
      AlgId : DER.TLV;
      Bits  : DER.TLV;
   begin
      Expect (Cert, Pos, Last, 16#30#, AlgId, Ok);        --  algorithm SEQUENCE
      Classify_Key_Algorithm (Cert, AlgId, Result, Ok);
      Pos := AlgId.Elem_Last + 1;
      Expect (Cert, Pos, Last, 16#03#, Bits, Ok);         --  subjectPublicKey BIT STRING
      if Ok and then not Whole_Octet_Bits (Cert, Bits.Content) then
         Ok := False;
      end if;
      Parse_Key_Bits (Cert, Bits, Result, Ok);
   end Parse_Public_Key;

   --  signatureAlgorithm's OID -> the algorithm it names, or Sig_Other.
   --
   --  A pure classification, so the "we cannot verify this, so it must not parse
   --  as Valid" POLICY is stated once at the call site instead of being buried
   --  in an Ok flag here.  (It also stops the parameter lying: an Ok that is only
   --  ever written cannot honestly be `in out`, and cannot be `out` either --
   --  the paths that recognise the OID must leave the caller's value alone.)
   function Signature_Kind (Cert : Byte_Array; OID_Bytes : Slice) return Sig_Algorithm
   is (if OID_Match (Cert, OID_Bytes, OID_RSA_SHA256) then Sig_RSA_SHA256
       elsif OID_Match (Cert, OID_Bytes, OID_RSA_SHA384) then Sig_RSA_SHA384
       elsif OID_Match (Cert, OID_Bytes, OID_RSA_SHA512) then Sig_RSA_SHA512
       elsif OID_Match (Cert, OID_Bytes, OID_ECDSA_SHA256) then Sig_ECDSA_SHA256
       elsif OID_Match (Cert, OID_Bytes, OID_ECDSA_SHA384) then Sig_ECDSA_SHA384
       elsif OID_Match (Cert, OID_Bytes, OID_Ed25519) then Sig_Ed25519
       else Sig_Other)
   with Pre => In_Buffer (Cert, OID_Bytes);

   --  Everything after tbsCertificate: signatureAlgorithm and signatureValue.
   --  Split out of Parse because it is a separate concern from walking the
   --  signed body -- and because these are the two fields NOT covered by the
   --  signature, so what they are checked against is the point of the code.
   --  Inner_Alg is the AlgorithmIdentifier from inside tbsCertificate.
   --  A first/last index pair carried as one value, so a call cannot pass the
   --  two the wrong way round.
   type Span is record
      From  : Natural;    --  first index to read
      Limit : Natural;    --  last index that may be read
   end record;

   --  The optional extensions field, which is where subjectAltName, the usage
   --  extensions and any unrecognised critical extension are found.  Absent is
   --  not an error: a certificate without extensions is a certificate whose
   --  policy fields simply do not restrict anything.
   procedure Parse_Optional_Extensions
     (Cert : Byte_Array; Where : Span; Result : in out Certificate)
   is
      Elem : DER.TLV;
   begin
      Read_TLV (Cert, Where.From, Where.Limit, Elem);
      if Elem.Valid and then Elem.Tag = 16#A3# then
         Parse_Extensions (Cert, Elem.Content.First, Elem.Content.Last, Result);
      end if;
   end Parse_Optional_Extensions;

   procedure Parse_Signature_Tail
     (Cert      : Byte_Array;
      Where     : Span;
      Inner_Alg : DER.TLV;
      Result    : in out Certificate;
      Ok        : in out Boolean)
   is
      SigAlg, OID, SigVal : DER.TLV;
      Pos                 : Natural;
   begin
      --  signatureAlgorithm SEQUENCE { OID ... }
      Pos := Where.From;
      Expect (Cert, Pos, Where.Limit, 16#30#, SigAlg, Ok);
      Expect (Cert, SigAlg.Content.First, SigAlg.Content.Last, 16#06#, OID, Ok);
      Result.Sig_Alg_OID := OID.Content;
      --  DER gives one encoding per value, so "the same identifier" is the
      --  same bytes.
      if Ok
        and then not Same_Content
                    (Cert, (Signed => Inner_Alg.Content, Outer => SigAlg.Content))
      then
         Ok := False;
      end if;
      if Ok then
         Result.Sig_Kind := Signature_Kind (Cert, OID.Content);
         --  An unknown signatureAlgorithm means we cannot verify this
         --  certificate's signature, so it must not parse as Valid -- otherwise
         --  a caller that forgets to reject Sig_Other treats an unverifiable
         --  cert as trusted.  (Matches how an unknown key type is rejected.)
         if Result.Sig_Kind = Sig_Other then
            Ok := False;
         end if;
      end if;
      Pos := SigAlg.Elem_Last + 1;

      --  signatureValue BIT STRING (drop the leading unused-bits byte, which
      --  must be zero: a signature is a whole number of octets, X.690 8.6.2.2.
      --  It is outside the signed region, so accepting any value there gave the
      --  same signature 256 encodings).  At least one byte has to follow it.
      Expect (Cert, Pos, Where.Limit, 16#03#, SigVal, Ok);
      if Ok
        and then Length (SigVal.Content) >= 2
        and then Cert (SigVal.Content.First) = 0
      then
         Result.Signature := (First => SigVal.Content.First + 1, Last => SigVal.Content.Last);
      else
         Ok := False;
      end if;

   end Parse_Signature_Tail;

   procedure Parse (Cert : Byte_Array; Result : out Certificate) is
      Ok                                                                  : Boolean := True;
      Outer, Tbs, Elem, Validity, SPKI, Inner_Alg : DER.TLV;
      Pos, Limit                                                          : Natural;
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

      Pos := Tbs.Content.First;
      Limit := Tbs.Content.Last;

      --  version [0] EXPLICIT -- optional.
      Read_TLV (Cert, Pos, Limit, Elem);
      if Elem.Valid and then Elem.Tag = 16#A0# then
         Pos := Elem.Elem_Last + 1;
      end if;

      --  serialNumber INTEGER
      Expect (Cert, Pos, Limit, 16#02#, Elem, Ok);
      Result.Serial := Elem.Content;
      Pos := Elem.Elem_Last + 1;

      --  signature AlgorithmIdentifier.  Kept, not skipped: this is the copy
      --  the CA signed, and the outer signatureAlgorithm read further down is
      --  the copy anyone can rewrite.  RFC 5280 4.1.1.2 requires the two to be
      --  the same identifier, and the comparison below is what makes that true
      --  here -- without it the verifier takes the algorithm to use from the
      --  unsigned copy.
      Expect (Cert, Pos, Limit, 16#30#, Inner_Alg, Ok);
      Pos := Inner_Alg.Elem_Last + 1;

      --  issuer Name  (skip)
      Expect (Cert, Pos, Limit, 16#30#, Elem, Ok);
      Pos := Elem.Elem_Last + 1;

      --  validity SEQUENCE { notBefore Time, notAfter Time }
      Expect (Cert, Pos, Limit, 16#30#, Validity, Ok);
      if Ok then
         Parse_Validity (Cert, Validity, Result, Ok);
      end if;
      Pos := Validity.Elem_Last + 1;

      --  subject Name  (skip)
      Expect (Cert, Pos, Limit, 16#30#, Elem, Ok);
      Pos := Elem.Elem_Last + 1;

      --  subjectPublicKeyInfo SEQUENCE { algorithm, subjectPublicKey BIT STRING }
      Expect (Cert, Pos, Limit, 16#30#, SPKI, Ok);
      if Ok then
         Parse_Public_Key (Cert, SPKI, Result, Ok);
      end if;

      --  extensions [3] EXPLICIT -- optional; we pull subjectAltName dNSNames.
      if Ok then
         Parse_Optional_Extensions
           (Cert, (From => SPKI.Elem_Last + 1, Limit => Limit), Result);
      end if;

      Parse_Signature_Tail
        (Cert,
         (From => Tbs.Elem_Last + 1, Limit => Outer.Content.Last),
         Inner_Alg, Result, Ok);

      --  RFC 5280 4.2: a cert with an unrecognized critical extension is invalid,
      --  even if it is otherwise structurally sound.
      Result.Valid := Ok and then not Result.Unhandled_Critical;
   end Parse;

   ---------------------------------------------------------------------------
   --  Validity dates
   ---------------------------------------------------------------------------

   --  Parse an ASN.1 Time (UTCTime YYMMDDHHMMSSZ or GeneralizedTime
   --  YYYYMMDDHHMMSSZ) at slice S into a packed Time_64.  False if malformed.
   --  A procedure (not a function): SPARK forbids a function with an out
   --  parameter, so returning the packed time via T plus a success flag Ok keeps
   --  the profile legal.  This time/date arithmetic is the one part that is left
   --  outside SPARK (SPARK_Mode => Off) -- it reads a Certificate's stored slice,
   --  which carries no invariant tying it to Cert -- so Valid_At below is Off too.
   procedure Parse_Time
     (Cert : Byte_Array; S : Slice; Tag : U8; T : out Time_64; Ok : out Boolean)
     with SPARK_Mode => Off
   is
      First                                  : constant Natural := S.First;
      Len                                    : constant Natural := Length (S);
      Base                                   : Natural;
      Year, Month, Day, Hour, Minute, Second : Natural;

      function Is_Digit (Off : Natural) return Boolean
      is (Cert (First + Off) in 16#30# .. 16#39#);
      function Digit (Off : Natural) return Natural
      is (Natural (Cert (First + Off)) - 16#30#);
      function Two (Off : Natural) return Natural
      is (Digit (Off) * 10 + Digit (Off + 1));
   begin
      T := 0;
      Ok := False;
      if Tag = 16#17# then
         --  UTCTime (13: YYMMDDHHMMSSZ)
         if Len /= 13 or else Cert (First + 12) /= 16#5A# then
            return;
         end if;
         for K in 0 .. 11 loop
            if not Is_Digit (K) then
               return;
            end if;
         end loop;
         Year := (if Two (0) < 50 then 2000 + Two (0) else 1900 + Two (0));
         Base := 2;
      elsif Tag = 16#18# then
         --  GeneralizedTime (15)
         if Len /= 15 or else Cert (First + 14) /= 16#5A# then
            return;
         end if;
         for K in 0 .. 13 loop
            if not Is_Digit (K) then
               return;
            end if;
         end loop;
         Year := Digit (0) * 1000 + Digit (1) * 100 + Digit (2) * 10 + Digit (3);
         Base := 4;
      else
         return;
      end if;
      Month := Two (Base);
      Day := Two (Base + 2);
      Hour := Two (Base + 4);
      Minute := Two (Base + 6);
      Second := Two (Base + 8);
      if Month not in 1 .. 12
        or else Day not in 1 .. 31
        or else Hour > 23
        or else Minute > 59
        or else Second > 60
      then
         return;
      end if;
      T := Pack_Time (Year, Month, Day, Hour, Minute, Second);
      Ok := True;
   end Parse_Time;

   function Valid_At (Cert : Byte_Array; C : Certificate; Now : Time_64) return Boolean
     with SPARK_Mode => Off
   is
      NB, NA         : Time_64;
      NB_Ok, NA_Ok   : Boolean;
   begin
      Parse_Time (Cert, C.Not_Before, C.NB_Tag, NB, NB_Ok);
      Parse_Time (Cert, C.Not_After, C.NA_Tag, NA, NA_Ok);
      if not NB_Ok or else not NA_Ok then
         return False;
      end if;
      return Now >= NB and then Now <= NA;
   end Valid_At;

   ---------------------------------------------------------------------------
   --  Hostname matching (subjectAltName dNSName)
   ---------------------------------------------------------------------------

   function Lower (B : U8) return U8
   is (if B in 16#41# .. 16#5A# then B + 16#20# else B);

   --  Case-insensitive equality of Cert[BF..BL] (ASCII bytes) and Host[HF..HL].
   --  The precondition says: whenever either range is non-empty it lies inside its
   --  container, so every indexed read below is in range.
   function Eq_CI
     (Cert : Byte_Array; BF, BL : Natural; Host : String; HF, HL : Natural) return Boolean
   with
     Pre =>
       (BF > BL or else (BF >= Cert'First and then BL <= Cert'Last))
       and then (HF > HL or else (HF >= Host'First and then HL <= Host'Last))
   is
   begin
      if BL < BF or else HL < HF or else BL - BF /= HL - HF then
         return False;
      end if;
      for K in 0 .. BL - BF loop
         pragma Loop_Invariant (BF + K <= BL and then HF + K <= HL);
         if Lower (Cert (BF + K)) /= Lower (U8 (Character'Pos (Host (HF + K)))) then
            return False;
         end if;
      end loop;
      return True;
   end Eq_CI;

   function Name_Matches (Cert : Byte_Array; S : Slice; Host : String) return Boolean is
      function Has_Dot (From, To : Natural) return Boolean
      with Pre => From > To or else (From >= Cert'First and then To <= Cert'Last)
      is
      begin
         for I in From .. To loop
            if Cert (I) = 16#2E# then
               return True;
            end if;
         end loop;
         return False;
      end Has_Dot;
   begin
      --  Reject an empty name/host, and defensively reject a slice that does not
      --  actually lie inside Cert (a well-parsed certificate never yields one, but
      --  the record carries no invariant tying its slices to this buffer): this
      --  establishes S.First .. S.Last are valid indices for all reads below.
      if Length (S) = 0
        or else Host'Length = 0
        or else S.First < Cert'First
        or else S.Last > Cert'Last
      then
         return False;
      end if;

      --  Wildcard "*." : match exactly one leftmost label of Host, and only where
      --  the remainder still has two labels (a dot).
      if Length (S) >= 2 and then Cert (S.First) = 16#2A# and then Cert (S.First + 1) = 16#2E# then
         declare
            Dot : Natural := 0;
         begin
            for I in Host'Range loop
               if Host (I) = '.' then
                  Dot := I;
                  exit;
               end if;
            end loop;
            if Dot = 0 or else Dot = Host'First then
               --  no / empty leftmost label
               return False;
            end if;
            return
              Eq_CI (Cert, S.First + 1, S.Last, Host, Dot, Host'Last)
              and then Has_Dot (S.First + 2, S.Last);
         end;
      else
         return Eq_CI (Cert, S.First, S.Last, Host, Host'First, Host'Last);
      end if;
   end Name_Matches;

   function Host_Matches (Cert : Byte_Array; C : Certificate; Host : String) return Boolean is
   begin
      --  Min guards the SAN array bound: Parse never stores more than Max_SAN, but
      --  the record type carries no such constraint, so clamp for a hostile C.
      for I in 1 .. Natural'Min (C.SAN_Count, Max_SAN) loop
         if Name_Matches (Cert, C.SAN (I), Host) then
            return True;
         end if;
      end loop;
      return False;
   end Host_Matches;

end X509;
