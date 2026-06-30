with Interfaces;                       use Interfaces;
with Ada.Text_IO;                      use Ada.Text_IO;
with Ada.Real_Time;                    use Ada.Real_Time;
with System;
with ESP32S3.GPIO;
with ESP32S3.RNG;
with ESP32S3.Temperature;
with ESP32S3.SPI;
with ESP32S3.I2C;
with ESP32S3.UART;
with ESP32S3.GDMA;
with ESP32S3.MCPWM;
with ESP32S3.I2S;
with ESP32S3.LEDC;
with ESP32S3.RMT;
with ESP32S3.PCNT;
with ESP32S3.SDM;
with ESP32S3.TWAI;
with ESP32S3.Timer;
with ESP32S3.LCD;
with ESP32S3.ADC;
with ESP32S3.RTC;
with ESP32S3.RTC_IO;
with ESP32S3.Touch;
with ESP32S3.SHA;
with ESP32S3.AES;
with ESP32S3.SD_SPI;
with ESP32S3.SDMMC;
with ESP32S3.Block_Dev;
with ESP32S3.Block_Dev.SD_SPI_Source;
with ESP32S3.Block_Dev.W25Q_Source;
with ESP32S3.Block_Dev.WL;
with ESP32S3.W25Q;
with ESP32S3.Ext4;
with ESP32S3.Ext4.FS;
with ESP32S3.Ext4.Inode;
with ESP32S3.Ext4.Mkfs;

package body Book_Examples is

   ---------------------------------------------------------------- ch_hal --

   procedure GPIO_Blink is
      use ESP32S3.GPIO;
      Led : constant Pin_Id := 2;
   begin
      Configure (Led, Mode => Output);
      loop
         Toggle (Led);
         delay until Clock + Milliseconds (250);
      end loop;
   end GPIO_Blink;

   procedure GPIO_Button is
      use ESP32S3.GPIO;
      Button_Pin : constant Pin_Id := 9;
      Led        : constant Pin_Id := 2;
   begin
      Configure (Button_Pin, Mode => Input, Pull => Pull_Up);
      Configure (Led,        Mode => Output);
      loop
         Write (Led, not Read (Button_Pin));
      end loop;
   end GPIO_Button;

   procedure RNG_Word is
      X : constant ESP32S3.RNG.Word := ESP32S3.RNG.Read;
   begin
      Put_Line (ESP32S3.RNG.Word'Image (X));
   end RNG_Word;

   procedure RNG_Nonce is
      Nonce : ESP32S3.RNG.Byte_Array (0 .. 15);
   begin
      ESP32S3.RNG.Fill (Nonce);
   end RNG_Nonce;

   procedure Temp_Degrees is
      use ESP32S3.Temperature;
   begin
      Initialize;
      Put_Line ("die temp =" & Integer'Image (Read_Celsius) & " C");
   end Temp_Degrees;

   procedure Temp_Centi is
      use ESP32S3.Temperature;
   begin
      Initialize (Span => Range_50_125);
      declare
         Centi : constant Integer := Read_Centi_Celsius;
      begin
         Put_Line ("temp =" & Integer'Image (Centi / 100) & "." &
                   Integer'Image (Centi mod 100) & " C");
      end;
   end Temp_Centi;

   procedure SPI_Write_Dev is
      use ESP32S3.SPI;
      S  : Session;
      Tx : aliased array (0 .. 2) of Interfaces.Unsigned_8 := (16#9F#, 0, 0);
      Rx : aliased array (0 .. 2) of Interfaces.Unsigned_8;
   begin
      Setup (SPI2);
      Configure_Pins (SPI2, Sclk => 12, Mosi => 11, Miso => 13, Cs => 10);
      Acquire (S, SPI2, Mode => 0, Clock_Hz => 8_000_000);   --  per-device
      Transfer (S, Tx'Address, Rx'Address, 3);
   end SPI_Write_Dev;

   procedure SPI_Loopback is
      use ESP32S3.SPI;
      S  : Session;
      Tx : aliased array (0 .. 31) of Interfaces.Unsigned_8 := (others => 16#A5#);
      Rx : aliased array (0 .. 31) of Interfaces.Unsigned_8 := (others => 0);
   begin
      Setup (SPI2);
      Enable_Loopback (SPI2, Pad => 5);
      Acquire (S, SPI2);
      Transfer (S, Tx'Address, Rx'Address, 32);
   end SPI_Loopback;

   --  Library-level, closure-free chip-select callback: IO10 low = selected.
   procedure CS_IO10 (Ctx : System.Address; Active : Boolean) is
      pragma Unreferenced (Ctx);
   begin
      if Active then
         ESP32S3.GPIO.Clear (10);
      else
         ESP32S3.GPIO.Set (10);
      end if;
   end CS_IO10;

   procedure SPI_App_CS is
      use ESP32S3.SPI;
      S  : Session;
      Tx : aliased array (0 .. 1) of Interfaces.Unsigned_8 := (16#9F#, 0);
      Rx : aliased array (0 .. 1) of Interfaces.Unsigned_8;
   begin
      Setup (SPI2);
      Configure_Pins (SPI2, Sclk => 12, Mosi => 11, Miso => 13);
      Acquire (S, SPI2, Clock_Hz => 8_000_000,
               Select_CB => CS_IO10'Access);             --  bring our own select
      Select_Device (S, On => True);
      Transfer (S, Tx'Address, Rx'Address, 2);
      Select_Device (S, On => False);
   end SPI_App_CS;

   procedure I2C_Write_Reg is
      use ESP32S3.I2C;
      S  : Session;
      Ok : Boolean;
   begin
      Setup (I2C0, Clock_Hz => 400_000);
      Configure_Pins (I2C0, Scl => 9, Sda => 8);
      Acquire (S, I2C0);
      Write (S, Addr => 16#68#, Data => (16#6B#, 16#00#), Success => Ok);
   end I2C_Write_Reg;

   procedure I2C_Read_Reg is
      use ESP32S3.I2C;
      S   : Session;
      Ok  : Boolean;
      Who : Byte_Array (0 .. 0);
   begin
      Setup (I2C0, Clock_Hz => 400_000);
      Configure_Pins (I2C0, Scl => 9, Sda => 8);
      Acquire (S, I2C0);
      Write (S, 16#68#, (1 => 16#75#), Ok);
      Read  (S, 16#68#, Who, Ok);
   end I2C_Read_Reg;

   procedure UART_Tx is
      use ESP32S3.UART;
      S : Session;
   begin
      Setup (UART1, Baud => 115_200, Tx => 17, Rx => 16);
      Acquire (S, UART1);
      Write (S, (Character'Pos ('h'), Character'Pos ('i'), 10));
   end UART_Tx;

   procedure UART_Reconfig is
      use ESP32S3.UART;
      S : Session;
   begin
      Setup (UART1, Tx => 17, Rx => 16);   --  115200 8-N-1 to start
      Acquire (S, UART1);                  --  own the port before reconfiguring
      Set_Baud      (S, 9_600);            --  then change each attribute alone
      Set_Data_Bits (S, 7);
      Set_Parity    (S, Even);
      Set_Stop_Bits (S, Two);              --  now 9600 7-E-2
      Write (S, (1 => 16#55#));
   end UART_Reconfig;

   procedure UART_Echo is
      use ESP32S3.UART;
      S   : Session;
      Buf : Byte_Array (0 .. 63);
      N   : Natural;
   begin
      Setup (UART1);
      Acquire (S, UART1);
      Enable_Loopback (S);
      Write (S, (1 => 16#42#));
      loop
         exit when Available (S) > 0;
      end loop;
      Read (S, Buf, N);
   end UART_Echo;

   --------------------------------------------------------------- ch_hal2 --

   procedure GDMA_Copy is
      use ESP32S3.GDMA;
      C   : Channel;
      Src : aliased array (0 .. 255) of Interfaces.Unsigned_8 := (others => 16#5A#);
      Dst : aliased array (0 .. 255) of Interfaces.Unsigned_8 := (others => 0);
   begin
      Claim (C, Peri => Mem2Mem);
      Copy  (C, Dst'Address, Src'Address, 256);
   end GDMA_Copy;

   procedure GDMA_RAII is
      use ESP32S3.GDMA;
      A, B, C2, D, E : Channel;
   begin
      Claim (A, Mem2Mem); Claim (B, Mem2Mem); Claim (C2, Mem2Mem);
      Claim (D, Mem2Mem); Claim (E, Mem2Mem);
   end GDMA_RAII;

   procedure MCPWM_Simple is
      use ESP32S3.MCPWM;
      C : Channel;
   begin
      Setup (MCPWM0);
      Claim (C, MCPWM0, Ch0);
      Configure_Channel (C, Freq => 20_000, Pin => 4);
      Set_Duty (C, 25.0);
      Start (C);
   end MCPWM_Simple;

   procedure MCPWM_Pair is
      use ESP32S3.MCPWM;
      C : Channel;
   begin
      Setup (MCPWM0);
      Claim (C, MCPWM0, Ch0);
      Configure_Channel (C, Freq => 20_000, Pin => 4,
                         Complement_Pin => 5, Dead_Time_Ns => 500);
      Set_Duty (C, 60.0);
      Start (C);
   end MCPWM_Pair;

   procedure I2S_Play is
      use ESP32S3.I2S;
      S    : Session;
      Tone : PCM_16 (0 .. 255) := (others => 0);
   begin
      Acquire (S, I2S0, Sample_Rate => 44_100, Bits => Bits_16,
               Bclk => 4, Ws => 5, Dout => 6);
      Write (S, Tone);
   end I2S_Play;

   procedure I2S_Loopback is
      use ESP32S3.I2S;
      S  : Session;
      Tx : PCM_16 (0 .. 63) := (others => 0);
      Rx : PCM_16 (0 .. 63) := (others => 0);
   begin
      Acquire (S, I2S0);
      Enable_Loopback (S, Pad => 7);
      Transfer (S, Tx, Rx);
   end I2S_Loopback;

   procedure LEDC_Simple is
      use ESP32S3.LEDC;
      C : Channel;
   begin
      Claim (C, 0);
      Configure (C, Freq => 5_000, Pin => 2);
      Set_Duty (C, 50.0);
   end LEDC_Simple;

   procedure LEDC_Fade is
      use ESP32S3.LEDC;
      C : Channel;
   begin
      Claim (C, 0);
      Configure (C, Freq => 5_000, Pin => 2);
      for D in 0 .. 100 loop
         Set_Duty (C, Duty_Percent (D));
         delay until Clock + Milliseconds (10);
      end loop;
   end LEDC_Fade;

   procedure RMT_Tx is
      use ESP32S3.RMT;
      Tx    : TX_Channel;
      Burst : constant Symbol_Array :=
        ((Level0 => True, Duration0 => 10, Level1 => False, Duration1 => 10),
         (Level0 => True, Duration0 => 20, Level1 => False, Duration1 => 20));
   begin
      Claim (Tx, 0);
      Configure (Tx, Resolution_Hz => 1_000_000, Pin => 4);
      Transmit (Tx, Burst);
   end RMT_Tx;

   procedure RMT_Rx is
      use ESP32S3.RMT;
      Rx   : RX_Channel;
      Syms : Symbol_Array (0 .. 63);
      N    : Natural;
   begin
      Claim (Rx, 0);
      Configure (Rx, Resolution_Hz => 1_000_000, Pin => 5);
      Start (Rx);
      Receive (Rx, Syms, N);
   end RMT_Rx;

   procedure PCNT_Count is
      use ESP32S3.PCNT;
      U : Unit;
   begin
      Claim (U, 0);
      Configure (U, Pin => 6);
      Clear (U);
      Put_Line ("edges =" & Integer'Image (Count (U)));
   end PCNT_Count;

   procedure PCNT_Both is
      use ESP32S3.PCNT;
      U : Unit;
   begin
      Claim (U, 0);
      Configure (U, Pin => 6, Both_Edges => True);
   end PCNT_Both;

   procedure SDM_Density is
      use ESP32S3.SDM;
      C : Channel;
   begin
      Claim (C, 0);
      Configure (C, Pin => 7, Carrier_Hz => 1_000_000);
      Set_Density (C, 25.0);
   end SDM_Density;

   procedure SDM_Breathe is
      use ESP32S3.SDM;
      C : Channel;
   begin
      Claim (C, 0);
      Configure (C, Pin => 7);
      for P in 0 .. 100 loop
         Set_Density (C, Density_Percent (P));
         delay until Clock + Milliseconds (10);
      end loop;
   end SDM_Breathe;

   procedure TWAI_Send is
      use ESP32S3.TWAI;
      S : Session;
   begin
      Setup (Mode => Normal, Bit_Rate => 500_000);
      Acquire (S);                          --  own the controller, then route pins
      Configure_Pins (S, Tx => 4, Rx => 5);
      Send (S, Standard_Frame'(Id => 16#123#, Remote => False, Length => 2,
                               Data => (16#DE#, 16#AD#, others => 0)));
      Send (S, Extended_Frame'(Id => 16#14AB_CDE#, Remote => False, Length => 1,
                               Data => (0 => 16#42#, others => 0)));  -- type picks Send
      Send (S, Standard_Frame'(Id => 16#7A5#, Remote => True,        -- RTR: request
                               Length => 8, Data => (others => 0)));  -- 8 bytes, none sent
   end TWAI_Send;

   procedure TWAI_Selftest is
      use ESP32S3.TWAI;
      S   : Session;
      RE  : Extended_Frame;
      Got : Boolean := False;
   begin
      Setup (Mode => Self_Test);
      Acquire (S);
      Enable_Loopback (S, Pad => 4);
      Send (S, Extended_Frame'(Id => 16#14AB_CDE#, Remote => False, Length => 1,
                               Data => (0 => 16#42#, others => 0)));
      if Available (S) and then Is_Extended (S) then
         Receive (S, RE, Got);   --  Got, RE.Id = 16#14AB_CDE#, RE.Remote = False
      end if;
   end TWAI_Selftest;

   procedure Timer_Measure is
      use ESP32S3.Timer;
      T       : Timer;
      Start_T : Ticks;
   begin
      Claim (T, 0);
      Configure (T, Tick_Hz => 1_000_000);
      Start (T);
      Start_T := Value (T);
      Put_Line ("elapsed us =" & Ticks'Image (Value (T) - Start_T));
   end Timer_Measure;

   procedure Timer_Alarm is
      use ESP32S3.Timer;
      T : Timer;
   begin
      Claim (T, 0);
      Configure (T, Tick_Hz => 1_000_000);
      Start (T);
      Set_Alarm (T, Value (T) + 50_000);
      loop exit when Alarm_Fired (T); end loop;
      Clear_Alarm (T);
   end Timer_Alarm;

   procedure LCD_Frame is
      use ESP32S3.LCD;
      S  : Session;
      Ok : Boolean;
      FB : aliased array (0 .. 3999) of Interfaces.Unsigned_8 := (others => 16#FF#);
   begin
      Setup (Pclk_Hz => 200_000);
      Acquire (S);
      Configure_Pins (S, Data => (1, 2, 3, 4, 5, 6, 7, 8), Pclk => 9);
      Transmit (S, FB'Address, FB'Length, Ok);
   end LCD_Frame;

   procedure LCD_Clk is
      use ESP32S3.LCD;
      S : Session;
   begin
      Setup;
      Acquire (S);
      Enable_Clock_Out (S, Pclk_Pad => 9);
   end LCD_Clk;

   procedure ADC_Read_Sample is
      use ESP32S3.ADC;
      R : Reader;
      V : Raw_Value;
   begin
      Claim (R, ADC1);
      V := Read (R, Ch => 0);
      Put_Line (Raw_Value'Image (V));
   end ADC_Read_Sample;

   procedure ADC_Atten is
      use ESP32S3.ADC;
      R : Reader;
      V : Raw_Value;
   begin
      Claim (R, ADC1);
      V := Read (R, Ch => 3, Atten => Db_0);
      Put_Line (Raw_Value'Image (V));
   end ADC_Atten;

   --------------------------------------------------------------- ch_hal3 --

   procedure RTC_Boot is
      use ESP32S3.RTC;
      N : Interfaces.Unsigned_32;
   begin
      if Last_Wake = Deep_Sleep_Timer then
         N := Read (0) + 1;
      else
         N := 1;
      end if;
      Write (0, N);
      Put_Line ("boot #" & N'Image);
      Deep_Sleep_For (5.0);
   end RTC_Boot;

   procedure RTC_Wake is
      use ESP32S3.RTC;
   begin
      Deep_Sleep_Until (Pin => 0, High => False);
   end RTC_Wake;

   procedure RTCIO_Hold is
   begin
      ESP32S3.GPIO.Configure (5, Mode => ESP32S3.GPIO.Output);
      ESP32S3.GPIO.Set (5);
      ESP32S3.RTC_IO.Hold (5);
      ESP32S3.RTC_IO.Release (5);
   end RTCIO_Hold;

   procedure RTCIO_Pull is
      use ESP32S3.RTC_IO;
   begin
      Set_Pull (0, Up);
   end RTCIO_Pull;

   procedure Touch_Read_Base is
      use ESP32S3.Touch;
   begin
      Setup;  Enable (1);  Enable (3);
      Put_Line ("ch1 =" & Natural'Image (Read (1)) &
                "  ch3 =" & Natural'Image (Read (3)));
   end Touch_Read_Base;

   procedure Touch_Detect is
      use ESP32S3.Touch;
      Base : constant Natural := Read (1);
   begin
      loop
         if Touched (1, Base, Margin => 50_000) then
            Put_Line ("touched!");
         end if;
      end loop;
   end Touch_Detect;

   procedure SHA_256_Ex is
      use ESP32S3.SHA;
      Msg    : constant Byte_Array := (16#61#, 16#62#, 16#63#);
      Digest : constant SHA256_Digest := Hash_256 (Msg);
      pragma Unreferenced (Digest);
   begin
      null;
   end SHA_256_Ex;

   procedure SHA_1_Ex is
      use ESP32S3.SHA;
      Msg : constant Byte_Array := (16#61#, 16#62#, 16#63#);
      D1  : constant SHA1_Digest := Hash_1 (Msg);
      pragma Unreferenced (D1);
   begin
      null;
   end SHA_1_Ex;

   procedure AES_128_Ex is
      use ESP32S3.AES;
      Key    : constant Key_128 := (16#00#, 16#01#, 16#02#, 16#03#, 16#04#, 16#05#,
                                    16#06#, 16#07#, 16#08#, 16#09#, 16#0A#, 16#0B#,
                                    16#0C#, 16#0D#, 16#0E#, 16#0F#);
      Plain  : constant Block := (others => 16#11#);
      Cipher : constant Block := Encrypt_ECB (Key, Plain);
      Back   : constant Block := Decrypt_ECB (Key, Cipher);
      pragma Unreferenced (Back);
   begin
      null;
   end AES_128_Ex;

   procedure AES_256_Ex is
      use ESP32S3.AES;
      Key256 : constant Key_256 := (others => 16#2B#);
      Plain  : constant Block := (others => 16#11#);
      C      : constant Block := Encrypt_ECB (Key256, Plain);
      pragma Unreferenced (C);
   begin
      null;
   end AES_256_Ex;

   ------------------------------------------------------------ ch_storage --

   procedure SD_Init is
      use ESP32S3.SD_SPI;
      C   : Card;
      St  : Status;
      Sec : Block;
   begin
      Setup (C, ESP32S3.SPI.SPI2, Sclk => 12, Mosi => 11, Miso => 13, Cs => 10);
      Initialize (C, St);
      if St = OK then
         Read_Block (C, LBA => 0, Data => Sec, Result => St);
      end if;
   end SD_Init;

   procedure SD_Roundtrip is
      use ESP32S3.SD_SPI;
      C          : Card;
      St         : Status;
      Orig, Back : Block;
   begin
      Setup (C, ESP32S3.SPI.SPI2, Sclk => 12, Mosi => 11, Miso => 13, Cs => 10);
      Initialize (C, St);
      Read_Block  (C, 16#2000#, Orig, St);
      Write_Block (C, 16#2000#, Orig, St);
      Read_Block  (C, 16#2000#, Back, St);
   end SD_Roundtrip;

   procedure SDMMC_Read_Ex is
      use ESP32S3.SDMMC;
      C   : Card;
      St  : Status;
      Sec : Block;
   begin
      Setup (C, On => Slot1, Clk => 14, Cmd => 15, D0 => 2, D1 => 4, D2 => 12,
             D3 => 13, Width => Width_4);
      Initialize (C, St);
      if St = OK then
         Read_Block (C, 0, Sec, St);
      end if;
   end SDMMC_Read_Ex;

   procedure EXT4_Read is
      use type ESP32S3.SD_SPI.Status;
      Card : aliased ESP32S3.SD_SPI.Card;
      St   : ESP32S3.SD_SPI.Status;
   begin
      ESP32S3.SD_SPI.Setup (Card, ESP32S3.SPI.SPI2,
                            Sclk => 12, Mosi => 11, Miso => 13, Cs => 10);
      ESP32S3.SD_SPI.Initialize (Card, St);
      if St /= ESP32S3.SD_SPI.OK then
         return;
      end if;
      declare
         Dev  : constant ESP32S3.Block_Dev.Device :=
                  ESP32S3.Block_Dev.SD_SPI_Source.Make (Card'Access);
         M    : ESP32S3.Ext4.FS.Mount;
         I    : ESP32S3.Ext4.Inode.Info;
         Buf  : ESP32S3.Ext4.Byte_Array (0 .. 255);
         Last : Natural;
      begin
         M.Open (Dev, Read_Only => True);
         M.Stat (M.Lookup ("/etc/hello.txt"), I);
         M.Read_File (I, Offset => 0, Into => Buf, Last => Last);
      end;
   end EXT4_Read;

   procedure EXT4_List is
      use type ESP32S3.SD_SPI.Status;
      Card : aliased ESP32S3.SD_SPI.Card;
      St   : ESP32S3.SD_SPI.Status;
   begin
      ESP32S3.SD_SPI.Setup (Card, ESP32S3.SPI.SPI2,
                            Sclk => 12, Mosi => 11, Miso => 13, Cs => 10);
      ESP32S3.SD_SPI.Initialize (Card, St);
      if St /= ESP32S3.SD_SPI.OK then
         return;
      end if;
      declare
         Dev  : constant ESP32S3.Block_Dev.Device :=
                  ESP32S3.Block_Dev.SD_SPI_Source.Make (Card'Access);
         M    : ESP32S3.Ext4.FS.Mount;
         Root : ESP32S3.Ext4.Inode.Info;
         procedure Show (Name : String;
                         Ino  : ESP32S3.Ext4.Inode_Number;
                         File_Type : ESP32S3.Ext4.U8) is
            pragma Unreferenced (Ino, File_Type);
         begin
            Put_Line ("  " & Name);
         end Show;
      begin
         M.Open (Dev, Read_Only => True);
         M.Stat (M.Lookup ("/"), Root);
         M.Iterate (Root, Show'Access);
      end;
   end EXT4_List;

   procedure EXT4_Write is
      use type ESP32S3.SD_SPI.Status;
      Card : aliased ESP32S3.SD_SPI.Card;
      St   : ESP32S3.SD_SPI.Status;
   begin
      ESP32S3.SD_SPI.Setup (Card, ESP32S3.SPI.SPI2,
                            Sclk => 12, Mosi => 11, Miso => 13, Cs => 10);
      ESP32S3.SD_SPI.Initialize (Card, St);
      if St /= ESP32S3.SD_SPI.OK then
         return;
      end if;
      declare
         Dev : constant ESP32S3.Block_Dev.Device :=
                 ESP32S3.Block_Dev.SD_SPI_Source.Make (Card'Access);
         M   : ESP32S3.Ext4.FS.Mount;
         N   : ESP32S3.Ext4.Inode_Number;
      begin
         M.Open (Dev, Read_Only => False);
         N := M.Create_File ("/", "log.txt");
         M.Write_File (N, (Character'Pos ('h'), Character'Pos ('i'), 10));
         M.Mkdir ("/", "data");
         M.Close;
      end;
   end EXT4_Write;

   procedure EXT4_Commit is
      use type ESP32S3.SD_SPI.Status;
      Card    : aliased ESP32S3.SD_SPI.Card;
      St      : ESP32S3.SD_SPI.Status;
      Payload : constant ESP32S3.Ext4.Byte_Array := (16#41#, 16#42#, 16#43#);
   begin
      ESP32S3.SD_SPI.Setup (Card, ESP32S3.SPI.SPI2,
                            Sclk => 12, Mosi => 11, Miso => 13, Cs => 10);
      ESP32S3.SD_SPI.Initialize (Card, St);
      if St /= ESP32S3.SD_SPI.OK then
         return;
      end if;
      declare
         Dev : constant ESP32S3.Block_Dev.Device :=
                 ESP32S3.Block_Dev.SD_SPI_Source.Make (Card'Access);
         M   : ESP32S3.Ext4.FS.Mount;
         N   : ESP32S3.Ext4.Inode_Number;
      begin
         M.Open (Dev, Read_Only => False);
         N := M.Create_File ("/", "important.txt");
         M.Write_File (N, Payload);
         M.Commit;
      end;
   end EXT4_Commit;

   procedure EXT4_Append is
      M     : ESP32S3.Ext4.FS.Mount;
      N     : ESP32S3.Ext4.Inode_Number;
      Chunk : constant ESP32S3.Ext4.Byte_Array (0 .. 255) := (others => 0);
   begin
      N := M.Create_File ("/", "big.log");
      for I in 1 .. 1000 loop          --  grow it a chunk at a time, no big buffer
         M.Append (N, Chunk);
      end loop;
      M.Commit;
   end EXT4_Append;

   --  The flash select is one plain GPIO (IO21): set CS_Pin and the SPI driver
   --  drives it active-low, held across each command -- no callback needed.
   procedure W25Q_Probe is
      use ESP32S3.W25Q;
      Flash   : ESP32S3.W25Q.Flash :=
        (Host => ESP32S3.SPI.SPI2, CS_Pin => 21, others => <>);
      ID      : JEDEC_ID;
      Mode_OK : Boolean;
   begin
      Read_Identification (Flash, ID);          --  EF 40 19 on a W25Q256FV
      Initialize (Flash, Mode_OK);              --  enter 4-byte address mode
      if ID.Manufacturer = 16#EF# and then Capacity_Bytes (ID) /= 0 then
         null;                                  --  Capacity_Bytes (ID) = 32 MB
      end if;
   end W25Q_Probe;

   procedure Flash_Stack is
      use ESP32S3.W25Q;
      package BDW renames ESP32S3.Block_Dev.W25Q_Source;
      package WL  renames ESP32S3.Block_Dev.WL;
      Flash      : ESP32S3.W25Q.Flash :=
        (Host => ESP32S3.SPI.SPI2, CS_Pin => 21, others => <>);
      Raw       : aliased BDW.Source;
      Vol       : aliased WL.Volume;
      Dev       : ESP32S3.Block_Dev.Device;
      Formatted : Boolean;
      pragma Unreferenced (Dev);
   begin
      BDW.Configure (Raw, Flash => Flash);      --  auto-size from the JEDEC id
      WL.Attach (Vol, BDW.Make (Raw'Access));   --  wear-leveling volume over it
      WL.Mount  (Vol, Formatted);               --  recover the saved wear state
      Dev := WL.Make (Vol'Access);              --  a 512-byte Block_Dev for ext4
   end Flash_Stack;

   procedure Flash_Mkfs is
      use ESP32S3.W25Q;
      package BDW renames ESP32S3.Block_Dev.W25Q_Source;
      package WL  renames ESP32S3.Block_Dev.WL;
      Flash      : ESP32S3.W25Q.Flash :=
        (Host => ESP32S3.SPI.SPI2, CS_Pin => 21, others => <>);
      Raw : aliased BDW.Source;
      Vol : aliased WL.Volume;
      Dev : ESP32S3.Block_Dev.Device;
      M   : ESP32S3.Ext4.FS.Mount;
      N   : ESP32S3.Ext4.Inode_Number;
   begin
      BDW.Configure (Raw, Flash => Flash);
      WL.Attach (Vol, BDW.Make (Raw'Access));
      WL.Format (Vol);                          --  fresh wear-leveling volume
      Dev := WL.Make (Vol'Access);

      ESP32S3.Ext4.Mkfs.Format (Dev, Volume_Label => "FLASH", Journal => True);
      M.Open (Dev, Read_Only => False);
      N := M.Create_File ("/", "boot.txt");
      M.Write_File (N, (Character'Pos ('h'), Character'Pos ('i'), 10));
      M.Commit;
   end Flash_Mkfs;

end Book_Examples;
