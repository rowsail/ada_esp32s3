--  What it demonstrates
--    AES-GCM AEAD as a known-answer test (KAT) on the ESP32-S3: authenticated
--    encrypt + decrypt for AES-128 and AES-256, driving the hardware AES block
--    with software GHASH/CTR.  Encrypt must reproduce the expected ciphertext and
--    tag; decrypt must verify the tag and recover the original plaintext.
--
--  Build & run
--    ./x run esp32s3_aes_gcm_kat
--    build.sh sets ESP32S3_RTS_PROFILE=embedded (the IDF-free bare-boot profile).
--
--  How to read the output
--    [gcm] AES-GCM known-answer tests (HW AES block + SW GHASH/CTR)
--    [gcm] AES-128-GCM : PASS      <- both cases must say PASS
--    [gcm] AES-256-GCM : PASS
--    [gcm] done
--    PASS means the encrypt output matched the expected C/T and the decrypt both
--    authenticated and recovered P; any mismatch prints FAIL on that line.
--
--  Hardware
--    None (self-contained) â vectors are baked in; no external parts or wiring.
--
--  Vector legend (per case N): KN=key, IVN=nonce, AN=AAD (authenticated, not
--    encrypted), PN=plaintext, CN=expected ciphertext, TN=expected auth tag.
--  Provenance: these K/IV/A/P/C/T vectors were generated with the Python
--    "cryptography" library (AESGCM), which produces the C and T for a given
--    K/IV/A/P; re-run that library on the K/IV/A/P below to regenerate C and T.
with Ada.Real_Time;   use Ada.Real_Time;
with Interfaces;
with ESP32S3.AES;     use ESP32S3.AES;
with ESP32S3.AES.GCM; use ESP32S3.AES.GCM;
with ESP32S3.RNG;
with ESP32S3.Log;     use ESP32S3.Log;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   use type Interfaces.Unsigned_8;

   K1 : constant Key_Bytes (0 .. 15) :=
     (16#25#,
      16#5D#,
      16#3F#,
      16#D9#,
      16#57#,
      16#2C#,
      16#82#,
      16#30#,
      16#09#,
      16#DC#,
      16#F3#,
      16#EB#,
      16#18#,
      16#F0#,
      16#AE#,
      16#72#);

   IV1 : constant Byte_Array (0 .. 11) :=
     (16#B5#,
      16#57#,
      16#9E#,
      16#B3#,
      16#A2#,
      16#25#,
      16#45#,
      16#84#,
      16#46#,
      16#F9#,
      16#10#,
      16#5D#);

   A1 : constant Byte_Array (0 .. 19) :=
     (16#5D#,
      16#06#,
      16#DC#,
      16#E8#,
      16#A1#,
      16#B4#,
      16#F1#,
      16#20#,
      16#2A#,
      16#1F#,
      16#C2#,
      16#B4#,
      16#BF#,
      16#8A#,
      16#BD#,
      16#9A#,
      16#A5#,
      16#0C#,
      16#07#,
      16#33#);

   P1 : constant Byte_Array (0 .. 31) :=
     (16#B3#,
      16#21#,
      16#C8#,
      16#16#,
      16#BF#,
      16#6C#,
      16#55#,
      16#1C#,
      16#2B#,
      16#0F#,
      16#DC#,
      16#0E#,
      16#0C#,
      16#0A#,
      16#8B#,
      16#91#,
      16#68#,
      16#EE#,
      16#12#,
      16#90#,
      16#85#,
      16#5D#,
      16#B3#,
      16#50#,
      16#50#,
      16#90#,
      16#AA#,
      16#53#,
      16#DB#,
      16#1A#,
      16#13#,
      16#C9#);

   C1 : constant Byte_Array (0 .. 31) :=
     (16#1D#,
      16#66#,
      16#44#,
      16#2F#,
      16#7A#,
      16#AC#,
      16#69#,
      16#AF#,
      16#CB#,
      16#3E#,
      16#02#,
      16#E4#,
      16#19#,
      16#CB#,
      16#01#,
      16#9A#,
      16#D9#,
      16#F3#,
      16#78#,
      16#45#,
      16#F5#,
      16#0A#,
      16#A5#,
      16#C8#,
      16#AC#,
      16#E6#,
      16#CE#,
      16#22#,
      16#BB#,
      16#CF#,
      16#2F#,
      16#9C#);

   T1 : constant Byte_Array (0 .. 15) :=
     (16#BE#,
      16#87#,
      16#57#,
      16#6E#,
      16#44#,
      16#5F#,
      16#07#,
      16#DD#,
      16#A3#,
      16#29#,
      16#DF#,
      16#F5#,
      16#15#,
      16#07#,
      16#45#,
      16#2F#);

   K2 : constant Key_Bytes (0 .. 31) :=
     (16#7F#,
      16#DE#,
      16#29#,
      16#D2#,
      16#ED#,
      16#15#,
      16#A6#,
      16#D4#,
      16#52#,
      16#FA#,
      16#66#,
      16#1F#,
      16#A5#,
      16#D1#,
      16#85#,
      16#3B#,
      16#45#,
      16#FF#,
      16#EE#,
      16#5E#,
      16#0C#,
      16#DF#,
      16#59#,
      16#48#,
      16#19#,
      16#9A#,
      16#F6#,
      16#CB#,
      16#E5#,
      16#38#,
      16#75#,
      16#BA#);

   IV2 : constant Byte_Array (0 .. 11) :=
     (16#C2#,
      16#93#,
      16#11#,
      16#BB#,
      16#DE#,
      16#52#,
      16#3D#,
      16#72#,
      16#71#,
      16#2E#,
      16#61#,
      16#15#);

   A2 : constant Byte_Array (0 .. 12) :=
     (16#5C#,
      16#34#,
      16#5A#,
      16#9B#,
      16#40#,
      16#81#,
      16#F3#,
      16#B2#,
      16#EE#,
      16#F6#,
      16#41#,
      16#5E#,
      16#52#);

   P2 : constant Byte_Array (0 .. 31) :=
     (16#B3#,
      16#25#,
      16#CC#,
      16#6B#,
      16#BB#,
      16#02#,
      16#49#,
      16#0C#,
      16#3D#,
      16#43#,
      16#5B#,
      16#18#,
      16#89#,
      16#C3#,
      16#5D#,
      16#EE#,
      16#9B#,
      16#54#,
      16#91#,
      16#CA#,
      16#F0#,
      16#16#,
      16#71#,
      16#EE#,
      16#F7#,
      16#07#,
      16#E9#,
      16#BB#,
      16#1C#,
      16#DA#,
      16#80#,
      16#41#);

   C2 : constant Byte_Array (0 .. 31) :=
     (16#CC#,
      16#53#,
      16#16#,
      16#73#,
      16#F0#,
      16#EB#,
      16#2C#,
      16#2F#,
      16#4D#,
      16#CE#,
      16#BF#,
      16#72#,
      16#6A#,
      16#A5#,
      16#1D#,
      16#07#,
      16#E2#,
      16#C1#,
      16#CD#,
      16#39#,
      16#DD#,
      16#A5#,
      16#79#,
      16#CD#,
      16#33#,
      16#CB#,
      16#78#,
      16#C2#,
      16#FD#,
      16#35#,
      16#E3#,
      16#D6#);

   T2 : constant Byte_Array (0 .. 15) :=
     (16#34#,
      16#CE#,
      16#E0#,
      16#DD#,
      16#28#,
      16#F1#,
      16#D2#,
      16#E6#,
      16#05#,
      16#90#,
      16#68#,
      16#4B#,
      16#D8#,
      16#5E#,
      16#A3#,
      16#F1#);

   --  True iff two byte arrays are equal element-for-element (length and content),
   --  comparing position-by-position regardless of either array's index base.
   function Eq (A, B : Byte_Array) return Boolean is
   begin
      if A'Length /= B'Length then
         return False;
      end if;
      for I in A'Range loop
         if A (I) /= B (B'First + (I - A'First)) then
            return False;
         end if;
      end loop;
      return True;
   end Eq;

   --  Run one AEAD known-answer case; report whether the ciphertext, tag, auth
   --  result and the recovered plaintext all match the vector.
   procedure Case_AEAD
     (Name : String; Key : Key_Bytes; IV : Nonce; AAD, P, C_Want, T_Want : Byte_Array)
   is
      C     : Byte_Array (0 .. P'Length - 1);   --  ciphertext produced by Encrypt
      P_Got : Byte_Array (0 .. P'Length - 1);   --  plaintext recovered by Decrypt
      T     : Auth_Tag;                          --  tag produced by Encrypt
      Ok    : Boolean;                           --  Decrypt's tag-authentication result
   begin
      --  Encrypt our P and check it reproduces the expected C/T; separately decrypt
      --  the expected C_Want/T_Want so the decrypt path is tested against the vector
      --  (not merely round-tripped against our own Encrypt output).
      Encrypt (Key, IV, AAD, P, C, T);
      Decrypt (Key, IV, AAD, C_Want, T_Want, P_Got, Ok);
      Put_Line
        ("[gcm] "
         & Name
         & " : "
         & (if Eq (C, C_Want) and then Eq (T, T_Want) and then Ok and then Eq (P_Got, P)
            then "PASS"
            else "FAIL"));
   end Case_AEAD;
begin
   delay until Clock + Milliseconds (200);
   ESP32S3.RNG.Enable_Entropy_Source;          --  CSPRNG entropy (RF-free target)

   Put_Line ("[gcm] AES-GCM known-answer tests (HW AES block + SW GHASH/CTR)");
   Case_AEAD ("AES-128-GCM", K1, IV1, A1, P1, C1, T1);
   Case_AEAD ("AES-256-GCM", K2, IV2, A2, P2, C2, T2);
   Put_Line ("[gcm] done");

   --  Nothing more to do; idle forever so the console output stays readable.
   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
