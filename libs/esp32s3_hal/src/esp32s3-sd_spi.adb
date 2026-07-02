with Interfaces; use Interfaces;
with ESP32S3.GPIO;

package body ESP32S3.SD_SPI is

   use type ESP32S3.SPI.SPI_Host;

   --  SD command numbers (the bare 6-bit index; the frame adds the 0x40 start).
   CMD0   : constant := 0;    --  GO_IDLE_STATE
   CMD8   : constant := 8;    --  SEND_IF_COND
   CMD16  : constant := 16;   --  SET_BLOCKLEN
   CMD17  : constant := 17;   --  READ_SINGLE_BLOCK
   CMD24  : constant := 24;   --  WRITE_BLOCK
   CMD55  : constant := 55;   --  APP_CMD (prefix for ACMDxx)
   CMD58  : constant := 58;   --  READ_OCR
   ACMD41 : constant := 41;   --  SD_SEND_OP_COND

   R1_Idle    : constant Unsigned_8 := 16#01#;   --  in idle state
   R1_Illegal : constant Unsigned_8 := 16#04#;   --  illegal command (=> v1 card)
   Data_Token : constant Unsigned_8 := 16#FE#;   --  single-block start token

   --  DMA scratch, one pair per host (the held SPI Session serialises a host's
   --  use of its pair).  Package-level => lands in .bss = internal SRAM, which
   --  GDMA can reach (a task stack in PSRAM cannot be a DMA target).
   type Buf is array (0 .. 511) of Unsigned_8;
   Tx_Buf : array (ESP32S3.SPI.SPI_Host) of Buf;
   Rx_Buf : array (ESP32S3.SPI.SPI_Host) of Buf;

   ---------------------------------------------------------------------------
   --  Low-level primitives -- all run while the caller holds the host Session.
   ---------------------------------------------------------------------------

   --  Shift N bytes from Tx_Buf out, capturing the same count into Rx_Buf.
   procedure Shift (C : Card; S : ESP32S3.SPI.Session; N : Natural) is
   begin
      ESP32S3.SPI.Transfer (S, Tx_Buf (C.Host)'Address, Rx_Buf (C.Host)'Address, N);
   end Shift;

   --  Clock N idle (0xFF) bytes (card sees MOSI high); ignore what comes back.
   procedure Idle_Clocks (C : Card; S : ESP32S3.SPI.Session; N : Natural) is
   begin
      Tx_Buf (C.Host) (0 .. N - 1) := (others => 16#FF#);
      Shift (C, S, N);
   end Idle_Clocks;

   --  Send one byte, return the byte shifted in alongside it.
   function Swap (C : Card; S : ESP32S3.SPI.Session; B : Unsigned_8) return Unsigned_8 is
   begin
      Tx_Buf (C.Host) (0) := B;
      Shift (C, S, 1);
      return Rx_Buf (C.Host) (0);
   end Swap;

   --  CRC7 of a command frame's first 5 bytes, returned already shifted into the
   --  frame's trailing byte (<<1 | stop bit).  Required for CMD0/CMD8; harmless
   --  (ignored by the card) for the rest, which run with CRC checking off.
   function CRC7_Frame (Cmd : Unsigned_8; Arg : Unsigned_32) return Unsigned_8 is
      Crc : Unsigned_8 := 0;

      procedure Add (B : Unsigned_8) is
         D : Unsigned_8 := B;
      begin
         for I in 1 .. 8 loop
            declare
               In_Bit : constant Unsigned_8 := Shift_Right (D, 7) and 1;
               Hi_Bit : constant Unsigned_8 := Shift_Right (Crc, 6) and 1;
            begin
               D := Shift_Left (D, 1);
               Crc := Shift_Left (Crc, 1) and 16#7F#;
               if (Hi_Bit xor In_Bit) = 1 then
                  Crc := Crc xor 16#09#;          --  poly x^7 + x^3 + 1

               end if;
            end;
         end loop;
      end Add;

   begin
      Add (16#40# or Cmd);
      Add (Unsigned_8 (Shift_Right (Arg, 24) and 16#FF#));
      Add (Unsigned_8 (Shift_Right (Arg, 16) and 16#FF#));
      Add (Unsigned_8 (Shift_Right (Arg, 8) and 16#FF#));
      Add (Unsigned_8 (Arg and 16#FF#));
      return Shift_Left (Crc, 1) or 1;
   end CRC7_Frame;

   --  Issue a 6-byte command and return its R1 response (first byte with bit7=0,
   --  polled for up to 10 bytes).  0xFF means "no response".
   function Command
     (C : Card; S : ESP32S3.SPI.Session; Cmd : Unsigned_8; Arg : Unsigned_32) return Unsigned_8
   is
      T : Buf renames Tx_Buf (C.Host);
      R : Unsigned_8 := 16#FF#;
   begin
      T (0) := 16#FF#;                       --  one gap byte before the frame
      T (1) := 16#40# or Cmd;
      T (2) := Unsigned_8 (Shift_Right (Arg, 24) and 16#FF#);
      T (3) := Unsigned_8 (Shift_Right (Arg, 16) and 16#FF#);
      T (4) := Unsigned_8 (Shift_Right (Arg, 8) and 16#FF#);
      T (5) := Unsigned_8 (Arg and 16#FF#);
      T (6) := CRC7_Frame (Cmd, Arg);
      Shift (C, S, 7);

      for I in 1 .. 10 loop
         R := Swap (C, S, 16#FF#);
         exit when (R and 16#80#) = 0;
      end loop;
      return R;
   end Command;

   ---------------------------------------------------------------------------
   --  Public API.
   ---------------------------------------------------------------------------

   -----------
   -- Setup --
   -----------

   procedure Setup
     (C                    : out Card;
      Host                 : ESP32S3.SPI.SPI_Host;
      Sclk, Mosi, Miso, Cs : ESP32S3.GPIO.Pin_Id;
      Init_Clock_Hz        : Positive := 400_000;
      Data_Clock_Hz        : Positive := 8_000_000) is
   begin
      C.Host := Host;
      C.Cs := Cs;
      C.Kind := Unknown;
      C.Block_Addressed := False;
      C.Init_Hz := Init_Clock_Hz;
      C.Data_Hz := Data_Clock_Hz;

      --  Route clock/data; the SD card's CS is a plain GPIO we drive by hand.
      --  SD is SPI mode 0; the init/data clocks are applied per hold at Acquire.
      ESP32S3.SPI.Setup (Host);
      ESP32S3.SPI.Configure_Pins (Host, Sclk => Sclk, Mosi => Mosi, Miso => Miso);
      ESP32S3.GPIO.Configure (Cs, Mode => ESP32S3.GPIO.Output, Pull => ESP32S3.GPIO.Pull_Up);
      ESP32S3.GPIO.Set (Cs);                 --  deassert (idle high)
   end Setup;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize (C : in out Card; Result : out Status) is
      S    : ESP32S3.SPI.Session;
      R    : Unsigned_8;
      V2   : Boolean := False;
      Done : Boolean := False;
   begin
      C.Kind := Unknown;
      C.Block_Addressed := False;

      ESP32S3.SPI.Acquire (S, C.Host, Clock_Hz => C.Init_Hz);

      --  Power-up: >= 74 clocks with CS and MOSI high puts the card in SPI mode.
      ESP32S3.GPIO.Set (C.Cs);
      Idle_Clocks (C, S, 10);

      ESP32S3.GPIO.Clear (C.Cs);

      --  CMD0: enter idle state.  Expect R1 = 0x01.
      R := Command (C, S, CMD0, 0);
      if R /= R1_Idle then
         ESP32S3.GPIO.Set (C.Cs);
         ESP32S3.SPI.Release (S);
         Result := No_Card;
         return;
      end if;

      --  CMD8: voltage check.  Illegal-command => v1 card; else read the R7 tail
      --  and confirm the 0xAA check pattern echoes back (a real v2 card).
      R := Command (C, S, CMD8, 16#1AA#);
      if (R and R1_Illegal) /= 0 then
         V2 := False;                         --  SD v1.x

      else
         declare
            B3 : Unsigned_8;                   --  3rd / 4th R7 bytes hold the
            B4 : Unsigned_8;                   --  voltage + the 0xAA echo
         begin
            B3 := Swap (C, S, 16#FF#);         --  (1st two R7 bytes ignored)
            B3 := Swap (C, S, 16#FF#);
            B3 := Swap (C, S, 16#FF#);
            B4 := Swap (C, S, 16#FF#);
            if B4 /= 16#AA# then
               ESP32S3.GPIO.Set (C.Cs);
               ESP32S3.SPI.Release (S);
               Result := Unusable;
               return;
            end if;
            V2 := True;
         end;
      end if;

      --  ACMD41 (CMD55 then CMD41) until the card leaves idle.  HCS bit set for
      --  v2 so an SDHC card reports high capacity in the OCR.
      --  ACMD41 argument carries the host's supported voltage window (OCR bits
      --  20..21 = 3.2 .. 3.4 V) alongside HCS: a card that gates on the window
      --  never leaves idle if it is sent as zero.  (Matches the SDMMC driver.)
      for Tries in 1 .. 2000 loop
         R := Command (C, S, CMD55, 0);
         R := Command (C, S, ACMD41, (if V2 then 16#4030_0000# else 16#0030_0000#));
         if R = 0 then
            Done := True;
            exit;
         end if;
      end loop;

      if not Done then
         ESP32S3.GPIO.Set (C.Cs);
         ESP32S3.SPI.Release (S);
         Result := Init_Timeout;
         return;
      end if;

      --  Capacity class: CMD58 OCR bit 30 (CCS) set => block-addressed SDHC/SDXC.
      if V2 then
         R := Command (C, S, CMD58, 0);
         declare
            O0 : constant Unsigned_8 := Swap (C, S, 16#FF#);   --  OCR[31:24]
            O1 : Unsigned_8 := Swap (C, S, 16#FF#);
         begin
            O1 := Swap (C, S, 16#FF#);
            O1 := Swap (C, S, 16#FF#);                          --  consume OCR[7:0]
            C.Block_Addressed := (O0 and 16#40#) /= 0;          --  CCS
            C.Kind := (if C.Block_Addressed then SD_V2_HC else SD_V2_SC);
         end;
      else
         C.Kind := SD_V1;
      end if;

      --  Byte-addressed cards: fix the block length at 512.
      if not C.Block_Addressed then
         R := Command (C, S, CMD16, 512);
      end if;

      ESP32S3.GPIO.Set (C.Cs);
      R := Swap (C, S, 16#FF#);                --  trailing clocks to release MISO
      ESP32S3.SPI.Release (S);

      --  Card is ready; subsequent Read_Block/Write_Block acquire at C.Data_Hz.
      Result := OK;
   end Initialize;

   ----------
   -- Kind --
   ----------

   function Kind (C : Card) return Card_Kind
   is (C.Kind);

   --  Byte vs block addressing: SDHC uses the LBA directly, SDSC needs *512.
   function Card_Arg (C : Card; LBA : Block_Address) return Unsigned_32
   is (if C.Block_Addressed then Unsigned_32 (LBA) else Unsigned_32 (LBA) * 512);

   ----------------
   -- Read_Block --
   ----------------

   procedure Read_Block
     (C : in out Card; LBA : Block_Address; Data : out Block; Result : out Status)
   is
      S         : ESP32S3.SPI.Session;
      R         : Unsigned_8;
      T         : Unsigned_8 := 16#FF#;
      Got_Token : Boolean := False;
   begin
      ESP32S3.SPI.Acquire (S, C.Host, Clock_Hz => C.Data_Hz);
      ESP32S3.GPIO.Clear (C.Cs);

      R := Command (C, S, CMD17, Card_Arg (C, LBA));
      if R /= 0 then
         ESP32S3.GPIO.Set (C.Cs);
         ESP32S3.SPI.Release (S);
         Data := (others => 0);
         Result := Read_Error;
         return;
      end if;

      --  Wait for the data start token (0xFE).  A token with the top nibble
      --  clear but /= 0xFE is an error token.
      for I in 1 .. 4000 loop
         T := Swap (C, S, 16#FF#);
         exit when T = Data_Token;
         if T /= 16#FF# then
            exit;                              --  error token -> bail

         end if;
      end loop;
      Got_Token := (T = Data_Token);

      if not Got_Token then
         ESP32S3.GPIO.Set (C.Cs);
         ESP32S3.SPI.Release (S);
         Data := (others => 0);
         Result := Read_Error;
         return;
      end if;

      --  512 data bytes, then 2 (ignored) CRC bytes.
      Tx_Buf (C.Host) := (others => 16#FF#);
      Shift (C, S, 512);
      Data := Block (Rx_Buf (C.Host));
      R := Swap (C, S, 16#FF#);
      R := Swap (C, S, 16#FF#);

      ESP32S3.GPIO.Set (C.Cs);
      R := Swap (C, S, 16#FF#);                --  trailing clocks
      ESP32S3.SPI.Release (S);
      Result := OK;
   end Read_Block;

   -----------------
   -- Write_Block --
   -----------------

   procedure Write_Block (C : in out Card; LBA : Block_Address; Data : Block; Result : out Status)
   is
      S    : ESP32S3.SPI.Session;
      R    : Unsigned_8;
      Resp : Unsigned_8;
      Busy : Boolean := True;
   begin
      ESP32S3.SPI.Acquire (S, C.Host, Clock_Hz => C.Data_Hz);
      ESP32S3.GPIO.Clear (C.Cs);

      R := Command (C, S, CMD24, Card_Arg (C, LBA));
      if R /= 0 then
         ESP32S3.GPIO.Set (C.Cs);
         ESP32S3.SPI.Release (S);
         Result := Write_Error;
         return;
      end if;

      R := Swap (C, S, 16#FF#);                --  one gap byte before the token
      R := Swap (C, S, Data_Token);            --  start-of-block token

      Tx_Buf (C.Host) := Buf (Data);           --  512 data bytes
      Shift (C, S, 512);

      R := Swap (C, S, 16#FF#);                --  2 dummy CRC bytes
      R := Swap (C, S, 16#FF#);

      --  Data-response byte: bits [4:0] = 0b00101 (0x05) means accepted.
      Resp := Swap (C, S, 16#FF#);
      if (Resp and 16#1F#) /= 16#05# then
         ESP32S3.GPIO.Set (C.Cs);
         ESP32S3.SPI.Release (S);
         Result := Write_Error;
         return;
      end if;

      --  Card holds MISO low (0x00) while it programs; wait for it to release.
      for I in 1 .. 100_000 loop
         if Swap (C, S, 16#FF#) /= 0 then
            Busy := False;
            exit;
         end if;
      end loop;

      ESP32S3.GPIO.Set (C.Cs);
      R := Swap (C, S, 16#FF#);                --  trailing clocks
      ESP32S3.SPI.Release (S);
      Result := (if Busy then Write_Error else OK);
   end Write_Block;

end ESP32S3.SD_SPI;
