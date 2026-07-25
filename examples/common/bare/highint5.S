/* Native level-5 interrupt vector for the GNARL CCOMPARE2 tick (int16).
 *
 * Owns xt_highint5 (ESP-IDF's default is weak/empty; ESP-IDF uses level 4).
 * Saves the interrupted thread's full context to an XT_STK frame on its own
 * stack, calls __gnat_timer_interrupt (System.BB: alarm handler + context
 * switch if needed), then restores + RFE.  The interrupted thread is saved
 * "solicited" by Context_Switch (returning into __gnat_timer_interrupt); this
 * vector performs its final register restore + RFE when it is resumed.
 *
 * Validated in hwtest/dualframe/.  Reuses ESP-IDF's _xt_context_save/restore.
 */

#include <xtensa/coreasm.h>
#include <xtensa/corebits.h>
#include <xtensa/config/specreg.h>
#include "xtensa_context.h"

	.data
	.align	4
	.global	gnat_hi5_marker		/* referenced by glue.c to force-link this */
gnat_hi5_marker:
	.word	0

	.section .iram1, "ax"
	.align	4
	.global	xt_highint5
	.type	xt_highint5, @function
xt_highint5:
	/* CXD8002 ROOT FIX -- test the window-vector DEFER *before* dereferencing the
	   interruptee SP.  DEFER if we interrupted a window over/underflow handler:
	   EPC_5 in [VECBASE, VECBASE+0x180).  PS.EXCM masks only interrupts <=
	   XCHAL_EXCM_LEVEL (3 on LX7), so a level-5 tick CAN land mid-window-handler.
	   CRUCIAL: at such a point the interruptee's a1 (sp) is TRANSIENTLY STALE --
	   the handler has rotated the window but not yet reloaded a1 from the stack
	   (HW-probed at _WindowUnderflow8+0: a1 reads 0x1 while the real saved SP
	   [a9-12] is a VALID 0x3c06xxxx the handler was about to load).  The OLD
	   prologue built its XT_STK frame on that stale sp FIRST (`s32i a0,sp,
	   XT_STK_A1`) and DOUBLE-FAULTED before the defer could bail -- the long-
	   standing intermittent CXD8002 crash (PC 0x403826a6 / xt_highint5 prologue).
	   So: check EPC_5 with NO stack access.  a0 is free (the L5 vector saved the
	   interruptee a0 in EXCSAVE_5); stash a2 in EXCSAVE_4 (level 4 is unused on
	   this port) for a second scratch. */
	wsr	a2, EXCSAVE_4
	rsr	a0, EPC_5		/* interruptee PC */
	rsr	a2, VECBASE
	sub	a2, a0, a2		/* a2 = EPC_5 - VECBASE */
	movi	a0, 0x180
	bltu	a2, a0, .Lhi5_defer	/* in a window vector -> defer, never touch sp */

	/* Not a window vector: sp is valid.  Build the XT_STK frame as before. */
	rsr	a2, EXCSAVE_4		/* restore interruptee a2 */
	/* Mask debug (raise INTLEVEL to DEBUGLEVEL=6) across the XT_STK frame
	   build below.  The frame is built on the interruptee's stack and can cross
	   the per-task stack-overflow DBREAK watchpoint (a 64-byte StoreBreak in the
	   redzone) when a task is preempted close to its limit; that store is
	   legitimate kernel overhead, not the task overflowing, so it must not raise
	   a (debug-context) Storage_Error -- which double-faults.  a0 holds the dead
	   0x180 compare constant here; rsil overwrites it (old PS discarded -- PS is
	   set explicitly after the save).  The handler then runs BELOW the 64-byte
	   window so cannot re-trip.  Restored to INTLEVEL 5 after _xt_context_save. */
	rsil	a0, 6
	mov	a0, sp
	addi	sp, sp, -XT_STK_FRMSZ
	s32i	a0, sp, XT_STK_A1
	s32i	a2, sp, XT_STK_A2
	j	.Lhi5_normal		/* skip the defer block (J has the range) */

.Lhi5_defer:
	/* Push CCOMPARE2 ahead so the level-5 timer DE-ASSERTS (the CCOMPARE
	   interrupt stays asserted until CCOMPARE2 is rewritten), giving the window
	   handler uninterrupted time to finish (and reload the real a1).  Without
	   this the still-asserted tick re-fires every instruction -> LIVELOCK.  Then
	   rfi back WITHOUT touching the (transiently stale) sp; the deferred tick
	   re-fires at a safe point. */
	rsr.ccount a0
	movi	a2, 0x100
	add	a0, a0, a2
	wsr.ccompare2 a0
	rsync
	rsr	a2, EXCSAVE_4		/* restore interruptee a2 */
	rsr	a0, EXCSAVE_5		/* restore interruptee a0 */
	rfi	5			/* return to the window handler; let it finish */

.Lhi5_normal:
	l32i	a2, sp, XT_STK_A2	/* restore a2 so _xt_context_save saves it */
	rsr	a0, EPS_5		/* the interruptee's PS (not L5-entry PS) */
	s32i	a0, sp, XT_STK_PS
	rsr	a0, EPC_5
	s32i	a0, sp, XT_STK_PC
	rsr	a0, EXCSAVE_5
	s32i	a0, sp, XT_STK_A0
	s32i	a12, sp, XT_STK_A12
	s32i	a13, sp, XT_STK_A13
	call0	_xt_context_save

	movi	a0, PS_INTLEVEL(5) | PS_UM | PS_WOE
	wsr	a0, PS
	rsync

	call4	__gnat_timer_interrupt	/* alarm handler + context switch */

	/* Interrupt epilogue (Option A).  If a switch was deferred (Switch_Pending)
	   and this is the outermost native interrupt (In_Native_Int == 0), tail-jump
	   to __gnat_preempt_dispatch from this clean single-window context (a1 = sp =
	   our XT_STK frame; no return).  Else resume the interruptee normally. */
	/* Mask before touching In_Native_Int: the decrement (moved here from
	   __gnat_timer_interrupt) and the outermost-switch decision below MUST be
	   atomic against a higher native level.  The count stays >= 1 through the
	   whole dispatch body and drops only inside this masked window, so a
	   higher-priority interrupt firing during a lower vector's epilogue can never
	   see 0, mistake itself for the outermost, and preempt_dispatch out of that
	   vector's half-unwound frame (the L3-over-L2 window-corruption bug; see
	   s-bbbosu In_Native_Int invariant).  a2 = old PS (discarded; rfi restores). */
	rsil	a2, 15
	getcoreid a2
	movi	a3, __gnat_in_native_int
	addx4	a3, a2, a3
	l32i	a4, a3, 0
	addi	a4, a4, -1
	s32i	a4, a3, 0
	bnez	a4, .Lhi5_resume
	movi	a3, __gnat_switch_pending
	addx4	a3, a2, a3
	l32i	a4, a3, 0
	beqz	a4, .Lhi5_resume
	movi	a4, 0
	s32i	a4, a3, 0
	movi	a2, __gnat_preempt_dispatch
	jx	a2

.Lhi5_resume:
	/* Restore the interrupted thread's full context and return to its
	   interruption point.  MUST stay at INTLEVEL 5 until the FINAL atomic
	   return: a plain 'wsr.ps' here would lower INTLEVEL to the interruptee's
	   level *before* a0/a1 are reloaded and before the return, opening a ~5-insn
	   window in which a fresh level-5 tick preempts this half-restored thread
	   (a1 still = the interrupt frame, not the thread SP).  That re-entrant save
	   is what later detonates in _xt_context_save's SPILL (ACATS CXD8002).
	   'rfi 5' restores PS<-EPS_5 and PC<-EPC_5 atomically, so INTLEVEL stays 5
	   right up to the return -- no preemptible window. */
	call0	_xt_context_restore
	/* SMP FIX -- normalize WINDOWSTART = 1<<WINDOWBASE (single clean frame), the
	   SAME idiom the dispatch path .Lresume_int already uses (CXD8002 064c175).
	   _xt_context_save (called in the prologue) does a SPILL_ALL_WINDOWS, so ALL
	   the interruptee's caller frames are on its stack; it MUST resume with one
	   live window and reload the callers via window underflow as it returns.
	   Without this the resumed thread inherited a STALE multi-frame WINDOWSTART
	   left by __gnat_timer_interrupt's own call chain -> a later window overflow
	   spilled a stale frame (saved SP garbage) -> double-fault.  Surfaced at
	   cross-core (core-1) task activation under SMP delay load, in a deep call8
	   nest (Real_Time Mul_Div/Scaled_Divide on the `delay until` path).  a0 is
	   scratch (reloaded just below). */
	rsr.windowbase a0
	ssl	a0			/* SAR = 32 - WINDOWBASE */
	movi	a0, 1
	sll	a0, a0			/* a0 = 1 << WINDOWBASE */
	wsr.windowstart a0
	rsync
	/* SAR FIX (delay-strand root cause).  The `ssl a0` above set SAR to
	   32-WINDOWBASE, CLOBBERING the interruptee SAR that _xt_context_restore
	   had just restored.  Any interruptee preempted mid shift-based math --
	   notably 64-bit __divdi3 / System.Arith_64.Scaled_Divide / Mul_Div, which
	   shift by SAR -- then resumes with a wrong shift amount and SILENTLY TEARS
	   (plain __muldi3 uses no SAR, so it was immune; that asymmetry pinned it).
	   Reload the saved SAR.  a0 is scratch; sp is still the XT_STK frame. */
	l32i	a0, sp, XT_STK_SAR
	wsr.sar	a0
	l32i	a0, sp, XT_STK_PS
	wsr	a0, EPS_5
	l32i	a0, sp, XT_STK_PC
	wsr	a0, EPC_5
	l32i	a0, sp, XT_STK_A0
	l32i	sp, sp, XT_STK_A1
	rsync
	rfi	5
	.size	xt_highint5, . - xt_highint5

/* Native level-3 interrupt handler for device interrupts (Takeover S4).
 *
 * Reached from our VECBASE table's level-3 slot (vectors.S):
 *     wsr.excsave3 a0 ; call0 __gnat_level3_vector
 * Identical dual-frame structure to xt_highint5, but level 3 (EPS_3/EPC_3/
 * EXCSAVE_3, PS_INTLEVEL(3)).  The level-5 tick can preempt this handler;
 * GNARL's priority elevation in Interrupt_Wrapper defers any context switch to
 * the outermost interrupt, so this composes safely (the epilogue's rfe is the
 * standard task-resume, same as level 5). */
	.align	4
	.global	__gnat_level3_vector
	.type	__gnat_level3_vector, @function
__gnat_level3_vector:
	/* Mask debug across the XT_STK frame build (same rationale as xt_highint5):
	   the frame can cross the per-task stack-overflow DBREAK watchpoint when an
	   L3 device interrupt preempts a near-limit task -- legitimate kernel spill,
	   not a task overflow.  a0 is free here (the interruptee a0 was stashed in
	   EXCSAVE_3 by the vector slot); rsil overwrites it before `mov a0, sp`.
	   Restored to INTLEVEL 3 after _xt_context_save. */
	rsil	a0, 6
	mov	a0, sp
	addi	sp, sp, -XT_STK_FRMSZ
	s32i	a0, sp, XT_STK_A1
	rsr	a0, EPS_3		/* interruptee's PS */
	s32i	a0, sp, XT_STK_PS
	rsr	a0, EPC_3
	s32i	a0, sp, XT_STK_PC
	rsr	a0, EXCSAVE_3
	s32i	a0, sp, XT_STK_A0
	s32i	a12, sp, XT_STK_A12
	s32i	a13, sp, XT_STK_A13
	call0	_xt_context_save

	movi	a0, PS_INTLEVEL(3) | PS_UM | PS_WOE
	wsr	a0, PS
	rsync

	call4	__gnat_level3_dispatch	/* Interrupt_Wrapper + context switch */

	/* Same deferred-dispatch epilogue as xt_highint5 (Option A). */
	/* Mask + decrement here (moved from __gnat_level3_dispatch), atomic with the
	   outermost-switch decision -- see the .Lhi5 epilogue for the full rationale.
	   a2 = old PS (discarded; rfi restores). */
	rsil	a2, 15
	getcoreid a2
	movi	a3, __gnat_in_native_int
	addx4	a3, a2, a3
	l32i	a4, a3, 0
	addi	a4, a4, -1
	s32i	a4, a3, 0
	bnez	a4, .Llv3_resume
	movi	a3, __gnat_switch_pending
	addx4	a3, a2, a3
	l32i	a4, a3, 0
	beqz	a4, .Llv3_resume
	movi	a4, 0
	s32i	a4, a3, 0
	movi	a2, __gnat_preempt_dispatch
	jx	a2

.Llv3_resume:
	/* Atomic level-3 return (see .Lhi5_resume): a level-5 tick can preempt
	   level-3 code, so the same half-restored-thread race applies.  Stay at
	   INTLEVEL 3 until the atomic 'rfi 3' (PS<-EPS_3, PC<-EPC_3). */
	call0	_xt_context_restore
	rsr.windowbase a0		/* SMP FIX: WINDOWSTART = 1<<WINDOWBASE (see .Lhi5_resume) */
	ssl	a0
	movi	a0, 1
	sll	a0, a0
	wsr.windowstart a0
	rsync
	/* SAR FIX (see .Lhi5_resume): reload the interruptee SAR clobbered by the
	   `ssl` above, else preempted shift-based math (64-bit divide) tears. */
	l32i	a0, sp, XT_STK_SAR
	wsr.sar	a0
	l32i	a0, sp, XT_STK_PS
	wsr	a0, EPS_3
	l32i	a0, sp, XT_STK_PC
	wsr	a0, EPC_3
	l32i	a0, sp, XT_STK_A0
	l32i	sp, sp, XT_STK_A1
	rsync
	rfi	3
	.size	__gnat_level3_vector, . - __gnat_level3_vector

/* Native level-2 interrupt handler (CPU_INT 19/20/21).  Identical dual-frame
 * structure to __gnat_level3_vector, one level down (EPS_2/EPC_2/EXCSAVE_2,
 * PS_INTLEVEL(2), rfi 2).  Medium level (< EXCM=3): it can be preempted by
 * level 3/4/5, so it keeps the same WINDOWSTART/SAR-reload epilogue fixes. */
	.align	4
	.global	__gnat_level2_vector
	.type	__gnat_level2_vector, @function
__gnat_level2_vector:
	/* Mask debug across the XT_STK frame build (same rationale as xt_highint5):
	   the frame can cross the per-task stack-overflow DBREAK watchpoint when an
	   L2 device interrupt preempts a near-limit task.  a0 is free here (the
	   interruptee a0 was stashed in EXCSAVE_2 by the vector slot); rsil
	   overwrites it before `mov a0, sp`.  Restored to INTLEVEL 2 after the save. */
	rsil	a0, 6
	mov	a0, sp
	addi	sp, sp, -XT_STK_FRMSZ
	s32i	a0, sp, XT_STK_A1
	rsr	a0, EPS_2		/* interruptee's PS */
	s32i	a0, sp, XT_STK_PS
	rsr	a0, EPC_2
	s32i	a0, sp, XT_STK_PC
	rsr	a0, EXCSAVE_2
	s32i	a0, sp, XT_STK_A0
	s32i	a12, sp, XT_STK_A12
	s32i	a13, sp, XT_STK_A13
	call0	_xt_context_save

	movi	a0, PS_INTLEVEL(2) | PS_UM | PS_WOE
	wsr	a0, PS
	rsync

	call4	__gnat_level2_dispatch	/* Interrupt_Wrapper + context switch */

	/* Same deferred-dispatch epilogue as __gnat_level3_vector. */
	/* Mask + decrement here (moved from __gnat_level2_dispatch), atomic with the
	   outermost-switch decision -- see the .Lhi5 epilogue for the full rationale.
	   This is THE fix for the L3-refill-preempts-L2-TWAI freeze: L2 is the level
	   most often preempted by a higher device interrupt during its epilogue.
	   a2 = old PS (discarded; rfi restores). */
	rsil	a2, 15
	getcoreid a2
	movi	a3, __gnat_in_native_int
	addx4	a3, a2, a3
	l32i	a4, a3, 0
	addi	a4, a4, -1
	s32i	a4, a3, 0
	bnez	a4, .Llv2_resume
	movi	a3, __gnat_switch_pending
	addx4	a3, a2, a3
	l32i	a4, a3, 0
	beqz	a4, .Llv2_resume
	movi	a4, 0
	s32i	a4, a3, 0
	movi	a2, __gnat_preempt_dispatch
	jx	a2

.Llv2_resume:
	call0	_xt_context_restore
	rsr.windowbase a0		/* WINDOWSTART = 1<<WINDOWBASE (see .Lhi5_resume) */
	ssl	a0
	movi	a0, 1
	sll	a0, a0
	wsr.windowstart a0
	rsync
	l32i	a0, sp, XT_STK_SAR	/* reload interruptee SAR (clobbered by ssl) */
	wsr.sar	a0
	l32i	a0, sp, XT_STK_PS
	wsr	a0, EPS_2
	l32i	a0, sp, XT_STK_PC
	wsr	a0, EPC_2
	l32i	a0, sp, XT_STK_A0
	l32i	sp, sp, XT_STK_A1
	rsync
	rfi	2
	.size	__gnat_level2_vector, . - __gnat_level2_vector
