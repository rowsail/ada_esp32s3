# BSP support for Xtensa / ESP32-S3 (dual-core SMP, windowed ABI)
#
# SKELETON board definition for the native Ada (Jorvik) RTS.  The CPU layer
# (context switch, Context_Buffer) is currently stubbed -- see
# src/s-bbcppr__xtensa.adb.  ESP-IDF performs boot/clock/flash bring-up, so
# this board is generated with --no-startup (no crt0 / linker script here).
from support.bsp_sources.archsupport import ArchSupport
from support.bsp_sources.target import DFBBTarget


class XtensaArch(ArchSupport):
    @property
    def name(self):
        return "xtensa"

    def __init__(self):
        super(XtensaArch, self).__init__()
        self.add_gnarl_sources(
            # Arch-independent CPU_Primitives interface (shared "new" model)
            "src/s-bbcppr__new.ads",
            # Xtensa windowed context switch + Context_Buffer
            "src/s-bbcppr__xtensa.adb",
            "src/s-bbcpsp__xtensa.ads",
            # The windowed register switch + thread trampoline (assembly)
            "xtensa/context_switch.S",
        )


class Esp32s3(DFBBTarget):
    @property
    def parent(self):
        return XtensaArch

    def __init__(self, smp=True):
        self.smp = smp
        super(Esp32s3, self).__init__()
        self.add_gnat_sources(
            # Machine reset via ESP-IDF esp_restart (does not export _exit/abort,
            # so no clash with newlib).
            "src/s-macres__esp32s3.adb",
            # Console: Ada.Text_IO -> built-in USB-serial-JTAG (devkit /dev/ttyACM).
            "src/s-textio__esp32s3.adb",
        )
        self.add_gnarl_sources(
            "src/s-bbpara__esp32s3.ads",
            # Board_Support body against the common timer32 spec (SKELETON)
            "src/s-bbbosu__esp32s3.adb",
            # Ada.Interrupts.Names: named CPU interrupts for pragma Attach_Handler
            "src/a-intnam__esp32s3.ads",
        )

    @property
    def name(self):
        return "esp32s3"

    @property
    def target(self):
        return "xtensa-esp32-elf"

    @property
    def has_single_precision_fpu(self):
        # ESP32-S3 has a single-precision FPU, but the runtime is soft-float
        # for now; coprocessor/FPU state will be saved lazily (CPENABLE).
        return False

    @property
    def has_double_precision_fpu(self):
        return False

    @property
    def system_ads(self):
        # Dual-core SMP: the Light (no-tasking) profile is dropped, as for
        # Leon3 SMP.  Both Jorvik tasking runtimes are offered:
        #   light-tasking : No_Exception_Propagation + No_Finalization (small)
        #   embedded      : full exception propagation + finalization (ZCX)
        return {
            "light-tasking": "system-xi-xtensa-light-tasking.ads",
            "embedded": "system-xi-xtensa-embedded.ads",
        }

    @property
    def compiler_switches(self):
        # -mlongcalls is the usual requirement for ESP32 code generation.
        return ("-mlongcalls",)
