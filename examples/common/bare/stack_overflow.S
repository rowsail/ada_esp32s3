/* Recoverable stack-overflow, stage 2: intercept the stack-limit watchpoint's
 * debug exception and redirect the faulting task into a Storage_Error raise
 * instead of panicking.
 *
 * xt_debugexception is WEAK in the IDF (the active _DebugExceptionVector does
 * "J xt_debugexception"); this strong definition overrides it.  Debug level is
 * 6 (EPC6 / EPS6 / EXCSAVE6, return with "rfi 6").  We only touch a0 (saved via
 * EXCSAVE6), leaving the faulting window (a1..a15, SP) intact so the trampoline
 * runs in the faulting task's context.
 *
 * On OUR watchpoint (data break #1, the stack limit): emulate a call4 from the
 * faulting instruction into the GNAT raise (see the inline comment) and rfi.
 * The raise runs in the redzone headroom below the watchpoint and unwinds the
 * over-limit frames to a `when Storage_Error` handler (or terminates the task
 * if none).
 *
 * Any other debug exception falls through to the default panic path. */

	.section .iram1, "ax"
	.align	4
	.global	xt_debugexception
xt_debugexception:
	wsr.excsave6	a0			/* save faulting a0 (our only scratch) */
	rsr.debugcause	a0
	bbci	a0, 2, .Lso_chain		/* DEBUGCAUSE.DBREAK (bit 2) clear -> not us */
	extui	a0, a0, 8, 4			/* a0 = DBNUM (bits 8..11) */
	bnei	a0, 1, .Lso_chain		/* not data break #1 -> not our watchpoint */

	/* Our stack-limit watchpoint.  Emulate a call4 from the faulting
	   instruction into the GNAT raise: set the return-address register a
	   call4 would set (a4 of the faulting window, call4-encoded to the
	   faulting PC) and CALLINC=1 in the resume PS, then resume at the
	   raise procedure -- its 'entry' completes the call.  The raise thus
	   appears as a callee of the faulting frame, and the ZCX unwinder
	   walks only real, FDE-covered Ada frames (hand-written assembly has
	   no FDE on Xtensa -- gas rejects CFI -- and an FDE-less frame aborts
	   the unwind, which is why a call-through trampoline cannot work).
	   a2/a3 of the faulting window are dead (only a0/a1 feed the unwind
	   chain; a4 is exactly what a real call4 clobbers). */
	rsr.epc6	a2			/* faulting PC */
	slli	a2, a2, 2
	srli	a2, a2, 2			/* pc & 0x3FFF_FFFF */
	movi	a3, 0x40000000
	or	a4, a2, a3			/* call4-encoded return address */
	movi	a2, __gnat_stack_overflow_raise
	wsr.epc6	a2
	rsr.eps6	a2
	movi	a3, ~0x00030000
	and	a2, a2, a3			/* clear PS.CALLINC */
	movi	a3, 0x00010000
	or	a2, a2, a3			/* PS.CALLINC := 1 (call4) */
	wsr.eps6	a2
	rsr.excsave6	a0			/* restore faulting a0 */
	rfi	6

.Lso_chain:
	/* not ours: same as the default _xt_debugexception -> _xt_panic */
	movi	a0, 1				/* PANIC_RSN_DEBUGEXCEPTION */
	wsr.exccause	a0
	rsr.epc6	a0
	wsr.epc1	a0
	rsr.excsave6	a0
	wsr.excsave1	a0
	call0	_xt_panic			/* does not return */

	/* Force this object to be linked: the IDF's WEAK xt_debugexception
	   already satisfies the vector's reference, so without a forced pull our
	   strong override is never taken from the component archive.  glue.c
	   touches this marker (same trick as highint5.S's gnat_hi5_marker). */
	.data
	.global	gnat_stack_ovf_marker
gnat_stack_ovf_marker:
	.word	0
