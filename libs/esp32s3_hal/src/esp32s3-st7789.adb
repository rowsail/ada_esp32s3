with System;
with ESP32S3.GDMA;
with Interfaces;    use Interfaces;
with Ada.Real_Time; use Ada.Real_Time;

package body ESP32S3.ST7789 is

   use type ESP32S3.GPIO.Pad_Number;   --  "/=" against No_Pin

   subtype Byte is Interfaces.Unsigned_8;
   type Bytes is array (Natural range <>) of Byte;
   No_Params : constant Bytes (1 .. 0) := (others => 0);

   ---------------------------------------------------------------------------
   --  ST7789 commands.
   ---------------------------------------------------------------------------

   Cmd_SWRESET : constant Byte := 16#01#;
   Cmd_SLPOUT  : constant Byte := 16#11#;
   Cmd_INVOFF  : constant Byte := 16#20#;
   Cmd_INVON   : constant Byte := 16#21#;
   Cmd_DISPOFF : constant Byte := 16#28#;
   Cmd_DISPON  : constant Byte := 16#29#;
   Cmd_CASET   : constant Byte := 16#2A#;
   Cmd_RASET   : constant Byte := 16#2B#;
   Cmd_RAMWR   : constant Byte := 16#2C#;
   Cmd_MADCTL  : constant Byte := 16#36#;
   Cmd_COLMOD  : constant Byte := 16#3A#;
   Cmd_NORON   : constant Byte := 16#13#;
   Cmd_SLPIN   : constant Byte := 16#10#;

   ---------------------------------------------------------------------------
   --  DMA scratch in internal SRAM (a task holds the SPI host's Session while
   --  it uses its buffer, so a per-host TX buffer is race-free; RX is an ignored
   --  dump that any host may share).  Each DMA Transfer is <= 4095 bytes.
   ---------------------------------------------------------------------------

   Chunk  : constant := 4064;             --  <= 4095, a 32-byte multiple, even (RGB565)
   subtype Buffer is ESP32S3.GDMA.DMA_Buffer (0 .. Chunk - 1);
   Tx_Buf : array (ESP32S3.SPI.SPI_Host) of Buffer;
   Rx_Buf : Buffer;

   ---------------------------------------------------------------------------
   --  Per-display locks, keyed by the CS pin (one display per CS GPIO).
   ---------------------------------------------------------------------------

   protected type Disp_Guard is
      entry Acquire;
      procedure Release;
   private
      Held : Boolean := False;
   end Disp_Guard;

   protected body Disp_Guard is
      entry Acquire when not Held is
      begin
         Held := True;
      end Acquire;
      procedure Release is
      begin
         Held := False;
      end Release;
   end Disp_Guard;

   Guards : array (0 .. 48) of Disp_Guard;

   ---------------------------------------------------------------------------
   --  SPI primitives -- all run inside one CS-asserted, SPI-held transaction.
   ---------------------------------------------------------------------------

   procedure Check_Owned (S : Session) is
   begin
      if not S.Active then
         raise Not_Owned with "ST7789 used without holding it -- Acquire first";
      end if;
   end Check_Owned;

   --  Shift N bytes of Tx_Buf out (MISO captured into the ignored Rx_Buf).
   procedure Send (Bus : ESP32S3.SPI.Session; Host : ESP32S3.SPI.SPI_Host; N : Natural) is
   begin
      if N > 0 then
         ESP32S3.SPI.Transfer (Bus, Tx_Buf (Host), Rx_Buf, N);
      end if;
   end Send;

   --  One command byte (DC low).
   procedure Cmd1 (Bus : ESP32S3.SPI.Session; S : Session; C : Byte) is
   begin
      ESP32S3.GPIO.Clear (S.DC);
      Tx_Buf (S.Host) (0) := C;
      Send (Bus, S.Host, 1);
   end Cmd1;

   --  Data bytes (DC high).
   procedure Dat (Bus : ESP32S3.SPI.Session; S : Session; D : Bytes) is
   begin
      if D'Length = 0 then
         return;
      end if;
      ESP32S3.GPIO.Set (S.DC);
      for I in 0 .. D'Length - 1 loop
         Tx_Buf (S.Host) (I) := D (D'First + I);
      end loop;
      Send (Bus, S.Host, D'Length);
   end Dat;

   --  A complete command transaction (acquire SPI, CS low, send, CS high, free).
   procedure Command (S : Session; C : Byte; Params : Bytes := No_Params) is
      Bus : ESP32S3.SPI.Session;
   begin
      ESP32S3.SPI.Acquire (Bus, S.Host, Mode => S.Mode, Clock_Hz => S.Clock_Hz);
      ESP32S3.GPIO.Clear (S.CS);
      Cmd1 (Bus, S, C);
      Dat (Bus, S, Params);
      ESP32S3.GPIO.Set (S.CS);
   end Command;                              --  Bus released here

   --  Set the address window (with the panel offsets applied).
   procedure Window (Bus : ESP32S3.SPI.Session; S : Session; X0, Y0, X1, Y1 : Natural) is
      AX0 : constant Natural := X0 + S.X_Off;
      AX1 : constant Natural := X1 + S.X_Off;
      AY0 : constant Natural := Y0 + S.Y_Off;
      AY1 : constant Natural := Y1 + S.Y_Off;
   begin
      Cmd1 (Bus, S, Cmd_CASET);
      Dat (Bus, S, (Byte (AX0 / 256), Byte (AX0 mod 256), Byte (AX1 / 256), Byte (AX1 mod 256)));
      Cmd1 (Bus, S, Cmd_RASET);
      Dat (Bus, S, (Byte (AY0 / 256), Byte (AY0 mod 256), Byte (AY1 / 256), Byte (AY1 mod 256)));
   end Window;

   -----------
   -- Setup --
   -----------

   procedure Setup
     (Dev                : out Device;
      Sclk, Mosi, DC, CS : ESP32S3.GPIO.Pin_Id;
      Width              : Positive := 240;
      Height             : Positive := 240;
      RST                : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      X_Offset, Y_Offset : Natural := 0;
      Host               : ESP32S3.SPI.SPI_Host := ESP32S3.SPI.SPI2;
      Mode               : ESP32S3.SPI.SPI_Mode := 0;
      Clock_Hz           : Positive := 40_000_000) is
   begin
      Dev :=
        (Host       => Host,
         Mode       => Mode,
         Clock_Hz   => Clock_Hz,
         DC         => DC,
         CS         => CS,
         RST        => RST,
         W          => Width,
         H          => Height,
         X_Off      => X_Offset,
         Y_Off      => Y_Offset,
         Configured => True);

      --  Control pins as GPIO outputs; CS idles high (deselected).
      ESP32S3.GPIO.Configure (DC, Mode => ESP32S3.GPIO.Output);
      ESP32S3.GPIO.Configure (CS, Mode => ESP32S3.GPIO.Output);
      ESP32S3.GPIO.Set (CS);
      if RST /= ESP32S3.GPIO.No_Pin then
         ESP32S3.GPIO.Configure (ESP32S3.GPIO.Pin_Id (RST), Mode => ESP32S3.GPIO.Output);
         ESP32S3.GPIO.Set (ESP32S3.GPIO.Pin_Id (RST));
      end if;

      --  SPI host: route SCLK/MOSI only (CS/DC driven above, MISO unused).
      --  Mode and clock are this display's; applied per hold at Acquire.
      ESP32S3.SPI.Setup (Host);
      ESP32S3.SPI.Configure_Pins (Host, Sclk => Sclk, Mosi => Mosi, Miso => ESP32S3.SPI.No_Pin);
   end Setup;

   -------------------------
   -- Acquire / Release --
   -------------------------

   procedure Acquire (S : in out Session; Dev : Device) is
   begin
      if not Dev.Configured then
         raise Not_Initialized with "ST7789 acquired before Setup";
      end if;
      Guards (Natural (Dev.CS)).Acquire;     --  suspends until this display free
      S.Active := True;
      S.Host := Dev.Host;
      S.Mode := Dev.Mode;
      S.Clock_Hz := Dev.Clock_Hz;
      S.DC := Dev.DC;
      S.CS := Dev.CS;
      S.RST := Dev.RST;
      S.W := Dev.W;
      S.H := Dev.H;
      S.X_Off := Dev.X_Off;
      S.Y_Off := Dev.Y_Off;
   end Acquire;

   procedure Release (S : in out Session) is
   begin
      if S.Active then
         S.Active := False;
         Guards (Natural (S.CS)).Release;
      end if;
   end Release;

   overriding
   procedure Finalize (S : in out Session) is
   begin
      Release (S);
   end Finalize;

   ----------------
   -- Initialize --
   ----------------

   procedure Init (S : Session) is
   begin
      Check_Owned (S);

      if S.RST /= ESP32S3.GPIO.No_Pin then
         declare
            Pin : constant ESP32S3.GPIO.Pin_Id := ESP32S3.GPIO.Pin_Id (S.RST);
         begin
            ESP32S3.GPIO.Set (Pin);
            delay until Clock + Milliseconds (10);
            ESP32S3.GPIO.Clear (Pin);                 --  reset pulse low
            delay until Clock + Milliseconds (10);
            ESP32S3.GPIO.Set (Pin);
            delay until Clock + Milliseconds (120);
         end;
      else
         Command (S, Cmd_SWRESET);
         delay until Clock + Milliseconds (150);
      end if;

      Command (S, Cmd_SLPOUT);
      delay until Clock + Milliseconds (120);
      Command (S, Cmd_COLMOD, (1 => 16#55#));          --  16-bit/pixel RGB565
      Command (S, Cmd_MADCTL, (1 => 16#00#));          --  default orientation
      Command (S, Cmd_INVON);                          --  ST7789 panels: on
      Command (S, Cmd_NORON);                          --  normal display mode
      Command (S, Cmd_DISPON);
      delay until Clock + Milliseconds (10);
   end Init;

   procedure Display_On (S : Session) is
   begin
      Check_Owned (S);
      Command (S, Cmd_DISPON);
   end Display_On;

   procedure Display_Off (S : Session) is
   begin
      Check_Owned (S);
      Command (S, Cmd_DISPOFF);
   end Display_Off;

   procedure Set_Rotation (S : Session; Rot : Rotation) is
      MADCTL : constant Byte :=   --  memory-access-control value for this rotation
        (case Rot is
           when Rot_0   => 16#00#,
           when Rot_90  => 16#60#,
           when Rot_180 => 16#C0#,
           when Rot_270 => 16#A0#);
   begin
      Check_Owned (S);
      Command (S, Cmd_MADCTL, (1 => MADCTL));
   end Set_Rotation;

   procedure Invert (S : Session; On : Boolean) is
   begin
      Check_Owned (S);
      Command (S, (if On then Cmd_INVON else Cmd_INVOFF));
   end Invert;

   procedure Sleep (S : Session; On : Boolean) is
   begin
      Check_Owned (S);
      Command (S, (if On then Cmd_SLPIN else Cmd_SLPOUT));
      delay until Clock + Milliseconds (120);
   end Sleep;

   ---------------
   -- Fill_Rect --
   ---------------

   procedure Fill_Rect (S : Session; X, Y, W, H : Natural; C : Color) is
      Bus    : ESP32S3.SPI.Session;
      Clip_W : Natural := W;                     --  width  clamped to the panel edge
      Clip_H : Natural := H;                     --  height clamped to the panel edge
      Hi     : constant Byte := Byte (C / 256);  --  high byte of the RGB565 colour
      Lo     : constant Byte := Byte (C mod 256);--  low byte
   begin
      Check_Owned (S);
      if X >= S.W or else Y >= S.H then
         return;
      end if;
      if X + Clip_W > S.W then
         Clip_W := S.W - X;
      end if;
      if Y + Clip_H > S.H then
         Clip_H := S.H - Y;
      end if;
      if Clip_W = 0 or else Clip_H = 0 then
         return;
      end if;

      ESP32S3.SPI.Acquire (Bus, S.Host, Mode => S.Mode, Clock_Hz => S.Clock_Hz);
      ESP32S3.GPIO.Clear (S.CS);
      Window (Bus, S, X, Y, X + Clip_W - 1, Y + Clip_H - 1);
      Cmd1 (Bus, S, Cmd_RAMWR);
      ESP32S3.GPIO.Set (S.DC);                         --  data phase

      declare
         PPC   : constant Natural := Chunk / 2;        --  pixels per chunk
         Count : Natural := Clip_W * Clip_H;
      begin
         for I in 0 .. PPC - 1 loop
            --  prefill the colour once
            Tx_Buf (S.Host) (2 * I) := Hi;
            Tx_Buf (S.Host) (2 * I + 1) := Lo;
         end loop;
         while Count > 0 loop
            declare
               N : constant Natural := Natural'Min (Count, PPC);
            begin
               Send (Bus, S.Host, N * 2);
               Count := Count - N;
            end;
         end loop;
      end;

      ESP32S3.GPIO.Set (S.CS);
   end Fill_Rect;

   ----------
   -- Fill --
   ----------

   procedure Fill (S : Session; C : Color) is
   begin
      Fill_Rect (S, 0, 0, S.W, S.H, C);
   end Fill;

   ---------------
   -- Set_Pixel --
   ---------------

   procedure Set_Pixel (S : Session; X, Y : Natural; C : Color) is
   begin
      Fill_Rect (S, X, Y, 1, 1, C);
   end Set_Pixel;

   -----------------
   -- Draw_Bitmap --
   -----------------

   procedure Draw_Bitmap (S : Session; X, Y, W, H : Natural; Pixels : Color_Array) is
      Bus : ESP32S3.SPI.Session;
      PPC : constant Natural := Chunk / 2;
      --  Clip to the panel and draw ONLY the visible sub-rectangle.  The source
      --  is row-major (W px per row), so a horizontally-clipped bitmap must skip
      --  the off-panel tail of every row: streaming Pixels linearly into an
      --  oversized window (X+W-1 past the right edge) would wrap the controller's
      --  RAMWR auto-increment and corrupt GRAM (the panel is only S.W columns).
      VW  : constant Natural := (if X >= S.W then 0 else Natural'Min (W, S.W - X));
      VH  : constant Natural := (if Y >= S.H then 0 else Natural'Min (H, S.H - Y));
   begin
      Check_Owned (S);
      if W = 0 or else H = 0 or else VW = 0 or else VH = 0 then
         return;
      end if;

      ESP32S3.SPI.Acquire (Bus, S.Host, Mode => S.Mode, Clock_Hz => S.Clock_Hz);
      ESP32S3.GPIO.Clear (S.CS);
      Window (Bus, S, X, Y, X + VW - 1, Y + VH - 1);   --  visible rect only
      Cmd1 (Bus, S, Cmd_RAMWR);
      ESP32S3.GPIO.Set (S.DC);

      --  Emit VW pixels from each of the first VH source rows; advancing the row
      --  base by the FULL W automatically drops each row's clipped-off tail.
      for Row in 0 .. VH - 1 loop
         declare
            Row_Start : constant Natural := Pixels'First + Row * W;
            Col       : Natural := 0;
         begin
            exit when Row_Start > Pixels'Last;        --  short array: stop cleanly
            while Col < VW loop
               declare
                  N : constant Natural :=
                    Natural'Min (Natural'Min (VW - Col, PPC), Pixels'Last - (Row_Start + Col) + 1);
               begin
                  exit when N = 0;
                  for K in 0 .. N - 1 loop
                     Tx_Buf (S.Host) (2 * K) := Byte (Pixels (Row_Start + Col + K) / 256);
                     Tx_Buf (S.Host) (2 * K + 1) := Byte (Pixels (Row_Start + Col + K) mod 256);
                  end loop;
                  Send (Bus, S.Host, N * 2);
                  Col := Col + N;
               end;
            end loop;
         end;
      end loop;

      ESP32S3.GPIO.Set (S.CS);
   end Draw_Bitmap;

   ---------
   -- RGB --
   ---------

   function RGB (R, G, B : Natural) return Color
   is (Color (Natural'Min (R, 255) / 8)
       * 2048
       + Color (Natural'Min (G, 255) / 4) * 32
       + Color (Natural'Min (B, 255) / 8));

end ESP32S3.ST7789;
