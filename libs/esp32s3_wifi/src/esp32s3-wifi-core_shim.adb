with Interfaces; use Interfaces;
with System;

package body ESP32S3.WiFi.Core_Shim is

   --  Log-verbosity globals the blobs read through wifi_log (default 0 = quiet,
   --  matching the blob's zero-initialised BSS).  g_log_mod is a 24-byte table.
   G_Log_Level : Unsigned_32 := 0
     with Export, Convention => C, External_Name => "g_log_level";
   G_Log_Mod   : array (0 .. 5) of Unsigned_32 := (others => 0)
     with Export, Convention => C, External_Name => "g_log_mod";

   --  The misc-NVS state object.  The blobs read *g_misc_nvs and index fields
   --  (cnx_sta_associated: [+4] with a beqz-null guard, [+8]; misc_nvs_load/
   --  deinit: [+36], [+56..]).  The real misc_nvs_init allocates this and leaves
   --  it EMPTY (zeroed) under our NVS-disabled operation -- the blobs then take
   --  their "no data" branches.  We back it with a static zeroed struct so
   --  g_misc_nvs is a valid, non-null pointer at startup (a null pointer faults
   --  cnx_sta_associated at [null+4]).  128 bytes covers every field the blobs
   --  touch (max +116).
   Misc_Nvs_Store : aliased array (0 .. 127) of Unsigned_8 := (others => 0)
     with Alignment => 4;
   G_Misc_Nvs : System.Address := System.Null_Address
     with Export, Convention => C, External_Name => "g_misc_nvs";

   --  misc NVS is disabled on this port: report "no data" and touch nothing.
   --  (The blob originals reached flash via the OS-adapter NVS slots, which Halt
   --  on our port -- so these were never allowed to land data anyway.)
   function Misc_Nvs_Load (Flag : Unsigned_8) return Integer_32
     with Export, Convention => C, External_Name => "misc_nvs_load";
   function Misc_Nvs_Load (Flag : Unsigned_8) return Integer_32 is
      pragma Unreferenced (Flag);
   begin
      return 0;
   end Misc_Nvs_Load;

   function Misc_Nvs_Init return Integer_32
     with Export, Convention => C, External_Name => "misc_nvs_init";
   function Misc_Nvs_Init return Integer_32 is
   begin
      return 0;
   end Misc_Nvs_Init;

   function Misc_Nvs_Restore return Integer_32
     with Export, Convention => C, External_Name => "misc_nvs_restore";
   function Misc_Nvs_Restore return Integer_32 is
   begin
      return 0;
   end Misc_Nvs_Restore;

   procedure Misc_Nvs_Deinit
     with Export, Convention => C, External_Name => "misc_nvs_deinit";
   procedure Misc_Nvs_Deinit is
   begin
      null;
   end Misc_Nvs_Deinit;

begin
   --  Point g_misc_nvs at the empty static struct before any blob reads it.
   G_Misc_Nvs := Misc_Nvs_Store'Address;
end ESP32S3.WiFi.Core_Shim;
