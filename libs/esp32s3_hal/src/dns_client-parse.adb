with ESP32S3.Endian;

package body DNS_Client.Parse with SPARK_Mode => On is

   use type Interfaces.Unsigned_16;

   Not_Found : constant A_Record := (Found => False, others => 0);

   function Find_A_Record
     (Msg : Byte_Array; Expected_Id : Interfaces.Unsigned_16) return A_Record
   is
      Last : constant Buffer_Index := Msg'Last;

      --  A cursor over the message.  It has headroom above Buffer_Index'Last so
      --  that a name walk running off the end of a truncated reply (Pos + 1 + Len,
      --  Len up to 255) cannot overflow the cursor type before the next bound test
      --  catches it; every actual buffer access is still guarded by Pos <= Last.
      subtype Cursor is Natural range 0 .. Max_Msg_Bytes + 511;

      --  Big-endian 16-bit read of Msg (Pos), Msg (Pos + 1).  Msg'First = 0 is
      --  restated here because a nested subprogram is verified against its own
      --  contract, not the enclosing Find_A_Record precondition.
      function U16 (Pos : Cursor) return Natural
      is (Natural (ESP32S3.Endian.Join_BE16 (Msg (Pos), Msg (Pos + 1))))
      with Pre => Msg'First = 0 and then Pos <= Last - 1;

      --  Advance Pos past a DNS name: consume labels until a 0 terminator, or
      --  stop at a 0xC0 compression pointer (2 bytes, the name ends there -- we do
      --  not need to follow it to reach the record after it).  Each label step
      --  strictly increases Pos (>= +2) and only runs while Pos <= Last, so the
      --  loop provably terminates and never reads past the received bytes even on
      --  a self-referential or truncated name.  Post: a walk that started within
      --  the buffer ends at most Last + 192 (one over-long label past the end); a
      --  Pos already past the end is left untouched.
      procedure Skip_Name (Pos : in out Cursor)
      with Pre  => Msg'First = 0 and then Pos <= Max_Msg_Bytes + 255,
           Post => Pos <= Integer'Max (Pos'Old, Last + 192)
      is
         Entry_Pos : constant Cursor := Pos;
         Len       : Natural;
      begin
         loop
            pragma Loop_Invariant (Pos <= Integer'Max (Entry_Pos, Last + 192));
            pragma Loop_Variant (Increases => Pos);
            exit when Pos > Last;
            Len := Natural (Msg (Pos));
            if Len = 0 then
               Pos := Pos + 1;               --  root label: name ends
               exit;
            elsif Len >= 16#C0# then
               Pos := Pos + 2;               --  compression pointer: name ends
               exit;
            else
               Pos := Pos + 1 + Len;         --  ordinary label, then continue
            end if;
         end loop;
      end Skip_Name;

   begin
      if Last < 11 then                       --  fewer than the 12 header bytes
         return Not_Found;
      end if;

      --  The reply must echo the transaction id we sent.
      if U16 (0) /= Natural (Expected_Id) then
         return Not_Found;
      end if;

      declare
         AnCount : constant Natural := U16 (6);   --  answer count
         Pos     : Cursor := 12;                  --  past the fixed header
      begin
         Skip_Name (Pos);                    --  the question's QNAME
         Pos := Pos + 4;                     --   + QTYPE + QCLASS

         for A in 1 .. AnCount loop
            pragma Loop_Invariant (Pos <= Last + 196);
            Skip_Name (Pos);                 --  answer NAME (usually a pointer)

            --  The fixed 10-byte RR header (type/class/ttl/rdlength) must lie
            --  within the received bytes before we index it.
            exit when Pos + 10 > Last;

            declare
               RRType : constant Natural := U16 (Pos);
               RDLen  : constant Natural := U16 (Pos + 8);
               RData  : constant Cursor  := Pos + 10;
            begin
               --  RDATA must fit too (written to avoid the RData + RDLen add
               --  overflowing: RData <= Last here, so Last - RData + 1 >= 1).
               exit when RDLen > Last - RData + 1;

               if RRType = 1 and then RDLen = 4 then     --  an IN A record
                  return
                    (Found => True,
                     B0    => Msg (RData),
                     B1    => Msg (RData + 1),
                     B2    => Msg (RData + 2),
                     B3    => Msg (RData + 3));
               end if;

               Pos := RData + RDLen;         --  skip to the next RR (<= Last + 1)
            end;
         end loop;
      end;

      return Not_Found;
   end Find_A_Record;

end DNS_Client.Parse;
