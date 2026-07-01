--  X.509 DER parser known-answer test (X509.Parse)
--  ===============================================
--  What it demonstrates: the bounds-checked DER certificate walk in the HAL's
--  X509 package.  It parses a known self-signed RSA-2048 certificate held in the
--  binary and checks the extracted fields (serial, notAfter, notAfter tag, RSA
--  modulus and exponent) against the values precomputed on the host -- a
--  known-answer test, so any drift in the parser shows up as a FAIL.
--
--  Build & run: ./x run esp32s3_x509_kat
--  Runs under the embedded profile (build.sh sets ESP32S3_RTS_PROFILE=embedded);
--  X509 is pure byte handling with no chip dependency, so the smallest profile
--  is enough.
--
--  Output: a header line, then one "[x509] <field> : PASS" per checked field,
--  then "[x509] done".  PASS on every line means the parser recovered each field
--  byte-for-byte.  If C.Valid comes back False the per-field lines are skipped
--  (the structure failed to parse at all).
--
--  Hardware: none (self-contained -- the certificate is embedded below).
with Ada.Real_Time; use Ada.Real_Time;
with Interfaces;
with X509;          use X509;
with X509.DER;
with ESP32S3.RNG;
with ESP32S3.Log;    use ESP32S3.Log;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   use type Interfaces.Unsigned_8;

   --  Settle time before the first console write, so the banner is not cut into
   --  by the boot-ROM chatter still draining on the UART.
   Console_Settle : constant Time_Span := Milliseconds (200);

   --  DER tag for an ASN.1 UTCTime (0x17); GeneralizedTime would be 0x18.  This
   --  certificate's notAfter is a UTCTime, so the parser must report this tag.
   UTCTime_Tag : constant := 16#17#;

   --  Idle period for the post-test parking loop (nothing to do once the KAT has
   --  printed; just keep the app alive without spinning).
   Idle_Period : constant Time_Span := Seconds (3600);

   --  The certificate under test, and the expected field values, are a
   --  known-answer vector: a self-signed RSA-2048 certificate constructed for
   --  this test (subject/issuer CN = "test.example.com", serialNumber =
   --  0x0123456789ABCDEF, validity 2020-01-01 .. UTCTime "491231235959Z",
   --  SHA-256 with RSA signature).  Cert_DER is its full DER encoding; the Exp_*
   --  arrays are the exact byte ranges X509.Parse must recover from it.

   --  Full DER of the certificate (the bytes a TLS peer would send).
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

   --  serialNumber INTEGER content: 0x0123456789ABCDEF.
   Exp_Serial : constant Byte_Array (0 .. 7) :=
     (16#01#, 16#23#, 16#45#, 16#67#, 16#89#, 16#AB#, 16#CD#, 16#EF#);

   --  notAfter time as ASCII UTCTime "491231235959Z" (YYMMDDHHMMSSZ = Dec 31
   --  23:59:59).
   Exp_Not_After : constant Byte_Array (0 .. 12) :=
     (16#34#, 16#39#, 16#31#, 16#32#, 16#33#, 16#31#, 16#32#, 16#33#, 16#35#, 16#39#, 16#35#, 16#39#,
      16#5A#);

   --  RSA public exponent: 65537 (0x010001), the conventional F4.
   Exp_Exponent : constant Byte_Array (0 .. 2) :=
     (16#01#, 16#00#, 16#01#);

   --  RSA modulus INTEGER content (big-endian, leading 0x00 sign byte then the
   --  256-byte 2048-bit modulus).
   Exp_Modulus : constant Byte_Array (0 .. 256) :=
     (16#00#, 16#DA#, 16#D7#, 16#BA#, 16#C4#, 16#60#, 16#9D#, 16#59#, 16#13#, 16#E2#, 16#FD#, 16#92#,
      16#1B#, 16#FB#, 16#0C#, 16#E3#, 16#EB#, 16#31#, 16#2E#, 16#F1#, 16#BB#, 16#4D#, 16#89#, 16#73#,
      16#47#, 16#C4#, 16#57#, 16#C5#, 16#BC#, 16#2E#, 16#96#, 16#7A#, 16#8E#, 16#20#, 16#19#, 16#F8#,
      16#1D#, 16#D9#, 16#72#, 16#A5#, 16#C8#, 16#16#, 16#2A#, 16#7B#, 16#C3#, 16#FF#, 16#C4#, 16#39#,
      16#9D#, 16#74#, 16#9A#, 16#E3#, 16#AC#, 16#FA#, 16#BA#, 16#DF#, 16#97#, 16#5A#, 16#9C#, 16#8E#,
      16#D9#, 16#B6#, 16#C3#, 16#FB#, 16#94#, 16#3B#, 16#DB#, 16#9D#, 16#CD#, 16#03#, 16#13#, 16#61#,
      16#A4#, 16#A8#, 16#E3#, 16#55#, 16#54#, 16#C0#, 16#0E#, 16#5E#, 16#9F#, 16#42#, 16#C4#, 16#C5#,
      16#53#, 16#DC#, 16#D9#, 16#76#, 16#85#, 16#2F#, 16#85#, 16#81#, 16#90#, 16#6C#, 16#FC#, 16#F5#,
      16#F7#, 16#3E#, 16#79#, 16#E6#, 16#0B#, 16#38#, 16#9F#, 16#10#, 16#BD#, 16#4F#, 16#67#, 16#06#,
      16#29#, 16#E7#, 16#B8#, 16#46#, 16#F5#, 16#8F#, 16#F4#, 16#CA#, 16#CE#, 16#02#, 16#21#, 16#D4#,
      16#C1#, 16#AE#, 16#27#, 16#5A#, 16#54#, 16#DD#, 16#07#, 16#BC#, 16#23#, 16#95#, 16#22#, 16#DD#,
      16#5D#, 16#3B#, 16#41#, 16#CF#, 16#D9#, 16#6B#, 16#10#, 16#10#, 16#D1#, 16#BA#, 16#2F#, 16#04#,
      16#8B#, 16#4B#, 16#67#, 16#63#, 16#7F#, 16#CE#, 16#B0#, 16#11#, 16#8B#, 16#3B#, 16#AE#, 16#B0#,
      16#AD#, 16#8B#, 16#6E#, 16#67#, 16#4F#, 16#68#, 16#AD#, 16#61#, 16#01#, 16#DF#, 16#C2#, 16#21#,
      16#C4#, 16#98#, 16#F5#, 16#19#, 16#17#, 16#C4#, 16#6B#, 16#34#, 16#C1#, 16#7D#, 16#D0#, 16#56#,
      16#FD#, 16#C5#, 16#63#, 16#35#, 16#8A#, 16#5B#, 16#A5#, 16#3C#, 16#D2#, 16#C0#, 16#5F#, 16#70#,
      16#8B#, 16#FF#, 16#8F#, 16#1F#, 16#A1#, 16#69#, 16#6E#, 16#D3#, 16#47#, 16#A9#, 16#C9#, 16#0C#,
      16#24#, 16#C9#, 16#AD#, 16#D5#, 16#1C#, 16#A3#, 16#C1#, 16#C4#, 16#B1#, 16#28#, 16#1E#, 16#35#,
      16#6C#, 16#BE#, 16#83#, 16#25#, 16#72#, 16#D4#, 16#A2#, 16#FD#, 16#39#, 16#36#, 16#12#, 16#13#,
      16#18#, 16#95#, 16#CB#, 16#19#, 16#D7#, 16#BD#, 16#E2#, 16#53#, 16#3C#, 16#D5#, 16#81#, 16#35#,
      16#A4#, 16#85#, 16#70#, 16#47#, 16#5C#, 16#57#, 16#BA#, 16#22#, 16#F0#, 16#27#, 16#9F#, 16#E1#,
      16#7B#, 16#BF#, 16#6C#, 16#BE#, 16#BB#);

   C : Certificate;

   --  Does the certificate sub-range named by S equal the expected bytes Want?
   --  S indexes into Cert_DER (the parser returns ranges, not copies), so this
   --  compares the parsed-out field against the host-known answer.
   function Slice_Eq (S : Slice; Want : Byte_Array) return Boolean is
   begin
      if Length (S) /= Want'Length then
         return False;
      end if;
      for I in 0 .. Want'Length - 1 loop
         if Cert_DER (S.First + I) /= Want (Want'First + I) then
            return False;
         end if;
      end loop;
      return True;
   end Slice_Eq;

   procedure Check (Name : String; Pass : Boolean) is
   begin
      Put_Line ("[x509] " & Name & " : " & (if Pass then "PASS" else "FAIL"));
   end Check;
begin
   delay until Clock + Console_Settle;

   --  Seed the hardware entropy source.  The X509 parse itself is deterministic,
   --  but TLS work links the RNG, so keep it enabled here for parity.
   ESP32S3.RNG.Enable_Entropy_Source;

   Put_Line ("[x509] parse a self-signed RSA-2048 certificate");
   Parse (Cert_DER, C);
   Check ("structure valid", C.Valid);
   if C.Valid then
      Check ("serial",        Slice_Eq (C.Serial,       Exp_Serial));
      Check ("notAfter",      Slice_Eq (C.Not_After,    Exp_Not_After));
      Check ("notAfter UTC",  C.NA_Tag = UTCTime_Tag);
      Check ("RSA modulus",   Slice_Eq (C.RSA_Modulus,  Exp_Modulus));
      Check ("RSA exponent",  Slice_Eq (C.RSA_Exponent, Exp_Exponent));
   end if;

   --  Adversarial: a 4-byte long-form DER length (84 FF FF FF FF) encodes
   --  2**32-1, which used to overflow the 31-bit Natural accumulator and raise
   --  Constraint_Error -- a DoS on any parsed certificate.  The reader must now
   --  reject it cleanly (Valid => False) rather than fault; reaching this verdict
   --  at all (instead of a reset) is the proof.
   declare
      Evil : constant Byte_Array (0 .. 5) :=
        (16#04#, 16#84#, 16#FF#, 16#FF#, 16#FF#, 16#FF#);  --  OCTET STRING, len 2^32-1
      E    : X509.DER.TLV;
   begin
      X509.DER.Read (Evil, Evil'First, Evil'Last, E);
      Check ("reject 4-byte length overflow", not E.Valid);
   end;

   Put_Line ("[x509] done");

   --  Test done; park forever rather than return (there is no OS to return to).
   loop
      delay until Clock + Idle_Period;
   end loop;
end Main;
