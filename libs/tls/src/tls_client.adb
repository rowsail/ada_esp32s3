with Ada.Streams;            use Ada.Streams;
with Interfaces;             use Interfaces;
with ESP32S3.RNG;
with ESP32S3.AES;
with ESP32S3.AES.GCM;
with X509;
with Cert_Verify;
with SPARKNaCl;               use SPARKNaCl;
with SPARKNaCl.Scalar;
with SPARKNaCl.Hashing.SHA256;
with SPARKNaCl.HKDF;
with P256;

package body TLS_Client is

   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_64;
   use type Interfaces.Integer_32;        --  arithmetic on SPARKNaCl N32 / I32
   use type X509.Key_Algorithm;
   use GNAT.Sockets;

   package SHA renames SPARKNaCl.Hashing.SHA256;

   --  Handshake transcript (ClientHello || Server|| ...), static (one at a time).
   TR     : Byte_Array (0 .. 4095);
   TR_Len : Natural := 0;

   procedure Transcript (Data : Byte_Array) is
   begin
      for E of Data loop
         if TR_Len <= TR'Last then
            TR (TR_Len) := E;
            TR_Len := TR_Len + 1;
         end if;
      end loop;
   end Transcript;

   --  Record content types and handshake message types.
   CT_Change_Cipher_Spec : constant U8 := 20;
   CT_Alert              : constant U8 := 21;
   CT_Handshake          : constant U8 := 22;
   HS_Client_Hello       : constant U8 := 1;
   HS_Server_Hello       : constant U8 := 2;

   ---------------------------------------------------------------------------
   --  X25519 key pair (SPARKNaCl, seeded from the hardware RNG).
   ---------------------------------------------------------------------------

   function To_B32 (B : Key32) return SPARKNaCl.Bytes_32 is
      R : SPARKNaCl.Bytes_32;
   begin
      for I in 0 .. 31 loop
         R (SPARKNaCl.Index_32 (I)) := SPARKNaCl.Byte (B (I));
      end loop;
      return R;
   end To_B32;

   function From_B32 (B : SPARKNaCl.Bytes_32) return Key32 is
      R : Key32;
   begin
      for I in 0 .. 31 loop
         R (I) := U8 (B (SPARKNaCl.Index_32 (I)));
      end loop;
      return R;
   end From_B32;

   procedure Make_Key_Pair (S : in out Session) is
      Rnd  : ESP32S3.RNG.Byte_Array (0 .. 31);
      Priv : P256.Bytes_32;
      PubX, PubY : P256.Bytes_32;
      Ok   : Boolean := False;
   begin
      --  X25519 ephemeral.
      ESP32S3.RNG.Fill (Rnd);
      for I in 0 .. 31 loop
         S.Priv (I) := U8 (Rnd (I));
      end loop;
      S.Pub := From_B32 (SPARKNaCl.Scalar.Mult_Base (To_B32 (S.Priv)));

      --  P-256 ephemeral (retry on the negligible chance the scalar is out of range).
      for Attempt in 1 .. 8 loop
         ESP32S3.RNG.Fill (Rnd);
         for I in 0 .. 31 loop Priv (I) := P256.Byte (Rnd (I)); end loop;
         Ok := P256.Public_Key (Priv, PubX, PubY);
         exit when Ok;
      end loop;
      if Ok then
         for I in 0 .. 31 loop
            S.P256_Priv  (I) := U8 (Priv (I));
            S.P256_Pub_X (I) := U8 (PubX (I));
            S.P256_Pub_Y (I) := U8 (PubY (I));
         end loop;
      end if;
   end Make_Key_Pair;

   ---------------------------------------------------------------------------
   --  Byte buffer builder (for the outgoing ClientHello).
   ---------------------------------------------------------------------------

   type Builder is record
      Data : Byte_Array (0 .. 2047);
      Len  : Natural := 0;
   end record;

   --  One handshake at a time, so keep the big buffers in static scratch rather
   --  than on the (limited) task stack -- alongside SPARKNaCl's X25519 they would
   --  otherwise overflow it.
   CH : Builder;                       --  ClientHello build buffer
   RB : Byte_Array (0 .. 4095);        --  inbound record fragment

   procedure P8  (B : in out Builder; V : U8) is
   begin
      B.Data (B.Len) := V;  B.Len := B.Len + 1;
   end P8;

   procedure P16 (B : in out Builder; V : U16) is
   begin
      P8 (B, U8 (V / 256));  P8 (B, U8 (V mod 256));
   end P16;

   procedure PBytes (B : in out Builder; X : Byte_Array) is
   begin
      for E of X loop
         P8 (B, E);
      end loop;
   end PBytes;

   procedure PString (B : in out Builder; S : String) is
   begin
      for C of S loop
         P8 (B, U8 (Character'Pos (C)));
      end loop;
   end PString;

   --  Back-patch a 2-byte length at Mark to (current end - Mark - 2).
   procedure Patch16 (B : in out Builder; Mark : Natural) is
      L : constant Natural := B.Len - Mark - 2;
   begin
      B.Data (Mark)     := U8 (L / 256);
      B.Data (Mark + 1) := U8 (L mod 256);
   end Patch16;

   ---------------------------------------------------------------------------
   --  Record I/O over the socket.
   ---------------------------------------------------------------------------

   procedure Send_Bytes (Sock : Socket_Type; Data : Byte_Array) is
      SEA  : Stream_Element_Array (1 .. Stream_Element_Offset (Data'Length));
      Last : Stream_Element_Offset;
   begin
      for I in Data'Range loop
         SEA (Stream_Element_Offset (I - Data'First) + 1) := Stream_Element (Data (I));
      end loop;
      Send_Socket (Sock, SEA, Last);
   end Send_Bytes;

   --  Read exactly Buf'Length bytes (TLS records may straddle TCP segments).
   procedure Recv_Exact (Sock : Socket_Type; Buf : out Byte_Array; Ok : out Boolean) is
      SEA  : Stream_Element_Array (1 .. Stream_Element_Offset (Buf'Length));
      Pos  : Stream_Element_Offset := 1;
      Last : Stream_Element_Offset;
   begin
      Ok := False;
      if Buf'Length = 0 then
         Ok := True;
         return;
      end if;
      while Pos <= SEA'Last loop
         Receive_Socket (Sock, SEA (Pos .. SEA'Last), Last);
         exit when Last < Pos;                 --  peer closed
         Pos := Last + 1;
      end loop;
      if Pos > SEA'Last then
         for I in Buf'Range loop
            Buf (I) := U8 (SEA (Stream_Element_Offset (I - Buf'First) + 1));
         end loop;
         Ok := True;
      end if;
   end Recv_Exact;

   --  Read one TLS record: its content type and fragment.
   procedure Recv_Record (Sock : Socket_Type; CType : out U8;
                          Frag : out Byte_Array; Len : out Natural; Ok : out Boolean) is
      Hdr : Byte_Array (0 .. 4);
   begin
      CType := 0;  Len := 0;
      Recv_Exact (Sock, Hdr, Ok);
      if not Ok then
         return;
      end if;
      CType := Hdr (0);
      Len   := Natural (Hdr (3)) * 256 + Natural (Hdr (4));
      if Len > Frag'Length then
         Ok := False;
         return;
      end if;
      if Len > 0 then
         Recv_Exact (Sock, Frag (Frag'First .. Frag'First + Len - 1), Ok);
      end if;
   end Recv_Record;

   ---------------------------------------------------------------------------
   --  ClientHello
   ---------------------------------------------------------------------------

   procedure Send_Client_Hello (S : in out Session; Sock : Socket_Type; Host : String) is
      B    : Builder renames CH;
      Rnd  : ESP32S3.RNG.Byte_Array (0 .. 31);
      Rec, HS, Body_Mark, Ext_Mark, M : Natural;
   begin
      B.Len := 0;
      --  Record header: handshake, legacy version 0x0303, length (patched last).
      P8 (B, CT_Handshake);  P16 (B, 16#0303#);  Rec := B.Len;  P16 (B, 0);

      --  Handshake header: client_hello, 3-byte length (patched last).
      P8 (B, HS_Client_Hello);  HS := B.Len;  P8 (B, 0); P16 (B, 0);
      Body_Mark := B.Len;

      P16 (B, 16#0303#);                                   --  legacy_version
      ESP32S3.RNG.Fill (Rnd);                              --  random (32), kept for keylog
      for I in 0 .. 31 loop
         S.Client_Random (I) := U8 (Rnd (I));
         P8 (B, U8 (Rnd (I)));
      end loop;
      ESP32S3.RNG.Fill (Rnd);                              --  legacy_session_id (32)
      P8 (B, 32);
      for I in 0 .. 31 loop P8 (B, U8 (Rnd (I))); end loop;

      P16 (B, 2);                                          --  cipher_suites (one)
      P16 (B, TLS_AES_128_GCM_SHA256);

      P8 (B, 1);  P8 (B, 0);                               --  compression: null

      Ext_Mark := B.Len;  P16 (B, 0);                      --  extensions length

      --  server_name (SNI)
      P16 (B, 0);  M := B.Len;  P16 (B, 0);
      P16 (B, Host'Length + 3);                            --  ServerNameList
      P8  (B, 0);                                          --  host_name
      P16 (B, Host'Length);  PString (B, Host);
      Patch16 (B, M);

      --  supported_groups: x25519, secp256r1
      P16 (B, 10);  P16 (B, 6);  P16 (B, 4);
      P16 (B, 16#001D#);  P16 (B, 16#0017#);

      --  signature_algorithms
      P16 (B, 13);  P16 (B, 8);  P16 (B, 6);
      P16 (B, 16#0401#);  P16 (B, 16#0804#);  P16 (B, 16#0403#);

      --  supported_versions: TLS 1.3
      P16 (B, 43);  P16 (B, 3);  P8 (B, 2);  P16 (B, 16#0304#);

      --  psk_key_exchange_modes: psk_dhe_ke (real clients always send this; some
      --  servers drop a ClientHello without it even when no PSK is offered).
      P16 (B, 45);  P16 (B, 2);  P8 (B, 1);  P8 (B, 1);

      --  key_share: an x25519 entry (36) and a secp256r1 entry (69) -- offer both so
      --  the server can choose either without a HelloRetryRequest.
      P16 (B, 51);  P16 (B, 107);  P16 (B, 105);           --  ext, ext len, list len
      P16 (B, 16#001D#);  P16 (B, 32);                     --  x25519 group + key length
      PBytes (B, S.Pub);
      P16 (B, 16#0017#);  P16 (B, 65);                     --  secp256r1 group + point length
      P8  (B, 16#04#);                                     --  uncompressed point
      PBytes (B, S.P256_Pub_X);
      PBytes (B, S.P256_Pub_Y);

      Patch16 (B, Ext_Mark);                               --  extensions length

      --  back-patch the handshake (3-byte) and record (2-byte) lengths
      declare
         HL : constant Natural := B.Len - Body_Mark;
      begin
         B.Data (HS)     := U8 (HL / 65536);
         B.Data (HS + 1) := U8 ((HL / 256) mod 256);
         B.Data (HS + 2) := U8 (HL mod 256);
      end;
      Patch16 (B, Rec);

      Send_Bytes (Sock, B.Data (0 .. B.Len - 1));
      Transcript (B.Data (5 .. B.Len - 1));         --  handshake message (no record hdr)
   end Send_Client_Hello;

   ---------------------------------------------------------------------------
   --  ServerHello parse: cipher suite + key_share
   ---------------------------------------------------------------------------

   procedure Parse_Server_Hello (S : in out Session; Frag : Byte_Array; Len : Natural;
                                 Ok : out Boolean) is
      P    : Natural := Frag'First;
      Last : constant Natural := Frag'First + Len - 1;

      function U16_At (I : Natural) return U16 is
        (U16 (Frag (I)) * 256 + U16 (Frag (I + 1)));
   begin
      Ok := False;
      if Len < 40 or else Frag (P) /= HS_Server_Hello then
         return;
      end if;
      P := P + 4;                                  --  hs type + 3-byte length
      P := P + 2;                                  --  legacy_version
      P := P + 32;                                 --  random
      if P > Last then return; end if;
      P := P + 1 + Natural (Frag (P));             --  legacy_session_id_echo
      if P + 2 > Last then return; end if;
      S.Suite := U16_At (P);  P := P + 2;          --  cipher_suite
      P := P + 1;                                  --  legacy_compression_method
      if P + 1 > Last then return; end if;
      P := P + 2;                                  --  extensions length

      --  Walk extensions for key_share (51).
      while P + 4 <= Last + 1 loop
         declare
            Ext_Type : constant U16     := U16_At (P);
            Ext_Len  : constant Natural := Natural (U16_At (P + 2));
            EBody    : constant Natural := P + 4;
         begin
            if Ext_Type = 51 and then Ext_Len >= 4 then
               --  KeyShareEntry: group (2) + length (2) + key_exchange.
               if U16_At (EBody) = 16#001D#
                 and then Natural (U16_At (EBody + 2)) = 32
               then
                  for I in 0 .. 31 loop
                     S.Server_Pub (I) := Frag (EBody + 4 + I);
                  end loop;
                  S.Group := 16#001D#;  S.Have_Share := True;
               elsif U16_At (EBody) = 16#0017#
                 and then Natural (U16_At (EBody + 2)) = 65
                 and then Frag (EBody + 4) = 16#04#         --  uncompressed point
               then
                  for I in 0 .. 31 loop
                     S.Server_P256_X (I) := Frag (EBody + 5 + I);
                     S.Server_P256_Y (I) := Frag (EBody + 37 + I);
                  end loop;
                  S.Group := 16#0017#;  S.Have_Share := True;
               end if;
            end if;
            P := EBody + Ext_Len;
         end;
      end loop;
      Ok := S.Suite /= 0;
   end Parse_Server_Hello;

   ---------------------------------------------------------------------------
   --  TLS 1.3 key schedule (SHA-256 suite): HKDF over the X25519 shared secret.
   ---------------------------------------------------------------------------

   SHA_Empty : constant SHA.Digest :=                 --  SHA-256 of the empty string
     (16#e3#, 16#b0#, 16#c4#, 16#42#, 16#98#, 16#fc#, 16#1c#, 16#14#,
      16#9a#, 16#fb#, 16#f4#, 16#c8#, 16#99#, 16#6f#, 16#b9#, 16#24#,
      16#27#, 16#ae#, 16#41#, 16#e4#, 16#64#, 16#9b#, 16#93#, 16#4c#,
      16#a4#, 16#95#, 16#99#, 16#1b#, 16#78#, 16#52#, 16#b8#, 16#55#);

   --  HKDF-Expand-Label(Secret, Label, Context, Length) per RFC 8446 7.1.
   function Expand_Label (Secret : SHA.Digest; Label : String;
                          Ctx : Byte_Seq; Len : Natural) return Byte_Seq
   is
      FL   : constant String  := "tls13 " & Label;
      ILn  : constant Natural := 2 + 1 + FL'Length + 1 + Ctx'Length;
      Info : Byte_Seq (0 .. N32 (ILn) - 1);
      OKM  : HKDF.OKM_Seq (0 .. N32 (Len) - 1);
      R    : Byte_Seq (0 .. N32 (Len) - 1);
      P    : N32;
   begin
      Info (0) := Byte (Len / 256);
      Info (1) := Byte (Len mod 256);
      Info (2) := Byte (FL'Length);                   --  HkdfLabel.label length
      for I in FL'Range loop
         Info (3 + N32 (I - FL'First)) := Byte (Character'Pos (FL (I)));
      end loop;
      P := 3 + N32 (FL'Length);
      Info (P) := Byte (Ctx'Length);                  --  HkdfLabel.context length
      for I in Ctx'Range loop
         Info (P + 1 + (I - Ctx'First)) := Ctx (I);
      end loop;
      HKDF.Expand (OKM, Secret, Info);
      for I in R'Range loop
         R (I) := OKM (I);
      end loop;
      return R;
   end Expand_Label;

   --  Derive-Secret(Secret, Label, Transcript-Hash) -- a 32-byte secret.
   function Derive_Secret (Secret : SHA.Digest; Label : String; Th : SHA.Digest)
                           return SHA.Digest
   is
      B : constant Byte_Seq := Expand_Label (Secret, Label, Th, 32);
      R : SHA.Digest;
   begin
      for I in 0 .. 31 loop
         R (Index_32 (I)) := B (N32 (I));
      end loop;
      return R;
   end Derive_Secret;

   procedure Derive_Keys (S : in out Session) is
      Shared : Bytes_32 := (others => 0);
      Z32    : constant Byte_Seq (0 .. 31) := (others => 0);
      No_Ctx : constant Byte_Seq (1 .. 0)  := (others => 0);   --  empty
      TH_Seq : Byte_Seq (0 .. N32 (TR_Len) - 1);
      Early, Derived, HS_Secret, S_HS, C_HS, TH : SHA.Digest;
   begin
      --  ECDHE shared secret, by the group the server chose.
      if S.Group = 16#0017# then                       --  secp256r1 (P-256 ECDH)
         declare
            Priv, PX, PY, ShB : P256.Bytes_32;
            Ok : Boolean;
         begin
            for I in 0 .. 31 loop
               Priv (I) := P256.Byte (S.P256_Priv (I));
               PX   (I) := P256.Byte (S.Server_P256_X (I));
               PY   (I) := P256.Byte (S.Server_P256_Y (I));
            end loop;
            Ok := P256.ECDH (Priv, PX, PY, ShB);
            if Ok then
               for I in 0 .. 31 loop
                  Shared (Index_32 (I)) := SPARKNaCl.Byte (ShB (I));
               end loop;
            end if;
         end;
      else                                              --  x25519 (default)
         Shared := SPARKNaCl.Scalar.Mult (To_B32 (S.Priv), To_B32 (S.Server_Pub));
      end if;
      for I in 0 .. TR_Len - 1 loop                   --  Transcript-Hash(CH||SH)
         TH_Seq (N32 (I)) := Byte (TR (I));
      end loop;
      TH := SHA.Hash (TH_Seq);

      HKDF.Extract (Early,     IKM => Z32,    Salt => Z32);       --  Early Secret
      Derived := Derive_Secret (Early, "derived", SHA_Empty);
      HKDF.Extract (HS_Secret, IKM => Shared, Salt => Derived);   --  Handshake Secret
      S_HS := Derive_Secret (HS_Secret, "s hs traffic", TH);
      C_HS := Derive_Secret (HS_Secret, "c hs traffic", TH);

      for I in 0 .. 31 loop
         S.S_HS_Secret (I) := U8 (S_HS (Index_32 (I)));
         S.C_HS_Secret (I) := U8 (C_HS (Index_32 (I)));
         S.HS_Secret   (I) := U8 (HS_Secret (Index_32 (I)));   --  for the Master Secret
      end loop;
      declare
         SK : constant Byte_Seq := Expand_Label (S_HS, "key", No_Ctx, 16);
         SV : constant Byte_Seq := Expand_Label (S_HS, "iv",  No_Ctx, 12);
         CK : constant Byte_Seq := Expand_Label (C_HS, "key", No_Ctx, 16);
         CV : constant Byte_Seq := Expand_Label (C_HS, "iv",  No_Ctx, 12);
      begin
         for I in 0 .. 15 loop S.Server_Key (I) := U8 (SK (N32 (I))); end loop;
         for I in 0 .. 11 loop S.Server_IV  (I) := U8 (SV (N32 (I))); end loop;
         for I in 0 .. 15 loop S.Client_Key (I) := U8 (CK (N32 (I))); end loop;
         for I in 0 .. 11 loop S.Client_IV  (I) := U8 (CV (N32 (I))); end loop;
      end;
      S.Have_Keys := True;
   end Derive_Keys;

   --  HMAC-SHA-256 over SPARKNaCl's SHA-256 (the key is <= 64 bytes here).
   function HMAC (Key, Msg : Byte_Array) return SHA.Digest is
      Blk      : constant := 64;
      K0       : array (0 .. Blk - 1) of U8 := (others => 0);
      Inner_In : Byte_Seq (0 .. N32 (Blk + Msg'Length) - 1);
      Outer_In : Byte_Seq (0 .. N32 (Blk + 32) - 1);
      Inner    : SHA.Digest;
   begin
      for I in Key'Range loop K0 (I - Key'First) := Key (I); end loop;
      for I in 0 .. Blk - 1 loop Inner_In (N32 (I)) := Byte (K0 (I) xor 16#36#); end loop;
      for I in 0 .. Msg'Length - 1 loop
         Inner_In (N32 (Blk + I)) := Byte (Msg (Msg'First + I));
      end loop;
      Inner := SHA.Hash (Inner_In);
      for I in 0 .. Blk - 1 loop Outer_In (N32 (I)) := Byte (K0 (I) xor 16#5C#); end loop;
      for I in 0 .. 31 loop Outer_In (N32 (Blk + I)) := Inner (Index_32 (I)); end loop;
      return SHA.Hash (Outer_In);
   end HMAC;

   function To_Digest (B : Key32) return SHA.Digest is
      R : SHA.Digest;
   begin
      for I in 0 .. 31 loop R (Index_32 (I)) := Byte (B (I)); end loop;
      return R;
   end To_Digest;

   ---------------------------------------------------------------------------
   --  Decrypt the server's encrypted handshake flight (AES-128-GCM).
   ---------------------------------------------------------------------------

   GC_C : ESP32S3.AES.GCM.Byte_Array (0 .. 4095);   --  ciphertext / plaintext scratch
   GC_P : ESP32S3.AES.GCM.Byte_Array (0 .. 4095);
   HSB  : Byte_Array (0 .. 8191);                   --  reassembled handshake messages
   HSB_Len : Natural := 0;

   --  Decrypt one TLS 1.3 record fragment Frag(.. Len-1) under the server key, with
   --  record sequence Seq.  On success, the inner handshake bytes are GC_P (0 ..
   --  Out_Len-1) and Inner_Type is the real content type (22 = handshake).
   procedure Decrypt_Record (RKey : Byte_Array; RIV : Byte_Array;
                             Frag : Byte_Array; Len : Natural;
                             Seq : Unsigned_64; Out_Len : out Natural;
                             Inner_Type : out U8; Ok : out Boolean)
   is
      use ESP32S3.AES.GCM;
      CLen : constant Natural := (if Len >= 16 then Len - 16 else 0);
      Key  : ESP32S3.AES.Key_Bytes (0 .. 15);
      IV   : Nonce;
      AAD  : ESP32S3.AES.GCM.Byte_Array (0 .. 4);
      Tag  : Auth_Tag;
      DOk  : Boolean;
      P    : Integer;
   begin
      Out_Len := 0;  Inner_Type := 0;  Ok := False;
      if Len < 17 or else CLen > GC_C'Length then
         return;
      end if;
      for I in 0 .. 15 loop Key (I) := RKey (RKey'First + I); end loop;
      for I in 0 .. 11 loop IV (I) := RIV (RIV'First + I); end loop;  --  iv XOR seq
      for I in 0 .. 7 loop
         IV (11 - I) := IV (11 - I) xor U8 (Shift_Right (Seq, 8 * I) and 16#FF#);
      end loop;
      AAD := (16#17#, 16#03#, 16#03#, U8 (Len / 256), U8 (Len mod 256));
      for I in 0 .. CLen - 1 loop GC_C (I) := Frag (Frag'First + I); end loop;
      for I in 0 .. 15 loop Tag (I) := Frag (Frag'First + CLen + I); end loop;

      Decrypt (Key, IV, AAD, GC_C (0 .. CLen - 1), Tag, GC_P (0 .. CLen - 1), DOk);
      if not DOk then
         return;
      end if;
      --  Strip trailing zero padding; the last non-zero byte is the content type.
      P := CLen - 1;
      while P >= 0 and then GC_P (P) = 0 loop P := P - 1; end loop;
      if P < 0 then
         return;
      end if;
      Inner_Type := GC_P (P);
      Out_Len    := P;                 --  handshake bytes = GC_P (0 .. P-1)
      Ok := True;
   end Decrypt_Record;

   --  Walk the reassembled handshake messages: note the Certificate (extract the
   --  leaf) and whether a Finished was seen.
   procedure Scan_Messages (S : in out Session; Saw_Finished : out Boolean) is
      P : Natural := 0;
   begin
      Saw_Finished := False;
      while P + 4 <= HSB_Len loop
         declare
            MType : constant U8 := HSB (P);
            MLen  : constant Natural :=
              Natural (HSB (P + 1)) * 65536 + Natural (HSB (P + 2)) * 256
              + Natural (HSB (P + 3));
         begin
            exit when P + 4 + MLen > HSB_Len;        --  message not fully present yet
            if MType = 11 then                       --  Certificate
               declare
                  CP       : Natural := P + 4;
                  List_End : Natural := P + 4;
               begin
                  CP := CP + 1 + Natural (HSB (CP));  --  certificate_request_context
                  declare
                     ListLen : constant Natural :=
                       Natural (HSB (CP)) * 65536 + Natural (HSB (CP + 1)) * 256
                       + Natural (HSB (CP + 2));
                  begin
                     CP       := CP + 3;              --  start of certificate_list
                     List_End := Natural'Min (CP + ListLen, HSB_Len);
                  end;
                  --  Walk every entry: [cert len(3)][cert DER][ext len(2)][exts].
                  S.Chain_Count := 0;
                  while CP + 3 <= List_End loop
                     declare
                        CLn : constant Natural :=
                          Natural (HSB (CP)) * 65536 + Natural (HSB (CP + 1)) * 256
                          + Natural (HSB (CP + 2));
                     begin
                        CP := CP + 3;
                        exit when CLn = 0 or else CP + CLn > List_End;
                        if S.Chain_Count < Max_Chain then
                           S.Chain_Count := S.Chain_Count + 1;
                           S.Chain (S.Chain_Count) := (First => CP, Last => CP + CLn - 1);
                        end if;
                        if S.Chain_Count = 1 then     --  leaf: kept for CertificateVerify
                           S.Cert_First := CP;
                           S.Cert_Last  := CP + CLn - 1;
                           S.Have_Cert  := True;
                        end if;
                        CP := CP + CLn;
                        exit when CP + 2 > List_End;   --  skip this entry's extensions
                        CP := CP + 2
                              + Natural (HSB (CP)) * 256 + Natural (HSB (CP + 1));
                     end;
                  end loop;
                  S.Cert_End := P + 4 + MLen;         --  transcript point for CertVerify
               end;
            elsif MType = 15 then                     --  CertificateVerify
               S.CV_Alg := U16 (HSB (P + 4)) * 256 + U16 (HSB (P + 5));
               declare
                  SLn : constant Natural :=
                    Natural (HSB (P + 6)) * 256 + Natural (HSB (P + 7));
               begin
                  S.CV_Sig_First := P + 8;
                  S.CV_Sig_Last  := P + 8 + SLn - 1;
               end;
               S.CV_End := P + 4 + MLen;              --  transcript point for Finished
            elsif MType = 20 then                     --  Finished
               S.Fin_First := P + 4;
               S.Fin_Last  := P + 4 + MLen - 1;
               Saw_Finished := True;
            end if;
            P := P + 4 + MLen;
         end;
      end loop;
   end Scan_Messages;

   procedure Read_Server_Flight (S : in out Session; Sock : Socket_Type;
                                 Ok : out Boolean) is
      Frag    : Byte_Array renames RB;
      CType   : U8;
      Len     : Natural;
      RK      : Boolean;
      Seq     : Unsigned_64 := 0;
      ITyp    : U8;
      OLen    : Natural;
      DOk     : Boolean;
      Records : Natural := 0;
      Fin     : Boolean := False;
   begin
      Ok := False;
      HSB_Len := 0;
      for Attempt in 1 .. 16 loop
         Recv_Record (Sock, CType, Frag, Len, RK);
         exit when not RK;
         if CType = CT_Change_Cipher_Spec then
            null;                                     --  middlebox-compat, ignore
         elsif CType = 23 then                        --  encrypted handshake
            Decrypt_Record (S.Server_Key, S.Server_IV, Frag, Len, Seq, OLen, ITyp, DOk);
            if not DOk then
               return;                                --  bad tag => wrong keys
            end if;
            Seq := Seq + 1;
            Records := Records + 1;
            if ITyp = 22 then                         --  handshake content
               for I in 0 .. OLen - 1 loop
                  if HSB_Len <= HSB'Last then
                     HSB (HSB_Len) := GC_P (I);  HSB_Len := HSB_Len + 1;
                  end if;
               end loop;
               Scan_Messages (S, Fin);
               exit when Fin;
            end if;
         else
            exit;                                     --  alert or unexpected
         end if;
      end loop;
      Ok := Fin and then Records > 0;
   end Read_Server_Flight;

   --  Verify the server Finished: verify_data = HMAC(finished_key,
   --  Transcript-Hash(ClientHello .. CertificateVerify)), with finished_key =
   --  Expand-Label(server_hs_traffic_secret, "finished", "", 32).
   procedure Verify_Finished (S : in out Session) is
      No_Ctx : constant Byte_Seq (1 .. 0) := (others => 0);
      FK     : constant Byte_Seq :=
        Expand_Label (To_Digest (S.S_HS_Secret), "finished", No_Ctx, 32);
      FK_BA  : Byte_Array (0 .. 31);
      TLen   : constant Natural := TR_Len + S.CV_End;     --  CH..CertificateVerify
      M      : Byte_Seq (0 .. N32 (TLen) - 1);
      TH     : SHA.Digest;
      TH_BA  : Byte_Array (0 .. 31);
      Exp    : SHA.Digest;
      Match  : Boolean := True;
   begin
      S.Fin_OK := False;
      if S.CV_End = 0 or else S.Fin_Last - S.Fin_First /= 31 then
         return;
      end if;
      for I in 0 .. 31 loop FK_BA (I) := U8 (FK (N32 (I))); end loop;
      for I in 0 .. TR_Len - 1 loop M (N32 (I)) := Byte (TR (I)); end loop;
      for I in 0 .. S.CV_End - 1 loop M (N32 (TR_Len + I)) := Byte (HSB (I)); end loop;
      TH := SHA.Hash (M);
      for I in 0 .. 31 loop TH_BA (I) := U8 (TH (Index_32 (I))); end loop;
      Exp := HMAC (FK_BA, TH_BA);
      for I in 0 .. 31 loop
         if U8 (Exp (Index_32 (I))) /= HSB (S.Fin_First + I) then
            Match := False;
         end if;
      end loop;
      S.Fin_OK := Match;
   end Verify_Finished;

   --  Verify the server CertificateVerify (RSA-PSS): the server signs
   --    (0x20)*64 || "TLS 1.3, server CertificateVerify" || 0x00
   --       || Transcript-Hash(ClientHello .. Certificate)
   --  with its certificate key.
   procedure Verify_Cert_Verify (S : in out Session) is
      Ctx   : constant String := "TLS 1.3, server CertificateVerify";
      CLn   : constant Natural := S.Cert_Last - S.Cert_First + 1;
      SLn   : constant Natural := S.CV_Sig_Last - S.CV_Sig_First + 1;
      TLen  : constant Natural := TR_Len + S.Cert_End;     --  CH .. Certificate
      CertBuf : X509.Byte_Array (0 .. CLn - 1);
      Sig     : X509.Byte_Array (0 .. SLn - 1);
      Signed  : X509.Byte_Array (0 .. 64 + Ctx'Length + 1 + 32 - 1);
      C       : X509.Certificate;
      M       : Byte_Seq (0 .. N32 (TLen) - 1);
      D       : SHA.Digest;
   begin
      S.CV_OK := False;
      if CLn <= 0 or else SLn <= 0 or else S.Cert_End = 0
        or else (S.CV_Alg /= 16#0804#               --  rsa_pss_rsae_sha256
                 and then S.CV_Alg /= 16#0403#)      --  ecdsa_secp256r1_sha256
      then
         return;
      end if;
      for I in 0 .. CLn - 1 loop CertBuf (I) := HSB (S.Cert_First + I); end loop;
      X509.Parse (CertBuf, C);
      if not C.Valid then
         return;
      end if;
      for I in 0 .. SLn - 1 loop Sig (I) := HSB (S.CV_Sig_First + I); end loop;

      --  Transcript-Hash(ClientHello .. Certificate).
      for I in 0 .. TR_Len - 1 loop M (N32 (I)) := Byte (TR (I)); end loop;
      for I in 0 .. S.Cert_End - 1 loop M (N32 (TR_Len + I)) := Byte (HSB (I)); end loop;
      D := SHA.Hash (M);

      for I in 0 .. 63 loop Signed (I) := 16#20#; end loop;
      for I in Ctx'Range loop
         Signed (64 + (I - Ctx'First)) := U8 (Character'Pos (Ctx (I)));
      end loop;
      Signed (64 + Ctx'Length) := 0;
      for I in 0 .. 31 loop
         Signed (64 + Ctx'Length + 1 + I) := U8 (D (Index_32 (I)));
      end loop;

      if S.CV_Alg = 16#0804# then
         S.CV_OK := C.Key_Kind = X509.Key_RSA and then Cert_Verify.RSA_PSS_SHA256
           (Message   => Signed,
            Signature => Sig,
            Modulus   => CertBuf (C.RSA_Modulus.First .. C.RSA_Modulus.Last),
            Exponent  => CertBuf (C.RSA_Exponent.First .. C.RSA_Exponent.Last));
      else                                           --  ecdsa_secp256r1_sha256
         S.CV_OK := C.Key_Kind = X509.Key_EC_P256 and then Cert_Verify.ECDSA_P256_SHA256
           (Message => Signed,
            Sig_DER => Sig,
            Pub_X   => CertBuf (C.EC_X.First .. C.EC_X.Last),
            Pub_Y   => CertBuf (C.EC_Y.First .. C.EC_Y.Last));
      end if;
   end Verify_Cert_Verify;

   ---------------------------------------------------------------------------
   --  Encrypt + send a record; complete the handshake (client Finished + app keys)
   ---------------------------------------------------------------------------

   GE_P : ESP32S3.AES.GCM.Byte_Array (0 .. 4095);
   GE_C : ESP32S3.AES.GCM.Byte_Array (0 .. 4095);
   ER   : Byte_Array (0 .. 4127);

   --  Encrypt Inner (plus its content-type byte) under (RKey, RIV) at Seq and send
   --  it as one TLS 1.3 application_data record.
   procedure Send_Encrypted (Sock : Socket_Type; RKey, RIV : Byte_Array;
                             Seq : Unsigned_64; Inner : Byte_Array; Inner_Type : U8)
   is
      use ESP32S3.AES.GCM;
      PLen : constant Natural := Inner'Length + 1;
      RLen : constant Natural := PLen + 16;
      Key  : ESP32S3.AES.Key_Bytes (0 .. 15);
      IV   : Nonce;
      AAD  : ESP32S3.AES.GCM.Byte_Array (0 .. 4);
      Tag  : Auth_Tag;
   begin
      if PLen > GE_P'Length then
         return;
      end if;
      for I in 0 .. 15 loop Key (I) := RKey (RKey'First + I); end loop;
      for I in 0 .. 11 loop IV (I) := RIV (RIV'First + I); end loop;
      for I in 0 .. 7 loop
         IV (11 - I) := IV (11 - I) xor U8 (Shift_Right (Seq, 8 * I) and 16#FF#);
      end loop;
      AAD := (16#17#, 16#03#, 16#03#, U8 (RLen / 256), U8 (RLen mod 256));
      for I in 0 .. Inner'Length - 1 loop GE_P (I) := Inner (Inner'First + I); end loop;
      GE_P (PLen - 1) := Inner_Type;
      Encrypt (Key, IV, AAD, GE_P (0 .. PLen - 1), GE_C (0 .. PLen - 1), Tag);
      ER (0) := 16#17#; ER (1) := 16#03#; ER (2) := 16#03#;
      ER (3) := U8 (RLen / 256);  ER (4) := U8 (RLen mod 256);
      for I in 0 .. PLen - 1 loop ER (5 + I) := GE_C (I); end loop;
      for I in 0 .. 15 loop ER (5 + PLen + I) := Tag (I); end loop;
      Send_Bytes (Sock, ER (0 .. 5 + RLen - 1));
   end Send_Encrypted;

   --  Send our Finished and derive the application traffic keys -> channel open.
   procedure Complete_Handshake (S : in out Session; Sock : Socket_Type) is
      No_Ctx : constant Byte_Seq (1 .. 0) := (others => 0);
      TLen   : constant Natural := TR_Len + HSB_Len;   --  CH .. server Finished
      M      : Byte_Seq (0 .. N32 (TLen) - 1);
      TH     : SHA.Digest;
      TH_BA  : Byte_Array (0 .. 31);
      CFK    : constant Byte_Seq :=
        Expand_Label (To_Digest (S.C_HS_Secret), "finished", No_Ctx, 32);
      CFK_BA : Byte_Array (0 .. 31);
      VD     : SHA.Digest;
      Fin    : Byte_Array (0 .. 35);                   --  [20][00 00 20][32]
      Z32    : constant Byte_Seq (0 .. 31) := (others => 0);
      Derived2, Master, C_Ap, S_Ap : SHA.Digest;
      CCS    : constant Byte_Array := (16#14#, 16#03#, 16#03#, 16#00#, 16#01#, 16#01#);
   begin
      for I in 0 .. TR_Len - 1 loop M (N32 (I)) := Byte (TR (I)); end loop;
      for I in 0 .. HSB_Len - 1 loop M (N32 (TR_Len + I)) := Byte (HSB (I)); end loop;
      TH := SHA.Hash (M);
      for I in 0 .. 31 loop TH_BA (I) := U8 (TH (Index_32 (I))); end loop;

      --  client Finished
      for I in 0 .. 31 loop CFK_BA (I) := U8 (CFK (N32 (I))); end loop;
      VD := HMAC (CFK_BA, TH_BA);
      Fin (0) := 20;  Fin (1) := 0;  Fin (2) := 0;  Fin (3) := 32;
      for I in 0 .. 31 loop Fin (4 + I) := U8 (VD (Index_32 (I))); end loop;

      --  Master Secret -> application traffic secrets -> application keys.
      Derived2 := Derive_Secret (To_Digest (S.HS_Secret), "derived", SHA_Empty);
      HKDF.Extract (Master, IKM => Z32, Salt => Derived2);
      C_Ap := Derive_Secret (Master, "c ap traffic", TH);
      S_Ap := Derive_Secret (Master, "s ap traffic", TH);
      declare
         CK : constant Byte_Seq := Expand_Label (C_Ap, "key", No_Ctx, 16);
         CV : constant Byte_Seq := Expand_Label (C_Ap, "iv",  No_Ctx, 12);
         SK : constant Byte_Seq := Expand_Label (S_Ap, "key", No_Ctx, 16);
         SV : constant Byte_Seq := Expand_Label (S_Ap, "iv",  No_Ctx, 12);
      begin
         for I in 0 .. 15 loop S.C_App_Key (I) := U8 (CK (N32 (I))); end loop;
         for I in 0 .. 11 loop S.C_App_IV  (I) := U8 (CV (N32 (I))); end loop;
         for I in 0 .. 15 loop S.S_App_Key (I) := U8 (SK (N32 (I))); end loop;
         for I in 0 .. 11 loop S.S_App_IV  (I) := U8 (SV (N32 (I))); end loop;
      end;
      S.C_App_Seq := 0;  S.S_App_Seq := 0;

      Send_Bytes (Sock, CCS);                                    --  middlebox-compat
      Send_Encrypted (Sock, S.Client_Key, S.Client_IV, 0, Fin, 22);  --  our Finished
      S.Open := True;
   end Complete_Handshake;

   ---------------------------------------------------------------------------
   --  Drive the opening exchange.
   ---------------------------------------------------------------------------

   procedure Hello (S : in out Session; Sock : Socket_Type; Host : String;
                    Ok : out Boolean) is
      Frag  : Byte_Array renames RB;
      CType : U8;
      Len   : Natural;
      RK    : Boolean;
   begin
      Ok := False;
      TR_Len := 0;
      Make_Key_Pair (S);
      Send_Client_Hello (S, Sock, Host);

      --  Read records until a handshake record arrives (skip ChangeCipherSpec).
      for Attempt in 1 .. 4 loop
         Recv_Record (Sock, CType, Frag, Len, RK);
         if not RK then
            return;
         end if;
         if CType = CT_Alert then
            return;                               --  server rejected us
         elsif CType = CT_Change_Cipher_Spec then
            null;                                 --  middlebox-compat, ignore
         elsif CType = CT_Handshake then
            Parse_Server_Hello (S, Frag, Len, Ok);
            if Ok then
               Transcript (Frag (Frag'First .. Frag'First + Len - 1));  --  ServerHello
               Derive_Keys (S);
               Read_Server_Flight (S, Sock, S.Flight);  --  decrypt the rest
               if S.Flight then
                  Verify_Cert_Verify (S);
                  Verify_Finished (S);
                  if S.Fin_OK then
                     Complete_Handshake (S, Sock);   --  send our Finished, open channel
                  end if;
               end if;
            end if;
            return;
         end if;
      end loop;
   end Hello;

   function Cipher_Suite (S : Session) return U16 is (S.Suite);
   function Server_Key_Share (S : Session) return Byte_Array is (S.Server_Pub);
   function Client_Random    (S : Session) return Byte_Array is (S.Client_Random);
   function Server_HS_Secret (S : Session) return Byte_Array is (S.S_HS_Secret);
   function Client_HS_Secret (S : Session) return Byte_Array is (S.C_HS_Secret);
   function Keys_Ready       (S : Session) return Boolean    is (S.Have_Keys);
   function Flight_OK        (S : Session) return Boolean    is (S.Flight);
   function Have_Server_Cert (S : Session) return Boolean    is (S.Have_Cert);
   function Server_Cert      (S : Session) return Byte_Array is
     (HSB (S.Cert_First .. S.Cert_Last));

   function Server_Cert_Count (S : Session) return Natural is (S.Chain_Count);

   function Server_Chain_Cert (S : Session; Index : Positive) return X509.Byte_Array is
      B : constant Cert_Bounds := S.Chain (Index);
      R : X509.Byte_Array (0 .. B.Last - B.First);
   begin
      for I in R'Range loop
         R (I) := X509.U8 (HSB (B.First + I));
      end loop;
      return R;
   end Server_Chain_Cert;

   function Server_Finished_OK (S : Session) return Boolean is (S.Fin_OK);
   function Server_Cert_Verify_OK (S : Session) return Boolean is (S.CV_OK);
   function Ready (S : Session) return Boolean is (S.Open);

   procedure Send (S : in out Session; Sock : Socket_Type; Data : Byte_Array) is
   begin
      Send_Encrypted (Sock, S.C_App_Key, S.C_App_IV, S.C_App_Seq, Data, 23);
      S.C_App_Seq := S.C_App_Seq + 1;
   end Send;

   procedure Recv (S : in out Session; Sock : Socket_Type; Buf : out Byte_Array;
                   Last : out Natural; Ok : out Boolean) is
      Frag  : Byte_Array renames RB;
      CType : U8;
      Len   : Natural;
      RK    : Boolean;
      ITyp  : U8;
      OLen  : Natural;
      DOk   : Boolean;
   begin
      Last := (if Buf'First > 0 then Buf'First - 1 else 0);
      Ok   := False;
      loop
         Recv_Record (Sock, CType, Frag, Len, RK);
         if not RK then
            return;
         end if;
         if CType = CT_Change_Cipher_Spec then
            null;                                          --  ignore
         elsif CType = 23 then
            Decrypt_Record (S.S_App_Key, S.S_App_IV, Frag, Len, S.S_App_Seq,
                            OLen, ITyp, DOk);
            if not DOk then
               return;
            end if;
            S.S_App_Seq := S.S_App_Seq + 1;
            if ITyp = 23 then                              --  application_data
               declare
                  N : constant Natural := Natural'Min (OLen, Buf'Length);
               begin
                  for I in 0 .. N - 1 loop Buf (Buf'First + I) := GC_P (I); end loop;
                  Last := Buf'First + N - 1;
                  Ok   := True;
                  return;
               end;
            elsif ITyp = 21 then                           --  alert
               return;
            end if;                                        --  else (e.g. tickets): loop
         else
            return;
         end if;
      end loop;
   end Recv;

end TLS_Client;
