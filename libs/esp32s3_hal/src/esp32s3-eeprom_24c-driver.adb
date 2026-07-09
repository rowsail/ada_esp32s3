with Ada.Real_Time; use Ada.Real_Time;

package body ESP32S3.EEPROM_24C.Driver is

   package Bus renames ESP32S3.I2C;

   --  How far a sequential read may run before it must be re-addressed.
   Read_Span : constant Positive :=
     (if Part.Max_Read_Span = 0 then Capacity else Part.Max_Read_Span);

   --  Internal program cycle: ~5 ms (datasheet t_W).  Poll for the part's ACK
   --  rather than sleeping the worst case blindly, but give up eventually.
   Write_Cycle_Limit : constant Time_Span := Milliseconds (10);
   Poll_Interval     : constant Time_Span := Microseconds (200);

   ---------------------------------------------------------------------------
   --  Addressing.
   ---------------------------------------------------------------------------

   --  The slave address that answers for cell A: the strapped base, plus the high
   --  address bits the part folds into its device-select byte.  For a part that
   --  folds nothing (Blocks = 1) this is just the base.
   function Slave_Of (Dev : Device; A : Memory_Address) return Bus.Slave_Address
   is (Base_Address + Dev.Strap + A / Word_Span);

   --  The word address, big-endian, as the part expects it: the low bits of A
   --  that fit in Address_Bytes.  Word'Length must be Address_Bytes.
   procedure Put_Word_Address (Word : out Bus.Byte_Array; A : Memory_Address) is
      Offset : constant Natural := A mod Word_Span;   --  position within the block
   begin
      if Address_Bytes = 1 then
         Word (Word'First) := Bus.Byte (Offset);
      else
         Word (Word'First) := Bus.Byte (Offset / 256);
         Word (Word'First + 1) := Bus.Byte (Offset mod 256);
      end if;
   end Put_Word_Address;

   --  Bytes left in the page that A falls in: a write must stop here or the part
   --  wraps to the start of the page instead of advancing.
   function Page_Remaining (A : Memory_Address) return Positive
   is (Page_Size - A mod Page_Size)
   with SPARK_Mode => On;

   --  Bytes left in the run that A falls in, for the rare part whose sequential
   --  read cannot cross a block (24LC1025/26).  Read_Span = Capacity otherwise,
   --  so this never splits a read.
   function Span_Remaining (A : Memory_Address) return Positive
   is (Read_Span - A mod Read_Span)
   with SPARK_Mode => On;

   --  ACK-poll the part back from an internal program cycle: it NACKs its own
   --  address until the cycle completes.  A zero-length write is an address-only
   --  probe.
   procedure Wait_Ready (S : Bus.Session; Slave : Bus.Slave_Address; Result : out Status) is
      Deadline : constant Time := Clock + Write_Cycle_Limit;
      Acked    : Boolean;
   begin
      Result := Write_Timeout;
      loop
         delay until Clock + Poll_Interval;
         Bus.Write (S, Slave, Bus.Byte_Array'(1 .. 0 => 0), Acked);
         if Acked then
            Result := OK;
            exit;
         end if;
         exit when Clock >= Deadline;
      end loop;
   end Wait_Ready;

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
      Clock_Hz : Positive := 400_000) is
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
      S     : Bus.Session;
      Acked : Boolean;
   begin
      Bus.Acquire (S, Dev.Host);
      Bus.Write (S, Slave_Of (Dev, 0), Bus.Byte_Array'(1 .. 0 => 0), Acked);
      return Acked;
   end Is_Present;

   ----------
   -- Read --
   ----------

   --  The datasheet's random read, exactly as written there: send the word
   --  address, then a REPEATED START into the read -- no STOP in between, so the
   --  part never sees the command end and its address counter cannot drift.  The
   --  host handles any length, so this is one transaction per readable run, and
   --  the counter walks the array for us.
   procedure Read
     (Dev : Device; From : Memory_Address; Data : out ESP32S3.I2C.Byte_Array; Result : out Status)
   is
      S      : Bus.Session;
      Acked  : Boolean;
      Offset : Natural := 0;   --  bytes already read
   begin
      Result := OK;
      if Data'Length = 0 then
         return;
      end if;

      Bus.Acquire (S, Dev.Host);
      while Offset < Data'Length loop
         declare
            Target : constant Memory_Address := From + Offset;
            Chunk  : constant Positive :=
              Natural'Min (Span_Remaining (Target), Data'Length - Offset);
            First  : constant Natural := Data'First + Offset;
            Word   : Bus.Byte_Array (0 .. Address_Bytes - 1);
         begin
            Put_Word_Address (Word, Target);
            Bus.Write_Read
              (S, Slave_Of (Dev, Target), Word, Data (First .. First + Chunk - 1), Acked);
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

   procedure Write
     (Dev : Device; To : Memory_Address; Data : ESP32S3.I2C.Byte_Array; Result : out Status)
   is
      S      : Bus.Session;
      Acked  : Boolean;
      Offset : Natural := 0;   --  bytes already committed
   begin
      Result := OK;
      if Data'Length = 0 then
         return;
      end if;

      --  Held across every page and program cycle: a multi-page Write is atomic
      --  with respect to other tasks sharing the host.
      Bus.Acquire (S, Dev.Host);
      while Offset < Data'Length loop
         declare
            Target : constant Memory_Address := To + Offset;
            Chunk  : constant Positive :=
              Natural'Min (Page_Remaining (Target), Data'Length - Offset);
            First  : constant Natural := Data'First + Offset;
            Slave  : constant Bus.Slave_Address := Slave_Of (Dev, Target);

            --  Word address then payload, one segment.  A page never straddles a
            --  block, so Slave is right for the whole frame.
            Frame : Bus.Byte_Array (0 .. Address_Bytes + Chunk - 1);
         begin
            Put_Word_Address (Frame (0 .. Address_Bytes - 1), Target);
            Frame (Address_Bytes .. Address_Bytes + Chunk - 1) :=
              Data (First .. First + Chunk - 1);

            Bus.Write (S, Slave, Frame, Acked);
            if not Acked then
               Result := Bus_Error;
               return;
            end if;

            Wait_Ready (S, Slave, Result);
            if Result /= OK then
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
      One : Bus.Byte_Array (0 .. 0) := (others => 0);
   begin
      Read (Dev, From, One, Result);
      Value := (if Result = OK then One (0) else 0);
   end Read_Byte;

   ----------------
   -- Write_Byte --
   ----------------

   procedure Write_Byte
     (Dev : Device; To : Memory_Address; Value : ESP32S3.I2C.Byte; Result : out Status) is
   begin
      Write (Dev, To, Bus.Byte_Array'(0 => Value), Result);
   end Write_Byte;

begin
   --  Instance sanity, checked once at elaboration (the formals are not static,
   --  so this cannot be a compile-time check).  A wrong Page_Size corrupts data
   --  silently, which is exactly the failure this family is notorious for.
   pragma Assert (Address_Bytes in 1 .. 2, "24C parts take one or two word-address bytes");
   pragma Assert (Capacity mod Page_Size = 0, "Capacity must be a whole number of pages");
   pragma Assert (Blocks = 1 or else Blocks * Word_Span = Capacity,
                  "Capacity must be a power of two");
   pragma Assert (Part.Max_Read_Span = 0 or else Capacity mod Part.Max_Read_Span = 0,
                  "Max_Read_Span must divide Capacity");
end ESP32S3.EEPROM_24C.Driver;
