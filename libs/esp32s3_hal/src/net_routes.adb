with Interfaces; use Interfaces;

package body Net_Routes is

   --  Pack a dotted address into a 32-bit value for masking/compare.
   function U32 (A : Net_Devices.IPv4_Address) return Unsigned_32
   is (Shift_Left (Unsigned_32 (A (0)), 24)
       or Shift_Left (Unsigned_32 (A (1)), 16)
       or Shift_Left (Unsigned_32 (A (2)), 8)
       or Unsigned_32 (A (3)));

   --  Prefix length = number of set bits in the mask (works for any mask, /0..32).
   function Prefix_Len (Mask : Unsigned_32) return Natural is
      V : Unsigned_32 := Mask;
      N : Natural := 0;
   begin
      while V /= 0 loop
         N := N + Natural (V and 1);
         V := Shift_Right (V, 1);
      end loop;
      return N;
   end Prefix_Len;

   type Route is record
      Dest, Mask : Unsigned_32 := 0;
      Iface      : Interface_Id := 0;
      Metric     : Natural := 0;
      Valid      : Boolean := False;
   end record;

   Max_Routes : constant := 16;
   Table      : array (1 .. Max_Routes) of Route;
   N_Routes   : Natural := 0;
   Up         : Up_Query := null;

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
           (Dest   => U32 (Dest),
            Mask   => U32 (Mask),
            Iface  => Iface,
            Metric => Metric,
            Valid  => True);
      end if;
   end Add_Route;

   procedure Set_Default (Iface : Interface_Id; Metric : Natural := 100) is
   begin
      Add_Route ((0, 0, 0, 0), (0, 0, 0, 0), Iface, Metric);
   end Set_Default;

   procedure Resolve
     (Dest : Net_Devices.IPv4_Address; Iface : out Interface_Id; Found : out Boolean)
   is
      D           : constant Unsigned_32 := U32 (Dest);
      Best_Len    : Integer := -1;          --  so the first match always wins
      Best_Metric : Natural := 0;
   begin
      Found := False;
      Iface := 0;
      for I in 1 .. N_Routes loop
         declare
            R : Route renames Table (I);
         begin
            if R.Valid
              and then (D and R.Mask) = (R.Dest and R.Mask)        --  matches
              and then (Up = null or else Up (R.Iface))            --  interface up
            then
               declare
                  Len : constant Natural := Prefix_Len (R.Mask);
               begin
                  if Len > Best_Len or else (Len = Best_Len and then R.Metric < Best_Metric) then
                     Best_Len := Len;
                     Best_Metric := R.Metric;
                     Iface := R.Iface;
                     Found := True;
                  end if;
               end;
            end if;
         end;
      end loop;
   end Resolve;

end Net_Routes;
