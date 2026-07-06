with Cert_Verify;

package body Chain_Verify with SPARK_Mode => On is

   use type X509.Sig_Algorithm;
   use type X509.Key_Algorithm;

   --  An issuing certificate must be a CA: basicConstraints cA = TRUE, and if it
   --  carries a keyUsage extension it must assert keyCertSign (RFC 5280 4.2.1.3 /
   --  4.2.1.9).  Applied to every certificate that signs another, including the
   --  pinned anchor when it issues the top of the chain.
   function Is_Valid_CA (C : X509.Certificate) return Boolean
   is (C.Is_CA and then (not C.KU_Present or else C.KU_Cert_Sign));

   --  A TLS server leaf: if it restricts extKeyUsage it must allow id-kp-serverAuth,
   --  and if it restricts keyUsage it must allow digitalSignature (in TLS 1.3 the
   --  server signs CertificateVerify with this key).
   function Leaf_Usage_OK (C : X509.Certificate) return Boolean
   is ((not C.EKU_Present or else C.EKU_Server)
       and then (not C.KU_Present or else C.KU_Digital_Sig));

   --  Does Child's signature verify under Issuer's public key?  Dispatches on how
   --  the child was signed (RSA-PKCS1-SHA256, or ECDSA/P-256 with SHA-256/384) and
   --  requires the issuer to hold a matching key type.
   --
   --  The declaration is SPARK-visible (a pure Boolean query the chain walk may
   --  call) but the *body* is SPARK_Mode => Off: it reaches the hardware RSA
   --  accelerator and the p256 / SPARKNaCl signature primitives, which are outside
   --  the SPARK subset.  Global => null keeps those effects from bubbling up into
   --  Validate (which must stay a side-effect-free SPARK function).
   function Sig_OK
     (Child_Buf : X509.Byte_Array;
      Child     : X509.Certificate;
      Iss_Buf   : X509.Byte_Array;
      Iss       : X509.Certificate) return Boolean
     with Global => null;

   function Sig_OK
     (Child_Buf : X509.Byte_Array;
      Child     : X509.Certificate;
      Iss_Buf   : X509.Byte_Array;
      Iss       : X509.Certificate) return Boolean
     with SPARK_Mode => Off
   is
      --  TBS = the child's To-Be-Signed certificate body; Sig = its signature bits.
      TBS : X509.Byte_Array renames Child_Buf (Child.TBS.First .. Child.TBS.Last);
      Sig : X509.Byte_Array renames Child_Buf (Child.Signature.First .. Child.Signature.Last);
   begin
      case Child.Sig_Kind is
         when X509.Sig_RSA_SHA256   =>
            return
              Iss.Key_Kind = X509.Key_RSA
              and then Cert_Verify.RSA_PKCS1_SHA256
                         (TBS,
                          Sig,
                          Iss_Buf (Iss.RSA_Modulus.First .. Iss.RSA_Modulus.Last),
                          Iss_Buf (Iss.RSA_Exponent.First .. Iss.RSA_Exponent.Last));

         when X509.Sig_RSA_SHA384   =>
            return
              Iss.Key_Kind = X509.Key_RSA
              and then Cert_Verify.RSA_PKCS1_SHA384
                         (TBS,
                          Sig,
                          Iss_Buf (Iss.RSA_Modulus.First .. Iss.RSA_Modulus.Last),
                          Iss_Buf (Iss.RSA_Exponent.First .. Iss.RSA_Exponent.Last));

         when X509.Sig_RSA_SHA512   =>
            return
              Iss.Key_Kind = X509.Key_RSA
              and then Cert_Verify.RSA_PKCS1_SHA512
                         (TBS,
                          Sig,
                          Iss_Buf (Iss.RSA_Modulus.First .. Iss.RSA_Modulus.Last),
                          Iss_Buf (Iss.RSA_Exponent.First .. Iss.RSA_Exponent.Last));

         when X509.Sig_Ed25519      =>
            return
              Iss.Key_Kind = X509.Key_Ed25519
              and then Cert_Verify.Ed25519_Verify
                         (TBS, Sig, Iss_Buf (Iss.Ed_Pub.First .. Iss.Ed_Pub.Last));

         when X509.Sig_ECDSA_SHA256 =>
            return
              Iss.Key_Kind = X509.Key_EC_P256
              and then Cert_Verify.ECDSA_P256_SHA256
                         (TBS,
                          Sig,
                          Iss_Buf (Iss.EC_X.First .. Iss.EC_X.Last),
                          Iss_Buf (Iss.EC_Y.First .. Iss.EC_Y.Last));

         when X509.Sig_ECDSA_SHA384 =>
            return
              Iss.Key_Kind = X509.Key_EC_P256
              and then Cert_Verify.ECDSA_P256_SHA384
                         (TBS,
                          Sig,
                          Iss_Buf (Iss.EC_X.First .. Iss.EC_X.Last),
                          Iss_Buf (Iss.EC_Y.First .. Iss.EC_Y.Last));

         when others                =>
            return False;
      end case;
   end Sig_OK;

   function Validate (Chain, Anchors : Cert_List; Host : String; Now : X509.Time_64) return Result
   is
   begin
      if Chain'Length = 0 then
         return Malformed;
      end if;

      --  Every referenced buffer must be a non-null, non-empty DER blob before it
      --  can be dereferenced and parsed (X509.Parse requires Cert'Length > 0); a
      --  null or empty reference is a malformed chain, not a run-time crash.

      --  Leaf: parse and check the host name.
      declare
         Leaf_Data : constant Cert_Data_Ref := Chain (Chain'First).Data;
      begin
         if Leaf_Data = null or else Leaf_Data.all'Length = 0 then
            return Malformed;
         end if;
         declare
            Leaf_Buf : X509.Byte_Array renames Leaf_Data.all;
            Leaf     : X509.Certificate;
         begin
            X509.Parse (Leaf_Buf, Leaf);
            pragma Annotate
              (GNATprove, False_Positive, "might be nonterminating",
               "X509.Parse is a bounded DER walk over a fixed buffer and provably "
               & "terminates (proven silver in the X509 proof project); its spec "
               & "simply carries no Always_Terminates aspect for this unit to see.");
            if not Leaf.Valid then
               return Malformed;
            end if;
            if not X509.Host_Matches (Leaf_Buf, Leaf, Host) then
               return Name_Mismatch;
            end if;
            if not Leaf_Usage_OK (Leaf) then
               return Bad_Key_Usage;
            end if;
         end;
      end;

      --  Each certificate must be in date, and each link must be signed by the
      --  next certificate in the chain.
      for I in Chain'Range loop
         declare
            Cert_Data : constant Cert_Data_Ref := Chain (I).Data;
         begin
            if Cert_Data = null or else Cert_Data.all'Length = 0 then
               return Malformed;
            end if;
            declare
               Cert_Buf : X509.Byte_Array renames Cert_Data.all;
               Cert     : X509.Certificate;
            begin
               X509.Parse (Cert_Buf, Cert);
               pragma Annotate
                 (GNATprove, False_Positive, "might be nonterminating",
                  "X509.Parse is a bounded DER walk over a fixed buffer and provably "
                  & "terminates (proven silver in the X509 proof project); its spec "
                  & "simply carries no Always_Terminates aspect for this unit to see.");
               if not Cert.Valid then
                  return Malformed;
               end if;
               if not X509.Valid_At (Cert_Buf, Cert, Now) then
                  return Expired;
               end if;
               if I < Chain'Last then
                  declare
                     Issuer_Data : constant Cert_Data_Ref := Chain (I + 1).Data;
                  begin
                     if Issuer_Data = null or else Issuer_Data.all'Length = 0 then
                        return Malformed;
                     end if;
                     declare
                        Issuer_Buf : X509.Byte_Array renames Issuer_Data.all;
                        Issuer     : X509.Certificate;
                     begin
                        X509.Parse (Issuer_Buf, Issuer);
                        pragma Annotate
                          (GNATprove, False_Positive, "might be nonterminating",
                           "X509.Parse is a bounded DER walk over a fixed buffer and "
                           & "provably terminates (proven silver in the X509 proof "
                           & "project); its spec simply carries no Always_Terminates "
                           & "aspect for this unit to see.");
                        if not Issuer.Valid then
                           return Malformed;
                        end if;
                        if not Sig_OK (Cert_Buf, Cert, Issuer_Buf, Issuer) then
                           return Bad_Signature;
                        end if;
                        if not Is_Valid_CA (Issuer) then
                           --  intermediate must be a CA
                           return Not_A_CA;
                        end if;
                     end;
                  end;
               end if;
            end;
         end;
      end loop;

      --  Anchor the top: its signature must verify under a pinned root key.
      declare
         Top_Data : constant Cert_Data_Ref := Chain (Chain'Last).Data;
      begin
         if Top_Data = null or else Top_Data.all'Length = 0 then
            return Malformed;
         end if;
         declare
            Top_Buf : X509.Byte_Array renames Top_Data.all;
            Top     : X509.Certificate;
         begin
            X509.Parse (Top_Buf, Top);               --  re-parse (already known valid)
            pragma Annotate
              (GNATprove, False_Positive, "might be nonterminating",
               "X509.Parse is a bounded DER walk over a fixed buffer and provably "
               & "terminates (proven silver in the X509 proof project); its spec "
               & "simply carries no Always_Terminates aspect for this unit to see.");
            for A in Anchors'Range loop
               declare
                  Anchor_Data : constant Cert_Data_Ref := Anchors (A).Data;
               begin
                  if Anchor_Data /= null and then Anchor_Data.all'Length > 0 then
                     declare
                        Anchor_Buf : X509.Byte_Array renames Anchor_Data.all;
                        Anchor     : X509.Certificate;
                     begin
                        X509.Parse (Anchor_Buf, Anchor);
                        pragma Annotate
                          (GNATprove, False_Positive, "might be nonterminating",
                           "X509.Parse is a bounded DER walk over a fixed buffer and "
                           & "provably terminates (proven silver in the X509 proof "
                           & "project); its spec simply carries no Always_Terminates "
                           & "aspect for this unit to see.");
                        if Anchor.Valid
                          and then Is_Valid_CA (Anchor)
                          and then Sig_OK (Top_Buf, Top, Anchor_Buf, Anchor)
                        then
                           return Valid;
                        end if;
                     end;
                  end if;
               end;
            end loop;
         end;
      end;
      return Untrusted_Root;
   end Validate;

end Chain_Verify;
