with Cert_Verify;

package body Chain_Verify is

   use type X509.Sig_Algorithm;
   use type X509.Key_Algorithm;

   --  An issuing certificate must be a CA: basicConstraints cA = TRUE, and if it
   --  carries a keyUsage extension it must assert keyCertSign (RFC 5280 4.2.1.3 /
   --  4.2.1.9).  Applied to every certificate that signs another, including the
   --  pinned anchor when it issues the top of the chain.
   function Is_Valid_CA (C : X509.Certificate) return Boolean is
     (C.Is_CA and then (not C.KU_Present or else C.KU_Cert_Sign));

   --  A TLS server leaf: if it restricts extKeyUsage it must allow id-kp-serverAuth,
   --  and if it restricts keyUsage it must allow digitalSignature (in TLS 1.3 the
   --  server signs CertificateVerify with this key).
   function Leaf_Usage_OK (C : X509.Certificate) return Boolean is
     ((not C.EKU_Present or else C.EKU_Server)
      and then (not C.KU_Present or else C.KU_Digital_Sig));

   --  Does Child's signature verify under Issuer's public key?  Dispatches on how
   --  the child was signed (RSA-PKCS1-SHA256, or ECDSA/P-256 with SHA-256/384) and
   --  requires the issuer to hold a matching key type.
   function Sig_OK (Child_Buf : X509.Byte_Array; Child : X509.Certificate;
                    Iss_Buf : X509.Byte_Array; Iss : X509.Certificate)
                    return Boolean
   is
      TBS : X509.Byte_Array renames Child_Buf (Child.TBS.First .. Child.TBS.Last);
      Sig : X509.Byte_Array renames
              Child_Buf (Child.Signature.First .. Child.Signature.Last);
   begin
      case Child.Sig_Kind is
         when X509.Sig_RSA_SHA256 =>
            return Iss.Key_Kind = X509.Key_RSA and then Cert_Verify.RSA_PKCS1_SHA256
              (TBS, Sig,
               Iss_Buf (Iss.RSA_Modulus.First .. Iss.RSA_Modulus.Last),
               Iss_Buf (Iss.RSA_Exponent.First .. Iss.RSA_Exponent.Last));
         when X509.Sig_RSA_SHA384 =>
            return Iss.Key_Kind = X509.Key_RSA and then Cert_Verify.RSA_PKCS1_SHA384
              (TBS, Sig,
               Iss_Buf (Iss.RSA_Modulus.First .. Iss.RSA_Modulus.Last),
               Iss_Buf (Iss.RSA_Exponent.First .. Iss.RSA_Exponent.Last));
         when X509.Sig_RSA_SHA512 =>
            return Iss.Key_Kind = X509.Key_RSA and then Cert_Verify.RSA_PKCS1_SHA512
              (TBS, Sig,
               Iss_Buf (Iss.RSA_Modulus.First .. Iss.RSA_Modulus.Last),
               Iss_Buf (Iss.RSA_Exponent.First .. Iss.RSA_Exponent.Last));
         when X509.Sig_Ed25519 =>
            return Iss.Key_Kind = X509.Key_Ed25519 and then Cert_Verify.Ed25519_Verify
              (TBS, Sig, Iss_Buf (Iss.Ed_Pub.First .. Iss.Ed_Pub.Last));
         when X509.Sig_ECDSA_SHA256 =>
            return Iss.Key_Kind = X509.Key_EC_P256 and then Cert_Verify.ECDSA_P256_SHA256
              (TBS, Sig,
               Iss_Buf (Iss.EC_X.First .. Iss.EC_X.Last),
               Iss_Buf (Iss.EC_Y.First .. Iss.EC_Y.Last));
         when X509.Sig_ECDSA_SHA384 =>
            return Iss.Key_Kind = X509.Key_EC_P256 and then Cert_Verify.ECDSA_P256_SHA384
              (TBS, Sig,
               Iss_Buf (Iss.EC_X.First .. Iss.EC_X.Last),
               Iss_Buf (Iss.EC_Y.First .. Iss.EC_Y.Last));
         when others =>
            return False;
      end case;
   end Sig_OK;

   function Validate
     (Chain, Anchors : Cert_List;
      Host           : String;
      Now            : X509.Time_64) return Result
   is
   begin
      if Chain'Length = 0 then
         return Malformed;
      end if;

      --  Leaf: parse and check the host name.
      declare
         LB   : X509.Byte_Array renames Chain (Chain'First).Data.all;
         Leaf : X509.Certificate;
      begin
         X509.Parse (LB, Leaf);
         if not Leaf.Valid then
            return Malformed;
         end if;
         if not X509.Host_Matches (LB, Leaf, Host) then
            return Name_Mismatch;
         end if;
         if not Leaf_Usage_OK (Leaf) then
            return Bad_Key_Usage;
         end if;
      end;

      --  Each certificate must be in date, and each link must be signed by the
      --  next certificate in the chain.
      for I in Chain'Range loop
         declare
            CB : X509.Byte_Array renames Chain (I).Data.all;
            C  : X509.Certificate;
         begin
            X509.Parse (CB, C);
            if not C.Valid then
               return Malformed;
            end if;
            if not X509.Valid_At (CB, C, Now) then
               return Expired;
            end if;
            if I < Chain'Last then
               declare
                  IB  : X509.Byte_Array renames Chain (I + 1).Data.all;
                  Iss : X509.Certificate;
               begin
                  X509.Parse (IB, Iss);
                  if not Iss.Valid then
                     return Malformed;
                  end if;
                  if not Sig_OK (CB, C, IB, Iss) then
                     return Bad_Signature;
                  end if;
                  if not Is_Valid_CA (Iss) then     --  intermediate must be a CA
                     return Not_A_CA;
                  end if;
               end;
            end if;
         end;
      end loop;

      --  Anchor the top: its signature must verify under a pinned root key.
      declare
         TB  : X509.Byte_Array renames Chain (Chain'Last).Data.all;
         Top : X509.Certificate;
      begin
         X509.Parse (TB, Top);                  --  re-parse (already known valid)
         for A in Anchors'Range loop
            declare
               AB : X509.Byte_Array renames Anchors (A).Data.all;
               Ac : X509.Certificate;
            begin
               X509.Parse (AB, Ac);
               if Ac.Valid and then Is_Valid_CA (Ac)
                 and then Sig_OK (TB, Top, AB, Ac)
               then
                  return Valid;
               end if;
            end;
         end loop;
      end;
      return Untrusted_Root;
   end Validate;

end Chain_Verify;
