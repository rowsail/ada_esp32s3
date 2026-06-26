--  What it demonstrates
--  ---------------------
--  End-to-end X.509 certificate signature verification as a known-answer test.
--  Parse a self-signed RSA-2048 certificate, then verify its signature: SHA-256 the
--  TBS (signed) region, RSA-recover the PKCS#1 block with the cert's own public key,
--  and compare.  A self-signed cert verifies under its own key, so a PASS exercises
--  the whole stack -- the DER parser, the RSA accelerator, and SPARKNaCl's SHA-256.
--  A copy with one signed byte flipped must be rejected.
--
--  Build & run
--  -----------
--  ./x run esp32s3_x509_verify
--  Needs the embedded profile; build.sh sets ESP32S3_RTS_PROFILE=embedded.
--
--  Output
--  ------
--  Four lines.  PASS is both "[verify]" check lines reading PASS:
--    [verify] self-signed RSA-2048 certificate signature
--    [verify] signature valid : PASS
--    [verify] tampered rejected : PASS
--    [verify] done
--  "[verify] parse failed" appears instead of the two check lines only if the
--  bundled DER fails to parse (it should not -- the bytes are a fixed test vector).
--
--  Hardware / wiring
--  -----------------
--  None (self-contained): the certificate is a compiled-in byte vector and the RSA
--  math runs on the on-chip accelerator.
with Ada.Real_Time; use Ada.Real_Time;
with Interfaces;
with X509;          use X509;
with Cert_Verify;
with ESP32S3.RNG;
with ESP32S3.Log;    use ESP32S3.Log;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   use type Interfaces.Unsigned_8;

   --  Test vector: a self-signed RSA-2048 X.509 v3 certificate, DER-encoded.
   --  Legend (decoded with `openssl x509 -inform DER -text`):
   --    Subject = Issuer : CN=test.example.com  (self-signed)
   --    Serial           : 0x0123456789ABCDEF
   --    Signature alg    : sha256WithRSAEncryption (RSASSA-PKCS1-v1.5)
   --    Public key       : RSA 2048-bit, exponent 65537 (0x10001)
   --    Validity         : 2020-01-01 .. 2049-12-31
   --  Provenance: a fixed, throwaway test certificate (private key discarded after
   --  signing -- it authenticates nothing).  `openssl verify` confirms it is a valid
   --  self-signed certificate, so RSA_PKCS1_SHA256 over its own key must return True.
   --  The 698 bytes below are the exact DER, so a reader can write them out and
   --  re-decode to check every field above.
   Cert_DER : constant Byte_Array (0 .. 697) :=
     (16#30#, 16#82#, 16#02#, 16#B6#, 16#30#, 16#82#, 16#01#, 16#9E#, 16#A0#, 16#03#, 16#02#, 16#01#,
      16#02#, 16#02#, 16#08#, 16#01#, 16#23#, 16#45#, 16#67#, 16#89#, 16#AB#, 16#CD#, 16#EF#, 16#30#,
      16#0D#, 16#06#, 16#09#, 16#2A#, 16#86#, 16#48#, 16#86#, 16#F7#, 16#0D#, 16#01#, 16#01#, 16#0B#,
      16#05#, 16#00#, 16#30#, 16#1B#, 16#31#, 16#19#, 16#30#, 16#17#, 16#06#, 16#03#, 16#55#, 16#04#,
      16#03#, 16#0C#, 16#10#, 16#74#, 16#65#, 16#73#, 16#74#, 16#2E#, 16#65#, 16#78#, 16#61#, 16#6D#,
      16#70#, 16#6C#, 16#65#, 16#2E#, 16#63#, 16#6F#, 16#6D#, 16#30#, 16#1E#, 16#17#, 16#0D#, 16#32#,
      16#30#, 16#30#, 16#31#, 16#30#, 16#31#, 16#30#, 16#30#, 16#30#, 16#30#, 16#30#, 16#30#, 16#5A#,
      16#17#, 16#0D#, 16#34#, 16#39#, 16#31#, 16#32#, 16#33#, 16#31#, 16#32#, 16#33#, 16#35#, 16#39#,
      16#35#, 16#39#, 16#5A#, 16#30#, 16#1B#, 16#31#, 16#19#, 16#30#, 16#17#, 16#06#, 16#03#, 16#55#,
      16#04#, 16#03#, 16#0C#, 16#10#, 16#74#, 16#65#, 16#73#, 16#74#, 16#2E#, 16#65#, 16#78#, 16#61#,
      16#6D#, 16#70#, 16#6C#, 16#65#, 16#2E#, 16#63#, 16#6F#, 16#6D#, 16#30#, 16#82#, 16#01#, 16#22#,
      16#30#, 16#0D#, 16#06#, 16#09#, 16#2A#, 16#86#, 16#48#, 16#86#, 16#F7#, 16#0D#, 16#01#, 16#01#,
      16#01#, 16#05#, 16#00#, 16#03#, 16#82#, 16#01#, 16#0F#, 16#00#, 16#30#, 16#82#, 16#01#, 16#0A#,
      16#02#, 16#82#, 16#01#, 16#01#, 16#00#, 16#DA#, 16#D7#, 16#BA#, 16#C4#, 16#60#, 16#9D#, 16#59#,
      16#13#, 16#E2#, 16#FD#, 16#92#, 16#1B#, 16#FB#, 16#0C#, 16#E3#, 16#EB#, 16#31#, 16#2E#, 16#F1#,
      16#BB#, 16#4D#, 16#89#, 16#73#, 16#47#, 16#C4#, 16#57#, 16#C5#, 16#BC#, 16#2E#, 16#96#, 16#7A#,
      16#8E#, 16#20#, 16#19#, 16#F8#, 16#1D#, 16#D9#, 16#72#, 16#A5#, 16#C8#, 16#16#, 16#2A#, 16#7B#,
      16#C3#, 16#FF#, 16#C4#, 16#39#, 16#9D#, 16#74#, 16#9A#, 16#E3#, 16#AC#, 16#FA#, 16#BA#, 16#DF#,
      16#97#, 16#5A#, 16#9C#, 16#8E#, 16#D9#, 16#B6#, 16#C3#, 16#FB#, 16#94#, 16#3B#, 16#DB#, 16#9D#,
      16#CD#, 16#03#, 16#13#, 16#61#, 16#A4#, 16#A8#, 16#E3#, 16#55#, 16#54#, 16#C0#, 16#0E#, 16#5E#,
      16#9F#, 16#42#, 16#C4#, 16#C5#, 16#53#, 16#DC#, 16#D9#, 16#76#, 16#85#, 16#2F#, 16#85#, 16#81#,
      16#90#, 16#6C#, 16#FC#, 16#F5#, 16#F7#, 16#3E#, 16#79#, 16#E6#, 16#0B#, 16#38#, 16#9F#, 16#10#,
      16#BD#, 16#4F#, 16#67#, 16#06#, 16#29#, 16#E7#, 16#B8#, 16#46#, 16#F5#, 16#8F#, 16#F4#, 16#CA#,
      16#CE#, 16#02#, 16#21#, 16#D4#, 16#C1#, 16#AE#, 16#27#, 16#5A#, 16#54#, 16#DD#, 16#07#, 16#BC#,
      16#23#, 16#95#, 16#22#, 16#DD#, 16#5D#, 16#3B#, 16#41#, 16#CF#, 16#D9#, 16#6B#, 16#10#, 16#10#,
      16#D1#, 16#BA#, 16#2F#, 16#04#, 16#8B#, 16#4B#, 16#67#, 16#63#, 16#7F#, 16#CE#, 16#B0#, 16#11#,
      16#8B#, 16#3B#, 16#AE#, 16#B0#, 16#AD#, 16#8B#, 16#6E#, 16#67#, 16#4F#, 16#68#, 16#AD#, 16#61#,
      16#01#, 16#DF#, 16#C2#, 16#21#, 16#C4#, 16#98#, 16#F5#, 16#19#, 16#17#, 16#C4#, 16#6B#, 16#34#,
      16#C1#, 16#7D#, 16#D0#, 16#56#, 16#FD#, 16#C5#, 16#63#, 16#35#, 16#8A#, 16#5B#, 16#A5#, 16#3C#,
      16#D2#, 16#C0#, 16#5F#, 16#70#, 16#8B#, 16#FF#, 16#8F#, 16#1F#, 16#A1#, 16#69#, 16#6E#, 16#D3#,
      16#47#, 16#A9#, 16#C9#, 16#0C#, 16#24#, 16#C9#, 16#AD#, 16#D5#, 16#1C#, 16#A3#, 16#C1#, 16#C4#,
      16#B1#, 16#28#, 16#1E#, 16#35#, 16#6C#, 16#BE#, 16#83#, 16#25#, 16#72#, 16#D4#, 16#A2#, 16#FD#,
      16#39#, 16#36#, 16#12#, 16#13#, 16#18#, 16#95#, 16#CB#, 16#19#, 16#D7#, 16#BD#, 16#E2#, 16#53#,
      16#3C#, 16#D5#, 16#81#, 16#35#, 16#A4#, 16#85#, 16#70#, 16#47#, 16#5C#, 16#57#, 16#BA#, 16#22#,
      16#F0#, 16#27#, 16#9F#, 16#E1#, 16#7B#, 16#BF#, 16#6C#, 16#BE#, 16#BB#, 16#02#, 16#03#, 16#01#,
      16#00#, 16#01#, 16#30#, 16#0D#, 16#06#, 16#09#, 16#2A#, 16#86#, 16#48#, 16#86#, 16#F7#, 16#0D#,
      16#01#, 16#01#, 16#0B#, 16#05#, 16#00#, 16#03#, 16#82#, 16#01#, 16#01#, 16#00#, 16#68#, 16#3A#,
      16#95#, 16#64#, 16#78#, 16#47#, 16#74#, 16#D2#, 16#A0#, 16#0E#, 16#99#, 16#ED#, 16#38#, 16#97#,
      16#FD#, 16#C9#, 16#56#, 16#87#, 16#E4#, 16#B1#, 16#CC#, 16#DB#, 16#41#, 16#48#, 16#E5#, 16#60#,
      16#29#, 16#FE#, 16#B2#, 16#EC#, 16#D5#, 16#2E#, 16#6E#, 16#8F#, 16#D9#, 16#A5#, 16#6C#, 16#EB#,
      16#00#, 16#98#, 16#18#, 16#D4#, 16#50#, 16#64#, 16#07#, 16#98#, 16#32#, 16#22#, 16#C6#, 16#E9#,
      16#6F#, 16#2C#, 16#49#, 16#79#, 16#0C#, 16#21#, 16#4C#, 16#9F#, 16#9E#, 16#D0#, 16#E9#, 16#46#,
      16#B5#, 16#3D#, 16#8E#, 16#2C#, 16#5E#, 16#16#, 16#46#, 16#71#, 16#A4#, 16#CA#, 16#B1#, 16#7F#,
      16#02#, 16#1C#, 16#4B#, 16#F5#, 16#D1#, 16#7C#, 16#76#, 16#EB#, 16#68#, 16#24#, 16#EC#, 16#4C#,
      16#64#, 16#F9#, 16#1C#, 16#A7#, 16#F8#, 16#6D#, 16#82#, 16#3B#, 16#D8#, 16#67#, 16#C7#, 16#39#,
      16#57#, 16#24#, 16#E0#, 16#59#, 16#95#, 16#6C#, 16#14#, 16#90#, 16#57#, 16#C6#, 16#33#, 16#2F#,
      16#FE#, 16#F6#, 16#57#, 16#31#, 16#0B#, 16#73#, 16#61#, 16#9E#, 16#CA#, 16#27#, 16#53#, 16#D6#,
      16#B3#, 16#BD#, 16#08#, 16#73#, 16#47#, 16#D3#, 16#BD#, 16#B3#, 16#A6#, 16#B3#, 16#38#, 16#AE#,
      16#5D#, 16#D1#, 16#9C#, 16#3F#, 16#01#, 16#4B#, 16#58#, 16#95#, 16#F0#, 16#8D#, 16#20#, 16#90#,
      16#0A#, 16#DA#, 16#B5#, 16#0D#, 16#54#, 16#4D#, 16#CE#, 16#33#, 16#87#, 16#E6#, 16#66#, 16#0D#,
      16#51#, 16#73#, 16#1D#, 16#49#, 16#CF#, 16#AE#, 16#27#, 16#65#, 16#09#, 16#BA#, 16#B1#, 16#E0#,
      16#7C#, 16#C7#, 16#CC#, 16#9D#, 16#DD#, 16#76#, 16#2F#, 16#C8#, 16#6D#, 16#53#, 16#4B#, 16#92#,
      16#04#, 16#65#, 16#75#, 16#6E#, 16#0F#, 16#26#, 16#F9#, 16#D8#, 16#E3#, 16#0A#, 16#0D#, 16#EC#,
      16#26#, 16#30#, 16#79#, 16#E0#, 16#11#, 16#9D#, 16#2F#, 16#C0#, 16#19#, 16#F2#, 16#B5#, 16#55#,
      16#C4#, 16#8F#, 16#88#, 16#CF#, 16#C5#, 16#87#, 16#A6#, 16#B7#, 16#26#, 16#A7#, 16#D4#, 16#26#,
      16#0F#, 16#F9#, 16#24#, 16#D4#, 16#BD#, 16#5B#, 16#D0#, 16#6E#, 16#89#, 16#EF#, 16#23#, 16#94#,
      16#FE#, 16#DA#, 16#5A#, 16#2C#, 16#4D#, 16#D8#, 16#82#, 16#8C#, 16#79#, 16#FA#, 16#3A#, 16#B3#,
      16#AC#, 16#D1#, 16#6D#, 16#B9#, 16#7B#, 16#13#, 16#47#, 16#4C#, 16#62#, 16#AE#, 16#E1#, 16#A2#,
      16#7C#, 16#28#);

   --  Negative test: which signed byte to corrupt, and how.  Any offset inside the
   --  TBS region works; 20 lands in the early version/serial fields.  XOR with all-
   --  ones flips every bit of that byte, guaranteeing a different SHA-256 of the TBS
   --  and therefore a signature that no longer matches.
   Tamper_Offset : constant := 20;
   All_Ones      : constant := 16#FF#;

   C : Certificate;

   function Bytes (S : Slice) return Byte_Array is (Cert_DER (S.First .. S.Last));

   procedure Check (Name : String; Pass : Boolean) is
   begin
      Put_Line ("[verify] " & Name & " : " & (if Pass then "PASS" else "FAIL"));
   end Check;
begin
   delay until Clock + Milliseconds (200);
   ESP32S3.RNG.Enable_Entropy_Source;

   Put_Line ("[verify] self-signed RSA-2048 certificate signature");
   Parse (Cert_DER, C);
   if not C.Valid then
      Put_Line ("[verify] parse failed");
   else
      --  Positive: the certificate's own signature must verify under its own key.
      Check ("signature valid",
             Cert_Verify.RSA_PKCS1_SHA256
               (TBS       => Bytes (C.TBS),
                Signature => Bytes (C.Signature),
                Modulus   => Bytes (C.RSA_Modulus),
                Exponent  => Bytes (C.RSA_Exponent)));

      --  Negative: flip one byte of the signed region; verification must fail.
      declare
         Bad      : Byte_Array := Bytes (C.TBS);
         Position : constant Natural := Bad'First + Tamper_Offset;
      begin
         Bad (Position) := Bad (Position) xor All_Ones;
         Check ("tampered rejected",
                not Cert_Verify.RSA_PKCS1_SHA256
                      (TBS       => Bad,
                       Signature => Bytes (C.Signature),
                       Modulus   => Bytes (C.RSA_Modulus),
                       Exponent  => Bytes (C.RSA_Exponent)));
      end;
   end if;
   Put_Line ("[verify] done");

   --  Self-test is one-shot; idle so the console output stays put for the runner.
   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
