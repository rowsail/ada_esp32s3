--  SPARKNaCl known-answer tests on the bare-metal ESP32-S3.
--  ========================================================
--
--  What it demonstrates
--    Runs the vendored, formally-verified SPARKNaCl crypto primitives on this
--    target and checks each one against a published test vector -- proving the
--    pure-Ada/SPARK crypto computes correct results on the S3 (the foundation
--    for a pure-Ada TLS stack).  Two primitives are exercised:
--      * SHA-256 hashing       (SPARKNaCl.Hashing.SHA256)
--      * X25519 scalar mult    (SPARKNaCl.Scalar.Mult, Curve25519 ECDH)
--    Then it shows the hardware RNG is producing live entropy.
--
--  Build & run
--    ./x run esp32s3_sparknacl_kat
--    Needs the embedded profile (not the default light-tasking); build.sh sets
--    ESP32S3_RTS_PROFILE=embedded.
--
--  How to read the output
--    Each known-answer test prints "[kat] <name> : PASS" (or FAIL).  A run that
--    passes prints PASS on both checks, then a line of three RNG words (which
--    differ from run to run, and from each other), then "[kat] done":
--      [kat] SPARKNaCl known-answer tests (pure Ada/SPARK on the S3)
--      [kat] SHA-256(abc)   : PASS
--      [kat] X25519 RFC7748 : PASS
--      [kat] RNG (entropy on): <w0> <w1> <w2>
--      [kat] done
--
--  Hardware / wiring
--    None (self-contained): the test vectors are compiled in and the RNG is
--    on-chip.
with Ada.Real_Time; use Ada.Real_Time;
with Interfaces;
with SPARKNaCl;
with SPARKNaCl.Hashing.SHA256;
with SPARKNaCl.Scalar;
with ESP32S3.RNG;
with ESP32S3.Log; use ESP32S3.Log;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   use type SPARKNaCl.Byte_Seq;
   subtype Byte_Seq is SPARKNaCl.Byte_Seq;
   subtype Bytes_32 is SPARKNaCl.Bytes_32;

   procedure Check (Name : String; Pass : Boolean) is
   begin
      Put_Line ("[kat] " & Name & " : " & (if Pass then "PASS" else "FAIL"));
   end Check;

   --  Known-answer vectors.  Legend:
   --    Abc      message input to hash, the three ASCII bytes "abc"
   --    SHA_Want expected SHA-256 digest of Abc
   --    X_Scalar X25519 scalar  (the "k" / private value)
   --    X_U      X25519 base point coordinate (the "u" input)
   --    X_Want   expected X25519 result, Mult (X_Scalar, X_U)
   --  Provenance:
   --    SHA-256("abc") digest -- FIPS 180-4, Appendix B.1 worked example.
   --    X25519 triple (k, u, result) -- RFC 7748 section 5.2, first test
   --    vector.  Both are reproducible from those documents.

   --  SHA-256("abc") (FIPS 180-4 example).
   Abc      : constant Byte_Seq (0 .. 2) := (16#61#, 16#62#, 16#63#);
   SHA_Want : constant Bytes_32 :=
     (16#ba#, 16#78#, 16#16#, 16#bf#, 16#8f#, 16#01#, 16#cf#, 16#ea#,
      16#41#, 16#41#, 16#40#, 16#de#, 16#5d#, 16#ae#, 16#22#, 16#23#,
      16#b0#, 16#03#, 16#61#, 16#a3#, 16#96#, 16#17#, 16#7a#, 16#9c#,
      16#b4#, 16#10#, 16#ff#, 16#61#, 16#f2#, 16#00#, 16#15#, 16#ad#);

   --  X25519 scalar multiplication (RFC 7748 section 5.2, first vector).
   X_Scalar : constant Bytes_32 :=
     (16#a5#, 16#46#, 16#e3#, 16#6b#, 16#f0#, 16#52#, 16#7c#, 16#9d#,
      16#3b#, 16#16#, 16#15#, 16#4b#, 16#82#, 16#46#, 16#5e#, 16#dd#,
      16#62#, 16#14#, 16#4c#, 16#0a#, 16#c1#, 16#fc#, 16#5a#, 16#18#,
      16#50#, 16#6a#, 16#22#, 16#44#, 16#ba#, 16#44#, 16#9a#, 16#c4#);
   X_U : constant Bytes_32 :=
     (16#e6#, 16#db#, 16#68#, 16#67#, 16#58#, 16#30#, 16#30#, 16#db#,
      16#35#, 16#94#, 16#c1#, 16#a4#, 16#24#, 16#b1#, 16#5f#, 16#7c#,
      16#72#, 16#66#, 16#24#, 16#ec#, 16#26#, 16#b3#, 16#35#, 16#3b#,
      16#10#, 16#a9#, 16#03#, 16#a6#, 16#d0#, 16#ab#, 16#1c#, 16#4c#);
   X_Want : constant Bytes_32 :=
     (16#c3#, 16#da#, 16#55#, 16#37#, 16#9d#, 16#e9#, 16#c6#, 16#90#,
      16#8e#, 16#94#, 16#ea#, 16#4d#, 16#f2#, 16#8d#, 16#08#, 16#4f#,
      16#32#, 16#ec#, 16#cf#, 16#03#, 16#49#, 16#1c#, 16#71#, 16#f7#,
      16#54#, 16#b4#, 16#07#, 16#55#, 16#77#, 16#a2#, 16#85#, 16#52#);

   --  Let the console come up before the first line (USB-serial settle).
   Console_Settle_Ms : constant := 200;

   --  Print width, in hex digits, of one 32-bit RNG word.
   RNG_Word_Hex_Digits : constant := 8;

   --  Number of RNG words to sample as the liveness check.
   RNG_Sample_Count : constant := 3;

   --  Park here forever once the tests are done; one-hour ticks just keep the
   --  task alive without busy-waiting.
   Idle_Tick_Seconds : constant := 3600;
begin
   delay until Clock + Milliseconds (Console_Settle_Ms);

   --  Enable a real hardware entropy source (internal 8 MHz clock + SAR ADC
   --  sampling) before using the RNG for anything cryptographic -- required on
   --  this RF-free bare-metal target so the RNG is a CSPRNG, not just jitter.
   ESP32S3.RNG.Enable_Entropy_Source;

   Put_Line ("[kat] SPARKNaCl known-answer tests (pure Ada/SPARK on the S3)");
   Check ("SHA-256(abc)  ", SPARKNaCl.Hashing.SHA256.Hash (Abc) = SHA_Want);
   Check ("X25519 RFC7748", SPARKNaCl.Scalar.Mult (X_Scalar, X_U) = X_Want);

   --  Show the entropy source is live: a few RNG words (which should all differ).
   Put ("[kat] RNG (entropy on):");
   for K in 1 .. RNG_Sample_Count loop
      Put (" ");
      Put_Hex (Interfaces.Unsigned_32 (ESP32S3.RNG.Read), RNG_Word_Hex_Digits);
   end loop;
   New_Line;
   Put_Line ("[kat] done");

   loop
      delay until Clock + Seconds (Idle_Tick_Seconds);
   end loop;
end Main;
