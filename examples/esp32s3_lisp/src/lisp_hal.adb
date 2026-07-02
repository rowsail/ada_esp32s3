with ESP32S3.GPIO;
with ESP32S3.ADC;
with ESP32S3.SPI;
with Interfaces; use Interfaces;
with System;
with Lisp;       use Lisp;
with Lisp.Eval;

package body Lisp_HAL is

   package GPIO renames ESP32S3.GPIO;
   package ADC renames ESP32S3.ADC;
   package SPI renames ESP32S3.SPI;

   ADC1 : ADC.Reader;                       --  claimed once in Register

   --  A handle registry for the stateful SPI driver: LISP holds a small integer id
   --  (not a raw access into the GC heap), which indexes this library-level table
   --  -- so the session outlives the LISP handle and no accessibility rule is bent.
   Max_SPI  : constant := 4;
   Sessions : array (1 .. Max_SPI) of aliased SPI.Session;
   N_SPI    : Natural := 0;

   function Pin_Of (Args : Ref) return GPIO.Pin_Id
   is (GPIO.Pin_Id (Int_Value (Car (Args))));

   --  (gpio-out PIN VAL): configure output, drive, return VAL.
   function Prim_Gpio_Out (Args : Ref) return Ref is
      Pin : constant GPIO.Pin_Id := Pin_Of (Args);
      Val : constant Ref := Car (Cdr (Args));
   begin
      GPIO.Configure (Pin, GPIO.Output);
      GPIO.Write (Pin, Is_Truthy (Val));
      return Val;
   end Prim_Gpio_Out;

   --  (gpio-toggle PIN): flip an output pin.
   function Prim_Gpio_Toggle (Args : Ref) return Ref is
   begin
      GPIO.Toggle (Pin_Of (Args));
      return Nil;
   end Prim_Gpio_Toggle;

   --  (gpio-in PIN): configure input, return the level.
   function Prim_Gpio_In (Args : Ref) return Ref is
      Pin : constant GPIO.Pin_Id := Pin_Of (Args);
   begin
      GPIO.Configure (Pin, GPIO.Input);
      return Make_Bool (GPIO.Read (Pin));
   end Prim_Gpio_In;

   --  (adc-read CH): one ADC1 sample, 0 .. 4095.
   function Prim_Adc_Read (Args : Ref) return Ref is
      Ch : constant ADC.Channel_Index := ADC.Channel_Index (Int_Value (Car (Args)));
   begin
      return Make_Int (Long_Long_Integer (ADC.Read (ADC1, Ch)));
   end Prim_Adc_Read;

   --  (room): cells currently in use -- watch GC keep it bounded across forms.
   function Prim_Room (Args : Ref) return Ref is
      pragma Unreferenced (Args);
   begin
      return Make_Int (Long_Long_Integer (Lisp.Cells_Used));
   end Prim_Room;

   --  (spi-open): bring up SPI2 for the on-board flash (SCLK=1 MOSI=4 MISO=45,
   --  CS=21, mode 0, 8 MHz) and return a handle.
   function Prim_Spi_Open (Args : Ref) return Ref is
      pragma Unreferenced (Args);
   begin
      if N_SPI >= Max_SPI then
         raise Lisp_Error with "too many SPI handles";
      end if;
      N_SPI := N_SPI + 1;
      SPI.Setup (SPI.SPI2);
      SPI.Configure_Pins (SPI.SPI2, Sclk => 1, Mosi => 4, Miso => 45);
      SPI.Acquire (Sessions (N_SPI), SPI.SPI2, Mode => 0, Clock_Hz => 8_000_000, CS_Pin => 21);
      return Make_Int (Long_Long_Integer (N_SPI));
   end Prim_Spi_Open;

   --  (spi-xfer HANDLE BYTES): full-duplex transfer; BYTES is a list of 0..255,
   --  returns the received bytes as a list.
   function Prim_Spi_Xfer (Args : Ref) return Ref is
      Id  : constant Natural := Natural (Int_Value (Car (Args)));
      Lst : constant Ref := Car (Cdr (Args));
      N   : Natural := 0;
      P   : Ref := Lst;
   begin
      if Id not in 1 .. N_SPI then
         raise Lisp_Error with "bad SPI handle";
      end if;
      while Is_Cons (P) loop
         N := N + 1;
         P := Cdr (P);
      end loop;
      if N = 0 then
         return Nil;
      end if;
      declare
         Tx     : array (0 .. N - 1) of Unsigned_8;          --  stack = internal SRAM (DMA)
         Rx     : array (0 .. N - 1) of Unsigned_8 := (others => 0);
         I      : Natural := 0;
         Q      : Ref := Lst;
         Result : Ref := Nil;
      begin
         while Is_Cons (Q) loop
            Tx (I) := Unsigned_8 (Int_Value (Car (Q)) mod 256);
            I := I + 1;
            Q := Cdr (Q);
         end loop;
         SPI.Select_Device (Sessions (Id), True);
         SPI.Transfer (Sessions (Id), Tx'Address, Rx'Address, N);
         SPI.Select_Device (Sessions (Id), False);
         for J in reverse 0 .. N - 1 loop
            Result := Cons (Make_Int (Long_Long_Integer (Rx (J))), Result);
         end loop;
         return Result;
      end;
   end Prim_Spi_Xfer;

   procedure Register is
   begin
      ADC.Claim (ADC1, ADC.ADC1);
      Lisp.Eval.Register_Primitive ("gpio-out", Prim_Gpio_Out'Access);
      Lisp.Eval.Register_Primitive ("gpio-toggle", Prim_Gpio_Toggle'Access);
      Lisp.Eval.Register_Primitive ("gpio-in", Prim_Gpio_In'Access);
      Lisp.Eval.Register_Primitive ("adc-read", Prim_Adc_Read'Access);
      Lisp.Eval.Register_Primitive ("room", Prim_Room'Access);
      Lisp.Eval.Register_Primitive ("spi-open", Prim_Spi_Open'Access);
      Lisp.Eval.Register_Primitive ("spi-xfer", Prim_Spi_Xfer'Access);
   end Register;

end Lisp_HAL;
