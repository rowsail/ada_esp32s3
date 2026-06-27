--  Every worked example from the book, as a compilable procedure.  Built
--  against the real HAL (embedded profile, xtensa) by verify.gpr to prove the
--  book's code actually compiles.  The book listings mirror these bodies.
package Book_Examples is
   --  ch_hal
   procedure GPIO_Blink;       procedure GPIO_Button;
   procedure RNG_Word;         procedure RNG_Nonce;
   procedure Temp_Degrees;     procedure Temp_Centi;
   procedure SPI_Write_Dev;    procedure SPI_Loopback;
   procedure SPI_App_CS;
   procedure I2C_Write_Reg;    procedure I2C_Read_Reg;
   procedure UART_Tx;          procedure UART_Echo;
   procedure UART_Reconfig;
   --  ch_hal2
   procedure GDMA_Copy;        procedure GDMA_RAII;
   procedure MCPWM_Simple;     procedure MCPWM_Pair;
   procedure I2S_Play;         procedure I2S_Loopback;
   procedure LEDC_Simple;      procedure LEDC_Fade;
   procedure RMT_Tx;           procedure RMT_Rx;
   procedure PCNT_Count;       procedure PCNT_Both;
   procedure SDM_Density;      procedure SDM_Breathe;
   procedure TWAI_Send;        procedure TWAI_Selftest;
   procedure Timer_Measure;    procedure Timer_Alarm;
   procedure LCD_Frame;        procedure LCD_Clk;
   procedure ADC_Read_Sample;  procedure ADC_Atten;
   --  ch_hal3
   procedure RTC_Boot;         procedure RTC_Wake;
   procedure RTCIO_Hold;       procedure RTCIO_Pull;
   procedure Touch_Read_Base;  procedure Touch_Detect;
   procedure SHA_256_Ex;       procedure SHA_1_Ex;
   procedure AES_128_Ex;       procedure AES_256_Ex;
   --  ch_storage
   procedure SD_Init;          procedure SD_Roundtrip;
   procedure SDMMC_Read_Ex;
   procedure EXT4_Read;        procedure EXT4_List;
   procedure EXT4_Write;       procedure EXT4_Commit;
   procedure EXT4_Append;
   procedure W25Q_Probe;       procedure Flash_Stack;
   procedure Flash_Mkfs;
end Book_Examples;
