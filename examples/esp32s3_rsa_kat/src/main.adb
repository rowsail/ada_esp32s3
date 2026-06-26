--  ESP32-S3 RSA accelerator known-answer test (KAT)
--  ================================================
--  What it demonstrates: one RSA-2048 modular exponentiation
--    Z = X^65537 mod M -- exactly an RSA signature *verify* (recover the padded
--    hash from a signature X under public key (M, e=65537)) -- on the hardware
--    RSA/MPI unit (ESP32S3.RSA.Mod_Exp), checked against a precomputed answer.
--    It runs the modexp twice: once with a host-supplied Montgomery constant
--    R^2, once letting the driver compute R^2 in software (works on any modulus,
--    e.g. an X.509 cert's).  Both must reproduce the same answer.
--
--  Build & run: ./x run esp32s3_rsa_kat
--    Uses the embedded runtime profile (build.sh sets ESP32S3_RTS_PROFILE=embedded).
--
--  How to read the output: four lines after the banner.  PASS looks like:
--    [rsa] ESP32-S3 RSA accelerator KAT (X^65537 mod M, 2048-bit)
--    [rsa] host-R2 : PASS
--    [rsa] soft-R2 : PASS
--    [rsa] done
--    A "FAIL" means the hardware finished but the result mismatched the vector;
--    a "hardware did not complete (timeout)" line means the accelerator never
--    signalled done within the bounded wait (a hardware fault).
--
--  Hardware: none (self-contained -- the modexp engine is on-chip).
--
--  Vector legend (all operands are 64-word little-endian limb arrays = 2048 bit):
--    M_Mod   M  -- the RSA public modulus (an RSA-2048 N; odd, as every N is).
--    X_Base  X  -- the base, i.e. the signature value being exponentiated.
--    Y_Exp   Y  -- the public exponent e = 65537, the conventional RSA "F4".
--    R2      R^2 mod M, the Montgomery constant with R = 2^(32*64) = 2^2048;
--               an optimisation input, redundant with M (recomputable from it).
--    Z_Want  the expected result X^Y mod M.
--
--  Vector provenance: computed on the host (Python/OpenSSL bignum) for a fixed
--    RSA-2048 key; no generator script is committed in this repo, so M/X/R2/Z are
--    carried here as literals.  (Inferred from the driver/source comments: there
--    is no committed script to cite, and these are not a published NIST count.)
--    The soft-R2 path independently recomputes R^2 from M on-chip, so it also
--    serves as a cross-check that R2 below is the correct Montgomery constant.
with Ada.Real_Time; use Ada.Real_Time;
with ESP32S3.RSA;    use ESP32S3.RSA;
with ESP32S3.RNG;
with ESP32S3.Log;    use ESP32S3.Log;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   use type Word;

   M_Mod : constant Word_Array (0 .. 63) :=
     (16#D106612F#, 16#B2833433#, 16#11818EBA#, 16#B8FB2FF0#, 16#C666F204#, 16#A3C2E3EB#,
      16#2613AD2A#, 16#2196B619#, 16#3B35871D#, 16#B9C4853A#, 16#7B3379B0#, 16#0DAA293A#,
      16#4B44E2EC#, 16#CE34A9D9#, 16#98F36757#, 16#D34D2086#, 16#ACCCAEC8#, 16#197D099E#,
      16#996913C0#, 16#C57F16E0#, 16#8FB93CC4#, 16#DDE9AA0A#, 16#4AAB3EBF#, 16#93F07B27#,
      16#9B43A9C6#, 16#E37127EF#, 16#9DE0EADF#, 16#49AB3756#, 16#ABF7D106#, 16#9C00126D#,
      16#E17E0F02#, 16#4FF681AC#, 16#7080A0C2#, 16#4B4B2B1F#, 16#370D29FF#, 16#37F707B3#,
      16#BC27195F#, 16#D5B036A7#, 16#4588A803#, 16#FA3245E4#, 16#5113402D#, 16#681210DD#,
      16#8B864CC4#, 16#DE037970#, 16#F24AACFA#, 16#3E913D83#, 16#B0864678#, 16#90C44B9C#,
      16#B67D93F0#, 16#1F3AEC34#, 16#8B983504#, 16#7AAF0F5C#, 16#D3E774ED#, 16#EF4F4A79#,
      16#C0D84904#, 16#8655071E#, 16#6D924A92#, 16#B28FE4A8#, 16#8B260D34#, 16#202BD6C1#,
      16#D6A836B1#, 16#71319EA7#, 16#A55298D2#, 16#E3FA5D06#);

   X_Base : constant Word_Array (0 .. 63) :=
     (16#6169DECB#, 16#A78F964D#, 16#B612EB37#, 16#80217D33#, 16#CE9F75F2#, 16#5A74FE83#,
      16#26CF9834#, 16#FD0529D0#, 16#8B7A671A#, 16#6DCAD8A7#, 16#DB7C451B#, 16#526F74D0#,
      16#22AC7205#, 16#8D1394D4#, 16#46B2C746#, 16#2FB1A032#, 16#042B5447#, 16#501D400B#,
      16#CF4A6650#, 16#9C9FB51B#, 16#3F25036F#, 16#54FD3F7F#, 16#492D3DA6#, 16#688EB98E#,
      16#AF8873E2#, 16#E4545C17#, 16#ADCC20D6#, 16#30C8B4AB#, 16#D8CC0ADD#, 16#348D42DA#,
      16#BEB2A2F1#, 16#AD2B2B63#, 16#A3F8CFE1#, 16#630080C7#, 16#0EFE88EF#, 16#F84CF7B2#,
      16#47241759#, 16#14051040#, 16#75A842AE#, 16#E9F74FB5#, 16#36C812FE#, 16#0DE762F2#,
      16#355CA8FF#, 16#946C38A4#, 16#B0C16911#, 16#6A63B52E#, 16#4FE609CE#, 16#9C952A4A#,
      16#4DF2B414#, 16#696B72CA#, 16#AD64B0B6#, 16#86312DB5#, 16#2270FC20#, 16#1671922A#,
      16#AC9842EF#, 16#87DFAAF3#, 16#1FB4B95F#, 16#98096350#, 16#F5C559FA#, 16#3B1A576B#,
      16#DF8A0CBB#, 16#79D202E9#, 16#5711698E#, 16#1C9F080E#);

   R2 : constant Word_Array (0 .. 63) :=
     (16#3172E674#, 16#73363C97#, 16#5AD913A8#, 16#5C6F8593#, 16#A30DE938#, 16#BF9280A4#,
      16#A085B953#, 16#3D9F71DF#, 16#9A63D63E#, 16#E8D2FFA8#, 16#CD2F68EF#, 16#BFA58BBC#,
      16#272F9393#, 16#2114B4A8#, 16#259FC008#, 16#ED10E6B2#, 16#AAE53839#, 16#FD7B907B#,
      16#ECB1D3DF#, 16#4666B6D2#, 16#C938240F#, 16#7D8FC4F3#, 16#6A10DA11#, 16#6FC8812E#,
      16#7BFAB4F1#, 16#EB722BC2#, 16#14CEBB9B#, 16#053A8BBE#, 16#FE3ECEA2#, 16#7742DB6B#,
      16#136CC92A#, 16#3D29140A#, 16#F2D161E1#, 16#71B8B300#, 16#5DD53570#, 16#9AE8B99C#,
      16#88A96178#, 16#008B8260#, 16#5F14CFFA#, 16#34A80211#, 16#B2F872E7#, 16#4C731157#,
      16#2E3CE7C1#, 16#3EC8E9B5#, 16#50A72436#, 16#8424149C#, 16#EBEC2B59#, 16#7A62BBEB#,
      16#00EF0F69#, 16#07390261#, 16#3617F09B#, 16#3C15DF3E#, 16#9EA6762A#, 16#F7BA3C74#,
      16#69FEC1D1#, 16#03C07719#, 16#F0AE3251#, 16#5D610420#, 16#B763BC2F#, 16#0A83C3A9#,
      16#F1E0419D#, 16#79DA0BC1#, 16#B2F77C84#, 16#24D472BD#);

   Z_Want : constant Word_Array (0 .. 63) :=
     (16#058FC365#, 16#945C55B7#, 16#A645F3E8#, 16#1EFDAB9C#, 16#7102C604#, 16#9A0F23E2#,
      16#D46DD368#, 16#7E7218EE#, 16#44B04783#, 16#C4A81590#, 16#710B43CB#, 16#936CE0F4#,
      16#6EE20D91#, 16#138D4677#, 16#9A9E2B87#, 16#57C32E24#, 16#1084C6A3#, 16#DE350689#,
      16#35E3F4E9#, 16#A183115C#, 16#CFF7DE3F#, 16#EB12C1B0#, 16#18DC7CA5#, 16#16A20799#,
      16#013AD239#, 16#5F42FF52#, 16#25920EE0#, 16#2C6DD9C0#, 16#2D408218#, 16#C0CF7408#,
      16#4B7AA9AA#, 16#09A9508C#, 16#645D1629#, 16#18DC59D6#, 16#3948C1BD#, 16#54D32709#,
      16#B271198F#, 16#1E8B6A47#, 16#6B3E1B36#, 16#58BBFE37#, 16#12245ECE#, 16#1890E5FC#,
      16#4E791BFD#, 16#554CE883#, 16#43C64E59#, 16#6BEE28C8#, 16#CB11967A#, 16#F427890A#,
      16#24BB0818#, 16#C07A7783#, 16#BDC4FD90#, 16#499308FE#, 16#B9E79ECA#, 16#108BFB80#,
      16#4329AADF#, 16#37C3E4C0#, 16#14AC7524#, 16#37A6B927#, 16#00F15285#, 16#9AED8D00#,
      16#BB6C496C#, 16#F55FA5B6#, 16#066967B6#, 16#AE7C4572#);

   --  RSA public exponent e = 65537 = 2^16 + 1 (the conventional "F4" exponent),
   --  encoded as 16#0001_0001# in the least-significant 32-bit limb of a 64-word
   --  little-endian operand.
   Public_Exponent_F4 : constant Word := 16#0001_0001#;   --  65537 = 2^16 + 1

   Y_Exp : constant Word_Array (0 .. 63) := (0 => Public_Exponent_F4, others => 0);

   Z  : Word_Array (0 .. 63);
   Ok : Boolean;

   function Eq (A, B : Word_Array) return Boolean is
   begin
      for I in A'Range loop
         if A (I) /= B (B'First + (I - A'First)) then
            return False;
         end if;
      end loop;
      return True;
   end Eq;
begin
   delay until Clock + Milliseconds (200);
   ESP32S3.RNG.Enable_Entropy_Source;            --  CSPRNG entropy (RF-free target)

   Put_Line ("[rsa] ESP32-S3 RSA accelerator KAT (X^65537 mod M, 2048-bit)");

   --  (1) HW modexp with a host-precomputed Montgomery constant R^2.
   Mod_Exp (X => X_Base, Y => Y_Exp, M => M_Mod, R2 => R2, Z => Z, Ok => Ok);
   if not Ok then
      Put_Line ("[rsa] host-R2 : hardware did not complete (timeout)");
   else
      Put_Line ("[rsa] host-R2 : " & (if Eq (Z, Z_Want) then "PASS" else "FAIL"));
   end if;

   --  (2) Same, but R^2 computed in software -- works on any modulus (e.g. a cert).
   Mod_Exp (X => X_Base, Y => Y_Exp, M => M_Mod, Z => Z, Ok => Ok);
   if not Ok then
      Put_Line ("[rsa] soft-R2 : hardware did not complete (timeout)");
   else
      Put_Line ("[rsa] soft-R2 : " & (if Eq (Z, Z_Want) then "PASS" else "FAIL"));
   end if;
   Put_Line ("[rsa] done");

   --  Nothing more to do; idle forever so the console output stays readable.
   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
