with Ada.Real_Time;

package body ESP32S3.Esp_Loader is

   use type Ada.Real_Time.Time;

   --  ---- SLIP ---------------------------------------------------------
   Frame_End      : constant Interfaces.Unsigned_8 := 16#C0#;
   Escape         : constant Interfaces.Unsigned_8 := 16#DB#;
   Escaped_End    : constant Interfaces.Unsigned_8 := 16#DC#;
   Escaped_Escape : constant Interfaces.Unsigned_8 := 16#DD#;

   --  ---- opcodes ------------------------------------------------------
   Op_Flash_Begin : constant Interfaces.Unsigned_8 := 16#02#;
   Op_Flash_Data  : constant Interfaces.Unsigned_8 := 16#03#;
   Op_Flash_End   : constant Interfaces.Unsigned_8 := 16#04#;
   Op_Sync        : constant Interfaces.Unsigned_8 := 16#08#;
   Op_Read_Reg    : constant Interfaces.Unsigned_8 := 16#0A#;
   Op_Spi_Params  : constant Interfaces.Unsigned_8 := 16#0B#;
   Op_Spi_Attach  : constant Interfaces.Unsigned_8 := 16#0D#;
   Op_Change_Baud : constant Interfaces.Unsigned_8 := 16#0F#;
   Op_Flash_Md5   : constant Interfaces.Unsigned_8 := 16#13#;
   Op_Security    : constant Interfaces.Unsigned_8 := 16#14#;

   --  Where every ESP ROM parks its chip-identification magic.
   Chip_Magic_Register : constant Interfaces.Unsigned_32 := 16#4000_1000#;

   --  Identification is quick or not happening: do not spend a whole command
   --  timeout discovering that an older ROM lacks GET_SECURITY_INFO.
   Detect_Timeout_Ms : constant := 500;

   --  Reply length of GET_SECURITY_INFO on chips that report a chip-id.  The
   --  ESP32-S2 answers a short form (12) with no id.
   Security_With_Id : constant := 20;

   --  Erase geometry the ESP8266's FLASH_BEGIN workaround is written in.
   Flash_Sector_Bytes  : constant := 4096;
   Sectors_Per_Block   : constant := 16;

   --  ---- timing -------------------------------------------------------
   --  Erasing the region FLASH_BEGIN covers is much the slowest step, hence
   --  its own long budget; the rest answer promptly or not at all.
   Sync_Timeout_Ms  : constant := 100;
   Short_Timeout_Ms : constant := 3_000;
   Write_Timeout_Ms : constant := 5_000;
   Erase_Timeout_Ms : constant := 30_000;
   Md5_Timeout_Ms   : constant := 30_000;

   Connect_Attempts : constant := 8;    --  reset-and-try-again rounds
   Sync_Attempts    : constant := 6;    --  SYNCs per round before re-resetting
   Reply_Attempts   : constant :=
     100;  --  frames to skip while hunting a reply

   procedure Pause (Milliseconds : Natural) is
   begin
      delay Duration (Milliseconds) / 1000.0;
   end Pause;

   ---------------------------------------------------------------------------
   --  Outgoing bytes
   ---------------------------------------------------------------------------

   procedure Flush (S : in out Session) is
   begin
      if S.Out_Len > 0 and then S.Over.Send /= null then
         S.Over.Send (S.Over.Ctx, S.Out_Buf (1 .. S.Out_Len));
      end if;
      S.Out_Len := 0;
   end Flush;

   procedure Emit (S : in out Session; Value : Interfaces.Unsigned_8) is
   begin
      if S.Out_Len = S.Out_Buf'Last then
         Flush (S);
      end if;
      S.Out_Len := S.Out_Len + 1;
      S.Out_Buf (S.Out_Len) := Value;
   end Emit;

   --  One payload byte, escaped as SLIP requires.
   procedure Emit_Escaped (S : in out Session; Value : Interfaces.Unsigned_8)
   is
   begin
      if Value = Frame_End then
         Emit (S, Escape);
         Emit (S, Escaped_End);
      elsif Value = Escape then
         Emit (S, Escape);
         Emit (S, Escaped_Escape);
      else
         Emit (S, Value);
      end if;
   end Emit_Escaped;

   procedure Emit_Escaped (S : in out Session; Data : Byte_Array) is
   begin
      for Value of Data loop
         Emit_Escaped (S, Value);
      end loop;
   end Emit_Escaped;

   ---------------------------------------------------------------------------
   --  Incoming bytes
   ---------------------------------------------------------------------------

   --  One byte, refilling from the transport.  Found is False on timeout.
   procedure Get_Byte
     (S          : in out Session;
      Timeout_Ms : Natural;
      Value      : out Interfaces.Unsigned_8;
      Found      : out Boolean)
   is
      Last : Natural;
   begin
      Value := 0;

      if S.In_Pos > S.In_Len then
         if S.Over.Receive = null then
            Found := False;
            return;
         end if;
         S.Over.Receive (S.Over.Ctx, S.In_Buf, Last, Timeout_Ms);
         if Last < S.In_Buf'First then
            S.In_Len := 0;
            S.In_Pos := 1;
            Found := False;
            return;
         end if;
         S.In_Len := Last;
         S.In_Pos := S.In_Buf'First;
      end if;

      Value := S.In_Buf (S.In_Pos);
      S.In_Pos := S.In_Pos + 1;
      Found := True;
   end Get_Byte;

   procedure Drop_Input (S : in out Session) is
   begin
      S.In_Len := 0;
      S.In_Pos := 1;
   end Drop_Input;

   --  Read one SLIP frame.  Length is the unescaped payload size, 0 with Found
   --  False on timeout.  A frame longer than the buffer is dropped rather than
   --  truncated: a truncated frame would parse as a plausible short one.
   procedure Read_Frame
     (S          : in out Session;
      Into       : out Byte_Array;
      Length     : out Natural;
      Timeout_Ms : Natural;
      Found      : out Boolean)
   is
      Value     : Interfaces.Unsigned_8;
      Got       : Boolean;
      Started   : Boolean := False;   --  a delimiter has been seen
      Overflown : Boolean := False;   --  this frame is too big for Into

      --  An OVERALL deadline, not just a per-byte one.
      --
      --  Timeout_Ms bounds the wait for the next byte, which bounds nothing at
      --  all when the target never stops talking -- and the target this matters
      --  most for is a BLANK one, which reboots forever printing "invalid
      --  header: 0xffffffff".  Its chatter contains no frame, so Found never
      --  becomes True, and no byte ever fails to arrive, so the loop below ran
      --  until the board was power-cycled.  A programmer meets blank targets
      --  as a matter of routine, so this is the normal case, not a corner.
      --
      --  Timeout_Ms is what the caller means by "wait this long for a reply",
      --  so spend it in total rather than per byte.
      Deadline : constant Ada.Real_Time.Time :=
        Ada.Real_Time.Clock + Ada.Real_Time.Milliseconds (Timeout_Ms);
   begin
      Length := 0;
      Found := False;

      loop
         if Ada.Real_Time.Clock >= Deadline then
            return;                    --  chatter, or a frame that never ended
         end if;

         Get_Byte (S, Timeout_Ms, Value, Got);
         if not Got then
            return;
         end if;

         if Value = Frame_End then
            if not Started then
               Started := True;              --  opens the first frame
            elsif Overflown then
               --  Drop it whole rather than truncate: a truncated frame would
               --  parse as a plausible short one.  This same delimiter opens
               --  the next frame.
               Length := 0;
               Overflown := False;
            elsif Length > 0 then
               Found := True;
               return;
            end if;
         --  Otherwise a run of delimiters between frames -- keep reading.

         elsif Started then
            if Value = Escape then
               Get_Byte (S, Timeout_Ms, Value, Got);
               if not Got then
                  return;
               end if;
               Value := (if Value = Escaped_End then Frame_End else Escape);
            end if;

            if Length < Into'Length then
               Length := Length + 1;
               Into (Into'First + Length - 1) := Value;
            else
               Overflown := True;
            end if;
         end if;
         --  Bytes before the first delimiter are the target's boot chatter.
      end loop;
   end Read_Frame;

   ---------------------------------------------------------------------------
   --  Commands
   ---------------------------------------------------------------------------

   procedure Put_32
     (Data     : in out Byte_Array;
      At_Index : Positive;
      Value    : Interfaces.Unsigned_32) is
   begin
      for I in 0 .. 3 loop
         Data (At_Index + I) :=
           Interfaces.Unsigned_8
             (Interfaces.Shift_Right (Value, 8 * I) and 16#FF#);
      end loop;
   end Put_32;

   function Get_32
     (Data : Byte_Array; At_Index : Positive) return Interfaces.Unsigned_32
   is (Interfaces.Unsigned_32 (Data (At_Index))
       or Interfaces.Shift_Left
            (Interfaces.Unsigned_32 (Data (At_Index + 1)), 8)
       or Interfaces.Shift_Left
            (Interfaces.Unsigned_32 (Data (At_Index + 2)), 16)
       or Interfaces.Shift_Left
            (Interfaces.Unsigned_32 (Data (At_Index + 3)), 24));

   --  The ROM's payload checksum: a seeded XOR over the DATA of a FLASH_DATA
   --  block only.  Every other command sends zero here.
   function Block_Checksum (Data : Byte_Array) return Interfaces.Unsigned_32 is
      Sum : Interfaces.Unsigned_8 := 16#EF#;
   begin
      for Value of Data loop
         Sum := Sum xor Value;
      end loop;
      return Interfaces.Unsigned_32 (Sum);
   end Block_Checksum;

   --  Send one command and wait for the matching reply.  Header and Payload go
   --  out as one frame (the split only spares the caller from concatenating a
   --  kilobyte block onto its 16-byte header).
   procedure Command
     (S          : in out Session;
      Op         : Interfaces.Unsigned_8;
      Header     : Byte_Array;
      Payload    : Byte_Array;
      Checksum   : Interfaces.Unsigned_32;
      Timeout_Ms : Natural;
      Value      : out Interfaces.Unsigned_32;
      Reply      : out Byte_Array;
      Reply_Len  : out Natural;
      Status     : out Status_Kind)
   is
      Length : constant Interfaces.Unsigned_32 :=
        Interfaces.Unsigned_32 (Header'Length + Payload'Length);
      Prefix : Byte_Array (1 .. 8);
      Frame  : Byte_Array (1 .. In_Frame);
      Got    : Natural;
      Found  : Boolean;
   begin
      Value := 0;
      Reply_Len := 0;
      Status := No_Response;

      Prefix (1) :=
        0;                                     --  direction: request
      Prefix (2) := Op;
      Prefix (3) := Interfaces.Unsigned_8 (Length and 16#FF#);
      Prefix (4) :=
        Interfaces.Unsigned_8 (Interfaces.Shift_Right (Length, 8) and 16#FF#);
      Put_32 (Prefix, 5, Checksum);

      Emit (S, Frame_End);
      Emit_Escaped (S, Prefix);
      Emit_Escaped (S, Header);
      Emit_Escaped (S, Payload);
      Emit (S, Frame_End);
      Flush (S);

      --  The target may still be emitting boot text, and a stale reply to an
      --  earlier retry can arrive first, so skip frames until one answers THIS
      --  opcode.
      for Attempt in 1 .. Reply_Attempts loop
         Read_Frame (S, Frame, Got, Timeout_Ms, Found);
         exit when not Found;

         if Got >= 8 and then Frame (1) = 1 and then Frame (2) = Op then
            Value := Get_32 (Frame, 5);

            --  The reply ends with the status bytes, the first of which is
            --  the error flag.  How MANY there are is per-chip -- four on the
            --  original ESP32's ROM, two everywhere else -- which is why
            --  Connect identifies the target before anything else is sent.
            if Got >= 8 + S.Status_Bytes
              and then Frame (Got - S.Status_Bytes + 1) /= 0
            then
               Status := Target_Refused;
               return;
            end if;

            --  What the caller gets back is the DATA, with the status bytes
            --  taken off, so a reply reads the same on every chip.
            if Got > 8 + S.Status_Bytes then
               Reply_Len :=
                 Natural'Min (Got - 8 - S.Status_Bytes, Reply'Length);
               Reply (Reply'First .. Reply'First + Reply_Len - 1) :=
                 Frame (9 .. 8 + Reply_Len);
            end if;
            Status := Ok;
            return;
         end if;
      end loop;
   end Command;

   --  A command with nothing to say back.
   procedure Simple_Command
     (S          : in out Session;
      Op         : Interfaces.Unsigned_8;
      Header     : Byte_Array;
      Timeout_Ms : Natural;
      Status     : out Status_Kind)
   is
      Nothing : constant Byte_Array (1 .. 0) := (others => 0);
      Reply   : Byte_Array (1 .. 4);
      Value   : Interfaces.Unsigned_32;
      Got     : Natural;
   begin
      Command
        (S, Op, Header, Nothing, 0, Timeout_Ms, Value, Reply, Got, Status);
   end Simple_Command;

   ---------------------------------------------------------------------------
   --  Identifying the target
   ---------------------------------------------------------------------------

   --  The chip-id every ROM since the ESP32-S3 reports through
   --  GET_SECURITY_INFO -- the same numbers that identify a chip in an
   --  application image header.
   function From_Chip_Id (Id : Interfaces.Unsigned_32) return Chip_Kind
   is (case Id is
         when 0 => Esp32,
         when 2 => Esp32_S2,
         when 5 => Esp32_C3,
         when 9 => Esp32_S3,
         when 12 => Esp32_C2,
         when 13 => Esp32_C6,
         when 16 => Esp32_H2,
         when 18 => Esp32_P4,
         when 20 => Esp32_C61,
         when 23 => Esp32_C5,
         when 25 => Esp32_H21,
         when 28 => Esp32_H4,
         when 31 => Esp32_E22,
         when 32 => Esp32_S31,
         when others => Unknown);

   --  The older identification: a value the ROM leaves in a fixed register.
   --  Several chips have more than one, across silicon revisions.
   --
   --  The ESP32-P4's published magic is 0 -- which is also what a mis-read or
   --  an unimplemented register gives back -- so it is deliberately NOT listed.
   --  The P4 reports a chip-id through GET_SECURITY_INFO, which is how it gets
   --  identified; guessing "P4" from a zero would be worse than Unknown,
   --  because Unknown still drives a modern target correctly.
   function From_Magic (Magic : Interfaces.Unsigned_32) return Chip_Kind
   is (case Magic is
         when 16#FFF0_C101# => Esp8266,
         when 16#00F0_1D83# => Esp32,
         when 16#0000_07C6# => Esp32_S2,
         when 16#0000_0009# | 16#EB00_4136# => Esp32_S3,
         when 16#6921_506F# | 16#1B31_506F#
            | 16#4881_606F# | 16#4361_606F# => Esp32_C3,
         when 16#6F51_306F# | 16#7C41_A06F# => Esp32_C2,
         when 16#2CE0_806F# | 16#0DA1_806F# => Esp32_C6,
         when 16#D7B7_3E80# | 16#CA26_CC22#
            | 16#6881_B06F# => Esp32_H2,
         when others => Unknown);

   procedure Detect (S : in out Session) is
      Nothing : constant Byte_Array (1 .. 0) := (others => 0);
      Reply   : Byte_Array (1 .. Security_With_Id);
      Value   : Interfaces.Unsigned_32;
      Got     : Natural;
      Result  : Status_Kind;
   begin
      S.Kind := Unknown;
      S.Status_Bytes := Default_Status_Bytes;

      --  Ask the modern way first.  Chips from the ESP32-S3 on report a
      --  chip-id here; the ESP32 ROM has no such command at all and the
      --  ESP32-S2 answers a short form with no id -- both fall through.
      Command
        (S, Op_Security, Nothing, Nothing, 0, Detect_Timeout_Ms, Value, Reply,
         Got, Result);
      if Result = Ok and then Got >= Security_With_Id then
         S.Kind := From_Chip_Id (Get_32 (Reply, 13));
      end if;

      --  Otherwise the magic register, which is the only way to tell an
      --  ESP8266, an ESP32 or an ESP32-S2 apart.
      if S.Kind = Unknown then
         declare
            Header : Byte_Array (1 .. 4);
            Magic  : Interfaces.Unsigned_32;
         begin
            Put_32 (Header, 1, Chip_Magic_Register);
            Command
              (S, Op_Read_Reg, Header, Nothing, 0, Detect_Timeout_Ms, Magic,
               Reply, Got, Result);
            if Result = Ok then
               S.Kind := From_Magic (Magic);
            end if;
         end;
      end if;

      --  The difference that changes how replies are PARSED, so it has to be
      --  settled before any further command goes out.
      S.Status_Bytes := (if S.Kind = Esp32 then 4 else Default_Status_Bytes);
   end Detect;

   ---------------------------------------------------------------------------
   --  Connecting
   ---------------------------------------------------------------------------

   procedure Set_Line
     (Line : Line_Proc; Ctx : System.Address; Asserted : Boolean) is
   begin
      if Line /= null then
         Line (Ctx, Asserted);
      end if;
   end Set_Line;

   procedure Reset_Target (Over : Link; Into_Download : Boolean := False) is
   begin
      --  IO0 is sampled as the target leaves reset, so it must already be
      --  settled before reset is released, and must stay put long enough
      --  afterwards for the ROM to have latched it.
      Set_Line (Over.Assert_Boot, Over.Ctx, Into_Download);
      Set_Line (Over.Assert_Reset, Over.Ctx, True);
      Pause (100);
      Set_Line (Over.Assert_Reset, Over.Ctx, False);
      Pause (50);
      Set_Line (Over.Assert_Boot, Over.Ctx, False);
   end Reset_Target;

   --  SYNC: a fixed pattern the ROM echoes.  It answers this one several
   --  times over, so the extras are drained rather than left to be mistaken
   --  for the reply to whatever comes next.
   procedure Sync (S : in out Session; Status : out Status_Kind) is
      Pattern : constant Byte_Array (1 .. 36) :=
        (1 => 16#07#, 2 => 16#07#, 3 => 16#12#, 4 => 16#20#, others => 16#55#);
      Junk    : Byte_Array (1 .. In_Frame);
      Got     : Natural;
      Found   : Boolean;
   begin
      Simple_Command (S, Op_Sync, Pattern, Sync_Timeout_Ms, Status);
      if Status = Ok then
         for Extra in 1 .. 7 loop
            Read_Frame (S, Junk, Got, 50, Found);
            exit when not Found;
         end loop;
      end if;
   end Sync;

   procedure Connect (S : out Session; Over : Link; Status : out Status_Kind)
   is
   begin
      S.Over := Over;
      S.Connected := False;
      Drop_Input (S);
      Status := No_Response;

      for Attempt in 1 .. Connect_Attempts loop
         Reset_Target (Over, Into_Download => True);
         Drop_Input (S);   --  the boot chatter is not ours

         for Try in 1 .. Sync_Attempts loop
            Sync (S, Status);
            exit when Status = Ok;
            Pause (50);
         end loop;

         if Status = Ok then
            S.Connected := True;
            Detect (S);
            return;
         end if;
      end loop;
   end Connect;

   function Is_Connected (S : Session) return Boolean
   is (S.Connected);

   function Chip (S : Session) return Chip_Kind
   is (S.Kind);

   function Chip_Name (Kind : Chip_Kind) return String
   is (case Kind is
         when Unknown => "unknown",
         when Esp8266 => "ESP8266",
         when Esp32 => "ESP32",
         when Esp32_S2 => "ESP32-S2",
         when Esp32_S3 => "ESP32-S3",
         when Esp32_C2 => "ESP32-C2",
         when Esp32_C3 => "ESP32-C3",
         when Esp32_C5 => "ESP32-C5",
         when Esp32_C6 => "ESP32-C6",
         when Esp32_C61 => "ESP32-C61",
         when Esp32_H2 => "ESP32-H2",
         when Esp32_H21 => "ESP32-H21",
         when Esp32_H4 => "ESP32-H4",
         when Esp32_P4 => "ESP32-P4",
         when Esp32_S31 => "ESP32-S31",
         when Esp32_E22 => "ESP32-E22");

   function Remaining (S : Session) return Interfaces.Unsigned_32
   is (S.Owed);

   ---------------------------------------------------------------------------
   --  Configuration
   ---------------------------------------------------------------------------

   procedure Set_Baud
     (S : in out Session; Baud : Positive; Status : out Status_Kind)
   is
      Header : Byte_Array (1 .. 8);
   begin
      if S.Over.Set_Baud = null then
         Status := Unsupported;
         return;
      end if;

      Put_32 (Header, 1, Interfaces.Unsigned_32 (Baud));
      Put_32
        (Header, 5, 0);        --  0 = we are talking to the ROM, not a stub
      Simple_Command (S, Op_Change_Baud, Header, Short_Timeout_Ms, Status);
      if Status /= Ok then
         return;
      end if;

      --  The target switches once its reply is on the wire, so let that drain
      --  before moving, and discard whatever straddled the change.
      Pause (50);
      S.Over.Set_Baud (S.Over.Ctx, Baud);
      Pause (50);
      Drop_Input (S);
   end Set_Baud;

   procedure Configure_Flash
     (S           : in out Session;
      Flash_Bytes : Interfaces.Unsigned_32;
      Status      : out Status_Kind)
   is
      Attach : constant Byte_Array (1 .. 8) := (others => 0);  --  default pins
      Params : Byte_Array (1 .. 24);
      Header : Byte_Array (1 .. 16);
   begin
      --  The ESP8266's ROM has NEITHER command.  It attaches the flash as a
      --  side effect of a zero-sized FLASH_BEGIN, and it has no notion of
      --  being told the geometry at all -- so that half is simply skipped,
      --  which is what esptool does too.
      if S.Kind = Esp8266 then
         Put_32 (Header, 1, 0);
         Put_32 (Header, 5, 0);
         Put_32 (Header, 9, Block_Bytes);
         Put_32 (Header, 13, 0);
         Simple_Command (S, Op_Flash_Begin, Header, Short_Timeout_Ms, Status);
         return;
      end if;

      Simple_Command (S, Op_Spi_Attach, Attach, Short_Timeout_Ms, Status);
      if Status /= Ok then
         return;
      end if;

      --  <id, total size, block, sector, page, status mask> -- the geometry
      --  every ESP32 SPI flash shares apart from its total size.
      Put_32 (Params, 1, 0);
      Put_32 (Params, 5, Flash_Bytes);
      Put_32 (Params, 9, 16#1_0000#);      --  64 KB block
      Put_32 (Params, 13, 16#1000#);       --  4 KB sector
      Put_32 (Params, 17, 16#100#);        --  256 byte page
      Put_32 (Params, 21, 16#FFFF#);       --  status mask
      Simple_Command (S, Op_Spi_Params, Params, Short_Timeout_Ms, Status);
   end Configure_Flash;

   ---------------------------------------------------------------------------
   --  Images
   ---------------------------------------------------------------------------

   --  The ESP8266's ROM miscounts how much it must erase, and erasing too
   --  little silently leaves stale flash behind the new image.  This is
   --  esptool's long-standing workaround, reproduced exactly: the value in
   --  FLASH_BEGIN's first word is not the image size but a doctored erase
   --  size.  On every other chip the two are the same number.
   function Erase_Size
     (Kind : Chip_Kind; At_Offset, Length : Interfaces.Unsigned_32)
      return Interfaces.Unsigned_32
   is
      Sectors      : Interfaces.Unsigned_32;
      First_Sector : Interfaces.Unsigned_32;
      Head         : Interfaces.Unsigned_32;
   begin
      if Kind /= Esp8266 then
         return Length;
      end if;

      Sectors :=
        (Length + Flash_Sector_Bytes - 1) / Flash_Sector_Bytes;
      First_Sector := At_Offset / Flash_Sector_Bytes;
      Head := Sectors_Per_Block - (First_Sector mod Sectors_Per_Block);
      if Sectors < Head then
         Head := Sectors;
      end if;

      if Sectors < 2 * Head then
         return ((Sectors + 1) / 2) * Flash_Sector_Bytes;
      else
         return (Sectors - Head) * Flash_Sector_Bytes;
      end if;
   end Erase_Size;

   procedure Begin_Image
     (S         : in out Session;
      At_Offset : Interfaces.Unsigned_32;
      Length    : Interfaces.Unsigned_32;
      Status    : out Status_Kind)
   is
      Blocks : constant Interfaces.Unsigned_32 :=
        (Length + Block_Bytes - 1) / Block_Bytes;

      --  The ESP32 and ESP8266 ROMs take the four-word form; every later ROM
      --  takes a fifth word saying whether the write is encrypted.  Sending
      --  the long form to an ESP32 is not ignored -- it is rejected.
      Extended : constant Boolean := S.Kind not in Esp32 | Esp8266;
      Words    : constant Natural := (if Extended then 5 else 4);
      Header   : Byte_Array (1 .. 4 * Words);
   begin
      Put_32 (Header, 1, Erase_Size (S.Kind, At_Offset, Length));
      Put_32 (Header, 5, Blocks);
      Put_32 (Header, 9, Block_Bytes);
      Put_32 (Header, 13, At_Offset);
      if Extended then
         Put_32 (Header, 17, 0);           --  not encrypted
      end if;

      Simple_Command (S, Op_Flash_Begin, Header, Erase_Timeout_Ms, Status);
      if Status /= Ok then
         return;
      end if;

      S.Block := (others => 16#FF#);
      S.Block_Fill := 0;
      S.Block_Seq := 0;
      S.Owed := Length;
      S.Image_Open := True;
   end Begin_Image;

   --  Ship the staged block, padded with erased-flash 0xFF if it is short.
   procedure Send_Block (S : in out Session; Status : out Status_Kind) is
      Header : Byte_Array (1 .. 16);
      Reply  : Byte_Array (1 .. 4);
      Value  : Interfaces.Unsigned_32;
      Got    : Natural;
   begin
      for I in S.Block_Fill + 1 .. S.Block'Last loop
         S.Block (I) := 16#FF#;
      end loop;

      Put_32 (Header, 1, Block_Bytes);
      Put_32 (Header, 5, S.Block_Seq);
      Put_32 (Header, 9, 0);
      Put_32 (Header, 13, 0);

      Command
        (S,
         Op_Flash_Data,
         Header,
         S.Block,
         Block_Checksum (S.Block),
         Write_Timeout_Ms,
         Value,
         Reply,
         Got,
         Status);

      S.Block_Seq := S.Block_Seq + 1;
      S.Block_Fill := 0;
   end Send_Block;

   procedure Write
     (S : in out Session; Data : Byte_Array; Status : out Status_Kind)
   is
      Next : Positive := Data'First;
   begin
      Status := Ok;

      if not S.Image_Open then
         Status := Not_Connected;
         return;
      end if;

      if Interfaces.Unsigned_32 (Data'Length) > S.Owed then
         Status := Wrong_Length;   --  more than Begin_Image declared
         return;
      end if;

      while Next <= Data'Last loop
         declare
            Room  : constant Natural := S.Block'Length - S.Block_Fill;
            Chunk : constant Natural :=
              Natural'Min (Room, Data'Last - Next + 1);
         begin
            S.Block (S.Block_Fill + 1 .. S.Block_Fill + Chunk) :=
              Data (Next .. Next + Chunk - 1);
            S.Block_Fill := S.Block_Fill + Chunk;
            Next := Next + Chunk;

            if S.Block_Fill = S.Block'Length then
               Send_Block (S, Status);
               if Status /= Ok then
                  return;
               end if;
            end if;
         end;
      end loop;

      S.Owed := S.Owed - Interfaces.Unsigned_32 (Data'Length);
   end Write;

   procedure End_Image (S : in out Session; Status : out Status_Kind) is
   begin
      if not S.Image_Open then
         Status := Not_Connected;
         return;
      end if;

      if S.Owed /= 0 then
         S.Image_Open := False;
         Status :=
           Wrong_Length;   --  fewer bytes than declared: a short source
         return;
      end if;

      Status := Ok;
      if S.Block_Fill > 0 then
         Send_Block (S, Status);
      end if;
      S.Image_Open := False;
   end End_Image;

   procedure Finish
     (S : in out Session; Run : Boolean := True; Status : out Status_Kind)
   is
      Header : Byte_Array (1 .. 4);
   begin
      --  1 = stay in the loader.  We always say stay and then reset the target
      --  ourselves, because we hold its reset line and that is unambiguous.
      Put_32 (Header, 1, 1);
      Simple_Command (S, Op_Flash_End, Header, Short_Timeout_Ms, Status);

      if Run then
         Reset_Target (S.Over, Into_Download => False);
         S.Connected := False;
      end if;
   end Finish;

   ---------------------------------------------------------------------------
   --  Inspection
   ---------------------------------------------------------------------------

   procedure Read_Register
     (S       : in out Session;
      Address : Interfaces.Unsigned_32;
      Value   : out Interfaces.Unsigned_32;
      Status  : out Status_Kind)
   is
      Header  : Byte_Array (1 .. 4);
      Nothing : constant Byte_Array (1 .. 0) := (others => 0);
      Reply   : Byte_Array (1 .. 4);
      Got     : Natural;
   begin
      Put_32 (Header, 1, Address);
      Command
        (S,
         Op_Read_Reg,
         Header,
         Nothing,
         0,
         Short_Timeout_Ms,
         Value,
         Reply,
         Got,
         Status);
   end Read_Register;

   procedure Read_Md5
     (S         : in out Session;
      At_Offset : Interfaces.Unsigned_32;
      Length    : Interfaces.Unsigned_32;
      Digest    : out Digest_Text;
      Status    : out Status_Kind)
   is
      Header  : Byte_Array (1 .. 16);
      Nothing : constant Byte_Array (1 .. 0) := (others => 0);
      Reply   : Byte_Array (1 .. 32);
      Value   : Interfaces.Unsigned_32;
      Got     : Natural;
   begin
      Digest := (others => '0');

      Put_32 (Header, 1, At_Offset);
      Put_32 (Header, 5, Length);
      Put_32 (Header, 9, 0);
      Put_32 (Header, 13, 0);

      Command
        (S,
         Op_Flash_Md5,
         Header,
         Nothing,
         0,
         Md5_Timeout_Ms,
         Value,
         Reply,
         Got,
         Status);
      if Status /= Ok then
         return;
      end if;

      --  The ROM answers with the digest already in hex -- 32 characters, not
      --  16 raw bytes (the stub loader is the one that sends raw).
      if Got < Digest'Length then
         Status := Bad_Reply;
         return;
      end if;

      for I in Digest'Range loop
         Digest (I) := Character'Val (Reply (Reply'First + I - 1));
      end loop;
   end Read_Md5;

end ESP32S3.Esp_Loader;

