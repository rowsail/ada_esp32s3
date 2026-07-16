--  Octal-PSRAM bring-up, pure Ada (ZFP style, no runtime).  Replaces the former
--  from-source C shim (psram_boot.c / psram_impl_src.c / mspi_timing_src.c):
--  configures the octal MSPI pins/clocks, programs the PSRAM mode registers over
--  the ROM OPI helper, maps the chip into the cache MMU, and does a real 80 MHz
--  data-in (din) sampling calibration.  Only ROM functions remain external.
--
--  Bringup exports the C symbol "psram_bringup", so the existing boot_main import
--  resolves to it unchanged.  See PSRAM_BRINGUP_RESEARCH.md for the register
--  provenance (captured live over JTAG) and why the din tune runs at 80 MHz.
package Boot_Psram is
   procedure Bringup
     with Export, Convention => C, External_Name => "psram_bringup";
end Boot_Psram;
