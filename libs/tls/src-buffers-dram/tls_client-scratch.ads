with ESP32S3.AES.GCM;

--  The TLS client's big static buffers (one handshake at a time, kept off the
--  limited task stack).  DRAM variant -- the default (TLS_BUFFERS=dram): plain
--  internal-RAM statics, exactly the placement the buffers always had.  The
--  PSRAM variant (src-buffers-psram) puts them in .ext_ram.bss for apps whose
--  leftover-DRAM heap is squeezed (e.g. alongside the Wi-Fi blob + LCD).
private package TLS_Client.Scratch is

   TR : Byte_Array (0 .. 4095);        --  handshake transcript

   CH : Builder;                       --  ClientHello build buffer
   RB : Byte_Array (0 .. 4095);        --  inbound record fragment

   GC_C : ESP32S3.AES.GCM.Byte_Array (0 .. 4095);   --  decrypt-side GCM scratch
   GC_P : ESP32S3.AES.GCM.Byte_Array (0 .. 4095);
   HSB  : Byte_Array (0 .. 8191);      --  reassembled handshake messages

   GE_P : ESP32S3.AES.GCM.Byte_Array (0 .. 4095);   --  encrypt-side GCM scratch
   GE_C : ESP32S3.AES.GCM.Byte_Array (0 .. 4095);
   ER   : Byte_Array (0 .. 4127);      --  assembled outbound record

end TLS_Client.Scratch;
