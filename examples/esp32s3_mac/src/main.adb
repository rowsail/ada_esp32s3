--  What it demonstrates
--  ---------------------
--  Reading the factory MAC address programmed into the ESP32-S3's eFuse, and the
--  per-interface MACs the chip derives from it (Espressif allocates each part a
--  block of four).  The Ethernet MAC (base + 3) is the natural choice to hand to a
--  W5500 -- see esp32s3_multinic, which now seeds its W5500s this way.
with Ada.Real_Time; use Ada.Real_Time;
with ESP32S3.Log;   use ESP32S3.Log;
with ESP32S3.MAC;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   package M renames ESP32S3.MAC;
begin
   delay until Clock + Milliseconds (200);
   Put_Line ("[mac] ESP32-S3 factory MAC addresses (from eFuse):");
   Put_Line ("[mac]   base / wifi-sta : " & M.Image (M.Wi_Fi_Station));
   Put_Line ("[mac]   wifi-softap     : " & M.Image (M.Wi_Fi_SoftAP));
   Put_Line ("[mac]   bluetooth       : " & M.Image (M.Bluetooth));
   Put_Line ("[mac]   ethernet (W5500): " & M.Image (M.Ethernet));
   Put_Line ("[mac]   2nd NIC (local) : " & M.Image (M.Local (M.Derived (4))));
   Put_Line ("[mac] done.");
   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
