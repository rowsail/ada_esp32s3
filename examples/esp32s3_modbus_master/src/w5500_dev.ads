with ESP32S3.W5500;
with ESP32S3.W5500.DHCP;

--  The W5500 as a library-level, aliased board resource, plus a one-call bring-up
--  that uses DHCP: SPI + reset + wait for link + acquire a lease (which programs
--  the IP / subnet / GATEWAY into the chip) + hand the chip to the GNAT.Sockets
--  facade.  No address is hand-configured -- the router assigns it, and the
--  returned lease also carries the DNS server to use.
package W5500_Dev is
   Dev : aliased ESP32S3.W5500.Device;

   --  How the board gets its address: either DHCP (the router assigns IP / subnet
   --  / gateway / DNS), or a static configuration you supply.
   type IP_Settings (Use_DHCP : Boolean := True) is record
      case Use_DHCP is
         when True  => null;
         when False =>
            IP, Subnet, Gateway, DNS : ESP32S3.W5500.IPv4_Address;
      end case;
   end record;

   --  The default: ask a DHCP server for everything.
   DHCP_Config : constant IP_Settings := (Use_DHCP => True);

   --  Bring the link up using Settings.  False if the chip is absent, the link
   --  never comes up, or (DHCP) no server answers.  On True the chip is configured
   --  and registered with GNAT.Sockets, and Lease holds the address in effect --
   --  the DHCP lease, or the static values echoed back -- so the caller reads
   --  Lease.DNS the same way either way.
   function Bring_Up
     (Settings : IP_Settings := DHCP_Config;
      Lease    : out ESP32S3.W5500.DHCP.Lease_Info) return Boolean;

   --  Dotted-decimal text of an IPv4 address, e.g. "192.168.1.50".
   function Image (A : ESP32S3.W5500.IPv4_Address) return String;
end W5500_Dev;
