with Interfaces; use Interfaces;

package body Net_Routes with SPARK_Mode => On is

   --  Pack a dotted address into a 32-bit value for masking/compare.
   function Pack (Addr : Net_Devices.IPv4_Address) return Unsigned_32
   is (Shift_Left (Unsigned_32 (Addr (0)), 24)
       or Shift_Left (Unsigned_32 (Addr (1)), 16)
       or Shift_Left (Unsigned_32 (Addr (2)), 8)
       or Unsigned_32 (Addr (3)));

   function Prefix_Len (Mask : Unsigned_32) return Natural is
      Count : Natural := 0;
   begin
      for Bit_Index in 0 .. 31 loop
         pragma Loop_Invariant (Count <= Bit_Index);
         if (Shift_Right (Mask, Bit_Index) and 1) = 1 then
            Count := Count + 1;
         end if;
      end loop;
      return Count;
   end Prefix_Len;

   Table    : Route_Table;
   N_Routes : Route_Total := 0;
   Up       : Up_Query := null;

   --  ---- proof model -------------------------------------------------------

   function Route_Count return Route_Total is (N_Routes);

   function Route_Covers (I : Route_Index; Dest : Net_Devices.IPv4_Address) return Boolean
   is (Covers (Table (I), Pack (Dest)));

   function Route_Iface (I : Route_Index) return Interface_Id
   is (Table (I).Iface);

   --  ---- table maintenance -------------------------------------------------

   procedure Configure (Is_Up : Up_Query) is
   begin
      Up := Is_Up;
   end Configure;

   procedure Clear is
   begin
      N_Routes := 0;
   end Clear;

   function Has_Routes return Boolean
   is (N_Routes > 0);

   procedure Add_Route
     (Dest, Mask : Net_Devices.IPv4_Address; Iface : Interface_Id; Metric : Natural := 100) is
   begin
      if N_Routes < Max_Routes then
         N_Routes := N_Routes + 1;
         Table (N_Routes) :=
           (Dest   => Pack (Dest),
            Mask   => Pack (Mask),
            Iface  => Iface,
            Metric => Metric);
      end if;
   end Add_Route;

   procedure Set_Default (Iface : Interface_Id; Metric : Natural := 100) is
   begin
      Add_Route ((0, 0, 0, 0), (0, 0, 0, 0), Iface, Metric);
   end Set_Default;

   ------------------
   -- Select_Route --
   ------------------

   procedure Select_Route
     (T        : Route_Table;
      Eligible : Eligibility;
      N        : Route_Total;
      Iface    : out Interface_Id;
      Found    : out Boolean;
      Pick     : out Route_Total)
   is
   begin
      Found := False;
      Iface := 0;
      Pick  := 0;
      for I in 1 .. N loop
         --  Everything the postcondition claims, restricted to the prefix of
         --  the table scanned so far.  The last conjunct is what turns "best
         --  of what I have seen" into "best of all of them" at loop exit.
         pragma Loop_Invariant (Found = (for some J in 1 .. I - 1 => Eligible (J)));
         pragma Loop_Invariant (if not Found then Pick = 0);
         pragma Loop_Invariant
           (if Found then
              Pick in 1 .. I - 1
              and then Eligible (Pick)
              and then Iface = T (Pick).Iface
              and then (for all J in 1 .. I - 1 =>
                          (if Eligible (J) then not Outranks (T, J, Pick))));
         --  The ranking rule is Outranks, and it is named ONCE -- there is no
         --  second copy here to drift from the one the postcondition is
         --  written against.  Nothing caches the incumbent's prefix length or
         --  metric either: Pick already identifies it, so the cache could only
         --  ever disagree with the table.
         if Eligible (I) and then (not Found or else Outranks (T, I, Pick)) then
            Iface := T (I).Iface;
            Pick  := I;
            Found := True;
         end if;
      end loop;
   end Select_Route;

   -------------
   -- Resolve --
   -------------

   procedure Resolve
     (Dest : Net_Devices.IPv4_Address; Iface : out Interface_Id; Found : out Boolean)
   is
      Dest_Bits : constant Unsigned_32 := Pack (Dest);
      Cand      : Eligibility := (others => False);
      Pick      : Route_Total;
   begin
      --  Sample the candidates once, then rank them.  Is_Up is still consulted
      --  only for routes whose prefix matches, exactly as before -- the `and
      --  then` keeps the callback off interfaces the destination cannot use.
      for I in 1 .. N_Routes loop
         Cand (I) := Covers (Table (I), Dest_Bits)
                     and then (Up = null or else Up (Table (I).Iface));
      end loop;

      Select_Route (Table, Cand, N_Routes, Iface, Found, Pick);

      --  Pick is the witness Resolve's own postcondition needs -- "the answer
      --  came from a route that covers Dest" is proved by pointing at one, and
      --  Pick is the one.  Naming it here says so; the assertion itself is
      --  free (it compiles away without -gnata).
      pragma Assert (if Found then Pick in 1 .. N_Routes and then Cand (Pick));
   end Resolve;

end Net_Routes;
