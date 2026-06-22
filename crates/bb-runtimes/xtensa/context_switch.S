/* ----------------------------------------------------------------------- *
 *                 GNAT RUN-TIME LIBRARY (GNARL) COMPONENTS                 *
 *                                                                          *
 *   Xtensa LX7 (ESP32-S3) windowed context switch and thread trampoline.   *
 *                                                                          *
 *   DUAL-FORMAT DISPATCH (Option A).  A thread is saved in one of two       *
 *   formats and resumed accordingly (cf. the FreeRTOS Xtensa port,          *
 *   reference/freertos-xtensa/):                                            *
 *     * SOLICITED (Frame_Kind = 0): a cooperative yield -- the live windows *
 *       are spilled to the thread's own stack, and it is resumed by a       *
 *       single 'retw' (window-underflow reloads the frame from the stack).  *
 *     * INTERRUPT (Frame_Kind = 1): the thread was preempted by a high-level *
 *       ISR; _xt_context_save wrote its FULL register state to an XT_STK     *
 *       frame, and it is resumed by _xt_context_restore + 'rfe'.            *
 *                                                                          *
 *   __gnat_context_switch saves the running thread SOLICITED (the           *
 *   cooperative Leave_Kernel path -- unchanged 213-PASS behaviour) and then *
 *   dispatches.  __gnat_preempt_dispatch records the running thread          *
 *   INTERRUPT and dispatches; it is tail-jumped from the ISR vector         *
 *   epilogue (highint5.S) and performs NO SPILL_ALL_WINDOWS.  Both paths     *
 *   share .Lresume, which resumes the next thread in its own format.        *
 *   WINDOWED ABI only.                                                      *
 * ----------------------------------------------------------------------- */

	.set	CTX_SP, 0	/* a1: stack pointer at the switch point  */
	.set	CTX_PS, 8	/* PS (processor state)                   */
	.set	CTX_A0, 12	/* a0: return address (call-size encoded) */
	.set	CTX_TPTR,   16	/* THREADPTR (thread-local storage base)  */
	.set	CTX_CP, 20	/* CP_State: ptr to the 72-byte FPU save  */
	.set	CTX_SAR,    24	/* SAR (shift amount register)            */
	.set	CTX_LBEG,   28	/* LBEG  \                                */
	.set	CTX_LEND,   32	/* LEND   > zero-overhead LOOP registers  */
	.set	CTX_LCOUNT, 36	/* LCOUNT/                                 */
	.set	CTX_KIND,   40	/* 0 = solicited, 1 = interrupt (Opt A)   */

	/* XT_STK interrupt-frame offsets (xtensa_context.h; MUST match highint5.S). */
	.set	XT_STK_PC,  4
	.set	XT_STK_PS,  8
	.set	XT_STK_A0,  12
	.set	XT_STK_A1,  16
	.set	XT_STK_SAR, 76

/* --------------------------------------------------------------------------
 * void __gnat_context_switch (Address running_slot, Address first_slot);
 *   a2 = &Running_Thread_Table (CPU); a3 = &First_Thread_Table (CPU)
 *   Cooperative: spill + save the running thread SOLICITED, then dispatch.
 * -------------------------------------------------------------------------- */
	.text
	.align	4
	.global	__gnat_context_switch
	.type	__gnat_context_switch, @function
__gnat_context_switch:
	entry	a1, 32

	/* SPILL_ALL_WINDOWS (hardcoded 64-areg form). a0-a3 survive. */
	and	a12, a12, a12
	rotw	3
	and	a12, a12, a12
	rotw	3
	and	a12, a12, a12
	rotw	3
	and	a12, a12, a12
	rotw	3
	and	a12, a12, a12
	rotw	4

	l32i	a4, a2, 0		/* a4 = running context buffer */
	s32i	a1, a4, CTX_SP
	s32i	a0, a4, CTX_A0
	rsr.ps	a5
	s32i	a5, a4, CTX_PS
	rsr.sar	a5
	s32i	a5, a4, CTX_SAR
	rsr	a5, LBEG
	s32i	a5, a4, CTX_LBEG
	rsr	a5, LEND
	s32i	a5, a4, CTX_LEND
	rsr	a5, LCOUNT
	s32i	a5, a4, CTX_LCOUNT
	movi	a5, 0
	s32i	a5, a4, CTX_KIND	/* solicited */
	rur.threadptr	a5		/* save THREADPTR (TLS base) */
	s32i	a5, a4, CTX_TPTR

	l32i	a8, a4, CTX_CP
	beqz	a8, .Lcs_nofp
	ssi	f0,  a8, 0
	ssi	f1,  a8, 4
	ssi	f2,  a8, 8
	ssi	f3,  a8, 12
	ssi	f4,  a8, 16
	ssi	f5,  a8, 20
	ssi	f6,  a8, 24
	ssi	f7,  a8, 28
	ssi	f8,  a8, 32
	ssi	f9,  a8, 36
	ssi	f10, a8, 40
	ssi	f11, a8, 44
	ssi	f12, a8, 48
	ssi	f13, a8, 52
	ssi	f14, a8, 56
	ssi	f15, a8, 60
	rur.fcr	a9
	s32i	a9, a8, 64
	rur.fsr	a9
	s32i	a9, a8, 68
.Lcs_nofp:
	j	.Lresume		/* a2 = &Running, a3 = &First */
	.size	__gnat_context_switch, . - __gnat_context_switch

/* --------------------------------------------------------------------------
 * __gnat_preempt_dispatch -- preemptive (interrupt-epilogue) dispatch.
 * Tail-jumped from the ISR vector epilogue (highint5.S), in the vector's
 * CLEAN SINGLE WINDOW (interruptee saved to XT_STK by _xt_context_save).
 * a1 = sp = that XT_STK frame.  NO spill here.  Record the interruptee
 * INTERRUPT, then share .Lresume.
 * -------------------------------------------------------------------------- */
	.align	4
	.global	__gnat_preempt_dispatch
	.type	__gnat_preempt_dispatch, @function
__gnat_preempt_dispatch:
	rsr.prid a6
	extui	a6, a6, 13, 1		/* a6 = core id (0/1) */
	movi	a2, __gnat_running_thread_table
	addx4	a2, a6, a2		/* a2 = &Running_Thread_Table (core) */
	movi	a3, first_thread_table
	addx4	a3, a6, a3		/* a3 = &First_Thread_Table (core)   */
	l32i	a4, a2, 0		/* a4 = interrupted context buffer   */
	s32i	a1, a4, CTX_SP		/* SP = its XT_STK frame             */
	movi	a5, 1
	s32i	a5, a4, CTX_KIND	/* interrupt */
	rur.threadptr	a5		/* save THREADPTR (TLS base) */
	s32i	a5, a4, CTX_TPTR

	l32i	a8, a4, CTX_CP
	beqz	a8, .Lpd_nofp
	ssi	f0,  a8, 0
	ssi	f1,  a8, 4
	ssi	f2,  a8, 8
	ssi	f3,  a8, 12
	ssi	f4,  a8, 16
	ssi	f5,  a8, 20
	ssi	f6,  a8, 24
	ssi	f7,  a8, 28
	ssi	f8,  a8, 32
	ssi	f9,  a8, 36
	ssi	f10, a8, 40
	ssi	f11, a8, 44
	ssi	f12, a8, 48
	ssi	f13, a8, 52
	ssi	f14, a8, 56
	ssi	f15, a8, 60
	rur.fcr	a9
	s32i	a9, a8, 64
	rur.fsr	a9
	s32i	a9, a8, 68
.Lpd_nofp:
	j	.Lresume		/* a2 = &Running, a3 = &First */
	.size	__gnat_preempt_dispatch, . - __gnat_preempt_dispatch

/* --------------------------------------------------------------------------
 * .Lresume -- make First the running thread and resume it in its own format.
 *   a2 = &Running_Thread_Table (CPU); a3 = &First_Thread_Table (CPU).
 * -------------------------------------------------------------------------- */
	.align	4
.Lresume:
	l32i	a7, a3, 0		/* a7 = next context buffer */
	s32i	a7, a2, 0		/* Running_Thread_Table (CPU) := next */

	l32i	a8, a7, CTX_CP
	beqz	a8, .Lresume_nofp
	lsi	f0,  a8, 0
	lsi	f1,  a8, 4
	lsi	f2,  a8, 8
	lsi	f3,  a8, 12
	lsi	f4,  a8, 16
	lsi	f5,  a8, 20
	lsi	f6,  a8, 24
	lsi	f7,  a8, 28
	lsi	f8,  a8, 32
	lsi	f9,  a8, 36
	lsi	f10, a8, 40
	lsi	f11, a8, 44
	lsi	f12, a8, 48
	lsi	f13, a8, 52
	lsi	f14, a8, 56
	lsi	f15, a8, 60
	l32i	a9, a8, 64
	wur.fcr	a9
	l32i	a9, a8, 68
	wur.fsr	a9
.Lresume_nofp:
	l32i	a8, a7, CTX_TPTR	/* restore THREADPTR (TLS base) */
	wur.threadptr	a8
	l32i	a6, a7, CTX_KIND
	bnez	a6, .Lresume_int

	/* SOLICITED resume: reload SP/A0/SAR/LOOP/PS and 'retw'. */
	l32i	a1, a7, CTX_SP
	l32i	a0, a7, CTX_A0
	l32i	a5, a7, CTX_SAR
	wsr.sar	a5
	l32i	a5, a7, CTX_LBEG
	wsr	a5, LBEG
	l32i	a5, a7, CTX_LEND
	wsr	a5, LEND
	l32i	a5, a7, CTX_LCOUNT
	wsr	a5, LCOUNT
	l32i	a5, a7, CTX_PS
	/* CXD8002 RECURSION FIX.  Force INTLEVEL=15 so the level-5 tick stays masked
	   through wsr.ps+retw.  The kernel does NOT raise INTLEVEL to 5 in its
	   critical sections (the timer is a high-priority L5 interrupt), so the PS we
	   restore here has INTLEVEL < 5.  With a cluster of tiny/overdue delays the
	   tick is perpetually pending and fires the instant wsr.ps lowers INTLEVEL --
	   BEFORE the retw -- so the dispatch frame never unwinds and recurses 0xC0
	   (one XT_STK frame) per tick down the stack until a window spill double-
	   faults (PC 0x403826a6).  Observed identically on CXD8002 and a 6-task
	   tiny-delay reproducer: interruptee pinned at this retw, SP marching down.
	   The resumed thread re-enters the scheduler and Leave_Kernel restores its
	   real interrupt level immediately, so the extra masking is transient.
	   a4 is scratch (the window rotates away on retw). */
	movi	a4, 0x0000000F
	or	a5, a5, a4
	wsr.ps	a5
	rsync
	retw

.Lresume_int:
	/* INTERRUPT resume: full restore from the XT_STK frame + 'rfe'. */
	l32i	a1, a7, CTX_SP		/* a1 = the thread's XT_STK frame */
	movi	a8, _xt_context_restore
	callx0	a8			/* restore a2-a15, SAR, LOOP from XT_STK */

	/* CXD8002 half-2 FIX.  A thread saved INTERRUPT was spilled by
	   _xt_context_save (SPILL_ALL_WINDOWS) -> it MUST resume with exactly ONE
	   live window; its caller frames are on its own stack and reload via window
	   underflow as it returns.  We were NOT setting WINDOWSTART here, so the
	   resumed thread inherited the DISPATCHER's stale WINDOWSTART -- e.g. the
	   idle thread, scheduled after a deep-chain task, ran with that task's
	   6-frame WINDOWSTART (0x2ab); the next tick's _xt_context_save then spilled
	   those STALE frames and intermittently hit one with saved SP~=0 -> Double
	   exception in the spill (EXCVADDR=[0-12]).  Set WINDOWSTART = 1<<WINDOWBASE
	   (single clean frame) for the resumed thread.  a0 is scratch here. */
	rsr.windowbase a0
	ssl	a0			/* SAR = 32 - WINDOWBASE */
	movi	a0, 1
	sll	a0, a0			/* a0 = 1 << WINDOWBASE */
	wsr.windowstart a0
	rsync

	/* SAR FIX (delay-strand root cause; see highint5.S .Lhi5_resume).  The
	   `ssl a0` above set SAR = 32-WINDOWBASE, CLOBBERING the interruptee SAR
	   that _xt_context_restore restored.  A preempted 64-bit divide /
	   Scaled_Divide / Mul_Div (which shift by SAR) then resumes with a wrong
	   shift amount and silently tears (plain __muldi3 uses no SAR, so it was
	   immune).  Reload the saved SAR.  a0 scratch; a1 still = the XT_STK frame. */
	l32i	a0, a1, XT_STK_SAR
	wsr.sar	a0

	/* Atomic interrupt return (CXD8002).  A plain 'wsr.ps' here lowers INTLEVEL
	   to the resumed thread's level (0) *before* a0/a1 are reloaded and before
	   the 'rfe', opening a window in which a fresh level-5 tick preempts this
	   half-restored thread (a1 still = the XT_STK frame, not the thread SP).  The
	   re-entrant save then detonates later in _xt_context_save's SPILL.  Mask all
	   interrupts for the (few-insn) restore window with rsil, set EPS_5/EPC_5,
	   and return with 'rfi 5' which restores PS<-EPS_5 + PC<-EPC_5 atomically --
	   INTLEVEL stays high right up to the return.  (This path is entered at
	   INTLEVEL 5 from highint5, 3 from the level-3 vector, or the kernel level
	   from a cooperative switch; rsil makes it correct from all three.)
	   a0 is scratch (the WINDOWSTART fix above already clobbered it); a8 must
	   NOT be touched -- _xt_context_restore has reloaded it as the thread's a8. */
	rsil	a0, 15
	l32i	a0, a1, XT_STK_PS
	wsr.eps5 a0
	l32i	a0, a1, XT_STK_PC
	wsr.epc5 a0
	l32i	a0, a1, XT_STK_A0
	l32i	a1, a1, XT_STK_A1
	rsync
	rfi	5

/* --------------------------------------------------------------------------
 * __gnat_start_thread -- first-entry trampoline for a new thread.
 * -------------------------------------------------------------------------- */
	.align	4
	.global	__gnat_start_thread
	.type	__gnat_start_thread, @function
__gnat_start_thread:
	mov	a6, a3			/* argument -> a6 (call4: callee a2)  */
	callx4	a2			/* wrapper (argument) -- never returns*/
.Lhang:
	j	.Lhang			/* safety net                        */
	.size	__gnat_start_thread, . - __gnat_start_thread
