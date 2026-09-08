--  Hold Chain_Verify to a verdict on certificates that are each wrong in one
--  named way.
--
--  This is the check that decides whether the device talks to the server it
--  meant to.  examples/esp32s3_x509_chain runs the same kind of table on the
--  board, which is the only place the RSA links can run (they go through the
--  chip's accelerator); this runs on the host so the POLICY -- validity dates,
--  host names, basicConstraints, key usage, anchoring -- is re-checked on
--  every push rather than the last time someone had a board in front of them.
--  The certificates are ECDSA P-256 and Ed25519, both pure Ada.
--
--  The last section is not a table: it flips one bit at a time through every
--  byte of a good chain and requires that no single-bit change anywhere in it
--  ever produces Valid, and that none of them raises.  A table only covers the
--  ways someone thought to be wrong.
with Ada.Command_Line;
with Ada.Directories;
with Ada.Streams.Stream_IO;
with Ada.Text_IO;    use Ada.Text_IO;
with Chain_Verify;   use Chain_Verify;
with X509;

procedure Chain_Host is

   use type X509.U8;

   Dir  : constant String := "fixtures/";
   Host : constant String := "test.example.com";

   --  Every fixture is valid 2020..2035 except the one named expired (2020..2021),
   --  so these three times sit inside the window, past it, and before it.
   Inside : constant X509.Time_64 := X509.Pack_Time (2026, 6, 1, 12, 0, 0);
   After  : constant X509.Time_64 := X509.Pack_Time (2040, 1, 1, 0, 0, 0);
   Before : constant X509.Time_64 := X509.Pack_Time (2019, 1, 1, 0, 0, 0);

   Failures : Natural := 0;
   Checks   : Natural := 0;

   ------------------------------------------------------------------
   --  Fixtures
   ------------------------------------------------------------------

   --  Certificates are held on the heap so each one is exactly as long as its
   --  file: a padded buffer would make a truncated certificate un-truncated
   --  again, which is the opposite of what the malformed case is testing.
   --  Nothing is freed -- the process is about to exit.
   function Load (Name : String) return Cert_Data_Ref is
      package IO renames Ada.Streams.Stream_IO;
      Path : constant String := Dir & Name & ".der";
      Size : constant Natural := Natural (Ada.Directories.Size (Path));
      Data : X509.Byte_Array (0 .. Size - 1);
      F    : IO.File_Type;
   begin
      IO.Open (F, IO.In_File, Path);
      X509.Byte_Array'Read (IO.Stream (F), Data);
      IO.Close (F);
      return new X509.Byte_Array'(Data);
   end Load;

   --  The same certificate with one bit flipped -- a forgery that is otherwise
   --  byte-for-byte what the CA signed.
   function Flip (Base : Cert_Data_Ref; At_Byte : Natural; Bit : Natural)
      return Cert_Data_Ref
   is
      Data : X509.Byte_Array := Base.all;
   begin
      Data (At_Byte) := Data (At_Byte) xor X509.U8 (2 ** Bit);
      return new X509.Byte_Array'(Data);
   end Flip;

   function Cut (Base : Cert_Data_Ref; To_Length : Natural) return Cert_Data_Ref
   is (new X509.Byte_Array'(Base (Base'First .. Base'First + To_Length - 1)));

   Root       : constant Cert_Data_Ref := Load ("root");
   Inter      : constant Cert_Data_Ref := Load ("inter");
   Leaf       : constant Cert_Data_Ref := Load ("leaf");
   Stale      : constant Cert_Data_Ref := Load ("leaf_expired");
   Client_EKU : constant Cert_Data_Ref := Load ("leaf_clientauth");
   Not_CA     : constant Cert_Data_Ref := Load ("notca");
   Under_Not  : constant Cert_Data_Ref := Load ("leaf_under_notca");
   Other      : constant Cert_Data_Ref := Load ("other_root");
   Ed_Root    : constant Cert_Data_Ref := Load ("ed_root");
   Ed_Leaf    : constant Cert_Data_Ref := Load ("ed_leaf");

   function R (D : Cert_Data_Ref) return Cert_Ref is (Data => D);

   ------------------------------------------------------------------

   procedure Check (Label : String; Got, Want : Result) is
   begin
      Checks := Checks + 1;
      if Got = Want then
         Put_Line ("  ok    " & Label);
      else
         Failures := Failures + 1;
         Put_Line ("  FAIL  " & Label & "  (wanted " & Result'Image (Want)
                   & ", got " & Result'Image (Got) & ")");
      end if;
   end Check;

begin
   Put_Line ("[chain] certificate-chain validation, ECDSA P-256 and Ed25519");

   --  What a good connection looks like, three ways.
   Check ("full chain, root pinned",
          Validate ((R (Leaf), R (Inter)), (1 => R (Root)), Host, Inside), Valid);
   Check ("leaf alone, its issuer pinned",
          Validate ((1 => R (Leaf)), (1 => R (Inter)), Host, Inside), Valid);
   Check ("Ed25519 chain",
          Validate ((1 => R (Ed_Leaf)), (1 => R (Ed_Root)), Host, Inside), Valid);

   --  Host names.  The leaf covers test.example.com outright and one label
   --  under wild.example.com; a wildcard covers ONE label, which is the whole
   --  point of the rule.
   Check ("wildcard covers one label",
          Validate ((R (Leaf), R (Inter)), (1 => R (Root)), "a.wild.example.com", Inside),
          Valid);
   Check ("wildcard does not cover two",
          Validate ((R (Leaf), R (Inter)), (1 => R (Root)), "a.b.wild.example.com", Inside),
          Name_Mismatch);
   Check ("a different host entirely",
          Validate ((R (Leaf), R (Inter)), (1 => R (Root)), "evil.example.com", Inside),
          Name_Mismatch);
   Check ("the host as a suffix of another",
          Validate ((R (Leaf), R (Inter)), (1 => R (Root)), "nottest.example.com", Inside),
          Name_Mismatch);

   --  Validity window, from both sides.
   Check ("leaf that has expired",
          Validate ((R (Stale), R (Inter)), (1 => R (Root)), Host, Inside), Expired);
   Check ("evaluated past every notAfter",
          Validate ((R (Leaf), R (Inter)), (1 => R (Root)), Host, After), Expired);
   Check ("evaluated before every notBefore",
          Validate ((R (Leaf), R (Inter)), (1 => R (Root)), Host, Before), Expired);

   --  Anchoring and the links between certificates.
   Check ("root not among the anchors",
          Validate ((R (Leaf), R (Inter)), (1 => R (Other)), Host, Inside),
          Untrusted_Root);
   Check ("intermediate left out",
          Validate ((1 => R (Leaf)), (1 => R (Root)), Host, Inside), Untrusted_Root);
   Check ("a link that was never signed",
          Validate ((R (Leaf), R (Leaf)), (1 => R (Root)), Host, Inside), Bad_Signature);

   --  The extensions that say what a certificate is allowed to be used for.
   Check ("issuer marked CA:FALSE",
          Validate ((R (Under_Not), R (Not_CA)), (1 => R (Root)), Host, Inside), Not_A_CA);
   Check ("leaf whose extKeyUsage is clientAuth",
          Validate ((R (Client_EKU), R (Inter)), (1 => R (Root)), Host, Inside),
          Bad_Key_Usage);

   --  Certificates that are not certificates.
   Check ("leaf cut in half",
          Validate ((R (Cut (Leaf, Leaf'Length / 2)), R (Inter)), (1 => R (Root)),
                    Host, Inside),
          Malformed);
   Check ("leaf cut to one byte",
          Validate ((R (Cut (Leaf, 1)), R (Inter)), (1 => R (Root)), Host, Inside),
          Malformed);

   --  And now the part no table covers: every single-bit change to a good
   --  chain, each one asked whether it is still a valid chain.  The answer has
   --  to be no every time -- a bit in the TBS breaks the issuer's signature, a
   --  bit in the signature breaks it the other way round, and a bit in the
   --  outer structure stops it parsing.  Anything that still came back Valid
   --  would be a certificate the CA did not sign and the client accepted.
   --
   --  Only certificates the chain has to VERIFY are swept.  A pinned anchor is
   --  trusted for being pinned, so a bit changed inside one is a different
   --  anchor rather than a forgery, and "it still validates" would say nothing.
   declare
      Accepted : Natural := 0;
      Tried    : Natural := 0;

      procedure Sweep
        (Which  : String;
         Base   : Cert_Data_Ref;    --  the certificate whose bits get flipped
         Issuer : Cert_Data_Ref;    --  the rest of the chain, or null for none
         Anchor : Cert_Data_Ref)
      is
         Verdict : Result;
      begin
         for At_Byte in Base'Range loop
            for Bit in 0 .. 7 loop
               declare
                  Forged : constant Cert_Ref := R (Flip (Base, At_Byte, Bit));
                  Chain  : constant Cert_List :=
                    (if Issuer = null then (1 => Forged) else (Forged, R (Issuer)));
               begin
                  Tried := Tried + 1;
                  Verdict := Validate (Chain, (1 => R (Anchor)), Host, Inside);
                  if Verdict = Valid then
                     Accepted := Accepted + 1;
                     if Accepted <= 8 then
                        Put_Line ("        " & Which & " byte" & At_Byte'Image
                                  & " bit" & Bit'Image & " still validates");
                     end if;
                  end if;
               end;
            end loop;
         end loop;
      end Sweep;
   begin
      Sweep ("leaf", Leaf, Inter, Root);
      Sweep ("intermediate", Inter, Leaf, Root);
      Sweep ("Ed25519 leaf", Ed_Leaf, null, Ed_Root);
      Checks := Checks + 1;
      if Accepted = 0 then
         Put_Line ("  ok    no single-bit forgery validates ("
                   & Tried'Image & " tried, none raised)");
      else
         Failures := Failures + 1;
         Put_Line ("  FAIL " & Accepted'Image & " of" & Tried'Image
                   & " single-bit forgeries validated");
      end if;
   end;

   --  RSA is verified on the board (the chip's accelerator does the modexp),
   --  but it is PARSED by the same code as everything else, and the parser is
   --  where the DER rules live.  Reject an RSA certificate here and the real
   --  trust anchors go with it, so each one is parsed and asked what it is.
   declare
      procedure Parses (Label, Name : String;
                        Key : X509.Key_Algorithm; Sig : X509.Sig_Algorithm)
      is
         use type X509.Key_Algorithm;
         use type X509.Sig_Algorithm;
         DER  : constant Cert_Data_Ref := Load (Name);
         Cert : X509.Certificate;
      begin
         X509.Parse (DER.all, Cert);
         Checks := Checks + 1;
         if Cert.Valid and then Cert.Key_Kind = Key and then Cert.Sig_Kind = Sig then
            Put_Line ("  ok    " & Label);
         else
            Failures := Failures + 1;
            Put_Line ("  FAIL  " & Label & "  (valid " & Cert.Valid'Image
                      & ", key " & Cert.Key_Kind'Image
                      & ", sig " & Cert.Sig_Kind'Image & ")");
         end if;
      end Parses;
   begin
      Parses ("RSA/SHA-256 root parses", "rsa_root_sha256",
              X509.Key_RSA, X509.Sig_RSA_SHA256);
      Parses ("RSA/SHA-256 leaf parses", "rsa_leaf_sha256",
              X509.Key_RSA, X509.Sig_RSA_SHA256);
      Parses ("RSA/SHA-384 leaf parses", "rsa_leaf_sha384",
              X509.Key_RSA, X509.Sig_RSA_SHA384);
      Parses ("RSA/SHA-512 leaf parses", "rsa_leaf_sha512",
              X509.Key_RSA, X509.Sig_RSA_SHA512);
      Parses ("P-256 leaf parses", "leaf", X509.Key_EC_P256, X509.Sig_ECDSA_SHA256);
      Parses ("Ed25519 leaf parses", "ed_leaf", X509.Key_Ed25519, X509.Sig_Ed25519);
   end;

   New_Line;
   if Failures = 0 then
      Put_Line ("[chain]" & Checks'Image & " checks, all as expected");
   else
      Put_Line ("[chain]" & Failures'Image & " of" & Checks'Image & " went wrong");
      Ada.Command_Line.Set_Exit_Status (1);
   end if;
end Chain_Host;
