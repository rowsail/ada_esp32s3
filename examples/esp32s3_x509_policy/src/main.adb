--  X.509 leaf-certificate policy checks on the bare-metal ESP32-S3 (no FreeRTOS,
--  no IDF)
--  =====================================================================
--  What it demonstrates:
--    The two policy checks the TLS client applies to a parsed leaf certificate,
--    on a single embedded test cert -- no chain, no signature crypto here:
--      * validity-window:  notBefore <= "now" <= notAfter, where "now" is a
--        wall-clock time the caller supplies (e.g. derived from NTP), so the
--        device decides freshness rather than trusting the cert blindly; and
--      * hostname matching:  does a requested host match a subjectAltName
--        dNSName, case-insensitively, honouring a single leftmost "*" wildcard
--        label per RFC 6125.
--    Each Check line asserts one expected verdict; together they cover the in-,
--    past- and future-window cases and the exact / case-fold / wrong-host /
--    wildcard-hit / wildcard-miss name cases.
--
--  Build & run:  ./x run esp32s3_x509_policy
--    Runs under the embedded profile (build.sh sets ESP32S3_RTS_PROFILE=embedded).
--
--  Output:
--    A banner, then one "[pol] <name> : PASS" line per case (the check returned
--    what was expected), then "[pol] done".  A failing assertion prints "FAIL"
--    instead.  The board then idles forever.
--
--  Hardware:  none (self-contained; the test certificate is embedded below).
with Ada.Real_Time; use Ada.Real_Time;
with X509;          use X509;
with ESP32S3.RNG;
with ESP32S3.Log;    use ESP32S3.Log;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is

   --  The embedded test certificate, as raw DER (the bytes of a single ASN.1
   --  Certificate SEQUENCE).  Decode with:  openssl x509 -inform DER -text.
   --
   --  Legend (what these bytes decode to, confirmed with openssl):
   --    Version            : v3
   --    Serial             : 0x42 (66)
   --    Issuer / Subject   : CN=test.example.com  (self-signed: issuer = subject)
   --    Validity           : 2020-01-01 00:00:00Z .. 2049-12-31 23:59:59Z (UTCTime)
   --    Subject public key : RSA 2048-bit, exponent 65537
   --    subjectAltName     : DNS:test.example.com, DNS:*.example.org  (the two SANs
   --                         the hostname cases below probe)
   --    Signature          : sha256WithRSAEncryption  (not checked here -- this
   --                         example exercises only the date/hostname policy, so
   --                         the self-signed signature is never verified)
   --
   --  Provenance:  a fixed, hand-built test vector committed with the parser
   --  (commit 2d794bc, "hal: X.509 validity-date and hostname (SAN) checks").
   --  No generator script is checked in; the field shapes (self-signed leaf,
   --  RSA-2048/SHA-256, the 2020..2049 window, the two SANs) are the canonical
   --  output of `openssl req -x509`, which is the presumed generator.
   Cert_DER : constant Byte_Array (0 .. 738) :=
     (16#30#, 16#82#, 16#02#, 16#DF#, 16#30#, 16#82#, 16#01#, 16#C7#, 16#A0#, 16#03#, 16#02#, 16#01#,
      16#02#, 16#02#, 16#01#, 16#42#, 16#30#, 16#0D#, 16#06#, 16#09#, 16#2A#, 16#86#, 16#48#, 16#86#,
      16#F7#, 16#0D#, 16#01#, 16#01#, 16#0B#, 16#05#, 16#00#, 16#30#, 16#1B#, 16#31#, 16#19#, 16#30#,
      16#17#, 16#06#, 16#03#, 16#55#, 16#04#, 16#03#, 16#0C#, 16#10#, 16#74#, 16#65#, 16#73#, 16#74#,
      16#2E#, 16#65#, 16#78#, 16#61#, 16#6D#, 16#70#, 16#6C#, 16#65#, 16#2E#, 16#63#, 16#6F#, 16#6D#,
      16#30#, 16#1E#, 16#17#, 16#0D#, 16#32#, 16#30#, 16#30#, 16#31#, 16#30#, 16#31#, 16#30#, 16#30#,
      16#30#, 16#30#, 16#30#, 16#30#, 16#5A#, 16#17#, 16#0D#, 16#34#, 16#39#, 16#31#, 16#32#, 16#33#,
      16#31#, 16#32#, 16#33#, 16#35#, 16#39#, 16#35#, 16#39#, 16#5A#, 16#30#, 16#1B#, 16#31#, 16#19#,
      16#30#, 16#17#, 16#06#, 16#03#, 16#55#, 16#04#, 16#03#, 16#0C#, 16#10#, 16#74#, 16#65#, 16#73#,
      16#74#, 16#2E#, 16#65#, 16#78#, 16#61#, 16#6D#, 16#70#, 16#6C#, 16#65#, 16#2E#, 16#63#, 16#6F#,
      16#6D#, 16#30#, 16#82#, 16#01#, 16#22#, 16#30#, 16#0D#, 16#06#, 16#09#, 16#2A#, 16#86#, 16#48#,
      16#86#, 16#F7#, 16#0D#, 16#01#, 16#01#, 16#01#, 16#05#, 16#00#, 16#03#, 16#82#, 16#01#, 16#0F#,
      16#00#, 16#30#, 16#82#, 16#01#, 16#0A#, 16#02#, 16#82#, 16#01#, 16#01#, 16#00#, 16#90#, 16#62#,
      16#20#, 16#5D#, 16#21#, 16#B1#, 16#0A#, 16#35#, 16#5E#, 16#79#, 16#8B#, 16#08#, 16#4F#, 16#9A#,
      16#B4#, 16#AE#, 16#7B#, 16#5A#, 16#BE#, 16#07#, 16#C2#, 16#65#, 16#83#, 16#D3#, 16#86#, 16#37#,
      16#3E#, 16#2E#, 16#00#, 16#DB#, 16#22#, 16#24#, 16#43#, 16#93#, 16#77#, 16#ED#, 16#DE#, 16#7A#,
      16#0D#, 16#95#, 16#FB#, 16#48#, 16#18#, 16#8E#, 16#0F#, 16#3D#, 16#BC#, 16#9A#, 16#E1#, 16#F7#,
      16#F8#, 16#82#, 16#CB#, 16#38#, 16#01#, 16#78#, 16#53#, 16#D5#, 16#17#, 16#F7#, 16#AE#, 16#48#,
      16#A3#, 16#90#, 16#8F#, 16#CB#, 16#80#, 16#54#, 16#53#, 16#CB#, 16#E5#, 16#24#, 16#CA#, 16#45#,
      16#77#, 16#9A#, 16#C0#, 16#41#, 16#90#, 16#F3#, 16#FF#, 16#07#, 16#03#, 16#0F#, 16#42#, 16#44#,
      16#36#, 16#32#, 16#E1#, 16#D1#, 16#D9#, 16#06#, 16#70#, 16#1F#, 16#61#, 16#38#, 16#6D#, 16#83#,
      16#29#, 16#85#, 16#05#, 16#A2#, 16#C7#, 16#8F#, 16#DF#, 16#E2#, 16#70#, 16#C9#, 16#CD#, 16#E3#,
      16#AC#, 16#72#, 16#7C#, 16#7A#, 16#EC#, 16#EA#, 16#73#, 16#AE#, 16#1D#, 16#0D#, 16#28#, 16#AF#,
      16#0E#, 16#73#, 16#10#, 16#11#, 16#A6#, 16#93#, 16#60#, 16#A2#, 16#78#, 16#79#, 16#F1#, 16#96#,
      16#F3#, 16#1B#, 16#9D#, 16#F0#, 16#29#, 16#A2#, 16#C5#, 16#6A#, 16#0D#, 16#8F#, 16#17#, 16#65#,
      16#FF#, 16#28#, 16#D5#, 16#77#, 16#17#, 16#6E#, 16#24#, 16#82#, 16#52#, 16#D2#, 16#AF#, 16#62#,
      16#06#, 16#08#, 16#C5#, 16#F6#, 16#CD#, 16#2B#, 16#4D#, 16#5F#, 16#22#, 16#06#, 16#04#, 16#24#,
      16#B5#, 16#06#, 16#3C#, 16#E4#, 16#3E#, 16#0B#, 16#F4#, 16#D1#, 16#BB#, 16#BB#, 16#B5#, 16#E7#,
      16#D5#, 16#94#, 16#FA#, 16#5E#, 16#47#, 16#DA#, 16#1F#, 16#A8#, 16#02#, 16#BB#, 16#49#, 16#02#,
      16#B6#, 16#82#, 16#C7#, 16#B5#, 16#45#, 16#46#, 16#B0#, 16#B7#, 16#61#, 16#19#, 16#43#, 16#AE#,
      16#00#, 16#BD#, 16#35#, 16#03#, 16#27#, 16#7C#, 16#D9#, 16#24#, 16#1F#, 16#F9#, 16#A7#, 16#2D#,
      16#A6#, 16#D9#, 16#EF#, 16#CA#, 16#B5#, 16#C6#, 16#82#, 16#6C#, 16#DC#, 16#18#, 16#C6#, 16#E3#,
      16#BD#, 16#5F#, 16#30#, 16#B6#, 16#F4#, 16#A1#, 16#81#, 16#0F#, 16#78#, 16#B1#, 16#49#, 16#19#,
      16#24#, 16#4A#, 16#7D#, 16#F0#, 16#37#, 16#43#, 16#57#, 16#45#, 16#1C#, 16#3A#, 16#CE#, 16#C9#,
      16#21#, 16#C7#, 16#02#, 16#03#, 16#01#, 16#00#, 16#01#, 16#A3#, 16#2E#, 16#30#, 16#2C#, 16#30#,
      16#2A#, 16#06#, 16#03#, 16#55#, 16#1D#, 16#11#, 16#04#, 16#23#, 16#30#, 16#21#, 16#82#, 16#10#,
      16#74#, 16#65#, 16#73#, 16#74#, 16#2E#, 16#65#, 16#78#, 16#61#, 16#6D#, 16#70#, 16#6C#, 16#65#,
      16#2E#, 16#63#, 16#6F#, 16#6D#, 16#82#, 16#0D#, 16#2A#, 16#2E#, 16#65#, 16#78#, 16#61#, 16#6D#,
      16#70#, 16#6C#, 16#65#, 16#2E#, 16#6F#, 16#72#, 16#67#, 16#30#, 16#0D#, 16#06#, 16#09#, 16#2A#,
      16#86#, 16#48#, 16#86#, 16#F7#, 16#0D#, 16#01#, 16#01#, 16#0B#, 16#05#, 16#00#, 16#03#, 16#82#,
      16#01#, 16#01#, 16#00#, 16#25#, 16#E0#, 16#03#, 16#77#, 16#81#, 16#7D#, 16#8E#, 16#BA#, 16#13#,
      16#DF#, 16#5B#, 16#9D#, 16#23#, 16#94#, 16#68#, 16#BB#, 16#23#, 16#BE#, 16#D6#, 16#53#, 16#BF#,
      16#1F#, 16#C3#, 16#81#, 16#02#, 16#FE#, 16#5B#, 16#73#, 16#50#, 16#E5#, 16#51#, 16#8A#, 16#7D#,
      16#7F#, 16#6C#, 16#03#, 16#3E#, 16#40#, 16#37#, 16#F6#, 16#A7#, 16#D1#, 16#0C#, 16#C7#, 16#DD#,
      16#75#, 16#6C#, 16#E6#, 16#A9#, 16#B1#, 16#3C#, 16#F8#, 16#77#, 16#AC#, 16#BB#, 16#B1#, 16#AD#,
      16#14#, 16#B3#, 16#F2#, 16#09#, 16#E4#, 16#8B#, 16#C0#, 16#AB#, 16#26#, 16#F3#, 16#B7#, 16#8E#,
      16#6D#, 16#7B#, 16#3B#, 16#CF#, 16#AB#, 16#46#, 16#92#, 16#02#, 16#CE#, 16#D6#, 16#87#, 16#2F#,
      16#F8#, 16#E2#, 16#9F#, 16#0D#, 16#4F#, 16#03#, 16#F5#, 16#53#, 16#0B#, 16#F7#, 16#18#, 16#F6#,
      16#50#, 16#F4#, 16#BB#, 16#CF#, 16#02#, 16#06#, 16#41#, 16#4B#, 16#04#, 16#69#, 16#F7#, 16#26#,
      16#5C#, 16#AF#, 16#45#, 16#C0#, 16#05#, 16#74#, 16#45#, 16#DF#, 16#9D#, 16#D5#, 16#B1#, 16#E8#,
      16#7E#, 16#21#, 16#AF#, 16#8D#, 16#A3#, 16#AE#, 16#C2#, 16#81#, 16#0A#, 16#4C#, 16#54#, 16#60#,
      16#AC#, 16#6D#, 16#B7#, 16#E6#, 16#1F#, 16#49#, 16#60#, 16#75#, 16#DD#, 16#42#, 16#0F#, 16#FC#,
      16#37#, 16#80#, 16#54#, 16#02#, 16#D8#, 16#C5#, 16#DD#, 16#8B#, 16#6D#, 16#92#, 16#83#, 16#98#,
      16#89#, 16#0F#, 16#2D#, 16#64#, 16#02#, 16#9C#, 16#88#, 16#05#, 16#D4#, 16#DB#, 16#B0#, 16#CB#,
      16#28#, 16#18#, 16#E8#, 16#1C#, 16#C5#, 16#DA#, 16#FD#, 16#C0#, 16#74#, 16#0E#, 16#7E#, 16#2A#,
      16#98#, 16#27#, 16#82#, 16#04#, 16#5E#, 16#DF#, 16#55#, 16#AF#, 16#CF#, 16#B7#, 16#26#, 16#44#,
      16#8F#, 16#16#, 16#AC#, 16#99#, 16#BB#, 16#83#, 16#8E#, 16#67#, 16#60#, 16#1A#, 16#DC#, 16#0E#,
      16#04#, 16#85#, 16#FC#, 16#98#, 16#DC#, 16#B3#, 16#F2#, 16#ED#, 16#E9#, 16#A8#, 16#55#, 16#BF#,
      16#06#, 16#21#, 16#81#, 16#DC#, 16#9E#, 16#7A#, 16#7C#, 16#FF#, 16#80#, 16#95#, 16#1C#, 16#D6#,
      16#13#, 16#96#, 16#D3#, 16#6B#, 16#54#, 16#DF#, 16#64#, 16#F2#, 16#56#, 16#50#, 16#13#, 16#61#,
      16#60#, 16#17#, 16#5F#, 16#B0#, 16#88#, 16#34#, 16#DA#, 16#BA#, 16#BE#, 16#6B#, 16#59#, 16#EF#,
      16#53#, 16#2A#, 16#0C#, 16#8A#, 16#F7#, 16#6B#, 16#52#);

   --  The parsed view of Cert_DER (slices into the buffer; see X509.Certificate).
   Parsed_Cert : Certificate;

   --  Report one policy assertion: print "[pol] <name> : PASS" when the check
   --  matched its expected outcome, "FAIL" otherwise.
   procedure Check (Name : String; Pass : Boolean) is
   begin
      Put_Line ("[pol] " & Name & " : " & (if Pass then "PASS" else "FAIL"));
   end Check;

   --  Pack a civil date/time into the comparable Time_64 that Valid_At expects,
   --  so each case below reads as plain calendar fields.
   function At_Time (Year, Month, Day, Hour, Minute, Second : Natural)
                     return Time_64 is
     (Pack_Time (Year, Month, Day, Hour, Minute, Second));

   --  Let the RNG/console come up before the first line is printed; the value is
   --  not load-bearing, just long enough to settle.
   Startup_Settle : constant Time_Span := Milliseconds (200);

   --  This example never returns; park the core for an hour at a time instead of
   --  spinning, so the last output stays on screen.
   Idle_Interval : constant Time_Span := Seconds (3600);
begin
   delay until Clock + Startup_Settle;
   ESP32S3.RNG.Enable_Entropy_Source;

   Put_Line ("[pol] X.509 validity + hostname (SAN) checks");
   Parse (Cert_DER, Parsed_Cert);
   Check ("parsed",            Parsed_Cert.Valid);
   Check ("SAN count = 2",     Parsed_Cert.SAN_Count = 2);

   --  Validity window: the cert is valid 2020-01-01 .. 2049-12-31 (see legend),
   --  so a "now" inside the window passes and one on either side fails.
   Check ("valid now (2025)",  Valid_At (Cert_DER, Parsed_Cert, At_Time (2025, 6, 1, 12, 0, 0)));
   Check ("expired (2050)",    not Valid_At (Cert_DER, Parsed_Cert, At_Time (2050, 1, 1, 0, 0, 0)));
   Check ("not yet (2019)",    not Valid_At (Cert_DER, Parsed_Cert, At_Time (2019, 1, 1, 0, 0, 0)));

   --  Hostname matching against the two SANs (test.example.com, *.example.org).
   --  The wildcard label matches exactly one label and only with >= 2 labels of
   --  remainder, so "example.org" (no label) and "a.b.example.org" (two) miss.
   Check ("exact match",       Host_Matches (Cert_DER, Parsed_Cert, "test.example.com"));
   Check ("case-insensitive",  Host_Matches (Cert_DER, Parsed_Cert, "TEST.Example.COM"));
   Check ("wrong host",        not Host_Matches (Cert_DER, Parsed_Cert, "evil.example.com"));
   Check ("wildcard match",    Host_Matches (Cert_DER, Parsed_Cert, "foo.example.org"));
   Check ("wildcard no-label", not Host_Matches (Cert_DER, Parsed_Cert, "example.org"));
   Check ("wildcard 1 label",  not Host_Matches (Cert_DER, Parsed_Cert, "a.b.example.org"));
   Put_Line ("[pol] done");

   loop
      delay until Clock + Idle_Interval;
   end loop;
end Main;
