/* Bare reset/startup for the IDF-free image (Level B).
 *
 * Our own IDF-free 2nd-stage bootloader (flash 0x0) does flash/cache/MMU/clock-pin
 * bring-up, then jumps to this ELF entry (_start).  We establish a clean
 * register window, VECBASE (our vendored Xtensa vector table), the env-task
 * stack, enable the FPU coprocessor (no lazy trap), clear .bss, then call the C
 * entry start_c() (which disables the RTC watchdogs and calls app_main()).
 *
 * Also defines bare, ABI-safe stubs for the handful of Xtensa/FreeRTOS symbols
 * the vendored xtensa_*.obj reference but that are never reached on this
 * single-L5-tick, fault-free blink path (panic / unhandled / FreeRTOS dispatch).
 */
	.section .iram1, "ax"
	.align	4
	.global	_start
	.type	_start, @function
_start:
	/* VECBASE FIRST -> our vectors, so any fault below is visible (not the
	   bootloader's stale handler).  The bootloader already called us with a
	   valid register window, so do NOT touch WINDOWBASE/WINDOWSTART. */
	movi	a0, _vector_table
	wsr.vecbase	a0
	rsync
	/* PS must match what the GNARL runtime assumes for a task's window context
	   (s-bbcppr__xtensa.adb Initial_PS = 0x0005_002F): WOE=1 (window overflow
	   detection), CALLINC=1 (frame entered as if call4'd) and UM=1 (user vector
	   mode).  The environment task that runs adainit/_ada_main INHERITS this raw
	   _start window/PS (Initialize_Context returns early for it), so getting the
	   PS wrong corrupts the window spill/restore chain during adainit's deep
	   elaboration.  Keep INTLEVEL=0 (interrupts arm later) -> PS = 0x0005_0020. */
	movi	a0, 0x00050020
	wsr.ps	a0
	rsync
	/* Discard the bootloader's deep window (several live frames on ITS stack) by
	   marking ONLY the current frame live: WINDOWSTART = 1 << WINDOWBASE, the
	   exact normalisation the runtime uses elsewhere -- WITHOUT forcing
	   WINDOWBASE=0 (that left the current physical window holding the bootloader's
	   stale a2..a15, which fed a 0 stack-pointer into a later window spill ->
	   adainit retw underflow read a 0 back-link -> LoadProhibited). */
	rsr.windowbase	a3
	ssl	a3
	movi	a2, 1
	sll	a2, a2
	wsr.windowstart	a2
	rsync
	movi	a0, 0
	/* enable coprocessor 0 (FPU) so first FP use does not take a coproc trap */
	movi	a0, 1
	wsr.cpenable	a0
	/* SP = top of the env-task stack, 16-aligned */
	movi	a1, __stack_end
	movi	a0, -16
	and	a1, a1, a0
	/* clear .bss [_bss_start, _bss_end) */
	movi	a2, _bss_start
	movi	a3, _bss_end
	movi	a4, 0
.Lbss:
	bgeu	a2, a3, .Lbss_done
	s32i	a4, a2, 0
	addi	a2, a2, 4
	j	.Lbss
.Lbss_done:
	/* Replicate IDF call_start_cpu0's I-cache bring-up (cpu_start.c ~L516-543).
	   The bootloader maps IROM/DROM into the MMU and enables the cache, but it
	   never tells the cache the IROM/DROM *split*.  On the shared-vaddr S3 the
	   cache then treats the whole MMU as DROM, so D-bus reads (DROM, 0x3c..)
	   work but the I-bus serves entry-0 IROM (0x42..) as ZEROS -> the first
	   flash-XIP fetch at start_c decodes 0x000000 = illegal instruction.
   The I-cache must be MODE-configured (Cache_Set_ICache_Mode) so it serves
	   flash-XIP -- a bare CTRL register poke does not run the chip's occupy/init
	   so I-bus reads come back ZEROS -- and then the IROM/DROM MMU split set.
	   CRITICAL: the size arg is an ENUM (CACHE_SIZE_HALF=0 => 16 KB icache,
	   CACHE_SIZE_FULL=1 => 32 KB), NOT a byte count.  A 32 KB icache occupies
	   0x40370000-0x40377FFF and EATS our vectors/_start at 0x40374000 (the next
	   fetch then returns zeros); 16 KB stays in 0x40370000-0x40373FFF and leaves
	   0x40374000 intact (exactly the IDF iram0_0_seg layout).  So:
	     Cache_Set_ICache_Mode(CACHE_SIZE_HALF=0, 8WAYS=1, LINE_32B=1)
	     Cache_Set_IDROM_MMU_Size(irom_mmu_bytes, 0x400 - irom_mmu_bytes)
	   Our IROM is one 64 KB MMU page -> irom_mmu_bytes = 1 * sizeof(u32) = 4. */
	/* rom_config_instruction_cache_mode does the FULL i-cache bring-up (occupy +
	   mode + tag init) that ad-hoc occupy/CTRL pokes cannot reproduce -- only it
	   makes the I-bus actually serve flash XIP (verified: IROM then reads back
	   correctly).  On this path it ALWAYS configures a 32 KB I-cache regardless
	   of the size arg, occupying 0x40370000-0x40377FFF.  We therefore link our
	   code/vectors at 0x40378000+ (vendor/memory.ld iram0_0_seg) so the cache
	   never eats them. */
	movi	a10, 0
	movi	a11, 1			/* CACHE_8WAYS_ASSOC */
	movi	a12, 1			/* CACHE_LINE_SIZE_32B */
	call4	rom_config_instruction_cache_mode
	movi	a10, 4			/* cache_mmu_irom_size: 1 page * 4 */
	movi	a11, 0x000003fc		/* CACHE_DROM_MMU_MAX_END(0x400) - 4 */
	call4	Cache_Set_IDROM_MMU_Size
	call4	Cache_Invalidate_ICache_All
	/* Switch the CPU to 240 MHz.  Our 2nd-stage bootloader does NO clock setup,
	   so it leaves the CPU on the ROM default: SYSTEM_SYSCLK_CONF SOC_CLK_SEL=0
	   (XTAL) with PRE_DIV_CNT=1, i.e. 40/2 = 20 MHz.  The GNARL runtime hard-
	   assumes 240 MHz (s-bbpara Clock_Frequency) for its timer/alarm maths, so at
	   20 MHz CCOUNT-driven alarms fire ~12x late (short Ada delays overshoot
	   wildly; ACATS/profile-test timing checks fail).  The 480 MHz BBPLL is
	   already enabled by the ROM (it clocks the 80 MHz flash MSPI), so we only
	   need to (a) set CPUPERIOD_SEL=2 + PLL_FREQ_SEL=480 in CPU_PER_CONF, then
	   (b) point SYSCLK_CONF at the PLL (SOC_CLK_SEL=1, PRE_DIV_CNT=0) -> 480/2 =
	   240 MHz.  Flash MSPI keeps its own 80 MHz clock (unaffected by the CPU
	   source).  Done here from IRAM, before the IROM jump, so any clock transient
	   does not disturb execution. */
	movi	a2, 0x600c0010		/* SYSTEM_CPU_PER_CONF_REG */
	l32i	a3, a2, 0
	movi	a4, 0xfffffff8		/* clear CPUPERIOD_SEL[1:0] + PLL_FREQ_SEL[2] */
	and	a3, a3, a4
	movi	a4, 0x6			/* PLL_FREQ_SEL=1 (480 MHz) | CPUPERIOD_SEL=2 */
	or	a3, a3, a4
	s32i	a3, a2, 0
	memw
	movi	a2, 0x600c0060		/* SYSTEM_SYSCLK_CONF_REG */
	l32i	a3, a2, 0
	movi	a4, 0xfffff000		/* clear PRE_DIV_CNT[9:0] + SOC_CLK_SEL[11:10] */
	and	a3, a3, a4
	movi	a4, 0x400		/* SOC_CLK_SEL=1 (PLL), PRE_DIV_CNT=0 */
	or	a3, a3, a4
	s32i	a3, a2, 0
	memw
	movi	a10, 240		/* tell the ROM the new freq (ets_delay_us) */
	call4	ets_update_cpu_frequency
	/* Enter start_c by JUMP, not call4: _start is raw asm with no ENTRY, so a
	   `call4 start_c` would leave _start as a phantom windowed frame ABOVE
	   start_c in the spill chain -- and when adainit's deep, window-wrapping
	   elaboration spills that frame the back-links go inconsistent (a later retw
	   underflow reads a 0 frame pointer -> LoadProhibited at excvaddr ~ -32).
	   Jumping makes start_c's own ENTRY the TRUE outermost windowed frame
	   (reusing this window), with a0=0 so its spill/unwind terminates cleanly --
	   exactly how the IDF enters call_start_cpu0 as a clean nested frame. */
	movi	a8, start_c		/* -mlongcalls -> l32r (start_c is far, in IROM) */
	movi	a0, 0
	jx	a8
	.size	_start, . - _start

/* __gnat_enter_env(body): enter the Ada environment task as the OUTERMOST
   register-window frame.  Reached via call4 from app_main (a2 = body fn ptr).
   The IDF build runs adainit/_ada_main as a FreeRTOS task whose entry is the top
   of the window; ours has caller frames (app_main -> start_c -> _start) ABOVE
   adainit, and the first cooperative context switch (Queues.Yield, reached from
   Time.Initialize_Timers during adainit) spills/normalises that deep caller
   chain, leaving a 0 window back-link that faults a later retw underflow.  Here
   we mark ONLY the current window live (WINDOWSTART = 1<<WINDOWBASE), discarding
   those callers (the env task never returns to them -- _ada_main loops forever),
   set a0=0 as the spill/unwind terminator, then jump into the body, which then
   IS the outermost frame.  This makes our env-task entry match the runtime's
   task-entry contract. */
	.align	4
	.global	__gnat_enter_env
	.type	__gnat_enter_env, @function
__gnat_enter_env:
	rsr.windowbase	a4
	ssl	a4
	movi	a3, 1
	sll	a3, a3
	wsr.windowstart	a3
	rsync
	movi	a0, 0
	movi	a2, ada_env_body	/* -mlongcalls -> l32r (far, in IROM) */
	jx	a2
	.size	__gnat_enter_env, . - __gnat_enter_env

/* APP_CPU (core 1) cold-entry shim.  ets_set_appcpu_boot_addr points the ROM's
   reset hand-off here.  The IDF-free bootloader never gave core 1 a stack (the
   IDF's call_start_cpu1 would), so core 1 would otherwise run core1_bare_main on
   its garbage reset SP and its window spills could clobber core 0's env stack ->
   core 0 faults at a later retw underflow.  Establish a clean CPU state on a
   dedicated core-1 stack, then call the C bring-up. */
	.align	4
	.global	core1_start
	.type	core1_start, @function
core1_start:
	movi	a0, _vector_table
	wsr.vecbase	a0
	rsync
	movi	a0, 0x00040000		/* PS = WOE, kernel ring, INTLEVEL=0 */
	wsr.ps	a0
	rsync
	movi	a0, 1
	wsr.cpenable	a0
	/* clean single register window (see _start) */
	movi	a0, 0
	wsr.windowstart	a0
	wsr.windowbase	a0
	rsync
	movi	a0, 1
	wsr.windowstart	a0
	rsync
	movi	a0, 0
	/* SP = top of core 1's dedicated stack, 16-aligned */
	movi	a1, __core1_stack_end
	movi	a0, -16
	and	a1, a1, a0
	call4	core1_bare_main
.Lc1hang:
	j	.Lc1hang
	.size	core1_start, . - core1_start

/* --- bare stubs (call0 ABI) for symbols not in the vendored objs and never
       reached on the blink path (panic / reset entry / FreeRTOS dispatch) --- */
	.align	4
	.global	_xt_panic
	.global	xt_unhandled_exception
	.global	call_user_start
_xt_panic:
xt_unhandled_exception:
call_user_start:
1:	j	1b

	.align	4
	.global	_frxt_int_enter
	.global	_frxt_int_exit
_frxt_int_enter:
_frxt_int_exit:
	ret

	.align	4
	.global	_frxt_coproc_exc_hook
_frxt_coproc_exc_hook:
	movi	a2, 0		/* "not handled" -> default path (never taken) */
	ret
