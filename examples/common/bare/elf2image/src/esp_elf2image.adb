------------------------------------------------------------------------------
--  esp_elf2image  --  ELF -> ESP32-S3 flash image (.bin): an Ada replacement
--  for `esptool --chip esp32s3 elf2image --flash_mode dio --flash_freq 80m
--  --flash_size 2MB`.  Reproduces esptool's algorithm byte-for-byte:
--    * source segments = allocated PROGBITS sections, merged when contiguous,
--      each data length padded up to a multiple of 4;
--    * 24-byte header (8 common + 16 extended) with chip_id=9, dio/80m/2MB;
--    * flash (IROM/DROM) segments 64 KB-aligned, with the RAM segments written
--      interleaved as the alignment padding (then a zero PADDING segment for
--      the remainder);
--    * XOR checksum (seed 0xEF) as the last byte of a 16-aligned block;
--    * SHA-256 of the whole image appended.
------------------------------------------------------------------------------
with Ada.Command_Line;      use Ada.Command_Line;
with Ada.Streams.Stream_IO; use Ada.Streams.Stream_IO;
with Ada.Streams;           use Ada.Streams;
with Ada.Text_IO;           use Ada.Text_IO;
with Interfaces;            use Interfaces;
with SHA256;
with Board;                   --  single source of truth: Flash_Size

procedure Esp_Elf2image is

   IROM_Start  : constant := 16#4200_0000#;
   IROM_End    : constant := 16#4400_0000#;
   DROM_Start  : constant := 16#3C00_0000#;
   DROM_End    : constant := 16#3E00_0000#;
   IROM_Align  : constant := 16#1_0000#;
   Seg_Hdr_Len : constant := 8;

   SHF_ALLOC    : constant := 16#2#;
   SHT_PROGBITS : constant := 1;

   --  ESP32-S3 image-header constants (esptool target esp32s3)
   Img_Magic  : constant := 16#E9#;
   Flash_Mode : constant := 2;       --  dio
   Flash_Freq : constant := 16#0F#;  --  80 MHz
   Image_Chip : constant := 9;       --  ESP32-S3

   --  Flash size in bytes for the image header.  Defaults to Board.Flash_Size
   --  (a compile-time fallback), but `--flash-size <bytes>` overrides it so the
   --  per-project board.ads drives the header without rebuilding this tool.
   Flash_Size_Bytes : Long_Long_Integer := Long_Long_Integer (Board.Flash_Size);

   --  Flash size/freq header byte: size-id nibble (1MB=0,2MB=1,4MB=2,...)
   --  derived from Flash_Size_Bytes, OR'd with the fixed 80 MHz freq nibble.
   function Flash_SzFq return Unsigned_8 is
      MB : Long_Long_Integer := Flash_Size_Bytes / (1024 * 1024);
      Id : Unsigned_8 := 0;
   begin
      while MB > 1 loop
         MB := MB / 2;
         Id := Id + 1;
      end loop;
      return Shift_Left (Id, 4) or Flash_Freq;
   end Flash_SzFq;
   WP_Pin_Off : constant := 16#EE#;
   Cksum_Seed : constant := 16#EF#;

   subtype Bytes is Stream_Element_Array;
   type Byte_Ptr is access Bytes;

   function Slurp (Name : String) return Byte_Ptr is
      F    : Ada.Streams.Stream_IO.File_Type;
      Last : Stream_Element_Offset;
   begin
      Open (F, In_File, Name);
      declare
         Len : constant Stream_Element_Offset :=
           Stream_Element_Offset (Ada.Streams.Stream_IO.Size (F));
         B   : constant Byte_Ptr := new Bytes (0 .. Len - 1);
      begin
         Read (F, B.all, Last);
         Close (F);
         return B;
      end;
   end Slurp;

   function U32 (B : Bytes; Off : Stream_Element_Offset) return Unsigned_32
   is (Unsigned_32 (B (Off))
       or Shift_Left (Unsigned_32 (B (Off + 1)), 8)
       or Shift_Left (Unsigned_32 (B (Off + 2)), 16)
       or Shift_Left (Unsigned_32 (B (Off + 3)), 24));

   function U16 (B : Bytes; Off : Stream_Element_Offset) return Unsigned_32
   is (Unsigned_32 (B (Off)) or Shift_Left (Unsigned_32 (B (Off + 1)), 8));

   --  a source segment: load addr + a slice of the ELF + a tail of zero
   --  padding so the total length is a multiple of 4.
   type Segment is record
      Addr : Unsigned_32;
      Off  : Stream_Element_Offset;   --  ELF offset of the real data
      Real : Natural;                 --  real bytes
      Pad4 : Natural;                 --  trailing zero bytes (0..3)
   end record;

   Max_Seg : constant := 64;
   type Seg_Array is array (1 .. Max_Seg) of Segment;
   Seg     : Seg_Array;
   N_Seg   : Natural := 0;

   function Is_Flash (A : Unsigned_32) return Boolean
   is ((A >= IROM_Start and A < IROM_End) or (A >= DROM_Start and A < DROM_End));

   procedure Sort_By_Addr is
      T : Segment;
   begin
      for I in 2 .. N_Seg loop
         T := Seg (I);
         declare
            J : Natural := I - 1;
         begin
            while J >= 1 and then Seg (J).Addr > T.Addr loop
               Seg (J + 1) := Seg (J);
               J := J - 1;
            end loop;
            Seg (J + 1) := T;
         end;
      end loop;
   end Sort_By_Addr;

   procedure Merge_Adjacent is
      Out_N : Natural := 0;
      R     : Seg_Array;
   begin
      for I in 1 .. N_Seg loop
         if Out_N > 0
           and then R (Out_N).Addr + Unsigned_32 (R (Out_N).Real) = Seg (I).Addr
           and then R (Out_N).Off + Stream_Element_Offset (R (Out_N).Real) = Seg (I).Off
         then
            R (Out_N).Real := R (Out_N).Real + Seg (I).Real;
         else
            Out_N := Out_N + 1;
            R (Out_N) := Seg (I);
         end if;
      end loop;
      Seg (1 .. Out_N) := R (1 .. Out_N);
      N_Seg := Out_N;
   end Merge_Adjacent;

   --  ---- output image buffer ----------------------------------------------
   Out_Buf : Byte_Ptr;
   Pos     : Stream_Element_Offset := 0;
   Cksum   : Unsigned_8 := Cksum_Seed;
   ELF     : Byte_Ptr;

   procedure Put8 (V : Unsigned_8) is
   begin
      Out_Buf (Pos) := Stream_Element (V);
      Pos := Pos + 1;
   end Put8;

   procedure Put32 (V : Unsigned_32) is
   begin
      Put8 (Unsigned_8 (V and 16#FF#));
      Put8 (Unsigned_8 (Shift_Right (V, 8) and 16#FF#));
      Put8 (Unsigned_8 (Shift_Right (V, 16) and 16#FF#));
      Put8 (Unsigned_8 (Shift_Right (V, 24) and 16#FF#));
   end Put32;

   --  Write one image segment: 8-byte header (addr,len) then Real bytes from
   --  the ELF at Off, then Pad zero bytes.  Segment DATA feeds the checksum.
   procedure Write_Seg
     (Addr : Unsigned_32; Off : Stream_Element_Offset; Real : Natural; Pad : Natural)
   is
      B : Unsigned_8;
   begin
      Put32 (Addr);
      Put32 (Unsigned_32 (Real + Pad));
      for I in 0 .. Real - 1 loop
         B := Unsigned_8 (ELF (Off + Stream_Element_Offset (I)));
         Put8 (B);
         Cksum := Cksum xor B;
      end loop;
      for I in 1 .. Pad loop
         Put8 (0);                 --  XOR 0 -> checksum unchanged
      end loop;
   end Write_Seg;

   --  esptool get_alignment_data_needed: padding bytes so that after the next
   --  8-byte header, file_pos % 64K == Addr % 64K.
   function Needed (Addr : Unsigned_32) return Integer is
      Align_Past : constant Integer := (Integer (Addr mod IROM_Align)) - Seg_Hdr_Len;
      Pad        : Integer := (IROM_Align - Integer (Pos mod IROM_Align)) + Align_Past;
   begin
      if Pad = 0 or Pad = IROM_Align then
         return 0;
      end if;
      Pad := Pad - Seg_Hdr_Len;
      if Pad < 0 then
         Pad := Pad + IROM_Align;
      end if;
      return Pad;
   end Needed;

   --  Positional args (<app.elf> <app.bin>) with an optional `--flash-size <bytes>`
   --  mixed in.  ELF_Idx / BIN_Idx point at the two positionals.
   ELF_Idx : Natural := 0;
   BIN_Idx : Natural := 0;

begin
   declare
      I, Pos : Natural := 0;
   begin
      I := 1;
      while I <= Argument_Count loop
         if Argument (I) = "--flash-size" and then I < Argument_Count then
            Flash_Size_Bytes := Long_Long_Integer'Value (Argument (I + 1));
            I := I + 2;
         else
            Pos := Pos + 1;
            if Pos = 1 then
               ELF_Idx := I;
            elsif Pos = 2 then
               BIN_Idx := I;
            end if;
            I := I + 1;
         end if;
      end loop;
   end;
   if ELF_Idx = 0 or else BIN_Idx = 0 then
      Put_Line (Standard_Error, "usage: esp_elf2image <app.elf> <app.bin> [--flash-size <bytes>]");
      Set_Exit_Status (2);
      return;
   end if;

   ELF := Slurp (Argument (ELF_Idx));
   declare
      B        : Bytes renames ELF.all;
      Sh_Off   : constant Stream_Element_Offset := Stream_Element_Offset (U32 (B, 16#20#));
      Sh_EntSz : constant Unsigned_32 := U16 (B, 16#2E#);
      Sh_Num   : constant Unsigned_32 := U16 (B, 16#30#);
      Entry_Pt : constant Unsigned_32 := U32 (B, 16#18#);
   begin
      if not (B (0) = 16#7F#
              and B (1) = Character'Pos ('E')
              and B (2) = Character'Pos ('L')
              and B (3) = Character'Pos ('F'))
      then
         Put_Line (Standard_Error, "not an ELF file");
         Set_Exit_Status (2);
         return;
      end if;

      for I in 0 .. Sh_Num - 1 loop
         declare
            H     : constant Stream_Element_Offset :=
              Sh_Off + Stream_Element_Offset (I * Sh_EntSz);
            STyp  : constant Unsigned_32 := U32 (B, H + 4);
            SFlg  : constant Unsigned_32 := U32 (B, H + 8);
            SAddr : constant Unsigned_32 := U32 (B, H + 12);
            SOff  : constant Unsigned_32 := U32 (B, H + 16);
            SSize : constant Unsigned_32 := U32 (B, H + 20);
         begin
            if (SFlg and SHF_ALLOC) /= 0 and STyp = SHT_PROGBITS and SSize > 0 then
               N_Seg := N_Seg + 1;
               Seg (N_Seg) :=
                 (Addr => SAddr,
                  Off  => Stream_Element_Offset (SOff),
                  Real => Natural (SSize),
                  Pad4 => 0);
            end if;
         end;
      end loop;

      Sort_By_Addr;
      Merge_Adjacent;
      for I in 1 .. N_Seg loop
         --  pad each segment to a multiple of 4
         Seg (I).Pad4 := (4 - (Seg (I).Real mod 4)) mod 4;
      end loop;

      --  ---- build the image ------------------------------------------------
      Out_Buf := new Bytes (0 .. Stream_Element_Offset (B'Length) + 16#20000#);

      --  common header (segment count patched at the end)
      Put8 (Img_Magic);
      Put8 (0);
      Put8 (Flash_Mode);
      Put8 (Flash_SzFq);
      Put32 (Entry_Pt);
      --  extended header: wp_pin, 3 drv, chip_id(u16), min_rev, min_rev_full(u16),
      --  max_rev_full(u16), 4 reserved, hash_appended
      Put8 (WP_Pin_Off);
      Put8 (0);
      Put8 (0);
      Put8 (0);
      Put8 (Image_Chip);
      Put8 (0);            --  chip_id (LE u16) = 9
      Put8 (0);                                --  min_rev
      Put8 (0);
      Put8 (0);                      --  min_rev_full (u16) = 0
      Put8 (16#FF#);
      Put8 (16#FF#);            --  max_rev_full (u16) = 0xFFFF (any)
      Put8 (0);
      Put8 (0);
      Put8 (0);
      Put8 (0);  --  reserved[4]
      Put8 (1);                                --  hash_appended

      declare
         --  split into flash + ram segment lists (each already addr-sorted),
         --  then pack: flash segments 64K-aligned, ram segments consumed as the
         --  alignment padding.  (esptool moves ".flash.appdesc" to the front of
         --  flash; here DROM has the lowest addr so it is already first.)
         Flash, Ram : Seg_Array;
         NF, NR     : Natural := 0;
         Total_Seg  : Natural := 0;
         R_Idx      : Natural := 1;       --  current ram segment
         R_Use      : Natural := 0;       --  bytes consumed of Ram (R_Idx)
         function Tot (S : Segment) return Natural
         is (S.Real + S.Pad4);
         function Ram_Left return Boolean
         is (R_Idx <= NR);

         procedure Take_Ram (Want : Natural) is
            Avail : constant Natural := Tot (Ram (R_Idx)) - R_Use;
            Emit  : constant Natural := Natural'Min (Want, Avail);
            RealL : constant Natural :=
              (if R_Use < Ram (R_Idx).Real then Ram (R_Idx).Real - R_Use else 0);
            RealE : constant Natural := Natural'Min (Emit, RealL);
         begin
            Write_Seg
              (Addr => Ram (R_Idx).Addr + Unsigned_32 (R_Use),
               Off  => Ram (R_Idx).Off + Stream_Element_Offset (R_Use),
               Real => RealE,
               Pad  => Emit - RealE);
            Total_Seg := Total_Seg + 1;
            R_Use := R_Use + Emit;
            if R_Use >= Tot (Ram (R_Idx)) then
               R_Idx := R_Idx + 1;
               R_Use := 0;
            end if;
         end Take_Ram;
      begin
         for I in 1 .. N_Seg loop
            if Is_Flash (Seg (I).Addr) then
               NF := NF + 1;
               Flash (NF) := Seg (I);
            else
               NR := NR + 1;
               Ram (NR) := Seg (I);
            end if;
         end loop;

         for FI in 1 .. NF loop
            loop
               declare
                  Pad : constant Integer := Needed (Flash (FI).Addr);
               begin
                  exit when Pad = 0;
                  if Ram_Left and then Pad > Seg_Hdr_Len then
                     Take_Ram (Pad);
                  else
                     Write_Seg (0, 0, 0, Pad);          --  zero padding segment
                     Total_Seg := Total_Seg + 1;
                  end if;
               end;
            end loop;
            Write_Seg (Flash (FI).Addr, Flash (FI).Off, Flash (FI).Real, Flash (FI).Pad4);
            Total_Seg := Total_Seg + 1;
         end loop;

         while Ram_Left loop
            --  any remaining ram segs
            Take_Ram (Tot (Ram (R_Idx)) - R_Use);
         end loop;

         --  checksum: zero-pad so the checksum byte is the last of a 16-block
         while (Pos mod 16) /= 15 loop
            Put8 (0);
         end loop;
         Put8 (Cksum);
         Out_Buf (1) := Stream_Element (Total_Seg);     --  patch segment count
      end;

      declare
         Img_Len : constant Stream_Element_Offset := Pos;
         D       : constant SHA256.Digest := SHA256.Hash (Out_Buf (0 .. Img_Len - 1));
      begin
         for I in D'Range loop
            Put8 (D (I));
         end loop;

         declare
            F : Ada.Streams.Stream_IO.File_Type;
         begin
            Create (F, Out_File, Argument (BIN_Idx));
            Write (F, Out_Buf (0 .. Pos - 1));
            Close (F);
         end;
      end;
   end;
end Esp_Elf2image;
