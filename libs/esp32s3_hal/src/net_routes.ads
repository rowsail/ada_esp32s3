with Net_Devices;

--  A tiny IPv4 routing table for boards with more than one network interface.
--  It maps a destination address to the interface that should carry it, by
--  longest-prefix match, preferring lower-metric routes and skipping interfaces
--  that are down -- so traffic leaves a live interface and fails over when one
--  drops.  The GNAT.Sockets facade consults this when a socket is not pinned to a
--  specific interface.
--
--  Selection, in order: among routes whose destination matches AND whose interface
--  is up, take the longest prefix (most specific), then the lowest metric.  So a
--  /24 route beats a /0 default regardless of metric, while two default routes are
--  decided by metric (e.g. wired 10 < cellular 100 => prefer wired, fall back to
--  cellular only when wired is down).
--
--  Liveness is injected (Configure) rather than wired to a specific stack, so the
--  table is pure logic and host-testable with a mock up-state.

package Net_Routes is

   subtype Interface_Id is Net_Devices.Interface_Id;

   --  Is interface Id usable right now?  Supplied by the caller -- the facade wires
   --  this to Net_Devices.Device.Is_Up through its registry.  Must be library-level
   --  and closure-free (bare-metal callback rules).
   type Up_Query is access function (Id : Interface_Id) return Boolean;

   procedure Configure (Is_Up : Up_Query);

   --  Add a route: destinations matching Dest under Mask go out Iface.  Lower
   --  Metric wins among equally-specific routes.
   procedure Add_Route
     (Dest, Mask : Net_Devices.IPv4_Address; Iface : Interface_Id; Metric : Natural := 100);

   --  Shorthand for a 0.0.0.0/0 default route out Iface.
   procedure Set_Default (Iface : Interface_Id; Metric : Natural := 100);

   --  Drop all routes (reconfiguration / tests).
   procedure Clear;

   --  Are any routes configured?  The facade falls back to its default interface
   --  when this is False, so a single-interface board that sets up no routes keeps
   --  its original behaviour; once routes exist, resolution is strict.
   function Has_Routes return Boolean;

   --  Choose the interface for Dest: longest-prefix match among routes whose
   --  interface is up, then lowest metric.  Found is False if none qualify (no
   --  matching route, or every matching interface is down).
   procedure Resolve
     (Dest : Net_Devices.IPv4_Address; Iface : out Interface_Id; Found : out Boolean);

end Net_Routes;
