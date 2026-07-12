with ESP32S3.W5500;
with ESP32S3.W5500.DHCP;

--  The W5500 as a board resource -- pins, MAC and bring-up in this ONE place;
--  every example that talks to the chip shares this package (from
--  examples/common/src).  EDIT the pins in the body to match your hardware.
--
--  Three ways in, by what the example needs:
--
--   * Bring_Up (Settings, Lease): DHCP by default (the router assigns IP /
--     subnet / gateway / DNS and the lease reports them), or a static
--     configuration you supply; registers the chip with GNAT.Sockets.
--
--   * Bring_Up: the historical one-call static form (192.168.1.50/24 via
--     .254) that many self-contained examples print and document; edit the
--     constants in the body for your LAN.
--
--   * Just Dev: examples that drive the socket engine directly take
--     Dev'Access and do their own bring-up.
package W5500_Dev is

   Dev : aliased ESP32S3.W5500.Device;

   --  How the board gets its address: either DHCP (the router assigns IP /
   --  subnet / gateway / DNS), or a static configuration you supply.
   type IP_Settings (Use_DHCP : Boolean := True) is record
      case Use_DHCP is
         when True =>
            null;

         when False =>
            IP, Subnet, Gateway, DNS : ESP32S3.W5500.IPv4_Address;
      end case;
   end record;

   --  The default: ask a DHCP server for everything.
   DHCP_Config : constant IP_Settings := (Use_DHCP => True);

   --  Bring the link up using Settings.  False if the chip is absent, the
   --  link never comes up, or (DHCP) no server answers.  On True the chip is
   --  configured and registered with GNAT.Sockets, and Lease holds the
   --  address in effect -- the DHCP lease, or the static values echoed back
   --  -- so the caller reads Lease.DNS the same way either way.
   function Bring_Up
     (Settings : IP_Settings := DHCP_Config;
      Lease    : out ESP32S3.W5500.DHCP.Lease_Info) return Boolean;

   --  The one-call static form: SPI + reset + the fixed address below + wait
   --  for the link + register with GNAT.Sockets.  False only if the chip is
   --  not found; a missing cable is reported but tolerated, as the examples
   --  using this form always have.
   function Bring_Up return Boolean;

   --  Dotted-decimal text of an IPv4 address, e.g. "192.168.1.50".
   function Image (Address : ESP32S3.W5500.IPv4_Address) return String;

end W5500_Dev;
