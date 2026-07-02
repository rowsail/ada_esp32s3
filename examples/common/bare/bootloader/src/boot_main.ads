--  Entry point of the IDF-free 2nd-stage bootloader's loader core, reached from
--  start.S as "boot_main".  Separate spec so the Export aspect is legal (GNAT
--  rejects a body-only Export on a library unit).

procedure Boot_Main
with Export => True, Convention => C, External_Name => "boot_main";
