--  Promiscuous-mode (monitor) capture for the ESP32-S3 Wi-Fi radio.
--
--  A diagnostic + feature layer over the same blob bring-up as scan/connect:
--  esp_wifi_set_channel + esp_wifi_set_promiscuous(+_rx_cb) hand every 802.11
--  frame on a channel to our callback, which decodes the management/EAPOL
--  frames we care about (assoc req/resp, auth, deauth, EAPOL-Key) and logs
--  them.  Its first use is ground-truthing the WPA2 association from a second
--  board: watch exactly what assoc IEs a connecting station sends and how the
--  AP answers (status / deauth reason).
--
--  Concurrency: the RX decoder runs in the blob's Wi-Fi-task context and writes
--  to ESP32S3.Log, so nothing else may drive that console concurrently.  Start /
--  Stop / Set_Channel / Watch_Beacon are meant to be called from one owner task
--  (the environment task); they are not re-entrant.
with Interfaces;

private with System;

package ESP32S3.WiFi.Sniffer is

   --  Put the (already Initialized) radio on Channel and start delivering
   --  frames to the decoder.  Runs until Stop.  Requires ESP32S3.WiFi.Initialize
   --  to have succeeded (STA mode is fine; promiscuous overrides the filter).
   procedure Start (Channel : Interfaces.Unsigned_8; Result : out Status);

   procedure Stop;

   --  Retune to another channel (for hopping).  Cheap; call between reads.
   procedure Set_Channel (Channel : Interfaces.Unsigned_8);

   --  Dump the security IEs of the beacon from this one BSSID (once) -- handy
   --  for reading an AP's real AKM/PMF.  Off until called (no BSSID is baked
   --  into the source).
   procedure Watch_Beacon (BSSID : MAC_Address);

   --  Also print every payload data frame that involves this station MAC
   --  (as addr1/addr2/addr3), regardless of BSSID -- catches a station's
   --  frames even if it associated to a different (mesh) BSSID than expected.
   procedure Watch_Sta (Station : MAC_Address);

end ESP32S3.WiFi.Sniffer;
