with System;
with Interfaces; use Interfaces;

package body ESP32S3.HC595 is

   package G renames ESP32S3.GPIO;
   package S renames ESP32S3.SPI;

   --  Library-level no-op chip-select: passing it to Acquire suppresses the
   --  host's hardware CS0 for our hold, so shifting the string asserts NO select
   --  and cannot disturb another device sharing the bus.  The 595 latches on
   --  RCLK instead, which we pulse ourselves after the shift.
   procedure No_CS (Ctx : System.Address; Active : Boolean) is null;

   --------------------------------------------------------------------------

   function Output_Count (C : Controller) return Natural
   is (C.Chips * 8);

   function Bit_Mask (Index : Natural) return Byte
   is (Byte (2**(Index mod 8)));

   --------------------------------------------------------------------------

   procedure Set_Output (C : in out Controller; Index : Natural; On : Boolean)
   is
      Chip : constant Positive := Index / 8 + 1;   --  0-based -> 1-based store
   begin
      if On then
         C.State (Chip) := C.State (Chip) or Bit_Mask (Index);
      else
         C.State (Chip) := C.State (Chip) and not Bit_Mask (Index);
      end if;
   end Set_Output;

   function Get_Output (C : Controller; Index : Natural) return Boolean
   is ((C.State (Index / 8 + 1) and Bit_Mask (Index)) /= 0);

   procedure Set_Byte (C : in out Controller; Chip : Natural; Value : Byte) is
   begin
      C.State (Chip + 1) := Value;            --  0-based chip -> 1-based store
   end Set_Byte;

   --------------------------------------------------------------------------

   --  Shift the shadow out through the string and latch it -- no /OE change.
   procedure Shift_And_Latch (C : in out Controller) is
      Sess : S.Session;
      Tx   : State_Array (1 .. C.Chips);
      Rx   : State_Array (1 .. C.Chips);   --  full-duplex DMA; ignored
   begin
      --  The farthest chip in the chain receives its byte first (the bits ripple
      --  through), so send State in reverse: chip Chips (farthest) .. chip 1.
      for K in 1 .. C.Chips loop
         Tx (K) := C.State (C.Chips - K + 1);
      end loop;

      S.Acquire
        (Sess,
         C.Host,
         Mode      => 0,
         Clock_Hz  => C.Clock,
         Select_CB => No_CS'Access);
      S.Transfer (Sess, Tx'Address, Rx'Address, C.Chips);
      S.Release (Sess);

      --  Latch: a rising edge on RCLK copies the shift register to the outputs.
      G.Set (C.RCLK);
      G.Clear (C.RCLK);
   end Shift_And_Latch;

   procedure Update (C : in out Controller) is
   begin
      Shift_And_Latch (C);
      --  Bring the outputs live on the FIRST update only (if auto-enabling), so
      --  /OE stays high until a defined state has actually been latched.
      if C.Auto_Enable and then not C.Live then
         Enable_Outputs (C);
         C.Live := True;
      end if;
   end Update;

   procedure Write_Output
     (C : in out Controller; Index : Natural; On : Boolean) is
   begin
      Set_Output (C, Index, On);
      Update (C);
   end Write_Output;

   procedure Clear_All (C : in out Controller) is
   begin
      C.State := (others => 0);
      Update (C);
   end Clear_All;

   procedure Set_All (C : in out Controller) is
   begin
      C.State := (others => 16#FF#);
      Update (C);
   end Set_All;

   --------------------------------------------------------------------------

   procedure Enable_Outputs (C : in out Controller) is
   begin
      G.Clear (C.OE);     --  /OE low = outputs driven
   end Enable_Outputs;

   procedure Disable_Outputs (C : in out Controller) is
   begin
      G.Set (C.OE);       --  /OE high = high-impedance
   end Disable_Outputs;

   --------------------------------------------------------------------------

   procedure Initialize
     (C        : in out Controller;
      Host     : S.SPI_Host;
      RCLK     : G.Pin_Id;
      OE       : G.Pin_Id;
      Clock_Hz : Positive := 10_000_000;
      Enable   : Boolean := True) is
   begin
      C.Host := Host;
      C.Clock := Clock_Hz;
      C.RCLK := RCLK;
      C.OE := OE;
      C.Auto_Enable := Enable;
      C.Live := False;
      C.State := (others => 0);

      --  Park the control lines: RCLK idle low, outputs OFF (/OE high) so the
      --  undefined power-up shift state never reaches the pins.
      G.Configure (OE, G.Output);
      G.Set (OE);                  --  /OE high: outputs disabled (high-Z)
      G.Configure (RCLK, G.Output);
      G.Clear (RCLK);                --  idle low

      --  Latch a defined all-zeros state, but leave /OE HIGH -- the outputs stay
      --  disabled until the application's first Update brings them live.
      Shift_And_Latch (C);
   end Initialize;

end ESP32S3.HC595;
