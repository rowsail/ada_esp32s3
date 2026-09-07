with Interfaces;
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
--
--  ---- what is proved ------------------------------------------------------
--  That selection rule is the whole reason this package exists -- it is what
--  decides Ethernet-to-cellular failover -- so it is proved, not just tested.
--  The proof is in two layers, because one obstacle is genuinely outside SPARK:
--
--    * Resolve's own postcondition (below) says it never hands back an
--      interface that is not on a route matching Dest.  No invented interface,
--      no entry past the end of the table, and nothing at all when no routes
--      are configured.
--    * The ranking itself -- longest prefix, then lowest metric, and that the
--      winner beats EVERY other candidate rather than merely the ones seen so
--      far -- is proved of Select_Route in the private part, which is where the
--      loop actually lives.
--
--  The split exists because Is_Up arrives as an access-to-function: SPARK has
--  no contract for it and so cannot reason through the call.  Resolve therefore
--  samples eligibility (matches AND up) once per route into an array, and the
--  ranking is proved over that array -- which is exactly the part a bug would
--  hide in.  Sampling also fixes the liveness for the duration of one decision,
--  so a link that drops mid-scan can no longer produce a self-inconsistent
--  answer (a route rejected as down losing to one admitted as up moments later).

package Net_Routes with SPARK_Mode => On is

   subtype Interface_Id is Net_Devices.Interface_Id;
   use type Net_Devices.Interface_Id;   --  the contracts below compare them

   --  Capacity of the table.  Visible because the proof model below indexes it.
   Max_Routes : constant := 16;
   subtype Route_Index is Positive range 1 .. Max_Routes;
   subtype Route_Total is Natural  range 0 .. Max_Routes;

   --  Is interface Id usable right now?  Supplied by the caller -- the facade wires
   --  this to Net_Devices.Device.Is_Up through its registry.  Must be library-level
   --  and closure-free (bare-metal callback rules).
   type Up_Query is access function (Id : Interface_Id) return Boolean;

   procedure Configure (Is_Up : Up_Query);

   --  Add a route: destinations matching Dest under Mask go out Iface.  Lower
   --  Metric wins among equally-specific routes.
   procedure Add_Route
     (Dest, Mask : Net_Devices.IPv4_Address; Iface : Interface_Id; Metric : Natural := 100)
   with Post => Has_Routes;

   --  Shorthand for a 0.0.0.0/0 default route out Iface.
   procedure Set_Default (Iface : Interface_Id; Metric : Natural := 100)
   with Post => Has_Routes;

   --  Drop all routes (reconfiguration / tests).
   procedure Clear
   with Post => not Has_Routes;

   --  Are any routes configured?  The facade falls back to its default interface
   --  when this is False, so a single-interface board that sets up no routes keeps
   --  its original behaviour; once routes exist, resolution is strict.
   function Has_Routes return Boolean;

   ---------------------------------------------------------------------------
   --  Proof model.  Ghost: compiled out of the real program, and here only so
   --  Resolve's postcondition can talk about the table without publishing it.
   ---------------------------------------------------------------------------

   function Route_Count return Route_Total with Ghost;

   --  Does route I's prefix cover Dest?
   function Route_Covers (I : Route_Index; Dest : Net_Devices.IPv4_Address) return Boolean
   with Ghost, Pre => I <= Route_Count;

   --  Which interface route I names.
   function Route_Iface (I : Route_Index) return Interface_Id
   with Ghost, Pre => I <= Route_Count;

   --  Choose the interface for Dest: longest-prefix match among routes whose
   --  interface is up, then lowest metric.  Found is False if none qualify (no
   --  matching route, or every matching interface is down).
   procedure Resolve
     (Dest : Net_Devices.IPv4_Address; Iface : out Interface_Id; Found : out Boolean)
   with Post =>
     --  Nothing is returned when nothing is configured ...
     (if not Has_Routes then not Found)
     --  ... and anything returned is a real route's interface, and a route
     --  whose prefix actually covers Dest.
     and then (if Found then
                 (for some I in 1 .. Route_Count =>
                    Route_Covers (I, Dest) and then Iface = Route_Iface (I)));

private

   use type Interfaces.Unsigned_32;

   type Route is record
      Dest, Mask : Interfaces.Unsigned_32 := 0;
      Iface      : Interface_Id := 0;
      Metric     : Natural := 0;
   end record;

   type Route_Table  is array (Route_Index) of Route;

   --  Per-route "this route is a candidate for the destination being resolved":
   --  its prefix covers the destination AND its interface was up when Resolve
   --  sampled.  One snapshot per call -- see the note at the top.
   type Eligibility is array (Route_Index) of Boolean;

   --  Prefix length = number of set bits in the mask (any mask, /0 .. /32).
   function Prefix_Len (Mask : Interfaces.Unsigned_32) return Natural
   with Post => Prefix_Len'Result <= 32;

   function Covers (R : Route; Dest_Bits : Interfaces.Unsigned_32) return Boolean
   is ((Dest_Bits and R.Mask) = (R.Dest and R.Mask));

   --  The selection order, as one predicate: I outranks J iff it is more
   --  specific, or equally specific and cheaper.  Everything the ranking means
   --  is here; Select_Route's postcondition just says it finds the maximum.
   function Outranks (T : Route_Table; I, J : Route_Index) return Boolean
   is (Prefix_Len (T (I).Mask) > Prefix_Len (T (J).Mask)
       or else (Prefix_Len (T (I).Mask) = Prefix_Len (T (J).Mask)
                and then T (I).Metric < T (J).Metric));

   --  Pick the best of the eligible routes in T (1 .. N).
   --
   --  The postcondition is the whole specification, and the third clause is the
   --  one with teeth: the winner is beaten by NO eligible route, not merely by
   --  none of the ones scanned before it.  A first-match-wins bug, a >= where a
   --  > belongs, or a metric comparison that forgets to require equal prefix
   --  lengths all stop proving here -- and each of those is a silent
   --  wrong-interface bug in the field rather than a crash.
   procedure Select_Route
     (T        : Route_Table;
      Eligible : Eligibility;
      N        : Route_Total;
      Iface    : out Interface_Id;
      Found    : out Boolean;
      Pick     : out Route_Total)
   with Post =>
     --  something is found exactly when something was eligible ...
     Found = (for some I in 1 .. N => Eligible (I))
     and then (if not Found then Pick = 0)
     and then (if Found then
                 --  ... the winner is itself eligible ...
                 Pick in 1 .. N
                 and then Eligible (Pick)
                 and then Iface = T (Pick).Iface
                 --  ... and no eligible route outranks it.
                 and then (for all J in 1 .. N =>
                             (if Eligible (J) then not Outranks (T, J, Pick))));

end Net_Routes;
