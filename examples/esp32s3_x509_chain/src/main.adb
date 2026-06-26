--  X.509 certificate-chain validation on the bare-metal ESP32-S3 (no FreeRTOS,
--  no IDF)
--  =====================================================================
--  What it demonstrates:
--    The trust *policy* layered on top of the crypto we already have -- a leaf
--    certificate signed by a CA, anchored to a pinned CA root.  Each case feeds
--    Chain_Verify.Validate an ordered chain (leaf first), a set of pinned trust
--    anchors, a host name and a wall-clock time, and asserts the verdict.
--    Between them the cases exercise every distinct Result the validator can
--    return: a good chain (Valid), the leaf alone re-anchored to its issuer
--    (Valid), a host-name miss (Name_Mismatch), evaluation past the validity
--    window (Expired), a forged link (Bad_Signature), an unpinned root
--    (Untrusted_Root), an issuer that is not a CA -- basicConstraints cA=FALSE --
--    even though its signature verifies (Not_A_CA), and a leaf whose extKeyUsage
--    permits only clientAuth (Bad_Key_Usage).  A final trio validates chains in
--    the other signature algorithms the verifier supports: Ed25519, and RSA with
--    SHA-384 / SHA-512 links (the default fixtures above are RSA with SHA-256).
--
--  Build & run:  ./x run esp32s3_x509_chain
--    Runs under the embedded profile (build.sh sets ESP32S3_RTS_PROFILE=embedded).
--
--  Output:
--    A banner, then one "[chain] <name> : PASS" line per case (the verdict
--    matched what was expected), then "[chain] done".  A mismatch prints
--    "FAIL (<actual Result>)" instead.  The board then idles forever.
--
--  Hardware:  none (self-contained; the test certificates are embedded).
with Ada.Real_Time; use Ada.Real_Time;
with X509;
with Chain_Verify;  use Chain_Verify;
with Chain_Certs;    use Chain_Certs;
with Neg_Certs;      use Neg_Certs;
with Alg_Certs;      use Alg_Certs;
with ESP32S3.RNG;
with ESP32S3.Log;    use ESP32S3.Log;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   --  The three embedded test certificates, referenced by their library-level DER
   --  bytes (see Chain_Certs for the legend and provenance).
   Leaf  : constant Cert_Ref := (Data => Leaf_DER'Access);   --  CN=test.example.com
   CA    : constant Cert_Ref := (Data => CA_DER'Access);     --  CN=Test Root CA (issues Leaf)
   Other : constant Cert_Ref := (Data => Other_DER'Access);  --  CN=Unrelated CA (a different, unpinned root)

   --  Negative-test PKI (see Neg_Certs): a rogue intermediate marked CA:FALSE that
   --  nonetheless signs a leaf, and a leaf whose only extKeyUsage is clientAuth.
   N_Root  : constant Cert_Ref := (Data => Neg_Root_DER'Access);      --  CA:TRUE anchor
   N_Rogue : constant Cert_Ref := (Data => Neg_Rogue_DER'Access);     --  CA:FALSE issuer
   N_Leaf  : constant Cert_Ref := (Data => Neg_Leaf_DER'Access);      --  signed by the rogue
   N_EKU   : constant Cert_Ref := (Data => Neg_EKU_Leaf_DER'Access);  --  EKU clientAuth only

   --  Chains exercising the other signature algorithms (see Alg_Certs): Ed25519,
   --  and RSA with SHA-384 / SHA-512 links.
   Ed_Lf   : constant Cert_Ref := (Data => Ed_Leaf_DER'Access);
   Ed_Rt   : constant Cert_Ref := (Data => Ed_Root_DER'Access);
   R384_Lf : constant Cert_Ref := (Data => R384_Leaf_DER'Access);
   R384_Rt : constant Cert_Ref := (Data => R384_CA_DER'Access);
   R512_Lf : constant Cert_Ref := (Data => R512_Leaf_DER'Access);
   R512_Rt : constant Cert_Ref := (Data => R512_CA_DER'Access);

   --  Evaluation times (UTC, packed as YYYYMMDDhhmmss).  All three certificates
   --  are valid 2020..2049, so Within_Window evaluates inside the window, while
   --  Past_Window is deliberately past notAfter to force the Expired verdict.
   Within_Window : constant X509.Time_64 := X509.Pack_Time (2025, 6, 1, 12, 0, 0);
   Past_Window   : constant X509.Time_64 := X509.Pack_Time (2050, 1, 1, 0, 0, 0);

   --  The host the leaf is expected to cover (its CN and its only SAN).
   Host : constant String := "test.example.com";

   --  Let the runtime and console settle before the first line of output.
   Console_Settle : constant Time_Span := Milliseconds (200);

   --  After the self-test the example has nothing left to do; park the core in a
   --  long idle delay rather than busy-looping.
   Idle_Period : constant Time_Span := Seconds (3600);

   procedure Check (Name : String; Got, Want : Result) is
   begin
      Put_Line ("[chain] " & Name & " : "
                & (if Got = Want then "PASS" else "FAIL (" & Result'Image (Got) & ")"));
   end Check;
begin
   delay until Clock + Console_Settle;

   --  Chain_Verify's RSA signature checks draw from the hardware RNG (blinding);
   --  arm the entropy source before the first Validate call.
   ESP32S3.RNG.Enable_Entropy_Source;
   Put_Line ("[chain] certificate-chain validation (leaf <- CA, pinned root)");

   --  Positive: full leaf<-CA chain, CA pinned as the trust anchor.
   Check ("leaf+CA, pinned CA",   Validate ((Leaf, CA),   (1 => CA),    Host, Within_Window), Valid);
   --  Positive: leaf alone is enough when its issuer is itself the pinned anchor.
   Check ("leaf only, anchor CA", Validate ((1 => Leaf),  (1 => CA),    Host, Within_Window), Valid);
   --  Negative: leaf does not cover this host name.
   Check ("wrong hostname",       Validate ((Leaf, CA),   (1 => CA),    "evil.example.com", Within_Window), Name_Mismatch);
   --  Negative: evaluated past the certificates' validity window.
   Check ("expired (2050)",       Validate ((Leaf, CA),   (1 => CA),    Host, Past_Window), Expired);
   --  Negative: leaf<-leaf is a forged link; the second cert did not sign the first.
   Check ("broken link",          Validate ((Leaf, Leaf), (1 => CA),    Host, Within_Window), Bad_Signature);
   --  Negative: the chain's root is not among the pinned anchors.
   Check ("untrusted root",       Validate ((Leaf, CA),   (1 => Other), Host, Within_Window), Untrusted_Root);
   --  Negative: the rogue issuer's signature verifies, but it is marked CA:FALSE.
   Check ("non-CA issuer",        Validate ((N_Leaf, N_Rogue), (1 => N_Root), Host, Within_Window), Not_A_CA);
   --  Negative: the leaf chains and dates fine, but its EKU forbids serverAuth.
   Check ("leaf EKU clientAuth",  Validate ((1 => N_EKU),      (1 => N_Root), Host, Within_Window), Bad_Key_Usage);
   --  Positive: other signature algorithms -- Ed25519, and RSA with SHA-384/512.
   Check ("Ed25519 chain",        Validate ((Ed_Lf, Ed_Rt),     (1 => Ed_Rt),   Host, Within_Window), Valid);
   Check ("RSA-SHA384 chain",     Validate ((R384_Lf, R384_Rt), (1 => R384_Rt), Host, Within_Window), Valid);
   Check ("RSA-SHA512 chain",     Validate ((R512_Lf, R512_Rt), (1 => R512_Rt), Host, Within_Window), Valid);
   Put_Line ("[chain] done");

   loop
      delay until Clock + Idle_Period;
   end loop;
end Main;
