with ESP32S3.AES.GCM;

--  The TLS client's big static buffers (one handshake at a time, kept off the
--  limited task stack).  PSRAM variant (TLS_BUFFERS=psram): all ~38 KB go to
--  .ext_ram.bss, for apps whose leftover-DRAM heap is squeezed (e.g. alongside
--  the Wi-Fi blob + LCD driver).  Requires the app to map PSRAM and provide an
--  .ext_ram.bss output section (and the CPU d-cache to be on whenever TLS
--  runs); the buffers are CPU-only, so PSRAM placement is safe -- just a bit
--  slower per access.
private package TLS_Client.Scratch is

   TR : Byte_Array (0 .. 4095)         --  handshake transcript
     with Linker_Section => ".ext_ram.bss", Alignment => 16;

   CH : Builder                        --  ClientHello build buffer
     with Linker_Section => ".ext_ram.bss", Alignment => 16;
   --  Inbound record fragment + decrypt scratch sized for a FULL TLS record
   --  (2^14 payload + expansion): big servers (IIS, CDNs) coalesce whole
   --  responses into 16 KB records, which the DRAM variant's 4 KB buffers
   --  reject.  PSRAM makes the full size affordable.
   RB : Byte_Array (0 .. 16_639)       --  inbound record fragment
     with Linker_Section => ".ext_ram.bss", Alignment => 16;

   GC_C : ESP32S3.AES.GCM.Byte_Array (0 .. 16_639)  --  decrypt-side GCM scratch
     with Linker_Section => ".ext_ram.bss", Alignment => 16;
   GC_P : ESP32S3.AES.GCM.Byte_Array (0 .. 16_639)
     with Linker_Section => ".ext_ram.bss", Alignment => 16;
   HSB  : Byte_Array (0 .. 8191)       --  reassembled handshake messages
     with Linker_Section => ".ext_ram.bss", Alignment => 16;

   GE_P : ESP32S3.AES.GCM.Byte_Array (0 .. 4095)    --  encrypt-side GCM scratch
     with Linker_Section => ".ext_ram.bss", Alignment => 16;
   GE_C : ESP32S3.AES.GCM.Byte_Array (0 .. 4095)
     with Linker_Section => ".ext_ram.bss", Alignment => 16;
   ER   : Byte_Array (0 .. 4127)       --  assembled outbound record
     with Linker_Section => ".ext_ram.bss", Alignment => 16;

end TLS_Client.Scratch;
