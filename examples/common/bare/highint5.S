/* Native OS-band interrupt vectors (levels 2 and 3) for the GNARL runtime.
 *
 * ARCHITECTURE -- the FreeRTOS Xtensa port model.  The original design ran
 * the tick as a LEVEL-5 vector (xt_highint5) with per-vector context-switch
 * deferral flags; level 5 > XCHAL_EXCM_LEVEL meant the tick could preempt
 * window-critical code (spills, window exceptions) and corrupt WINDOWSTART
 * -- the intermittent _WindowUnderflow8 freezes.  This file replaces that
 * design wholesale with the structure the FreeRTOS Xtensa port has proven:
 *
 *   1. Every interrupt that interacts with the OS (makes tasks ready, hence
 *      may require a context switch) lives at a level <= XCHAL_EXCM_LEVEL
 *      (3): the SYSTIMER tick + cross-core poke (CPU_INT 21, level 2), the
 *      level-2 device slots (CPU_INT 19/20/21) and the level-3 device slots
 *      (CPU_INT 23/27).  PS.EXCM -- set by hardware during every window
 *      over/underflow exception -- and the INTLEVEL raised across every
 *      SPILL_ALL_WINDOWS therefore mask ALL of them: no OS-band interrupt
 *      can ever observe a half-spilled register window.  Levels above
 *      EXCM_LEVEL are reserved for OS-oblivious handlers (none installed;
 *      level 5 parks, see xt_highint5 below).
 *
 *   2. Handlers are DISPATCHED AT INTLEVEL = XCHAL_EXCM_LEVEL, exactly like
 *      ESP-IDF's _xt_medint2/_xt_medint3: OS-band handlers never preempt one
 *      another (the interrupt LEVEL still decides which pending source is
 *      taken first and which interrupts preempt task code).  True vector
 *      nesting is thereby confined to the few instructions of a prologue
 *      before its rsil, where it is handled by the epilogue guard (4).
 *
 *   3. The outermost entry switches to the per-CPU INTERRUPT STACK
 *      (interrupt_stack_table -- GNARL's per-CPU stacks, s-bbinte): handler
 *      frames and their window spills never land on task stacks.
 *
 *   4. The context switch happens in EXACTLY ONE place: the OUTERMOST vector
 *      epilogue, fully masked, after the dispatch chain has completely
 *      unwound.  Ada code never switches from inside an interrupt
 *      (s-bbcppr.Context_Switch returns immediately while __gnat_int_nest is
 *      nonzero; the epilogue compares First_Thread with Running_Thread
 *      itself).  A switch is additionally DEFERRED when the interrupted PC
 *      lies inside vector text (the VECBASE page or this file): we never
 *      dispatch away from a half-entered vector whose EPC/EPS/EXCSAVE
 *      special registers are still live in hardware -- the next interrupt
 *      exit (bounded by the tick) performs the switch instead.
 *
 * The interruptee's full context is saved to an XT_STK frame on its own
 * stack by the vendored _xt_context_save, whose SPILL_ALL_WINDOWS leaves
 * WINDOWSTART = 1 << WINDOWBASE by construction -- so a plain resume needs
 * no WINDOWSTART bookkeeping at all.  The task-switch path is
 * context_switch.S (__gnat_preempt_dispatch -> .Lresume).
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

	/* Per-core native-interrupt nesting depth.  Owned by the vectors below
	   (incremented in the masked prologue, decremented in the masked
	   epilogue); imported by s-bbcppr.Context_Switch, which refuses to
	   switch while it is nonzero (the epilogue switches instead). */
	.align	4
	.global	__gnat_int_nest
__gnat_int_nest:
	.word	0, 0

	/* Per-core task-side SP (the interruptee's XT_STK frame), stored at
	   outermost entry when hopping onto the interrupt stack, reloaded at
	   outermost exit. */
	.align	4
__gnat_int_task_sp:
	.word	0, 0

	/* TEMP diagnostic: set when a vector entered with an interruptee SP
	   outside DRAM (a corrupted resumed context) -- the core parks in the
	   vector before that SP can scribble a single byte.  [0]=the bad SP,
	   [1]=the interrupted PC.  NB engmon-only assumption: all task stacks
	   live in DRAM (no ENV_STACK_PSRAM). */
	.align	4
	.global	__gnat_bad_sp
__gnat_bad_sp:
	.word	0, 0

	.section .iram1, "ax"
	.align	4
	.global	__gnat_vec_text_start
__gnat_vec_text_start:

/* --------------------------------------------------------------------------
 * gnat_os_vector -- the OS-band vector body, one instantiation per level.
 * Entered from the VECBASE slot with the interruptee's a0 in EXCSAVE_LVL and
 * PS.INTLEVEL = LVL.
 * -------------------------------------------------------------------------- */
	.macro	gnat_os_vector	LVL, DISPATCH

	/* -- Prologue: save the interruptee --------------------------------- */

	/* Mask the whole OS band plus the debug level at once (INTLEVEL 6 =
	   DEBUGLEVEL).  Two purposes: (a) a higher OS-band interrupt can now
	   land only on the VECBASE slot or this very instruction -- both inside
	   the epilogue guard's vector-text range, so no switch can strand us;
	   (b) the frame build below may cross the interrupted task's
	   stack-guard DBREAK watchpoint (kernel bookkeeping in the redzone, not
	   a task overflow) and must not raise a debug exception.  a0 is free:
	   the slot stashed the interruptee's a0 in EXCSAVE_\LVL. */
	rsil	a0, 6

	/* TEMP diagnostic (see __gnat_bad_sp): park BEFORE the frame build if
	   the interruptee SP is not a DRAM stack address -- a corrupted context
	   was resumed, and building the XT_STK frame through its SP would
	   scribble whatever it points at (observed: SYSTIMER registers).  Only
	   a0 is free; sp itself is expendable on the bad path. */
	movi	a0, 0x3FC80000
	bltu	sp, a0, 9f
	movi	a0, 0x3FD00000
	bgeu	sp, a0, 9f
	j	8f
9:	movi	a0, __gnat_bad_sp
	s32i	sp, a0, 0		/* [0] = the bad SP */
	rsr.epc\LVL	sp		/* sp is garbage anyway: reuse for EPC */
	s32i	sp, a0, 4		/* [1] = interrupted PC */
9:	j	9b			/* park, fully masked, evidence intact */
8:
	mov	a0, sp
	addi	sp, sp, -XT_STK_FRMSZ
	s32i	a0, sp, XT_STK_A1
	rsr.eps\LVL	a0		/* interruptee PS */
	s32i	a0, sp, XT_STK_PS
	rsr.epc\LVL	a0		/* interruptee PC */
	s32i	a0, sp, XT_STK_PC
	rsr.excsave\LVL	a0		/* interruptee a0 */
	s32i	a0, sp, XT_STK_A0
	s32i	a12, sp, XT_STK_A12	/* temps _xt_context_save relies on */
	s32i	a13, sp, XT_STK_A13
	call0	_xt_context_save	/* a2-a15, SAR, loops; SPILLs ALL windows */

	/* -- Enter: nesting count + interrupt stack (still at INTLEVEL 6) --- */

	getcoreid a2
	movi	a3, __gnat_int_nest
	addx4	a3, a2, a3
	l32i	a4, a3, 0
	addi	a5, a4, 1
	s32i	a5, a3, 0		/* nest++ */
	bnez	a4, 1f			/* nested: already on the interrupt stack */
	movi	a5, __gnat_int_task_sp
	addx4	a5, a2, a5
	s32i	sp, a5, 0		/* remember the task-side frame */
	movi	a5, interrupt_stack_table
	addx4	a5, a2, a5
	l32i	a5, a5, 0		/* per-CPU interrupt stack top (16-aligned) */
	beqz	a5, 1f			/* table not initialized yet: stay put */
	mov	sp, a5
1:
	/* -- Dispatch at EXCM_LEVEL: OS-band handlers never nest ------------ */

	movi	a0, PS_INTLEVEL(XCHAL_EXCM_LEVEL) | PS_UM | PS_WOE
	wsr	a0, PS
	rsync

	call4	\DISPATCH		/* Ada: service every pending source */

	/* -- Exit: masked from here to the rfi ------------------------------ */

	rsil	a2, 15
	getcoreid a2
	movi	a3, __gnat_int_nest
	addx4	a3, a2, a3
	l32i	a4, a3, 0
	addi	a4, a4, -1
	s32i	a4, a3, 0		/* nest-- */
	bnez	a4, 2f			/* nested exit: plain restore, stay put */

	movi	a5, __gnat_int_task_sp
	addx4	a5, a2, a5
	l32i	sp, a5, 0		/* back to the task-side frame */

	/* Preemptive dispatch?  Decided ONLY here, at the outermost exit,
	   directly from the scheduler queues. */
	movi	a5, first_thread_table
	addx4	a5, a2, a5
	l32i	a6, a5, 0
	movi	a5, __gnat_running_thread_table
	addx4	a5, a2, a5
	l32i	a7, a5, 0
	beqz	a6, 2f			/* scheduler not fully up: no dispatch */
	beqz	a7, 2f			/* (FreeRTOS's port_xSchedulerRunning guard) */
	beq	a6, a7, 2f		/* First = Running: plain resume */

	/* Guard: never dispatch away from a half-entered vector.  Its
	   EPC/EPS/EXCSAVE special registers are still live in hardware and
	   would be clobbered by the next same-level interrupt long before it
	   was resumed.  If the interrupted PC lies in the VECBASE page (window
	   handlers + vector slots) or in this file's vector text, resume it;
	   the next interrupt exit -- bounded by the tick -- switches then. */
	l32i	a5, sp, XT_STK_PC
	rsr	a6, VECBASE
	sub	a6, a5, a6
	movi	a7, 0x400
	bltu	a6, a7, 2f		/* in the VECBASE page: defer */
	movi	a6, __gnat_vec_text_start
	bltu	a5, a6, 3f		/* below this file's vectors: switch */
	movi	a7, __gnat_vec_text_end
	bltu	a5, a7, 2f		/* inside this file's vectors: defer */
3:
	movi	a2, __gnat_preempt_dispatch
	jx	a2			/* a1 = the task's XT_STK frame; no return */

2:	/* Plain resume of the interrupted context.  _xt_context_restore
	   reloads a2-a15, SAR and the loop registers; nothing below may touch
	   any of them.  'rfi' restores PS and PC atomically from EPS/EPC, so
	   the mask holds right up to the return -- no preemptible window. */
	call0	_xt_context_restore
	l32i	a0, sp, XT_STK_PS
	wsr.eps\LVL	a0
	l32i	a0, sp, XT_STK_PC
	wsr.epc\LVL	a0
	l32i	a0, sp, XT_STK_A0
	l32i	sp, sp, XT_STK_A1
	rsync
	rfi	\LVL
	.endm

	.align	4
	.global	__gnat_level2_vector
	.type	__gnat_level2_vector, @function
__gnat_level2_vector:
	gnat_os_vector	2, __gnat_level2_dispatch
	.size	__gnat_level2_vector, . - __gnat_level2_vector

	.align	4
	.global	__gnat_level3_vector
	.type	__gnat_level3_vector, @function
__gnat_level3_vector:
	gnat_os_vector	3, __gnat_level3_dispatch
	.size	__gnat_level3_vector, . - __gnat_level3_vector

/* --------------------------------------------------------------------------
 * Level 5: nothing is routed here any more.  The tick moved to level 2
 * (CPU_INT 21); the old CCOMPARE2 (int 16) and poke (int 31) sources are
 * parked and never enabled.  The vendored VECBASE table still targets
 * xt_highint5, so provide a stub: an arrival can only mean a routing bug --
 * park with the PC on this label, plainly visible to a JTAG halt.
 * -------------------------------------------------------------------------- */
	.align	4
	.global	xt_highint5
	.type	xt_highint5, @function
xt_highint5:
1:	j	1b
	.size	xt_highint5, . - xt_highint5

	.global	__gnat_vec_text_end
__gnat_vec_text_end:
