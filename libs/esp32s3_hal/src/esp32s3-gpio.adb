--  ESP32-S3 GPIO driver body. Maps the pin abstraction onto the generated
--  register layer: IO_MUX (per-pad function/drive/pull/input-enable), the GPIO
--  matrix output route (FUNC_OUT_SEL_CFG.OUT_SEL = 256 = plain GPIO out), and the
--  OUT/ENABLE/IN banks with their atomic W1TS/W1TC set/clear. Pins 0..31 use the
--  32-bit banks; pins 32..48 use the "*1" banks -- the split is hidden here.
with ESP32S3_Registers; use ESP32S3_Registers;

package body ESP32S3.GPIO is

   package Reg renames ESP32S3_Registers.GPIO;
   package Mux renames ESP32S3_Registers.IO_MUX;

   --  Single-bit masks (modular exponentiation: no Integer overflow at bit 31).
   --
   --  The preconditions are what let SPARK discharge the shift: Pin_Id's own
   --  predicate is 0 .. 21 | 38 .. 48, so "Pin <= 31" at a call site means
   --  Pin <= 21 and "Pin > 31" means Pin >= 38 -- and both exponents are then
   --  in range for the result type.  Without them the subtraction in Hi_Bit
   --  could underflow Natural.
   function Lo_Bit (Pin : Pin_Id) return UInt32
   is (UInt32'(2)**Natural (Pin))
   with SPARK_Mode => On, Inline, Pre => Pin <= 31;   --  pins 0..31
   function Hi_Bit (Pin : Pin_Id) return UInt22
   is (UInt22'(2)**(Natural (Pin) - 32))
   with SPARK_Mode => On, Inline, Pre => Pin > 31;    --  pins 32..48

   --------------------------------------------------------------------------
   --  Serialises the read-modify-write register ops (Configure, Toggle) so
   --  concurrent tasks can't lose an update.  Set/Clear/Write/Read stay
   --  lock-free (atomic banks / pure load).
   --------------------------------------------------------------------------
   protected Lock is
      procedure Configure
        (Pin   : Pin_Id;
         Mode  : Pin_Mode;
         Pull  : Pull_Mode;
         Drive : Drive_Strength);
      procedure Toggle (Pin : Pin_Id);
   end Lock;

   protected body Lock is

      procedure Configure
        (Pin   : Pin_Id;
         Mode  : Pin_Mode;
         Pull  : Pull_Mode;
         Drive : Drive_Strength)
      is
         Pad : Mux.GPIO_Register := Mux.IO_MUX_Periph.GPIO (Natural (Pin));
      begin
         --  IO_MUX pad config (read-modify-write the whole word).
         Pad.MCU_SEL :=
           1;                     --  route through the GPIO matrix
         Pad.FUN_DRV := Mux.GPIO_FUN_DRV_Field (Drive_Strength'Pos (Drive));
         Pad.FUN_IE := True;                  --  input buffer on (Read/Toggle)
         Pad.FUN_WPU := (Pull = Pull_Up);
         Pad.FUN_WPD := (Pull = Pull_Down);
         Mux.IO_MUX_Periph.GPIO (Natural (Pin)) := Pad;

         --  Route the matrix output as a plain GPIO (output index 256).
         declare
            Out_Cfg : Reg.FUNC_OUT_SEL_CFG_Register :=
              Reg.GPIO_Periph.FUNC_OUT_SEL_CFG (Natural (Pin));
         begin
            Out_Cfg.OUT_SEL := 256;            --  SIG_GPIO_OUT_IDX: plain GPIO
            Reg.GPIO_Periph.FUNC_OUT_SEL_CFG (Natural (Pin)) := Out_Cfg;
         end;

         --  Output driver enable / disable (atomic W1TS / W1TC).
         case Mode is
            when Output =>
               if Pin <= 31 then
                  Reg.GPIO_Periph.ENABLE_W1TS := Lo_Bit (Pin);
               else
                  Reg.GPIO_Periph.ENABLE1_W1TS.ENABLE1_W1TS := Hi_Bit (Pin);
               end if;

            when Input  =>
               if Pin <= 31 then
                  Reg.GPIO_Periph.ENABLE_W1TC := Lo_Bit (Pin);
               else
                  Reg.GPIO_Periph.ENABLE1_W1TC.ENABLE1_W1TC := Hi_Bit (Pin);
               end if;
         end case;
      end Configure;

      procedure Toggle (Pin : Pin_Id) is
         Currently_High : Boolean;
      begin
         --  Flip based on the OUTPUT LATCH (OUT_k / OUT1.DATA_ORIG), not the input
         --  pad level: Read samples IN_k, which on a loaded, slow-RC or contended
         --  output pin can differ from the last driven value, so a Read-based
         --  toggle could flip to the wrong state or fail to alternate.  (Serialised
         --  by this protected object.)
         if Pin <= 31 then
            Currently_High := (Reg.GPIO_Periph.OUT_k and Lo_Bit (Pin)) /= 0;
         else
            Currently_High :=
              (Reg.GPIO_Periph.OUT1.DATA_ORIG and Hi_Bit (Pin)) /= 0;
         end if;
         Write (Pin, not Currently_High);
      end Toggle;

   end Lock;

   --------------------------------------------------------------------------
   procedure Configure
     (Pin   : Pin_Id;
      Mode  : Pin_Mode;
      Pull  : Pull_Mode := Floating;
      Drive : Drive_Strength := Drive_Medium) is
   begin
      Lock.Configure (Pin, Mode, Pull, Drive);
   end Configure;

   --------------------------------------------------------------------------
   procedure Set (Pin : Pin_Id) with SPARK_Mode => On is
   begin
      if Pin <= 31 then
         Reg.GPIO_Periph.OUT_W1TS := Lo_Bit (Pin);
      else
         Reg.GPIO_Periph.OUT1_W1TS.OUT1_W1TS := Hi_Bit (Pin);
      end if;
   end Set;

   procedure Clear (Pin : Pin_Id) with SPARK_Mode => On is
   begin
      if Pin <= 31 then
         Reg.GPIO_Periph.OUT_W1TC := Lo_Bit (Pin);
      else
         Reg.GPIO_Periph.OUT1_W1TC.OUT1_W1TC := Hi_Bit (Pin);
      end if;
   end Clear;

   procedure Write (Pin : Pin_Id; On : Boolean) with SPARK_Mode => On is
   begin
      if On then
         Set (Pin);
      else
         Clear (Pin);
      end if;
   end Write;

   procedure Toggle (Pin : Pin_Id) is
   begin
      Lock.Toggle (Pin);
   end Toggle;

   --------------------------------------------------------------------------
   function Read (Pin : Pin_Id) return Boolean with SPARK_Mode => On is
   begin
      --  Each volatile read is taken into a local before it is masked.  SPARK
      --  RM 7.1.3(9) forbids one inside a larger expression, and the reason is
      --  real: the pad is driven from outside the program, so the sample must
      --  be fixed before anything else looks at it.
      if Pin <= 31 then
         declare
            Level : constant UInt32 := Reg.GPIO_Periph.IN_k;
         begin
            return (Level and Lo_Bit (Pin)) /= 0;
         end;
      else
         declare
            Level : constant UInt22 := Reg.GPIO_Periph.IN1.DATA_NEXT;
         begin
            return (Level and Hi_Bit (Pin)) /= 0;
         end;
      end if;
   end Read;

end ESP32S3.GPIO;
