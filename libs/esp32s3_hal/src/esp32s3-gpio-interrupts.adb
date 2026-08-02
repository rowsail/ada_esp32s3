with ESP32S3_Registers; use ESP32S3_Registers;
with ESP32S3_Registers.GPIO;
with ESP32S3_Registers.INTERRUPT_CORE0;

package body ESP32S3.GPIO.Interrupts is

   package Reg renames ESP32S3_Registers.GPIO;
   package IC renames ESP32S3_Registers.INTERRUPT_CORE0;

   --  CPU interrupt the GPIO source is routed to (= Device_L2_1).  The runtime's
   --  level-2 dispatch (Level2_Dispatch, via the native L2 vector) hands CPU_INT
   --  20 to the GNARL wrapper, which runs the handler attached below.  L2_1 and
   --  not an L3 slot because both L3 slots are spoken for on an RGB-LCD board:
   --  Device_L3_0 is the LCD engine's double-buffer relock and Device_L3_1 the
   --  GDMA EOF -- attaching GPIO there too would collide at elaboration.
   GPIO_CPU_Int : constant := 20;

   function Int_Type (T : Trigger) return Reg.PIN_INT_TYPE_Field
   is (case T is
         when Rising_Edge  => 1,
         when Falling_Edge => 2,
         when Any_Edge     => 3,
         when Low_Level    => 4,
         when High_Level   => 5);

   --  Indexed by the full Pad_Number range (a predicated subtype isn't used as
   --  an array index); only Pin_Id slots are ever populated, and the dispatch
   --  loop below iterates Pin_Id so reserved pads are skipped.
   type Callback_Map is array (Pad_Number) of Callback;

   --------------------------------------------------------------------------
   --  Owns the GPIO ISR (level-2 ceiling) plus the per-pin registration; the
   --  ceiling serialises config against the ISR.
   --------------------------------------------------------------------------
   protected Ctrl
     with Interrupt_Priority => Ada.Interrupts.Names.Device_L2_Priority
   is
      procedure Configure (Pin : Pin_Id; On : Trigger; Action : Callback);
      procedure Remove (Pin : Pin_Id);
   private
      procedure Handler
      with Attach_Handler => Ada.Interrupts.Names.Device_L2_1;
      Actions : Callback_Map := (others => null);
      Routed  : Boolean := False;
   end Ctrl;

   protected body Ctrl is

      procedure Configure (Pin : Pin_Id; On : Trigger; Action : Callback) is
         Pin_Reg : Reg.PIN_Register := Reg.GPIO_Periph.PIN (Natural (Pin));
      begin
         if not Routed then
            --  Route the GPIO source to CPU_INT 20 (Attach_Handler already
            --  enabled it; Level2_Dispatch handles the dispatch).
            IC.INTERRUPT_CORE0_Periph.GPIO_INTERRUPT_PRO_MAP.GPIO_INTERRUPT_PRO_MAP :=
              GPIO_CPU_Int;
            Routed := True;
         end if;
         Actions (Pin) := Action;
         Pin_Reg.INT_TYPE := Int_Type (On);
         Pin_Reg.INT_ENA := 1;           --  bit 0: deliver to PRO (core 0) CPU
         Reg.GPIO_Periph.PIN (Natural (Pin)) := Pin_Reg;
      end Configure;

      procedure Remove (Pin : Pin_Id) is
         Pin_Reg : Reg.PIN_Register := Reg.GPIO_Periph.PIN (Natural (Pin));
      begin
         Pin_Reg.INT_ENA := 0;
         Reg.GPIO_Periph.PIN (Natural (Pin)) := Pin_Reg;
         Actions (Pin) := null;
      end Remove;

      procedure Handler is
         Lo : constant UInt32 := Reg.GPIO_Periph.STATUS;                  --  0..31
         Hi : constant UInt32 := UInt32 (Reg.GPIO_Periph.STATUS1.INTERRUPT); -- 32..48
      begin
         --  Clear the latched status first so the level-2 source deasserts.
         Reg.GPIO_Periph.STATUS_W1TC := Lo;
         Reg.GPIO_Periph.STATUS1_W1TC :=
           (STATUS1_W1TC => Reg.STATUS1_W1TC_STATUS1_W1TC_Field (Hi), others => <>);
         --  Dispatch to each pin that fired.
         for Pin in Pin_Id loop
            declare
               Fired : constant Boolean :=
                 (if Pin <= 31
                  then (Lo and UInt32'(2)**Natural (Pin)) /= 0
                  else (Hi and UInt32'(2)**(Natural (Pin) - 32)) /= 0);
            begin
               if Fired and then Actions (Pin) /= null then
                  Actions (Pin).all;
               end if;
            end;
         end loop;
      end Handler;

   end Ctrl;

   ------------
   -- Enable --
   ------------

   procedure Enable (Pin : Pin_Id; On : Trigger; Action : Callback) is
   begin
      Ctrl.Configure (Pin, On, Action);
   end Enable;

   -------------
   -- Disable --
   -------------

   procedure Disable (Pin : Pin_Id) is
   begin
      Ctrl.Remove (Pin);
   end Disable;

end ESP32S3.GPIO.Interrupts;
