------------------------------------------------------------------------------
--  esp_flash  --  flash an ESP32-S3 over its serial / USB-JTAG ROM bootloader,
--  an Ada replacement for `esptool --chip esp32s3 -p PORT write_flash`.
--  ROM commands only (no stub, no compression): reset into download, SYNC,
--  SPI attach + set-params, then per file flash_begin / flash_data* / flash_end,
--  then a hard reset to run.  Stage 1 here: serial + SLIP + reset + SYNC.
------------------------------------------------------------------------------
with Ada.Command_Line; use Ada.Command_Line;
with Ada.Text_IO;      use Ada.Text_IO;
with Ada.Streams.Stream_IO;
with Ada.Streams;
with Interfaces;       use Interfaces;
with Interfaces.C;
with System;
with Board;                  --  single source of truth: Flash_Size

procedure Esp_Flash is

   use type Interfaces.C.int;

   --  ---- POSIX serial via direct libc bindings (no C source) --------------
   use type Interfaces.C.unsigned;
   --  Linux/glibc constants (stable ABI; verified against the system headers).
   O_RDWR     : constant Interfaces.C.int := 2;
   O_NOCTTY   : constant Interfaces.C.int := 8#400#;        --  0x100
   O_NONBLOCK : constant Interfaces.C.int := 8#4000#;       --  0x800
   TCSANOW    : constant Interfaces.C.int := 0;
   B115200    : constant Interfaces.C.unsigned := 16#1002#;
   CLOCAL     : constant Interfaces.C.unsigned := 16#800#;
   CREAD      : constant Interfaces.C.unsigned := 16#80#;
   CRTSCTS    : constant Interfaces.C.unsigned := 16#8000_0000#;
   VTIME_Idx  : constant := 5;
   VMIN_Idx   : constant := 6;
   POLLIN     : constant Interfaces.C.short := 1;
   TIOCMBIS   : constant Interfaces.C.unsigned_long := 16#5416#;
   TIOCMBIC   : constant Interfaces.C.unsigned_long := 16#5417#;
   TIOCMSET   : constant Interfaces.C.unsigned_long := 16#5418#;
   TIOCM_DTR  : constant Interfaces.C.int := 16#0002#;
   TIOCM_RTS  : constant Interfaces.C.int := 16#0004#;

   type Cc_Array is array (0 .. 31) of Interfaces.C.unsigned_char;   --  NCCS = 32
   type Termios is record
      --  glibc layout
      C_Iflag, C_Oflag, C_Cflag, C_Lflag : Interfaces.C.unsigned;
      C_Line                             : Interfaces.C.unsigned_char;
      C_Cc                               : Cc_Array;
      C_Ispeed, C_Ospeed                 : Interfaces.C.unsigned;
   end record
   with Convention => C;

   type Pollfd is record
      Fd              : Interfaces.C.int;
      Events, Revents : Interfaces.C.short;
   end record
   with Convention => C;

   function C_Open
     (Path : Interfaces.C.char_array; Flags : Interfaces.C.int) return Interfaces.C.int
   with Import, Convention => C, External_Name => "open";
   function C_Close (Fd : Interfaces.C.int) return Interfaces.C.int
   with Import, Convention => C, External_Name => "close";
   function C_Read
     (Fd : Interfaces.C.int; Buf : System.Address; N : Interfaces.C.size_t)
      return Interfaces.C.long
   with Import, Convention => C, External_Name => "read";
   function C_Write
     (Fd : Interfaces.C.int; Buf : System.Address; N : Interfaces.C.size_t)
      return Interfaces.C.long
   with Import, Convention => C, External_Name => "write";
   function C_Ioctl
     (Fd : Interfaces.C.int; Req : Interfaces.C.unsigned_long; Arg : System.Address)
      return Interfaces.C.int
   with Import, Convention => C, External_Name => "ioctl";
   function C_Poll
     (Fds : System.Address; N : Interfaces.C.unsigned_long; Timeout : Interfaces.C.int)
      return Interfaces.C.int
   with Import, Convention => C, External_Name => "poll";
   function C_Tcgetattr (Fd : Interfaces.C.int; T : System.Address) return Interfaces.C.int
   with Import, Convention => C, External_Name => "tcgetattr";
   function C_Tcsetattr (Fd, Act : Interfaces.C.int; T : System.Address) return Interfaces.C.int
   with Import, Convention => C, External_Name => "tcsetattr";
   procedure C_Cfmakeraw (T : System.Address)
   with Import, Convention => C, External_Name => "cfmakeraw";
   function C_Cfsetispeed (T : System.Address; Sp : Interfaces.C.unsigned) return Interfaces.C.int
   with Import, Convention => C, External_Name => "cfsetispeed";
   function C_Cfsetospeed (T : System.Address; Sp : Interfaces.C.unsigned) return Interfaces.C.int
   with Import, Convention => C, External_Name => "cfsetospeed";

   function Sp_Open (Path : Interfaces.C.char_array) return Interfaces.C.int
   is (C_Open (Path, O_RDWR + O_NOCTTY + O_NONBLOCK));   --  flags are disjoint bits

   function Sp_Setup (Fd : Interfaces.C.int) return Interfaces.C.int is
      T : aliased Termios;
   begin
      if C_Tcgetattr (Fd, T'Address) /= 0 then
         return -1;
      end if;
      C_Cfmakeraw (T'Address);
      if C_Cfsetispeed (T'Address, B115200) /= 0 then
         null;
      end if;
      if C_Cfsetospeed (T'Address, B115200) /= 0 then
         null;
      end if;
      T.C_Cc (VMIN_Idx) := 0;
      T.C_Cc (VTIME_Idx) := 0;
      T.C_Cflag := (T.C_Cflag or CLOCAL or CREAD) and not CRTSCTS;
      return C_Tcsetattr (Fd, TCSANOW, T'Address);
   end Sp_Setup;

   procedure Sp_Modem (Fd : Interfaces.C.int; On : Boolean; Bit : Interfaces.C.int) is
      B : aliased Interfaces.C.int := Bit;
   begin
      if C_Ioctl (Fd, (if On then TIOCMBIS else TIOCMBIC), B'Address) /= 0 then
         null;
      end if;
   end Sp_Modem;
   procedure Sp_Dtr (Fd, On : Interfaces.C.int) is
   begin
      Sp_Modem (Fd, On /= 0, TIOCM_DTR);
   end;
   procedure Sp_Rts (Fd, On : Interfaces.C.int) is
   begin
      Sp_Modem (Fd, On /= 0, TIOCM_RTS);
   end;

   --  Set DTR and RTS in ONE ioctl (TIOCMSET) so the classic two-transistor
   --  auto-reset doesn't glitch through an intermediate state -- as esptool's
   --  UnixTightReset does on Linux.
   procedure Sp_Dtr_Rts (Fd : Interfaces.C.int; Dtr, Rts : Boolean) is
      M : aliased Interfaces.C.int :=
        (if Dtr then TIOCM_DTR else 0) + (if Rts then TIOCM_RTS else 0);
   begin
      if C_Ioctl (Fd, TIOCMSET, M'Address) /= 0 then
         null;
      end if;
   end Sp_Dtr_Rts;

   function Sp_Read
     (Fd : Interfaces.C.int; Buf : System.Address; N, Timeout_Ms : Interfaces.C.int)
      return Interfaces.C.int
   is
      P : aliased Pollfd := (Fd => Fd, Events => POLLIN, Revents => 0);
      R : constant Interfaces.C.int := C_Poll (P'Address, 1, Timeout_Ms);
   begin
      if R <= 0 then
         return R;
      end if;
      return Interfaces.C.int (C_Read (Fd, Buf, Interfaces.C.size_t (N)));
   end Sp_Read;

   function Sp_Write
     (Fd : Interfaces.C.int; Buf : System.Address; N : Interfaces.C.int) return Interfaces.C.int
   is (Interfaces.C.int (C_Write (Fd, Buf, Interfaces.C.size_t (N))));

   procedure Sp_Close (Fd : Interfaces.C.int) is
   begin
      if C_Close (Fd) /= 0 then
         null;
      end if;
   end Sp_Close;

   type Bytes is array (Natural range <>) of Unsigned_8;

   Fd         : Interfaces.C.int;
   No_Reset   : Boolean := False;     --  --no-reset: leave chip in download mode
   Monitor    : Boolean := False;     --  --monitor: after reset-to-run, stream the
   --  console to stdout WITHOUT closing the port
   --  (so the reset doesn't re-enumerate USB and
   --  the app runs once, captured from the start)
   Port_Idx   : Natural := 0;         --  argument index of the port
   Flash_Size : Unsigned_32 :=
     Unsigned_32 (Board.Flash_Size);  --  --flash-size, default from board.ads
   type Flash_Pair is record
      Off      : Unsigned_32;
      File_Idx : Natural;
   end record;
   Pairs      : array (1 .. 32) of Flash_Pair;
   N_Pairs    : Natural := 0;

   --  ---- low-level byte I/O with a small input buffer ---------------------
   In_Buf : Bytes (0 .. 4095);
   In_Len : Natural := 0;
   In_Pos : Natural := 0;

   --  one byte, refilling from the port; returns -1 on timeout
   function Get_Byte (Timeout_Ms : Integer) return Integer is
   begin
      if In_Pos >= In_Len then
         declare
            R : constant Interfaces.C.int :=
              Sp_Read (Fd, In_Buf'Address, In_Buf'Length, Interfaces.C.int (Timeout_Ms));
         begin
            if R <= 0 then
               return -1;
            end if;
            In_Len := Natural (R);
            In_Pos := 0;
         end;
      end if;
      declare
         B : constant Unsigned_8 := In_Buf (In_Pos);
      begin
         In_Pos := In_Pos + 1;
         return Integer (B);
      end;
   end Get_Byte;

   procedure Write_Raw (Data : Bytes) is
      R : Interfaces.C.int;
      pragma Unreferenced (R);
   begin
      if Data'Length > 0 then
         R := Sp_Write (Fd, Data'Address, Data'Length);
      end if;
   end Write_Raw;

   procedure Msleep (Ms : Integer) is
   begin
      delay Duration (Ms) / 1000.0;
   end Msleep;

   --  ---- SLIP framing ------------------------------------------------------
   C0 : constant := 16#C0#;
   DB : constant := 16#DB#;

   procedure Slip_Write (Payload : Bytes) is
      Out_B : Bytes (0 .. Payload'Length * 2 + 1);
      O     : Natural := 0;
   begin
      Out_B (O) := C0;
      O := O + 1;
      for X of Payload loop
         if X = C0 then
            Out_B (O) := DB;
            Out_B (O + 1) := 16#DC#;
            O := O + 2;
         elsif X = DB then
            Out_B (O) := DB;
            Out_B (O + 1) := 16#DD#;
            O := O + 2;
         else
            Out_B (O) := X;
            O := O + 1;
         end if;
      end loop;
      Out_B (O) := C0;
      O := O + 1;
      Write_Raw (Out_B (0 .. O - 1));
   end Slip_Write;

   --  read one SLIP frame into Buf; returns its length, or -1 on timeout
   function Slip_Read (Buf : in out Bytes; Timeout_Ms : Integer) return Integer is
      B : Integer;
      N : Natural := 0;
   begin
      --  skip until a frame start
      loop
         B := Get_Byte (Timeout_Ms);
         if B < 0 then
            return -1;
         end if;
         exit when B = C0;
      end loop;
      --  read until the closing C0, unescaping; ignore empty (back-to-back C0)
      loop
         B := Get_Byte (Timeout_Ms);
         if B < 0 then
            return -1;
         end if;
         if B = C0 then
            if N = 0 then
               null;                       --  leading delimiter run; keep reading

            else
               return N;
            end if;
         elsif B = DB then
            B := Get_Byte (Timeout_Ms);
            if B < 0 then
               return -1;
            end if;
            if B = 16#DC# then
               Buf (N) := C0;
            else
               Buf (N) := DB;
            end if;
            N := N + 1;
         else
            Buf (N) := Unsigned_8 (B);
            N := N + 1;
         end if;
      end loop;
   end Slip_Read;

   --  ---- the request/response command protocol -----------------------------
   --  Build <BBHI> (dir=0, op, len, chk) + data, send, await a matching reply.
   --  On success returns True and sets Val + the (status-stripped) reply Data.
   function Command
     (Op         : Unsigned_8;
      Data       : Bytes;
      Chk        : Unsigned_32;
      Timeout_Ms : Integer;
      Val        : out Unsigned_32) return Boolean
   is
      Pkt : Bytes (0 .. 7 + Data'Length);
      Rb  : Bytes (0 .. 4095);
   begin
      Pkt (0) := 0;
      Pkt (1) := Op;
      Pkt (2) := Unsigned_8 (Unsigned_32 (Data'Length) and 16#FF#);
      Pkt (3) := Unsigned_8 (Shift_Right (Unsigned_32 (Data'Length), 8) and 16#FF#);
      Pkt (4) := Unsigned_8 (Chk and 16#FF#);
      Pkt (5) := Unsigned_8 (Shift_Right (Chk, 8) and 16#FF#);
      Pkt (6) := Unsigned_8 (Shift_Right (Chk, 16) and 16#FF#);
      Pkt (7) := Unsigned_8 (Shift_Right (Chk, 24) and 16#FF#);
      if Data'Length > 0 then
         Pkt (8 .. Pkt'Last) := Data;
      end if;
      Slip_Write (Pkt);

      Val := 0;
      for Retry in 1 .. 100 loop
         declare
            L : constant Integer := Slip_Read (Rb, Timeout_Ms);
         begin
            exit when L < 0;
            if L >= 8 and then Rb (0) = 1 and then Rb (1) = Op then
               Val :=
                 Unsigned_32 (Rb (4))
                 or Shift_Left (Unsigned_32 (Rb (5)), 8)
                 or Shift_Left (Unsigned_32 (Rb (6)), 16)
                 or Shift_Left (Unsigned_32 (Rb (7)), 24);
               --  status bytes (2) at the end of the data: byte0 = error flag
               if L >= 10 and then Rb (L - 2) /= 0 then
                  return False;             --  command reported an error

               end if;
               return True;
            end if;
         end;
      end loop;
      return False;
   end Command;

   --  Two reset circuits exist in the wild and need different DTR/RTS dances:
   --  the built-in USB-Serial-JTAG (VID 303a) decodes the lines on-chip, while
   --  an external USB-UART bridge (CH343/CP210x/FT231) drives EN/GPIO0 through
   --  the classic two-transistor auto-reset.  The board type isn't known up
   --  front, so provide both and let the connect loop alternate -- a wrong
   --  guess just leaves the chip running and the next attempt re-resets it.

   --  Built-in USB-Serial-JTAG: the (1,1) transitions matter (matches esptool's
   --  UnixTightReset for USB-JTAG).
   procedure Reset_Usb_Jtag is
   begin
      Sp_Rts (Fd, 0);
      Sp_Dtr (Fd, 0);
      Msleep (100);
      Sp_Dtr (Fd, 1);
      Sp_Rts (Fd, 0);
      Msleep (100);
      Sp_Rts (Fd, 1);
      Sp_Dtr (Fd, 0);
      Sp_Rts (Fd, 1);
      Msleep (100);
      Sp_Dtr (Fd, 0);
      Sp_Rts (Fd, 0);
      In_Len := 0;
      In_Pos := 0;             --  drop any boot noise
   end Reset_Usb_Jtag;

   --  External USB-UART bridge with the classic auto-reset (DTR -> GPIO0,
   --  RTS -> EN, inverted by the transistors): matches esptool's UnixTightReset
   --  -- both lines change together (TIOCMSET), with priming transitions.
   procedure Reset_Classic is
   begin
      Sp_Dtr_Rts (Fd, False, False);
      Sp_Dtr_Rts (Fd, True, True);
      Sp_Dtr_Rts (Fd, False, True);   --  IO0 high, EN low: held in reset
      Msleep (100);
      Sp_Dtr_Rts (Fd, True, False);  --  IO0 low, EN high: out of reset -> dl
      Msleep (50);
      Sp_Dtr_Rts (Fd, False, False);  --  release both
      In_Len := 0;
      In_Pos := 0;             --  drop any boot noise
   end Reset_Classic;

   function Sync return Boolean is
      --  SYNC payload: 0x07 0x07 0x12 0x20 then 32 x 0x55
      P  : constant Bytes (0 .. 35) :=
        (0 => 16#07#, 1 => 16#07#, 2 => 16#12#, 3 => 16#20#, others => 16#55#);
      V  : Unsigned_32;
      Ok : Boolean;
   begin
      Ok := Command (16#08#, P, 0, 100, V);
      if Ok then
         for I in 1 .. 7 loop
            --  drain the extra sync replies
            declare
               Junk : Bytes (0 .. 255);
            begin
               exit when Slip_Read (Junk, 50) < 0;
            end;
         end loop;
      end if;
      return Ok;
   end Sync;

   --  ---- flash protocol ----------------------------------------------------
   Flash_Block_Sz : constant := 16#400#;

   function U32_Hex (V : Unsigned_32) return String is
      H : constant String := "0123456789abcdef";
      S : String (1 .. 8);
      X : Unsigned_32 := V;
   begin
      for I in reverse S'Range loop
         S (I) := H (Natural (X and 16#F#) + 1);
         X := Shift_Right (X, 4);
      end loop;
      return S;
   end U32_Hex;

   function Parse_Hex (S : String) return Unsigned_32 is
      V : Unsigned_32 := 0;
      I : Natural := S'First;
   begin
      if S'Length > 2
        and then S (S'First) = '0'
        and then (S (S'First + 1) = 'x' or S (S'First + 1) = 'X')
      then
         I := S'First + 2;
      end if;
      while I <= S'Last loop
         declare
            D : Unsigned_32;
         begin
            case S (I) is
               when '0' .. '9' =>
                  D := Character'Pos (S (I)) - Character'Pos ('0');

               when 'a' .. 'f' =>
                  D := Character'Pos (S (I)) - Character'Pos ('a') + 10;

               when 'A' .. 'F' =>
                  D := Character'Pos (S (I)) - Character'Pos ('A') + 10;

               when others     =>
                  exit;
            end case;
            V := V * 16 + D;
         end;
         I := I + 1;
      end loop;
      return V;
   end Parse_Hex;

   --  size like 2MB / 8MB / 0x400000 / 4194304 (suffix K/M/G optional)
   function Parse_Size (S : String) return Unsigned_32 is
      V    : Unsigned_32 := 0;
      Base : Unsigned_32 := 10;
      I    : Natural := S'First;
   begin
      if S'Length >= 2
        and then S (S'First) = '0'
        and then (S (S'First + 1) = 'x' or S (S'First + 1) = 'X')
      then
         Base := 16;
         I := S'First + 2;
      end if;
      while I <= S'Last loop
         declare
            C : constant Character := S (I);
            D : Unsigned_32;
         begin
            if C in '0' .. '9' then
               D := Character'Pos (C) - Character'Pos ('0');
            elsif Base = 16 and then C in 'a' .. 'f' then
               D := Character'Pos (C) - Character'Pos ('a') + 10;
            elsif Base = 16 and then C in 'A' .. 'F' then
               D := Character'Pos (C) - Character'Pos ('A') + 10;
            else
               exit;                          --  reached the K/M/G suffix
            end if;
            V := V * Base + D;
         end;
         I := I + 1;
      end loop;
      if I <= S'Last then
         case S (I) is
            when 'k' | 'K' =>
               V := V * 16#400#;

            when 'm' | 'M' =>
               V := V * 16#10_0000#;

            when 'g' | 'G' =>
               V := V * 16#4000_0000#;

            when others    =>
               null;
         end case;
      end if;
      return V;
   end Parse_Size;

   function Checksum (Data : Bytes) return Unsigned_8 is
      C : Unsigned_8 := 16#EF#;
   begin
      for X of Data loop
         C := C xor X;
      end loop;
      return C;
   end Checksum;

   procedure Put_U32 (B : in out Bytes; Off : Natural; V : Unsigned_32) is
   begin
      B (Off) := Unsigned_8 (V and 16#FF#);
      B (Off + 1) := Unsigned_8 (Shift_Right (V, 8) and 16#FF#);
      B (Off + 2) := Unsigned_8 (Shift_Right (V, 16) and 16#FF#);
      B (Off + 3) := Unsigned_8 (Shift_Right (V, 24) and 16#FF#);
   end Put_U32;

   function Cmd (Op : Unsigned_8; Data : Bytes; Timeout_Ms : Integer) return Boolean is
      V : Unsigned_32;
   begin
      return Command (Op, Data, 0, Timeout_Ms, V);
   end Cmd;

   function Spi_Attach return Boolean is
      P : constant Bytes (0 .. 7) := (others => 0);   --  <II> 0, 0
   begin
      return Cmd (16#0D#, P, 3000);
   end Spi_Attach;

   function Spi_Set_Params (Flash_Size : Unsigned_32) return Boolean is
      P : Bytes (0 .. 23);                              --  <IIIIII>
   begin
      Put_U32 (P, 0, 0);
      Put_U32 (P, 4, Flash_Size);
      Put_U32 (P, 8, 16#1_0000#);
      Put_U32 (P, 12, 16#1000#);
      Put_U32 (P, 16, 16#100#);
      Put_U32 (P, 20, 16#FFFF#);
      return Cmd (16#0B#, P, 3000);
   end Spi_Set_Params;

   type Byte_Ptr is access Bytes;
   function Read_File (Name : String) return Byte_Ptr is
      use Ada.Streams, Ada.Streams.Stream_IO;
      F    : Ada.Streams.Stream_IO.File_Type;
      Last : Stream_Element_Offset;
   begin
      Open (F, In_File, Name);
      declare
         Len : constant Natural := Natural (Size (F));
         B   : constant Byte_Ptr := new Bytes (0 .. Natural'Max (Len, 1) - 1);
         SE  : Stream_Element_Array (0 .. Stream_Element_Offset (Natural'Max (Len, 1)) - 1);
      begin
         if Len > 0 then
            Read (F, SE, Last);
            for I in 0 .. Len - 1 loop
               B (I) := Unsigned_8 (SE (Stream_Element_Offset (I)));
            end loop;
         end if;
         Close (F);
         return B;
      end;
   end Read_File;

   function Flash_File (Offset : Unsigned_32; Name : String) return Boolean is
      Img    : constant Byte_Ptr := Read_File (Name);
      Sz     : constant Natural := Img.all'Length;
      Blocks : constant Natural := (Sz + Flash_Block_Sz - 1) / Flash_Block_Sz;
      Hdr    : Bytes (0 .. 19);
   begin
      Put_Line
        ("[esp_flash] "
         & Name
         & " -> 0x"
         & U32_Hex (Offset)
         & " ("
         & Natural'Image (Sz)
         & " B,"
         & Natural'Image (Blocks)
         & " blk)");
      Put_U32 (Hdr, 0, Unsigned_32 (Sz));
      Put_U32 (Hdr, 4, Unsigned_32 (Blocks));
      Put_U32 (Hdr, 8, Flash_Block_Sz);
      Put_U32 (Hdr, 12, Offset);
      Put_U32 (Hdr, 16, 0);                    --  not encrypted
      if not Cmd (16#02#, Hdr, 15000) then
         Put_Line (Standard_Error, "  flash_begin failed");
         return False;
      end if;
      for Seq in 0 .. Blocks - 1 loop
         declare
            Pay : Bytes (0 .. 15 + Flash_Block_Sz);
            Blk : Bytes (0 .. Flash_Block_Sz - 1) := (others => 16#FF#);
            Lo  : constant Natural := Seq * Flash_Block_Sz;
            N   : constant Natural := Natural'Min (Flash_Block_Sz, Sz - Lo);
            V   : Unsigned_32;
         begin
            for I in 0 .. N - 1 loop
               Blk (I) := Img (Lo + I);
            end loop;
            Put_U32 (Pay, 0, Flash_Block_Sz);
            Put_U32 (Pay, 4, Unsigned_32 (Seq));
            Put_U32 (Pay, 8, 0);
            Put_U32 (Pay, 12, 0);
            Pay (16 .. Pay'Last) := Blk;
            if not Command (16#03#, Pay, Unsigned_32 (Checksum (Blk)), 5000, V) then
               Put_Line (Standard_Error, "  flash_data failed at block" & Natural'Image (Seq));
               return False;
            end if;
         end;
      end loop;
      return True;
   end Flash_File;

   function Flash_Finish return Boolean is
      P : Bytes (0 .. 3);
   begin
      Put_U32 (P, 0, 1);                       --  stay; we hard-reset to run
      return Cmd (16#04#, P, 3000);
   end Flash_Finish;

   procedure Hard_Reset is
   begin
      Sp_Dtr (Fd, 0);
      Sp_Rts (Fd, 1);
      Msleep (100);
      Sp_Rts (Fd, 0);
   end Hard_Reset;

   --  Stream the running app's console to stdout until the ACATS driver prints
   --  "batch complete" (the RTC-WDT sweeps even crashers/hangs to the end, so it
   --  always arrives) or Idle_Limit of console silence.  The port stays open the
   --  whole time (no Sp_Close, no re-enumeration), so we capture the single
   --  post-reset run from its first byte -- unlike an external monitor that must
   --  re-open after the flasher closed the port (USB-JTAG re-enumerates on reset).
   procedure Monitor_Run is
      Target     : constant String := "batch complete";
      Mpos       : Natural := 0;
      Idle_Ms    : Natural := 0;
      Idle_Limit : constant Natural := 90_000;     --  90 s silence -> done/wedged
      B          : Integer;
      C          : Character;
   begin
      In_Len := 0;
      In_Pos := 0;                    --  drop stale ROM/flash bytes
      loop
         B := Get_Byte (1000);
         if B < 0 then
            Idle_Ms := Idle_Ms + 1000;
            exit when Idle_Ms >= Idle_Limit;
         else
            Idle_Ms := 0;
            C := Character'Val (B);
            Ada.Text_IO.Put (C);
            if C = Character'Val (10) then
               Ada.Text_IO.Flush;
            end if;
            if C = Target (Target'First + Mpos) then
               Mpos := Mpos + 1;
               if Mpos = Target'Length then
                  Ada.Text_IO.Flush;
                  return;
               end if;
            elsif C = Target (Target'First) then
               Mpos := 1;
            else
               Mpos := 0;
            end if;
         end if;
      end loop;
      Ada.Text_IO.Flush;
   end Monitor_Run;

begin
   declare
      I : Natural := 1;
   begin
      while I <= Argument_Count loop
         declare
            A : constant String := Argument (I);
         begin
            if A = "-p" and then I < Argument_Count then
               Port_Idx := I + 1;
               I := I + 2;
            elsif (A = "--flash-size" or A = "-fs") and then I < Argument_Count then
               Flash_Size := Parse_Size (Argument (I + 1));
               I := I + 2;
            elsif A = "--no-reset" then
               No_Reset := True;
               I := I + 1;
            elsif A = "--monitor" then
               Monitor := True;
               I := I + 1;
            elsif A'Length > 0 and then A (A'First) in '0' .. '9' and then I < Argument_Count then
               --  <offset> <file> pair
               N_Pairs := N_Pairs + 1;
               Pairs (N_Pairs) := (Off => Parse_Hex (A), File_Idx => I + 1);
               I := I + 2;
            elsif Port_Idx = 0 then
               Port_Idx := I;
               I := I + 1;       --  positional port
            else
               Put_Line (Standard_Error, "unexpected argument: " & A);
               Set_Exit_Status (2);
               return;
            end if;
         end;
      end loop;
   end;

   if Port_Idx = 0 or N_Pairs = 0 then
      Put_Line
        (Standard_Error,
         "usage: esp_flash [-p] <port> [--flash-size SZ] [--no-reset|--monitor]"
         & " <offset> <file> [<offset> <file> ...]");
      Set_Exit_Status (2);
      return;
   end if;

   Fd := Sp_Open (Interfaces.C.To_C (Argument (Port_Idx)));
   if Fd < 0 then
      Put_Line (Standard_Error, "cannot open " & Argument (Port_Idx));
      Set_Exit_Status (1);
      return;
   end if;
   if Sp_Setup (Fd) /= 0 then
      Put_Line (Standard_Error, "serial setup failed");
      Set_Exit_Status (1);
      return;
   end if;

   --  connect: reset into download + sync, a few attempts
   declare
      Connected : Boolean := False;
   begin
      for Attempt in 1 .. 8 loop
         if Attempt mod 2 = 1 then
            Reset_Usb_Jtag;        --  built-in USB-Serial-JTAG (VID 303a)

         else
            Reset_Classic;         --  external USB-UART bridge (CH343/CP210x)
         end if;
         --  The ROM needs a moment to come up after reset and may miss the
         --  first SYNC, so poll it a few times before re-resetting (esptool
         --  does the same -- this is what makes the bridge boards reliable).
         for S in 1 .. 6 loop
            if Sync then
               Connected := True;
               exit;
            end if;
            Msleep (50);
         end loop;
         exit when Connected;
      end loop;
      if not Connected then
         Put_Line (Standard_Error, "[esp_flash] SYNC failed (no response from ROM)");
         Sp_Close (Fd);
         Set_Exit_Status (1);
         return;
      end if;
      Put_Line ("[esp_flash] connected (ROM bootloader)");
   end;

   if not Spi_Attach then
      Put_Line (Standard_Error, "spi_attach failed");
      Sp_Close (Fd);
      Set_Exit_Status (1);
      return;
   end if;
   if not Spi_Set_Params (Flash_Size) then
      Put_Line (Standard_Error, "spi_set_params failed");
      Sp_Close (Fd);
      Set_Exit_Status (1);
      return;
   end if;

   --  flash each parsed (offset, file) pair
   declare
      Ok : Boolean := True;
   begin
      for K in 1 .. N_Pairs loop
         Ok := Flash_File (Pairs (K).Off, Argument (Pairs (K).File_Idx));
         exit when not Ok;
      end loop;
      if Ok then
         Ok := Flash_Finish;
      end if;
      if not Ok then
         Put_Line (Standard_Error, "[esp_flash] FAILED");
         Sp_Close (Fd);
         Set_Exit_Status (1);
         return;
      end if;
      if Monitor then
         Put_Line (Standard_Error, "[esp_flash] done; resetting to run + monitoring");
         Hard_Reset;
         Monitor_Run;                  --  port stays open across the reset
      elsif No_Reset then
         Put_Line ("[esp_flash] done (left in download mode; --no-reset)");
      else
         Put_Line ("[esp_flash] done; resetting to run");
         Hard_Reset;
      end if;
   end;

   Sp_Close (Fd);
exception
   when others =>
      Put_Line (Standard_Error, "[esp_flash] error (file not found or I/O failure)");
      Set_Exit_Status (1);
end Esp_Flash;
