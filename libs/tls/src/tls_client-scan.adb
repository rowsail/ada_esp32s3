with Interfaces; use type Interfaces.Unsigned_8;

package body TLS_Client.Scan with SPARK_Mode => On is

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
               if Ext_Type = 51 and then Ext_Len >= 4 then
                  declare
                     Group  : constant Natural := U16_At (Body_At);
                     Sh_Len : constant Natural := U16_At (Body_At + 2);
                  begin
                     if Group = 16#001D#
                       and then Sh_Len = 32
                       and then Ext_Len >= 36
                     then
                        for I in 0 .. 31 loop
                           Info.X25519 (I) := Buf (Body_At + 4 + I);
                        end loop;
                        Info.Group := 16#001D#;
                        Info.Have_Share := True;

                     elsif Group = 16#0017#
                       and then Sh_Len = 65
                       and then Ext_Len >= 69
                       and then Buf (Body_At + 4) = 16#04#   --  uncompressed
                     then
                        for I in 0 .. 31 loop
                           Info.P256_X (I) := Buf (Body_At + 5 + I);
                           Info.P256_Y (I) := Buf (Body_At + 37 + I);
                        end loop;
                        Info.Group := 16#0017#;
                        Info.Have_Share := True;
                     end if;
                  end;

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

            case MType is
               when 11 =>                            --  Certificate
                  --  The body must hold the context-length byte and the
                  --  three-byte list length before either is read.
                  if MLen >= 4 then
                     declare
                        Ctx_Len  : constant Natural := Natural (Buf (Body_At));
                        Msg_End  : constant Natural := Body_At + MLen;
                        Cert_Pos : Natural;
                        List_End : Natural;
                     begin
                        if Ctx_Len <= MLen - 4 then
                           Cert_Pos := Body_At + 1 + Ctx_Len;
                           List_End :=
                             Natural'Min (Cert_Pos + 3 + U24_At (Cert_Pos), Msg_End);
                           Cert_Pos := Cert_Pos + 3;

                           --  [cert len(3)][cert DER][ext len(2)][exts], repeated.
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
                              pragma Loop_Variant (Increases => Cert_Pos);

                              declare
                                 Cert_Len : constant Natural := U24_At (Cert_Pos);
                                 Cert_At  : constant Natural := Cert_Pos + 3;
                              begin
                                 exit when Cert_Len = 0
                                   or else Cert_Len > List_End - Cert_At;

                                 if Info.Chain_Count < Max_Chain then
                                    Info.Chain_Count := Info.Chain_Count + 1;
                                    Info.Chain (Info.Chain_Count) :=
                                      (First => Cert_At,
                                       Last  => Cert_At + Cert_Len - 1);
                                 end if;
                                 if not Info.Have_Cert then
                                    Info.Cert_First := Cert_At;      --  the leaf
                                    Info.Cert_Last := Cert_At + Cert_Len - 1;
                                    Info.Have_Cert := True;
                                 end if;

                                 Cert_Pos := Cert_At + Cert_Len;
                                 --  This entry's extensions, if they are there.
                                 exit when Cert_Pos + 2 > List_End;
                                 Cert_Pos := Cert_Pos + 2 + U16_At (Cert_Pos);
                              end;
                           end loop;
                        end if;
                     end;
                  end if;
                  Info.Cert_End := Body_At + MLen;

               when 15 =>                            --  CertificateVerify
                  --  Two bytes of algorithm and two of length, if the body is
                  --  long enough to hold them.
                  if MLen >= 4 then
                     declare
                        Sig_Len : constant Natural := U16_At (Body_At + 2);
                     begin
                        Info.CV_Alg := U16 (U16_At (Body_At));
                        --  The signature must fill the body exactly.
                        if Sig_Len = MLen - 4 and then Sig_Len > 0 then
                           Info.CV_Sig_First := Body_At + 4;
                           Info.CV_Sig_Last := Body_At + 4 + Sig_Len - 1;
                        end if;
                     end;
                  end if;
                  Info.CV_End := Body_At + MLen;

               when 13 =>                            --  CertificateRequest
                  --  We hold no client certificate, but RFC 8446 4.4.2 still
                  --  requires an (empty) Certificate message before Finished.
                  Info.Cert_Req_Seen := True;

               when 20 =>                            --  Finished
                  if MLen > 0 then
                     Info.Fin_First := Body_At;
                     Info.Fin_Last := Body_At + MLen - 1;
                  end if;
                  Info.Saw_Finished := True;

               when others =>
                  null;
            end case;

            Pos := Body_At + MLen;
         end;
      end loop;
   end Walk;

end TLS_Client.Scan;
