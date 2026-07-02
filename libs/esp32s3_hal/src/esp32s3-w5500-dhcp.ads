with Interfaces;
with ESP32S3.W5500.Sockets;

--  A minimal DHCP client for the W5500.  DHCP is a software protocol over UDP
--  (the chip has no hardware DHCP), so this rides on the socket engine: it runs
--  the DORA exchange (Discover / Offer / Request / Ack) and, on success, programs
--  the leased IP / subnet / gateway into the chip (Net.Configure).  Use it instead
--  of a static address.
--
--  Acquire_Lease is one-shot (no automatic renewal yet); call it again before the
--  lease expires to renew.  Requires the embedded or full profile.

package ESP32S3.W5500.DHCP is

   type Lease_Info is record
      IP, Subnet, Gateway, DNS : IPv4_Address := (0, 0, 0, 0);
      Lease_Seconds            : Interfaces.Unsigned_32 := 0;
   end record;

   --  Run DORA on the given hardware Socket using MAC as the client identity.
   --  On success: Lease is filled, the chip is configured with it, and the result
   --  is True.  On failure (no server answered within Tries attempts): False, and
   --  the chip is left with a 0.0.0.0 address.
   function Acquire_Lease
     (Dev    : ESP32S3.W5500.Sockets.Device_Access;
      MAC    : MAC_Address;
      Lease  : out Lease_Info;
      Socket : Socket_Id := 0;
      Tries  : Positive := 4) return Boolean;

   --  Renew an existing lease once: a REQUEST that keeps the current IP up
   --  (ciaddr = the leased address), broadcast so any server can answer.  True on
   --  ACK, with Lease refreshed.  (Maintain, below, does this automatically.)
   function Renew_Lease
     (Dev    : ESP32S3.W5500.Sockets.Device_Access;
      MAC    : MAC_Address;
      Lease  : in out Lease_Info;
      Socket : Socket_Id := 0) return Boolean;

   ----------------------------------------------------------------------------
   --  Automatic maintenance: acquire a lease and keep it renewed indefinitely.
   ----------------------------------------------------------------------------

   --  Called from the maintenance task on each (re)bind.  Must be library-level
   --  (no up-level-capturing nested subprogram -- see the HAL's no-trampoline rule).
   type Bound_Callback is access procedure (Lease : Lease_Info);

   --  Start a background task that acquires a lease and keeps it: it renews
   --  (unicast) at ~T1 = 50% of the lease, rebinds (broadcast) at ~T2 = 87.5%,
   --  and re-acquires on expiry, reprogramming the chip each time.  On_Bound, if
   --  given, is called on each (re)bind.  The given Socket is reserved for DHCP;
   --  the application must not use it.  Call Maintain once.
   procedure Maintain
     (Dev      : ESP32S3.W5500.Sockets.Device_Access;
      MAC      : MAC_Address;
      Socket   : Socket_Id := 0;
      On_Bound : Bound_Callback := null);

   function Is_Bound return Boolean;       --  a lease is currently held
   function Current_Lease return Lease_Info;

end ESP32S3.W5500.DHCP;
