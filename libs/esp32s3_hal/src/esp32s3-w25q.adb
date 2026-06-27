package body ESP32S3.W25Q is

   package SPI renames ESP32S3.SPI;

   --  Winbond command opcodes.  We put the chip in 4-byte ADDRESS MODE (0xB7)
   --  at Initialize and then use the STANDARD opcodes, which then consume four
   --  address bytes and reach the full 32 MB.  This is exactly what the
   --  W25Q256FV datasheet's "Instruction Set Table 3 (4-Byte Address Mode)"
   --  prescribes: Page Program is still 0x02, Sector Erase still 0x20, Block
   --  Erase still 0xD8 -- the FV defines NO dedicated 4-byte program/erase
   --  opcodes at all (the 0x12 / 0x21 / 0xDC set only exists on the later
   --  W25Q256JV).  Only the *read* family gets 4-byte-address variants (0x13
   --  etc.), which is why a 0x12/0x21 attempt is silently ignored here.
   Cmd_Write_Enable : constant := 16#06#;
   Cmd_Read_Status1 : constant := 16#05#;   --  status register 1; BUSY = bit 0
   Cmd_Read_Status3 : constant := 16#15#;   --  status register 3; ADS = bit 0
   Cmd_Enter_4Byte  : constant := 16#B7#;   --  enter 4-byte address mode
   Cmd_JEDEC_ID     : constant := 16#9F#;
   Cmd_Read         : constant := 16#03#;   --  read data (4 addr bytes in 4B mode)
   Cmd_Page_Program : constant := 16#02#;   --  page program  ("    "    "    "   )
   Cmd_Sector_Erase : constant := 16#20#;   --  4 KB sector erase ("  "    "    " )

   Status_Busy : constant Unsigned_8 := 16#01#;   --  SR1 bit 0
   Status3_ADS : constant Unsigned_8 := 16#01#;   --  SR3 bit 0: 4-byte mode active

   --  Largest single transfer we build: opcode + 4 address bytes + a full page.
   Header_Len : constant := 5;

   ----------------------------------------------------------------------------
   --  Low-level command helpers (all run while the host is already Acquired)
   ----------------------------------------------------------------------------

   --  Write the 32-bit address big-endian into Buf (1 .. 4), just past the
   --  opcode at Buf'First.
   procedure Put_Address (Buf : in out Byte_Array; Addr : Address) is
   begin
      Buf (Buf'First + 1) := Unsigned_8 (Shift_Right (Addr, 24) and 16#FF#);
      Buf (Buf'First + 2) := Unsigned_8 (Shift_Right (Addr, 16) and 16#FF#);
      Buf (Buf'First + 3) := Unsigned_8 (Shift_Right (Addr,  8) and 16#FF#);
      Buf (Buf'First + 4) := Unsigned_8 (Addr and 16#FF#);
   end Put_Address;

   --  One full-duplex command: assert CS, shift Len bytes, deassert CS.
   procedure Command (S : in out SPI.Session; Tx, Rx : System.Address;
                      Len : Natural) is
   begin
      SPI.Select_Device (S, On => True);
      SPI.Transfer (S, Tx, Rx, Len);
      SPI.Select_Device (S, On => False);
   end Command;

   --  Latch the write-enable bit before an erase/program (its own CS pulse).
   procedure Write_Enable (S : in out SPI.Session) is
      Cmd : aliased Byte_Array := (0 => Cmd_Write_Enable);
      Rsp : aliased Byte_Array (0 .. 0);
   begin
      Command (S, Cmd'Address, Rsp'Address, 1);
   end Write_Enable;

   --  Read a one-byte status register (opcode then one clocked-in status byte).
   function Read_Register (S : in out SPI.Session; Opcode : Unsigned_8)
      return Unsigned_8
   is
      Cmd : aliased Byte_Array := (Opcode, 16#00#);
      Rsp : aliased Byte_Array (0 .. 1);
   begin
      Command (S, Cmd'Address, Rsp'Address, 2);
      return Rsp (1);                 --  Rsp(1): the byte clocked in after the opcode
   end Read_Register;

   --  Poll status register 1 until BUSY clears (erase/program complete).
   procedure Wait_Until_Ready (S : in out SPI.Session) is
   begin
      while (Read_Register (S, Cmd_Read_Status1) and Status_Busy) /= 0 loop
         null;
      end loop;
   end Wait_Until_Ready;

   ----------------------------------------------------------------------------
   --  Single-GPIO chip select (the common case)
   ----------------------------------------------------------------------------

   procedure Init_Pin (Cell : Pin_Cell) is
   begin
      ESP32S3.GPIO.Configure (Cell.Pin, Mode => ESP32S3.GPIO.Output,
                              Drive => ESP32S3.GPIO.Drive_Strong);
      ESP32S3.GPIO.Set (Cell.Pin);          --  idle high = deselected
   end Init_Pin;

   procedure GPIO_Select (Ctx : System.Address; Active : Boolean) is
      Cell : Pin_Cell with Import, Address => Ctx;
   begin
      if Active then
         ESP32S3.GPIO.Clear (Cell.Pin);     --  active-low: select drives low
      else
         ESP32S3.GPIO.Set (Cell.Pin);
      end if;
   end GPIO_Select;

   ----------------------------------------------------------------------------
   --  Operations
   ----------------------------------------------------------------------------

   procedure Initialize (Dev : Flash; OK : out Boolean) is
      S   : SPI.Session;
      Cmd : aliased Byte_Array := (0 => Cmd_Enter_4Byte);
      Rsp : aliased Byte_Array (0 .. 0);
   begin
      SPI.Acquire (S, Dev.Host, Dev.CS, Dev.Ctx);
      Command (S, Cmd'Address, Rsp'Address, 1);                --  enter 4-byte mode
      OK := (Read_Register (S, Cmd_Read_Status3) and Status3_ADS) /= 0;
      SPI.Release (S);
   end Initialize;

   procedure Read_Identification (Dev : Flash; ID : out JEDEC_ID) is
      S   : SPI.Session;
      Cmd : aliased Byte_Array := (Cmd_JEDEC_ID, 0, 0, 0);
      Rsp : aliased Byte_Array (0 .. 3);
   begin
      SPI.Acquire (S, Dev.Host, Dev.CS, Dev.Ctx);
      Command (S, Cmd'Address, Rsp'Address, 4);
      SPI.Release (S);
      --  Rsp(0) is shifted in while the opcode goes out; the ID follows.
      ID := (Manufacturer => Rsp (1),
             Memory_Type  => Rsp (2),
             Capacity     => Rsp (3));
   end Read_Identification;

   function Capacity_Bytes (ID : JEDEC_ID) return Address is
      Code : constant Natural := Natural (ID.Capacity);
   begin
      --  Standard SPI-NOR density encoding: size = 2 ** capacity-byte.  Accept
      --  64 KB (0x10) .. 64 MB (0x1A); anything else (0x00 / 0xFF / a vendor's
      --  non-standard code) is reported as unknown.
      if Code in 16#10# .. 16#1A# then
         return Shift_Left (Address (1), Code);
      else
         return 0;
      end if;
   end Capacity_Bytes;

   procedure Read (Dev : Flash; Addr : Address; Data : out Byte_Array) is
      S      : SPI.Session;
      Header : aliased Byte_Array (0 .. Header_Len - 1);
      Junk   : aliased Byte_Array (0 .. Header_Len - 1);
      Zeros  : constant Byte_Array (0 .. 255) := (others => 0);
      Pos    : Natural := Data'First;
      Chunk  : Natural;
   begin
      Header (0) := Cmd_Read;
      Put_Address (Header, Addr);

      SPI.Acquire (S, Dev.Host, Dev.CS, Dev.Ctx);
      SPI.Select_Device (S, On => True);
      --  Opcode + address, then keep CS asserted and stream the data out in
      --  chunks -- the chip auto-increments, so successive transfers continue
      --  reading sequential bytes.
      SPI.Transfer (S, Header'Address, Junk'Address, Header_Len);
      while Pos <= Data'Last loop
         Chunk := Natural'Min (Zeros'Length, Data'Last - Pos + 1);
         SPI.Transfer (S, Zeros'Address, Data (Pos)'Address, Chunk);
         Pos := Pos + Chunk;
      end loop;
      SPI.Select_Device (S, On => False);
      SPI.Release (S);
   end Read;

   procedure Erase_Sector (Dev : Flash; Addr : Address) is
      S   : SPI.Session;
      Cmd : aliased Byte_Array (0 .. Header_Len - 1);
      Rsp : aliased Byte_Array (0 .. Header_Len - 1);
   begin
      Cmd (0) := Cmd_Sector_Erase;
      Put_Address (Cmd, Addr);

      SPI.Acquire (S, Dev.Host, Dev.CS, Dev.Ctx);
      Write_Enable (S);
      Command (S, Cmd'Address, Rsp'Address, Header_Len);
      Wait_Until_Ready (S);
      SPI.Release (S);
   end Erase_Sector;

   procedure Program_Page (Dev : Flash; Addr : Address; Data : Byte_Array) is
      S   : SPI.Session;
      Len : constant Natural := Data'Length;
      Buf : aliased Byte_Array (0 .. Header_Len + Page_Size - 1);
      Rsp : aliased Byte_Array (0 .. Header_Len + Page_Size - 1);
   begin
      if Len = 0 or else Len > Page_Size then
         raise Constraint_Error with "W25Q.Program_Page: 1 .. 256 bytes only";
      end if;
      if (Addr mod Page_Size) + Address (Len) > Page_Size then
         raise Constraint_Error with "W25Q.Program_Page: crosses a page boundary";
      end if;

      Buf (0) := Cmd_Page_Program;
      Put_Address (Buf, Addr);
      Buf (Header_Len .. Header_Len + Len - 1) := Data;

      SPI.Acquire (S, Dev.Host, Dev.CS, Dev.Ctx);
      Write_Enable (S);
      Command (S, Buf'Address, Rsp'Address, Header_Len + Len);
      Wait_Until_Ready (S);
      SPI.Release (S);
   end Program_Page;

end ESP32S3.W25Q;
