package body ESP32S3.GT911 is

   use ESP32S3.I2C;   --  Byte, Byte_Array, Session, Slave_Address, Acquire/Write_Read
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;

   ---------------------------------------------------------------------------
   --  Register map (GT911 programming guide v0.1, section "register map").
   --  16-bit addresses, sent MSB-first; multi-byte values little-endian.
   ---------------------------------------------------------------------------

   type Register is mod 2**16;

   Reg_Config_X_Max : constant Register := 16#8048#;   --  .. 0x804B: X max, Y max (LE u16 each)
   Reg_Product_Id   : constant Register := 16#8140#;   --  .. 0x8143: "911" + NUL
   Reg_Firmware     : constant Register := 16#8144#;   --  .. 0x8145: version (LE u16)
   Reg_Touch_Status : constant Register := 16#814E#;   --  buffer flag + point count
   Reg_Point_Data   : constant Register := 16#814F#;   --  5 x 8-byte point records

   --  Touch status register: bit 7 = a new report is latched (write 0 to the
   --  whole register to re-arm); bits 3:0 = number of valid points.
   Status_Buffer_Ready : constant Byte := 16#80#;
   Status_Count_Mask   : constant Byte := 16#0F#;

   --  Each latched point is 8 bytes: track id, X (LE), Y (LE), size (LE),
   --  one reserved byte.
   Point_Record_Size : constant := 8;

   ---------------------------------------------------------------------------
   --  Register access on an already-acquired Session (Addr = the device's I2C
   --  address).  The public operations open one Session and drive these.
   ---------------------------------------------------------------------------

   --  Set the 16-bit register pointer, then stream Data'Length bytes from it
   --  (the chip auto-increments across the read).  One combined transaction --
   --  the repeated start keeps the pointer-set and the read as one command.
   procedure Read_Regs
     (S : Session; Addr : Slave_Address; Reg : Register; Data : out Byte_Array; Result : out Status)
   is
      Acked : Boolean;
   begin
      Write_Read
        (S, Addr,
         Tx      => (Byte (Reg / 256), Byte (Reg mod 256)),
         Rx      => Data,
         Success => Acked);
      Result := (if Acked then OK else Bus_Error);
   end Read_Regs;

   --  Write Data to the registers starting at Reg, in one transaction.
   procedure Write_Regs
     (S : Session; Addr : Slave_Address; Reg : Register; Data : Byte_Array; Result : out Status)
   is
      Acked : Boolean;
      Buf   : Byte_Array (0 .. 1 + Data'Length);
   begin
      Buf (0) := Byte (Reg / 256);
      Buf (1) := Byte (Reg mod 256);
      if Data'Length > 0 then
         Buf (2 .. Buf'Last) := Data;
      end if;
      Write (S, Addr, Buf, Acked);
      Result := (if Acked then OK else Bus_Error);
   end Write_Regs;

   --  Little-endian byte pair -> 16-bit unsigned.
   function LE16 (Lo, Hi : Byte) return Interfaces.Unsigned_16
   is (Interfaces.Unsigned_16 (Hi) * 256 + Interfaces.Unsigned_16 (Lo));

   -----------
   -- Setup --
   -----------

   procedure Setup
     (Dev      : out Device;
      Sda      : ESP32S3.GPIO.Pin_Id;
      Scl      : ESP32S3.GPIO.Pin_Id;
      Int_Pin  : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Address  : ESP32S3.I2C.Slave_Address := Address_Int_Low;
      Host     : ESP32S3.I2C.I2C_Host := ESP32S3.I2C.I2C0;
      Clock_Hz : Positive := 400_000) is
   begin
      Dev :=
        (Host    => Host,
         Address => Address,
         Sda     => Sda,
         Scl     => Scl,
         Int_Pin => Int_Pin);
      ESP32S3.I2C.Setup (Host, Clock_Hz => Clock_Hz);
      ESP32S3.I2C.Configure_Pins (Host, Scl => Scl, Sda => Sda);
   end Setup;

   -------------------
   -- Interrupt_Pin --
   -------------------

   function Interrupt_Pin (Dev : Device) return ESP32S3.GPIO.Optional_Pin
   is (Dev.Int_Pin);

   ---------------------
   -- Read_Product_Id --
   ---------------------

   procedure Read_Product_Id (Dev : Device; Id : out Product_Id; Result : out Status) is
      S    : Session;
      Regs : Byte_Array (0 .. 3);
   begin
      Id := (others => Character'Val (0));
      Acquire (S, Dev.Host);
      Read_Regs (S, Dev.Address, Reg_Product_Id, Regs, Result);
      if Result = OK then
         for I in Regs'Range loop
            Id (Id'First + I) := Character'Val (Regs (I));
         end loop;
      end if;
   end Read_Product_Id;

   ---------------------------
   -- Read_Firmware_Version --
   ---------------------------

   procedure Read_Firmware_Version
     (Dev : Device; Version : out Interfaces.Unsigned_16; Result : out Status)
   is
      S    : Session;
      Regs : Byte_Array (0 .. 1);
   begin
      Version := 0;
      Acquire (S, Dev.Host);
      Read_Regs (S, Dev.Address, Reg_Firmware, Regs, Result);
      if Result = OK then
         Version := LE16 (Regs (0), Regs (1));
      end if;
   end Read_Firmware_Version;

   ---------------------
   -- Read_Resolution --
   ---------------------

   procedure Read_Resolution
     (Dev : Device; Width, Height : out Interfaces.Unsigned_16; Result : out Status)
   is
      S    : Session;
      Regs : Byte_Array (0 .. 3);
   begin
      Width := 0;
      Height := 0;
      Acquire (S, Dev.Host);
      Read_Regs (S, Dev.Address, Reg_Config_X_Max, Regs, Result);
      if Result = OK then
         Width := LE16 (Regs (0), Regs (1));
         Height := LE16 (Regs (2), Regs (3));
      end if;
   end Read_Resolution;

   ------------------
   -- Read_Touches --
   ------------------

   procedure Read_Touches (Dev : Device; State : out Touch_State; Result : out Status) is
      S          : Session;
      Status_Reg : Byte_Array (0 .. 0);
   begin
      State := (Fresh => False, Count => 0, Points => (others => <>));

      Acquire (S, Dev.Host);
      Read_Regs (S, Dev.Address, Reg_Touch_Status, Status_Reg, Result);
      if Result /= OK then
         return;
      end if;

      --  No new report latched since the last re-arm: report stale (the chip
      --  is mid-scan; the caller keeps its previous state) and leave the
      --  register alone.
      if (Status_Reg (0) and Status_Buffer_Ready) = 0 then
         return;
      end if;

      declare
         --  A count above Max_Points cannot come from a healthy chip (the
         --  status read itself ACKed) -- treat it as an empty report and fall
         --  through to the re-arm, which resynchronises the latch.
         Latched : constant Natural := Natural (Status_Reg (0) and Status_Count_Mask);
         Count   : constant Point_Count :=
           (if Latched <= Max_Points then Point_Count (Latched) else 0);
      begin
         if Count > 0 then
            declare
               Data : Byte_Array (0 .. Natural (Count) * Point_Record_Size - 1);
            begin
               Read_Regs (S, Dev.Address, Reg_Point_Data, Data, Result);
               if Result /= OK then
                  return;
               end if;
               for P in 1 .. Count loop
                  declare
                     Base : constant Natural := Natural (P - 1) * Point_Record_Size;
                  begin
                     State.Points (Point_Index (P)) :=
                       (Id   => Interfaces.Unsigned_8 (Data (Base)),
                        X    => LE16 (Data (Base + 1), Data (Base + 2)),
                        Y    => LE16 (Data (Base + 3), Data (Base + 4)),
                        Size => LE16 (Data (Base + 5), Data (Base + 6)));
                  end;
               end loop;
            end;
         end if;

         --  Re-arm the latch; only now is the report complete.  Count = 0 with
         --  the flag set is itself a real report: all fingers lifted.
         Write_Regs (S, Dev.Address, Reg_Touch_Status, (1 => 0), Result);
         if Result = OK then
            State.Fresh := True;
            State.Count := Count;
         end if;
      end;
   end Read_Touches;

end ESP32S3.GT911;
