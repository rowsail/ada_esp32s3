with Interfaces;                 use Interfaces;
with Ada.Real_Time;
with ESP32S3_Registers;          use ESP32S3_Registers;
with ESP32S3_Registers.SDHOST;   use ESP32S3_Registers.SDHOST;
with ESP32S3_Registers.SYSTEM;
with ESP32S3_Registers.GPIO;
with ESP32S3_Registers.IO_MUX;

package body ESP32S3.SDMMC is

   package GR renames ESP32S3_Registers.GPIO;
   package MX renames ESP32S3_Registers.IO_MUX;

   --  The card-clock source feeding the controller's CLKDIV (PLL160M on the S3).
   --  The card clock = Src_Hz / (2 * divider).  If your bring-up clocks come out
   --  wrong, this is the number to revisit.
   Src_Hz : constant := 160_000_000;

   --  GPIO-matrix signal indices (ESP32-S3 gpio_sig_map.h), per slot.
   type Dat_Sigs is array (0 .. 3) of Natural;
   type Sig_Set is record
      Cclk : Natural;                 --  card clock out
      Ccmd : Natural;                 --  command line (out = in, bidirectional)
      Cdat : Dat_Sigs;                --  data lines D0..D3 (out = in)
   end record;

   Sig : constant array (Slot) of Sig_Set :=
     (Slot1 => (Cclk => 172, Ccmd => 178, Cdat => (180, 181, 182, 183)),
      Slot2 => (Cclk => 173, Ccmd => 179, Cdat => (213, 214, 215, 216)));

   function Card_No (S : Slot) return Natural is (Slot'Pos (S));

   --  Raw views of the registers whose useful bits the SVD lumps into one field.
   RINT : UInt32
     with Volatile, Import, Address => SDHOST_Periph.RINTSTS'Address;
   CDIV : UInt32
     with Volatile, Import, Address => SDHOST_Periph.CLKDIV'Address;
   FIFO : UInt32
     with Volatile, Import, Address => SDHOST_Periph.BUFFIFO'Address;

   --  RINTSTS bit masks (DesignWare mobile-storage host).
   Int_Cmd_Done : constant UInt32 := 16#0004#;   --  command done
   Int_Data_Over: constant UInt32 := 16#0008#;   --  data transfer over (DTO)
   Int_RCRC     : constant UInt32 := 16#0040#;   --  response CRC error
   Int_DCRC     : constant UInt32 := 16#0080#;   --  data CRC error
   Int_RTO      : constant UInt32 := 16#0100#;   --  response timeout
   Int_DRTO     : constant UInt32 := 16#0200#;   --  data read timeout
   Int_HTO      : constant UInt32 := 16#0400#;   --  data starvation by host
   Int_FRUN     : constant UInt32 := 16#0800#;   --  FIFO under/overrun
   Int_EBE      : constant UInt32 := 16#8000#;   --  end-bit error
   Int_Resp_Err : constant UInt32 := 16#0002#;   --  response error
   Data_Err     : constant UInt32 := Int_DCRC or Int_DRTO or Int_HTO or
                                     Int_FRUN or Int_EBE;

   --  Per-operation response words, filled by Issue (guarded by Lock).
   R0, R1w, R2w, R3w : UInt32 := 0;

   type Resp_Kind is (No_Resp, Short_Resp, Short_NoCRC, Long_Resp);
   type Data_Dir  is (No_Data, Read_Data, Write_Data);

   --  Busy-poll deadlines.  These are REAL-TIME bounds, not iteration counts:
   --  at -O2 a tight register-poll loop expires in microseconds -- far short of
   --  a command's response time -- so an iteration count silently gives up
   --  before the response/data arrives.  A wall-clock deadline is independent of
   --  CPU speed and optimisation.  On real silicon the hardware short-circuits
   --  these (the CIU accepts in a few clocks; a missing card raises RTO within
   --  the response timeout), so they only bound the WORST case.
   CIU_Span  : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Milliseconds (50);
   Cmd_Span  : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Milliseconds (250);
   Data_Span : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Milliseconds (1000);
   Busy_Span : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Milliseconds (1000);
   Reg_Span  : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Milliseconds (50);
   ACMD41_Tries : constant := 400;        --  ~SD spec's 1 s power-up budget

   --  True once the wall-clock has passed Deadline (used by the poll loops).
   use type Ada.Real_Time.Time;
   function Past (Deadline : Ada.Real_Time.Time) return Boolean is
     (Ada.Real_Time.Clock >= Deadline);

   ---------------------------------------------------------------------------
   --  GPIO-matrix routing (single-threaded, from Setup).
   ---------------------------------------------------------------------------

   --  Drive matrix signal Sig out onto Pad.
   procedure Route_Out (Pad : ESP32S3.GPIO.Pin_Id; S : Natural) is
      O : GR.FUNC_OUT_SEL_CFG_Register :=
            GR.GPIO_Periph.FUNC_OUT_SEL_CFG (Natural (Pad));
   begin
      ESP32S3.GPIO.Configure (Pad, Mode => ESP32S3.GPIO.Output,
                              Drive => ESP32S3.GPIO.Drive_Strong);
      O.OUT_SEL := GR.FUNC_OUT_SEL_CFG_OUT_SEL_Field (S);
      O.OEN_SEL := False;
      GR.GPIO_Periph.FUNC_OUT_SEL_CFG (Natural (Pad)) := O;
   end Route_Out;

   --  Enable Pad's input buffer (with pull-up) and feed it to matrix input Sig.
   procedure Route_In (S : Natural; Pad : ESP32S3.GPIO.Pin_Id) is
      Ix : constant Natural := Natural (Pad);
      P  : MX.GPIO_Register := MX.IO_MUX_Periph.GPIO (Ix);
   begin
      P.MCU_SEL := 1;
      P.FUN_IE  := True;
      P.FUN_WPU := True;                       --  SD lines idle high
      MX.IO_MUX_Periph.GPIO (Ix) := P;
      GR.GPIO_Periph.FUNC_IN_SEL_CFG (S) :=
        (IN_SEL => GR.FUNC_IN_SEL_CFG_IN_SEL_Field (Ix), SEL => True, others => <>);
   end Route_In;

   --  A bidirectional SD line: both driven out and sampled in, pulled up.
   procedure Route_Bidir (Pad : ESP32S3.GPIO.Pin_Id; S : Natural) is
   begin
      Route_Out (Pad, S);
      Route_In  (S, Pad);
   end Route_Bidir;

   ---------------------------------------------------------------------------
   --  Card-clock programming (the DW "update clock registers only" dance).
   ---------------------------------------------------------------------------

   --  Issue a bare clock-update command and wait for the CIU to take it.
   procedure Clock_Command (Slot_No : Natural) is
   begin
      SDHOST_Periph.CMD :=
        (UPDATE_CLOCK_REGISTERS_ONLY => True,
         WAIT_PRVDATA_COMPLETE       => True,
         CARD_NUMBER                 => CMD_CARD_NUMBER_Field (Slot_No),
         START_CMD                   => True,
         others                      => <>);
      declare
         D : constant Ada.Real_Time.Time := Ada.Real_Time.Clock + Reg_Span;
      begin
         while SDHOST_Periph.CMD.START_CMD loop
            exit when Past (D);
         end loop;
      end;
   end Clock_Command;

   procedure Set_Card_Clock (Slot_No : Natural; Hz : Positive) is
      Div : Natural := Src_Hz / (2 * Hz);
   begin
      if Div < 1 then
         Div := 0;                             --  0 => bypass (cclk = source)
      elsif Div > 255 then
         Div := 255;
      end if;

      SDHOST_Periph.CLKENA.CCLK_ENABLE := 0;   --  stop the clock
      Clock_Command (Slot_No);

      CDIV := UInt32 (Div);               --  divider[0] in the low byte
      SDHOST_Periph.CLKSRC.CLKSRC := 0;        --  every card uses divider 0
      Clock_Command (Slot_No);

      SDHOST_Periph.CLKENA :=
        (CCLK_ENABLE => CLKENA_CCLK_ENABLE_Field (2 ** Slot_No),
         LP_ENABLE   => 0,                     --  keep the clock running when idle
         others      => <>);
      Clock_Command (Slot_No);
   end Set_Card_Clock;

   ---------------------------------------------------------------------------
   --  Command / response.
   ---------------------------------------------------------------------------

   --  Send one command and collect its response into R0..R3w.  Sets up the data
   --  path flags (BLKSIZ/BYTCNT are programmed by the caller before a data cmd).
   function Issue (Index   : Natural;
                   Arg     : UInt32;
                   Resp    : Resp_Kind;
                   Dir     : Data_Dir := No_Data;
                   Slot_No : Natural;
                   Init    : Boolean := False) return Status
   is
   begin
      --  Clear all raw interrupt bits (write 1 to clear).
      RINT := 16#FFFF#;

      SDHOST_Periph.CMDARG := Arg;
      SDHOST_Periph.CMD :=
        (INDEX                 => CMD_INDEX_Field (Index),
         RESPONSE_EXPECT       => Resp /= No_Resp,
         RESPONSE_LENGTH       => Resp = Long_Resp,
         CHECK_RESPONSE_CRC    => Resp in Short_Resp | Long_Resp,
         DATA_EXPECTED         => Dir /= No_Data,
         READ_WRITE            => Dir = Write_Data,
         WAIT_PRVDATA_COMPLETE => True,
         SEND_INITIALIZATION   => Init,
         CARD_NUMBER           => CMD_CARD_NUMBER_Field (Slot_No),
         START_CMD             => True,
         others                => <>);

      --  Wait for the CIU to load the command.
      declare
         D : constant Ada.Real_Time.Time := Ada.Real_Time.Clock + CIU_Span;
      begin
         while SDHOST_Periph.CMD.START_CMD loop
            exit when Past (D);
         end loop;
      end;

      --  Wait for command done (or an error / timeout).
      declare
         D : constant Ada.Real_Time.Time := Ada.Real_Time.Clock + Cmd_Span;
      begin
         while (RINT and (Int_Cmd_Done or Int_RTO)) = 0 loop
            exit when Past (D);
         end loop;
      end;

      if (RINT and Int_RTO) /= 0 then
         RINT := Int_RTO or Int_Cmd_Done;
         return Cmd_Timeout;
      end if;
      if (RINT and Int_Cmd_Done) = 0 then
         --  Poll ran out with no response and no RTO (e.g. an unclocked CIU):
         --  treat as a timeout rather than reading a stale response register.
         return Cmd_Timeout;
      end if;
      if Resp in Short_Resp | Long_Resp and then (RINT and Int_RCRC) /= 0 then
         RINT := Int_RCRC or Int_Cmd_Done or Int_Resp_Err;
         return Cmd_CRC;
      end if;

      R0 := SDHOST_Periph.RESP0;
      if Resp = Long_Resp then
         R1w := SDHOST_Periph.RESP1;
         R2w := SDHOST_Periph.RESP2;
         R3w := SDHOST_Periph.RESP3;
      end if;
      RINT := Int_Cmd_Done or Int_Resp_Err;
      return OK;
   end Issue;

   --  Wait for the card to stop signalling busy (DATA0 held low after R1b/write).
   procedure Wait_Not_Busy is
      D : constant Ada.Real_Time.Time := Ada.Real_Time.Clock + Busy_Span;
   begin
      while SDHOST_Periph.STATUS.DATA_BUSY loop
         exit when Past (D);
      end loop;
   end Wait_Not_Busy;

   ---------------------------------------------------------------------------
   --  PIO data transfer through the FIFO (no DMA).
   ---------------------------------------------------------------------------

   procedure Prepare_Data (Bytes : Natural := 512) is
   begin
      SDHOST_Periph.CTRL.FIFO_RESET := True;
      declare
         D : constant Ada.Real_Time.Time := Ada.Real_Time.Clock + Reg_Span;
      begin
         while SDHOST_Periph.CTRL.FIFO_RESET loop
            exit when Past (D);
         end loop;
      end;
      SDHOST_Periph.BLKSIZ.BLOCK_SIZE := BLKSIZ_BLOCK_SIZE_Field (Bytes);
      SDHOST_Periph.BYTCNT := UInt32 (Bytes);
   end Prepare_Data;

   --  Read N bytes (N <= 64, multiple of 4) of a SMALL data block (SCR, CMD6
   --  switch status) into Buf, big-endian (Buf (0) = first byte on the wire).
   --  The data command must already have been issued with Dir => Read_Data.
   subtype Small_Index is Natural range 0 .. 63;
   type Small_Buf is array (Small_Index) of Unsigned_8;

   function Read_Small (N : Natural; Buf : out Small_Buf) return Status is
      W : UInt32;
   begin
      Buf := (others => 0);
      for Word in 0 .. N / 4 - 1 loop
         declare
            Ready : Boolean := False;
            D     : constant Ada.Real_Time.Time := Ada.Real_Time.Clock + Data_Span;
         begin
            loop
               if (RINT and Data_Err) /= 0 then
                  RINT := Data_Err;
                  return Read_Error;
               end if;
               if not SDHOST_Periph.STATUS.FIFO_EMPTY then
                  Ready := True;
                  exit;
               end if;
               exit when Past (D);
            end loop;
            if not Ready then
               return Read_Error;
            end if;
         end;
         W := FIFO;
         Buf (Word * 4)     := Unsigned_8 (W and 16#FF#);
         Buf (Word * 4 + 1) := Unsigned_8 (Shift_Right (W, 8)  and 16#FF#);
         Buf (Word * 4 + 2) := Unsigned_8 (Shift_Right (W, 16) and 16#FF#);
         Buf (Word * 4 + 3) := Unsigned_8 (Shift_Right (W, 24) and 16#FF#);
      end loop;
      declare
         D : constant Ada.Real_Time.Time := Ada.Real_Time.Clock + Data_Span;
      begin
         while (RINT and (Int_Data_Over or Data_Err)) = 0 loop
            exit when Past (D);
         end loop;
      end;
      if (RINT and Data_Err) /= 0 then
         RINT := Data_Err or Int_Data_Over;
         return Read_Error;
      end if;
      RINT := Int_Data_Over;
      return OK;
   end Read_Small;

   --  Pull 512 bytes (128 words, little-endian) out of the read FIFO.
   function Read_FIFO (Data : out Block) return Status is
      W : UInt32;
   begin
      for Word in 0 .. 127 loop
         declare
            Ready : Boolean := False;
            D     : constant Ada.Real_Time.Time := Ada.Real_Time.Clock + Data_Span;
         begin
            loop
               if (RINT and Data_Err) /= 0 then
                  RINT := Data_Err;
                  Data := (others => 0);
                  return Read_Error;
               end if;
               if not SDHOST_Periph.STATUS.FIFO_EMPTY then
                  Ready := True;
                  exit;
               end if;
               exit when Past (D);
            end loop;
            if not Ready then
               Data := (others => 0);
               return Read_Error;
            end if;
         end;
         W := FIFO;
         Data (Word * 4)     := Unsigned_8 (W and 16#FF#);
         Data (Word * 4 + 1) := Unsigned_8 (Shift_Right (W, 8)  and 16#FF#);
         Data (Word * 4 + 2) := Unsigned_8 (Shift_Right (W, 16) and 16#FF#);
         Data (Word * 4 + 3) := Unsigned_8 (Shift_Right (W, 24) and 16#FF#);
      end loop;

      --  Wait for the data-transfer-over flag.
      declare
         D : constant Ada.Real_Time.Time := Ada.Real_Time.Clock + Data_Span;
      begin
         while (RINT and (Int_Data_Over or Data_Err)) = 0 loop
            exit when Past (D);
         end loop;
      end;
      if (RINT and Data_Err) /= 0 then
         RINT := Data_Err or Int_Data_Over;
         return Read_Error;
      end if;
      RINT := Int_Data_Over;
      return OK;
   end Read_FIFO;

   --  Push 512 bytes (128 words) into the write FIFO.
   function Write_FIFO (Data : Block) return Status is
      W : UInt32;
   begin
      for Word in 0 .. 127 loop
         declare
            Ready : Boolean := False;
            D     : constant Ada.Real_Time.Time := Ada.Real_Time.Clock + Data_Span;
         begin
            loop
               if (RINT and Data_Err) /= 0 then
                  RINT := Data_Err;
                  return Write_Error;
               end if;
               if not SDHOST_Periph.STATUS.FIFO_FULL then
                  Ready := True;
                  exit;
               end if;
               exit when Past (D);
            end loop;
            if not Ready then
               return Write_Error;
            end if;
         end;
         W := UInt32 (Data (Word * 4))
              or Shift_Left (UInt32 (Data (Word * 4 + 1)),  8)
              or Shift_Left (UInt32 (Data (Word * 4 + 2)), 16)
              or Shift_Left (UInt32 (Data (Word * 4 + 3)), 24);
         FIFO := W;
      end loop;

      declare
         D : constant Ada.Real_Time.Time := Ada.Real_Time.Clock + Data_Span;
      begin
         while (RINT and (Int_Data_Over or Data_Err)) = 0 loop
            exit when Past (D);
         end loop;
      end;
      if (RINT and Data_Err) /= 0 then
         RINT := Data_Err or Int_Data_Over;
         return Write_Error;
      end if;
      RINT := Int_Data_Over;
      Wait_Not_Busy;                            --  card programs the block
      return OK;
   end Write_FIFO;

   ---------------------------------------------------------------------------
   --  Whole operations (run under Lock).
   ---------------------------------------------------------------------------

   --  Byte vs block addressing: SDHC uses the LBA directly, SDSC needs *512.
   function Addr_Of (C : Card; LBA : Block_Address) return UInt32 is
     (if C.Block_Addressed
      then UInt32 (LBA)
      else UInt32 (LBA) * 512);

   --  Decode the 8-byte SCR (Buf big-endian) into spec version + bus widths.
   procedure Decode_SCR (C : in out Card; Buf : Small_Buf) is
      Sd_Spec  : constant Natural := Natural (Buf (0) and 16#0F#);   --  [59:56]
      Sd_Spec3 : constant Boolean := (Buf (2) and 16#80#) /= 0;      --  [47]
      Sd_Spec4 : constant Boolean := (Buf (2) and 16#04#) /= 0;      --  [42]
      Sd_Specx : constant Natural :=                                 --  [41:38]
        Natural (Shift_Left (Buf (2) and 16#03#, 2) or Shift_Right (Buf (3), 6));
   begin
      C.Bus_4bit := (Buf (1) and 16#04#) /= 0;     --  SD_BUS_WIDTHS bit 2
      C.Spec_Minor := 0;
      if Sd_Spec = 0 then
         C.Spec_Major := 1;
      elsif Sd_Spec = 1 then
         C.Spec_Major := 1; C.Spec_Minor := 1;
      elsif Sd_Spec = 2 then
         if not Sd_Spec3 then       C.Spec_Major := 2;
         elsif Sd_Specx >= 1 then   C.Spec_Major := 4 + Sd_Specx;  --  5/6/7..
         elsif Sd_Spec4 then        C.Spec_Major := 4;
         else                       C.Spec_Major := 3;
         end if;
      end if;
   end Decode_SCR;

   procedure Do_Initialize (C : in out Card; Result : out Status) is
      N         : constant Natural := Card_No (C.On);
      St        : Status;
      V2        : Boolean := False;
      Responded : Boolean := False;
      Ready     : Boolean := False;
      OCR_Arg   : UInt32;
   begin
      C.Kind := Unknown;
      C.Block_Addressed := False;

      Set_Card_Clock (N, C.Init_Hz);

      --  CMD0: 80 init clocks then go-idle (no response).
      St := Issue (0, 0, No_Resp, Slot_No => N, Init => True);

      --  CMD8: voltage check.  No response => v1 card; else confirm 0xAA echo.
      St := Issue (8, 16#1AA#, Short_Resp, Slot_No => N);
      V2 := (St = OK and then (R0 and 16#FF#) = 16#AA#);

      --  ACMD41 until the card powers up (OCR busy bit 31 set).
      OCR_Arg := (if V2 then 16#4030_0000# else 16#0030_0000#);   --  HCS + 3V3
      for Tries in 1 .. ACMD41_Tries loop
         St := Issue (55, 0, Short_Resp, Slot_No => N);
         St := Issue (41, OCR_Arg, Short_NoCRC, Slot_No => N);
         if St = OK then
            Responded := True;
            if (R0 and 16#8000_0000#) /= 0 then
               Ready := True;
               exit;
            end if;
         end if;
      end loop;

      if not Ready then
         Result := (if Responded then Init_Timeout else No_Card);
         return;
      end if;

      C.Block_Addressed := (R0 and 16#4000_0000#) /= 0;          --  CCS bit
      C.Kind := (if C.Block_Addressed then SDHC else SDSC);

      --  CMD2: read CID (long response: R3w:R2w:R1w:R0 = CID[127:0]).
      St := Issue (2, 0, Long_Resp, Slot_No => N);
      C.CID := (Unsigned_32 (R0), Unsigned_32 (R1w),
                Unsigned_32 (R2w), Unsigned_32 (R3w));

      --  CMD3: publish a relative card address (R6: RCA in the high half-word).
      St := Issue (3, 0, Short_Resp, Slot_No => N);
      if St /= OK then
         Result := St;
         return;
      end if;
      C.RCA := Unsigned_16 (Shift_Right (R0, 16) and 16#FFFF#);

      --  CMD9: read CSD (addressed by RCA, valid in standby -> before CMD7).
      St := Issue (9, Shift_Left (UInt32 (C.RCA), 16), Long_Resp, Slot_No => N);
      C.CSD := (Unsigned_32 (R0), Unsigned_32 (R1w),
                Unsigned_32 (R2w), Unsigned_32 (R3w));

      --  CMD7: select the card (R1b -> may go busy).
      St := Issue (7, Shift_Left (UInt32 (C.RCA), 16), Short_Resp,
                   Slot_No => N);
      Wait_Not_Busy;

      --  Optional 4-bit bus: ACMD6 then set the controller's card width.
      if C.Width = Width_4 then
         St := Issue (55, Shift_Left (UInt32 (C.RCA), 16), Short_Resp,
                      Slot_No => N);
         St := Issue (6, 2, Short_Resp, Slot_No => N);           --  bus width = 4
         SDHOST_Periph.CTYPE.CARD_WIDTH4 :=
           CTYPE_CARD_WIDTH4_Field (2 ** N);
      end if;

      --  CMD16: 512-byte blocks (required for SDSC, harmless for SDHC).
      St := Issue (16, 512, Short_Resp, Slot_No => N);

      --  SCR (ACMD51): SD spec version + supported bus widths (8-byte data read).
      declare
         Buf : Small_Buf;
      begin
         St := Issue (55, Shift_Left (UInt32 (C.RCA), 16), Short_Resp,
                      Slot_No => N);
         Prepare_Data (8);
         St := Issue (51, 0, Short_Resp, Dir => Read_Data, Slot_No => N);
         if St = OK and then Read_Small (8, Buf) = OK then
            Decode_SCR (C, Buf);
         end if;
      end;

      --  CMD6 SWITCH_FUNC: query High-Speed support, optionally switch to it
      --  (64-byte status data read).  Arg bit 31 = 0 check / 1 set; group 1
      --  (access mode) function 1 = High Speed; other groups 0xF = no change.
      declare
         Buf : Small_Buf;
      begin
         Prepare_Data (64);
         St := Issue (6, 16#00FF_FFF1#, Short_Resp, Dir => Read_Data, Slot_No => N);
         if St = OK and then Read_Small (64, Buf) = OK then
            C.HS_Supported := (Buf (13) and 16#02#) /= 0;  --  group 1 function 1
         end if;
         if C.Want_HS and then C.HS_Supported then
            Prepare_Data (64);
            St := Issue (6, 16#80FF_FFF1#, Short_Resp, Dir => Read_Data,
                         Slot_No => N);
            if St = OK and then Read_Small (64, Buf) = OK then
               C.HS_Active := (Buf (16) and 16#0F#) = 1;   --  selected function
            end if;
         end if;
      end;

      --  Raise the clock: High Speed allows up to 50 MHz, else the 25 MHz limit.
      declare
         Cap : constant Positive :=
           (if C.HS_Active then 50_000_000 else 25_000_000);
      begin
         C.Active_Hz := Positive'Min (C.Data_Hz, Cap);
      end;
      Set_Card_Clock (N, C.Active_Hz);
      Result := OK;
   end Do_Initialize;

   procedure Do_Read (C : in out Card; LBA : Block_Address;
                      Data : out Block; Result : out Status) is
      N  : constant Natural := Card_No (C.On);
      St : Status;
   begin
      Prepare_Data;
      St := Issue (17, Addr_Of (C, LBA), Short_Resp, Dir => Read_Data,
                   Slot_No => N);
      if St /= OK then
         Data := (others => 0);
         Result := St;
         return;
      end if;
      Result := Read_FIFO (Data);
   end Do_Read;

   procedure Do_Write (C : in out Card; LBA : Block_Address;
                       Data : Block; Result : out Status) is
      N  : constant Natural := Card_No (C.On);
      St : Status;
   begin
      Prepare_Data;
      St := Issue (24, Addr_Of (C, LBA), Short_Resp, Dir => Write_Data,
                   Slot_No => N);
      if St /= OK then
         Result := St;
         return;
      end if;
      Result := Write_FIFO (Data);
   end Do_Write;

   ---------------------------------------------------------------------------
   --  The single shared controller -- one protected object serialises it.
   ---------------------------------------------------------------------------

   protected Lock is
      procedure Initialize (C : in out Card; Result : out Status);
      procedure Read  (C : in out Card; LBA : Block_Address;
                       Data : out Block; Result : out Status);
      procedure Write (C : in out Card; LBA : Block_Address;
                       Data : Block; Result : out Status);
   end Lock;

   protected body Lock is
      procedure Initialize (C : in out Card; Result : out Status) is
      begin
         Do_Initialize (C, Result);
      end Initialize;

      procedure Read (C : in out Card; LBA : Block_Address;
                      Data : out Block; Result : out Status) is
      begin
         Do_Read (C, LBA, Data, Result);
      end Read;

      procedure Write (C : in out Card; LBA : Block_Address;
                       Data : Block; Result : out Status) is
      begin
         Do_Write (C, LBA, Data, Result);
      end Write;
   end Lock;

   ---------------------------------------------------------------------------
   --  Public API.
   ---------------------------------------------------------------------------

   procedure Setup (C             : out Card;
                    On            : Slot;
                    Clk, Cmd, D0  : ESP32S3.GPIO.Pin_Id;
                    D1, D2, D3    : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
                    Width         : Bus_Width := Width_1;
                    Init_Clock_Hz : Positive := 400_000;
                    Data_Clock_Hz : Positive := 20_000_000;
                    High_Speed    : Boolean  := False)
   is
      use ESP32S3_Registers.SYSTEM;
      use type ESP32S3.GPIO.Pad_Number;
      S : constant Sig_Set := Sig (On);
      N : constant Natural := Card_No (On);
   begin
      C.On      := On;
      C.Width   := Width;
      C.Init_Hz := Init_Clock_Hz;
      C.Data_Hz := Data_Clock_Hz;
      C.Kind    := Unknown;
      C.RCA     := 0;
      C.Block_Addressed := False;
      C.CID     := (others => 0);
      C.CSD     := (others => 0);
      C.Want_HS      := High_Speed;
      C.HS_Supported := False;
      C.HS_Active    := False;
      C.Active_Hz    := 0;
      C.Spec_Major   := 0;
      C.Spec_Minor   := 0;
      C.Bus_4bit     := False;

      --  Peripheral clock + release reset.
      SYSTEM_Periph.PERIP_CLK_EN1.SDIO_HOST_CLK_EN := True;
      SYSTEM_Periph.PERIP_RST_EN1.SDIO_HOST_RST    := True;
      SYSTEM_Periph.PERIP_RST_EN1.SDIO_HOST_RST    := False;

      --  Reset the controller, FIFO and DMA blocks.
      SDHOST_Periph.CTRL :=
        (CONTROLLER_RESET => True, FIFO_RESET => True, DMA_RESET => True,
         others => <>);
      declare
         D : constant Ada.Real_Time.Time := Ada.Real_Time.Clock + Reg_Span;
      begin
         while SDHOST_Periph.CTRL.CONTROLLER_RESET
           or else SDHOST_Periph.CTRL.FIFO_RESET
         loop
            exit when Past (D);
         end loop;
      end;

      --  Generous response/data timeouts; conservative FIFO watermarks.
      SDHOST_Periph.TMOUT := (RESPONSE_TIMEOUT => 16#FF#,
                              DATA_TIMEOUT => 16#FFFFFF#, others => <>);
      SDHOST_Periph.FIFOTH := (TX_WMARK => 8, RX_WMARK => 7,
                               DMA_MULTIPLE_TRANSACTION_SIZE => 0, others => <>);
      SDHOST_Periph.RST_N.CARD_RESET := RST_N_CARD_RESET_Field (2 ** N);
      SDHOST_Periph.CTYPE := (others => <>);    --  start 1-bit; widened at init
      SDHOST_Periph.INTMASK := (others => <>);  --  poll, no interrupts
      RINT := 16#FFFF#;                         --  clear stale raw ints

      --  Route the slot's lines through the GPIO matrix.
      Route_Out   (Clk, S.Cclk);                --  clock: output only
      Route_Bidir (Cmd, S.Ccmd);                --  command: bidirectional
      Route_Bidir (D0,  S.Cdat (0));
      if D1 /= ESP32S3.GPIO.No_Pin then
         Route_Bidir (ESP32S3.GPIO.Pin_Id (D1), S.Cdat (1));
      end if;
      if D2 /= ESP32S3.GPIO.No_Pin then
         Route_Bidir (ESP32S3.GPIO.Pin_Id (D2), S.Cdat (2));
      end if;
      if D3 /= ESP32S3.GPIO.No_Pin then
         Route_Bidir (ESP32S3.GPIO.Pin_Id (D3), S.Cdat (3));
      end if;

      --  Start the card clock slow for the identification phase.
      Set_Card_Clock (N, Init_Clock_Hz);
   end Setup;

   procedure Initialize (C : in out Card; Result : out Status) is
   begin
      Lock.Initialize (C, Result);
   end Initialize;

   function Kind (C : Card) return Card_Kind is (C.Kind);

   --  Extract Width bits (<= 32) starting at bit Lo from a 128-bit register
   --  (word 0 = bits [31:0]).  Fields may straddle a 32-bit word boundary.
   function Field (R : Reg128; Lo, Width : Natural) return Unsigned_32 is
      W    : constant Natural := Lo / 32;
      Off  : constant Natural := Lo mod 32;
      Low  : constant Unsigned_64 := Unsigned_64 (R (W));
      High : constant Unsigned_64 :=
        (if W < 3 then Unsigned_64 (R (W + 1)) else 0);
      V    : constant Unsigned_64 :=
        Shift_Right (Low or Shift_Left (High, 32), Off);
      Mask : constant Unsigned_64 :=
        (if Width >= 32 then 16#FFFF_FFFF#
         else Shift_Left (Unsigned_64 (1), Width) - 1);
   begin
      return Unsigned_32 (V and Mask);
   end Field;

   --------------
   -- Identity --
   --------------

   function Identity (C : Card) return Card_Id is
      function F (Lo, W : Natural) return Unsigned_32 is (Field (C.CID, Lo, W));
      function Ch (Lo : Natural) return Character is
        (Character'Val (Natural (F (Lo, 8))));
      Id : Card_Id;
   begin
      Id.Manufacturer   := Unsigned_8 (F (120, 8));        --  MID
      Id.OEM            := (Ch (112), Ch (104));           --  OID (2 ASCII)
      Id.Product        := (Ch (96), Ch (88), Ch (80), Ch (72), Ch (64));  --  PNM
      Id.Revision_Major := Natural (F (60, 4));            --  PRV high nibble
      Id.Revision_Minor := Natural (F (56, 4));            --  PRV low nibble
      Id.Serial         := F (24, 32);                     --  PSN
      Id.Mfg_Month      := Natural (F (8, 4));             --  MDT month
      Id.Mfg_Year       := 2000 + Natural (F (12, 8));     --  MDT year
      return Id;
   end Identity;

   ---------------------
   -- Capacity_Blocks --
   ---------------------

   function Capacity_Blocks (C : Card) return Unsigned_64 is
      Structure : constant Unsigned_32 := Field (C.CSD, 126, 2);
   begin
      if Structure = 1 then
         --  CSD v2 (SDHC/SDXC): capacity = (C_SIZE + 1) * 512 KB = * 1024 blocks.
         return (Unsigned_64 (Field (C.CSD, 48, 22)) + 1) * 1024;
      else
         --  CSD v1 (SDSC): bytes = (C_SIZE+1) * 2**(C_SIZE_MULT+2) * 2**READ_BL_LEN.
         declare
            C_Size : constant Unsigned_64 := Unsigned_64 (Field (C.CSD, 62, 12));
            C_Mult : constant Natural     := Natural (Field (C.CSD, 47, 3));
            Rd_Len : constant Natural     := Natural (Field (C.CSD, 80, 4));
            Bytes  : constant Unsigned_64 :=
              (C_Size + 1) * Shift_Left (Unsigned_64 (1), C_Mult + 2)
              * Shift_Left (Unsigned_64 (1), Rd_Len);
         begin
            return Bytes / 512;
         end;
      end if;
   end Capacity_Blocks;

   ------------------
   -- Capabilities --
   ------------------

   function Capabilities (C : Card) return Card_Caps is
      --  TRAN_SPEED [103:96]: bits [2:0] = rate unit, [6:3] = time value index.
      TS   : constant Unsigned_32 := Field (C.CSD, 96, 8);
      Unit : constant array (0 .. 3) of Natural :=
        (100, 1_000, 10_000, 100_000);                       --  kbit/s
      Mult : constant array (0 .. 15) of Natural :=          --  x10 (avoid frac)
        (0, 10, 12, 13, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 70, 80);
      U    : constant Natural := Natural (TS and 7);
      M    : constant Natural := Natural (Shift_Right (TS, 3) and 16#F#);
      Caps : Card_Caps;
   begin
      Caps.Max_Speed_MHz   := Unit (U) * Mult (M) / 10 / 1000;
      Caps.Command_Classes := Unsigned_16 (Field (C.CSD, 84, 12));   --  CCC
      Caps.Read_Block_Len  := 2 ** Natural (Field (C.CSD, 80, 4));   --  READ_BL_LEN
      Caps.Spec_Major      := C.Spec_Major;                          --  SCR
      Caps.Spec_Minor      := C.Spec_Minor;
      Caps.Supports_4bit   := C.Bus_4bit;
      Caps.High_Speed      := C.HS_Supported;                        --  CMD6
      return Caps;
   end Capabilities;

   function High_Speed_Active (C : Card) return Boolean is (C.HS_Active);
   function Active_Clock_Hz   (C : Card) return Natural is (C.Active_Hz);

   procedure Read_Block (C : in out Card; LBA : Block_Address;
                         Data : out Block; Result : out Status) is
   begin
      Lock.Read (C, LBA, Data, Result);
   end Read_Block;

   procedure Write_Block (C : in out Card; LBA : Block_Address;
                          Data : Block; Result : out Status) is
   begin
      Lock.Write (C, LBA, Data, Result);
   end Write_Block;

end ESP32S3.SDMMC;
