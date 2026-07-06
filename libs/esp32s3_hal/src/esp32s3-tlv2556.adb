with Interfaces;    use Interfaces;
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.GDMA;

package body ESP32S3.TLV2556 is

   package SPI renames ESP32S3.SPI;

   type Byte_Array is array (Natural range <>) of Unsigned_8;
   subtype Frame is Byte_Array (0 .. 1);     --  one 16-clock (2-byte) transfer

   --  Command-register (CMR) and configuration nibbles (see the datasheet's
   --  Table 2).  The 8-bit command byte is  (command-nibble << 4) or CFGR1.
   Cmd_CFGR2 : constant Unsigned_8 := 16#F0#;   --  command Fh: access CFGR2

   --  CFGR1 low nibble: D[3:2]=11 -> 16-bit output, D1=0 -> MSB first,
   --  D0=0 -> unipolar binary.  Sent with every channel-select command.
   CFGR1_16bit : constant Unsigned_8 := 16#0C#;

   --  CFGR2 low nibble for each reference: D[3:2] reference, D1=0 (pin 19 = EOC),
   --  D0=0 (normal mode -- CFGR1 is programmed by Read, not the default mode).
   function CFGR2_Nibble (Ref : Reference) return Unsigned_8
   is (case Ref is
         when Internal_4096mV => 16#00#,    --  00: internal 4.096 V
         when Internal_2048mV => 16#04#,    --  01: internal 2.048 V
         when External        => 16#0C#)    --  11: external reference
   with SPARK_Mode => On;

   --  Conversion time is at most 5.54 us (2.7-3.6 V); wait comfortably past it
   --  between priming a conversion and reading it back (no EOC pin is wired).
   Convert_Delay : constant Time_Span := Microseconds (25);

   --  Acquire the host for this ADC, with its chip select (built-in CS_Pin or a
   --  custom callback).
   procedure Acquire (S : in out SPI.Session; Dev : Device) is
   begin
      SPI.Acquire
        (S,
         Dev.Host,
         Mode      => 0,
         Clock_Hz  => Dev.Clock_Hz,
         CS_Pin    => Dev.CS_Pin,
         Select_CB => Dev.CS_CB,
         Ctx       => Dev.Ctx);
   end Acquire;

   ----------------------------------------------------------------------------
   --  One CS-framed 16-clock transfer: shift Tx out, capture Rx.
   ----------------------------------------------------------------------------

   procedure Cycle (S : in out SPI.Session; Tx : Frame; Rx : out Frame) is
      --  DMA buffers padded to a whole cache line (the DMA size precondition);
      --  only Frame'Length (2) bytes are transferred.
      Out_Buf : ESP32S3.GDMA.DMA_Buffer (0 .. 31) := (others => 0);
      In_Buf  : ESP32S3.GDMA.DMA_Buffer (0 .. 31);
   begin
      Out_Buf (0 .. Frame'Length - 1) := ESP32S3.GDMA.DMA_Buffer (Tx);
      SPI.Select_Device (S, On => True);
      SPI.Transfer (S, Out_Buf, In_Buf, Frame'Length);
      SPI.Select_Device (S, On => False);
      Rx := Frame (In_Buf (0 .. Frame'Length - 1));
   end Cycle;

   ----------------------------------------------------------------------------
   --  Operations
   ----------------------------------------------------------------------------

   procedure Initialize (Dev : Device; Ref : Reference := External) is
      S  : SPI.Session;
      Rx : Frame;
   begin
      Acquire (S, Dev);
      Cycle (S, (Cmd_CFGR2 or CFGR2_Nibble (Ref), 16#00#), Rx);
      SPI.Release (S);
   end Initialize;

   function Read (Dev : Device; Input : Analog_Input) return Sample is
      S    : SPI.Session;
      Rx   : Frame;
      Word : constant Frame :=
        (Shift_Left (Unsigned_8 (Analog_Input'Pos (Input)), 4) or CFGR1_16bit, 16#00#);
      Raw  : Unsigned_16;
   begin
      Acquire (S, Dev);
      Cycle (S, Word, Rx);                       --  prime: start converting Input
      delay until Clock + Convert_Delay;         --  wait out the conversion
      Cycle (S, Word, Rx);                       --  read Input's result back
      SPI.Release (S);

      --  16-bit output, MSB first: result in the top 12 bits, low 4 are pads.
      Raw := Shift_Left (Unsigned_16 (Rx (0)), 8) or Unsigned_16 (Rx (1));
      return Sample (Shift_Right (Raw, 4) and 16#0FFF#);
   end Read;

   function Millivolts (S : Sample; Ref : Reference) return Natural
   is (case Ref is
         when Internal_4096mV => Natural (S),            --  1 LSB = 1 mV
         when Internal_2048mV => Natural (S) * 2048 / 4096,
         when External        => 0)                      --  scale unknown here
   with SPARK_Mode => On;

end ESP32S3.TLV2556;
