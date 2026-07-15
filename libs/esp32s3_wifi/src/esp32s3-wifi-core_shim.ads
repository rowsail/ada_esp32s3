--  Ada replacement for the retired libcore.a.
--
--  libcore.a was a single 4.8 KB object (misc_nvs.o): Wi-Fi "misc NVS"
--  persistence -- a 60-byte calibration/config blob stored in the NVS flash
--  partition -- plus two log-verbosity globals.  It reaches flash only through
--  the OS-adapter NVS slots that WE provide, and our port runs with NVS disabled
--  (see ESP32S3.WiFi.Idf: Nvs_Enable = 0 -> calibrate fresh every boot;
--  St_Nvs_Open is a Halt stub).  So misc NVS is dormant: g_misc_nvs stays null
--  and no data is ever landed.  We import nothing from libcore.
--
--  This unit provides the exact 6 symbols the other three blobs reference (the
--  two log globals, g_misc_nvs, and the misc_nvs_* entries as no-NVS stubs), so
--  libcore.a can be dropped from the link entirely -- one fewer Espressif blob.
--  Measurement + rationale: research/wifi-re (libcore = 1 object, 8 symbols, 6
--  externally referenced).
private package ESP32S3.WiFi.Core_Shim is
   pragma Elaborate_Body;
end ESP32S3.WiFi.Core_Shim;
