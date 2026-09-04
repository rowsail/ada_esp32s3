with Interfaces;

--  The pure, bounded response-parsing core of DNS_Client, factored out of
--  Resolve so it can be SPARK-proven free of run-time errors on any malformed or
--  malicious DNS reply.  It withs only Interfaces (+ ESP32S3.Endian in the body):
--  no sockets, no I/O, no chip dependency.  Find_A_Record walks the question and
--  answer sections -- including 0xC0 name-compression pointers -- over a
--  received-bytes buffer with a bounded, index-monotone walk, so a hostile reply
--  can neither overrun the buffer nor loop forever.
--
--  The parent DNS_Client is not Pure (it withs GNAT.Sockets), so this child
--  cannot be Pure either; it is SPARK_Mode => On instead (the property that
--  matters for the proof), mirroring ESP32S3.GPS.NMEA.

package DNS_Client.Parse with SPARK_Mode => On is

   subtype U8 is Interfaces.Unsigned_8;

   --  DNS messages are at most 64 KiB (the TCP length prefix is 16-bit; UDP
   --  replies are far smaller).  Capping the buffer index well below Integer'Last
   --  makes 'Length and every cursor addition provably non-overflowing while
   --  walking an untrusted reply -- the constrained-index pattern the ext4/X509
   --  proofs use.
   Max_Msg_Bytes : constant := 2 ** 16;                --  64 KiB
   subtype Buffer_Index is Natural range 0 .. Max_Msg_Bytes - 1;
   type Byte_Array is array (Buffer_Index range <>) of U8;

   --  The extracted first A record: Found with its four IPv4 octets, or not.
   type A_Record is record
      Found          : Boolean := False;
      B0, B1, B2, B3 : U8      := 0;   --  meaningful only when Found
   end record;

   --  Extract the first A record from a DNS reply.  Msg'Range is exactly the
   --  bytes actually received (Msg'First = 0, Msg'Last the last received index).
   --  Returns Found = False -- never an out-of-range access -- unless the reply
   --  echoes Expected_Id (the transaction id we asked with) in its header and
   --  carries a well-formed IN A record.
   function Find_A_Record
     (Msg : Byte_Array; Expected_Id : Interfaces.Unsigned_16) return A_Record
   with Pre => Msg'First = 0 and then Msg'Length > 0;

end DNS_Client.Parse;
