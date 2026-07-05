with System;
with System.Storage_Elements;      use System.Storage_Elements;
with System.Machine_Code;          use System.Machine_Code;
with Interfaces;                   use Interfaces;
with Ada.Unchecked_Conversion;
with Ada.Interrupts.Names;
with Ada.Synchronous_Task_Control; use Ada.Synchronous_Task_Control;
with Ada.Real_Time;                use Ada.Real_Time;
with Ada.Real_Time.Timing_Events;  use Ada.Real_Time.Timing_Events;
with ESP32S3_Registers;            use ESP32S3_Registers;
with ESP32S3_Registers.DMA;        use ESP32S3_Registers.DMA;
with ESP32S3_Registers.SYSTEM;
with ESP32S3_Registers.INTERRUPT_CORE0;

package body ESP32S3.GDMA is

   use type System.Address;

   Cache_Line : constant := 32;   --  ESP32-S3 external-memory DCache line size

   --  True if A is in external PSRAM (accessed through the DCache).
   function In_PSRAM (A : System.Address) return Boolean
   is (To_Integer (A) in 16#3C00_0000# .. 16#3DFF_FFFF#);

   --  The GDMA reaches internal SRAM directly, and external PSRAM THROUGH the
   --  DCache -- so a PSRAM buffer is DMA-capable only when it is cache-line
   --  aligned (the sync below rounds the length to a line, so the buffer should
   --  also be sized to a line-multiple, or share its trailing line with nothing
   --  live).  Flash .rodata (also 0x3C..) is never writable/aligned for this and
   --  so is correctly excluded.
   function Is_DMA_Capable (A : System.Address) return Boolean is
      Addr : constant Integer_Address := To_Integer (A);
   begin
      return Addr in 16#3FC8_8000# .. 16#3FCF_FFFF#            --  internal SRAM
        or else (In_PSRAM (A) and then Addr mod Cache_Line = 0);
   end Is_DMA_Capable;

   --  ROM DCache maintenance by address (rom_syms.ld).  Write back dirty lines so
   --  PSRAM holds the CPU's data before the DMA reads it; invalidate stale lines
   --  so the CPU re-reads PSRAM after the DMA wrote it.
   procedure Rom_WriteBack (Addr, Size : Unsigned_32)
   with Import, Convention => C, External_Name => "rom_Cache_WriteBack_Addr";
   procedure Rom_Invalidate (Addr, Size : Unsigned_32)
   with Import, Convention => C, External_Name => "Cache_Invalidate_Addr";

   --  Synchronise a PSRAM region with the DMA's view, over whole cache lines, with
   --  interrupts masked: the ROM op briefly manipulates the DCache, so an ISR that
   --  touched cached memory in the window could fault or race.
   procedure Cache_Sync (Addr : System.Address; Length : Natural; Invalidate : Boolean) is
      Base : constant Integer_Address :=
        To_Integer (Addr) - (To_Integer (Addr) mod Cache_Line);
      Last : constant Integer_Address := To_Integer (Addr) + Integer_Address (Length);
      Size : constant Integer_Address :=
        ((Last - Base + Cache_Line - 1) / Cache_Line) * Cache_Line;
      PS   : Unsigned_32;
   begin
      Asm ("rsil %0, 15", Outputs => Unsigned_32'Asm_Output ("=r", PS),
           Volatile => True, Clobber => "memory");
      if Invalidate then
         Rom_Invalidate (Unsigned_32 (Base), Unsigned_32 (Size));
      else
         Rom_WriteBack (Unsigned_32 (Base), Unsigned_32 (Size));
      end if;
      Asm ("wsr.ps %0" & ASCII.LF & "rsync", Inputs => Unsigned_32'Asm_Input ("r", PS),
           Volatile => True, Clobber => "memory");
   end Cache_Sync;

   --  PERI_SEL value that DISCONNECTS a path from any peripheral.
   Disconnect_Sel : constant := 16#3F#;

   --  Memory-to-memory does NOT use the "invalid/disconnected" id -- it borrows
   --  a *free real* peripheral trigger slot (any of 0..9) together with
   --  MEM_TRANS_EN on the RX path.  Using 0x3F here leaves the channel
   --  disconnected and it never runs (that was the long mem2mem bug).  esp-idf
   --  picks the lowest free slot; we use 0 (mem2mem doesn't touch the real SPI2,
   --  the data path is the internal TX->RX loopback).
   M2M_Sel : constant := 0;

   --  PERI_SEL encoding for a bound peripheral (TRM: 0:SPI2 .. 9:RMT).
   function Peri_Sel (P : Peripheral) return UInt6
   is (case P is
         when Mem2Mem => M2M_Sel,
         when SPI2    => 0,
         when SPI3    => 1,
         when UHCI0   => 2,
         when I2S0    => 3,
         when I2S1    => 4,
         when LCD_CAM => 5,
         when AES     => 6,
         when SHA     => 7,
         when ADC_DAC => 8,
         when RMT     => 9);

   ---------------------------------------------------------------------------
   --  Per-channel register overlay.
   --
   --  svd2ada flattened the five identical channel blocks into named _CH0.._CH4
   --  fields; the hardware is really a regular array (stride 0xC0, IN block at
   --  +0x00, OUT block at +0x60).  We re-impose that array here -- only the
   --  registers the driver touches are named, at their in-block offsets -- so a
   --  runtime Channel_Id indexes Channels (Id).
   ---------------------------------------------------------------------------

   type Channel_Regs is record
      IN_CONF0     : IN_CONF0_CH_Register;
      IN_INT_RAW   : IN_INT_RAW_CH_Register;
      IN_INT_ST    : IN_INT_ST_CH_Register;
      IN_INT_ENA   : IN_INT_ENA_CH_Register;
      IN_INT_CLR   : IN_INT_CLR_CH_Register;
      IN_LINK      : IN_LINK_CH_Register;
      IN_PERI_SEL  : IN_PERI_SEL_CH_Register;
      OUT_CONF0    : OUT_CONF0_CH_Register;
      OUT_INT_RAW  : OUT_INT_RAW_CH_Register;
      OUT_INT_ST   : OUT_INT_ST_CH_Register;
      OUT_INT_ENA  : OUT_INT_ENA_CH_Register;
      OUT_INT_CLR  : OUT_INT_CLR_CH_Register;
      OUT_LINK     : OUT_LINK_CH_Register;
      OUT_PERI_SEL : OUT_PERI_SEL_CH_Register;
   end record
   with Volatile;

   for Channel_Regs use
     record
       IN_CONF0 at 16#00# range 0 .. 31;
       IN_INT_RAW at 16#08# range 0 .. 31;
       IN_INT_ST at 16#0C# range 0 .. 31;
       IN_INT_ENA at 16#10# range 0 .. 31;
       IN_INT_CLR at 16#14# range 0 .. 31;
       IN_LINK at 16#20# range 0 .. 31;
       IN_PERI_SEL at 16#48# range 0 .. 31;
       OUT_CONF0 at 16#60# range 0 .. 31;
       OUT_INT_RAW at 16#68# range 0 .. 31;
       OUT_INT_ST at 16#6C# range 0 .. 31;
       OUT_INT_ENA at 16#70# range 0 .. 31;
       OUT_INT_CLR at 16#74# range 0 .. 31;
       OUT_LINK at 16#80# range 0 .. 31;
       OUT_PERI_SEL at 16#A8# range 0 .. 31;
     end record;

   for Channel_Regs'Size use 16#C0# * 8;          --  192-byte channel stride
   for Channel_Regs'Object_Size use 16#C0# * 8;

   type Channel_Array is array (Channel_Id) of Channel_Regs;

   Channels : Channel_Array
   with Import, Volatile, Address => ESP32S3_Registers.DMA_Base;

   ---------------------------------------------------------------------------
   --  DMA descriptor (in-RAM linked-list node; 12 bytes, 4-byte aligned).
   ---------------------------------------------------------------------------

   --  DW0 = descriptor word 0: the control/status word of a GDMA descriptor.
   type DW0_Field is record
      Size    : UInt12 := 0;    --  buffer capacity in bytes
      Length  : UInt12 := 0;    --  valid bytes (TX: set by us; RX: by HW)
      Rsv     : UInt4 := 0;        --  reserved (bits 24..27)
      Err_EOF : Boolean := False;  --  error end-of-frame
      Rsv29   : Boolean := False;  --  reserved (bit 29)
      Suc_EOF : Boolean := False;  --  success end-of-frame: last node in the link
      Owner   : Boolean := False;  --  True = owned by DMA engine
   end record;
   for DW0_Field use
     record
       Size at 0 range 0 .. 11;
       Length at 0 range 12 .. 23;
       Rsv at 0 range 24 .. 27;
       Err_EOF at 0 range 28 .. 28;
       Rsv29 at 0 range 29 .. 29;
       Suc_EOF at 0 range 30 .. 30;
       Owner at 0 range 31 .. 31;
     end record;
   for DW0_Field'Size use 32;

   type Descriptor is record
      W0     : DW0_Field;        --  control/status word (see DW0_Field above)
      Buffer : System.Address;   --  the data buffer this node moves
      Next   : System.Address;   --  next descriptor (or self / null to stop)
   end record
   with Alignment => 4;

   --  One TX (source) and one RX (destination) descriptor per channel.  Module
   --  level -> lands in .bss (internal SRAM), satisfying the 20-bit link addr.
   TX_Desc : array (Channel_Id) of aliased Descriptor;
   RX_Desc : array (Channel_Id) of aliased Descriptor;

   --  A receive into PSRAM needs its cache lines invalidated AFTER the DMA writes
   --  them, but the buffer address isn't known at the Wait/Done completion point
   --  -- stash it here per channel when the RX is armed (Null when the RX target
   --  was internal SRAM and needs no sync).
   RX_Sync_Buf : array (Channel_Id) of System.Address := (others => System.Null_Address);
   RX_Sync_Len : array (Channel_Id) of Natural := (others => 0);

   function Addr_To_U32 is new Ada.Unchecked_Conversion (System.Address, UInt32);

   --  Low 20 bits of an address, for the *LINK INLINK/OUTLINK_ADDR field.
   function Link_Addr (A : System.Address) return UInt20
   is (UInt20 (Addr_To_U32 (A) and 16#F_FFFF#));

   --  Fill a one-node descriptor: whole buffer, last in link, DMA-owned.
   procedure Set_Desc (D : in out Descriptor; Buf : System.Address; Length : Natural) is
   begin
      D.W0 :=
        (Size    => UInt12 (Length),
         Length  => UInt12 (Length),
         Suc_EOF => True,
         Owner   => True,
         others  => <>);
      D.Buffer := Buf;
      D.Next := System.Null_Address;
   end Set_Desc;

   --------------------------------------------------------------------------
   --  Interrupt-driven completion.  A transfer arms its channel's EOF
   --  interrupt; the waiting task suspends and the GDMA EOF interrupt (every
   --  channel routed to CPU_INT 19 = Device_L2_0) wakes it -- so the core is
   --  free for the whole transfer instead of busy-polling.  A short spin first
   --  absorbs tiny transfers without paying the interrupt + context-switch cost.
   --------------------------------------------------------------------------

   GDMA_CPU_Int : constant := 19;   --  Device_L2_0

   --  One completion signal per channel and direction.  A channel is owned by
   --  one task at a time, so at most one task ever waits on each.
   Done_Signal : array (Channel_Id, Direction) of Suspension_Object;

   --  Deadline timer per channel/direction: if the EOF interrupt never arrives
   --  (a stuck or misconfigured DMA), this fires and force-wakes the completion
   --  signal so Wait cannot block forever.  Generous -- a single GDMA transfer
   --  is <= 4095 bytes, whose EOF (bytes reached the FIFO) lands well inside this
   --  even when the FIFO drain is rate-gated -- so it only ever trips on a fault.
   Timeout_Ev   : array (Channel_Id, Direction) of Timing_Event;
   Wait_Timeout : constant Time_Span := Seconds (5);

   --  Poll Done this many times before suspending.  Each poll is a slow APB
   --  register read, so this is a few microseconds -- enough to absorb a tiny
   --  transfer that would finish before the interrupt + context switch pays
   --  off, without wasting much before suspending on a long one.  Tunable; the
   --  suspend path alone is correct at 0.
   Spin_Limit : constant := 200;

   protected Completion
     with Interrupt_Priority => Ada.Interrupts.Names.Device_L2_Priority
   is
      procedure Route;     --  one-time: map every DMA channel int to CPU_INT 19
   private
      procedure Handler
      with Attach_Handler => Ada.Interrupts.Names.Device_L2_0;
      Routed : Boolean := False;
   end Completion;

   protected body Completion is

      procedure Route is
         use ESP32S3_Registers.INTERRUPT_CORE0;
      begin
         if Routed then
            return;
         end if;
         INTERRUPT_CORE0_Periph.DMA_IN_CH0_INT_MAP.DMA_IN_CH0_INT_MAP := GDMA_CPU_Int;
         INTERRUPT_CORE0_Periph.DMA_IN_CH1_INT_MAP.DMA_IN_CH1_INT_MAP := GDMA_CPU_Int;
         INTERRUPT_CORE0_Periph.DMA_IN_CH2_INT_MAP.DMA_IN_CH2_INT_MAP := GDMA_CPU_Int;
         INTERRUPT_CORE0_Periph.DMA_IN_CH3_INT_MAP.DMA_IN_CH3_INT_MAP := GDMA_CPU_Int;
         INTERRUPT_CORE0_Periph.DMA_IN_CH4_INT_MAP.DMA_IN_CH4_INT_MAP := GDMA_CPU_Int;
         INTERRUPT_CORE0_Periph.DMA_OUT_CH0_INT_MAP.DMA_OUT_CH0_INT_MAP := GDMA_CPU_Int;
         INTERRUPT_CORE0_Periph.DMA_OUT_CH1_INT_MAP.DMA_OUT_CH1_INT_MAP := GDMA_CPU_Int;
         INTERRUPT_CORE0_Periph.DMA_OUT_CH2_INT_MAP.DMA_OUT_CH2_INT_MAP := GDMA_CPU_Int;
         INTERRUPT_CORE0_Periph.DMA_OUT_CH3_INT_MAP.DMA_OUT_CH3_INT_MAP := GDMA_CPU_Int;
         INTERRUPT_CORE0_Periph.DMA_OUT_CH4_INT_MAP.DMA_OUT_CH4_INT_MAP := GDMA_CPU_Int;
         Routed := True;
      end Route;

      procedure Handler is
      begin
         --  For each channel/direction at EOF: DISABLE that EOF enable (this
         --  deasserts the shared level-triggered CPU int while LEAVING the raw
         --  status set, so Done still reads completion) and wake the waiter.
         for C in Channel_Id loop
            if Channels (C).IN_INT_ST.IN_SUC_EOF then
               Channels (C).IN_INT_ENA.IN_SUC_EOF := False;
               Set_True (Done_Signal (C, Periph_To_Mem));
            end if;
            if Channels (C).OUT_INT_ST.OUT_EOF then
               Channels (C).OUT_INT_ENA.OUT_EOF := False;
               Set_True (Done_Signal (C, Mem_To_Periph));
            end if;
         end loop;
      end Handler;

   end Completion;

   --  Timing-event handler: runs at Interrupt_Priority'Last (a separate PO from
   --  Completion, whose ceiling is only Device_L2_Priority).  On the deadline it
   --  force-wakes the matching completion signal; Wait re-checks Done afterwards
   --  to distinguish a real EOF from a timeout.  Set_True is idempotent, so a
   --  timeout racing the EOF interrupt is harmless.
   protected Timeout_Waker
     with Interrupt_Priority => System.Interrupt_Priority'Last
   is
      procedure On_Deadline (Event : in out Timing_Event);
   end Timeout_Waker;

   protected body Timeout_Waker is
      procedure On_Deadline (Event : in out Timing_Event) is
         use type System.Address;
      begin
         for C in Channel_Id loop
            for D in Direction loop
               if Timeout_Ev (C, D)'Address = Event'Address then
                  Set_True (Done_Signal (C, D));
                  return;
               end if;
            end loop;
         end loop;
      end On_Deadline;
   end Timeout_Waker;

   --  Arm a channel's EOF completion interrupt just before its transfer is
   --  kicked: reset the wait signal, clear the stale EOF status, enable the EOF
   --  interrupt.  (RAW=0 + ENA=1 cannot assert until the transfer completes.)
   procedure Arm (Id : Channel_Id; Dir : Direction) is
   begin
      Set_False (Done_Signal (Id, Dir));
      case Dir is
         when Mem_To_Periph =>
            Channels (Id).OUT_INT_CLR.OUT_EOF := True;
            Channels (Id).OUT_INT_ENA.OUT_EOF := True;

         when Periph_To_Mem =>
            Channels (Id).IN_INT_CLR.IN_SUC_EOF := True;
            Channels (Id).IN_INT_ENA.IN_SUC_EOF := True;
      end case;
   end Arm;

   --  Disable a channel's EOF completion interrupt (idempotent).
   procedure Disarm (Id : Channel_Id; Dir : Direction) is
   begin
      case Dir is
         when Mem_To_Periph =>
            Channels (Id).OUT_INT_ENA.OUT_EOF := False;

         when Periph_To_Mem =>
            Channels (Id).IN_INT_ENA.IN_SUC_EOF := False;
      end case;
   end Disarm;

   ----------
   -- Stop --
   ----------

   procedure Stop (C : Channel; Dir : Direction) is
   begin
      if not C.Valid then
         return;
      end if;
      --  Halt the engine and detach the descriptor by pulsing the direction's
      --  reset.  Used on a timeout: otherwise the descriptor still points at the
      --  caller's (often stack) buffer, and a later recovery would DMA stale
      --  bytes into a reused frame.  Also drop the EOF enable.
      case Dir is
         when Mem_To_Periph =>
            Channels (C.Id).OUT_LINK.OUTLINK_STOP := True;
            Channels (C.Id).OUT_CONF0.OUT_RST := True;
            Channels (C.Id).OUT_CONF0.OUT_RST := False;
         when Periph_To_Mem =>
            Channels (C.Id).IN_LINK.INLINK_STOP := True;
            Channels (C.Id).IN_CONF0.IN_RST := True;
            Channels (C.Id).IN_CONF0.IN_RST := False;
      end case;
      Disarm (C.Id, Dir);
   end Stop;

   --------------------------------------------------------------------------
   --  Protected channel allocator.  Serialises Claim / Release and the
   --  one-time module bring-up, so concurrent tasks can never be handed the
   --  same channel.  The transfer operations need no lock: once you hold a
   --  channel, only you touch its registers and descriptors.
   --------------------------------------------------------------------------

   type Use_Map is array (Channel_Id) of Boolean;

   protected Pool is
      procedure Claim (Peri : Peripheral; Id : out Channel_Id; Ok : out Boolean);
      procedure Release (Id : Channel_Id);
   private
      In_Use : Use_Map := (others => False);
      Inited : Boolean := False;
   end Pool;

   protected body Pool is

      procedure Claim (Peri : Peripheral; Id : out Channel_Id; Ok : out Boolean) is
         use ESP32S3_Registers.SYSTEM;
      begin
         --  One-time module bring-up: clock on, reset pulse, AHB master reset.
         if not Inited then
            SYSTEM_Periph.PERIP_CLK_EN1.DMA_CLK_EN := True;
            SYSTEM_Periph.PERIP_RST_EN1.DMA_RST := True;
            SYSTEM_Periph.PERIP_RST_EN1.DMA_RST := False;
            DMA_Periph.MISC_CONF.CLK_EN := True;
            DMA_Periph.MISC_CONF.AHBM_RST_INTER := True;
            DMA_Periph.MISC_CONF.AHBM_RST_INTER := False;
            Inited := True;
         end if;

         for C in Channel_Id loop
            if not In_Use (C) then
               In_Use (C) := True;

               --  Reset both paths, bind the peripheral, set mem2mem loopback.
               Channels (C).IN_CONF0.IN_RST := True;
               Channels (C).IN_CONF0.IN_RST := False;
               Channels (C).OUT_CONF0.OUT_RST := True;
               Channels (C).OUT_CONF0.OUT_RST := False;
               Channels (C).OUT_PERI_SEL.PERI_OUT_SEL := Peri_Sel (Peri);
               Channels (C).IN_PERI_SEL.PERI_IN_SEL := Peri_Sel (Peri);
               Channels (C).IN_CONF0.MEM_TRANS_EN := (Peri = Mem2Mem);

               Id := C;
               Ok := True;
               return;
            end if;
         end loop;

         Id := 0;
         Ok := False;          --  pool exhausted
      end Claim;

      procedure Release (Id : Channel_Id) is
      begin
         Channels (Id).IN_CONF0.MEM_TRANS_EN := False;
         Channels (Id).IN_PERI_SEL.PERI_IN_SEL := Disconnect_Sel;
         Channels (Id).OUT_PERI_SEL.PERI_OUT_SEL := Disconnect_Sel;
         In_Use (Id) := False;
      end Release;

   end Pool;

   -----------
   -- Claim --
   -----------

   procedure Claim (C : in out Channel; Peri : Peripheral) is
      Id : Channel_Id;
      Ok : Boolean;
   begin
      Completion.Route;               --  ensure DMA ints reach CPU_INT 19 (once)
      Release (C);                    --  free any channel C already held
      Pool.Claim (Peri, Id, Ok);
      if Ok then
         C.Id := Id;
         C.Valid := True;
      end if;
   end Claim;

   --------------
   -- Is_Valid --
   --------------

   function Is_Valid (C : Channel) return Boolean
   is (C.Valid);

   -------------
   -- Release --
   -------------

   procedure Release (C : in out Channel) is
   begin
      if C.Valid then
         Pool.Release (C.Id);
         C.Valid := False;
      end if;
   end Release;

   --  Scope-exit / exception-unwind cleanup: return the channel if still held.
   overriding
   procedure Finalize (C : in out Channel) is
   begin
      Release (C);
   end Finalize;

   ----------
   -- Copy --
   ----------

   procedure Copy (C : Channel; Dst, Src : System.Address; Length : Natural) is
   begin
      if not C.Valid or else Length = 0 or else Length > Max_Transfer then
         return;
      end if;

      --  PSRAM coherency + burst, as for Start: flush Src so the DMA reads the
      --  CPU's data; flush Dst clean and record it so Wait invalidates it after
      --  the DMA writes it.
      Channels (C.Id).OUT_CONF0.OUT_DATA_BURST_EN := In_PSRAM (Src);
      Channels (C.Id).OUT_CONF0.OUTDSCR_BURST_EN := In_PSRAM (Src);
      Channels (C.Id).IN_CONF0.IN_DATA_BURST_EN := In_PSRAM (Dst);
      Channels (C.Id).IN_CONF0.INDSCR_BURST_EN := In_PSRAM (Dst);
      if In_PSRAM (Src) then
         Cache_Sync (Src, Length, Invalidate => False);
      end if;
      if In_PSRAM (Dst) then
         Cache_Sync (Dst, Length, Invalidate => False);
         RX_Sync_Buf (C.Id) := Dst;
         RX_Sync_Len (C.Id) := Length;
      else
         RX_Sync_Buf (C.Id) := System.Null_Address;
      end if;

      --  Source (OUT/TX) and destination (IN/RX) descriptors.
      Set_Desc (TX_Desc (C.Id), Src, Length);
      Set_Desc (RX_Desc (C.Id), Dst, Length);

      --  Clear the sticky DONE / error flags from any previous transfer, then
      --  arm the receive-side EOF completion interrupt (clears IN_SUC_EOF too).
      Channels (C.Id).IN_INT_CLR.IN_DONE := True;
      Channels (C.Id).IN_INT_CLR.IN_DSCR_ERR := True;
      Arm (C.Id, Periph_To_Mem);

      --  Barrier: the descriptors above are plain memory writes; make sure they
      --  have committed to SRAM before the DMA (a separate bus master) fetches
      --  them.
      Asm ("memw", Volatile => True, Clobber => "memory");

      --  Mount the links and kick both paths (RX first, then TX feeds it).
      Channels (C.Id).IN_LINK.INLINK_AUTO_RET := False;
      Channels (C.Id).OUT_LINK.OUTLINK_ADDR := Link_Addr (TX_Desc (C.Id)'Address);
      Channels (C.Id).IN_LINK.INLINK_ADDR := Link_Addr (RX_Desc (C.Id)'Address);

      Channels (C.Id).IN_LINK.INLINK_START := True;
      Channels (C.Id).OUT_LINK.OUTLINK_START := True;

      --  Suspend (after a short spin) until the receive side signals EOF.
      Wait (C, Periph_To_Mem);
   end Copy;

   -----------
   -- Start --
   -----------

   procedure Start (C : Channel; Dir : Direction; Buffer : System.Address; Length : Natural) is
   begin
      if not C.Valid or else Length = 0 or else Length > Max_Transfer then
         return;
      end if;

      case Dir is
         when Mem_To_Periph =>
            --  OUT/TX path.  PSRAM access needs data-burst mode, and the DMA reads
            --  from PSRAM -- so flush the CPU's writes to it first.
            Channels (C.Id).OUT_CONF0.OUT_DATA_BURST_EN := In_PSRAM (Buffer);
            Channels (C.Id).OUT_CONF0.OUTDSCR_BURST_EN := In_PSRAM (Buffer);
            if In_PSRAM (Buffer) then
               Cache_Sync (Buffer, Length, Invalidate => False);   --  write back
            end if;
            Set_Desc (TX_Desc (C.Id), Buffer, Length);
            Channels (C.Id).OUT_INT_CLR.OUT_DONE := True;
            Channels (C.Id).OUT_INT_CLR.OUT_DSCR_ERR := True;
            Arm (C.Id, Mem_To_Periph);              --  clears OUT_EOF + enables it
            Asm ("memw", Volatile => True, Clobber => "memory");
            Channels (C.Id).OUT_LINK.OUTLINK_ADDR := Link_Addr (TX_Desc (C.Id)'Address);
            Channels (C.Id).OUT_LINK.OUTLINK_START := True;

         when Periph_To_Mem =>
            --  IN/RX path.  PSRAM access needs data-burst mode; flush first so no
            --  dirty line is later evicted over the DMA data, and record the buffer
            --  so Wait can invalidate it once the DMA has written PSRAM.
            Channels (C.Id).IN_CONF0.IN_DATA_BURST_EN := In_PSRAM (Buffer);
            Channels (C.Id).IN_CONF0.INDSCR_BURST_EN := In_PSRAM (Buffer);
            if In_PSRAM (Buffer) then
               Cache_Sync (Buffer, Length, Invalidate => False);   --  write back (clean)
               RX_Sync_Buf (C.Id) := Buffer;
               RX_Sync_Len (C.Id) := Length;
            else
               RX_Sync_Buf (C.Id) := System.Null_Address;
            end if;
            Set_Desc (RX_Desc (C.Id), Buffer, Length);
            Channels (C.Id).IN_INT_CLR.IN_DONE := True;
            Channels (C.Id).IN_INT_CLR.IN_DSCR_ERR := True;
            Arm (C.Id, Periph_To_Mem);              --  clears IN_SUC_EOF + enables
            Asm ("memw", Volatile => True, Clobber => "memory");
            Channels (C.Id).IN_LINK.INLINK_AUTO_RET := False;
            Channels (C.Id).IN_LINK.INLINK_ADDR := Link_Addr (RX_Desc (C.Id)'Address);
            Channels (C.Id).IN_LINK.INLINK_START := True;
      end case;
   end Start;

   ----------------
   -- Start_Loop --
   ----------------

   procedure Start_Loop (C : Channel; Buffer : System.Address; Length : Natural) is
   begin
      if not C.Valid or else Length = 0 or else Length > Max_Transfer then
         return;
      end if;

      --  Self-linked descriptor: Next points back to itself and Suc_EOF is
      --  clear, so the OUT engine walks it forever.  With OUT_AUTO_WRBACK off
      --  the engine never writes the descriptor back, so Owner stays True and
      --  every pass re-reads Buffer -- a hands-free repeating transfer.
      TX_Desc (C.Id).W0 :=
        (Size    => UInt12 (Length),
         Length  => UInt12 (Length),
         Suc_EOF => False,
         Owner   => True,
         others  => <>);
      TX_Desc (C.Id).Buffer := Buffer;
      TX_Desc (C.Id).Next := TX_Desc (C.Id)'Address;   --  loop to self

      Channels (C.Id).OUT_CONF0.OUT_AUTO_WRBACK := False;
      Channels (C.Id).OUT_INT_CLR.OUT_DONE := True;
      Channels (C.Id).OUT_INT_CLR.OUT_EOF := True;
      Channels (C.Id).OUT_INT_CLR.OUT_DSCR_ERR := True;
      Asm ("memw", Volatile => True, Clobber => "memory");
      Channels (C.Id).OUT_LINK.OUTLINK_ADDR := Link_Addr (TX_Desc (C.Id)'Address);
      Channels (C.Id).OUT_LINK.OUTLINK_START := True;
   end Start_Loop;

   ----------
   -- Done --
   ----------

   function Done (C : Channel; Dir : Direction) return Boolean is
   begin
      if not C.Valid then
         return True;
      end if;
      case Dir is
         when Mem_To_Periph =>
            return Channels (C.Id).OUT_INT_RAW.OUT_EOF;

         when Periph_To_Mem =>
            return Channels (C.Id).IN_INT_RAW.IN_SUC_EOF;
      end case;
   end Done;

   ----------
   -- Wait --
   ----------

   procedure Wait (C : Channel; Dir : Direction) is
      Spin : Natural := 0;
   begin
      if not C.Valid then
         return;
      end if;
      --  Short spin first: a tiny transfer finishes before the interrupt and
      --  context switch would pay off.
      while Spin < Spin_Limit and then not Done (C, Dir) loop
         Spin := Spin + 1;
      end loop;
      --  Still running: hand the core back until the EOF interrupt wakes us.
      --  Arm a deadline timer first so a stuck DMA (EOF that never arrives)
      --  cannot block this task forever: whichever fires first -- the EOF
      --  interrupt (real completion) or the timer -- sets Done_Signal, and we
      --  then cancel the other.  On a timeout Done (C, Dir) stays False, but Wait
      --  returns (unblocks) instead of deadlocking the system.
      if not Done (C, Dir) then
         declare
            Cancelled : Boolean;
         begin
            Set_Handler
              (Timeout_Ev (C.Id, Dir), Clock + Wait_Timeout, Timeout_Waker.On_Deadline'Access);
            Suspend_Until_True (Done_Signal (C.Id, Dir));
            Cancel_Handler (Timeout_Ev (C.Id, Dir), Cancelled);
         end;
      end if;
      if not Done (C, Dir) then
         --  Timed out: halt the engine so it can't later write the caller's
         --  buffer.  (Stop also Disarms.)
         Stop (C, Dir);
      else
         Disarm (C.Id, Dir);   --  completed: just drop the EOF enable
         --  The DMA just wrote PSRAM; invalidate the CPU's stale cached copy so a
         --  read sees the received data (Start/Copy recorded the buffer).
         if Dir = Periph_To_Mem
           and then RX_Sync_Buf (C.Id) /= System.Null_Address
         then
            Cache_Sync (RX_Sync_Buf (C.Id), RX_Sync_Len (C.Id), Invalidate => True);
            RX_Sync_Buf (C.Id) := System.Null_Address;
         end if;
      end if;
   end Wait;

   ---------------
   -- Self_Test --
   ---------------

   function Self_Test (Buf_A, Buf_B : System.Address) return Self_Test_Result is
      Len : constant := 64;
      type Bytes is array (0 .. Len - 1) of Unsigned_8;
      function Pattern (I : Natural) return Unsigned_8
      is (Unsigned_8 ((I * 7 + 3) mod 256));
      A : Bytes with Import, Address => Buf_A;
      B : Bytes with Import, Address => Buf_B;
      C : Channel;
   begin
      Claim (C, Mem2Mem);
      if not Is_Valid (C) then
         return No_Channel;
      end if;
      for I in A'Range loop        --  CPU writes the source (into cache if PSRAM)
         A (I) := Pattern (I);
      end loop;
      B := (others => 0);
      Copy (C, Buf_B, Buf_A, Len);  --  DMA A -> B, with the cache sync under test
      Release (C);
      for I in B'Range loop         --  CPU reads the destination back
         if B (I) /= Pattern (I) then
            return Failed;
         end if;
      end loop;
      return (if In_PSRAM (Buf_A) then Passed_PSRAM else Passed_SRAM);
   end Self_Test;

end ESP32S3.GDMA;
