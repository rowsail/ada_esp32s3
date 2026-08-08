package body ESP32S3.Esp_Loader is

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
   begin
      Length := 0;
      Found := False;

      loop
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

            --  Status is the last two payload bytes; the first is the error
            --  flag.  Short replies (SYNC) carry no status pair.
            if Got >= 10 and then Frame (Got - 1) /= 0 then
               Status := Target_Refused;
               return;
            end if;

            if Got > 8 then
               Reply_Len := Natural'Min (Got - 8, Reply'Length);
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
            return;
         end if;
      end loop;
   end Connect;

   function Is_Connected (S : Session) return Boolean
   is (S.Connected);

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
      Attach : constant Byte_Array (1 .. 8) :=
        (others => 0);  --  default SPI pins
      Params : Byte_Array (1 .. 24);
   begin
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

   procedure Begin_Image
     (S         : in out Session;
      At_Offset : Interfaces.Unsigned_32;
      Length    : Interfaces.Unsigned_32;
      Status    : out Status_Kind)
   is
      Blocks : constant Interfaces.Unsigned_32 :=
        (Length + Block_Bytes - 1) / Block_Bytes;
      Header : Byte_Array (1 .. 20);
   begin
      Put_32 (Header, 1, Length);
      Put_32 (Header, 5, Blocks);
      Put_32 (Header, 9, Block_Bytes);
      Put_32 (Header, 13, At_Offset);
      Put_32 (Header, 17, 0);              --  not encrypted

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

