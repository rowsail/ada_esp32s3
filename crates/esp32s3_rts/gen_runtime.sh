#!/bin/bash
# Generate + build a GNARL runtime (profile via ESP32S3_RTS_PROFILE: light-tasking/
# Jorvik, embedded, full) from the forked bb-runtimes esp32s3
# board.  Run as the crate's pre-build action:
#   - XTENSA_GNU_CONFIG is set by the xtensa_dynconfig dependency ([environment])
#     -- it selects the ESP32-S3 core config (little-endian, 64 aregs, FPU).
#   - the gnat_xtensa_esp32_elf toolchain + gprbuild are on PATH (Alire).
# Idempotent: regenerates only when the output is missing.
#
# Profile (ESP32S3_RTS_PROFILE), default "light-tasking":
#   light-tasking : No_Exception_Propagation + No_Finalization (small; the default)
#   embedded      : full exception propagation + finalization (ZCX).  WIP -- needs
#                   .eh_frame kept by the final link to actually unwind on target.
# Keep this in sync with the crate GPR's Runtime_Path (same external variable).
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
BBRT="$HERE/../bb-runtimes"
PROFILE="${ESP32S3_RTS_PROFILE:-light-tasking}"
RTS="$HERE/$PROFILE-esp32s3"
PACK="$HERE/packs/$PROFILE-esp32s3.tar.zst"
AR=xtensa-esp32-elf-ar

# Fast path (no bb-runtimes, no network): unpack the committed runtime SOURCE
# pack if the runtime dir is missing.  It is compiled below on the first build
# (then cached), so it is toolchain-version-independent.  bb-runtimes is only
# needed to *regenerate* the source pack (rare; after a runtime-source change).
if [ ! -d "$RTS" ] && [ -f "$PACK" ]; then
    echo "[esp32s3_rts] unpacking $PROFILE runtime source (compiles on first build)"
    mkdir -p "$RTS" && tar --zstd -xf "$PACK" -C "$RTS"
fi
if [ ! -d "$RTS" ] && [ ! -f "$BBRT/build_rts.py" ]; then
    echo "[esp32s3_rts] ERROR: no source pack ($PACK) and bb-runtimes is absent." >&2
    echo "    Restore crates/bb-runtimes to regenerate the runtime source." >&2
    exit 1
fi

if [ -z "$XTENSA_GNU_CONFIG" ]; then
    echo "[esp32s3_rts] ERROR: XTENSA_GNU_CONFIG unset; depend on xtensa_dynconfig" >&2
    exit 1
fi
echo "[esp32s3_rts] profile=$PROFILE  XTENSA_GNU_CONFIG=$XTENSA_GNU_CONFIG"

# 1. Generate the runtime source tree from the bb-runtimes esp32s3 board.
#    build_rts.py emits a dir per profile the board declares (light-tasking +
#    embedded); we then build the selected one.
if [ ! -d "$RTS" ]; then
    if [ "$PROFILE" = "full" ]; then
        # "full" is NOT a bb-runtimes board profile; synthesize it locally by
        # cloning the generated embedded source tree and overlaying our own
        # sources (a de-restricted system.ads + extra GNARL units from
        # full_overlay/).  bb-runtimes is left untouched.
        if [ ! -d "$HERE/embedded-esp32s3" ]; then
            echo "[esp32s3_rts] generating base runtime from bb-runtimes esp32s3..."
            ( cd "$BBRT" && python3 build_rts.py -f -o "$HERE" \
                --rts-src-descriptor=gnat_rts_sources/lib/gnat/rts-sources.json esp32s3 )
        fi
        echo "[esp32s3_rts] synthesizing 'full' from embedded + full_overlay/..."
        cp -a "$HERE/embedded-esp32s3" "$RTS"
        rm -rf "$RTS/obj" "$RTS/adalib"; mkdir -p "$RTS/obj" "$RTS/adalib"

        # Import the portable full-tasking GNARL units from the version-matched
        # host GNAT (gnat_native -- same GCC as the cross-compiler).  These are
        # not committed (same policy as the rest of the generated runtime).
        # Toolchain search root: set by tools/sdk-env.sh (default = Alire's dir).
        NATIVE_ADAINC=$(ls -d "${ESP32S3_ADA_TOOLCHAINS:-$HOME/.local/share/alire/toolchains}"/gnat_native_*/lib/gcc/*/[0-9]*/adainclude 2>/dev/null | sort -V | tail -1)
        if [ ! -d "$NATIVE_ADAINC" ]; then
            echo "[esp32s3_rts] ERROR: full profile needs native GNAT (gnat_native) for the full GNARL sources." >&2
            exit 1
        fi
        while read -r u; do
            case "$u" in ''|\#*) continue;; esac
            for ext in ads adb; do
                [ -f "$NATIVE_ADAINC/$u.$ext" ] && install -m644 "$NATIVE_ADAINC/$u.$ext" "$RTS/gnarl/"
            done
        done < "$HERE/full_overlay/donor_units.txt"
        rm -f "$RTS"/gnarl/s-tarest.*    # restricted stages: unused in full tasking

        # Overlay OUR sources last so the GNULL shims + system.ads override any
        # same-named donor unit (e.g. our bareboard s-intman beats the host one).
        cp -a "$HERE/full_overlay/gnat/." "$RTS/gnat/"
        [ -n "$(ls -A "$HERE/full_overlay/gnarl" 2>/dev/null)" ] \
            && cp -a "$HERE/full_overlay/gnarl/." "$RTS/gnarl/"
        chmod -R u+w "$RTS/gnarl" "$RTS/gnat"

        # A unit may not belong to two source dirs: where a donor unit (gnarl/)
        # shadows a bareboard one in gnat/, keep the gnarl/ (full-tasking) copy.
        comm -12 \
          <(ls "$RTS"/gnat/*.ad? 2>/dev/null | xargs -n1 basename | sort -u) \
          <(ls "$RTS"/gnarl/*.ad? 2>/dev/null | xargs -n1 basename | sort -u) \
          | while read -r f; do rm -f "$RTS/gnat/$f"; done

        # Imported donor units are -gnatg-clean on the host but trip a couple of
        # benign warnings (e.g. "loop range is null") on this target's config;
        # don't let -gnatg escalate those to errors for the full runtime build.
        sed -i 's/use Target_Options.GNARL_ADAFLAGS;/use Target_Options.GNARL_ADAFLAGS \& ("-gnatwn");/' \
            "$RTS/ravenscar_build.gpr" 2>/dev/null || true

        # The donor System.Soft_Links.Destroy_TSD calls Secondary_Stack.SS_Free
        # to reclaim a task's secondary stack on termination.  The bareboard
        # s-secsta (a) lacks SS_Free and (b) assigns each default-sized task
        # secondary stack from a MONOTONIC binder pool (-Q n) that is never
        # reclaimed -- so a program creating many tasks over its lifetime
        # exhausts the pool (STORAGE_ERROR), which capped on-target ACATS runs.
        # Patch the full profile to HEAP-manage task secondary stacks: SS_Init
        # allocates each from the heap, SS_Free reclaims it.  Build the full RTS
        # with -Q0 (no binder pool) so every secondary stack is heap-managed.
        patch -p1 -d "$RTS" \
            < "$HERE/full_overlay/patches/01-s-secsta-heap-secondary-stacks.patch"
        echo "[gen_runtime] s-secsta heap secondary stacks: applied"

        # s-interr: the full profile lifts the Ravenscar interrupt restrictions,
        # so the compiler lowers pragma Attach_Handler to the full dynamic
        # machinery (Register_Interrupt_Handler / Static_Interrupt_Protection /
        # Install_Handlers), which the restricted bareboard s-interr does not
        # provide.  full_overlay/gnarl/s-interr.{ads,adb} (copied above) is a
        # bareboard re-implementation of that full surface on top of
        # System.OS_Interface.Attach_Handler, so no in-place patching is needed.

        # The bareboard sets Max_Attribute_Count = 0 (no task attributes); the
        # full runtime supports Ada.Task_Attributes, so allow a small pool.
        sed -i 's/Max_Attribute_Count : constant := 0;/Max_Attribute_Count : constant := 16;/' \
            "$RTS/gnat/s-parame.ads" 2>/dev/null || true

        # The bareboard inherits No_Abort = True from Ravenscar/Jorvik, which
        # compiles OUT the entire abort machinery in s-tasini: the real
        # Abort_Defer/Undefer soft links are never installed (Init_RTS guards
        # them with `if not No_Abort`), and Defer/Undefer_Abort + Do_Pending_-
        # Action short-circuit to no-ops. With No_Abort = True an `abort` is
        # silently dropped (Abort_Signal is never raised). Flip it so `abort`,
        # asynchronous `select`, and select-with-terminate are actually
        # delivered at abort-completion points. (Verified on HW: enabling it
        # makes `abort` of a delaying task work cleanly and does NOT regress
        # M1-M4. See full_overlay/README.md.)
        sed -i 's/No_Abort : constant Boolean := True;/No_Abort : constant Boolean := False;/' \
            "$RTS/gnat/s-parame.ads" 2>/dev/null || true

        # ACATS heap headroom.  The bare full heap is leftover INTERNAL DRAM
        # (~258 KB) and task primary stacks come from it.  Tests that create many
        # concurrent tasks (CXD4006, C433A0x, C953xxx) overran it at the 20 KB
        # default -> OOM -> swept.  Primary stacks MUST stay in internal DRAM (the
        # level-5 context-switch ISR can't safely touch cached PSRAM), so trim the
        # default to 12 KB to fit ~2x more concurrent stacks.  The DBREAK stack-
        # overflow watchpoint (s-taprop Enter_Task) precisely catches any task that
        # genuinely needs more, so this is safe to validate by a full sweep.
        sed -i 's/Default_Stack_Size : constant Size_Type := 20 \* 1024;/Default_Stack_Size : constant Size_Type := 12 * 1024;/' \
            "$RTS/gnat/s-parame.ads" 2>/dev/null || true

        # ESP32-S3 trampoline fix.  A task body that CAPTURES its enclosing
        # subprogram's frame (a sibling task it calls, a locally-declared
        # controlled type, ...) is a nested function, so GNAT stores a GCC
        # TRAMPOLINE in Self_ID.Common.Task_Entry_Point.  The trampoline is built
        # on the stack = internal SRAM1, *DRAM* view (0x3FC8_8000..0x3FCF_0000),
        # which is NOT on the instruction bus -- so Task_Wrapper's indirect
        # `callx8 Task_Entry_Point` faults (InstructionFetchError).  SRAM1 is
        # dual-mapped: its IRAM view is at +0x6F_0000 (SOC_DIRAM_IRAM_LOW -
        # SOC_DIRAM_DRAM_LOW).  Re-point Task_Entry_Point at the IRAM alias when
        # it lands in that DRAM window, so the call fetches executable bytes.
        # (Root-caused by JTAG single-step; see full_overlay/README.md.)
        patch -p1 -d "$RTS" \
            < "$HERE/full_overlay/patches/02-s-taskin-trampoline-iram-alias.patch"
        echo "[gen_runtime] s-taskin trampoline fix: applied"

        # Ada.Real_Time.Clock must return the raw hardware TICK count.  The donor
        # body returns Time (Monotonic_Clock), but this port's Monotonic_Clock
        # returns Duration *seconds* while Ada.Real_Time.Time is a 64-bit *tick*
        # count (type Time is new System.BB.Time.Time, mod 2**64).  Converting
        # Duration->Time truncates the VALUE, so e.g. 18.4 s becomes 18 ticks
        # (~75 ns ~= 0): Clock is frozen near zero, every delay deadline
        # (Clock + D) lands in the BB clock's past, and Delay_Until returns
        # immediately -- a plain relative `delay` never blocks (ACATS C97307A:
        # the acceptor's `delay 15.0` is a no-op, so it serves the timed entry
        # calls before their timeouts can cancel them).  Read the BB tick clock
        # directly; the conversion is value-preserving since Time IS new
        # System.BB.Time.Time.  (Verified on HW: a task's `delay 3.0` measured
        # 0 ms before this fix, ~3000 ms after.)
        sed -i \
          -e 's/with System.Task_Primitives.Operations;/with System.Task_Primitives.Operations;\nwith System.BB.Time;/' \
          -e 's/return Time (System.Task_Primitives.Operations.Monotonic_Clock);/return Time (System.BB.Time.Clock);/' \
          "$RTS/gnarl/a-reatim.adb" 2>/dev/null || true
        grep -q 'return Time (System.BB.Time.Clock);' "$RTS/gnarl/a-reatim.adb" \
          && echo "[gen_runtime] a-reatim Clock -> raw BB ticks: applied"

        # Ada.Real_Time.To_Time_Span of a NONZERO Duration must not underflow to
        # a ZERO Time_Span.  This port's clock tick (Time_Unit = 1/240 MHz ~=
        # 4.17 ns) is COARSER than Duration'Small (1 ns), so the donor's
        # Mul_Div (To_Integer (D), Ticks_Per_Second, Duration_Units) rounds any
        # sub-tick Duration to 0.  Returning 0 for nonzero D breaks code that
        # scales up from the smallest Duration -- ACATS CXD8002 does
        #   Delay_Amount := To_Time_Span (Duration'Small);  -- 0 here!
        #   loop ... exit when ...; Delay_Amount := Delay_Amount * 2; end loop;
        # so 0*2 stays 0 forever -> infinite loop (the CXD8002 "livelock").
        # Round a nonzero D away from zero to the smallest representable
        # Time_Span (1 tick) so the scale-up terminates.
        patch -p1 -d "$RTS" \
            < "$HERE/full_overlay/patches/03-a-reatim-to-time-span.patch"
        echo "[gen_runtime] a-reatim To_Time_Span nonzero->>=1 tick: applied"

        # Priority_Queuing entry-queue REORDER on a dynamic priority change must
        # use the caller's BASE priority, not STPO.Get_Priority (Self).  This
        # port's Get_Priority returns the raw BB scheduler priority, which is
        # transiently boosted to the server-lock CEILING inside
        # Poll_Base_Priority_Change_At_Entry_Call (it runs holding Lock_Server).
        # So Requeue_Call_With_New_Prio re-inserted the call at the ceiling -> the
        # re-prioritised caller jumped to the HEAD of the whole queue instead of
        # behind its same-priority peers (ACATS CXD4006/CXD4009).  Standard GNARL
        # Get_Priority returns the logical *active* priority (== base for a queued
        # caller, no inheritance while blocked); we can't make this port's
        # Get_Priority do that without breaking nested-lock save/restore (which
        # needs the real OS priority), so use Common.Base_Priority here -- the
        # value Ada.Dynamic_Priorities.Set_Priority just wrote.
        sed -i \
          's/(Entry_Call, STPO.Get_Priority (Self_ID));/(Entry_Call, Self_ID.Common.Base_Priority);/' \
          "$RTS/gnarl/s-taenca.adb" 2>/dev/null || true
        grep -q '(Entry_Call, Self_ID.Common.Base_Priority);' "$RTS/gnarl/s-taenca.adb" \
          && echo "[gen_runtime] s-taenca requeue prio -> Base_Priority: applied"

        # Ada.Dynamic_Priorities.Set_Priority on SELF must actually change the
        # task's active priority.  a-dynpri calls STPO.Set_Priority (Self) while
        # holding Self's ATCB Write_Lock, but this port's Unlock_Generic restores
        # the priority saved at lock-acquire time -- clobbering the change -- so
        # the new priority was silently lost (e.g. it never reached the task's
        # subsequent entry calls: ACATS CXD4009, two-phase priority reordering).
        # Re-apply the new base priority AFTER the unlock, in the self +
        # Yield_Needed case (where the change is meant to take effect at once;
        # the rendezvous-lowering case keeps Yield_Needed False and is skipped).
        patch -p1 -d "$RTS" \
            < "$HERE/full_overlay/patches/04-a-dynpri-reapply-priority.patch"
        echo "[gen_runtime] a-dynpri re-apply prio after unlock: applied"

        # ARM D.2.3 (FIFO_Within_Priorities): setting a task's BASE priority via
        # Ada.Dynamic_Priorities.Set_Priority must move it to the TAIL of the
        # ready queue for its active priority -- even when the numeric value is
        # unchanged -- so it trails its same-priority peers.  The BB scheduler's
        # Change_Priority always re-inserts at the HEAD (correct only for the
        # Ravenscar "priority lowered by loss of inheritance" case) and early-
        # returns when the priority is unchanged, so a base set was a no-op
        # (ACATS CXD2001: Prime_Task kept running instead of yielding to its
        # Sub_Tasks).  Fix: expose a kernel-protected Yield (tail-move, already
        # implemented by Queues.Yield) and call it from STPO.Set_Priority on a
        # base set (Loss_Of_Inheritance = False); the rendezvous-restore path
        # (s-taenca, Loss_Of_Inheritance => True) keeps the head placement.
        patch -p1 -d "$RTS" \
            < "$HERE/full_overlay/patches/05-priority-d23-fifo.patch"
        echo "[gen_runtime] D.2.3 priority (CXD2001/CXD2003/CXD4005/CXD4009): applied"

        # Rendezvous priority INHERITANCE (Boost_Priority) must use the caller's
        # BASE priority, not Get_Priority (the raw BB active priority).  This port
        # transiently boosts active to an internal lock CEILING (Any_Priority'Last
        # = 255) while a task holds an RTS/ATCB lock -- and the caller holds one
        # here (entry-call setup).  Inheriting that 255 makes the acceptor run its
        # accept body at 255, so a protected-object call in the body spuriously
        # violates the object ceiling (Program_Error, propagated through the
        # rendezvous): ACATS C954017 / C954A01 / C954A03 / C974004.
        # Common.Base_Priority is the caller's real priority (kept current by
        # Ada.Dynamic_Priorities) -- the value the acceptor should inherit.  Same
        # Base_Priority-not-Get_Priority pattern as the entry-queuing sites.
        # (Inert without the cross-task Set_Priority patch above.)
        sed -i \
          -e 's/Caller_Prio   : constant System.Any_Priority := Get_Priority (Caller);/Caller_Prio   : constant System.Any_Priority := Caller.Common.Base_Priority;/' \
          -e 's/Acceptor_Prio : constant System.Any_Priority := Get_Priority (Acceptor);/Acceptor_Prio : constant System.Any_Priority := Acceptor.Common.Base_Priority;/' \
          "$RTS/gnarl/s-tasren.adb" 2>/dev/null || true
        grep -q 'Caller_Prio   : constant System.Any_Priority := Caller.Common.Base_Priority;' "$RTS/gnarl/s-tasren.adb" \
          && echo "[gen_runtime] Boost_Priority inherit BASE not active (C954017/C954A0x): applied"

        # Priority_Queuing INITIAL entry-call queuing priority must be the
        # caller's BASE priority, not STPO.Get_Priority (Self) -- which in this
        # port returns the raw BB active priority, transiently BOOSTED to the PO
        # ceiling while the caller holds the server lock during the enqueue.  So
        # callers were queued at the CEILING; a later base-priority change that
        # requeues a blocked caller at its (lower) base could never overtake them
        # (ACATS CXD4005).  This is the same fix already applied to the REQUEUE
        # site (s-taenca, CXD4006) -- here for the FIRST enqueue (s-tpobop).  Inert
        # under FIFO_Queuing (the Prio field is ignored), so the shared runner
        # (default policy) is unaffected.
        sed -i \
          -e 's/Entry_Call.Prio := STPO.Get_Priority (Self_ID);/Entry_Call.Prio := Self_ID.Common.Base_Priority;/' \
          -e 's/Entry_Call.Prio := STPO.Get_Priority (Self_Id);/Entry_Call.Prio := Self_Id.Common.Base_Priority;/' \
          "$RTS/gnarl/s-tpobop.adb" 2>/dev/null || true
        grep -q 'Entry_Call.Prio := Self_I[dD].Common.Base_Priority;' "$RTS/gnarl/s-tpobop.adb" \
          && echo "[gen_runtime] s-tpobop initial entry-call prio -> Base_Priority (CXD4005): applied"

    else
        echo "[esp32s3_rts] generating runtime from bb-runtimes esp32s3..."
        ( cd "$BBRT" && python3 build_rts.py -f -o "$HERE" \
            --rts-src-descriptor=gnat_rts_sources/lib/gnat/rts-sources.json esp32s3 )
    fi
fi

# The embedded/full runtimes pull libc/libgcc (exceptions -> the DWARF unwinder).
# The Alire xtensa toolchain's libc/libgcc are big-endian (base Xtensa config);
# our target is little-endian.  We link into an ESP-IDF image whose final link
# provides the little-endian newlib + libgcc + _Unwind_*, so drop -lc/-lgcc from
# the runtime link group and let IDF resolve them at the final link.  Run this on
# EVERY build (not just first generation): the cache is gitignored and a stale
# one generated before this drop existed would otherwise keep linking the
# big-endian libc.a.  Idempotent -- a no-op once the group is already dropped.
if [ "$PROFILE" = "embedded" ] || [ "$PROFILE" = "full" ]; then
    sed -i 's/--start-group,-lgnarl,-lgnat,-lc,-lgcc,--end-group/--start-group,-lgnarl,-lgnat,--end-group/' \
        "$RTS/runtime.xml" 2>/dev/null || true
fi

# 1b. Ada.Calendar children (RM 9.6.1: Arithmetic / Formatting / Time_Zones /
#     Delays) + the J.1 obsolescent `Calendar` rename, from the shared
#     calendar_overlay/ (the full profile no longer carries them in full_overlay/).
#     EMBEDDED + FULL ONLY: those build the base Ada.Calendar parent and have real
#     exception propagation.  light-tasking is intentionally EXCLUDED -- bb-runtimes
#     omits Ada.Calendar from the Jorvik profile because No_Exception_Propagation
#     turns every Time_Error / Constraint_Error into a board reset, so Calendar is
#     unusable (and grades nothing) there.  Don't fight that design.
if [ "$PROFILE" = "embedded" ] || [ "$PROFILE" = "full" ]; then
    cp -a "$HERE/calendar_overlay/gnat/."  "$RTS/gnat/"
    cp -a "$HERE/calendar_overlay/gnarl/." "$RTS/gnarl/"
    chmod -R u+w "$RTS/gnat" "$RTS/gnarl"
    echo "[gen_runtime] Ada.Calendar children + J.1 rename: applied ($PROFILE)"
fi

# 2. Compile the runtime and archive into libgnat.a / libgnarl.a (bb-runtimes
#    cannot build a library project for xtensa-esp32-elf, so archive by hand).
if [ ! -f "$RTS/adalib/libgnat.a" ]; then
    echo "[esp32s3_rts] building runtime objects..."
    #  -cargs -g: DWARF for the runtime (GNARL/GNAT) too, so the debugger can find
    #  function bounds when a step-over passes through runtime code (without it,
    #  GDB's "next" fails with "cannot find bounds of current function"). Debug
    #  sections are non-allocated -> no effect on the flashed image. (The hand-
    #  written Xtensa asm vectors/context-switch still lack bounds -- inherent.)
    ( cd "$RTS" && gprbuild -c -P ravenscar_build.gpr -j0 -cargs -g )
    gnarl_units=$(ls "$RTS"/gnarl "$RTS"/gnarl_user 2>/dev/null | sed -n 's/\.ad[sb]$//p' | sort -u)
    gnarl_o=""; gnat_o=""
    for o in "$RTS"/obj/*.o; do
        b=$(basename "$o" .o)
        if grep -qx "$b" <<<"$gnarl_units"; then gnarl_o="$gnarl_o $o"; else gnat_o="$gnat_o $o"; fi
    done
    cp "$RTS"/obj/*.ali "$RTS"/adalib/
    $AR rc "$RTS"/adalib/libgnat.a  $gnat_o
    $AR rc "$RTS"/adalib/libgnarl.a $gnarl_o
fi
echo "[esp32s3_rts] runtime ready: $RTS"
