package body TLS_Client.Scan with SPARK_Mode => On is

   use type U8;

   --  A stretch of the buffer: where it starts and how long it is.  One
   --  parameter rather than two Naturals side by side, which a positional call
   --  can swap without anything noticing.
   type Region is record
      At_Byte : Natural;
      Length  : Natural;
   end record;

   procedure Parse_Hello (Buf : Byte_Array; Len : Natural; Info : out Hello_Info) is
      HS_Server_Hello : constant U8 := 2;
      Pos             : Natural := 0;

      function U16_At (I : Natural) return Natural
      is (Natural (Buf (I)) * 256 + Natural (Buf (I + 1)))
      with Pre  => Buf'First = 0
                   and then Buf'Last < Natural'Last / 2
                   and then Len <= Buf'Last + 1
                   and then Len >= 2
                   and then I <= Len - 2,
           Post => U16_At'Result <= 65_535;
      --  A curve's share, copied out of a key_share entry.  One procedure per
      --  curve: the offsets differ and each is easier to check on its own than
      --  as another arm of a chain of and-thens.
      procedure Take_X25519 (At_Key : Natural)
      with Pre => Buf'First = 0
                  and then Buf'Last < Natural'Last / 2
                  and then Len <= Buf'Last + 1
                  and then Len >= 32
                  and then At_Key <= Len - 32
      is
      begin
         for I in 0 .. 31 loop
            Info.X25519 (I) := Buf (At_Key + I);
         end loop;
         Info.Group := 16#001D#;
         Info.Have_Share := True;
      end Take_X25519;

      procedure Take_P256 (At_Point : Natural)
      with Pre => Buf'First = 0
                  and then Buf'Last < Natural'Last / 2
                  and then Len <= Buf'Last + 1
                  and then Len >= 64
                  and then At_Point <= Len - 64
      is
      begin
         for I in 0 .. 31 loop
            Info.P256_X (I) := Buf (At_Point + I);
            Info.P256_Y (I) := Buf (At_Point + 32 + I);
         end loop;
         Info.Group := 16#0017#;
         Info.Have_Share := True;
      end Take_P256;

      --  The key_share extension: one entry, whichever group the server picked.
      procedure Take_Key_Share (Ext : Region)
      with Pre => Buf'First = 0
                  and then Buf'Last < Natural'Last / 2
                  and then Len <= Buf'Last + 1
                  and then Len >= 2
                  and then Ext.At_Byte <= Len
                  and then Ext.Length <= Len - Ext.At_Byte
      is
         Group, Sh_Len : Natural;
      begin
         if Ext.Length < 4 then
            return;                          --  no group and length in it
         end if;
         Group := U16_At (Ext.At_Byte);
         Sh_Len := U16_At (Ext.At_Byte + 2);

         if Group = 16#001D# and then Sh_Len = 32 and then Ext.Length >= 36 then
            Take_X25519 (Ext.At_Byte + 4);
         elsif Group = 16#0017#
           and then Sh_Len = 65
           and then Ext.Length >= 69
         then
            --  An uncompressed point, or nothing this client can use.
            if Buf (Ext.At_Byte + 4) = 16#04# then
               Take_P256 (Ext.At_Byte + 5);
            end if;
         end if;
      end Take_Key_Share;
   begin
      Info := (others => <>);

      --  A ServerHello is at least: type(1) length(3) version(2) random(32)
      --  session_id_len(1) suite(2) compression(1) ext_len(2).
      if Len < 44 or else Buf (0) /= HS_Server_Hello then
         return;
      end if;

      Pos := 4 + 2 + 32;                      --  header, legacy_version, random
      --  legacy_session_id_echo, whose length the server chooses.
      if Natural (Buf (Pos)) > Len - Pos - 1 then
         return;                              --  echo runs past the message
      end if;
      Pos := Pos + 1 + Natural (Buf (Pos));

      if Pos > Len - 6 then                   --  suite(2) compression(1) ext_len(2)
         return;
      end if;
      Info.Suite := U16 (U16_At (Pos));
      Pos := Pos + 2 + 1 + 2;                 --  suite, compression, ext_len

      --  Walk the extensions for key_share (51) and pre_shared_key (41).
      while Pos <= Len - 4 loop
         pragma Loop_Invariant (Pos <= Len - 4);
         pragma Loop_Variant (Increases => Pos);
         declare
            Ext_Type : constant Natural := U16_At (Pos);
            Ext_Len  : constant Natural := U16_At (Pos + 2);
            Body_At  : constant Natural := Pos + 4;
         begin
            --  The body has to be present before anything inside it is read:
            --  the loop condition only guarantees the four header bytes.
            if Ext_Len <= Len - Body_At then
               if Ext_Type = 51 then
                  Take_Key_Share ((At_Byte => Body_At, Length => Ext_Len));
               elsif Ext_Type = 41 then
                  --  pre_shared_key: the server took our only offer.
                  Info.Resumed_PSK := True;
               end if;
            end if;

            exit when Ext_Len > Len - Body_At - 1;   --  nothing further fits
            Pos := Body_At + Ext_Len;
         end;
      end loop;
   end Parse_Hello;

   procedure Walk (Buf : Byte_Array; Len : Natural; Info : out Flight_Info) is
      Pos : Natural := 0;

      --  A 24-bit handshake length, and a 16-bit one.  Both read from the
      --  server's bytes, so both are bounded by construction rather than by
      --  what the server meant.
      --  The preconditions carry the buffer's shape as well as the index,
      --  because a nested function is verified on its own contract.
      function U24_At (I : Natural) return Natural
      is (Natural (Buf (I)) * 65_536
          + Natural (Buf (I + 1)) * 256
          + Natural (Buf (I + 2)))
      with Pre  => Buf'First = 0
                   and then Buf'Last < Natural'Last / 2
                   and then Len <= Buf'Last + 1
                   and then Len >= 3
                   and then I <= Len - 3,
           Post => U24_At'Result <= 16#FF_FFFF#;

      function U16_At (I : Natural) return Natural
      is (Natural (Buf (I)) * 256 + Natural (Buf (I + 1)))
      with Pre  => Buf'First = 0
                   and then Buf'Last < Natural'Last / 2
                   and then Len <= Buf'Last + 1
                   and then Len >= 2
                   and then I <= Len - 2,
           Post => U16_At'Result <= 65_535;
      --  CertificateVerify's fixed fields: two bytes of algorithm and two of
      --  signature length, present only if the body is long enough for them.
      procedure Take_Cert_Verify (Msg : Region)
      with Pre  => Buf'First = 0
                   and then Buf'Last < Natural'Last / 2
                   and then Len <= Buf'Last + 1
                   and then Len >= 2
                   and then Msg.At_Byte <= Len
                   and then Msg.Length <= Len - Msg.At_Byte
                   --  It may return without touching these, so what holds on
                   --  the way out has to hold on the way in.
                   and then (if Info.CV_Sig_First <= Info.CV_Sig_Last
                             then Info.CV_Sig_Last < Len),
           Post => (if Info.CV_Sig_First <= Info.CV_Sig_Last
                    then Info.CV_Sig_Last < Len)
                   and then Info.Chain_Count = Info.Chain_Count'Old
                   and then Info.Chain = Info.Chain'Old
                   and then Info.Have_Cert = Info.Have_Cert'Old
                   and then Info.Cert_First = Info.Cert_First'Old
                   and then Info.Cert_Last = Info.Cert_Last'Old
                   and then Info.Fin_First = Info.Fin_First'Old
                   and then Info.Fin_Last = Info.Fin_Last'Old
      is
         Sig_Len : Natural;
      begin
         if Msg.Length < 4 then
            return;                          --  nothing to read it from
         end if;
         Info.CV_Alg := U16 (U16_At (Msg.At_Byte));
         Sig_Len := U16_At (Msg.At_Byte + 2);
         --  The signature must fill the body exactly.
         if Sig_Len = Msg.Length - 4 and then Sig_Len > 0 then
            Info.CV_Sig_First := Msg.At_Byte + 4;
            Info.CV_Sig_Last := Msg.At_Byte + 4 + Sig_Len - 1;
         end if;
      end Take_Cert_Verify;

      --  Note one certificate of the list: in the chain, and as the leaf if it
      --  is the first.  A chain longer than Max_Chain keeps its first entries.
      procedure Record_Cert (Cert : Region)
      with Pre  => Cert.Length > 0
                   and then Cert.At_Byte <= Len - Cert.Length
                   and then Info.Chain_Count <= Max_Chain
                   and then (if Info.Have_Cert
                             then Info.Cert_First <= Info.Cert_Last
                                  and then Info.Cert_Last < Len)
                   and then (for all K in 1 .. Info.Chain_Count =>
                               Info.Chain (K).First <= Info.Chain (K).Last
                               and then Info.Chain (K).Last < Len),
           Post => Info.Chain_Count <= Max_Chain
                   and then Info.Have_Cert
                   and then Info.Cert_First <= Info.Cert_Last
                   and then Info.Cert_Last < Len
                   and then (for all K in 1 .. Info.Chain_Count =>
                               Info.Chain (K).First <= Info.Chain (K).Last
                               and then Info.Chain (K).Last < Len)
                   and then Info.CV_Sig_First = Info.CV_Sig_First'Old
                   and then Info.CV_Sig_Last = Info.CV_Sig_Last'Old
                   and then Info.Fin_First = Info.Fin_First'Old
                   and then Info.Fin_Last = Info.Fin_Last'Old
      is
      begin
         if Info.Chain_Count < Max_Chain then
            Info.Chain_Count := Info.Chain_Count + 1;
            Info.Chain (Info.Chain_Count) :=
              (First => Cert.At_Byte, Last => Cert.At_Byte + Cert.Length - 1);
         end if;
         if not Info.Have_Cert then
            Info.Cert_First := Cert.At_Byte;                     --  the leaf
            Info.Cert_Last := Cert.At_Byte + Cert.Length - 1;
            Info.Have_Cert := True;
         end if;
      end Record_Cert;

      --  The certificate_list of a Certificate message: [len(3)][DER]
      --  [extlen(2)][exts], repeated.  Its own procedure -- the walk that calls
      --  it is nested deeply enough already, and this is the part a reader
      --  needs to check most carefully.
      procedure Take_Certificates (Msg : Region)
      with Pre => Buf'First = 0
                  and then Buf'Last < Natural'Last / 2
                  and then Len <= Buf'Last + 1
                  and then Len >= 3
                  and then Msg.At_Byte <= Len
                  and then Msg.Length <= Len - Msg.At_Byte
                  and then Info.Chain_Count <= Max_Chain
                  and then (if Info.Have_Cert
                            then Info.Cert_First <= Info.Cert_Last
                                 and then Info.Cert_Last < Len)
                  and then (for all K in 1 .. Info.Chain_Count =>
                              Info.Chain (K).First <= Info.Chain (K).Last
                              and then Info.Chain (K).Last < Len),
           Post => Info.Chain_Count <= Max_Chain
                   and then (if Info.Have_Cert
                             then Info.Cert_First <= Info.Cert_Last
                                  and then Info.Cert_Last < Len)
                   and then (for all K in 1 .. Info.Chain_Count =>
                               Info.Chain (K).First <= Info.Chain (K).Last
                               and then Info.Chain (K).Last < Len)
                   and then Info.CV_Sig_First = Info.CV_Sig_First'Old
                   and then Info.CV_Sig_Last = Info.CV_Sig_Last'Old
                   and then Info.Fin_First = Info.Fin_First'Old
                   and then Info.Fin_Last = Info.Fin_Last'Old
      is
         Msg_End  : constant Natural := Msg.At_Byte + Msg.Length;
         Ctx_Len  : Natural;
         Cert_Pos : Natural;
         List_End : Natural;
      begin
         --  The body must hold the context-length byte and the three-byte list
         --  length before either is read.
         if Msg.Length < 4 then
            return;
         end if;
         Ctx_Len := Natural (Buf (Msg.At_Byte));
         if Ctx_Len > Msg.Length - 4 then
            return;                          --  context runs past the message
         end if;

         Cert_Pos := Msg.At_Byte + 1 + Ctx_Len;
         List_End := Natural'Min (Cert_Pos + 3 + U24_At (Cert_Pos), Msg_End);
         Cert_Pos := Cert_Pos + 3;

         while Cert_Pos + 3 <= List_End loop
            pragma Loop_Invariant (Cert_Pos + 3 <= List_End);
            pragma Loop_Invariant (List_End <= Len);
            pragma Loop_Invariant (Info.Chain_Count <= Max_Chain);
            pragma Loop_Invariant
              (if Info.Have_Cert
               then Info.Cert_First <= Info.Cert_Last
                    and then Info.Cert_Last < Len);
            pragma Loop_Invariant
              (for all K in 1 .. Info.Chain_Count =>
                 Info.Chain (K).First <= Info.Chain (K).Last
                 and then Info.Chain (K).Last < Len);
            pragma Loop_Invariant (Info.CV_Sig_First = Info.CV_Sig_First'Loop_Entry);
            pragma Loop_Invariant (Info.CV_Sig_Last = Info.CV_Sig_Last'Loop_Entry);
            pragma Loop_Invariant (Info.Fin_First = Info.Fin_First'Loop_Entry);
            pragma Loop_Invariant (Info.Fin_Last = Info.Fin_Last'Loop_Entry);
            pragma Loop_Variant (Increases => Cert_Pos);

            declare
               Cert_Len : constant Natural := U24_At (Cert_Pos);
               Cert_At  : constant Natural := Cert_Pos + 3;
            begin
               exit when Cert_Len = 0 or else Cert_Len > List_End - Cert_At;
               Record_Cert ((At_Byte => Cert_At, Length => Cert_Len));

               Cert_Pos := Cert_At + Cert_Len;
               exit when Cert_Pos + 2 > List_End;           --  no extensions
               Cert_Pos := Cert_Pos + 2 + U16_At (Cert_Pos);
            end;
         end loop;
      end Take_Certificates;
   begin
      Info := (others => <>);

      while Pos + 4 <= Len loop
         pragma Loop_Invariant (Pos + 4 <= Len);
         pragma Loop_Invariant (Info.Chain_Count <= Max_Chain);
         pragma Loop_Invariant
           (if Info.Have_Cert
            then Info.Cert_First <= Info.Cert_Last and then Info.Cert_Last < Len);
         pragma Loop_Invariant
           (for all K in 1 .. Info.Chain_Count =>
              Info.Chain (K).First <= Info.Chain (K).Last
              and then Info.Chain (K).Last < Len);
         pragma Loop_Invariant
           (if Info.CV_Sig_First <= Info.CV_Sig_Last then Info.CV_Sig_Last < Len);
         pragma Loop_Invariant
           (if Info.Fin_First <= Info.Fin_Last then Info.Fin_Last < Len);
         pragma Loop_Variant (Increases => Pos);

         declare
            MType : constant U8 := Buf (Pos);
            MLen  : constant Natural := U24_At (Pos + 1);
            Body_At : constant Natural := Pos + 4;   --  first byte of the body
         begin
            exit when MLen > Len - Body_At;          --  not fully present yet

            --  An if-chain rather than a case: every other message type is
            --  simply passed over, and a case would need an empty branch to
            --  say so.
            if MType = 11 then                       --  Certificate
               Take_Certificates ((At_Byte => Body_At, Length => MLen));
               Info.Cert_End := Body_At + MLen;

            elsif MType = 15 then                    --  CertificateVerify
               Take_Cert_Verify ((At_Byte => Body_At, Length => MLen));
               Info.CV_End := Body_At + MLen;

            elsif MType = 13 then                    --  CertificateRequest
               --  We hold no client certificate, but RFC 8446 4.4.2 still
               --  requires an (empty) Certificate message before Finished.
               Info.Cert_Req_Seen := True;

            elsif MType = 20 then                    --  Finished
               if MLen > 0 then
                  Info.Fin_First := Body_At;
                  Info.Fin_Last := Body_At + MLen - 1;
               end if;
               Info.Saw_Finished := True;
            end if;

            Pos := Body_At + MLen;
         end;
      end loop;
   end Walk;

end TLS_Client.Scan;
