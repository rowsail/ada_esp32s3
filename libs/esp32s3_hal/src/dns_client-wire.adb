package body DNS_Client.Wire with SPARK_Mode => On is

   Max_Label : constant := 63;    --  RFC 1035: one label's byte ceiling

   procedure Build_A_Query
     (Name   : String;
      Id     : Interfaces.Unsigned_16;
      Buffer : out Query_Buffer;
      Length : out Natural;
      Ok     : out Boolean)
   is
      --  Writes land through Put, which LATCHES on a full buffer instead of
      --  overrunning (for a valid name the message tops out near 270 bytes,
      --  far under the buffer -- the latch is the proof-friendly guard, not
      --  an expected event).
      Pos         : Natural range 0 .. Max_Query_Bytes := 0;
      Overflowed  : Boolean := False;
      Label_Start : Natural := Name'First;

      procedure Put (Value : Parse.U8) is
      begin
         if Pos < Max_Query_Bytes then
            Buffer (Pos) := Value;
            Pos := Pos + 1;
         else
            Overflowed := True;
         end if;
      end Put;

   begin
      Buffer := (others => 0);
      Length := 0;
      Ok     := False;

      --  Header: Id, flags = standard query + recursion desired, QDCOUNT 1.
      Put (Parse.U8 (Id / 256));
      Put (Parse.U8 (Id mod 256));
      Put (16#01#);
      Put (16#00#);
      Put (0);
      Put (1);
      Put (0);
      Put (0);
      Put (0);
      Put (0);
      Put (0);
      Put (0);

      --  QNAME: dot-separated labels, each length-prefixed and 1 .. 63 bytes.
      --  A leading, trailing, or doubled dot yields an empty label: refused.
      for I in Name'First .. Name'Last + 1 loop
         pragma Loop_Invariant (Label_Start >= Name'First);
         pragma Loop_Invariant (Label_Start <= I);
         if I > Name'Last or else Name (I) = '.' then
            declare
               Label_Length : constant Natural := I - Label_Start;
            begin
               if Label_Length = 0 or else Label_Length > Max_Label then
                  return;                       --  Ok stays False
               end if;
               Put (Parse.U8 (Label_Length));
               for J in Label_Start .. I - 1 loop
                  Put (Parse.U8 (Character'Pos (Name (J))));
               end loop;
               if I <= Name'Last then      --  final iteration has no successor
                  Label_Start := I + 1;
               end if;
            end;
         end if;
      end loop;

      Put (0);                                  --  the root label
      Put (0);
      Put (1);                                  --  QTYPE  = A
      Put (0);
      Put (1);                                  --  QCLASS = IN

      if Overflowed or else Pos = 0 then
         Length := 0;                           --  cannot happen for a valid
         Ok     := False;                       --  name; refused regardless
      else
         Length := Pos;
         Ok     := True;
      end if;
   end Build_A_Query;

end DNS_Client.Wire;
