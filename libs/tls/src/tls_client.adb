with Ada.Streams; use Ada.Streams;
with Interfaces;  use Interfaces;
with ESP32S3.RNG;
with ESP32S3.AES;
with ESP32S3.AES.GCM;
with X509;
with Cert_Verify;
with SPARKNaCl;   use SPARKNaCl;
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
      Result : SPARKNaCl.Bytes_32;
   begin
      for I in 0 .. 31 loop
         Result (SPARKNaCl.Index_32 (I)) := SPARKNaCl.Byte (B (I));
      end loop;
      return Result;
   end To_B32;

   function From_B32 (B : SPARKNaCl.Bytes_32) return Key32 is
      Result : Key32;
   begin
      for I in 0 .. 31 loop
         Result (I) := U8 (B (SPARKNaCl.Index_32 (I)));
      end loop;
      return Result;
   end From_B32;

   procedure Make_Key_Pair (S : in out Session) is
      Rnd        : ESP32S3.RNG.Byte_Array (0 .. 31);
      Priv       : P256.Bytes_32;
      PubX, PubY : P256.Bytes_32;
      Ok         : Boolean := False;
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
         for I in 0 .. 31 loop
            Priv (I) := P256.Byte (Rnd (I));
         end loop;
         Ok := P256.Public_Key (Priv, PubX, PubY);
         exit when Ok;
      end loop;
      if Ok then
         for I in 0 .. 31 loop
            S.P256_Priv (I) := U8 (Priv (I));
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

   procedure P8 (B : in out Builder; V : U8) is
   begin
      B.Data (B.Len) := V;
      B.Len := B.Len + 1;
   end P8;

   procedure P16 (B : in out Builder; V : U16) is
   begin
      P8 (B, U8 (V / 256));
      P8 (B, U8 (V mod 256));
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
      B.Data (Mark) := U8 (L / 256);
      B.Data (Mark + 1) := U8 (L mod 256);
   end Patch16;

   ---------------------------------------------------------------------------
   --  Record I/O over the socket.
   ---------------------------------------------------------------------------

   procedure Send_Bytes (Sock : Socket_Type; Data : Byte_Array) is
      Stream_Buf : Stream_Element_Array (1 .. Stream_Element_Offset (Data'Length));
      Last       : Stream_Element_Offset;
   begin
      for I in Data'Range loop
         Stream_Buf (Stream_Element_Offset (I - Data'First) + 1) := Stream_Element (Data (I));
      end loop;
      Send_Socket (Sock, Stream_Buf, Last);
   end Send_Bytes;

   --  Read exactly Buf'Length bytes (TLS records may straddle TCP segments).
   procedure Recv_Exact (Sock : Socket_Type; Buf : out Byte_Array; Ok : out Boolean) is
      Stream_Buf : Stream_Element_Array (1 .. Stream_Element_Offset (Buf'Length));
      Pos        : Stream_Element_Offset := 1;
      Last       : Stream_Element_Offset;
   begin
      Ok := False;
      if Buf'Length = 0 then
         Ok := True;
         return;
      end if;
      while Pos <= Stream_Buf'Last loop
         Receive_Socket (Sock, Stream_Buf (Pos .. Stream_Buf'Last), Last);
         exit when Last < Pos;                 --  peer closed
         Pos := Last + 1;
      end loop;
      if Pos > Stream_Buf'Last then
         for I in Buf'Range loop
            Buf (I) := U8 (Stream_Buf (Stream_Element_Offset (I - Buf'First) + 1));
         end loop;
         Ok := True;
      end if;
   end Recv_Exact;

   --  Read one TLS record: its content type and fragment.
   procedure Recv_Record
     (Sock  : Socket_Type;
      CType : out U8;
      Frag  : out Byte_Array;
      Len   : out Natural;
      Ok    : out Boolean)
   is
      Hdr : Byte_Array (0 .. 4);
   begin
      CType := 0;
      Len := 0;
      Recv_Exact (Sock, Hdr, Ok);
      if not Ok then
         return;
      end if;
      CType := Hdr (0);
      Len := Natural (Hdr (3)) * 256 + Natural (Hdr (4));
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
      B                                                : Builder renames CH;
      Rnd                                              : ESP32S3.RNG.Byte_Array (0 .. 31);
      Rec_Mark, HS_Mark, Body_Mark, Ext_Mark, SNI_Mark : Natural;
   begin
      B.Len := 0;
      --  Record header: handshake, legacy version 0x0303, length (patched last).
      P8 (B, CT_Handshake);
      P16 (B, 16#0303#);
      Rec_Mark := B.Len;
      P16 (B, 0);

      --  Handshake header: client_hello, 3-byte length (patched last).
      P8 (B, HS_Client_Hello);
      HS_Mark := B.Len;
      P8 (B, 0);
      P16 (B, 0);
      Body_Mark := B.Len;

      P16 (B, 16#0303#);                                   --  legacy_version
      ESP32S3.RNG.Fill (Rnd);                              --  random (32), kept for keylog
      for I in 0 .. 31 loop
         S.Client_Random (I) := U8 (Rnd (I));
         P8 (B, U8 (Rnd (I)));
      end loop;
      ESP32S3.RNG.Fill (Rnd);                              --  legacy_session_id (32)
      P8 (B, 32);
      for I in 0 .. 31 loop
         P8 (B, U8 (Rnd (I)));
      end loop;

      P16 (B, 2);                                          --  cipher_suites (one)
      P16 (B, TLS_AES_128_GCM_SHA256);

      P8 (B, 1);
      P8 (B, 0);                               --  compression: null

      Ext_Mark := B.Len;
      P16 (B, 0);                      --  extensions length

      --  server_name (SNI)
      P16 (B, 0);
      SNI_Mark := B.Len;
      P16 (B, 0);
      P16 (B, Host'Length + 3);                            --  ServerNameList
      P8 (B, 0);                                          --  host_name
      P16 (B, Host'Length);
      PString (B, Host);
      Patch16 (B, SNI_Mark);

      --  supported_groups: x25519, secp256r1
      P16 (B, 10);
      P16 (B, 6);
      P16 (B, 4);
      P16 (B, 16#001D#);
      P16 (B, 16#0017#);

      --  signature_algorithms
      P16 (B, 13);
      P16 (B, 8);
      P16 (B, 6);
      P16 (B, 16#0401#);
      P16 (B, 16#0804#);
      P16 (B, 16#0403#);

      --  supported_versions: TLS 1.3
      P16 (B, 43);
      P16 (B, 3);
      P8 (B, 2);
      P16 (B, 16#0304#);

      --  psk_key_exchange_modes: psk_dhe_ke (real clients always send this; some
      --  servers drop a ClientHello without it even when no PSK is offered).
      P16 (B, 45);
      P16 (B, 2);
      P8 (B, 1);
      P8 (B, 1);

      --  key_share: an x25519 entry (36) and a secp256r1 entry (69) -- offer both so
      --  the server can choose either without a HelloRetryRequest.  Both paths are
      --  HW-verified (x25519 and a P-256-only ClientHello each complete a handshake).
      P16 (B, 51);
      P16 (B, 107);
      P16 (B, 105);           --  ext, ext len, list len
      P16 (B, 16#001D#);
      P16 (B, 32);                     --  x25519 group + key length
      PBytes (B, S.Pub);
      P16 (B, 16#0017#);
      P16 (B, 65);                     --  secp256r1 group + point length
      P8 (B, 16#04#);                                     --  uncompressed point
      PBytes (B, S.P256_Pub_X);
      PBytes (B, S.P256_Pub_Y);

      Patch16 (B, Ext_Mark);                               --  extensions length

      --  back-patch the handshake (3-byte) and record (2-byte) lengths
      declare
         HL : constant Natural := B.Len - Body_Mark;
      begin
         B.Data (HS_Mark) := U8 (HL / 65536);
         B.Data (HS_Mark + 1) := U8 ((HL / 256) mod 256);
         B.Data (HS_Mark + 2) := U8 (HL mod 256);
      end;
      Patch16 (B, Rec_Mark);

      Send_Bytes (Sock, B.Data (0 .. B.Len - 1));
      Transcript (B.Data (5 .. B.Len - 1));         --  handshake message (no record hdr)
   end Send_Client_Hello;

   ---------------------------------------------------------------------------
   --  ServerHello parse: cipher suite + key_share
   ---------------------------------------------------------------------------

   procedure Parse_Server_Hello
     (S : in out Session; Frag : Byte_Array; Len : Natural; Ok : out Boolean)
   is
      Pos  : Natural := Frag'First;
      Last : constant Natural := Frag'First + Len - 1;

      function U16_At (I : Natural) return U16
      is (U16 (Frag (I)) * 256 + U16 (Frag (I + 1)));
   begin
      Ok := False;
      if Len < 40 or else Frag (Pos) /= HS_Server_Hello then
         return;
      end if;
      Pos := Pos + 4;                              --  hs type + 3-byte length
      Pos := Pos + 2;                              --  legacy_version
      Pos := Pos + 32;                             --  random
      if Pos > Last then
         return;
      end if;
      Pos := Pos + 1 + Natural (Frag (Pos));       --  legacy_session_id_echo
      if Pos + 2 > Last then
         return;
      end if;
      S.Suite := U16_At (Pos);
      Pos := Pos + 2;          --  cipher_suite
      Pos := Pos + 1;                              --  legacy_compression_method
      if Pos + 1 > Last then
         return;
      end if;
      Pos := Pos + 2;                              --  extensions length

      --  Walk extensions for key_share (51).
      while Pos + 4 <= Last + 1 loop
         declare
            Ext_Type : constant U16 := U16_At (Pos);
            Ext_Len  : constant Natural := Natural (U16_At (Pos + 2));
            Ext_Body : constant Natural := Pos + 4;
         begin
            --  Require the whole extension body to be present in Frag before any
            --  inner read: the outer loop only guarantees the 4-byte header, so a
            --  short fragment with a large Ext_Len would otherwise index past it.
            if Ext_Type = 51 and then Ext_Len >= 4
              and then Ext_Body + Ext_Len <= Last + 1
            then
               --  KeyShareEntry: group (2) + length (2) + key_exchange.
               if U16_At (Ext_Body) = 16#001D# and then Natural (U16_At (Ext_Body + 2)) = 32
                 and then Ext_Body + 36 <= Last + 1        --  4 + 32 key bytes
               then
                  for I in 0 .. 31 loop
                     S.Server_Pub (I) := Frag (Ext_Body + 4 + I);
                  end loop;
                  S.Group := 16#001D#;
                  S.Have_Share := True;
               elsif U16_At (Ext_Body) = 16#0017#
                 and then Natural (U16_At (Ext_Body + 2)) = 65
                 and then Ext_Body + 69 <= Last + 1        --  5 + 64 point bytes
                 and then Frag (Ext_Body + 4) = 16#04#      --  uncompressed point
               then
                  for I in 0 .. 31 loop
                     S.Server_P256_X (I) := Frag (Ext_Body + 5 + I);
                     S.Server_P256_Y (I) := Frag (Ext_Body + 37 + I);
                  end loop;
                  S.Group := 16#0017#;
                  S.Have_Share := True;
               end if;
            elsif Ext_Type = 41 then
               --  pre_shared_key: server accepted
               S.Resumed_PSK := True;           --  selected_identity is our only offer
            end if;
            Pos := Ext_Body + Ext_Len;
         end;
      end loop;
      Ok := S.Suite /= 0;
   end Parse_Server_Hello;

   ---------------------------------------------------------------------------
   --  TLS 1.3 key schedule (SHA-256 suite): HKDF over the X25519 shared secret.
   ---------------------------------------------------------------------------

   SHA_Empty : constant SHA.Digest :=                 --  SHA-256 of the empty string
     (16#e3#,
      16#b0#,
      16#c4#,
      16#42#,
      16#98#,
      16#fc#,
      16#1c#,
      16#14#,
      16#9a#,
      16#fb#,
      16#f4#,
      16#c8#,
      16#99#,
      16#6f#,
      16#b9#,
      16#24#,
      16#27#,
      16#ae#,
      16#41#,
      16#e4#,
      16#64#,
      16#9b#,
      16#93#,
      16#4c#,
      16#a4#,
      16#95#,
      16#99#,
      16#1b#,
      16#78#,
      16#52#,
      16#b8#,
      16#55#);

   --  HKDF-Expand-Label(Secret, Label, Context, Length) per RFC 8446 7.1.
   function Expand_Label
     (Secret : SHA.Digest; Label : String; Ctx : Byte_Seq; Len : Natural) return Byte_Seq
   is
      Full_Label : constant String := "tls13 " & Label;
      Info_Len   : constant Natural := 2 + 1 + Full_Label'Length + 1 + Ctx'Length;
      Info       : Byte_Seq (0 .. N32 (Info_Len) - 1);
      OKM        : HKDF.OKM_Seq (0 .. N32 (Len) - 1);   --  HKDF output keying material
      Result     : Byte_Seq (0 .. N32 (Len) - 1);
      Pos        : N32;
   begin
      Info (0) := Byte (Len / 256);
      Info (1) := Byte (Len mod 256);
      Info (2) := Byte (Full_Label'Length);           --  HkdfLabel.label length
      for I in Full_Label'Range loop
         Info (3 + N32 (I - Full_Label'First)) := Byte (Character'Pos (Full_Label (I)));
      end loop;
      Pos := 3 + N32 (Full_Label'Length);
      Info (Pos) := Byte (Ctx'Length);                --  HkdfLabel.context length
      for I in Ctx'Range loop
         Info (Pos + 1 + (I - Ctx'First)) := Ctx (I);
      end loop;
      HKDF.Expand (OKM, Secret, Info);
      for I in Result'Range loop
         Result (I) := OKM (I);
      end loop;
      return Result;
   end Expand_Label;

   --  Derive-Secret(Secret, Label, Transcript-Hash) -- a 32-byte secret.
   function Derive_Secret (Secret : SHA.Digest; Label : String; Th : SHA.Digest) return SHA.Digest
   is
      Expanded : constant Byte_Seq := Expand_Label (Secret, Label, Th, 32);
      Result   : SHA.Digest;
   begin
      for I in 0 .. 31 loop
         Result (Index_32 (I)) := Expanded (N32 (I));
      end loop;
      return Result;
   end Derive_Secret;

   procedure Derive_Keys (S : in out Session) is
      Shared                                    : Bytes_32 := (others => 0);
      Z32                                       : constant Byte_Seq (0 .. 31) := (others => 0);
      No_Ctx                                    : constant Byte_Seq (1 .. 0) :=
        (others => 0);   --  empty
      TH_Seq                                    : Byte_Seq (0 .. N32 (TR_Len) - 1);
      Early, Derived, HS_Secret, S_HS, C_HS, TH : SHA.Digest;
   begin
      --  ECDHE shared secret, by the group the server chose.
      if S.Group = 16#0017# then
         --  secp256r1 (P-256 ECDH)
         declare
            Priv, PX, PY, ShB : P256.Bytes_32;
            Ok                : Boolean;
         begin
            for I in 0 .. 31 loop
               Priv (I) := P256.Byte (S.P256_Priv (I));
               PX (I) := P256.Byte (S.Server_P256_X (I));
               PY (I) := P256.Byte (S.Server_P256_Y (I));
            end loop;
            Ok := P256.ECDH (Priv, PX, PY, ShB);
            if Ok then
               for I in 0 .. 31 loop
                  Shared (Index_32 (I)) := SPARKNaCl.Byte (ShB (I));
               end loop;
            end if;
         end;
      else
         --  x25519 (default)
         Shared := SPARKNaCl.Scalar.Mult (To_B32 (S.Priv), To_B32 (S.Server_Pub));
      end if;
      for I in 0 .. TR_Len - 1 loop
         --  Transcript-Hash(CH||SH)
         TH_Seq (N32 (I)) := Byte (TR (I));
      end loop;
      TH := SHA.Hash (TH_Seq);

      if S.Resumed_PSK then
         --  Early from the PSK
         declare
            PSKb : Byte_Seq (0 .. 31);
         begin
            for I in 0 .. 31 loop
               PSKb (N32 (I)) := Byte (S.Offered_PSK (I));
            end loop;
            HKDF.Extract (Early, IKM => PSKb, Salt => Z32);
         end;
      else
         HKDF.Extract (Early, IKM => Z32, Salt => Z32);       --  Early Secret (no PSK)
      end if;
      Derived := Derive_Secret (Early, "derived", SHA_Empty);
      HKDF.Extract (HS_Secret, IKM => Shared, Salt => Derived);   --  Handshake Secret
      S_HS := Derive_Secret (HS_Secret, "s hs traffic", TH);
      C_HS := Derive_Secret (HS_Secret, "c hs traffic", TH);

      for I in 0 .. 31 loop
         S.S_HS_Secret (I) := U8 (S_HS (Index_32 (I)));
         S.C_HS_Secret (I) := U8 (C_HS (Index_32 (I)));
         S.HS_Secret (I) := U8 (HS_Secret (Index_32 (I)));   --  for the Master Secret
      end loop;
      declare
         SK : constant Byte_Seq := Expand_Label (S_HS, "key", No_Ctx, 16);
         SV : constant Byte_Seq := Expand_Label (S_HS, "iv", No_Ctx, 12);
         CK : constant Byte_Seq := Expand_Label (C_HS, "key", No_Ctx, 16);
         CV : constant Byte_Seq := Expand_Label (C_HS, "iv", No_Ctx, 12);
      begin
         for I in 0 .. 15 loop
            S.Server_Key (I) := U8 (SK (N32 (I)));
         end loop;
         for I in 0 .. 11 loop
            S.Server_IV (I) := U8 (SV (N32 (I)));
         end loop;
         for I in 0 .. 15 loop
            S.Client_Key (I) := U8 (CK (N32 (I)));
         end loop;
         for I in 0 .. 11 loop
            S.Client_IV (I) := U8 (CV (N32 (I)));
         end loop;
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
      for I in Key'Range loop
         K0 (I - Key'First) := Key (I);
      end loop;
      for I in 0 .. Blk - 1 loop
         Inner_In (N32 (I)) := Byte (K0 (I) xor 16#36#);
      end loop;
      for I in 0 .. Msg'Length - 1 loop
         Inner_In (N32 (Blk + I)) := Byte (Msg (Msg'First + I));
      end loop;
      Inner := SHA.Hash (Inner_In);
      for I in 0 .. Blk - 1 loop
         Outer_In (N32 (I)) := Byte (K0 (I) xor 16#5C#);
      end loop;
      for I in 0 .. 31 loop
         Outer_In (N32 (Blk + I)) := Inner (Index_32 (I));
      end loop;
      return SHA.Hash (Outer_In);
   end HMAC;

   function To_Digest (B : Key32) return SHA.Digest is
      Result : SHA.Digest;
   begin
      for I in 0 .. 31 loop
         Result (Index_32 (I)) := Byte (B (I));
      end loop;
      return Result;
   end To_Digest;

   ---------------------------------------------------------------------------
   --  Decrypt the server's encrypted handshake flight (AES-128-GCM).
   ---------------------------------------------------------------------------

   GC_C    : ESP32S3.AES.GCM.Byte_Array (0 .. 4095);   --  ciphertext / plaintext scratch
   GC_P    : ESP32S3.AES.GCM.Byte_Array (0 .. 4095);
   HSB     : Byte_Array (0 .. 8191);                   --  reassembled handshake messages
   HSB_Len : Natural := 0;

   --  Decrypt one TLS 1.3 record fragment Frag(.. Len-1) under the server key, with
   --  record sequence Seq.  On success, the inner handshake bytes are GC_P (0 ..
   --  Out_Len-1) and Inner_Type is the real content type (22 = handshake).
   procedure Decrypt_Record
     (RKey       : Byte_Array;
      RIV        : Byte_Array;
      Frag       : Byte_Array;
      Len        : Natural;
      Seq        : Unsigned_64;
      Out_Len    : out Natural;
      Inner_Type : out U8;
      Ok         : out Boolean)
   is
      use ESP32S3.AES.GCM;
      CLen   : constant Natural := (if Len >= 16 then Len - 16 else 0);
      Key    : ESP32S3.AES.Key_Bytes (0 .. 15);
      IV     : Nonce;
      AAD    : ESP32S3.AES.GCM.Byte_Array (0 .. 4);
      Tag    : Auth_Tag;
      Dec_OK : Boolean;
      Pos    : Integer;
   begin
      Out_Len := 0;
      Inner_Type := 0;
      Ok := False;
      if Len < 17 or else CLen > GC_C'Length then
         return;
      end if;
      for I in 0 .. 15 loop
         Key (I) := RKey (RKey'First + I);
      end loop;
      for I in 0 .. 11 loop
         IV (I) := RIV (RIV'First + I);
      end loop;  --  iv XOR seq
      for I in 0 .. 7 loop
         IV (11 - I) := IV (11 - I) xor U8 (Shift_Right (Seq, 8 * I) and 16#FF#);
      end loop;
      AAD := (16#17#, 16#03#, 16#03#, U8 (Len / 256), U8 (Len mod 256));
      for I in 0 .. CLen - 1 loop
         GC_C (I) := Frag (Frag'First + I);
      end loop;
      for I in 0 .. 15 loop
         Tag (I) := Frag (Frag'First + CLen + I);
      end loop;

      Decrypt (Key, IV, AAD, GC_C (0 .. CLen - 1), Tag, GC_P (0 .. CLen - 1), Dec_OK);
      if not Dec_OK then
         return;
      end if;
      --  Strip trailing zero padding; the last non-zero byte is the content type.
      Pos := CLen - 1;
      while Pos >= 0 and then GC_P (Pos) = 0 loop
         Pos := Pos - 1;
      end loop;
      if Pos < 0 then
         return;
      end if;
      Inner_Type := GC_P (Pos);
      Out_Len := Pos;               --  handshake bytes = GC_P (0 .. Pos-1)
      Ok := True;
   end Decrypt_Record;

   --  Walk the reassembled handshake messages: note the Certificate (extract the
   --  leaf) and whether a Finished was seen.
   procedure Scan_Messages (S : in out Session; Saw_Finished : out Boolean) is
      Pos : Natural := 0;
   begin
      Saw_Finished := False;
      while Pos + 4 <= HSB_Len loop
         declare
            MType : constant U8 := HSB (Pos);
            MLen  : constant Natural :=
              Natural (HSB (Pos + 1))
              * 65536
              + Natural (HSB (Pos + 2)) * 256
              + Natural (HSB (Pos + 3));
         begin
            exit when Pos + 4 + MLen > HSB_Len;      --  message not fully present yet
            if MType = 11 then
               --  Certificate
               declare
                  Msg_End  : constant Natural := Pos + 4 + MLen;   --  end of this message
                  Cert_Pos : Natural := Pos + 4;
                  List_End : Natural := Pos + 4;
               begin
                  Cert_Pos := Cert_Pos + 1 + Natural (HSB (Cert_Pos));  --  cert_request_context
                  --  A bogus context length could push Cert_Pos past the message
                  --  (and near HSB's end, past the 8 KB buffer); bound the 3-byte
                  --  ListLen read before indexing.
                  if Cert_Pos + 3 > Msg_End or else Cert_Pos + 2 > HSB_Len then
                     S.Chain_Count := 0;
                     List_End := Cert_Pos;                 --  empty walk below
                  else
                     declare
                        ListLen : constant Natural :=
                          Natural (HSB (Cert_Pos))
                          * 65536
                          + Natural (HSB (Cert_Pos + 1)) * 256
                          + Natural (HSB (Cert_Pos + 2));
                     begin
                        Cert_Pos := Cert_Pos + 3;         --  start of certificate_list
                        List_End := Natural'Min (Cert_Pos + ListLen, HSB_Len);
                     end;
                  end if;
                  --  Walk every entry: [cert len(3)][cert DER][ext len(2)][exts].
                  S.Chain_Count := 0;
                  while Cert_Pos + 3 <= List_End loop
                     declare
                        Cert_Len : constant Natural :=
                          Natural (HSB (Cert_Pos))
                          * 65536
                          + Natural (HSB (Cert_Pos + 1)) * 256
                          + Natural (HSB (Cert_Pos + 2));
                     begin
                        Cert_Pos := Cert_Pos + 3;
                        exit when Cert_Len = 0 or else Cert_Pos + Cert_Len > List_End;
                        if S.Chain_Count < Max_Chain then
                           S.Chain_Count := S.Chain_Count + 1;
                           S.Chain (S.Chain_Count) :=
                             (First => Cert_Pos, Last => Cert_Pos + Cert_Len - 1);
                        end if;
                        if S.Chain_Count = 1 then
                           --  leaf: kept for CertificateVerify
                           S.Cert_First := Cert_Pos;
                           S.Cert_Last := Cert_Pos + Cert_Len - 1;
                           S.Have_Cert := True;
                        end if;
                        Cert_Pos := Cert_Pos + Cert_Len;
                        exit when Cert_Pos + 2 > List_End;   --  skip this entry's extensions
                        Cert_Pos :=
                          Cert_Pos
                          + 2
                          + Natural (HSB (Cert_Pos)) * 256
                          + Natural (HSB (Cert_Pos + 1));
                     end;
                  end loop;
                  S.Cert_End := Pos + 4 + MLen;       --  transcript point for CertVerify
               end;
            elsif MType = 15 then
               --  CertificateVerify
               S.CV_Alg := U16 (HSB (Pos + 4)) * 256 + U16 (HSB (Pos + 5));
               declare
                  Sig_Len : constant Natural :=
                    Natural (HSB (Pos + 6)) * 256 + Natural (HSB (Pos + 7));
               begin
                  --  The signature must exactly fill the message body (2 alg + 2
                  --  len + Sig_Len = MLen).  Reject anything else: a bogus wire
                  --  length (up to 65535) would otherwise push CV_Sig_Last past
                  --  the message -- and past the 8 KB HSB -- so Verify_Cert_Verify
                  --  sizes a giant stack array and reads out of bounds.
                  if MLen >= 4 and then Sig_Len = MLen - 4 then
                     S.CV_Sig_First := Pos + 8;
                     S.CV_Sig_Last := Pos + 8 + Sig_Len - 1;
                  else
                     S.CV_Sig_First := 1;
                     S.CV_Sig_Last := 0;      --  Sig_Len <= 0 => Verify rejects it
                  end if;
               end;
               S.CV_End := Pos + 4 + MLen;            --  transcript point for Finished
            elsif MType = 20 then
               --  Finished
               S.Fin_First := Pos + 4;
               S.Fin_Last := Pos + 4 + MLen - 1;
               Saw_Finished := True;
            end if;
            Pos := Pos + 4 + MLen;
         end;
      end loop;
   end Scan_Messages;

   procedure Read_Server_Flight (S : in out Session; Sock : Socket_Type; Ok : out Boolean) is
      Frag       : Byte_Array renames RB;
      CType      : U8;
      Len        : Natural;
      Rec_OK     : Boolean;
      Seq        : Unsigned_64 := 0;
      Inner_Type : U8;
      Out_Len    : Natural;
      Dec_OK     : Boolean;
      Records    : Natural := 0;
      Fin        : Boolean := False;
   begin
      Ok := False;
      HSB_Len := 0;
      for Attempt in 1 .. 16 loop
         Recv_Record (Sock, CType, Frag, Len, Rec_OK);
         exit when not Rec_OK;
         if CType = CT_Change_Cipher_Spec then
            null;                                     --  middlebox-compat, ignore
         elsif CType = 23 then
            --  encrypted handshake
            Decrypt_Record
              (S.Server_Key, S.Server_IV, Frag, Len, Seq, Out_Len, Inner_Type, Dec_OK);
            if not Dec_OK then
               return;                                --  bad tag => wrong keys

            end if;
            Seq := Seq + 1;
            Records := Records + 1;
            if Inner_Type = 22 then
               --  handshake content
               for I in 0 .. Out_Len - 1 loop
                  if HSB_Len <= HSB'Last then
                     HSB (HSB_Len) := GC_P (I);
                     HSB_Len := HSB_Len + 1;
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
      --  Transcript through the message just before the server Finished.  The
      --  Finished message starts 4 bytes (its handshake header) before its
      --  verify_data at Fin_First; this is CertificateVerify's end in a full
      --  handshake and EncryptedExtensions' end in a resumed (no-cert) one.
      Pre    : constant Natural := (if S.Fin_First >= 4 then S.Fin_First - 4 else 0);
      TLen   : constant Natural := TR_Len + Pre;
      Msg    : Byte_Seq (0 .. N32 (TLen) - 1);
      TH     : SHA.Digest;
      TH_BA  : Byte_Array (0 .. 31);
      Exp    : SHA.Digest;
      Match  : Boolean := True;
   begin
      S.Fin_OK := False;
      if S.Fin_First < 4 or else S.Fin_Last - S.Fin_First /= 31 then
         return;
      end if;
      for I in 0 .. 31 loop
         FK_BA (I) := U8 (FK (N32 (I)));
      end loop;
      for I in 0 .. TR_Len - 1 loop
         Msg (N32 (I)) := Byte (TR (I));
      end loop;
      for I in 0 .. Pre - 1 loop
         Msg (N32 (TR_Len + I)) := Byte (HSB (I));
      end loop;
      TH := SHA.Hash (Msg);
      for I in 0 .. 31 loop
         TH_BA (I) := U8 (TH (Index_32 (I)));
      end loop;
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
      Ctx      : constant String := "TLS 1.3, server CertificateVerify";
      Cert_Len : constant Natural := S.Cert_Last - S.Cert_First + 1;
      Sig_Len  : constant Natural := S.CV_Sig_Last - S.CV_Sig_First + 1;
      TLen     : constant Natural := TR_Len + S.Cert_End;     --  CH .. Certificate
      CertBuf  : X509.Byte_Array (0 .. Cert_Len - 1);
      Sig      : X509.Byte_Array (0 .. Sig_Len - 1);
      Signed   : X509.Byte_Array (0 .. 64 + Ctx'Length + 1 + 32 - 1);
      Cert     : X509.Certificate;
      Msg      : Byte_Seq (0 .. N32 (TLen) - 1);
      Digest   : SHA.Digest;
   begin
      S.CV_OK := False;
      if Cert_Len <= 0
        or else Sig_Len <= 0
        or else S.Cert_End = 0
        or else (S.CV_Alg /= 16#0804#               --  rsa_pss_rsae_sha256
                 and then S.CV_Alg /= 16#0403#)      --  ecdsa_secp256r1_sha256
      then
         return;
      end if;
      for I in 0 .. Cert_Len - 1 loop
         CertBuf (I) := HSB (S.Cert_First + I);
      end loop;
      X509.Parse (CertBuf, Cert);
      if not Cert.Valid then
         return;
      end if;
      for I in 0 .. Sig_Len - 1 loop
         Sig (I) := HSB (S.CV_Sig_First + I);
      end loop;

      --  Transcript-Hash(ClientHello .. Certificate).
      for I in 0 .. TR_Len - 1 loop
         Msg (N32 (I)) := Byte (TR (I));
      end loop;
      for I in 0 .. S.Cert_End - 1 loop
         Msg (N32 (TR_Len + I)) := Byte (HSB (I));
      end loop;
      Digest := SHA.Hash (Msg);

      for I in 0 .. 63 loop
         Signed (I) := 16#20#;
      end loop;
      for I in Ctx'Range loop
         Signed (64 + (I - Ctx'First)) := U8 (Character'Pos (Ctx (I)));
      end loop;
      Signed (64 + Ctx'Length) := 0;
      for I in 0 .. 31 loop
         Signed (64 + Ctx'Length + 1 + I) := U8 (Digest (Index_32 (I)));
      end loop;

      if S.CV_Alg = 16#0804# then
         S.CV_OK :=
           Cert.Key_Kind = X509.Key_RSA
           and then Cert_Verify.RSA_PSS_SHA256
                      (Message   => Signed,
                       Signature => Sig,
                       Modulus   => CertBuf (Cert.RSA_Modulus.First .. Cert.RSA_Modulus.Last),
                       Exponent  => CertBuf (Cert.RSA_Exponent.First .. Cert.RSA_Exponent.Last));
      else
         --  ecdsa_secp256r1_sha256
         S.CV_OK :=
           Cert.Key_Kind = X509.Key_EC_P256
           and then Cert_Verify.ECDSA_P256_SHA256
                      (Message => Signed,
                       Sig_DER => Sig,
                       Pub_X   => CertBuf (Cert.EC_X.First .. Cert.EC_X.Last),
                       Pub_Y   => CertBuf (Cert.EC_Y.First .. Cert.EC_Y.Last));
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
   procedure Send_Encrypted
     (Sock       : Socket_Type;
      RKey, RIV  : Byte_Array;
      Seq        : Unsigned_64;
      Inner      : Byte_Array;
      Inner_Type : U8)
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
      for I in 0 .. 15 loop
         Key (I) := RKey (RKey'First + I);
      end loop;
      for I in 0 .. 11 loop
         IV (I) := RIV (RIV'First + I);
      end loop;
      for I in 0 .. 7 loop
         IV (11 - I) := IV (11 - I) xor U8 (Shift_Right (Seq, 8 * I) and 16#FF#);
      end loop;
      AAD := (16#17#, 16#03#, 16#03#, U8 (RLen / 256), U8 (RLen mod 256));
      for I in 0 .. Inner'Length - 1 loop
         GE_P (I) := Inner (Inner'First + I);
      end loop;
      GE_P (PLen - 1) := Inner_Type;
      Encrypt (Key, IV, AAD, GE_P (0 .. PLen - 1), GE_C (0 .. PLen - 1), Tag);
      ER (0) := 16#17#;
      ER (1) := 16#03#;
      ER (2) := 16#03#;
      ER (3) := U8 (RLen / 256);
      ER (4) := U8 (RLen mod 256);
      for I in 0 .. PLen - 1 loop
         ER (5 + I) := GE_C (I);
      end loop;
      for I in 0 .. 15 loop
         ER (5 + PLen + I) := Tag (I);
      end loop;
      Send_Bytes (Sock, ER (0 .. 5 + RLen - 1));
   end Send_Encrypted;

   --  Send our Finished and derive the application traffic keys -> channel open.
   procedure Complete_Handshake (S : in out Session; Sock : Socket_Type) is
      No_Ctx                       : constant Byte_Seq (1 .. 0) := (others => 0);
      TLen                         : constant Natural :=
        TR_Len + HSB_Len;   --  CH .. server Finished
      Msg                          : Byte_Seq (0 .. N32 (TLen) - 1);
      TH                           : SHA.Digest;
      TH_BA                        : Byte_Array (0 .. 31);
      CFK                          : constant Byte_Seq :=
        Expand_Label (To_Digest (S.C_HS_Secret), "finished", No_Ctx, 32);
      CFK_BA                       : Byte_Array (0 .. 31);
      VD                           : SHA.Digest;
      Fin                          : Byte_Array (0 .. 35);                   --  [20][00 00 20][32]
      Z32                          : constant Byte_Seq (0 .. 31) := (others => 0);
      Derived2, Master, C_Ap, S_Ap : SHA.Digest;
      CCS                          : constant Byte_Array :=
        (16#14#, 16#03#, 16#03#, 16#00#, 16#01#, 16#01#);
   begin
      for I in 0 .. TR_Len - 1 loop
         Msg (N32 (I)) := Byte (TR (I));
      end loop;
      for I in 0 .. HSB_Len - 1 loop
         Msg (N32 (TR_Len + I)) := Byte (HSB (I));
      end loop;
      TH := SHA.Hash (Msg);
      for I in 0 .. 31 loop
         TH_BA (I) := U8 (TH (Index_32 (I)));
      end loop;

      --  client Finished
      for I in 0 .. 31 loop
         CFK_BA (I) := U8 (CFK (N32 (I)));
      end loop;
      VD := HMAC (CFK_BA, TH_BA);
      Fin (0) := 20;
      Fin (1) := 0;
      Fin (2) := 0;
      Fin (3) := 32;
      for I in 0 .. 31 loop
         Fin (4 + I) := U8 (VD (Index_32 (I)));
      end loop;

      --  Master Secret -> application traffic secrets -> application keys.
      Derived2 := Derive_Secret (To_Digest (S.HS_Secret), "derived", SHA_Empty);
      HKDF.Extract (Master, IKM => Z32, Salt => Derived2);
      C_Ap := Derive_Secret (Master, "c ap traffic", TH);
      S_Ap := Derive_Secret (Master, "s ap traffic", TH);
      declare
         CK : constant Byte_Seq := Expand_Label (C_Ap, "key", No_Ctx, 16);
         CV : constant Byte_Seq := Expand_Label (C_Ap, "iv", No_Ctx, 12);
         SK : constant Byte_Seq := Expand_Label (S_Ap, "key", No_Ctx, 16);
         SV : constant Byte_Seq := Expand_Label (S_Ap, "iv", No_Ctx, 12);
      begin
         for I in 0 .. 15 loop
            S.C_App_Key (I) := U8 (CK (N32 (I)));
         end loop;
         for I in 0 .. 11 loop
            S.C_App_IV (I) := U8 (CV (N32 (I)));
         end loop;
         for I in 0 .. 15 loop
            S.S_App_Key (I) := U8 (SK (N32 (I)));
         end loop;
         for I in 0 .. 11 loop
            S.S_App_IV (I) := U8 (SV (N32 (I)));
         end loop;
      end;
      S.C_App_Seq := 0;
      S.S_App_Seq := 0;

      --  resumption_master_secret = Derive-Secret(Master, "res master",
      --  Transcript-Hash(ClientHello .. client Finished)).
      declare
         RM  : Byte_Seq (0 .. N32 (TLen + Fin'Length) - 1);
         RTH : SHA.Digest;
         Res : SHA.Digest;
      begin
         for I in 0 .. TLen - 1 loop
            RM (N32 (I)) := Msg (N32 (I));
         end loop;
         for I in Fin'Range loop
            RM (N32 (TLen + (I - Fin'First))) := Byte (Fin (I));
         end loop;
         RTH := SHA.Hash (RM);
         Res := Derive_Secret (Master, "res master", RTH);
         for I in 0 .. 31 loop
            S.Res_Master (I) := U8 (Res (Index_32 (I)));
         end loop;
         S.Have_Res := True;
      end;

      Send_Bytes (Sock, CCS);                                    --  middlebox-compat
      Send_Encrypted (Sock, S.Client_Key, S.Client_IV, 0, Fin, 22);  --  our Finished
      S.Open := True;
   end Complete_Handshake;

   ---------------------------------------------------------------------------
   --  Drive the opening exchange.
   ---------------------------------------------------------------------------

   procedure Hello (S : in out Session; Sock : Socket_Type; Host : String; Ok : out Boolean) is
      Frag   : Byte_Array renames RB;
      CType  : U8;
      Len    : Natural;
      Rec_OK : Boolean;
   begin
      Ok := False;
      TR_Len := 0;
      Make_Key_Pair (S);
      Send_Client_Hello (S, Sock, Host);

      --  Read records until a handshake record arrives (skip ChangeCipherSpec).
      for Attempt in 1 .. 4 loop
         Recv_Record (Sock, CType, Frag, Len, Rec_OK);
         if not Rec_OK then
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
                  --  Require the CertificateVerify signature to check out, not
                  --  just Finished: Finished proves the ECDHE agreement, while
                  --  CertificateVerify proves the peer holds the presented cert's
                  --  private key.  A full (non-PSK) handshake without CV_OK is a
                  --  MITM forwarding someone else's certificate.  (Chain / trust-
                  --  anchor / hostname validation is still the caller's job -- see
                  --  Server_Cert_Verify_OK and Chain_Verify in the spec.)
                  if S.Fin_OK and then S.CV_OK then
                     Complete_Handshake (S, Sock);   --  send our Finished, open channel

                  end if;
               end if;
            end if;
            return;
         end if;
      end loop;
   end Hello;

   --  ClientHello for resumption: as Send_Client_Hello, but with the pre_shared_key
   --  extension last (RFC 8446 4.2.11) offering S.Ticket as a PSK-with-(EC)DHE
   --  identity, then the binder over the truncated ClientHello.
   procedure Send_Resume_Client_Hello (S : in out Session; Sock : Socket_Type; Host : String) is
      B                                                                   : Builder renames CH;
      Rnd                                                                 :
        ESP32S3.RNG.Byte_Array (0 .. 31);
      Rec_Mark, HS_Mark, Body_Mark, Ext_Mark, SNI_Mark, PSK_Mark, Bind_At : Natural;
   begin
      B.Len := 0;
      P8 (B, CT_Handshake);
      P16 (B, 16#0303#);
      Rec_Mark := B.Len;
      P16 (B, 0);
      P8 (B, HS_Client_Hello);
      HS_Mark := B.Len;
      P8 (B, 0);
      P16 (B, 0);
      Body_Mark := B.Len;
      P16 (B, 16#0303#);
      ESP32S3.RNG.Fill (Rnd);
      for I in 0 .. 31 loop
         S.Client_Random (I) := U8 (Rnd (I));
         P8 (B, U8 (Rnd (I)));
      end loop;
      ESP32S3.RNG.Fill (Rnd);
      P8 (B, 32);
      for I in 0 .. 31 loop
         P8 (B, U8 (Rnd (I)));
      end loop;
      P16 (B, 2);
      P16 (B, TLS_AES_128_GCM_SHA256);
      P8 (B, 1);
      P8 (B, 0);
      Ext_Mark := B.Len;
      P16 (B, 0);
      P16 (B, 0);
      SNI_Mark := B.Len;
      P16 (B, 0);                 --  server_name (SNI)
      P16 (B, Host'Length + 3);
      P8 (B, 0);
      P16 (B, Host'Length);
      PString (B, Host);
      Patch16 (B, SNI_Mark);
      P16 (B, 10);
      P16 (B, 6);
      P16 (B, 4);                --  supported_groups
      P16 (B, 16#001D#);
      P16 (B, 16#0017#);
      P16 (B, 13);
      P16 (B, 8);
      P16 (B, 6);                --  signature_algorithms
      P16 (B, 16#0401#);
      P16 (B, 16#0804#);
      P16 (B, 16#0403#);
      P16 (B, 43);
      P16 (B, 3);
      P8 (B, 2);
      P16 (B, 16#0304#);  --  supported_versions
      P16 (B, 45);
      P16 (B, 2);
      P8 (B, 1);
      P8 (B, 1);     --  psk_key_exchange_modes
      P16 (B, 51);
      P16 (B, 107);
      P16 (B, 105);            --  key_share
      P16 (B, 16#001D#);
      P16 (B, 32);
      PBytes (B, S.Pub);
      P16 (B, 16#0017#);
      P16 (B, 65);
      P8 (B, 16#04#);
      PBytes (B, S.P256_Pub_X);
      PBytes (B, S.P256_Pub_Y);

      --  pre_shared_key (MUST be the last extension).
      P16 (B, 41);
      PSK_Mark := B.Len;
      P16 (B, 0);
      P16 (B, U16 (S.Ticket_Len + 6));                      --  PskIdentity list length
      P16 (B, U16 (S.Ticket_Len));                          --  identity length
      for I in 0 .. S.Ticket_Len - 1 loop
         P8 (B, S.Ticket (I));
      end loop;
      P8 (B, U8 (Shift_Right (S.Offered_Age, 24) and 16#FF#));   --  obfuscated_ticket_age
      P8 (B, U8 (Shift_Right (S.Offered_Age, 16) and 16#FF#));
      P8 (B, U8 (Shift_Right (S.Offered_Age, 8) and 16#FF#));
      P8 (B, U8 (S.Offered_Age and 16#FF#));
      P16 (B, 33);
      P8 (B, 32);
      Bind_At := B.Len;          --  binders: len + entry len
      for I in 0 .. 31 loop
         P8 (B, 0);
      end loop;            --  binder placeholder
      Patch16 (B, PSK_Mark);
      Patch16 (B, Ext_Mark);

      declare
         HL : constant Natural := B.Len - Body_Mark;
      begin
         B.Data (HS_Mark) := U8 (HL / 65536);
         B.Data (HS_Mark + 1) := U8 ((HL / 256) mod 256);
         B.Data (HS_Mark + 2) := U8 (HL mod 256);
      end;
      Patch16 (B, Rec_Mark);

      --  binder = HMAC(finished_key, Transcript-Hash(truncated CH)); the truncated
      --  CH is the handshake message (from byte 5) minus the 35-byte binders portion
      --  (2 list-len + 1 entry-len + 32 binder).
      declare
         No_Ctx            : constant Byte_Seq (1 .. 0) := (others => 0);
         Z32               : constant Byte_Seq (0 .. 31) := (others => 0);
         PSKb              : Byte_Seq (0 .. 31);
         Early, Binder_Key : SHA.Digest;
         FK                : Byte_Seq (0 .. 31);
         TruncLen          : constant Natural := (B.Len - 5) - 35;
         TS                : Byte_Seq (0 .. N32 (TruncLen) - 1);
         TH, VD            : SHA.Digest;
         TH_BA, FK_BA      : Byte_Array (0 .. 31);
      begin
         for I in 0 .. 31 loop
            PSKb (N32 (I)) := Byte (S.Offered_PSK (I));
         end loop;
         HKDF.Extract (Early, IKM => PSKb, Salt => Z32);
         Binder_Key := Derive_Secret (Early, "res binder", SHA_Empty);
         FK := Expand_Label (Binder_Key, "finished", No_Ctx, 32);
         for I in 0 .. TruncLen - 1 loop
            TS (N32 (I)) := Byte (B.Data (5 + I));
         end loop;
         TH := SHA.Hash (TS);
         for I in 0 .. 31 loop
            TH_BA (I) := U8 (TH (Index_32 (I)));
            FK_BA (I) := U8 (FK (N32 (I)));
         end loop;
         VD := HMAC (FK_BA, TH_BA);
         for I in 0 .. 31 loop
            B.Data (Bind_At + I) := U8 (VD (Index_32 (I)));
         end loop;
      end;

      Send_Bytes (Sock, B.Data (0 .. B.Len - 1));
      Transcript (B.Data (5 .. B.Len - 1));         --  full CH including the real binder
   end Send_Resume_Client_Hello;

   procedure Resume
     (S       : in out Session;
      Sock    : Socket_Type;
      Host    : String;
      Prior   : Session;
      Ok      : out Boolean;
      Resumed : out Boolean)
   is
      Frag   : Byte_Array renames RB;
      CType  : U8;
      Len    : Natural;
      Rec_OK : Boolean;
   begin
      Ok := False;
      Resumed := False;
      if not Prior.Has_Tick then
         return;
      end if;
      --  Carry the prior session's ticket + resumption PSK into this attempt.
      S.Offered_PSK := Prior.Ticket_PSK;
      S.Offered_Age := Prior.Ticket_Age_Add;
      S.Ticket := Prior.Ticket;
      S.Ticket_Len := Prior.Ticket_Len;
      S.Resumed_PSK := False;

      TR_Len := 0;
      Make_Key_Pair (S);
      Send_Resume_Client_Hello (S, Sock, Host);
      for Attempt in 1 .. 4 loop
         Recv_Record (Sock, CType, Frag, Len, Rec_OK);
         if not Rec_OK then
            return;
         end if;
         if CType = CT_Alert then
            return;
         elsif CType = CT_Change_Cipher_Spec then
            null;
         elsif CType = CT_Handshake then
            Parse_Server_Hello (S, Frag, Len, Ok);
            if Ok then
               Transcript (Frag (Frag'First .. Frag'First + Len - 1));
               Derive_Keys (S);
               Read_Server_Flight (S, Sock, S.Flight);
               if S.Flight then
                  if not S.Resumed_PSK then
                     --  full fallback: a cert was sent
                     Verify_Cert_Verify (S);
                  end if;
                  Verify_Finished (S);
                  --  On the full (cert) path require CV_OK; a PSK resumption is
                  --  authenticated by the pre-shared key itself, no cert sent.
                  if S.Fin_OK and then (S.Resumed_PSK or else S.CV_OK) then
                     Complete_Handshake (S, Sock);
                     Resumed := S.Resumed_PSK;
                  end if;
               end if;
            end if;
            return;
         end if;
      end loop;
   end Resume;

   function Cipher_Suite (S : Session) return U16
   is (S.Suite);
   function Server_Key_Share (S : Session) return Byte_Array
   is (S.Server_Pub);
   function Client_Random (S : Session) return Byte_Array
   is (S.Client_Random);
   function Server_HS_Secret (S : Session) return Byte_Array
   is (S.S_HS_Secret);
   function Client_HS_Secret (S : Session) return Byte_Array
   is (S.C_HS_Secret);
   function Keys_Ready (S : Session) return Boolean
   is (S.Have_Keys);
   function Flight_OK (S : Session) return Boolean
   is (S.Flight);
   function Have_Server_Cert (S : Session) return Boolean
   is (S.Have_Cert);
   function Server_Cert (S : Session) return Byte_Array
   is (HSB (S.Cert_First .. S.Cert_Last));

   function Server_Cert_Count (S : Session) return Natural
   is (S.Chain_Count);

   function Server_Chain_Cert (S : Session; Index : Positive) return X509.Byte_Array is
      Bounds : constant Cert_Bounds := S.Chain (Index);
      Result : X509.Byte_Array (0 .. Bounds.Last - Bounds.First);
   begin
      for I in Result'Range loop
         Result (I) := X509.U8 (HSB (Bounds.First + I));
      end loop;
      return Result;
   end Server_Chain_Cert;

   function Server_Finished_OK (S : Session) return Boolean
   is (S.Fin_OK);
   function Server_Cert_Verify_OK (S : Session) return Boolean
   is (S.CV_OK);
   function Ready (S : Session) return Boolean
   is (S.Open);

   procedure Send (S : in out Session; Sock : Socket_Type; Data : Byte_Array) is
   begin
      Send_Encrypted (Sock, S.C_App_Key, S.C_App_IV, S.C_App_Seq, Data, 23);
      S.C_App_Seq := S.C_App_Seq + 1;
   end Send;

   --  Parse the first NewSessionTicket in the just-decrypted handshake plaintext
   --  GC_P (0 .. Len-1) and derive its resumption PSK (RFC 8446 4.6.1).  Only the
   --  first ticket of the session is kept.
   procedure Capture_Ticket (S : in out Session; Len : Natural) is
      Pos, Body_End, Msg_Len, Nonce_Len, Tick_Len : Natural;
      Empty                                       : constant Byte_Seq (1 .. 0) := (others => 0);
      Nonce                                       : Byte_Array (0 .. 255) := (others => 0);
   begin
      if S.Has_Tick or else not S.Have_Res then
         return;                                  --  keep the first ticket only

      end if;
      if Len < 4 or else GC_P (0) /= 4 then
         --  handshake type 4 = NewSessionTicket
         return;
      end if;
      Msg_Len := Natural (GC_P (1)) * 65536 + Natural (GC_P (2)) * 256 + Natural (GC_P (3));
      Body_End := 4 + Msg_Len;
      Pos := 4;
      if Body_End > Len or else Pos + 8 > Body_End then
         return;                                   --  lifetime(4) + age_add(4)

      end if;
      S.Ticket_Age_Add :=
        Unsigned_32 (GC_P (Pos + 4))
        * 16#0100_0000#
        + Unsigned_32 (GC_P (Pos + 5)) * 16#1_0000#
        + Unsigned_32 (GC_P (Pos + 6)) * 16#100#
        + Unsigned_32 (GC_P (Pos + 7));
      Pos := Pos + 8;
      if Pos >= Body_End then
         return;
      end if;
      Nonce_Len := Natural (GC_P (Pos));
      Pos := Pos + 1;
      if Nonce_Len > 255 or else Pos + Nonce_Len > Body_End then
         return;
      end if;
      for I in 0 .. Nonce_Len - 1 loop
         Nonce (I) := U8 (GC_P (Pos + I));
      end loop;
      Pos := Pos + Nonce_Len;
      if Pos + 2 > Body_End then
         return;
      end if;
      Tick_Len := Natural (GC_P (Pos)) * 256 + Natural (GC_P (Pos + 1));
      Pos := Pos + 2;
      if Tick_Len = 0 or else Tick_Len > Max_Ticket or else Pos + Tick_Len > Body_End then
         return;
      end if;
      for I in 0 .. Tick_Len - 1 loop
         S.Ticket (I) := U8 (GC_P (Pos + I));
      end loop;
      S.Ticket_Len := Tick_Len;

      --  PSK = HKDF-Expand-Label(resumption_master_secret, "resumption", nonce, 32).
      declare
         PSK : Byte_Seq (0 .. 31);
      begin
         if Nonce_Len = 0 then
            PSK := Expand_Label (To_Digest (S.Res_Master), "resumption", Empty, 32);
         else
            declare
               NS : Byte_Seq (0 .. N32 (Nonce_Len) - 1);
            begin
               for I in 0 .. Nonce_Len - 1 loop
                  NS (N32 (I)) := Byte (Nonce (I));
               end loop;
               PSK := Expand_Label (To_Digest (S.Res_Master), "resumption", NS, 32);
            end;
         end if;
         for I in 0 .. 31 loop
            S.Ticket_PSK (I) := U8 (PSK (N32 (I)));
         end loop;
      end;
      S.Has_Tick := True;
   end Capture_Ticket;

   function Has_Ticket (S : Session) return Boolean
   is (S.Has_Tick);
   function Server_Accepted_PSK (S : Session) return Boolean
   is (S.Resumed_PSK);

   procedure Recv
     (S    : in out Session;
      Sock : Socket_Type;
      Buf  : out Byte_Array;
      Last : out Natural;
      Ok   : out Boolean)
   is
      Frag       : Byte_Array renames RB;
      CType      : U8;
      Len        : Natural;
      Rec_OK     : Boolean;
      Inner_Type : U8;
      Out_Len    : Natural;
      Dec_OK     : Boolean;
   begin
      Last := (if Buf'First > 0 then Buf'First - 1 else 0);
      Ok := False;
      loop
         Recv_Record (Sock, CType, Frag, Len, Rec_OK);
         if not Rec_OK then
            return;
         end if;
         if CType = CT_Change_Cipher_Spec then
            null;                                          --  ignore
         elsif CType = 23 then
            Decrypt_Record
              (S.S_App_Key, S.S_App_IV, Frag, Len, S.S_App_Seq, Out_Len, Inner_Type, Dec_OK);
            if not Dec_OK then
               return;
            end if;
            S.S_App_Seq := S.S_App_Seq + 1;
            if Inner_Type = 23 then
               --  application_data
               declare
                  Copy_Len : constant Natural := Natural'Min (Out_Len, Buf'Length);
               begin
                  for I in 0 .. Copy_Len - 1 loop
                     Buf (Buf'First + I) := GC_P (I);
                  end loop;
                  Last := Buf'First + Copy_Len - 1;
                  Ok := True;
                  return;
               end;
            elsif Inner_Type = 21 then
               --  alert
               return;
            elsif Inner_Type = 22 then
               --  NewSessionTicket
               Capture_Ticket (S, Out_Len);                   --  capture, then loop
            end if;
         else
            return;
         end if;
      end loop;
   end Recv;

end TLS_Client;
