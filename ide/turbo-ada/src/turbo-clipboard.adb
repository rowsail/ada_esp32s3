with Ada.Strings.Wide_Wide_Unbounded;
with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with Turbo.Term;

package body Turbo.Clipboard is

   use Ada.Strings.Wide_Wide_Unbounded;

   Content : Unbounded_Wide_Wide_String;

   function Base64 (S : String) return String is
      Alphabet : constant String :=
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
      Result : String (1 .. ((S'Length + 2) / 3) * 4);
      R      : Positive := 1;
      I      : Positive := S'First;
      N      : Natural;
   begin
      while I <= S'Last loop
         N := Character'Pos (S (I)) * 65536;
         if I + 1 <= S'Last then
            N := N + Character'Pos (S (I + 1)) * 256;
         end if;
         if I + 2 <= S'Last then
            N := N + Character'Pos (S (I + 2));
         end if;
         Result (R) := Alphabet (N / 262144 + 1);
         Result (R + 1) := Alphabet ((N / 4096) mod 64 + 1);
         Result (R + 2) :=
           (if I + 1 <= S'Last then Alphabet ((N / 64) mod 64 + 1) else '=');
         Result (R + 3) :=
           (if I + 2 <= S'Last then Alphabet (N mod 64 + 1) else '=');
         R := R + 4;
         I := I + 3;
      end loop;
      return Result;
   end Base64;

   procedure Set (Text : Wide_Wide_String) is
      UTF8 : constant String :=
        Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode (Text);
   begin
      Content := To_Unbounded_Wide_Wide_String (Text);
      --  Terminals cap OSC 52 payloads (often around 100 kB); past that the
      --  internal clipboard still works.
      if UTF8'Length <= 64 * 1024 and then Term.Is_Active then
         Term.Write (Character'Val (27) & "]52;c;" & Base64 (UTF8)
                     & Character'Val (7));
      end if;
   end Set;

   function Get return Wide_Wide_String is (To_Wide_Wide_String (Content));

   function Is_Empty return Boolean is (Length (Content) = 0);

end Turbo.Clipboard;
