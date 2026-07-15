--  A minimal pure-Ada DHCP client (DORA) over the ESP32S3.WiFi.IP UDP engine.
--  Acquire runs Discover/Offer/Request/Ack on one UDP socket, and on success
--  fills the lease AND calls IP.Configure so the interface is addressed.
with Interfaces;
with ESP32S3.WiFi.IP;

package ESP32S3.WiFi.DHCP is

   type Lease is record
      Addr, Mask, Gateway, DNS : ESP32S3.WiFi.IP.IPv4 := (0, 0, 0, 0);
      Lease_Seconds            : Interfaces.Unsigned_32 := 0;
   end record;

   --  Run DORA on the given (closed) UDP socket.  Returns True on ACK, having
   --  filled L and configured the interface; the socket is closed on return.
   function Acquire
     (Socket : ESP32S3.WiFi.IP.Socket_Id;
      L      : out Lease;
      Tries  : Positive := 4) return Boolean;

end ESP32S3.WiFi.DHCP;
