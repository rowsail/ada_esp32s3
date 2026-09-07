with Interfaces;

--  The untrusted DER-INTEGER parse used to pull r and s out of an ECDSA
--  signature (ECDSA-Sig-Value SEQUENCE { r INTEGER, s INTEGER }) as it arrives
--  in a certificate or a TLS 1.3 CertificateVerify -- attacker-controlled bytes.
--  Split out from Cert_Verify (DER_Int / DER_Int_48) with SPARK contracts so
--  gnatprove can machine-check it never reads outside the signature buffer nor
--  writes outside the fixed-width output, for ANY input -- the memory-safety
--  property that matters on network input.  Width-generic: Out_Val'Length is the
--  field size (32 for P-256, 48 for P-384), so one proof covers both.
package Der_Sig with SPARK_Mode => On is

   subtype U8 is Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_8;   --  the Post compares Out_Val bytes to 0
   type Bytes is array (Natural range <>) of U8;

   --  Read a DER INTEGER (tag 0x02, short-form length) from Buf at Pos: big-endian,
   --  right-aligned into Out_Val, leading zero sign bytes dropped, short values
   --  left-padded with zero.  Pos is advanced past the INTEGER.  Ok is cleared on
   --  any malformation (already-failed, wrong tag, truncated length/value, or a
   --  value wider than Out_Val) and Out_Val is then all-zero.
   procedure Read_Integer
     (Buf     : Bytes;
      Pos     : in out Natural;
      Last    : Natural;
      Out_Val : out Bytes;
      Ok      : in out Boolean)
     with
       Pre  => Pos >= Buf'First
               and then Last <= Buf'Last
               --  bound Pos and Last well below Natural'Last so none of the index
               --  arithmetic can overflow; trivially true for any real buffer, and
               --  robust across chained calls (a malformed INTEGER may leave Pos a
               --  few past Last, which the tag/length checks then reject safely).
               and then Last <= Natural'Last - 256
               and then Pos <= Natural'Last - 256
               and then Out_Val'First = 0
               and then Out_Val'Length in 1 .. 255,
       Post => Pos >= Pos'Old and then (if not Ok'Old then not Ok)
               --  On ANY rejection the output is all-zero.  The comment above
               --  has always claimed this and the body has always done it, but
               --  until now nothing proved it, so a caller that mishandled Ok
               --  had no guarantee it was not holding attacker-chosen bytes in
               --  an ECDSA r or s.  This is the clause that makes ignoring Ok
               --  merely wrong rather than exploitable.
               and then (if not Ok then
                           (for all K in Out_Val'Range => Out_Val (K) = 0))
               --  On acceptance the parse consumed at least one byte and stopped
               --  inside the window -- so a caller reading r then s advances,
               --  and the second read starts within the signature.
               and then (if Ok then Pos > Pos'Old and then Pos <= Last + 1);

end Der_Sig;
