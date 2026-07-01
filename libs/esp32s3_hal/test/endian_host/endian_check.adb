with Ada.Text_IO;    use Ada.Text_IO;
with Interfaces;      use Interfaces;
with ESP32S3.Endian;  use ESP32S3.Endian;

--  Native check of the shared ESP32S3.Endian helpers against independent
--  arithmetic references (byte i weighted by 256**i, LE or BE) plus round-trips.
--  Exercises the REAL package, so if a lane is ever wrong this fails here.
procedure Endian_Check is
   Fails : Natural := 0;

   --  Representative byte values covering the low/high edges of every lane.
   Vals : constant array (0 .. 7) of U8 := (0, 1, 2, 127, 128, 200, 254, 255);

   procedure Note (Label : String; Bad : Natural; Cases : Natural) is
   begin
      Fails := Fails + Bad;
      Put_Line ("  " & Label & (if Bad = 0 then "PASS (" & Cases'Image & " cases)"
                                else "FAIL"));
   end Note;

begin
   Put_Line ("ESP32S3.Endian equivalence check:");

   --  Little-endian: Join vs weighted sum, and Split as its exact inverse.
   declare
      Bad, N : Natural := 0;
      O0, O1, O2, O3 : U8;
   begin
      for A of Vals loop
       for B of Vals loop
        for C of Vals loop
         for D of Vals loop
            N := N + 1;
            declare
               W   : constant U32 := Join_LE (A, B, C, D);
               Ref : constant U32 :=
                 U32 (A) + U32 (B) * 256 + U32 (C) * 65536 + U32 (D) * 16777216;
            begin
               if W /= Ref then Bad := Bad + 1; end if;
               Split_LE (W, O0, O1, O2, O3);
               if O0 /= A or else O1 /= B or else O2 /= C or else O3 /= D then
                  Bad := Bad + 1;
               end if;
            end;
         end loop;
        end loop;
       end loop;
      end loop;
      Note ("little-endian join/split . ", Bad, N);
   end;

   --  Big-endian 32: Join vs weighted sum (byte 0 = MSB) and Split inverse.
   declare
      Bad, N : Natural := 0;
      O0, O1, O2, O3 : U8;
   begin
      for A of Vals loop
       for B of Vals loop
        for C of Vals loop
         for D of Vals loop
            N := N + 1;
            declare
               W   : constant U32 := Join_BE32 (A, B, C, D);
               Ref : constant U32 :=
                 U32 (A) * 16777216 + U32 (B) * 65536 + U32 (C) * 256 + U32 (D);
            begin
               if W /= Ref then Bad := Bad + 1; end if;
               Split_BE32 (W, O0, O1, O2, O3);
               if O0 /= A or else O1 /= B or else O2 /= C or else O3 /= D then
                  Bad := Bad + 1;
               end if;
            end;
         end loop;
        end loop;
       end loop;
      end loop;
      Note ("big-endian 32 join/split . ", Bad, N);
   end;

   --  Big-endian 16: exhaustive over all 65536 byte pairs.
   declare
      Bad : Natural := 0;
      Hi_O, Lo_O : U8;
   begin
      for Hi in 0 .. 255 loop
         for Lo in 0 .. 255 loop
            declare
               V   : constant U16 := Join_BE16 (U8 (Hi), U8 (Lo));
               Ref : constant U16 := U16 (Hi) * 256 + U16 (Lo);
            begin
               if V /= Ref then Bad := Bad + 1; end if;
               Split_BE16 (V, Hi_O, Lo_O);
               if Natural (Hi_O) /= Hi or else Natural (Lo_O) /= Lo then
                  Bad := Bad + 1;
               end if;
            end;
         end loop;
      end loop;
      Note ("big-endian 16 join/split . ", Bad, 65536);
   end;

   if Fails = 0 then
      Put_Line ("ESP32S3.Endian: all helpers match the arithmetic reference.");
   else
      Put_Line ("FAILURES:" & Fails'Image);
   end if;
end Endian_Check;
