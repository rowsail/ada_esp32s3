with Ada.Real_Time; use Ada.Real_Time;

package body ESP32S3.M24C64 is

   package Bus renames ESP32S3.I2C;

   --  Internal program cycle: 5 ms max (datasheet t_W).  Poll for the part's ACK
   --  rather than sleeping the worst case blindly, but give up eventually.
   Write_Cycle_Limit : constant Time_Span := Milliseconds (10);
   Poll_Interval     : constant Time_Span := Microseconds (200);

   ---------------------------------------------------------------------------
   --  The 16-bit memory address, big-endian, as the part expects it.
   ---------------------------------------------------------------------------

   function Addr_Hi (A : Memory_Address) return Bus.Byte
   is (Bus.Byte (A / 256))
   with SPARK_Mode => On;

   function Addr_Lo (A : Memory_Address) return Bus.Byte
   is (Bus.Byte (A mod 256))
   with SPARK_Mode => On;

   --  Bytes left in the 32-byte page that A falls in: a write must stop here or
   --  the part wraps to the start of the page instead of advancing.
   function Page_Remaining (A : Memory_Address) return Positive
   is (Page_Size - A mod Page_Size)
   with SPARK_Mode => On;

   --  ACK-poll the part back from an internal program cycle: it NACKs its own
   --  address until the cycle completes.  A zero-length write is an address-only
   --  probe.
   procedure Wait_Ready (S : Bus.Session; Dev : Device; Result : out Status) is
      Deadline : constant Time := Clock + Write_Cycle_Limit;
      Acked    : Boolean;
   begin
      Result := Write_Timeout;
      loop
         delay until Clock + Poll_Interval;
         Bus.Write (S, Dev.Addr, Bus.Byte_Array'(1 .. 0 => 0), Acked);
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
      Dev := (Host => Host, Addr => Device_Address (A0, A1, A2));
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
      Bus.Write (S, Dev.Addr, Bus.Byte_Array'(1 .. 0 => 0), Acked);
      return Acked;
   end Is_Present;

   ----------
   -- Read --
   ----------

   --  The datasheet's random read, exactly as written there: send the 16-bit
   --  address, then a REPEATED START into the read -- no STOP in between, so the
   --  part never sees the command end and its address counter cannot drift.  The
   --  host handles any length, so this is one transaction however much is asked
   --  for; the counter walks the array for us.
   procedure Read
     (Dev : Device; From : Memory_Address; Data : out ESP32S3.I2C.Byte_Array; Result : out Status)
   is
      S     : Bus.Session;
      Acked : Boolean;
   begin
      Result := OK;
      if Data'Length = 0 then
         return;
      end if;

      Bus.Acquire (S, Dev.Host);
      Bus.Write_Read (S, Dev.Addr, (Addr_Hi (From), Addr_Lo (From)), Data, Acked);
      Result := (if Acked then OK else Bus_Error);
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

            --  Address bytes then payload, one segment.
            Frame : Bus.Byte_Array (0 .. Chunk + 1);
         begin
            Frame (0) := Addr_Hi (Target);
            Frame (1) := Addr_Lo (Target);
            Frame (2 .. Chunk + 1) := Data (First .. First + Chunk - 1);

            Bus.Write (S, Dev.Addr, Frame, Acked);
            if not Acked then
               Result := Bus_Error;
               return;
            end if;

            Wait_Ready (S, Dev, Result);
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

end ESP32S3.M24C64;
