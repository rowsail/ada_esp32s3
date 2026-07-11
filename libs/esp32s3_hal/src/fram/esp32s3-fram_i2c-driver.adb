package body ESP32S3.FRAM_I2C.Driver is

   package Bus renames ESP32S3.I2C;

   --  Reserved slave address for the Device ID sequence (0xF8 >> 1).
   Reserved_ID_Slave : constant Bus.Slave_Address := 16#7C#;

   ---------------------------------------------------------------------------
   --  Addressing.
   ---------------------------------------------------------------------------

   --  The slave address that answers for the byte at Location: the strapped base,
   --  plus the high address bits the part folds into its device-select byte.
   function Slave_Of (Dev : Device; Location : Memory_Address) return Bus.Slave_Address
   is (Base_Address + Dev.Strap + Location / Word_Span);

   --  The word address, big-endian: the low bits of Location that fit in Address_Bytes.
   procedure Put_Word_Address (Word : out Bus.Byte_Array; Location : Memory_Address) is
      Offset : constant Natural := Location mod Word_Span;   --  position within the block
   begin
      if Address_Bytes = 1 then
         Word (Word'First) := Bus.Byte (Offset);
      else
         Word (Word'First)     := Bus.Byte (Offset / 256);
         Word (Word'First + 1) := Bus.Byte (Offset mod 256);
      end if;
   end Put_Word_Address;

   --  Bytes left in the block that Location falls in: a transfer must re-address at a block
   --  boundary because that boundary is a change of slave address, not just of the
   --  word counter.  For a part that folds nothing (Blocks = 1) this never splits.
   function Block_Remaining (Location : Memory_Address) return Positive
   is (Word_Span - Location mod Word_Span);

   -----------
   -- Setup --
   -----------

   procedure Setup
     (Dev      : out Device;
      Sda      : ESP32S3.GPIO.Pin_Id;
      Scl      : ESP32S3.GPIO.Pin_Id;
      A0       : Pin_State := Low;
      A1       : Pin_State := Low;
      A2       : Pin_State := Low;
      Host     : ESP32S3.I2C.I2C_Host := ESP32S3.I2C.I2C0;
      Clock_Hz : Positive := Max_Clock) is
   begin
      Dev :=
        (Host  => Host,
         Strap => (if A0 = High then 1 else 0)
                  + (if A1 = High then 2 else 0)
                  + (if A2 = High then 4 else 0));
      Bus.Setup (Host, Clock_Hz => Clock_Hz);
      Bus.Configure_Pins (Host, Scl => Scl, Sda => Sda);
   end Setup;

   ----------------
   -- Is_Present --
   ----------------

   function Is_Present (Dev : Device) return Boolean is
      Session     : Bus.Session;
      Acked : Boolean;
   begin
      Bus.Acquire (Session, Dev.Host);
      Bus.Write (Session, Slave_Of (Dev, 0), Bus.Byte_Array'(1 .. 0 => 0), Acked);
      return Acked;
   end Is_Present;

   ----------
   -- Read --
   ----------

   --  The datasheet's random read: word address, REPEATED START into the read,
   --  no STOP between.  FRAM has no read-run limit, so the only split is a block
   --  boundary on a folded part.
   procedure Read
     (Dev : Device; From : Memory_Address; Data : out ESP32S3.I2C.Byte_Array; Result : out Status)
   is
      Session      : Bus.Session;
      Acked  : Boolean;
      Offset : Natural := 0;   --  bytes already read
   begin
      Result := OK;
      if Data'Length = 0 then
         return;
      end if;

      Bus.Acquire (Session, Dev.Host);
      while Offset < Data'Length loop
         declare
            Target : constant Memory_Address := From + Offset;
            Chunk  : constant Positive :=
              Natural'Min (Block_Remaining (Target), Data'Length - Offset);
            First  : constant Natural := Data'First + Offset;
            Word   : Bus.Byte_Array (0 .. Address_Bytes - 1);
         begin
            Put_Word_Address (Word, Target);
            Bus.Write_Read
              (Session, Slave_Of (Dev, Target), Word, Data (First .. First + Chunk - 1), Acked);
            if not Acked then
               Result := Bus_Error;
               return;
            end if;
            Offset := Offset + Chunk;
         end;
      end loop;
   end Read;

   -----------
   -- Write --
   -----------

   --  Word address then the whole payload in one segment.  No page boundary and no
   --  program cycle: FRAM commits each byte as it is clocked in, so there is
   --  nothing to wait for after the STOP.  The only split is a block boundary.
   procedure Write
     (Dev : Device; To : Memory_Address; Data : ESP32S3.I2C.Byte_Array; Result : out Status)
   is
      Session      : Bus.Session;
      Acked  : Boolean;
      Offset : Natural := 0;   --  bytes already committed
   begin
      Result := OK;
      if Data'Length = 0 then
         return;
      end if;

      Bus.Acquire (Session, Dev.Host);
      while Offset < Data'Length loop
         declare
            Target : constant Memory_Address := To + Offset;
            Chunk  : constant Positive :=
              Natural'Min (Block_Remaining (Target), Data'Length - Offset);
            First  : constant Natural := Data'First + Offset;
            Frame  : Bus.Byte_Array (0 .. Address_Bytes + Chunk - 1);
         begin
            Put_Word_Address (Frame (0 .. Address_Bytes - 1), Target);
            Frame (Address_Bytes .. Address_Bytes + Chunk - 1) :=
              Data (First .. First + Chunk - 1);

            Bus.Write (Session, Slave_Of (Dev, Target), Frame, Acked);
            if not Acked then
               Result := Bus_Error;
               return;
            end if;
            Offset := Offset + Chunk;
         end;
      end loop;
   end Write;

   ---------------
   -- Read_Byte --
   ---------------

   procedure Read_Byte
     (Dev : Device; From : Memory_Address; Value : out ESP32S3.I2C.Byte; Result : out Status)
   is
      One_Byte : Bus.Byte_Array (0 .. 0) := (others => 0);
   begin
      Read (Dev, From, One_Byte, Result);
      Value := (if Result = OK then One_Byte (0) else 0);
   end Read_Byte;

   ----------------
   -- Write_Byte --
   ----------------

   procedure Write_Byte
     (Dev : Device; To : Memory_Address; Value : ESP32S3.I2C.Byte; Result : out Status) is
   begin
      Write (Dev, To, Bus.Byte_Array'(0 => Value), Result);
   end Write_Byte;

   --------------------
   -- Read_Device_ID --
   --------------------

   --  Reserved-slave-ID sequence: START, 0xF8 (write) + the device's own 8-bit
   --  write address as the one data byte, REPEATED START, 0xF9 (read), 3 bytes.
   --  Bus.Write_Read drives exactly that (same slave 0x7C for both phases).
   --  The 24 bits are Manufacturer[11..0], Density[3..0], Product[7..0].
   procedure Read_Device_ID (Dev : Device; ID : out Device_ID; Result : out Status) is
      Session     : Bus.Session;
      Acked : Boolean;
      Tx    : constant Bus.Byte_Array (0 .. 0) := (0 => Bus.Byte (Address (Dev) * 2));
      ID_Bytes   : Bus.Byte_Array (0 .. 2) := (others => 0);
   begin
      ID := (others => 0);
      Bus.Acquire (Session, Dev.Host);
      Bus.Write_Read (Session, Reserved_ID_Slave, Tx, ID_Bytes, Acked);
      if not Acked then
         Result := Bus_Error;
         return;
      end if;
      ID.Manufacturer := Natural (ID_Bytes (0)) * 16 + Natural (ID_Bytes (1)) / 16;
      ID.Density      := Natural (ID_Bytes (1)) mod 16;
      ID.Product      := Natural (ID_Bytes (2));
      Result := OK;
   end Read_Device_ID;

   --------------
   -- Identify --
   --------------

   function Identify (Dev : Device) return Vendor is
      ID  : Device_ID;
      Result : Status;
   begin
      Read_Device_ID (Dev, ID, Result);
      if Result /= OK then
         return Unknown;
      end if;
      case ID.Manufacturer is
         when Fujitsu_Manufacturer => return Fujitsu;
         when Cypress_Manufacturer => return Cypress;
         when others               => return Unknown;
      end case;
   end Identify;


begin
   --  Instance sanity, checked once at elaboration (the formals are not static).
   pragma Assert (Address_Bytes in 1 .. 2, "FRAM parts take one or two word-address bytes");
   pragma Assert (Blocks = 1 or else Blocks * Word_Span = Capacity,
                  "Capacity must be a power of two");
end ESP32S3.FRAM_I2C.Driver;
