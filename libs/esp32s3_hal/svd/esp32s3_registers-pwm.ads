pragma Style_Checks (Off);

--  Copyright 2024 Espressif Systems (Shanghai) PTE LTD
--
--  Licensed under the Apache License, Version 2.0 (the "License");
--  you may not use this file except in compliance with the License.
--  You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
--  Unless required by applicable law or agreed to in writing, software
--  distributed under the License is distributed on an "AS IS" BASIS,
--  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--  See the License for the specific language governing permissions and
--  limitations under the License.

--  This spec has been automatically generated from esp32s3.svd

pragma Restrictions (No_Elaboration_Code);

with System;

package ESP32S3_Registers.PWM is
   pragma Preelaborate;

   ---------------
   -- Registers --
   ---------------

   subtype CLK_CFG_CLK_PRESCALE_Field is ESP32S3_Registers.Byte;

   --  PWM clock prescaler register.
   type CLK_CFG_Register is record
      --  Period of PWM_clk = 6.25ns * (PWM_CLK_PRESCALE + 1)
      CLK_PRESCALE  : CLK_CFG_CLK_PRESCALE_Field := 16#0#;
      --  unspecified
      Reserved_8_31 : ESP32S3_Registers.UInt24 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CLK_CFG_Register use record
      CLK_PRESCALE  at 0 range 0 .. 7;
      Reserved_8_31 at 0 range 8 .. 31;
   end record;

   subtype TIMER0_CFG0_TIMER0_PRESCALE_Field is ESP32S3_Registers.Byte;
   subtype TIMER0_CFG0_TIMER0_PERIOD_Field is ESP32S3_Registers.UInt16;
   subtype TIMER0_CFG0_TIMER0_PERIOD_UPMETHOD_Field is ESP32S3_Registers.UInt2;

   --  PWM timer0 period and update method configuration register.
   type TIMER0_CFG0_Register is record
      --  period of PT0_clk = Period of PWM_clk * (PWM_TIMER0_PRESCALE + 1)
      TIMER0_PRESCALE        : TIMER0_CFG0_TIMER0_PRESCALE_Field := 16#0#;
      --  period shadow register of PWM timer0
      TIMER0_PERIOD          : TIMER0_CFG0_TIMER0_PERIOD_Field := 16#FF#;
      --  Update method for active register of PWM timer0 period, 0: immediate,
      --  1: TEZ, 2: sync, 3: TEZ | sync. TEZ here and below means timer equal
      --  zero event
      TIMER0_PERIOD_UPMETHOD : TIMER0_CFG0_TIMER0_PERIOD_UPMETHOD_Field :=
                                16#0#;
      --  unspecified
      Reserved_26_31         : ESP32S3_Registers.UInt6 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for TIMER0_CFG0_Register use record
      TIMER0_PRESCALE        at 0 range 0 .. 7;
      TIMER0_PERIOD          at 0 range 8 .. 23;
      TIMER0_PERIOD_UPMETHOD at 0 range 24 .. 25;
      Reserved_26_31         at 0 range 26 .. 31;
   end record;

   subtype TIMER0_CFG1_TIMER0_START_Field is ESP32S3_Registers.UInt3;
   subtype TIMER0_CFG1_TIMER0_MOD_Field is ESP32S3_Registers.UInt2;

   --  PWM timer0 working mode and start/stop control configuration register.
   type TIMER0_CFG1_Register is record
      --  PWM timer0 start and stop control. 0: if PWM timer0 starts, then
      --  stops at TEZ, 1: if timer0 starts, then stops at TEP, 2: PWM timer0
      --  starts and runs on, 3: timer0 starts and stops at the next TEZ, 4:
      --  timer0 starts and stops at the next TEP. TEP here and below means the
      --  event that happens when the timer equals to period
      TIMER0_START  : TIMER0_CFG1_TIMER0_START_Field := 16#0#;
      --  PWM timer0 working mode, 0: freeze, 1: increase mode, 2: decrease
      --  mode, 3: up-down mode
      TIMER0_MOD    : TIMER0_CFG1_TIMER0_MOD_Field := 16#0#;
      --  unspecified
      Reserved_5_31 : ESP32S3_Registers.UInt27 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for TIMER0_CFG1_Register use record
      TIMER0_START  at 0 range 0 .. 2;
      TIMER0_MOD    at 0 range 3 .. 4;
      Reserved_5_31 at 0 range 5 .. 31;
   end record;

   subtype TIMER0_SYNC_TIMER0_SYNCO_SEL_Field is ESP32S3_Registers.UInt2;
   subtype TIMER0_SYNC_TIMER0_PHASE_Field is ESP32S3_Registers.UInt16;

   --  PWM timer0 sync function configuration register.
   type TIMER0_SYNC_Register is record
      --  When set, timer reloading with phase on sync input event is enabled.
      TIMER0_SYNCI_EN        : Boolean := False;
      --  Toggling this bit will trigger a software sync.
      SW                     : Boolean := False;
      --  PWM timer0 sync_out selection, 0: synci, 1: TEZ, 2: TEP,
      --  otherwise:sync out is software sync
      TIMER0_SYNCO_SEL       : TIMER0_SYNC_TIMER0_SYNCO_SEL_Field := 16#0#;
      --  phase for timer reload on sync event
      TIMER0_PHASE           : TIMER0_SYNC_TIMER0_PHASE_Field := 16#0#;
      --  Configure the PWM timer0's direction when timer0 mode is up-down
      --  mode. 0: increase; 1: decrease.
      TIMER0_PHASE_DIRECTION : Boolean := False;
      --  unspecified
      Reserved_21_31         : ESP32S3_Registers.UInt11 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for TIMER0_SYNC_Register use record
      TIMER0_SYNCI_EN        at 0 range 0 .. 0;
      SW                     at 0 range 1 .. 1;
      TIMER0_SYNCO_SEL       at 0 range 2 .. 3;
      TIMER0_PHASE           at 0 range 4 .. 19;
      TIMER0_PHASE_DIRECTION at 0 range 20 .. 20;
      Reserved_21_31         at 0 range 21 .. 31;
   end record;

   subtype TIMER0_STATUS_TIMER0_VALUE_Field is ESP32S3_Registers.UInt16;

   --  PWM timer0 status register.
   type TIMER0_STATUS_Register is record
      --  Read-only. current PWM timer0 counter value
      TIMER0_VALUE     : TIMER0_STATUS_TIMER0_VALUE_Field;
      --  Read-only. current PWM timer0 counter direction, 0: increment 1:
      --  decrement
      TIMER0_DIRECTION : Boolean;
      --  unspecified
      Reserved_17_31   : ESP32S3_Registers.UInt15;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for TIMER0_STATUS_Register use record
      TIMER0_VALUE     at 0 range 0 .. 15;
      TIMER0_DIRECTION at 0 range 16 .. 16;
      Reserved_17_31   at 0 range 17 .. 31;
   end record;

   subtype TIMER1_CFG0_TIMER1_PRESCALE_Field is ESP32S3_Registers.Byte;
   subtype TIMER1_CFG0_TIMER1_PERIOD_Field is ESP32S3_Registers.UInt16;
   subtype TIMER1_CFG0_TIMER1_PERIOD_UPMETHOD_Field is ESP32S3_Registers.UInt2;

   --  PWM timer1 period and update method configuration register.
   type TIMER1_CFG0_Register is record
      --  period of PT0_clk = Period of PWM_clk * (PWM_timer1_PRESCALE + 1)
      TIMER1_PRESCALE        : TIMER1_CFG0_TIMER1_PRESCALE_Field := 16#0#;
      --  period shadow register of PWM timer1
      TIMER1_PERIOD          : TIMER1_CFG0_TIMER1_PERIOD_Field := 16#FF#;
      --  Update method for active register of PWM timer1 period, 0: immediate,
      --  1: TEZ, 2: sync, 3: TEZ | sync. TEZ here and below means timer equal
      --  zero event
      TIMER1_PERIOD_UPMETHOD : TIMER1_CFG0_TIMER1_PERIOD_UPMETHOD_Field :=
                                16#0#;
      --  unspecified
      Reserved_26_31         : ESP32S3_Registers.UInt6 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for TIMER1_CFG0_Register use record
      TIMER1_PRESCALE        at 0 range 0 .. 7;
      TIMER1_PERIOD          at 0 range 8 .. 23;
      TIMER1_PERIOD_UPMETHOD at 0 range 24 .. 25;
      Reserved_26_31         at 0 range 26 .. 31;
   end record;

   subtype TIMER1_CFG1_TIMER1_START_Field is ESP32S3_Registers.UInt3;
   subtype TIMER1_CFG1_TIMER1_MOD_Field is ESP32S3_Registers.UInt2;

   --  PWM timer1 working mode and start/stop control configuration register.
   type TIMER1_CFG1_Register is record
      --  PWM timer1 start and stop control. 0: if PWM timer1 starts, then
      --  stops at TEZ, 1: if timer1 starts, then stops at TEP, 2: PWM timer1
      --  starts and runs on, 3: timer1 starts and stops at the next TEZ, 4:
      --  timer1 starts and stops at the next TEP. TEP here and below means the
      --  event that happens when the timer equals to period
      TIMER1_START  : TIMER1_CFG1_TIMER1_START_Field := 16#0#;
      --  PWM timer1 working mode, 0: freeze, 1: increase mode, 2: decrease
      --  mode, 3: up-down mode
      TIMER1_MOD    : TIMER1_CFG1_TIMER1_MOD_Field := 16#0#;
      --  unspecified
      Reserved_5_31 : ESP32S3_Registers.UInt27 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for TIMER1_CFG1_Register use record
      TIMER1_START  at 0 range 0 .. 2;
      TIMER1_MOD    at 0 range 3 .. 4;
      Reserved_5_31 at 0 range 5 .. 31;
   end record;

   subtype TIMER1_SYNC_TIMER1_SYNCO_SEL_Field is ESP32S3_Registers.UInt2;
   subtype TIMER1_SYNC_TIMER1_PHASE_Field is ESP32S3_Registers.UInt16;

   --  PWM timer1 sync function configuration register.
   type TIMER1_SYNC_Register is record
      --  When set, timer reloading with phase on sync input event is enabled.
      TIMER1_SYNCI_EN        : Boolean := False;
      --  Toggling this bit will trigger a software sync.
      SW                     : Boolean := False;
      --  PWM timer1 sync_out selection, 0: synci, 1: TEZ, 2: TEP,
      --  otherwise:sync out is software sync
      TIMER1_SYNCO_SEL       : TIMER1_SYNC_TIMER1_SYNCO_SEL_Field := 16#0#;
      --  phase for timer reload on sync event
      TIMER1_PHASE           : TIMER1_SYNC_TIMER1_PHASE_Field := 16#0#;
      --  Configure the PWM timer1's direction when timer1 mode is up-down
      --  mode. 0: increase; 1: decrease.
      TIMER1_PHASE_DIRECTION : Boolean := False;
      --  unspecified
      Reserved_21_31         : ESP32S3_Registers.UInt11 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for TIMER1_SYNC_Register use record
      TIMER1_SYNCI_EN        at 0 range 0 .. 0;
      SW                     at 0 range 1 .. 1;
      TIMER1_SYNCO_SEL       at 0 range 2 .. 3;
      TIMER1_PHASE           at 0 range 4 .. 19;
      TIMER1_PHASE_DIRECTION at 0 range 20 .. 20;
      Reserved_21_31         at 0 range 21 .. 31;
   end record;

   subtype TIMER1_STATUS_TIMER1_VALUE_Field is ESP32S3_Registers.UInt16;

   --  PWM timer1 status register.
   type TIMER1_STATUS_Register is record
      --  Read-only. current PWM timer1 counter value
      TIMER1_VALUE     : TIMER1_STATUS_TIMER1_VALUE_Field;
      --  Read-only. current PWM timer1 counter direction, 0: increment 1:
      --  decrement
      TIMER1_DIRECTION : Boolean;
      --  unspecified
      Reserved_17_31   : ESP32S3_Registers.UInt15;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for TIMER1_STATUS_Register use record
      TIMER1_VALUE     at 0 range 0 .. 15;
      TIMER1_DIRECTION at 0 range 16 .. 16;
      Reserved_17_31   at 0 range 17 .. 31;
   end record;

   subtype TIMER2_CFG0_TIMER2_PRESCALE_Field is ESP32S3_Registers.Byte;
   subtype TIMER2_CFG0_TIMER2_PERIOD_Field is ESP32S3_Registers.UInt16;
   subtype TIMER2_CFG0_TIMER2_PERIOD_UPMETHOD_Field is ESP32S3_Registers.UInt2;

   --  PWM timer2 period and update method configuration register.
   type TIMER2_CFG0_Register is record
      --  period of PT0_clk = Period of PWM_clk * (PWM_timer2_PRESCALE + 1)
      TIMER2_PRESCALE        : TIMER2_CFG0_TIMER2_PRESCALE_Field := 16#0#;
      --  period shadow register of PWM timer2
      TIMER2_PERIOD          : TIMER2_CFG0_TIMER2_PERIOD_Field := 16#FF#;
      --  Update method for active register of PWM timer2 period, 0: immediate,
      --  1: TEZ, 2: sync, 3: TEZ | sync. TEZ here and below means timer equal
      --  zero event
      TIMER2_PERIOD_UPMETHOD : TIMER2_CFG0_TIMER2_PERIOD_UPMETHOD_Field :=
                                16#0#;
      --  unspecified
      Reserved_26_31         : ESP32S3_Registers.UInt6 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for TIMER2_CFG0_Register use record
      TIMER2_PRESCALE        at 0 range 0 .. 7;
      TIMER2_PERIOD          at 0 range 8 .. 23;
      TIMER2_PERIOD_UPMETHOD at 0 range 24 .. 25;
      Reserved_26_31         at 0 range 26 .. 31;
   end record;

   subtype TIMER2_CFG1_TIMER2_START_Field is ESP32S3_Registers.UInt3;
   subtype TIMER2_CFG1_TIMER2_MOD_Field is ESP32S3_Registers.UInt2;

   --  PWM timer2 working mode and start/stop control configuration register.
   type TIMER2_CFG1_Register is record
      --  PWM timer2 start and stop control. 0: if PWM timer2 starts, then
      --  stops at TEZ, 1: if timer2 starts, then stops at TEP, 2: PWM timer2
      --  starts and runs on, 3: timer2 starts and stops at the next TEZ, 4:
      --  timer2 starts and stops at the next TEP. TEP here and below means the
      --  event that happens when the timer equals to period
      TIMER2_START  : TIMER2_CFG1_TIMER2_START_Field := 16#0#;
      --  PWM timer2 working mode, 0: freeze, 1: increase mode, 2: decrease
      --  mode, 3: up-down mode
      TIMER2_MOD    : TIMER2_CFG1_TIMER2_MOD_Field := 16#0#;
      --  unspecified
      Reserved_5_31 : ESP32S3_Registers.UInt27 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for TIMER2_CFG1_Register use record
      TIMER2_START  at 0 range 0 .. 2;
      TIMER2_MOD    at 0 range 3 .. 4;
      Reserved_5_31 at 0 range 5 .. 31;
   end record;

   subtype TIMER2_SYNC_TIMER2_SYNCO_SEL_Field is ESP32S3_Registers.UInt2;
   subtype TIMER2_SYNC_TIMER2_PHASE_Field is ESP32S3_Registers.UInt16;

   --  PWM timer2 sync function configuration register.
   type TIMER2_SYNC_Register is record
      --  When set, timer reloading with phase on sync input event is enabled.
      TIMER2_SYNCI_EN        : Boolean := False;
      --  Toggling this bit will trigger a software sync.
      SW                     : Boolean := False;
      --  PWM timer2 sync_out selection, 0: synci, 1: TEZ, 2: TEP,
      --  otherwise:sync out is software sync
      TIMER2_SYNCO_SEL       : TIMER2_SYNC_TIMER2_SYNCO_SEL_Field := 16#0#;
      --  phase for timer reload on sync event
      TIMER2_PHASE           : TIMER2_SYNC_TIMER2_PHASE_Field := 16#0#;
      --  Configure the PWM timer2's direction when timer2 mode is up-down
      --  mode. 0: increase; 1: decrease.
      TIMER2_PHASE_DIRECTION : Boolean := False;
      --  unspecified
      Reserved_21_31         : ESP32S3_Registers.UInt11 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for TIMER2_SYNC_Register use record
      TIMER2_SYNCI_EN        at 0 range 0 .. 0;
      SW                     at 0 range 1 .. 1;
      TIMER2_SYNCO_SEL       at 0 range 2 .. 3;
      TIMER2_PHASE           at 0 range 4 .. 19;
      TIMER2_PHASE_DIRECTION at 0 range 20 .. 20;
      Reserved_21_31         at 0 range 21 .. 31;
   end record;

   subtype TIMER2_STATUS_TIMER2_VALUE_Field is ESP32S3_Registers.UInt16;

   --  PWM timer2 status register.
   type TIMER2_STATUS_Register is record
      --  Read-only. current PWM timer2 counter value
      TIMER2_VALUE     : TIMER2_STATUS_TIMER2_VALUE_Field;
      --  Read-only. current PWM timer2 counter direction, 0: increment 1:
      --  decrement
      TIMER2_DIRECTION : Boolean;
      --  unspecified
      Reserved_17_31   : ESP32S3_Registers.UInt15;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for TIMER2_STATUS_Register use record
      TIMER2_VALUE     at 0 range 0 .. 15;
      TIMER2_DIRECTION at 0 range 16 .. 16;
      Reserved_17_31   at 0 range 17 .. 31;
   end record;

   subtype TIMER_SYNCI_CFG_TIMER0_SYNCISEL_Field is ESP32S3_Registers.UInt3;
   subtype TIMER_SYNCI_CFG_TIMER1_SYNCISEL_Field is ESP32S3_Registers.UInt3;
   subtype TIMER_SYNCI_CFG_TIMER2_SYNCISEL_Field is ESP32S3_Registers.UInt3;

   --  Synchronization input selection for three PWM timers.
   type TIMER_SYNCI_CFG_Register is record
      --  select sync input for PWM timer0, 1: PWM timer0 sync_out, 2: PWM
      --  timer1 sync_out, 3: PWM timer2 sync_out, 4: SYNC0 from GPIO matrix,
      --  5: SYNC1 from GPIO matrix, 6: SYNC2 from GPIO matrix, other values:
      --  no sync input selected
      TIMER0_SYNCISEL        : TIMER_SYNCI_CFG_TIMER0_SYNCISEL_Field := 16#0#;
      --  select sync input for PWM timer1, 1: PWM timer0 sync_out, 2: PWM
      --  timer1 sync_out, 3: PWM timer2 sync_out, 4: SYNC0 from GPIO matrix,
      --  5: SYNC1 from GPIO matrix, 6: SYNC2 from GPIO matrix, other values:
      --  no sync input selected
      TIMER1_SYNCISEL        : TIMER_SYNCI_CFG_TIMER1_SYNCISEL_Field := 16#0#;
      --  select sync input for PWM timer2, 1: PWM timer0 sync_out, 2: PWM
      --  timer1 sync_out, 3: PWM timer2 sync_out, 4: SYNC0 from GPIO matrix,
      --  5: SYNC1 from GPIO matrix, 6: SYNC2 from GPIO matrix, other values:
      --  no sync input selected
      TIMER2_SYNCISEL        : TIMER_SYNCI_CFG_TIMER2_SYNCISEL_Field := 16#0#;
      --  invert SYNC0 from GPIO matrix
      EXTERNAL_SYNCI0_INVERT : Boolean := False;
      --  invert SYNC1 from GPIO matrix
      EXTERNAL_SYNCI1_INVERT : Boolean := False;
      --  invert SYNC2 from GPIO matrix
      EXTERNAL_SYNCI2_INVERT : Boolean := False;
      --  unspecified
      Reserved_12_31         : ESP32S3_Registers.UInt20 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for TIMER_SYNCI_CFG_Register use record
      TIMER0_SYNCISEL        at 0 range 0 .. 2;
      TIMER1_SYNCISEL        at 0 range 3 .. 5;
      TIMER2_SYNCISEL        at 0 range 6 .. 8;
      EXTERNAL_SYNCI0_INVERT at 0 range 9 .. 9;
      EXTERNAL_SYNCI1_INVERT at 0 range 10 .. 10;
      EXTERNAL_SYNCI2_INVERT at 0 range 11 .. 11;
      Reserved_12_31         at 0 range 12 .. 31;
   end record;

   subtype OPERATOR_TIMERSEL_OPERATOR0_TIMERSEL_Field is
     ESP32S3_Registers.UInt2;
   subtype OPERATOR_TIMERSEL_OPERATOR1_TIMERSEL_Field is
     ESP32S3_Registers.UInt2;
   subtype OPERATOR_TIMERSEL_OPERATOR2_TIMERSEL_Field is
     ESP32S3_Registers.UInt2;

   --  Select specific timer for PWM operators.
   type OPERATOR_TIMERSEL_Register is record
      --  Select which PWM timer's is the timing reference for PWM operator0,
      --  0: timer0, 1: timer1, 2: timer2
      OPERATOR0_TIMERSEL : OPERATOR_TIMERSEL_OPERATOR0_TIMERSEL_Field :=
                            16#0#;
      --  Select which PWM timer's is the timing reference for PWM operator1,
      --  0: timer0, 1: timer1, 2: timer2
      OPERATOR1_TIMERSEL : OPERATOR_TIMERSEL_OPERATOR1_TIMERSEL_Field :=
                            16#0#;
      --  Select which PWM timer's is the timing reference for PWM operator2,
      --  0: timer0, 1: timer1, 2: timer2
      OPERATOR2_TIMERSEL : OPERATOR_TIMERSEL_OPERATOR2_TIMERSEL_Field :=
                            16#0#;
      --  unspecified
      Reserved_6_31      : ESP32S3_Registers.UInt26 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for OPERATOR_TIMERSEL_Register use record
      OPERATOR0_TIMERSEL at 0 range 0 .. 1;
      OPERATOR1_TIMERSEL at 0 range 2 .. 3;
      OPERATOR2_TIMERSEL at 0 range 4 .. 5;
      Reserved_6_31      at 0 range 6 .. 31;
   end record;

   subtype CMPR0_CFG_CMPR0_A_UPMETHOD_Field is ESP32S3_Registers.UInt4;
   subtype CMPR0_CFG_CMPR0_B_UPMETHOD_Field is ESP32S3_Registers.UInt4;

   --  Transfer status and update method for time stamp registers A and B
   type CMPR0_CFG_Register is record
      --  Update method for PWM generator 0 time stamp A's active register.
      --  When all bits are set to 0: immediately, when bit0 is set to 1: TEZ,
      --  when bit1 is set to 1: TEP,when bit2 is set to 1: sync, when bit3 is
      --  set to 1: disable the update.
      CMPR0_A_UPMETHOD  : CMPR0_CFG_CMPR0_A_UPMETHOD_Field := 16#0#;
      --  Update method for PWM generator 0 time stamp B's active register.
      --  When all bits are set to 0: immediately, when bit0 is set to 1: TEZ,
      --  when bit1 is set to 1: TEP,when bit2 is set to 1: sync, when bit3 is
      --  set to 1: disable the update.
      CMPR0_B_UPMETHOD  : CMPR0_CFG_CMPR0_B_UPMETHOD_Field := 16#0#;
      --  Set and reset by hardware. If set, PWM generator 0 time stamp A's
      --  shadow reg is filled and waiting to be transferred to A's active reg.
      --  If cleared, A's active reg has been updated with shadow register
      --  latest value
      CMPR0_A_SHDW_FULL : Boolean := False;
      --  Set and reset by hardware. If set, PWM generator 0 time stamp B's
      --  shadow reg is filled and waiting to be transferred to B's active reg.
      --  If cleared, B's active reg has been updated with shadow register
      --  latest value
      CMPR0_B_SHDW_FULL : Boolean := False;
      --  unspecified
      Reserved_10_31    : ESP32S3_Registers.UInt22 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CMPR0_CFG_Register use record
      CMPR0_A_UPMETHOD  at 0 range 0 .. 3;
      CMPR0_B_UPMETHOD  at 0 range 4 .. 7;
      CMPR0_A_SHDW_FULL at 0 range 8 .. 8;
      CMPR0_B_SHDW_FULL at 0 range 9 .. 9;
      Reserved_10_31    at 0 range 10 .. 31;
   end record;

   subtype CMPR0_VALUE0_CMPR0_A_Field is ESP32S3_Registers.UInt16;

   --  Shadow register for register A.
   type CMPR0_VALUE0_Register is record
      --  PWM generator 0 time stamp A's shadow register
      CMPR0_A        : CMPR0_VALUE0_CMPR0_A_Field := 16#0#;
      --  unspecified
      Reserved_16_31 : ESP32S3_Registers.UInt16 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CMPR0_VALUE0_Register use record
      CMPR0_A        at 0 range 0 .. 15;
      Reserved_16_31 at 0 range 16 .. 31;
   end record;

   subtype CMPR0_VALUE1_CMPR0_B_Field is ESP32S3_Registers.UInt16;

   --  Shadow register for register B.
   type CMPR0_VALUE1_Register is record
      --  PWM generator 0 time stamp B's shadow register
      CMPR0_B        : CMPR0_VALUE1_CMPR0_B_Field := 16#0#;
      --  unspecified
      Reserved_16_31 : ESP32S3_Registers.UInt16 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CMPR0_VALUE1_Register use record
      CMPR0_B        at 0 range 0 .. 15;
      Reserved_16_31 at 0 range 16 .. 31;
   end record;

   subtype GEN0_CFG0_GEN0_CFG_UPMETHOD_Field is ESP32S3_Registers.UInt4;
   subtype GEN0_CFG0_GEN0_T0_SEL_Field is ESP32S3_Registers.UInt3;
   subtype GEN0_CFG0_GEN0_T1_SEL_Field is ESP32S3_Registers.UInt3;

   --  Fault event T0 and T1 handling
   type GEN0_CFG0_Register is record
      --  Update method for PWM generator 0's active register of configuration.
      --  When all bits are set to 0: immediately, when bit0 is set to 1: TEZ,
      --  when bit1 is set to 1:
      GEN0_CFG_UPMETHOD : GEN0_CFG0_GEN0_CFG_UPMETHOD_Field := 16#0#;
      --  Source selection for PWM generator 0 event_t0, take effect
      --  immediately, 0: fault_event0, 1: fault_event1, 2: fault_event2, 3:
      --  sync_taken, 4: none
      GEN0_T0_SEL       : GEN0_CFG0_GEN0_T0_SEL_Field := 16#0#;
      --  Source selection for PWM generator 0 event_t1, take effect
      --  immediately, 0: fault_event0, 1: fault_event1, 2: fault_event2, 3:
      --  sync_taken, 4: none
      GEN0_T1_SEL       : GEN0_CFG0_GEN0_T1_SEL_Field := 16#0#;
      --  unspecified
      Reserved_10_31    : ESP32S3_Registers.UInt22 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for GEN0_CFG0_Register use record
      GEN0_CFG_UPMETHOD at 0 range 0 .. 3;
      GEN0_T0_SEL       at 0 range 4 .. 6;
      GEN0_T1_SEL       at 0 range 7 .. 9;
      Reserved_10_31    at 0 range 10 .. 31;
   end record;

   subtype GEN0_FORCE_GEN0_CNTUFORCE_UPMETHOD_Field is ESP32S3_Registers.UInt6;
   subtype GEN0_FORCE_GEN0_A_CNTUFORCE_MODE_Field is ESP32S3_Registers.UInt2;
   subtype GEN0_FORCE_GEN0_B_CNTUFORCE_MODE_Field is ESP32S3_Registers.UInt2;
   subtype GEN0_FORCE_GEN0_A_NCIFORCE_MODE_Field is ESP32S3_Registers.UInt2;
   subtype GEN0_FORCE_GEN0_B_NCIFORCE_MODE_Field is ESP32S3_Registers.UInt2;

   --  Permissives to force PWM0A and PWM0B outputs by software
   type GEN0_FORCE_Register is record
      --  Updating method for continuous software force of PWM generator0. When
      --  all bits are set to 0: immediately, when bit0 is set to 1: TEZ,,when
      --  bit1 is set to 1: TEP, when bit2 is set to 1: TEA, when bit3 is set
      --  to 1: TEB, when bit4 is set to 1: sync, when bit5 is set to 1:
      --  disable update. (TEA/B here and below means an event generated when
      --  the timer's value equals to that of register A/B.)
      GEN0_CNTUFORCE_UPMETHOD : GEN0_FORCE_GEN0_CNTUFORCE_UPMETHOD_Field :=
                                 16#20#;
      --  Continuous software force mode for PWM0A. 0: disabled, 1: low, 2:
      --  high, 3: disabled
      GEN0_A_CNTUFORCE_MODE   : GEN0_FORCE_GEN0_A_CNTUFORCE_MODE_Field :=
                                 16#0#;
      --  Continuous software force mode for PWM0B. 0: disabled, 1: low, 2:
      --  high, 3: disabled
      GEN0_B_CNTUFORCE_MODE   : GEN0_FORCE_GEN0_B_CNTUFORCE_MODE_Field :=
                                 16#0#;
      --  Trigger of non-continuous immediate software-force event for PWM0A, a
      --  toggle will trigger a force event.
      GEN0_A_NCIFORCE         : Boolean := False;
      --  non-continuous immediate software force mode for PWM0A, 0: disabled,
      --  1: low, 2: high, 3: disabled
      GEN0_A_NCIFORCE_MODE    : GEN0_FORCE_GEN0_A_NCIFORCE_MODE_Field :=
                                 16#0#;
      --  Trigger of non-continuous immediate software-force event for PWM0B, a
      --  toggle will trigger a force event.
      GEN0_B_NCIFORCE         : Boolean := False;
      --  non-continuous immediate software force mode for PWM0B, 0: disabled,
      --  1: low, 2: high, 3: disabled
      GEN0_B_NCIFORCE_MODE    : GEN0_FORCE_GEN0_B_NCIFORCE_MODE_Field :=
                                 16#0#;
      --  unspecified
      Reserved_16_31          : ESP32S3_Registers.UInt16 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for GEN0_FORCE_Register use record
      GEN0_CNTUFORCE_UPMETHOD at 0 range 0 .. 5;
      GEN0_A_CNTUFORCE_MODE   at 0 range 6 .. 7;
      GEN0_B_CNTUFORCE_MODE   at 0 range 8 .. 9;
      GEN0_A_NCIFORCE         at 0 range 10 .. 10;
      GEN0_A_NCIFORCE_MODE    at 0 range 11 .. 12;
      GEN0_B_NCIFORCE         at 0 range 13 .. 13;
      GEN0_B_NCIFORCE_MODE    at 0 range 14 .. 15;
      Reserved_16_31          at 0 range 16 .. 31;
   end record;

   subtype GEN0_A_UTEZ_Field is ESP32S3_Registers.UInt2;
   subtype GEN0_A_UTEP_Field is ESP32S3_Registers.UInt2;
   subtype GEN0_A_UTEA_Field is ESP32S3_Registers.UInt2;
   subtype GEN0_A_UTEB_Field is ESP32S3_Registers.UInt2;
   --  GEN0_A_UT array element
   subtype GEN0_A_UT_Element is ESP32S3_Registers.UInt2;

   --  GEN0_A_UT array
   type GEN0_A_UT_Field_Array is array (0 .. 1) of GEN0_A_UT_Element
     with Component_Size => 2, Size => 4;

   --  Type definition for GEN0_A_UT
   type GEN0_A_UT_Field
     (As_Array : Boolean := False)
   is record
      case As_Array is
         when False =>
            --  UT as a value
            Val : ESP32S3_Registers.UInt4;
         when True =>
            --  UT as an array
            Arr : GEN0_A_UT_Field_Array;
      end case;
   end record
     with Unchecked_Union, Size => 4;

   for GEN0_A_UT_Field use record
      Val at 0 range 0 .. 3;
      Arr at 0 range 0 .. 3;
   end record;

   subtype GEN0_A_DTEZ_Field is ESP32S3_Registers.UInt2;
   subtype GEN0_A_DTEP_Field is ESP32S3_Registers.UInt2;
   subtype GEN0_A_DTEA_Field is ESP32S3_Registers.UInt2;
   subtype GEN0_A_DTEB_Field is ESP32S3_Registers.UInt2;
   --  GEN0_A_DT array element
   subtype GEN0_A_DT_Element is ESP32S3_Registers.UInt2;

   --  GEN0_A_DT array
   type GEN0_A_DT_Field_Array is array (0 .. 1) of GEN0_A_DT_Element
     with Component_Size => 2, Size => 4;

   --  Type definition for GEN0_A_DT
   type GEN0_A_DT_Field
     (As_Array : Boolean := False)
   is record
      case As_Array is
         when False =>
            --  DT as a value
            Val : ESP32S3_Registers.UInt4;
         when True =>
            --  DT as an array
            Arr : GEN0_A_DT_Field_Array;
      end case;
   end record
     with Unchecked_Union, Size => 4;

   for GEN0_A_DT_Field use record
      Val at 0 range 0 .. 3;
      Arr at 0 range 0 .. 3;
   end record;

   --  Actions triggered by events on PWM0A
   type GEN0_A_Register is record
      --  Action on PWM0A triggered by event TEZ when timer increasing
      UTEZ           : GEN0_A_UTEZ_Field := 16#0#;
      --  Action on PWM0A triggered by event TEP when timer increasing
      UTEP           : GEN0_A_UTEP_Field := 16#0#;
      --  Action on PWM0A triggered by event TEA when timer increasing
      UTEA           : GEN0_A_UTEA_Field := 16#0#;
      --  Action on PWM0A triggered by event TEB when timer increasing
      UTEB           : GEN0_A_UTEB_Field := 16#0#;
      --  Action on PWM0A triggered by event_t0 when timer increasing
      UT             : GEN0_A_UT_Field := (As_Array => False, Val => 16#0#);
      --  Action on PWM0A triggered by event TEZ when timer decreasing
      DTEZ           : GEN0_A_DTEZ_Field := 16#0#;
      --  Action on PWM0A triggered by event TEP when timer decreasing
      DTEP           : GEN0_A_DTEP_Field := 16#0#;
      --  Action on PWM0A triggered by event TEA when timer decreasing
      DTEA           : GEN0_A_DTEA_Field := 16#0#;
      --  Action on PWM0A triggered by event TEB when timer decreasing
      DTEB           : GEN0_A_DTEB_Field := 16#0#;
      --  Action on PWM0A triggered by event_t0 when timer decreasing
      DT             : GEN0_A_DT_Field := (As_Array => False, Val => 16#0#);
      --  unspecified
      Reserved_24_31 : ESP32S3_Registers.Byte := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for GEN0_A_Register use record
      UTEZ           at 0 range 0 .. 1;
      UTEP           at 0 range 2 .. 3;
      UTEA           at 0 range 4 .. 5;
      UTEB           at 0 range 6 .. 7;
      UT             at 0 range 8 .. 11;
      DTEZ           at 0 range 12 .. 13;
      DTEP           at 0 range 14 .. 15;
      DTEA           at 0 range 16 .. 17;
      DTEB           at 0 range 18 .. 19;
      DT             at 0 range 20 .. 23;
      Reserved_24_31 at 0 range 24 .. 31;
   end record;

   subtype GEN0_B_UTEZ_Field is ESP32S3_Registers.UInt2;
   subtype GEN0_B_UTEP_Field is ESP32S3_Registers.UInt2;
   subtype GEN0_B_UTEA_Field is ESP32S3_Registers.UInt2;
   subtype GEN0_B_UTEB_Field is ESP32S3_Registers.UInt2;
   --  GEN0_B_UT array element
   subtype GEN0_B_UT_Element is ESP32S3_Registers.UInt2;

   --  GEN0_B_UT array
   type GEN0_B_UT_Field_Array is array (0 .. 1) of GEN0_B_UT_Element
     with Component_Size => 2, Size => 4;

   --  Type definition for GEN0_B_UT
   type GEN0_B_UT_Field
     (As_Array : Boolean := False)
   is record
      case As_Array is
         when False =>
            --  UT as a value
            Val : ESP32S3_Registers.UInt4;
         when True =>
            --  UT as an array
            Arr : GEN0_B_UT_Field_Array;
      end case;
   end record
     with Unchecked_Union, Size => 4;

   for GEN0_B_UT_Field use record
      Val at 0 range 0 .. 3;
      Arr at 0 range 0 .. 3;
   end record;

   subtype GEN0_B_DTEZ_Field is ESP32S3_Registers.UInt2;
   subtype GEN0_B_DTEP_Field is ESP32S3_Registers.UInt2;
   subtype GEN0_B_DTEA_Field is ESP32S3_Registers.UInt2;
   subtype GEN0_B_DTEB_Field is ESP32S3_Registers.UInt2;
   --  GEN0_B_DT array element
   subtype GEN0_B_DT_Element is ESP32S3_Registers.UInt2;

   --  GEN0_B_DT array
   type GEN0_B_DT_Field_Array is array (0 .. 1) of GEN0_B_DT_Element
     with Component_Size => 2, Size => 4;

   --  Type definition for GEN0_B_DT
   type GEN0_B_DT_Field
     (As_Array : Boolean := False)
   is record
      case As_Array is
         when False =>
            --  DT as a value
            Val : ESP32S3_Registers.UInt4;
         when True =>
            --  DT as an array
            Arr : GEN0_B_DT_Field_Array;
      end case;
   end record
     with Unchecked_Union, Size => 4;

   for GEN0_B_DT_Field use record
      Val at 0 range 0 .. 3;
      Arr at 0 range 0 .. 3;
   end record;

   --  Actions triggered by events on PWM0B
   type GEN0_B_Register is record
      --  Action on PWM0B triggered by event TEZ when timer increasing
      UTEZ           : GEN0_B_UTEZ_Field := 16#0#;
      --  Action on PWM0B triggered by event TEP when timer increasing
      UTEP           : GEN0_B_UTEP_Field := 16#0#;
      --  Action on PWM0B triggered by event TEA when timer increasing
      UTEA           : GEN0_B_UTEA_Field := 16#0#;
      --  Action on PWM0B triggered by event TEB when timer increasing
      UTEB           : GEN0_B_UTEB_Field := 16#0#;
      --  Action on PWM0B triggered by event_t0 when timer increasing
      UT             : GEN0_B_UT_Field := (As_Array => False, Val => 16#0#);
      --  Action on PWM0B triggered by event TEZ when timer decreasing
      DTEZ           : GEN0_B_DTEZ_Field := 16#0#;
      --  Action on PWM0B triggered by event TEP when timer decreasing
      DTEP           : GEN0_B_DTEP_Field := 16#0#;
      --  Action on PWM0B triggered by event TEA when timer decreasing
      DTEA           : GEN0_B_DTEA_Field := 16#0#;
      --  Action on PWM0B triggered by event TEB when timer decreasing
      DTEB           : GEN0_B_DTEB_Field := 16#0#;
      --  Action on PWM0B triggered by event_t0 when timer decreasing
      DT             : GEN0_B_DT_Field := (As_Array => False, Val => 16#0#);
      --  unspecified
      Reserved_24_31 : ESP32S3_Registers.Byte := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for GEN0_B_Register use record
      UTEZ           at 0 range 0 .. 1;
      UTEP           at 0 range 2 .. 3;
      UTEA           at 0 range 4 .. 5;
      UTEB           at 0 range 6 .. 7;
      UT             at 0 range 8 .. 11;
      DTEZ           at 0 range 12 .. 13;
      DTEP           at 0 range 14 .. 15;
      DTEA           at 0 range 16 .. 17;
      DTEB           at 0 range 18 .. 19;
      DT             at 0 range 20 .. 23;
      Reserved_24_31 at 0 range 24 .. 31;
   end record;

   subtype DB0_CFG_DB0_FED_UPMETHOD_Field is ESP32S3_Registers.UInt4;
   subtype DB0_CFG_DB0_RED_UPMETHOD_Field is ESP32S3_Registers.UInt4;

   --  dead time type selection and configuration
   type DB0_CFG_Register is record
      --  Update method for FED (falling edge delay) active register. 0:
      --  immediate, bit0: tez, bit1: tep, bit2: sync, bit3: freeze
      DB0_FED_UPMETHOD  : DB0_CFG_DB0_FED_UPMETHOD_Field := 16#0#;
      --  Update method for RED (rising edge delay) active register. 0:
      --  immediate, bit0: tez, bit1: tep, bit2: sync, bit3: freeze
      DB0_RED_UPMETHOD  : DB0_CFG_DB0_RED_UPMETHOD_Field := 16#0#;
      --  S8 in documentation, dual-edge B mode, 0: fed/red take effect on
      --  different path separately, 1: fed/red take effect on B path, A out is
      --  in bypass or dulpB mode
      DB0_DEB_MODE      : Boolean := False;
      --  S6 in documentation
      DB0_A_OUTSWAP     : Boolean := False;
      --  S7 in documentation
      DB0_B_OUTSWAP     : Boolean := False;
      --  S4 in documentation
      DB0_RED_INSEL     : Boolean := False;
      --  S5 in documentation
      DB0_FED_INSEL     : Boolean := False;
      --  S2 in documentation
      DB0_RED_OUTINVERT : Boolean := False;
      --  S3 in documentation
      DB0_FED_OUTINVERT : Boolean := False;
      --  S1 in documentation
      DB0_A_OUTBYPASS   : Boolean := True;
      --  S0 in documentation
      DB0_B_OUTBYPASS   : Boolean := True;
      --  Dead time generator 0 clock selection. 0: PWM_clk, 1: PT_clk
      DB0_CLK_SEL       : Boolean := False;
      --  unspecified
      Reserved_18_31    : ESP32S3_Registers.UInt14 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DB0_CFG_Register use record
      DB0_FED_UPMETHOD  at 0 range 0 .. 3;
      DB0_RED_UPMETHOD  at 0 range 4 .. 7;
      DB0_DEB_MODE      at 0 range 8 .. 8;
      DB0_A_OUTSWAP     at 0 range 9 .. 9;
      DB0_B_OUTSWAP     at 0 range 10 .. 10;
      DB0_RED_INSEL     at 0 range 11 .. 11;
      DB0_FED_INSEL     at 0 range 12 .. 12;
      DB0_RED_OUTINVERT at 0 range 13 .. 13;
      DB0_FED_OUTINVERT at 0 range 14 .. 14;
      DB0_A_OUTBYPASS   at 0 range 15 .. 15;
      DB0_B_OUTBYPASS   at 0 range 16 .. 16;
      DB0_CLK_SEL       at 0 range 17 .. 17;
      Reserved_18_31    at 0 range 18 .. 31;
   end record;

   subtype DB0_FED_CFG_DB0_FED_Field is ESP32S3_Registers.UInt16;

   --  Shadow register for falling edge delay (FED).
   type DB0_FED_CFG_Register is record
      --  Shadow register for FED
      DB0_FED        : DB0_FED_CFG_DB0_FED_Field := 16#0#;
      --  unspecified
      Reserved_16_31 : ESP32S3_Registers.UInt16 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DB0_FED_CFG_Register use record
      DB0_FED        at 0 range 0 .. 15;
      Reserved_16_31 at 0 range 16 .. 31;
   end record;

   subtype DB0_RED_CFG_DB0_RED_Field is ESP32S3_Registers.UInt16;

   --  Shadow register for rising edge delay (RED).
   type DB0_RED_CFG_Register is record
      --  Shadow register for RED
      DB0_RED        : DB0_RED_CFG_DB0_RED_Field := 16#0#;
      --  unspecified
      Reserved_16_31 : ESP32S3_Registers.UInt16 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DB0_RED_CFG_Register use record
      DB0_RED        at 0 range 0 .. 15;
      Reserved_16_31 at 0 range 16 .. 31;
   end record;

   subtype CHOPPER0_CFG_CHOPPER0_PRESCALE_Field is ESP32S3_Registers.UInt4;
   subtype CHOPPER0_CFG_CHOPPER0_DUTY_Field is ESP32S3_Registers.UInt3;
   subtype CHOPPER0_CFG_CHOPPER0_OSHTWTH_Field is ESP32S3_Registers.UInt4;

   --  Carrier enable and configuratoin
   type CHOPPER0_CFG_Register is record
      --  When set, carrier0 function is enabled. When cleared, carrier0 is
      --  bypassed
      CHOPPER0_EN         : Boolean := False;
      --  PWM carrier0 clock (PC_clk) prescale value. Period of PC_clk = period
      --  of PWM_clk * (PWM_CARRIER0_PRESCALE + 1)
      CHOPPER0_PRESCALE   : CHOPPER0_CFG_CHOPPER0_PRESCALE_Field := 16#0#;
      --  carrier duty selection. Duty = PWM_CARRIER0_DUTY / 8
      CHOPPER0_DUTY       : CHOPPER0_CFG_CHOPPER0_DUTY_Field := 16#0#;
      --  width of the fist pulse in number of periods of the carrier
      CHOPPER0_OSHTWTH    : CHOPPER0_CFG_CHOPPER0_OSHTWTH_Field := 16#0#;
      --  when set, invert the output of PWM0A and PWM0B for this submodule
      CHOPPER0_OUT_INVERT : Boolean := False;
      --  when set, invert the input of PWM0A and PWM0B for this submodule
      CHOPPER0_IN_INVERT  : Boolean := False;
      --  unspecified
      Reserved_14_31      : ESP32S3_Registers.UInt18 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CHOPPER0_CFG_Register use record
      CHOPPER0_EN         at 0 range 0 .. 0;
      CHOPPER0_PRESCALE   at 0 range 1 .. 4;
      CHOPPER0_DUTY       at 0 range 5 .. 7;
      CHOPPER0_OSHTWTH    at 0 range 8 .. 11;
      CHOPPER0_OUT_INVERT at 0 range 12 .. 12;
      CHOPPER0_IN_INVERT  at 0 range 13 .. 13;
      Reserved_14_31      at 0 range 14 .. 31;
   end record;

   subtype TZ0_CFG0_TZ0_A_CBC_D_Field is ESP32S3_Registers.UInt2;
   subtype TZ0_CFG0_TZ0_A_CBC_U_Field is ESP32S3_Registers.UInt2;
   subtype TZ0_CFG0_TZ0_A_OST_D_Field is ESP32S3_Registers.UInt2;
   subtype TZ0_CFG0_TZ0_A_OST_U_Field is ESP32S3_Registers.UInt2;
   subtype TZ0_CFG0_TZ0_B_CBC_D_Field is ESP32S3_Registers.UInt2;
   subtype TZ0_CFG0_TZ0_B_CBC_U_Field is ESP32S3_Registers.UInt2;
   subtype TZ0_CFG0_TZ0_B_OST_D_Field is ESP32S3_Registers.UInt2;
   subtype TZ0_CFG0_TZ0_B_OST_U_Field is ESP32S3_Registers.UInt2;

   --  Actions on PWM0A and PWM0B trip events
   type TZ0_CFG0_Register is record
      --  Enable register for software force cycle-by-cycle mode action. 0:
      --  disable, 1: enable
      TZ0_SW_CBC     : Boolean := False;
      --  event_f2 will trigger cycle-by-cycle mode action. 0: disable, 1:
      --  enable
      TZ0_F2_CBC     : Boolean := False;
      --  event_f1 will trigger cycle-by-cycle mode action. 0: disable, 1:
      --  enable
      TZ0_F1_CBC     : Boolean := False;
      --  event_f0 will trigger cycle-by-cycle mode action. 0: disable, 1:
      --  enable
      TZ0_F0_CBC     : Boolean := False;
      --  Enable register for software force one-shot mode action. 0: disable,
      --  1: enable
      TZ0_SW_OST     : Boolean := False;
      --  event_f2 will trigger one-shot mode action. 0: disable, 1: enable
      TZ0_F2_OST     : Boolean := False;
      --  event_f1 will trigger one-shot mode action. 0: disable, 1: enable
      TZ0_F1_OST     : Boolean := False;
      --  event_f0 will trigger one-shot mode action. 0: disable, 1: enable
      TZ0_F0_OST     : Boolean := False;
      --  Cycle-by-cycle mode action on PWM0A when fault event occurs and timer
      --  is decreasing. 0: do nothing, 1: force lo, 2: force hi, 3: toggle
      TZ0_A_CBC_D    : TZ0_CFG0_TZ0_A_CBC_D_Field := 16#0#;
      --  Cycle-by-cycle mode action on PWM0A when fault event occurs and timer
      --  is increasing. 0: do nothing, 1: force lo, 2: force hi, 3: toggle
      TZ0_A_CBC_U    : TZ0_CFG0_TZ0_A_CBC_U_Field := 16#0#;
      --  One-shot mode action on PWM0A when fault event occurs and timer is
      --  decreasing. 0: do nothing, 1: force lo, 2: force hi, 3: toggle
      TZ0_A_OST_D    : TZ0_CFG0_TZ0_A_OST_D_Field := 16#0#;
      --  One-shot mode action on PWM0A when fault event occurs and timer is
      --  increasing. 0: do nothing, 1: force lo, 2: force hi, 3: toggle
      TZ0_A_OST_U    : TZ0_CFG0_TZ0_A_OST_U_Field := 16#0#;
      --  Cycle-by-cycle mode action on PWM0B when fault event occurs and timer
      --  is decreasing. 0: do nothing, 1: force lo, 2: force hi, 3: toggle
      TZ0_B_CBC_D    : TZ0_CFG0_TZ0_B_CBC_D_Field := 16#0#;
      --  Cycle-by-cycle mode action on PWM0B when fault event occurs and timer
      --  is increasing. 0: do nothing, 1: force lo, 2: force hi, 3: toggle
      TZ0_B_CBC_U    : TZ0_CFG0_TZ0_B_CBC_U_Field := 16#0#;
      --  One-shot mode action on PWM0B when fault event occurs and timer is
      --  decreasing. 0: do nothing, 1: force lo, 2: force hi, 3: toggle
      TZ0_B_OST_D    : TZ0_CFG0_TZ0_B_OST_D_Field := 16#0#;
      --  One-shot mode action on PWM0B when fault event occurs and timer is
      --  increasing. 0: do nothing, 1: force lo, 2: force hi, 3: toggle
      TZ0_B_OST_U    : TZ0_CFG0_TZ0_B_OST_U_Field := 16#0#;
      --  unspecified
      Reserved_24_31 : ESP32S3_Registers.Byte := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for TZ0_CFG0_Register use record
      TZ0_SW_CBC     at 0 range 0 .. 0;
      TZ0_F2_CBC     at 0 range 1 .. 1;
      TZ0_F1_CBC     at 0 range 2 .. 2;
      TZ0_F0_CBC     at 0 range 3 .. 3;
      TZ0_SW_OST     at 0 range 4 .. 4;
      TZ0_F2_OST     at 0 range 5 .. 5;
      TZ0_F1_OST     at 0 range 6 .. 6;
      TZ0_F0_OST     at 0 range 7 .. 7;
      TZ0_A_CBC_D    at 0 range 8 .. 9;
      TZ0_A_CBC_U    at 0 range 10 .. 11;
      TZ0_A_OST_D    at 0 range 12 .. 13;
      TZ0_A_OST_U    at 0 range 14 .. 15;
      TZ0_B_CBC_D    at 0 range 16 .. 17;
      TZ0_B_CBC_U    at 0 range 18 .. 19;
      TZ0_B_OST_D    at 0 range 20 .. 21;
      TZ0_B_OST_U    at 0 range 22 .. 23;
      Reserved_24_31 at 0 range 24 .. 31;
   end record;

   subtype TZ0_CFG1_TZ0_CBCPULSE_Field is ESP32S3_Registers.UInt2;

   --  Software triggers for fault handler actions
   type TZ0_CFG1_Register is record
      --  a rising edge will clear on going one-shot mode action
      TZ0_CLR_OST   : Boolean := False;
      --  cycle-by-cycle mode action refresh moment selection. Bit0: TEZ,
      --  bit1:TEP
      TZ0_CBCPULSE  : TZ0_CFG1_TZ0_CBCPULSE_Field := 16#0#;
      --  a toggle trigger a cycle-by-cycle mode action
      TZ0_FORCE_CBC : Boolean := False;
      --  a toggle (software negate its value) triggers a one-shot mode action
      TZ0_FORCE_OST : Boolean := False;
      --  unspecified
      Reserved_5_31 : ESP32S3_Registers.UInt27 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for TZ0_CFG1_Register use record
      TZ0_CLR_OST   at 0 range 0 .. 0;
      TZ0_CBCPULSE  at 0 range 1 .. 2;
      TZ0_FORCE_CBC at 0 range 3 .. 3;
      TZ0_FORCE_OST at 0 range 4 .. 4;
      Reserved_5_31 at 0 range 5 .. 31;
   end record;

   --  Status of fault events.
   type TZ0_STATUS_Register is record
      --  Read-only. Set and reset by hardware. If set, a cycle-by-cycle mode
      --  action is on going
      TZ0_CBC_ON    : Boolean;
      --  Read-only. Set and reset by hardware. If set, an one-shot mode action
      --  is on going
      TZ0_OST_ON    : Boolean;
      --  unspecified
      Reserved_2_31 : ESP32S3_Registers.UInt30;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for TZ0_STATUS_Register use record
      TZ0_CBC_ON    at 0 range 0 .. 0;
      TZ0_OST_ON    at 0 range 1 .. 1;
      Reserved_2_31 at 0 range 2 .. 31;
   end record;

   subtype CMPR1_CFG_CMPR1_A_UPMETHOD_Field is ESP32S3_Registers.UInt4;
   subtype CMPR1_CFG_CMPR1_B_UPMETHOD_Field is ESP32S3_Registers.UInt4;

   --  Transfer status and update method for time stamp registers A and B
   type CMPR1_CFG_Register is record
      --  Update method for PWM generator 1 time stamp A's active register.
      --  When all bits are set to 0: immediately, when bit0 is set to 1: TEZ,
      --  when bit1 is set to 1: TEP,when bit2 is set to 1: sync, when bit3 is
      --  set to 1: disable the update.
      CMPR1_A_UPMETHOD  : CMPR1_CFG_CMPR1_A_UPMETHOD_Field := 16#0#;
      --  Update method for PWM generator 1 time stamp B's active register.
      --  When all bits are set to 0: immediately, when bit0 is set to 1: TEZ,
      --  when bit1 is set to 1: TEP,when bit2 is set to 1: sync, when bit3 is
      --  set to 1: disable the update.
      CMPR1_B_UPMETHOD  : CMPR1_CFG_CMPR1_B_UPMETHOD_Field := 16#0#;
      --  Set and reset by hardware. If set, PWM generator 1 time stamp A's
      --  shadow reg is filled and waiting to be transferred to A's active reg.
      --  If cleared, A's active reg has been updated with shadow register
      --  latest value
      CMPR1_A_SHDW_FULL : Boolean := False;
      --  Set and reset by hardware. If set, PWM generator 1 time stamp B's
      --  shadow reg is filled and waiting to be transferred to B's active reg.
      --  If cleared, B's active reg has been updated with shadow register
      --  latest value
      CMPR1_B_SHDW_FULL : Boolean := False;
      --  unspecified
      Reserved_10_31    : ESP32S3_Registers.UInt22 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CMPR1_CFG_Register use record
      CMPR1_A_UPMETHOD  at 0 range 0 .. 3;
      CMPR1_B_UPMETHOD  at 0 range 4 .. 7;
      CMPR1_A_SHDW_FULL at 0 range 8 .. 8;
      CMPR1_B_SHDW_FULL at 0 range 9 .. 9;
      Reserved_10_31    at 0 range 10 .. 31;
   end record;

   subtype CMPR1_VALUE0_CMPR1_A_Field is ESP32S3_Registers.UInt16;

   --  Shadow register for register A.
   type CMPR1_VALUE0_Register is record
      --  PWM generator 1 time stamp A's shadow register
      CMPR1_A        : CMPR1_VALUE0_CMPR1_A_Field := 16#0#;
      --  unspecified
      Reserved_16_31 : ESP32S3_Registers.UInt16 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CMPR1_VALUE0_Register use record
      CMPR1_A        at 0 range 0 .. 15;
      Reserved_16_31 at 0 range 16 .. 31;
   end record;

   subtype CMPR1_VALUE1_CMPR1_B_Field is ESP32S3_Registers.UInt16;

   --  Shadow register for register B.
   type CMPR1_VALUE1_Register is record
      --  PWM generator 1 time stamp B's shadow register
      CMPR1_B        : CMPR1_VALUE1_CMPR1_B_Field := 16#0#;
      --  unspecified
      Reserved_16_31 : ESP32S3_Registers.UInt16 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CMPR1_VALUE1_Register use record
      CMPR1_B        at 0 range 0 .. 15;
      Reserved_16_31 at 0 range 16 .. 31;
   end record;

   subtype GEN1_CFG0_GEN1_CFG_UPMETHOD_Field is ESP32S3_Registers.UInt4;
   subtype GEN1_CFG0_GEN1_T0_SEL_Field is ESP32S3_Registers.UInt3;
   subtype GEN1_CFG0_GEN1_T1_SEL_Field is ESP32S3_Registers.UInt3;

   --  Fault event T0 and T1 handling
   type GEN1_CFG0_Register is record
      --  Update method for PWM generator 1's active register of configuration.
      --  When all bits are set to 0: immediately, when bit0 is set to 1: TEZ,
      --  when bit1 is set to 1:
      GEN1_CFG_UPMETHOD : GEN1_CFG0_GEN1_CFG_UPMETHOD_Field := 16#0#;
      --  Source selection for PWM generator 1 event_t0, take effect
      --  immediately, 0: fault_event0, 1: fault_event1, 2: fault_event2, 3:
      --  sync_taken, 4: none
      GEN1_T0_SEL       : GEN1_CFG0_GEN1_T0_SEL_Field := 16#0#;
      --  Source selection for PWM generator 1 event_t1, take effect
      --  immediately, 0: fault_event0, 1: fault_event1, 2: fault_event2, 3:
      --  sync_taken, 4: none
      GEN1_T1_SEL       : GEN1_CFG0_GEN1_T1_SEL_Field := 16#0#;
      --  unspecified
      Reserved_10_31    : ESP32S3_Registers.UInt22 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for GEN1_CFG0_Register use record
      GEN1_CFG_UPMETHOD at 0 range 0 .. 3;
      GEN1_T0_SEL       at 0 range 4 .. 6;
      GEN1_T1_SEL       at 0 range 7 .. 9;
      Reserved_10_31    at 0 range 10 .. 31;
   end record;

   subtype GEN1_FORCE_GEN1_CNTUFORCE_UPMETHOD_Field is ESP32S3_Registers.UInt6;
   subtype GEN1_FORCE_GEN1_A_CNTUFORCE_MODE_Field is ESP32S3_Registers.UInt2;
   subtype GEN1_FORCE_GEN1_B_CNTUFORCE_MODE_Field is ESP32S3_Registers.UInt2;
   subtype GEN1_FORCE_GEN1_A_NCIFORCE_MODE_Field is ESP32S3_Registers.UInt2;
   subtype GEN1_FORCE_GEN1_B_NCIFORCE_MODE_Field is ESP32S3_Registers.UInt2;

   --  Permissives to force PWM1A and PWM1B outputs by software
   type GEN1_FORCE_Register is record
      --  Updating method for continuous software force of PWM generator 1.
      --  When all bits are set to 0: immediately, when bit0 is set to 1:
      --  TEZ,,when bit1 is set to 1: TEP, when bit2 is set to 1: TEA, when
      --  bit3 is set to 1: TEB, when bit4 is set to 1: sync, when bit5 is set
      --  to 1: disable update. (TEA/B here and below means an event generated
      --  when the timer's value equals to that of register A/B.)
      GEN1_CNTUFORCE_UPMETHOD : GEN1_FORCE_GEN1_CNTUFORCE_UPMETHOD_Field :=
                                 16#20#;
      --  Continuous software force mode for PWM1A. 0: disabled, 1: low, 2:
      --  high, 3: disabled
      GEN1_A_CNTUFORCE_MODE   : GEN1_FORCE_GEN1_A_CNTUFORCE_MODE_Field :=
                                 16#0#;
      --  Continuous software force mode for PWM1B. 0: disabled, 1: low, 2:
      --  high, 3: disabled
      GEN1_B_CNTUFORCE_MODE   : GEN1_FORCE_GEN1_B_CNTUFORCE_MODE_Field :=
                                 16#0#;
      --  Trigger of non-continuous immediate software-force event for PWM1A, a
      --  toggle will trigger a force event.
      GEN1_A_NCIFORCE         : Boolean := False;
      --  non-continuous immediate software force mode for PWM1A, 0: disabled,
      --  1: low, 2: high, 3: disabled
      GEN1_A_NCIFORCE_MODE    : GEN1_FORCE_GEN1_A_NCIFORCE_MODE_Field :=
                                 16#0#;
      --  Trigger of non-continuous immediate software-force event for PWM1B, a
      --  toggle will trigger a force event.
      GEN1_B_NCIFORCE         : Boolean := False;
      --  non-continuous immediate software force mode for PWM1B, 0: disabled,
      --  1: low, 2: high, 3: disabled
      GEN1_B_NCIFORCE_MODE    : GEN1_FORCE_GEN1_B_NCIFORCE_MODE_Field :=
                                 16#0#;
      --  unspecified
      Reserved_16_31          : ESP32S3_Registers.UInt16 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for GEN1_FORCE_Register use record
      GEN1_CNTUFORCE_UPMETHOD at 0 range 0 .. 5;
      GEN1_A_CNTUFORCE_MODE   at 0 range 6 .. 7;
      GEN1_B_CNTUFORCE_MODE   at 0 range 8 .. 9;
      GEN1_A_NCIFORCE         at 0 range 10 .. 10;
      GEN1_A_NCIFORCE_MODE    at 0 range 11 .. 12;
      GEN1_B_NCIFORCE         at 0 range 13 .. 13;
      GEN1_B_NCIFORCE_MODE    at 0 range 14 .. 15;
      Reserved_16_31          at 0 range 16 .. 31;
   end record;

   subtype GEN1_A_UTEZ_Field is ESP32S3_Registers.UInt2;
   subtype GEN1_A_UTEP_Field is ESP32S3_Registers.UInt2;
   subtype GEN1_A_UTEA_Field is ESP32S3_Registers.UInt2;
   subtype GEN1_A_UTEB_Field is ESP32S3_Registers.UInt2;
   --  GEN1_A_UT array element
   subtype GEN1_A_UT_Element is ESP32S3_Registers.UInt2;

   --  GEN1_A_UT array
   type GEN1_A_UT_Field_Array is array (0 .. 1) of GEN1_A_UT_Element
     with Component_Size => 2, Size => 4;

   --  Type definition for GEN1_A_UT
   type GEN1_A_UT_Field
     (As_Array : Boolean := False)
   is record
      case As_Array is
         when False =>
            --  UT as a value
            Val : ESP32S3_Registers.UInt4;
         when True =>
            --  UT as an array
            Arr : GEN1_A_UT_Field_Array;
      end case;
   end record
     with Unchecked_Union, Size => 4;

   for GEN1_A_UT_Field use record
      Val at 0 range 0 .. 3;
      Arr at 0 range 0 .. 3;
   end record;

   subtype GEN1_A_DTEZ_Field is ESP32S3_Registers.UInt2;
   subtype GEN1_A_DTEP_Field is ESP32S3_Registers.UInt2;
   subtype GEN1_A_DTEA_Field is ESP32S3_Registers.UInt2;
   subtype GEN1_A_DTEB_Field is ESP32S3_Registers.UInt2;
   --  GEN1_A_DT array element
   subtype GEN1_A_DT_Element is ESP32S3_Registers.UInt2;

   --  GEN1_A_DT array
   type GEN1_A_DT_Field_Array is array (0 .. 1) of GEN1_A_DT_Element
     with Component_Size => 2, Size => 4;

   --  Type definition for GEN1_A_DT
   type GEN1_A_DT_Field
     (As_Array : Boolean := False)
   is record
      case As_Array is
         when False =>
            --  DT as a value
            Val : ESP32S3_Registers.UInt4;
         when True =>
            --  DT as an array
            Arr : GEN1_A_DT_Field_Array;
      end case;
   end record
     with Unchecked_Union, Size => 4;

   for GEN1_A_DT_Field use record
      Val at 0 range 0 .. 3;
      Arr at 0 range 0 .. 3;
   end record;

   --  Actions triggered by events on PWM1A
   type GEN1_A_Register is record
      --  Action on PWM1A triggered by event TEZ when timer increasing
      UTEZ           : GEN1_A_UTEZ_Field := 16#0#;
      --  Action on PWM1A triggered by event TEP when timer increasing
      UTEP           : GEN1_A_UTEP_Field := 16#0#;
      --  Action on PWM1A triggered by event TEA when timer increasing
      UTEA           : GEN1_A_UTEA_Field := 16#0#;
      --  Action on PWM1A triggered by event TEB when timer increasing
      UTEB           : GEN1_A_UTEB_Field := 16#0#;
      --  Action on PWM1A triggered by event_t0 when timer increasing
      UT             : GEN1_A_UT_Field := (As_Array => False, Val => 16#0#);
      --  Action on PWM1A triggered by event TEZ when timer decreasing
      DTEZ           : GEN1_A_DTEZ_Field := 16#0#;
      --  Action on PWM1A triggered by event TEP when timer decreasing
      DTEP           : GEN1_A_DTEP_Field := 16#0#;
      --  Action on PWM1A triggered by event TEA when timer decreasing
      DTEA           : GEN1_A_DTEA_Field := 16#0#;
      --  Action on PWM1A triggered by event TEB when timer decreasing
      DTEB           : GEN1_A_DTEB_Field := 16#0#;
      --  Action on PWM1A triggered by event_t0 when timer decreasing
      DT             : GEN1_A_DT_Field := (As_Array => False, Val => 16#0#);
      --  unspecified
      Reserved_24_31 : ESP32S3_Registers.Byte := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for GEN1_A_Register use record
      UTEZ           at 0 range 0 .. 1;
      UTEP           at 0 range 2 .. 3;
      UTEA           at 0 range 4 .. 5;
      UTEB           at 0 range 6 .. 7;
      UT             at 0 range 8 .. 11;
      DTEZ           at 0 range 12 .. 13;
      DTEP           at 0 range 14 .. 15;
      DTEA           at 0 range 16 .. 17;
      DTEB           at 0 range 18 .. 19;
      DT             at 0 range 20 .. 23;
      Reserved_24_31 at 0 range 24 .. 31;
   end record;

   subtype GEN1_B_UTEZ_Field is ESP32S3_Registers.UInt2;
   subtype GEN1_B_UTEP_Field is ESP32S3_Registers.UInt2;
   subtype GEN1_B_UTEA_Field is ESP32S3_Registers.UInt2;
   subtype GEN1_B_UTEB_Field is ESP32S3_Registers.UInt2;
   --  GEN1_B_UT array element
   subtype GEN1_B_UT_Element is ESP32S3_Registers.UInt2;

   --  GEN1_B_UT array
   type GEN1_B_UT_Field_Array is array (0 .. 1) of GEN1_B_UT_Element
     with Component_Size => 2, Size => 4;

   --  Type definition for GEN1_B_UT
   type GEN1_B_UT_Field
     (As_Array : Boolean := False)
   is record
      case As_Array is
         when False =>
            --  UT as a value
            Val : ESP32S3_Registers.UInt4;
         when True =>
            --  UT as an array
            Arr : GEN1_B_UT_Field_Array;
      end case;
   end record
     with Unchecked_Union, Size => 4;

   for GEN1_B_UT_Field use record
      Val at 0 range 0 .. 3;
      Arr at 0 range 0 .. 3;
   end record;

   subtype GEN1_B_DTEZ_Field is ESP32S3_Registers.UInt2;
   subtype GEN1_B_DTEP_Field is ESP32S3_Registers.UInt2;
   subtype GEN1_B_DTEA_Field is ESP32S3_Registers.UInt2;
   subtype GEN1_B_DTEB_Field is ESP32S3_Registers.UInt2;
   --  GEN1_B_DT array element
   subtype GEN1_B_DT_Element is ESP32S3_Registers.UInt2;

   --  GEN1_B_DT array
   type GEN1_B_DT_Field_Array is array (0 .. 1) of GEN1_B_DT_Element
     with Component_Size => 2, Size => 4;

   --  Type definition for GEN1_B_DT
   type GEN1_B_DT_Field
     (As_Array : Boolean := False)
   is record
      case As_Array is
         when False =>
            --  DT as a value
            Val : ESP32S3_Registers.UInt4;
         when True =>
            --  DT as an array
            Arr : GEN1_B_DT_Field_Array;
      end case;
   end record
     with Unchecked_Union, Size => 4;

   for GEN1_B_DT_Field use record
      Val at 0 range 0 .. 3;
      Arr at 0 range 0 .. 3;
   end record;

   --  Actions triggered by events on PWM1B
   type GEN1_B_Register is record
      --  Action on PWM1B triggered by event TEZ when timer increasing
      UTEZ           : GEN1_B_UTEZ_Field := 16#0#;
      --  Action on PWM1B triggered by event TEP when timer increasing
      UTEP           : GEN1_B_UTEP_Field := 16#0#;
      --  Action on PWM1B triggered by event TEA when timer increasing
      UTEA           : GEN1_B_UTEA_Field := 16#0#;
      --  Action on PWM1B triggered by event TEB when timer increasing
      UTEB           : GEN1_B_UTEB_Field := 16#0#;
      --  Action on PWM1B triggered by event_t0 when timer increasing
      UT             : GEN1_B_UT_Field := (As_Array => False, Val => 16#0#);
      --  Action on PWM1B triggered by event TEZ when timer decreasing
      DTEZ           : GEN1_B_DTEZ_Field := 16#0#;
      --  Action on PWM1B triggered by event TEP when timer decreasing
      DTEP           : GEN1_B_DTEP_Field := 16#0#;
      --  Action on PWM1B triggered by event TEA when timer decreasing
      DTEA           : GEN1_B_DTEA_Field := 16#0#;
      --  Action on PWM1B triggered by event TEB when timer decreasing
      DTEB           : GEN1_B_DTEB_Field := 16#0#;
      --  Action on PWM1B triggered by event_t0 when timer decreasing
      DT             : GEN1_B_DT_Field := (As_Array => False, Val => 16#0#);
      --  unspecified
      Reserved_24_31 : ESP32S3_Registers.Byte := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for GEN1_B_Register use record
      UTEZ           at 0 range 0 .. 1;
      UTEP           at 0 range 2 .. 3;
      UTEA           at 0 range 4 .. 5;
      UTEB           at 0 range 6 .. 7;
      UT             at 0 range 8 .. 11;
      DTEZ           at 0 range 12 .. 13;
      DTEP           at 0 range 14 .. 15;
      DTEA           at 0 range 16 .. 17;
      DTEB           at 0 range 18 .. 19;
      DT             at 0 range 20 .. 23;
      Reserved_24_31 at 0 range 24 .. 31;
   end record;

   subtype DB1_CFG_DB1_FED_UPMETHOD_Field is ESP32S3_Registers.UInt4;
   subtype DB1_CFG_DB1_RED_UPMETHOD_Field is ESP32S3_Registers.UInt4;

   --  dead time type selection and configuration
   type DB1_CFG_Register is record
      --  Update method for FED (falling edge delay) active register. 0:
      --  immediate, bit0: tez, bit1: tep, bit2: sync, bit3: freeze
      DB1_FED_UPMETHOD  : DB1_CFG_DB1_FED_UPMETHOD_Field := 16#0#;
      --  Update method for RED (rising edge delay) active register. 0:
      --  immediate, bit0: tez, bit1: tep, bit2: sync, bit3: freeze
      DB1_RED_UPMETHOD  : DB1_CFG_DB1_RED_UPMETHOD_Field := 16#0#;
      --  S8 in documentation, dual-edge B mode, 0: fed/red take effect on
      --  different path separately, 1: fed/red take effect on B path, A out is
      --  in bypass or dulpB mode
      DB1_DEB_MODE      : Boolean := False;
      --  S6 in documentation
      DB1_A_OUTSWAP     : Boolean := False;
      --  S7 in documentation
      DB1_B_OUTSWAP     : Boolean := False;
      --  S4 in documentation
      DB1_RED_INSEL     : Boolean := False;
      --  S5 in documentation
      DB1_FED_INSEL     : Boolean := False;
      --  S2 in documentation
      DB1_RED_OUTINVERT : Boolean := False;
      --  S3 in documentation
      DB1_FED_OUTINVERT : Boolean := False;
      --  S1 in documentation
      DB1_A_OUTBYPASS   : Boolean := True;
      --  S0 in documentation
      DB1_B_OUTBYPASS   : Boolean := True;
      --  Dead time generator 1 clock selection. 0: PWM_clk, 1: PT_clk
      DB1_CLK_SEL       : Boolean := False;
      --  unspecified
      Reserved_18_31    : ESP32S3_Registers.UInt14 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DB1_CFG_Register use record
      DB1_FED_UPMETHOD  at 0 range 0 .. 3;
      DB1_RED_UPMETHOD  at 0 range 4 .. 7;
      DB1_DEB_MODE      at 0 range 8 .. 8;
      DB1_A_OUTSWAP     at 0 range 9 .. 9;
      DB1_B_OUTSWAP     at 0 range 10 .. 10;
      DB1_RED_INSEL     at 0 range 11 .. 11;
      DB1_FED_INSEL     at 0 range 12 .. 12;
      DB1_RED_OUTINVERT at 0 range 13 .. 13;
      DB1_FED_OUTINVERT at 0 range 14 .. 14;
      DB1_A_OUTBYPASS   at 0 range 15 .. 15;
      DB1_B_OUTBYPASS   at 0 range 16 .. 16;
      DB1_CLK_SEL       at 0 range 17 .. 17;
      Reserved_18_31    at 0 range 18 .. 31;
   end record;

   subtype DB1_FED_CFG_DB1_FED_Field is ESP32S3_Registers.UInt16;

   --  Shadow register for falling edge delay (FED).
   type DB1_FED_CFG_Register is record
      --  Shadow register for FED
      DB1_FED        : DB1_FED_CFG_DB1_FED_Field := 16#0#;
      --  unspecified
      Reserved_16_31 : ESP32S3_Registers.UInt16 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DB1_FED_CFG_Register use record
      DB1_FED        at 0 range 0 .. 15;
      Reserved_16_31 at 0 range 16 .. 31;
   end record;

   subtype DB1_RED_CFG_DB1_RED_Field is ESP32S3_Registers.UInt16;

   --  Shadow register for rising edge delay (RED).
   type DB1_RED_CFG_Register is record
      --  Shadow register for RED
      DB1_RED        : DB1_RED_CFG_DB1_RED_Field := 16#0#;
      --  unspecified
      Reserved_16_31 : ESP32S3_Registers.UInt16 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DB1_RED_CFG_Register use record
      DB1_RED        at 0 range 0 .. 15;
      Reserved_16_31 at 0 range 16 .. 31;
   end record;

   subtype CHOPPER1_CFG_CHOPPER1_PRESCALE_Field is ESP32S3_Registers.UInt4;
   subtype CHOPPER1_CFG_CHOPPER1_DUTY_Field is ESP32S3_Registers.UInt3;
   subtype CHOPPER1_CFG_CHOPPER1_OSHTWTH_Field is ESP32S3_Registers.UInt4;

   --  Carrier enable and configuratoin
   type CHOPPER1_CFG_Register is record
      --  When set, carrier0 function is enabled. When cleared, carrier0 is
      --  bypassed
      CHOPPER1_EN         : Boolean := False;
      --  PWM carrier0 clock (PC_clk) prescale value. Period of PC_clk = period
      --  of PWM_clk * (PWM_CARRIER0_PRESCALE + 1)
      CHOPPER1_PRESCALE   : CHOPPER1_CFG_CHOPPER1_PRESCALE_Field := 16#0#;
      --  carrier duty selection. Duty = PWM_CARRIER0_DUTY / 8
      CHOPPER1_DUTY       : CHOPPER1_CFG_CHOPPER1_DUTY_Field := 16#0#;
      --  width of the fist pulse in number of periods of the carrier
      CHOPPER1_OSHTWTH    : CHOPPER1_CFG_CHOPPER1_OSHTWTH_Field := 16#0#;
      --  when set, invert the output of PWM1A and PWM1B for this submodule
      CHOPPER1_OUT_INVERT : Boolean := False;
      --  when set, invert the input of PWM1A and PWM1B for this submodule
      CHOPPER1_IN_INVERT  : Boolean := False;
      --  unspecified
      Reserved_14_31      : ESP32S3_Registers.UInt18 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CHOPPER1_CFG_Register use record
      CHOPPER1_EN         at 0 range 0 .. 0;
      CHOPPER1_PRESCALE   at 0 range 1 .. 4;
      CHOPPER1_DUTY       at 0 range 5 .. 7;
      CHOPPER1_OSHTWTH    at 0 range 8 .. 11;
      CHOPPER1_OUT_INVERT at 0 range 12 .. 12;
      CHOPPER1_IN_INVERT  at 0 range 13 .. 13;
      Reserved_14_31      at 0 range 14 .. 31;
   end record;

   subtype TZ1_CFG0_TZ1_A_CBC_D_Field is ESP32S3_Registers.UInt2;
   subtype TZ1_CFG0_TZ1_A_CBC_U_Field is ESP32S3_Registers.UInt2;
   subtype TZ1_CFG0_TZ1_A_OST_D_Field is ESP32S3_Registers.UInt2;
   subtype TZ1_CFG0_TZ1_A_OST_U_Field is ESP32S3_Registers.UInt2;
   subtype TZ1_CFG0_TZ1_B_CBC_D_Field is ESP32S3_Registers.UInt2;
   subtype TZ1_CFG0_TZ1_B_CBC_U_Field is ESP32S3_Registers.UInt2;
   subtype TZ1_CFG0_TZ1_B_OST_D_Field is ESP32S3_Registers.UInt2;
   subtype TZ1_CFG0_TZ1_B_OST_U_Field is ESP32S3_Registers.UInt2;

   --  Actions on PWM1A and PWM1B trip events
   type TZ1_CFG0_Register is record
      --  Enable register for software force cycle-by-cycle mode action. 0:
      --  disable, 1: enable
      TZ1_SW_CBC     : Boolean := False;
      --  event_f2 will trigger cycle-by-cycle mode action. 0: disable, 1:
      --  enable
      TZ1_F2_CBC     : Boolean := False;
      --  event_f1 will trigger cycle-by-cycle mode action. 0: disable, 1:
      --  enable
      TZ1_F1_CBC     : Boolean := False;
      --  event_f0 will trigger cycle-by-cycle mode action. 0: disable, 1:
      --  enable
      TZ1_F0_CBC     : Boolean := False;
      --  Enable register for software force one-shot mode action. 0: disable,
      --  1: enable
      TZ1_SW_OST     : Boolean := False;
      --  event_f2 will trigger one-shot mode action. 0: disable, 1: enable
      TZ1_F2_OST     : Boolean := False;
      --  event_f1 will trigger one-shot mode action. 0: disable, 1: enable
      TZ1_F1_OST     : Boolean := False;
      --  event_f0 will trigger one-shot mode action. 0: disable, 1: enable
      TZ1_F0_OST     : Boolean := False;
      --  Cycle-by-cycle mode action on PWM1A when fault event occurs and timer
      --  is decreasing. 0: do nothing, 1: force lo, 2: force hi, 3: toggle
      TZ1_A_CBC_D    : TZ1_CFG0_TZ1_A_CBC_D_Field := 16#0#;
      --  Cycle-by-cycle mode action on PWM1A when fault event occurs and timer
      --  is increasing. 0: do nothing, 1: force lo, 2: force hi, 3: toggle
      TZ1_A_CBC_U    : TZ1_CFG0_TZ1_A_CBC_U_Field := 16#0#;
      --  One-shot mode action on PWM1A when fault event occurs and timer is
      --  decreasing. 0: do nothing, 1: force lo, 2: force hi, 3: toggle
      TZ1_A_OST_D    : TZ1_CFG0_TZ1_A_OST_D_Field := 16#0#;
      --  One-shot mode action on PWM1A when fault event occurs and timer is
      --  increasing. 0: do nothing, 1: force lo, 2: force hi, 3: toggle
      TZ1_A_OST_U    : TZ1_CFG0_TZ1_A_OST_U_Field := 16#0#;
      --  Cycle-by-cycle mode action on PWM1B when fault event occurs and timer
      --  is decreasing. 0: do nothing, 1: force lo, 2: force hi, 3: toggle
      TZ1_B_CBC_D    : TZ1_CFG0_TZ1_B_CBC_D_Field := 16#0#;
      --  Cycle-by-cycle mode action on PWM1B when fault event occurs and timer
      --  is increasing. 0: do nothing, 1: force lo, 2: force hi, 3: toggle
      TZ1_B_CBC_U    : TZ1_CFG0_TZ1_B_CBC_U_Field := 16#0#;
      --  One-shot mode action on PWM1B when fault event occurs and timer is
      --  decreasing. 0: do nothing, 1: force lo, 2: force hi, 3: toggle
      TZ1_B_OST_D    : TZ1_CFG0_TZ1_B_OST_D_Field := 16#0#;
      --  One-shot mode action on PWM1B when fault event occurs and timer is
      --  increasing. 0: do nothing, 1: force lo, 2: force hi, 3: toggle
      TZ1_B_OST_U    : TZ1_CFG0_TZ1_B_OST_U_Field := 16#0#;
      --  unspecified
      Reserved_24_31 : ESP32S3_Registers.Byte := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for TZ1_CFG0_Register use record
      TZ1_SW_CBC     at 0 range 0 .. 0;
      TZ1_F2_CBC     at 0 range 1 .. 1;
      TZ1_F1_CBC     at 0 range 2 .. 2;
      TZ1_F0_CBC     at 0 range 3 .. 3;
      TZ1_SW_OST     at 0 range 4 .. 4;
      TZ1_F2_OST     at 0 range 5 .. 5;
      TZ1_F1_OST     at 0 range 6 .. 6;
      TZ1_F0_OST     at 0 range 7 .. 7;
      TZ1_A_CBC_D    at 0 range 8 .. 9;
      TZ1_A_CBC_U    at 0 range 10 .. 11;
      TZ1_A_OST_D    at 0 range 12 .. 13;
      TZ1_A_OST_U    at 0 range 14 .. 15;
      TZ1_B_CBC_D    at 0 range 16 .. 17;
      TZ1_B_CBC_U    at 0 range 18 .. 19;
      TZ1_B_OST_D    at 0 range 20 .. 21;
      TZ1_B_OST_U    at 0 range 22 .. 23;
      Reserved_24_31 at 0 range 24 .. 31;
   end record;

   subtype TZ1_CFG1_TZ1_CBCPULSE_Field is ESP32S3_Registers.UInt2;

   --  Software triggers for fault handler actions
   type TZ1_CFG1_Register is record
      --  a rising edge will clear on going one-shot mode action
      TZ1_CLR_OST   : Boolean := False;
      --  cycle-by-cycle mode action refresh moment selection. Bit0: TEZ,
      --  bit1:TEP
      TZ1_CBCPULSE  : TZ1_CFG1_TZ1_CBCPULSE_Field := 16#0#;
      --  a toggle trigger a cycle-by-cycle mode action
      TZ1_FORCE_CBC : Boolean := False;
      --  a toggle (software negate its value) triggers a one-shot mode action
      TZ1_FORCE_OST : Boolean := False;
      --  unspecified
      Reserved_5_31 : ESP32S3_Registers.UInt27 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for TZ1_CFG1_Register use record
      TZ1_CLR_OST   at 0 range 0 .. 0;
      TZ1_CBCPULSE  at 0 range 1 .. 2;
      TZ1_FORCE_CBC at 0 range 3 .. 3;
      TZ1_FORCE_OST at 0 range 4 .. 4;
      Reserved_5_31 at 0 range 5 .. 31;
   end record;

   --  Status of fault events.
   type TZ1_STATUS_Register is record
      --  Read-only. Set and reset by hardware. If set, a cycle-by-cycle mode
      --  action is on going
      TZ1_CBC_ON    : Boolean;
      --  Read-only. Set and reset by hardware. If set, an one-shot mode action
      --  is on going
      TZ1_OST_ON    : Boolean;
      --  unspecified
      Reserved_2_31 : ESP32S3_Registers.UInt30;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for TZ1_STATUS_Register use record
      TZ1_CBC_ON    at 0 range 0 .. 0;
      TZ1_OST_ON    at 0 range 1 .. 1;
      Reserved_2_31 at 0 range 2 .. 31;
   end record;

   subtype CMPR2_CFG_CMPR2_A_UPMETHOD_Field is ESP32S3_Registers.UInt4;
   subtype CMPR2_CFG_CMPR2_B_UPMETHOD_Field is ESP32S3_Registers.UInt4;

   --  Transfer status and update method for time stamp registers A and B
   type CMPR2_CFG_Register is record
      --  Update method for PWM generator 2 time stamp A's active register.
      --  When all bits are set to 0: immediately, when bit0 is set to 1: TEZ,
      --  when bit1 is set to 1: TEP,when bit2 is set to 1: sync, when bit3 is
      --  set to 1: disable the update.
      CMPR2_A_UPMETHOD  : CMPR2_CFG_CMPR2_A_UPMETHOD_Field := 16#0#;
      --  Update method for PWM generator 2 time stamp B's active register.
      --  When all bits are set to 0: immediately, when bit0 is set to 1: TEZ,
      --  when bit1 is set to 1: TEP,when bit2 is set to 1: sync, when bit3 is
      --  set to 1: disable the update.
      CMPR2_B_UPMETHOD  : CMPR2_CFG_CMPR2_B_UPMETHOD_Field := 16#0#;
      --  Set and reset by hardware. If set, PWM generator 2 time stamp A's
      --  shadow reg is filled and waiting to be transferred to A's active reg.
      --  If cleared, A's active reg has been updated with shadow register
      --  latest value
      CMPR2_A_SHDW_FULL : Boolean := False;
      --  Set and reset by hardware. If set, PWM generator 2 time stamp B's
      --  shadow reg is filled and waiting to be transferred to B's active reg.
      --  If cleared, B's active reg has been updated with shadow register
      --  latest value
      CMPR2_B_SHDW_FULL : Boolean := False;
      --  unspecified
      Reserved_10_31    : ESP32S3_Registers.UInt22 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CMPR2_CFG_Register use record
      CMPR2_A_UPMETHOD  at 0 range 0 .. 3;
      CMPR2_B_UPMETHOD  at 0 range 4 .. 7;
      CMPR2_A_SHDW_FULL at 0 range 8 .. 8;
      CMPR2_B_SHDW_FULL at 0 range 9 .. 9;
      Reserved_10_31    at 0 range 10 .. 31;
   end record;

   subtype CMPR2_VALUE0_CMPR2_A_Field is ESP32S3_Registers.UInt16;

   --  Shadow register for register A.
   type CMPR2_VALUE0_Register is record
      --  PWM generator 2 time stamp A's shadow register
      CMPR2_A        : CMPR2_VALUE0_CMPR2_A_Field := 16#0#;
      --  unspecified
      Reserved_16_31 : ESP32S3_Registers.UInt16 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CMPR2_VALUE0_Register use record
      CMPR2_A        at 0 range 0 .. 15;
      Reserved_16_31 at 0 range 16 .. 31;
   end record;

   subtype CMPR2_VALUE1_CMPR2_B_Field is ESP32S3_Registers.UInt16;

   --  Shadow register for register B.
   type CMPR2_VALUE1_Register is record
      --  PWM generator 2 time stamp B's shadow register
      CMPR2_B        : CMPR2_VALUE1_CMPR2_B_Field := 16#0#;
      --  unspecified
      Reserved_16_31 : ESP32S3_Registers.UInt16 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CMPR2_VALUE1_Register use record
      CMPR2_B        at 0 range 0 .. 15;
      Reserved_16_31 at 0 range 16 .. 31;
   end record;

   subtype GEN2_CFG0_GEN2_CFG_UPMETHOD_Field is ESP32S3_Registers.UInt4;
   subtype GEN2_CFG0_GEN2_T0_SEL_Field is ESP32S3_Registers.UInt3;
   subtype GEN2_CFG0_GEN2_T1_SEL_Field is ESP32S3_Registers.UInt3;

   --  Fault event T0 and T1 handling
   type GEN2_CFG0_Register is record
      --  Update method for PWM generator 2's active register of configuration.
      --  When all bits are set to 0: immediately, when bit0 is set to 1: TEZ,
      --  when bit1 is set to 1:
      GEN2_CFG_UPMETHOD : GEN2_CFG0_GEN2_CFG_UPMETHOD_Field := 16#0#;
      --  Source selection for PWM generator 2 event_t0, take effect
      --  immediately, 0: fault_event0, 1: fault_event1, 2: fault_event2, 3:
      --  sync_taken, 4: none
      GEN2_T0_SEL       : GEN2_CFG0_GEN2_T0_SEL_Field := 16#0#;
      --  Source selection for PWM generator 2 event_t1, take effect
      --  immediately, 0: fault_event0, 1: fault_event1, 2: fault_event2, 3:
      --  sync_taken, 4: none
      GEN2_T1_SEL       : GEN2_CFG0_GEN2_T1_SEL_Field := 16#0#;
      --  unspecified
      Reserved_10_31    : ESP32S3_Registers.UInt22 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for GEN2_CFG0_Register use record
      GEN2_CFG_UPMETHOD at 0 range 0 .. 3;
      GEN2_T0_SEL       at 0 range 4 .. 6;
      GEN2_T1_SEL       at 0 range 7 .. 9;
      Reserved_10_31    at 0 range 10 .. 31;
   end record;

   subtype GEN2_FORCE_GEN2_CNTUFORCE_UPMETHOD_Field is ESP32S3_Registers.UInt6;
   subtype GEN2_FORCE_GEN2_A_CNTUFORCE_MODE_Field is ESP32S3_Registers.UInt2;
   subtype GEN2_FORCE_GEN2_B_CNTUFORCE_MODE_Field is ESP32S3_Registers.UInt2;
   subtype GEN2_FORCE_GEN2_A_NCIFORCE_MODE_Field is ESP32S3_Registers.UInt2;
   subtype GEN2_FORCE_GEN2_B_NCIFORCE_MODE_Field is ESP32S3_Registers.UInt2;

   --  Permissives to force PWM2A and PWM2B outputs by software
   type GEN2_FORCE_Register is record
      --  Updating method for continuous software force of PWM generator 2.
      --  When all bits are set to 0: immediately, when bit0 is set to 1:
      --  TEZ,,when bit1 is set to 1: TEP, when bit2 is set to 1: TEA, when
      --  bit3 is set to 1: TEB, when bit4 is set to 1: sync, when bit5 is set
      --  to 1: disable update. (TEA/B here and below means an event generated
      --  when the timer's value equals to that of register A/B.)
      GEN2_CNTUFORCE_UPMETHOD : GEN2_FORCE_GEN2_CNTUFORCE_UPMETHOD_Field :=
                                 16#20#;
      --  Continuous software force mode for PWM2A. 0: disabled, 1: low, 2:
      --  high, 3: disabled
      GEN2_A_CNTUFORCE_MODE   : GEN2_FORCE_GEN2_A_CNTUFORCE_MODE_Field :=
                                 16#0#;
      --  Continuous software force mode for PWM2B. 0: disabled, 1: low, 2:
      --  high, 3: disabled
      GEN2_B_CNTUFORCE_MODE   : GEN2_FORCE_GEN2_B_CNTUFORCE_MODE_Field :=
                                 16#0#;
      --  Trigger of non-continuous immediate software-force event for PWM2A, a
      --  toggle will trigger a force event.
      GEN2_A_NCIFORCE         : Boolean := False;
      --  non-continuous immediate software force mode for PWM2A, 0: disabled,
      --  1: low, 2: high, 3: disabled
      GEN2_A_NCIFORCE_MODE    : GEN2_FORCE_GEN2_A_NCIFORCE_MODE_Field :=
                                 16#0#;
      --  Trigger of non-continuous immediate software-force event for PWM2B, a
      --  toggle will trigger a force event.
      GEN2_B_NCIFORCE         : Boolean := False;
      --  non-continuous immediate software force mode for PWM2B, 0: disabled,
      --  1: low, 2: high, 3: disabled
      GEN2_B_NCIFORCE_MODE    : GEN2_FORCE_GEN2_B_NCIFORCE_MODE_Field :=
                                 16#0#;
      --  unspecified
      Reserved_16_31          : ESP32S3_Registers.UInt16 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for GEN2_FORCE_Register use record
      GEN2_CNTUFORCE_UPMETHOD at 0 range 0 .. 5;
      GEN2_A_CNTUFORCE_MODE   at 0 range 6 .. 7;
      GEN2_B_CNTUFORCE_MODE   at 0 range 8 .. 9;
      GEN2_A_NCIFORCE         at 0 range 10 .. 10;
      GEN2_A_NCIFORCE_MODE    at 0 range 11 .. 12;
      GEN2_B_NCIFORCE         at 0 range 13 .. 13;
      GEN2_B_NCIFORCE_MODE    at 0 range 14 .. 15;
      Reserved_16_31          at 0 range 16 .. 31;
   end record;

   subtype GEN2_A_UTEZ_Field is ESP32S3_Registers.UInt2;
   subtype GEN2_A_UTEP_Field is ESP32S3_Registers.UInt2;
   subtype GEN2_A_UTEA_Field is ESP32S3_Registers.UInt2;
   subtype GEN2_A_UTEB_Field is ESP32S3_Registers.UInt2;
   --  GEN2_A_UT array element
   subtype GEN2_A_UT_Element is ESP32S3_Registers.UInt2;

   --  GEN2_A_UT array
   type GEN2_A_UT_Field_Array is array (0 .. 1) of GEN2_A_UT_Element
     with Component_Size => 2, Size => 4;

   --  Type definition for GEN2_A_UT
   type GEN2_A_UT_Field
     (As_Array : Boolean := False)
   is record
      case As_Array is
         when False =>
            --  UT as a value
            Val : ESP32S3_Registers.UInt4;
         when True =>
            --  UT as an array
            Arr : GEN2_A_UT_Field_Array;
      end case;
   end record
     with Unchecked_Union, Size => 4;

   for GEN2_A_UT_Field use record
      Val at 0 range 0 .. 3;
      Arr at 0 range 0 .. 3;
   end record;

   subtype GEN2_A_DTEZ_Field is ESP32S3_Registers.UInt2;
   subtype GEN2_A_DTEP_Field is ESP32S3_Registers.UInt2;
   subtype GEN2_A_DTEA_Field is ESP32S3_Registers.UInt2;
   subtype GEN2_A_DTEB_Field is ESP32S3_Registers.UInt2;
   --  GEN2_A_DT array element
   subtype GEN2_A_DT_Element is ESP32S3_Registers.UInt2;

   --  GEN2_A_DT array
   type GEN2_A_DT_Field_Array is array (0 .. 1) of GEN2_A_DT_Element
     with Component_Size => 2, Size => 4;

   --  Type definition for GEN2_A_DT
   type GEN2_A_DT_Field
     (As_Array : Boolean := False)
   is record
      case As_Array is
         when False =>
            --  DT as a value
            Val : ESP32S3_Registers.UInt4;
         when True =>
            --  DT as an array
            Arr : GEN2_A_DT_Field_Array;
      end case;
   end record
     with Unchecked_Union, Size => 4;

   for GEN2_A_DT_Field use record
      Val at 0 range 0 .. 3;
      Arr at 0 range 0 .. 3;
   end record;

   --  Actions triggered by events on PWM2A
   type GEN2_A_Register is record
      --  Action on PWM2A triggered by event TEZ when timer increasing
      UTEZ           : GEN2_A_UTEZ_Field := 16#0#;
      --  Action on PWM2A triggered by event TEP when timer increasing
      UTEP           : GEN2_A_UTEP_Field := 16#0#;
      --  Action on PWM2A triggered by event TEA when timer increasing
      UTEA           : GEN2_A_UTEA_Field := 16#0#;
      --  Action on PWM2A triggered by event TEB when timer increasing
      UTEB           : GEN2_A_UTEB_Field := 16#0#;
      --  Action on PWM2A triggered by event_t0 when timer increasing
      UT             : GEN2_A_UT_Field := (As_Array => False, Val => 16#0#);
      --  Action on PWM2A triggered by event TEZ when timer decreasing
      DTEZ           : GEN2_A_DTEZ_Field := 16#0#;
      --  Action on PWM2A triggered by event TEP when timer decreasing
      DTEP           : GEN2_A_DTEP_Field := 16#0#;
      --  Action on PWM2A triggered by event TEA when timer decreasing
      DTEA           : GEN2_A_DTEA_Field := 16#0#;
      --  Action on PWM2A triggered by event TEB when timer decreasing
      DTEB           : GEN2_A_DTEB_Field := 16#0#;
      --  Action on PWM2A triggered by event_t0 when timer decreasing
      DT             : GEN2_A_DT_Field := (As_Array => False, Val => 16#0#);
      --  unspecified
      Reserved_24_31 : ESP32S3_Registers.Byte := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for GEN2_A_Register use record
      UTEZ           at 0 range 0 .. 1;
      UTEP           at 0 range 2 .. 3;
      UTEA           at 0 range 4 .. 5;
      UTEB           at 0 range 6 .. 7;
      UT             at 0 range 8 .. 11;
      DTEZ           at 0 range 12 .. 13;
      DTEP           at 0 range 14 .. 15;
      DTEA           at 0 range 16 .. 17;
      DTEB           at 0 range 18 .. 19;
      DT             at 0 range 20 .. 23;
      Reserved_24_31 at 0 range 24 .. 31;
   end record;

   subtype GEN2_B_UTEZ_Field is ESP32S3_Registers.UInt2;
   subtype GEN2_B_UTEP_Field is ESP32S3_Registers.UInt2;
   subtype GEN2_B_UTEA_Field is ESP32S3_Registers.UInt2;
   subtype GEN2_B_UTEB_Field is ESP32S3_Registers.UInt2;
   --  GEN2_B_UT array element
   subtype GEN2_B_UT_Element is ESP32S3_Registers.UInt2;

   --  GEN2_B_UT array
   type GEN2_B_UT_Field_Array is array (0 .. 1) of GEN2_B_UT_Element
     with Component_Size => 2, Size => 4;

   --  Type definition for GEN2_B_UT
   type GEN2_B_UT_Field
     (As_Array : Boolean := False)
   is record
      case As_Array is
         when False =>
            --  UT as a value
            Val : ESP32S3_Registers.UInt4;
         when True =>
            --  UT as an array
            Arr : GEN2_B_UT_Field_Array;
      end case;
   end record
     with Unchecked_Union, Size => 4;

   for GEN2_B_UT_Field use record
      Val at 0 range 0 .. 3;
      Arr at 0 range 0 .. 3;
   end record;

   subtype GEN2_B_DTEZ_Field is ESP32S3_Registers.UInt2;
   subtype GEN2_B_DTEP_Field is ESP32S3_Registers.UInt2;
   subtype GEN2_B_DTEA_Field is ESP32S3_Registers.UInt2;
   subtype GEN2_B_DTEB_Field is ESP32S3_Registers.UInt2;
   --  GEN2_B_DT array element
   subtype GEN2_B_DT_Element is ESP32S3_Registers.UInt2;

   --  GEN2_B_DT array
   type GEN2_B_DT_Field_Array is array (0 .. 1) of GEN2_B_DT_Element
     with Component_Size => 2, Size => 4;

   --  Type definition for GEN2_B_DT
   type GEN2_B_DT_Field
     (As_Array : Boolean := False)
   is record
      case As_Array is
         when False =>
            --  DT as a value
            Val : ESP32S3_Registers.UInt4;
         when True =>
            --  DT as an array
            Arr : GEN2_B_DT_Field_Array;
      end case;
   end record
     with Unchecked_Union, Size => 4;

   for GEN2_B_DT_Field use record
      Val at 0 range 0 .. 3;
      Arr at 0 range 0 .. 3;
   end record;

   --  Actions triggered by events on PWM2B
   type GEN2_B_Register is record
      --  Action on PWM2B triggered by event TEZ when timer increasing
      UTEZ           : GEN2_B_UTEZ_Field := 16#0#;
      --  Action on PWM2B triggered by event TEP when timer increasing
      UTEP           : GEN2_B_UTEP_Field := 16#0#;
      --  Action on PWM2B triggered by event TEA when timer increasing
      UTEA           : GEN2_B_UTEA_Field := 16#0#;
      --  Action on PWM2B triggered by event TEB when timer increasing
      UTEB           : GEN2_B_UTEB_Field := 16#0#;
      --  Action on PWM2B triggered by event_t0 when timer increasing
      UT             : GEN2_B_UT_Field := (As_Array => False, Val => 16#0#);
      --  Action on PWM2B triggered by event TEZ when timer decreasing
      DTEZ           : GEN2_B_DTEZ_Field := 16#0#;
      --  Action on PWM2B triggered by event TEP when timer decreasing
      DTEP           : GEN2_B_DTEP_Field := 16#0#;
      --  Action on PWM2B triggered by event TEA when timer decreasing
      DTEA           : GEN2_B_DTEA_Field := 16#0#;
      --  Action on PWM2B triggered by event TEB when timer decreasing
      DTEB           : GEN2_B_DTEB_Field := 16#0#;
      --  Action on PWM2B triggered by event_t0 when timer decreasing
      DT             : GEN2_B_DT_Field := (As_Array => False, Val => 16#0#);
      --  unspecified
      Reserved_24_31 : ESP32S3_Registers.Byte := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for GEN2_B_Register use record
      UTEZ           at 0 range 0 .. 1;
      UTEP           at 0 range 2 .. 3;
      UTEA           at 0 range 4 .. 5;
      UTEB           at 0 range 6 .. 7;
      UT             at 0 range 8 .. 11;
      DTEZ           at 0 range 12 .. 13;
      DTEP           at 0 range 14 .. 15;
      DTEA           at 0 range 16 .. 17;
      DTEB           at 0 range 18 .. 19;
      DT             at 0 range 20 .. 23;
      Reserved_24_31 at 0 range 24 .. 31;
   end record;

   subtype DB2_CFG_DB2_FED_UPMETHOD_Field is ESP32S3_Registers.UInt4;
   subtype DB2_CFG_DB2_RED_UPMETHOD_Field is ESP32S3_Registers.UInt4;

   --  dead time type selection and configuration
   type DB2_CFG_Register is record
      --  Update method for FED (falling edge delay) active register. 0:
      --  immediate, bit0: tez, bit1: tep, bit2: sync, bit3: freeze
      DB2_FED_UPMETHOD  : DB2_CFG_DB2_FED_UPMETHOD_Field := 16#0#;
      --  Update method for RED (rising edge delay) active register. 0:
      --  immediate, bit0: tez, bit1: tep, bit2: sync, bit3: freeze
      DB2_RED_UPMETHOD  : DB2_CFG_DB2_RED_UPMETHOD_Field := 16#0#;
      --  S8 in documentation, dual-edge B mode, 0: fed/red take effect on
      --  different path separately, 1: fed/red take effect on B path, A out is
      --  in bypass or dulpB mode
      DB2_DEB_MODE      : Boolean := False;
      --  S6 in documentation
      DB2_A_OUTSWAP     : Boolean := False;
      --  S7 in documentation
      DB2_B_OUTSWAP     : Boolean := False;
      --  S4 in documentation
      DB2_RED_INSEL     : Boolean := False;
      --  S5 in documentation
      DB2_FED_INSEL     : Boolean := False;
      --  S2 in documentation
      DB2_RED_OUTINVERT : Boolean := False;
      --  S3 in documentation
      DB2_FED_OUTINVERT : Boolean := False;
      --  S1 in documentation
      DB2_A_OUTBYPASS   : Boolean := True;
      --  S0 in documentation
      DB2_B_OUTBYPASS   : Boolean := True;
      --  Dead time generator 2 clock selection. 0: PWM_clk, 1: PT_clk
      DB2_CLK_SEL       : Boolean := False;
      --  unspecified
      Reserved_18_31    : ESP32S3_Registers.UInt14 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DB2_CFG_Register use record
      DB2_FED_UPMETHOD  at 0 range 0 .. 3;
      DB2_RED_UPMETHOD  at 0 range 4 .. 7;
      DB2_DEB_MODE      at 0 range 8 .. 8;
      DB2_A_OUTSWAP     at 0 range 9 .. 9;
      DB2_B_OUTSWAP     at 0 range 10 .. 10;
      DB2_RED_INSEL     at 0 range 11 .. 11;
      DB2_FED_INSEL     at 0 range 12 .. 12;
      DB2_RED_OUTINVERT at 0 range 13 .. 13;
      DB2_FED_OUTINVERT at 0 range 14 .. 14;
      DB2_A_OUTBYPASS   at 0 range 15 .. 15;
      DB2_B_OUTBYPASS   at 0 range 16 .. 16;
      DB2_CLK_SEL       at 0 range 17 .. 17;
      Reserved_18_31    at 0 range 18 .. 31;
   end record;

   subtype DB2_FED_CFG_DB2_FED_Field is ESP32S3_Registers.UInt16;

   --  Shadow register for falling edge delay (FED).
   type DB2_FED_CFG_Register is record
      --  Shadow register for FED
      DB2_FED        : DB2_FED_CFG_DB2_FED_Field := 16#0#;
      --  unspecified
      Reserved_16_31 : ESP32S3_Registers.UInt16 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DB2_FED_CFG_Register use record
      DB2_FED        at 0 range 0 .. 15;
      Reserved_16_31 at 0 range 16 .. 31;
   end record;

   subtype DB2_RED_CFG_DB2_RED_Field is ESP32S3_Registers.UInt16;

   --  Shadow register for rising edge delay (RED).
   type DB2_RED_CFG_Register is record
      --  Shadow register for RED
      DB2_RED        : DB2_RED_CFG_DB2_RED_Field := 16#0#;
      --  unspecified
      Reserved_16_31 : ESP32S3_Registers.UInt16 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DB2_RED_CFG_Register use record
      DB2_RED        at 0 range 0 .. 15;
      Reserved_16_31 at 0 range 16 .. 31;
   end record;

   subtype CHOPPER2_CFG_CHOPPER2_PRESCALE_Field is ESP32S3_Registers.UInt4;
   subtype CHOPPER2_CFG_CHOPPER2_DUTY_Field is ESP32S3_Registers.UInt3;
   subtype CHOPPER2_CFG_CHOPPER2_OSHTWTH_Field is ESP32S3_Registers.UInt4;

   --  Carrier enable and configuratoin
   type CHOPPER2_CFG_Register is record
      --  When set, carrier0 function is enabled. When cleared, carrier0 is
      --  bypassed
      CHOPPER2_EN         : Boolean := False;
      --  PWM carrier0 clock (PC_clk) prescale value. Period of PC_clk = period
      --  of PWM_clk * (PWM_CARRIER0_PRESCALE + 1)
      CHOPPER2_PRESCALE   : CHOPPER2_CFG_CHOPPER2_PRESCALE_Field := 16#0#;
      --  carrier duty selection. Duty = PWM_CARRIER0_DUTY / 8
      CHOPPER2_DUTY       : CHOPPER2_CFG_CHOPPER2_DUTY_Field := 16#0#;
      --  width of the fist pulse in number of periods of the carrier
      CHOPPER2_OSHTWTH    : CHOPPER2_CFG_CHOPPER2_OSHTWTH_Field := 16#0#;
      --  when set, invert the output of PWM2A and PWM2B for this submodule
      CHOPPER2_OUT_INVERT : Boolean := False;
      --  when set, invert the input of PWM2A and PWM2B for this submodule
      CHOPPER2_IN_INVERT  : Boolean := False;
      --  unspecified
      Reserved_14_31      : ESP32S3_Registers.UInt18 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CHOPPER2_CFG_Register use record
      CHOPPER2_EN         at 0 range 0 .. 0;
      CHOPPER2_PRESCALE   at 0 range 1 .. 4;
      CHOPPER2_DUTY       at 0 range 5 .. 7;
      CHOPPER2_OSHTWTH    at 0 range 8 .. 11;
      CHOPPER2_OUT_INVERT at 0 range 12 .. 12;
      CHOPPER2_IN_INVERT  at 0 range 13 .. 13;
      Reserved_14_31      at 0 range 14 .. 31;
   end record;

   subtype TZ2_CFG0_TZ2_A_CBC_D_Field is ESP32S3_Registers.UInt2;
   subtype TZ2_CFG0_TZ2_A_CBC_U_Field is ESP32S3_Registers.UInt2;
   subtype TZ2_CFG0_TZ2_A_OST_D_Field is ESP32S3_Registers.UInt2;
   subtype TZ2_CFG0_TZ2_A_OST_U_Field is ESP32S3_Registers.UInt2;
   subtype TZ2_CFG0_TZ2_B_CBC_D_Field is ESP32S3_Registers.UInt2;
   subtype TZ2_CFG0_TZ2_B_CBC_U_Field is ESP32S3_Registers.UInt2;
   subtype TZ2_CFG0_TZ2_B_OST_D_Field is ESP32S3_Registers.UInt2;
   subtype TZ2_CFG0_TZ2_B_OST_U_Field is ESP32S3_Registers.UInt2;

   --  Actions on PWM2A and PWM2B trip events
   type TZ2_CFG0_Register is record
      --  Enable register for software force cycle-by-cycle mode action. 0:
      --  disable, 1: enable
      TZ2_SW_CBC     : Boolean := False;
      --  event_f2 will trigger cycle-by-cycle mode action. 0: disable, 1:
      --  enable
      TZ2_F2_CBC     : Boolean := False;
      --  event_f1 will trigger cycle-by-cycle mode action. 0: disable, 1:
      --  enable
      TZ2_F1_CBC     : Boolean := False;
      --  event_f0 will trigger cycle-by-cycle mode action. 0: disable, 1:
      --  enable
      TZ2_F0_CBC     : Boolean := False;
      --  Enable register for software force one-shot mode action. 0: disable,
      --  1: enable
      TZ2_SW_OST     : Boolean := False;
      --  event_f2 will trigger one-shot mode action. 0: disable, 1: enable
      TZ2_F2_OST     : Boolean := False;
      --  event_f1 will trigger one-shot mode action. 0: disable, 1: enable
      TZ2_F1_OST     : Boolean := False;
      --  event_f0 will trigger one-shot mode action. 0: disable, 1: enable
      TZ2_F0_OST     : Boolean := False;
      --  Cycle-by-cycle mode action on PWM2A when fault event occurs and timer
      --  is decreasing. 0: do nothing, 1: force lo, 2: force hi, 3: toggle
      TZ2_A_CBC_D    : TZ2_CFG0_TZ2_A_CBC_D_Field := 16#0#;
      --  Cycle-by-cycle mode action on PWM2A when fault event occurs and timer
      --  is increasing. 0: do nothing, 1: force lo, 2: force hi, 3: toggle
      TZ2_A_CBC_U    : TZ2_CFG0_TZ2_A_CBC_U_Field := 16#0#;
      --  One-shot mode action on PWM2A when fault event occurs and timer is
      --  decreasing. 0: do nothing, 1: force lo, 2: force hi, 3: toggle
      TZ2_A_OST_D    : TZ2_CFG0_TZ2_A_OST_D_Field := 16#0#;
      --  One-shot mode action on PWM2A when fault event occurs and timer is
      --  increasing. 0: do nothing, 1: force lo, 2: force hi, 3: toggle
      TZ2_A_OST_U    : TZ2_CFG0_TZ2_A_OST_U_Field := 16#0#;
      --  Cycle-by-cycle mode action on PWM2B when fault event occurs and timer
      --  is decreasing. 0: do nothing, 1: force lo, 2: force hi, 3: toggle
      TZ2_B_CBC_D    : TZ2_CFG0_TZ2_B_CBC_D_Field := 16#0#;
      --  Cycle-by-cycle mode action on PWM2B when fault event occurs and timer
      --  is increasing. 0: do nothing, 1: force lo, 2: force hi, 3: toggle
      TZ2_B_CBC_U    : TZ2_CFG0_TZ2_B_CBC_U_Field := 16#0#;
      --  One-shot mode action on PWM2B when fault event occurs and timer is
      --  decreasing. 0: do nothing, 1: force lo, 2: force hi, 3: toggle
      TZ2_B_OST_D    : TZ2_CFG0_TZ2_B_OST_D_Field := 16#0#;
      --  One-shot mode action on PWM2B when fault event occurs and timer is
      --  increasing. 0: do nothing, 1: force lo, 2: force hi, 3: toggle
      TZ2_B_OST_U    : TZ2_CFG0_TZ2_B_OST_U_Field := 16#0#;
      --  unspecified
      Reserved_24_31 : ESP32S3_Registers.Byte := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for TZ2_CFG0_Register use record
      TZ2_SW_CBC     at 0 range 0 .. 0;
      TZ2_F2_CBC     at 0 range 1 .. 1;
      TZ2_F1_CBC     at 0 range 2 .. 2;
      TZ2_F0_CBC     at 0 range 3 .. 3;
      TZ2_SW_OST     at 0 range 4 .. 4;
      TZ2_F2_OST     at 0 range 5 .. 5;
      TZ2_F1_OST     at 0 range 6 .. 6;
      TZ2_F0_OST     at 0 range 7 .. 7;
      TZ2_A_CBC_D    at 0 range 8 .. 9;
      TZ2_A_CBC_U    at 0 range 10 .. 11;
      TZ2_A_OST_D    at 0 range 12 .. 13;
      TZ2_A_OST_U    at 0 range 14 .. 15;
      TZ2_B_CBC_D    at 0 range 16 .. 17;
      TZ2_B_CBC_U    at 0 range 18 .. 19;
      TZ2_B_OST_D    at 0 range 20 .. 21;
      TZ2_B_OST_U    at 0 range 22 .. 23;
      Reserved_24_31 at 0 range 24 .. 31;
   end record;

   subtype TZ2_CFG1_TZ2_CBCPULSE_Field is ESP32S3_Registers.UInt2;

   --  Software triggers for fault handler actions
   type TZ2_CFG1_Register is record
      --  a rising edge will clear on going one-shot mode action
      TZ2_CLR_OST   : Boolean := False;
      --  cycle-by-cycle mode action refresh moment selection. Bit0: TEZ,
      --  bit1:TEP
      TZ2_CBCPULSE  : TZ2_CFG1_TZ2_CBCPULSE_Field := 16#0#;
      --  a toggle trigger a cycle-by-cycle mode action
      TZ2_FORCE_CBC : Boolean := False;
      --  a toggle (software negate its value) triggers a one-shot mode action
      TZ2_FORCE_OST : Boolean := False;
      --  unspecified
      Reserved_5_31 : ESP32S3_Registers.UInt27 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for TZ2_CFG1_Register use record
      TZ2_CLR_OST   at 0 range 0 .. 0;
      TZ2_CBCPULSE  at 0 range 1 .. 2;
      TZ2_FORCE_CBC at 0 range 3 .. 3;
      TZ2_FORCE_OST at 0 range 4 .. 4;
      Reserved_5_31 at 0 range 5 .. 31;
   end record;

   --  Status of fault events.
   type TZ2_STATUS_Register is record
      --  Read-only. Set and reset by hardware. If set, a cycle-by-cycle mode
      --  action is on going
      TZ2_CBC_ON    : Boolean;
      --  Read-only. Set and reset by hardware. If set, an one-shot mode action
      --  is on going
      TZ2_OST_ON    : Boolean;
      --  unspecified
      Reserved_2_31 : ESP32S3_Registers.UInt30;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for TZ2_STATUS_Register use record
      TZ2_CBC_ON    at 0 range 0 .. 0;
      TZ2_OST_ON    at 0 range 1 .. 1;
      Reserved_2_31 at 0 range 2 .. 31;
   end record;

   --  FAULT_DETECT_EVENT_F array
   type FAULT_DETECT_EVENT_F_Field_Array is array (0 .. 2) of Boolean
     with Component_Size => 1, Size => 3;

   --  Type definition for FAULT_DETECT_EVENT_F
   type FAULT_DETECT_EVENT_F_Field
     (As_Array : Boolean := False)
   is record
      case As_Array is
         when False =>
            --  EVENT_F as a value
            Val : ESP32S3_Registers.UInt3;
         when True =>
            --  EVENT_F as an array
            Arr : FAULT_DETECT_EVENT_F_Field_Array;
      end case;
   end record
     with Unchecked_Union, Size => 3;

   for FAULT_DETECT_EVENT_F_Field use record
      Val at 0 range 0 .. 2;
      Arr at 0 range 0 .. 2;
   end record;

   --  Fault detection configuration and status
   type FAULT_DETECT_Register is record
      --  When set, event_f0 generation is enabled
      F0_EN         : Boolean := False;
      --  When set, event_f1 generation is enabled
      F1_EN         : Boolean := False;
      --  When set, event_f2 generation is enabled
      F2_EN         : Boolean := False;
      --  Set event_f0 trigger polarity on FAULT2 source from GPIO matrix. 0:
      --  level low, 1: level high
      F0_POLE       : Boolean := False;
      --  Set event_f1 trigger polarity on FAULT2 source from GPIO matrix. 0:
      --  level low, 1: level high
      F1_POLE       : Boolean := False;
      --  Set event_f2 trigger polarity on FAULT2 source from GPIO matrix. 0:
      --  level low, 1: level high
      F2_POLE       : Boolean := False;
      --  Read-only. Set and reset by hardware. If set, event_f0 is on going
      EVENT_F       : FAULT_DETECT_EVENT_F_Field :=
                       (As_Array => False, Val => 16#0#);
      --  unspecified
      Reserved_9_31 : ESP32S3_Registers.UInt23 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for FAULT_DETECT_Register use record
      F0_EN         at 0 range 0 .. 0;
      F1_EN         at 0 range 1 .. 1;
      F2_EN         at 0 range 2 .. 2;
      F0_POLE       at 0 range 3 .. 3;
      F1_POLE       at 0 range 4 .. 4;
      F2_POLE       at 0 range 5 .. 5;
      EVENT_F       at 0 range 6 .. 8;
      Reserved_9_31 at 0 range 9 .. 31;
   end record;

   subtype CAP_TIMER_CFG_CAP_SYNCI_SEL_Field is ESP32S3_Registers.UInt3;

   --  Configure capture timer
   type CAP_TIMER_CFG_Register is record
      --  When set, capture timer incrementing under APB_clk is enabled.
      CAP_TIMER_EN  : Boolean := False;
      --  When set, capture timer sync is enabled.
      CAP_SYNCI_EN  : Boolean := False;
      --  capture module sync input selection. 0: none, 1: timer0 sync_out, 2:
      --  timer1 sync_out, 3: timer2 sync_out, 4: SYNC0 from GPIO matrix, 5:
      --  SYNC1 from GPIO matrix, 6: SYNC2 from GPIO matrix
      CAP_SYNCI_SEL : CAP_TIMER_CFG_CAP_SYNCI_SEL_Field := 16#0#;
      --  Write-only. Write 1 will force a capture timer sync, capture timer is
      --  loaded with value in phase register.
      CAP_SYNC_SW   : Boolean := False;
      --  unspecified
      Reserved_6_31 : ESP32S3_Registers.UInt26 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CAP_TIMER_CFG_Register use record
      CAP_TIMER_EN  at 0 range 0 .. 0;
      CAP_SYNCI_EN  at 0 range 1 .. 1;
      CAP_SYNCI_SEL at 0 range 2 .. 4;
      CAP_SYNC_SW   at 0 range 5 .. 5;
      Reserved_6_31 at 0 range 6 .. 31;
   end record;

   subtype CAP_CH0_CFG_CAP0_MODE_Field is ESP32S3_Registers.UInt2;
   subtype CAP_CH0_CFG_CAP0_PRESCALE_Field is ESP32S3_Registers.Byte;

   --  Capture channel 0 configuration and enable
   type CAP_CH0_CFG_Register is record
      --  When set, capture on channel 0 is enabled
      CAP0_EN        : Boolean := False;
      --  Edge of capture on channel 0 after prescaling. When bit0 is set to 1:
      --  enable capture on the negative edge, When bit1 is set to 1: enable
      --  capture on the positive edge.
      CAP0_MODE      : CAP_CH0_CFG_CAP0_MODE_Field := 16#0#;
      --  Value of prescaling on possitive edge of CAP0. Prescale value =
      --  PWM_CAP0_PRESCALE + 1
      CAP0_PRESCALE  : CAP_CH0_CFG_CAP0_PRESCALE_Field := 16#0#;
      --  when set, CAP0 form GPIO matrix is inverted before prescale
      CAP0_IN_INVERT : Boolean := False;
      --  Write-only. Write 1 will trigger a software forced capture on channel
      --  0
      CAP0_SW        : Boolean := False;
      --  unspecified
      Reserved_13_31 : ESP32S3_Registers.UInt19 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CAP_CH0_CFG_Register use record
      CAP0_EN        at 0 range 0 .. 0;
      CAP0_MODE      at 0 range 1 .. 2;
      CAP0_PRESCALE  at 0 range 3 .. 10;
      CAP0_IN_INVERT at 0 range 11 .. 11;
      CAP0_SW        at 0 range 12 .. 12;
      Reserved_13_31 at 0 range 13 .. 31;
   end record;

   subtype CAP_CH1_CFG_CAP1_MODE_Field is ESP32S3_Registers.UInt2;
   subtype CAP_CH1_CFG_CAP1_PRESCALE_Field is ESP32S3_Registers.Byte;

   --  Capture channel 1 configuration and enable
   type CAP_CH1_CFG_Register is record
      --  When set, capture on channel 2 is enabled
      CAP1_EN        : Boolean := False;
      --  Edge of capture on channel 1 after prescaling. When bit0 is set to 1:
      --  enable capture on the negative edge, When bit1 is set to 1: enable
      --  capture on the positive edge.
      CAP1_MODE      : CAP_CH1_CFG_CAP1_MODE_Field := 16#0#;
      --  Value of prescaling on possitive edge of CAP1. Prescale value =
      --  PWM_CAP1_PRESCALE + 1
      CAP1_PRESCALE  : CAP_CH1_CFG_CAP1_PRESCALE_Field := 16#0#;
      --  when set, CAP1 form GPIO matrix is inverted before prescale
      CAP1_IN_INVERT : Boolean := False;
      --  Write-only. Write 1 will trigger a software forced capture on channel
      --  1
      CAP1_SW        : Boolean := False;
      --  unspecified
      Reserved_13_31 : ESP32S3_Registers.UInt19 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CAP_CH1_CFG_Register use record
      CAP1_EN        at 0 range 0 .. 0;
      CAP1_MODE      at 0 range 1 .. 2;
      CAP1_PRESCALE  at 0 range 3 .. 10;
      CAP1_IN_INVERT at 0 range 11 .. 11;
      CAP1_SW        at 0 range 12 .. 12;
      Reserved_13_31 at 0 range 13 .. 31;
   end record;

   subtype CAP_CH2_CFG_CAP2_MODE_Field is ESP32S3_Registers.UInt2;
   subtype CAP_CH2_CFG_CAP2_PRESCALE_Field is ESP32S3_Registers.Byte;

   --  Capture channel 2 configuration and enable
   type CAP_CH2_CFG_Register is record
      --  When set, capture on channel 2 is enabled
      CAP2_EN        : Boolean := False;
      --  Edge of capture on channel 2 after prescaling. When bit0 is set to 1:
      --  enable capture on the negative edge, When bit1 is set to 1: enable
      --  capture on the positive edge.
      CAP2_MODE      : CAP_CH2_CFG_CAP2_MODE_Field := 16#0#;
      --  Value of prescaling on possitive edge of CAP2. Prescale value =
      --  PWM_CAP2_PRESCALE + 1
      CAP2_PRESCALE  : CAP_CH2_CFG_CAP2_PRESCALE_Field := 16#0#;
      --  when set, CAP2 form GPIO matrix is inverted before prescale
      CAP2_IN_INVERT : Boolean := False;
      --  Write-only. Write 1 will trigger a software forced capture on channel
      --  2
      CAP2_SW        : Boolean := False;
      --  unspecified
      Reserved_13_31 : ESP32S3_Registers.UInt19 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CAP_CH2_CFG_Register use record
      CAP2_EN        at 0 range 0 .. 0;
      CAP2_MODE      at 0 range 1 .. 2;
      CAP2_PRESCALE  at 0 range 3 .. 10;
      CAP2_IN_INVERT at 0 range 11 .. 11;
      CAP2_SW        at 0 range 12 .. 12;
      Reserved_13_31 at 0 range 13 .. 31;
   end record;

   --  Edge of last capture trigger
   type CAP_STATUS_Register is record
      --  Read-only. Edge of last capture trigger on channel 0, 0: posedge, 1:
      --  negedge
      CAP0_EDGE     : Boolean;
      --  Read-only. Edge of last capture trigger on channel 1, 0: posedge, 1:
      --  negedge
      CAP1_EDGE     : Boolean;
      --  Read-only. Edge of last capture trigger on channel 2, 0: posedge, 1:
      --  negedge
      CAP2_EDGE     : Boolean;
      --  unspecified
      Reserved_3_31 : ESP32S3_Registers.UInt29;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CAP_STATUS_Register use record
      CAP0_EDGE     at 0 range 0 .. 0;
      CAP1_EDGE     at 0 range 1 .. 1;
      CAP2_EDGE     at 0 range 2 .. 2;
      Reserved_3_31 at 0 range 3 .. 31;
   end record;

   --  Enable update.
   type UPDATE_CFG_Register is record
      --  The global enable of update of all active registers in MCPWM module
      GLOBAL_UP_EN    : Boolean := True;
      --  a toggle (software invert its value) will trigger a forced update of
      --  all active registers in MCPWM module
      GLOBAL_FORCE_UP : Boolean := False;
      --  When set and PWM_GLOBAL_UP_EN is set, update of active registers in
      --  PWM operator 0 are enabled
      OP0_UP_EN       : Boolean := True;
      --  a toggle (software invert its value) will trigger a forced update of
      --  active registers in PWM operator 0
      OP0_FORCE_UP    : Boolean := False;
      --  When set and PWM_GLOBAL_UP_EN is set, update of active registers in
      --  PWM operator 1 are enabled
      OP1_UP_EN       : Boolean := True;
      --  a toggle (software invert its value) will trigger a forced update of
      --  active registers in PWM operator 1
      OP1_FORCE_UP    : Boolean := False;
      --  When set and PWM_GLOBAL_UP_EN is set, update of active registers in
      --  PWM operator 2 are enabled
      OP2_UP_EN       : Boolean := True;
      --  a toggle (software invert its value) will trigger a forced update of
      --  active registers in PWM operator 2
      OP2_FORCE_UP    : Boolean := False;
      --  unspecified
      Reserved_8_31   : ESP32S3_Registers.UInt24 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for UPDATE_CFG_Register use record
      GLOBAL_UP_EN    at 0 range 0 .. 0;
      GLOBAL_FORCE_UP at 0 range 1 .. 1;
      OP0_UP_EN       at 0 range 2 .. 2;
      OP0_FORCE_UP    at 0 range 3 .. 3;
      OP1_UP_EN       at 0 range 4 .. 4;
      OP1_FORCE_UP    at 0 range 5 .. 5;
      OP2_UP_EN       at 0 range 6 .. 6;
      OP2_FORCE_UP    at 0 range 7 .. 7;
      Reserved_8_31   at 0 range 8 .. 31;
   end record;

   --  Interrupt enable bits
   type INT_ENA_Register is record
      --  The enable bit for the interrupt triggered when the timer 0 stops.
      TIMER0_STOP_INT_ENA : Boolean := False;
      --  The enable bit for the interrupt triggered when the timer 1 stops.
      TIMER1_STOP_INT_ENA : Boolean := False;
      --  The enable bit for the interrupt triggered when the timer 2 stops.
      TIMER2_STOP_INT_ENA : Boolean := False;
      --  The enable bit for the interrupt triggered by a PWM timer 0 TEZ
      --  event.
      TIMER0_TEZ_INT_ENA  : Boolean := False;
      --  The enable bit for the interrupt triggered by a PWM timer 1 TEZ
      --  event.
      TIMER1_TEZ_INT_ENA  : Boolean := False;
      --  The enable bit for the interrupt triggered by a PWM timer 2 TEZ
      --  event.
      TIMER2_TEZ_INT_ENA  : Boolean := False;
      --  The enable bit for the interrupt triggered by a PWM timer 0 TEP
      --  event.
      TIMER0_TEP_INT_ENA  : Boolean := False;
      --  The enable bit for the interrupt triggered by a PWM timer 1 TEP
      --  event.
      TIMER1_TEP_INT_ENA  : Boolean := False;
      --  The enable bit for the interrupt triggered by a PWM timer 2 TEP
      --  event.
      TIMER2_TEP_INT_ENA  : Boolean := False;
      --  The enable bit for the interrupt triggered when event_f0 starts.
      FAULT0_INT_ENA      : Boolean := False;
      --  The enable bit for the interrupt triggered when event_f1 starts.
      FAULT1_INT_ENA      : Boolean := False;
      --  The enable bit for the interrupt triggered when event_f2 starts.
      FAULT2_INT_ENA      : Boolean := False;
      --  The enable bit for the interrupt triggered when event_f0 ends.
      FAULT0_CLR_INT_ENA  : Boolean := False;
      --  The enable bit for the interrupt triggered when event_f1 ends.
      FAULT1_CLR_INT_ENA  : Boolean := False;
      --  The enable bit for the interrupt triggered when event_f2 ends.
      FAULT2_CLR_INT_ENA  : Boolean := False;
      --  The enable bit for the interrupt triggered by a PWM operator 0 TEA
      --  event
      CMPR0_TEA_INT_ENA   : Boolean := False;
      --  The enable bit for the interrupt triggered by a PWM operator 1 TEA
      --  event
      CMPR1_TEA_INT_ENA   : Boolean := False;
      --  The enable bit for the interrupt triggered by a PWM operator 2 TEA
      --  event
      CMPR2_TEA_INT_ENA   : Boolean := False;
      --  The enable bit for the interrupt triggered by a PWM operator 0 TEB
      --  event
      CMPR0_TEB_INT_ENA   : Boolean := False;
      --  The enable bit for the interrupt triggered by a PWM operator 1 TEB
      --  event
      CMPR1_TEB_INT_ENA   : Boolean := False;
      --  The enable bit for the interrupt triggered by a PWM operator 2 TEB
      --  event
      CMPR2_TEB_INT_ENA   : Boolean := False;
      --  The enable bit for the interrupt triggered by a cycle-by-cycle mode
      --  action on PWM0.
      TZ0_CBC_INT_ENA     : Boolean := False;
      --  The enable bit for the interrupt triggered by a cycle-by-cycle mode
      --  action on PWM1.
      TZ1_CBC_INT_ENA     : Boolean := False;
      --  The enable bit for the interrupt triggered by a cycle-by-cycle mode
      --  action on PWM2.
      TZ2_CBC_INT_ENA     : Boolean := False;
      --  The enable bit for the interrupt triggered by a one-shot mode action
      --  on PWM0.
      TZ0_OST_INT_ENA     : Boolean := False;
      --  The enable bit for the interrupt triggered by a one-shot mode action
      --  on PWM1.
      TZ1_OST_INT_ENA     : Boolean := False;
      --  The enable bit for the interrupt triggered by a one-shot mode action
      --  on PWM2.
      TZ2_OST_INT_ENA     : Boolean := False;
      --  The enable bit for the interrupt triggered by capture on channel 0.
      CAP0_INT_ENA        : Boolean := False;
      --  The enable bit for the interrupt triggered by capture on channel 1.
      CAP1_INT_ENA        : Boolean := False;
      --  The enable bit for the interrupt triggered by capture on channel 2.
      CAP2_INT_ENA        : Boolean := False;
      --  unspecified
      Reserved_30_31      : ESP32S3_Registers.UInt2 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for INT_ENA_Register use record
      TIMER0_STOP_INT_ENA at 0 range 0 .. 0;
      TIMER1_STOP_INT_ENA at 0 range 1 .. 1;
      TIMER2_STOP_INT_ENA at 0 range 2 .. 2;
      TIMER0_TEZ_INT_ENA  at 0 range 3 .. 3;
      TIMER1_TEZ_INT_ENA  at 0 range 4 .. 4;
      TIMER2_TEZ_INT_ENA  at 0 range 5 .. 5;
      TIMER0_TEP_INT_ENA  at 0 range 6 .. 6;
      TIMER1_TEP_INT_ENA  at 0 range 7 .. 7;
      TIMER2_TEP_INT_ENA  at 0 range 8 .. 8;
      FAULT0_INT_ENA      at 0 range 9 .. 9;
      FAULT1_INT_ENA      at 0 range 10 .. 10;
      FAULT2_INT_ENA      at 0 range 11 .. 11;
      FAULT0_CLR_INT_ENA  at 0 range 12 .. 12;
      FAULT1_CLR_INT_ENA  at 0 range 13 .. 13;
      FAULT2_CLR_INT_ENA  at 0 range 14 .. 14;
      CMPR0_TEA_INT_ENA   at 0 range 15 .. 15;
      CMPR1_TEA_INT_ENA   at 0 range 16 .. 16;
      CMPR2_TEA_INT_ENA   at 0 range 17 .. 17;
      CMPR0_TEB_INT_ENA   at 0 range 18 .. 18;
      CMPR1_TEB_INT_ENA   at 0 range 19 .. 19;
      CMPR2_TEB_INT_ENA   at 0 range 20 .. 20;
      TZ0_CBC_INT_ENA     at 0 range 21 .. 21;
      TZ1_CBC_INT_ENA     at 0 range 22 .. 22;
      TZ2_CBC_INT_ENA     at 0 range 23 .. 23;
      TZ0_OST_INT_ENA     at 0 range 24 .. 24;
      TZ1_OST_INT_ENA     at 0 range 25 .. 25;
      TZ2_OST_INT_ENA     at 0 range 26 .. 26;
      CAP0_INT_ENA        at 0 range 27 .. 27;
      CAP1_INT_ENA        at 0 range 28 .. 28;
      CAP2_INT_ENA        at 0 range 29 .. 29;
      Reserved_30_31      at 0 range 30 .. 31;
   end record;

   --  Raw interrupt status
   type INT_RAW_Register is record
      --  The raw status bit for the interrupt triggered when the timer 0
      --  stops.
      TIMER0_STOP_INT_RAW : Boolean := False;
      --  The raw status bit for the interrupt triggered when the timer 1
      --  stops.
      TIMER1_STOP_INT_RAW : Boolean := False;
      --  The raw status bit for the interrupt triggered when the timer 2
      --  stops.
      TIMER2_STOP_INT_RAW : Boolean := False;
      --  The raw status bit for the interrupt triggered by a PWM timer 0 TEZ
      --  event.
      TIMER0_TEZ_INT_RAW  : Boolean := False;
      --  The raw status bit for the interrupt triggered by a PWM timer 1 TEZ
      --  event.
      TIMER1_TEZ_INT_RAW  : Boolean := False;
      --  The raw status bit for the interrupt triggered by a PWM timer 2 TEZ
      --  event.
      TIMER2_TEZ_INT_RAW  : Boolean := False;
      --  The raw status bit for the interrupt triggered by a PWM timer 0 TEP
      --  event.
      TIMER0_TEP_INT_RAW  : Boolean := False;
      --  The raw status bit for the interrupt triggered by a PWM timer 1 TEP
      --  event.
      TIMER1_TEP_INT_RAW  : Boolean := False;
      --  The raw status bit for the interrupt triggered by a PWM timer 2 TEP
      --  event.
      TIMER2_TEP_INT_RAW  : Boolean := False;
      --  The raw status bit for the interrupt triggered when event_f0 starts.
      FAULT0_INT_RAW      : Boolean := False;
      --  The raw status bit for the interrupt triggered when event_f1 starts.
      FAULT1_INT_RAW      : Boolean := False;
      --  The raw status bit for the interrupt triggered when event_f2 starts.
      FAULT2_INT_RAW      : Boolean := False;
      --  The raw status bit for the interrupt triggered when event_f0 ends.
      FAULT0_CLR_INT_RAW  : Boolean := False;
      --  The raw status bit for the interrupt triggered when event_f1 ends.
      FAULT1_CLR_INT_RAW  : Boolean := False;
      --  The raw status bit for the interrupt triggered when event_f2 ends.
      FAULT2_CLR_INT_RAW  : Boolean := False;
      --  The raw status bit for the interrupt triggered by a PWM operator 0
      --  TEA event
      CMPR0_TEA_INT_RAW   : Boolean := False;
      --  The raw status bit for the interrupt triggered by a PWM operator 1
      --  TEA event
      CMPR1_TEA_INT_RAW   : Boolean := False;
      --  The raw status bit for the interrupt triggered by a PWM operator 2
      --  TEA event
      CMPR2_TEA_INT_RAW   : Boolean := False;
      --  The raw status bit for the interrupt triggered by a PWM operator 0
      --  TEB event
      CMPR0_TEB_INT_RAW   : Boolean := False;
      --  The raw status bit for the interrupt triggered by a PWM operator 1
      --  TEB event
      CMPR1_TEB_INT_RAW   : Boolean := False;
      --  The raw status bit for the interrupt triggered by a PWM operator 2
      --  TEB event
      CMPR2_TEB_INT_RAW   : Boolean := False;
      --  The raw status bit for the interrupt triggered by a cycle-by-cycle
      --  mode action on PWM0.
      TZ0_CBC_INT_RAW     : Boolean := False;
      --  The raw status bit for the interrupt triggered by a cycle-by-cycle
      --  mode action on PWM1.
      TZ1_CBC_INT_RAW     : Boolean := False;
      --  The raw status bit for the interrupt triggered by a cycle-by-cycle
      --  mode action on PWM2.
      TZ2_CBC_INT_RAW     : Boolean := False;
      --  The raw status bit for the interrupt triggered by a one-shot mode
      --  action on PWM0.
      TZ0_OST_INT_RAW     : Boolean := False;
      --  The raw status bit for the interrupt triggered by a one-shot mode
      --  action on PWM1.
      TZ1_OST_INT_RAW     : Boolean := False;
      --  The raw status bit for the interrupt triggered by a one-shot mode
      --  action on PWM2.
      TZ2_OST_INT_RAW     : Boolean := False;
      --  The raw status bit for the interrupt triggered by capture on channel
      --  0.
      CAP0_INT_RAW        : Boolean := False;
      --  The raw status bit for the interrupt triggered by capture on channel
      --  1.
      CAP1_INT_RAW        : Boolean := False;
      --  The raw status bit for the interrupt triggered by capture on channel
      --  2.
      CAP2_INT_RAW        : Boolean := False;
      --  unspecified
      Reserved_30_31      : ESP32S3_Registers.UInt2 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for INT_RAW_Register use record
      TIMER0_STOP_INT_RAW at 0 range 0 .. 0;
      TIMER1_STOP_INT_RAW at 0 range 1 .. 1;
      TIMER2_STOP_INT_RAW at 0 range 2 .. 2;
      TIMER0_TEZ_INT_RAW  at 0 range 3 .. 3;
      TIMER1_TEZ_INT_RAW  at 0 range 4 .. 4;
      TIMER2_TEZ_INT_RAW  at 0 range 5 .. 5;
      TIMER0_TEP_INT_RAW  at 0 range 6 .. 6;
      TIMER1_TEP_INT_RAW  at 0 range 7 .. 7;
      TIMER2_TEP_INT_RAW  at 0 range 8 .. 8;
      FAULT0_INT_RAW      at 0 range 9 .. 9;
      FAULT1_INT_RAW      at 0 range 10 .. 10;
      FAULT2_INT_RAW      at 0 range 11 .. 11;
      FAULT0_CLR_INT_RAW  at 0 range 12 .. 12;
      FAULT1_CLR_INT_RAW  at 0 range 13 .. 13;
      FAULT2_CLR_INT_RAW  at 0 range 14 .. 14;
      CMPR0_TEA_INT_RAW   at 0 range 15 .. 15;
      CMPR1_TEA_INT_RAW   at 0 range 16 .. 16;
      CMPR2_TEA_INT_RAW   at 0 range 17 .. 17;
      CMPR0_TEB_INT_RAW   at 0 range 18 .. 18;
      CMPR1_TEB_INT_RAW   at 0 range 19 .. 19;
      CMPR2_TEB_INT_RAW   at 0 range 20 .. 20;
      TZ0_CBC_INT_RAW     at 0 range 21 .. 21;
      TZ1_CBC_INT_RAW     at 0 range 22 .. 22;
      TZ2_CBC_INT_RAW     at 0 range 23 .. 23;
      TZ0_OST_INT_RAW     at 0 range 24 .. 24;
      TZ1_OST_INT_RAW     at 0 range 25 .. 25;
      TZ2_OST_INT_RAW     at 0 range 26 .. 26;
      CAP0_INT_RAW        at 0 range 27 .. 27;
      CAP1_INT_RAW        at 0 range 28 .. 28;
      CAP2_INT_RAW        at 0 range 29 .. 29;
      Reserved_30_31      at 0 range 30 .. 31;
   end record;

   --  Masked interrupt status
   type INT_ST_Register is record
      --  Read-only. The masked status bit for the interrupt triggered when the
      --  timer 0 stops.
      TIMER0_STOP_INT_ST : Boolean;
      --  Read-only. The masked status bit for the interrupt triggered when the
      --  timer 1 stops.
      TIMER1_STOP_INT_ST : Boolean;
      --  Read-only. The masked status bit for the interrupt triggered when the
      --  timer 2 stops.
      TIMER2_STOP_INT_ST : Boolean;
      --  Read-only. The masked status bit for the interrupt triggered by a PWM
      --  timer 0 TEZ event.
      TIMER0_TEZ_INT_ST  : Boolean;
      --  Read-only. The masked status bit for the interrupt triggered by a PWM
      --  timer 1 TEZ event.
      TIMER1_TEZ_INT_ST  : Boolean;
      --  Read-only. The masked status bit for the interrupt triggered by a PWM
      --  timer 2 TEZ event.
      TIMER2_TEZ_INT_ST  : Boolean;
      --  Read-only. The masked status bit for the interrupt triggered by a PWM
      --  timer 0 TEP event.
      TIMER0_TEP_INT_ST  : Boolean;
      --  Read-only. The masked status bit for the interrupt triggered by a PWM
      --  timer 1 TEP event.
      TIMER1_TEP_INT_ST  : Boolean;
      --  Read-only. The masked status bit for the interrupt triggered by a PWM
      --  timer 2 TEP event.
      TIMER2_TEP_INT_ST  : Boolean;
      --  Read-only. The masked status bit for the interrupt triggered when
      --  event_f0 starts.
      FAULT0_INT_ST      : Boolean;
      --  Read-only. The masked status bit for the interrupt triggered when
      --  event_f1 starts.
      FAULT1_INT_ST      : Boolean;
      --  Read-only. The masked status bit for the interrupt triggered when
      --  event_f2 starts.
      FAULT2_INT_ST      : Boolean;
      --  Read-only. The masked status bit for the interrupt triggered when
      --  event_f0 ends.
      FAULT0_CLR_INT_ST  : Boolean;
      --  Read-only. The masked status bit for the interrupt triggered when
      --  event_f1 ends.
      FAULT1_CLR_INT_ST  : Boolean;
      --  Read-only. The masked status bit for the interrupt triggered when
      --  event_f2 ends.
      FAULT2_CLR_INT_ST  : Boolean;
      --  Read-only. The masked status bit for the interrupt triggered by a PWM
      --  operator 0 TEA event
      CMPR0_TEA_INT_ST   : Boolean;
      --  Read-only. The masked status bit for the interrupt triggered by a PWM
      --  operator 1 TEA event
      CMPR1_TEA_INT_ST   : Boolean;
      --  Read-only. The masked status bit for the interrupt triggered by a PWM
      --  operator 2 TEA event
      CMPR2_TEA_INT_ST   : Boolean;
      --  Read-only. The masked status bit for the interrupt triggered by a PWM
      --  operator 0 TEB event
      CMPR0_TEB_INT_ST   : Boolean;
      --  Read-only. The masked status bit for the interrupt triggered by a PWM
      --  operator 1 TEB event
      CMPR1_TEB_INT_ST   : Boolean;
      --  Read-only. The masked status bit for the interrupt triggered by a PWM
      --  operator 2 TEB event
      CMPR2_TEB_INT_ST   : Boolean;
      --  Read-only. The masked status bit for the interrupt triggered by a
      --  cycle-by-cycle mode action on PWM0.
      TZ0_CBC_INT_ST     : Boolean;
      --  Read-only. The masked status bit for the interrupt triggered by a
      --  cycle-by-cycle mode action on PWM1.
      TZ1_CBC_INT_ST     : Boolean;
      --  Read-only. The masked status bit for the interrupt triggered by a
      --  cycle-by-cycle mode action on PWM2.
      TZ2_CBC_INT_ST     : Boolean;
      --  Read-only. The masked status bit for the interrupt triggered by a
      --  one-shot mode action on PWM0.
      TZ0_OST_INT_ST     : Boolean;
      --  Read-only. The masked status bit for the interrupt triggered by a
      --  one-shot mode action on PWM1.
      TZ1_OST_INT_ST     : Boolean;
      --  Read-only. The masked status bit for the interrupt triggered by a
      --  one-shot mode action on PWM2.
      TZ2_OST_INT_ST     : Boolean;
      --  Read-only. The masked status bit for the interrupt triggered by
      --  capture on channel 0.
      CAP0_INT_ST        : Boolean;
      --  Read-only. The masked status bit for the interrupt triggered by
      --  capture on channel 1.
      CAP1_INT_ST        : Boolean;
      --  Read-only. The masked status bit for the interrupt triggered by
      --  capture on channel 2.
      CAP2_INT_ST        : Boolean;
      --  unspecified
      Reserved_30_31     : ESP32S3_Registers.UInt2;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for INT_ST_Register use record
      TIMER0_STOP_INT_ST at 0 range 0 .. 0;
      TIMER1_STOP_INT_ST at 0 range 1 .. 1;
      TIMER2_STOP_INT_ST at 0 range 2 .. 2;
      TIMER0_TEZ_INT_ST  at 0 range 3 .. 3;
      TIMER1_TEZ_INT_ST  at 0 range 4 .. 4;
      TIMER2_TEZ_INT_ST  at 0 range 5 .. 5;
      TIMER0_TEP_INT_ST  at 0 range 6 .. 6;
      TIMER1_TEP_INT_ST  at 0 range 7 .. 7;
      TIMER2_TEP_INT_ST  at 0 range 8 .. 8;
      FAULT0_INT_ST      at 0 range 9 .. 9;
      FAULT1_INT_ST      at 0 range 10 .. 10;
      FAULT2_INT_ST      at 0 range 11 .. 11;
      FAULT0_CLR_INT_ST  at 0 range 12 .. 12;
      FAULT1_CLR_INT_ST  at 0 range 13 .. 13;
      FAULT2_CLR_INT_ST  at 0 range 14 .. 14;
      CMPR0_TEA_INT_ST   at 0 range 15 .. 15;
      CMPR1_TEA_INT_ST   at 0 range 16 .. 16;
      CMPR2_TEA_INT_ST   at 0 range 17 .. 17;
      CMPR0_TEB_INT_ST   at 0 range 18 .. 18;
      CMPR1_TEB_INT_ST   at 0 range 19 .. 19;
      CMPR2_TEB_INT_ST   at 0 range 20 .. 20;
      TZ0_CBC_INT_ST     at 0 range 21 .. 21;
      TZ1_CBC_INT_ST     at 0 range 22 .. 22;
      TZ2_CBC_INT_ST     at 0 range 23 .. 23;
      TZ0_OST_INT_ST     at 0 range 24 .. 24;
      TZ1_OST_INT_ST     at 0 range 25 .. 25;
      TZ2_OST_INT_ST     at 0 range 26 .. 26;
      CAP0_INT_ST        at 0 range 27 .. 27;
      CAP1_INT_ST        at 0 range 28 .. 28;
      CAP2_INT_ST        at 0 range 29 .. 29;
      Reserved_30_31     at 0 range 30 .. 31;
   end record;

   --  Interrupt clear bits
   type INT_CLR_Register is record
      --  Write-only. Set this bit to clear the interrupt triggered when the
      --  timer 0 stops.
      TIMER0_STOP_INT_CLR : Boolean := False;
      --  Write-only. Set this bit to clear the interrupt triggered when the
      --  timer 1 stops.
      TIMER1_STOP_INT_CLR : Boolean := False;
      --  Write-only. Set this bit to clear the interrupt triggered when the
      --  timer 2 stops.
      TIMER2_STOP_INT_CLR : Boolean := False;
      --  Write-only. Set this bit to clear the interrupt triggered by a PWM
      --  timer 0 TEZ event.
      TIMER0_TEZ_INT_CLR  : Boolean := False;
      --  Write-only. Set this bit to clear the interrupt triggered by a PWM
      --  timer 1 TEZ event.
      TIMER1_TEZ_INT_CLR  : Boolean := False;
      --  Write-only. Set this bit to clear the interrupt triggered by a PWM
      --  timer 2 TEZ event.
      TIMER2_TEZ_INT_CLR  : Boolean := False;
      --  Write-only. Set this bit to clear the interrupt triggered by a PWM
      --  timer 0 TEP event.
      TIMER0_TEP_INT_CLR  : Boolean := False;
      --  Write-only. Set this bit to clear the interrupt triggered by a PWM
      --  timer 1 TEP event.
      TIMER1_TEP_INT_CLR  : Boolean := False;
      --  Write-only. Set this bit to clear the interrupt triggered by a PWM
      --  timer 2 TEP event.
      TIMER2_TEP_INT_CLR  : Boolean := False;
      --  Write-only. Set this bit to clear the interrupt triggered when
      --  event_f0 starts.
      FAULT0_INT_CLR      : Boolean := False;
      --  Write-only. Set this bit to clear the interrupt triggered when
      --  event_f1 starts.
      FAULT1_INT_CLR      : Boolean := False;
      --  Write-only. Set this bit to clear the interrupt triggered when
      --  event_f2 starts.
      FAULT2_INT_CLR      : Boolean := False;
      --  Write-only. Set this bit to clear the interrupt triggered when
      --  event_f0 ends.
      FAULT0_CLR_INT_CLR  : Boolean := False;
      --  Write-only. Set this bit to clear the interrupt triggered when
      --  event_f1 ends.
      FAULT1_CLR_INT_CLR  : Boolean := False;
      --  Write-only. Set this bit to clear the interrupt triggered when
      --  event_f2 ends.
      FAULT2_CLR_INT_CLR  : Boolean := False;
      --  Write-only. Set this bit to clear the interrupt triggered by a PWM
      --  operator 0 TEA event
      CMPR0_TEA_INT_CLR   : Boolean := False;
      --  Write-only. Set this bit to clear the interrupt triggered by a PWM
      --  operator 1 TEA event
      CMPR1_TEA_INT_CLR   : Boolean := False;
      --  Write-only. Set this bit to clear the interrupt triggered by a PWM
      --  operator 2 TEA event
      CMPR2_TEA_INT_CLR   : Boolean := False;
      --  Write-only. Set this bit to clear the interrupt triggered by a PWM
      --  operator 0 TEB event
      CMPR0_TEB_INT_CLR   : Boolean := False;
      --  Write-only. Set this bit to clear the interrupt triggered by a PWM
      --  operator 1 TEB event
      CMPR1_TEB_INT_CLR   : Boolean := False;
      --  Write-only. Set this bit to clear the interrupt triggered by a PWM
      --  operator 2 TEB event
      CMPR2_TEB_INT_CLR   : Boolean := False;
      --  Write-only. Set this bit to clear the interrupt triggered by a
      --  cycle-by-cycle mode action on PWM0.
      TZ0_CBC_INT_CLR     : Boolean := False;
      --  Write-only. Set this bit to clear the interrupt triggered by a
      --  cycle-by-cycle mode action on PWM1.
      TZ1_CBC_INT_CLR     : Boolean := False;
      --  Write-only. Set this bit to clear the interrupt triggered by a
      --  cycle-by-cycle mode action on PWM2.
      TZ2_CBC_INT_CLR     : Boolean := False;
      --  Write-only. Set this bit to clear the interrupt triggered by a
      --  one-shot mode action on PWM0.
      TZ0_OST_INT_CLR     : Boolean := False;
      --  Write-only. Set this bit to clear the interrupt triggered by a
      --  one-shot mode action on PWM1.
      TZ1_OST_INT_CLR     : Boolean := False;
      --  Write-only. Set this bit to clear the interrupt triggered by a
      --  one-shot mode action on PWM2.
      TZ2_OST_INT_CLR     : Boolean := False;
      --  Write-only. Set this bit to clear the interrupt triggered by capture
      --  on channel 0.
      CAP0_INT_CLR        : Boolean := False;
      --  Write-only. Set this bit to clear the interrupt triggered by capture
      --  on channel 1.
      CAP1_INT_CLR        : Boolean := False;
      --  Write-only. Set this bit to clear the interrupt triggered by capture
      --  on channel 2.
      CAP2_INT_CLR        : Boolean := False;
      --  unspecified
      Reserved_30_31      : ESP32S3_Registers.UInt2 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for INT_CLR_Register use record
      TIMER0_STOP_INT_CLR at 0 range 0 .. 0;
      TIMER1_STOP_INT_CLR at 0 range 1 .. 1;
      TIMER2_STOP_INT_CLR at 0 range 2 .. 2;
      TIMER0_TEZ_INT_CLR  at 0 range 3 .. 3;
      TIMER1_TEZ_INT_CLR  at 0 range 4 .. 4;
      TIMER2_TEZ_INT_CLR  at 0 range 5 .. 5;
      TIMER0_TEP_INT_CLR  at 0 range 6 .. 6;
      TIMER1_TEP_INT_CLR  at 0 range 7 .. 7;
      TIMER2_TEP_INT_CLR  at 0 range 8 .. 8;
      FAULT0_INT_CLR      at 0 range 9 .. 9;
      FAULT1_INT_CLR      at 0 range 10 .. 10;
      FAULT2_INT_CLR      at 0 range 11 .. 11;
      FAULT0_CLR_INT_CLR  at 0 range 12 .. 12;
      FAULT1_CLR_INT_CLR  at 0 range 13 .. 13;
      FAULT2_CLR_INT_CLR  at 0 range 14 .. 14;
      CMPR0_TEA_INT_CLR   at 0 range 15 .. 15;
      CMPR1_TEA_INT_CLR   at 0 range 16 .. 16;
      CMPR2_TEA_INT_CLR   at 0 range 17 .. 17;
      CMPR0_TEB_INT_CLR   at 0 range 18 .. 18;
      CMPR1_TEB_INT_CLR   at 0 range 19 .. 19;
      CMPR2_TEB_INT_CLR   at 0 range 20 .. 20;
      TZ0_CBC_INT_CLR     at 0 range 21 .. 21;
      TZ1_CBC_INT_CLR     at 0 range 22 .. 22;
      TZ2_CBC_INT_CLR     at 0 range 23 .. 23;
      TZ0_OST_INT_CLR     at 0 range 24 .. 24;
      TZ1_OST_INT_CLR     at 0 range 25 .. 25;
      TZ2_OST_INT_CLR     at 0 range 26 .. 26;
      CAP0_INT_CLR        at 0 range 27 .. 27;
      CAP1_INT_CLR        at 0 range 28 .. 28;
      CAP2_INT_CLR        at 0 range 29 .. 29;
      Reserved_30_31      at 0 range 30 .. 31;
   end record;

   --  MCPWM APB configuration register
   type CLK_Register is record
      --  Force clock on for this register file
      EN            : Boolean := False;
      --  unspecified
      Reserved_1_31 : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CLK_Register use record
      EN            at 0 range 0 .. 0;
      Reserved_1_31 at 0 range 1 .. 31;
   end record;

   subtype VERSION_DATE_Field is ESP32S3_Registers.UInt28;

   --  Version register.
   type VERSION_Register is record
      --  Version of this register file
      DATE           : VERSION_DATE_Field := 16#1509110#;
      --  unspecified
      Reserved_28_31 : ESP32S3_Registers.UInt4 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for VERSION_Register use record
      DATE           at 0 range 0 .. 27;
      Reserved_28_31 at 0 range 28 .. 31;
   end record;

   -----------------
   -- Peripherals --
   -----------------

   --  Motor Control Pulse-Width Modulation 0
   type PWM_Peripheral is record
      --  PWM clock prescaler register.
      CLK_CFG           : aliased CLK_CFG_Register;
      --  PWM timer0 period and update method configuration register.
      TIMER0_CFG0       : aliased TIMER0_CFG0_Register;
      --  PWM timer0 working mode and start/stop control configuration
      --  register.
      TIMER0_CFG1       : aliased TIMER0_CFG1_Register;
      --  PWM timer0 sync function configuration register.
      TIMER0_SYNC       : aliased TIMER0_SYNC_Register;
      --  PWM timer0 status register.
      TIMER0_STATUS     : aliased TIMER0_STATUS_Register;
      --  PWM timer1 period and update method configuration register.
      TIMER1_CFG0       : aliased TIMER1_CFG0_Register;
      --  PWM timer1 working mode and start/stop control configuration
      --  register.
      TIMER1_CFG1       : aliased TIMER1_CFG1_Register;
      --  PWM timer1 sync function configuration register.
      TIMER1_SYNC       : aliased TIMER1_SYNC_Register;
      --  PWM timer1 status register.
      TIMER1_STATUS     : aliased TIMER1_STATUS_Register;
      --  PWM timer2 period and update method configuration register.
      TIMER2_CFG0       : aliased TIMER2_CFG0_Register;
      --  PWM timer2 working mode and start/stop control configuration
      --  register.
      TIMER2_CFG1       : aliased TIMER2_CFG1_Register;
      --  PWM timer2 sync function configuration register.
      TIMER2_SYNC       : aliased TIMER2_SYNC_Register;
      --  PWM timer2 status register.
      TIMER2_STATUS     : aliased TIMER2_STATUS_Register;
      --  Synchronization input selection for three PWM timers.
      TIMER_SYNCI_CFG   : aliased TIMER_SYNCI_CFG_Register;
      --  Select specific timer for PWM operators.
      OPERATOR_TIMERSEL : aliased OPERATOR_TIMERSEL_Register;
      --  Transfer status and update method for time stamp registers A and B
      CMPR0_CFG         : aliased CMPR0_CFG_Register;
      --  Shadow register for register A.
      CMPR0_VALUE0      : aliased CMPR0_VALUE0_Register;
      --  Shadow register for register B.
      CMPR0_VALUE1      : aliased CMPR0_VALUE1_Register;
      --  Fault event T0 and T1 handling
      GEN0_CFG0         : aliased GEN0_CFG0_Register;
      --  Permissives to force PWM0A and PWM0B outputs by software
      GEN0_FORCE        : aliased GEN0_FORCE_Register;
      --  Actions triggered by events on PWM0A
      GEN0_A            : aliased GEN0_A_Register;
      --  Actions triggered by events on PWM0B
      GEN0_B            : aliased GEN0_B_Register;
      --  dead time type selection and configuration
      DB0_CFG           : aliased DB0_CFG_Register;
      --  Shadow register for falling edge delay (FED).
      DB0_FED_CFG       : aliased DB0_FED_CFG_Register;
      --  Shadow register for rising edge delay (RED).
      DB0_RED_CFG       : aliased DB0_RED_CFG_Register;
      --  Carrier enable and configuratoin
      CHOPPER0_CFG      : aliased CHOPPER0_CFG_Register;
      --  Actions on PWM0A and PWM0B trip events
      TZ0_CFG0          : aliased TZ0_CFG0_Register;
      --  Software triggers for fault handler actions
      TZ0_CFG1          : aliased TZ0_CFG1_Register;
      --  Status of fault events.
      TZ0_STATUS        : aliased TZ0_STATUS_Register;
      --  Transfer status and update method for time stamp registers A and B
      CMPR1_CFG         : aliased CMPR1_CFG_Register;
      --  Shadow register for register A.
      CMPR1_VALUE0      : aliased CMPR1_VALUE0_Register;
      --  Shadow register for register B.
      CMPR1_VALUE1      : aliased CMPR1_VALUE1_Register;
      --  Fault event T0 and T1 handling
      GEN1_CFG0         : aliased GEN1_CFG0_Register;
      --  Permissives to force PWM1A and PWM1B outputs by software
      GEN1_FORCE        : aliased GEN1_FORCE_Register;
      --  Actions triggered by events on PWM1A
      GEN1_A            : aliased GEN1_A_Register;
      --  Actions triggered by events on PWM1B
      GEN1_B            : aliased GEN1_B_Register;
      --  dead time type selection and configuration
      DB1_CFG           : aliased DB1_CFG_Register;
      --  Shadow register for falling edge delay (FED).
      DB1_FED_CFG       : aliased DB1_FED_CFG_Register;
      --  Shadow register for rising edge delay (RED).
      DB1_RED_CFG       : aliased DB1_RED_CFG_Register;
      --  Carrier enable and configuratoin
      CHOPPER1_CFG      : aliased CHOPPER1_CFG_Register;
      --  Actions on PWM1A and PWM1B trip events
      TZ1_CFG0          : aliased TZ1_CFG0_Register;
      --  Software triggers for fault handler actions
      TZ1_CFG1          : aliased TZ1_CFG1_Register;
      --  Status of fault events.
      TZ1_STATUS        : aliased TZ1_STATUS_Register;
      --  Transfer status and update method for time stamp registers A and B
      CMPR2_CFG         : aliased CMPR2_CFG_Register;
      --  Shadow register for register A.
      CMPR2_VALUE0      : aliased CMPR2_VALUE0_Register;
      --  Shadow register for register B.
      CMPR2_VALUE1      : aliased CMPR2_VALUE1_Register;
      --  Fault event T0 and T1 handling
      GEN2_CFG0         : aliased GEN2_CFG0_Register;
      --  Permissives to force PWM2A and PWM2B outputs by software
      GEN2_FORCE        : aliased GEN2_FORCE_Register;
      --  Actions triggered by events on PWM2A
      GEN2_A            : aliased GEN2_A_Register;
      --  Actions triggered by events on PWM2B
      GEN2_B            : aliased GEN2_B_Register;
      --  dead time type selection and configuration
      DB2_CFG           : aliased DB2_CFG_Register;
      --  Shadow register for falling edge delay (FED).
      DB2_FED_CFG       : aliased DB2_FED_CFG_Register;
      --  Shadow register for rising edge delay (RED).
      DB2_RED_CFG       : aliased DB2_RED_CFG_Register;
      --  Carrier enable and configuratoin
      CHOPPER2_CFG      : aliased CHOPPER2_CFG_Register;
      --  Actions on PWM2A and PWM2B trip events
      TZ2_CFG0          : aliased TZ2_CFG0_Register;
      --  Software triggers for fault handler actions
      TZ2_CFG1          : aliased TZ2_CFG1_Register;
      --  Status of fault events.
      TZ2_STATUS        : aliased TZ2_STATUS_Register;
      --  Fault detection configuration and status
      FAULT_DETECT      : aliased FAULT_DETECT_Register;
      --  Configure capture timer
      CAP_TIMER_CFG     : aliased CAP_TIMER_CFG_Register;
      --  Phase for capture timer sync
      CAP_TIMER_PHASE   : aliased ESP32S3_Registers.UInt32;
      --  Capture channel 0 configuration and enable
      CAP_CH0_CFG       : aliased CAP_CH0_CFG_Register;
      --  Capture channel 1 configuration and enable
      CAP_CH1_CFG       : aliased CAP_CH1_CFG_Register;
      --  Capture channel 2 configuration and enable
      CAP_CH2_CFG       : aliased CAP_CH2_CFG_Register;
      --  Value of last capture on channel 0
      CAP_CH0           : aliased ESP32S3_Registers.UInt32;
      --  Value of last capture on channel 1
      CAP_CH1           : aliased ESP32S3_Registers.UInt32;
      --  Value of last capture on channel 2
      CAP_CH2           : aliased ESP32S3_Registers.UInt32;
      --  Edge of last capture trigger
      CAP_STATUS        : aliased CAP_STATUS_Register;
      --  Enable update.
      UPDATE_CFG        : aliased UPDATE_CFG_Register;
      --  Interrupt enable bits
      INT_ENA           : aliased INT_ENA_Register;
      --  Raw interrupt status
      INT_RAW           : aliased INT_RAW_Register;
      --  Masked interrupt status
      INT_ST            : aliased INT_ST_Register;
      --  Interrupt clear bits
      INT_CLR           : aliased INT_CLR_Register;
      --  MCPWM APB configuration register
      CLK               : aliased CLK_Register;
      --  Version register.
      VERSION           : aliased VERSION_Register;
   end record
     with Volatile;

   for PWM_Peripheral use record
      CLK_CFG           at 16#0# range 0 .. 31;
      TIMER0_CFG0       at 16#4# range 0 .. 31;
      TIMER0_CFG1       at 16#8# range 0 .. 31;
      TIMER0_SYNC       at 16#C# range 0 .. 31;
      TIMER0_STATUS     at 16#10# range 0 .. 31;
      TIMER1_CFG0       at 16#14# range 0 .. 31;
      TIMER1_CFG1       at 16#18# range 0 .. 31;
      TIMER1_SYNC       at 16#1C# range 0 .. 31;
      TIMER1_STATUS     at 16#20# range 0 .. 31;
      TIMER2_CFG0       at 16#24# range 0 .. 31;
      TIMER2_CFG1       at 16#28# range 0 .. 31;
      TIMER2_SYNC       at 16#2C# range 0 .. 31;
      TIMER2_STATUS     at 16#30# range 0 .. 31;
      TIMER_SYNCI_CFG   at 16#34# range 0 .. 31;
      OPERATOR_TIMERSEL at 16#38# range 0 .. 31;
      CMPR0_CFG         at 16#3C# range 0 .. 31;
      CMPR0_VALUE0      at 16#40# range 0 .. 31;
      CMPR0_VALUE1      at 16#44# range 0 .. 31;
      GEN0_CFG0         at 16#48# range 0 .. 31;
      GEN0_FORCE        at 16#4C# range 0 .. 31;
      GEN0_A            at 16#50# range 0 .. 31;
      GEN0_B            at 16#54# range 0 .. 31;
      DB0_CFG           at 16#58# range 0 .. 31;
      DB0_FED_CFG       at 16#5C# range 0 .. 31;
      DB0_RED_CFG       at 16#60# range 0 .. 31;
      CHOPPER0_CFG      at 16#64# range 0 .. 31;
      TZ0_CFG0          at 16#68# range 0 .. 31;
      TZ0_CFG1          at 16#6C# range 0 .. 31;
      TZ0_STATUS        at 16#70# range 0 .. 31;
      CMPR1_CFG         at 16#74# range 0 .. 31;
      CMPR1_VALUE0      at 16#78# range 0 .. 31;
      CMPR1_VALUE1      at 16#7C# range 0 .. 31;
      GEN1_CFG0         at 16#80# range 0 .. 31;
      GEN1_FORCE        at 16#84# range 0 .. 31;
      GEN1_A            at 16#88# range 0 .. 31;
      GEN1_B            at 16#8C# range 0 .. 31;
      DB1_CFG           at 16#90# range 0 .. 31;
      DB1_FED_CFG       at 16#94# range 0 .. 31;
      DB1_RED_CFG       at 16#98# range 0 .. 31;
      CHOPPER1_CFG      at 16#9C# range 0 .. 31;
      TZ1_CFG0          at 16#A0# range 0 .. 31;
      TZ1_CFG1          at 16#A4# range 0 .. 31;
      TZ1_STATUS        at 16#A8# range 0 .. 31;
      CMPR2_CFG         at 16#AC# range 0 .. 31;
      CMPR2_VALUE0      at 16#B0# range 0 .. 31;
      CMPR2_VALUE1      at 16#B4# range 0 .. 31;
      GEN2_CFG0         at 16#B8# range 0 .. 31;
      GEN2_FORCE        at 16#BC# range 0 .. 31;
      GEN2_A            at 16#C0# range 0 .. 31;
      GEN2_B            at 16#C4# range 0 .. 31;
      DB2_CFG           at 16#C8# range 0 .. 31;
      DB2_FED_CFG       at 16#CC# range 0 .. 31;
      DB2_RED_CFG       at 16#D0# range 0 .. 31;
      CHOPPER2_CFG      at 16#D4# range 0 .. 31;
      TZ2_CFG0          at 16#D8# range 0 .. 31;
      TZ2_CFG1          at 16#DC# range 0 .. 31;
      TZ2_STATUS        at 16#E0# range 0 .. 31;
      FAULT_DETECT      at 16#E4# range 0 .. 31;
      CAP_TIMER_CFG     at 16#E8# range 0 .. 31;
      CAP_TIMER_PHASE   at 16#EC# range 0 .. 31;
      CAP_CH0_CFG       at 16#F0# range 0 .. 31;
      CAP_CH1_CFG       at 16#F4# range 0 .. 31;
      CAP_CH2_CFG       at 16#F8# range 0 .. 31;
      CAP_CH0           at 16#FC# range 0 .. 31;
      CAP_CH1           at 16#100# range 0 .. 31;
      CAP_CH2           at 16#104# range 0 .. 31;
      CAP_STATUS        at 16#108# range 0 .. 31;
      UPDATE_CFG        at 16#10C# range 0 .. 31;
      INT_ENA           at 16#110# range 0 .. 31;
      INT_RAW           at 16#114# range 0 .. 31;
      INT_ST            at 16#118# range 0 .. 31;
      INT_CLR           at 16#11C# range 0 .. 31;
      CLK               at 16#120# range 0 .. 31;
      VERSION           at 16#124# range 0 .. 31;
   end record;

   --  Motor Control Pulse-Width Modulation 0
   MCPWM0_Periph : aliased PWM_Peripheral
     with Import, Address => MCPWM0_Base, Volatile,
          Async_Readers    => True,
          Async_Writers    => True,
          Effective_Reads  => False,
          Effective_Writes => True;

   --  Motor Control Pulse-Width Modulation 1
   MCPWM1_Periph : aliased PWM_Peripheral
     with Import, Address => MCPWM1_Base, Volatile,
          Async_Readers    => True,
          Async_Writers    => True,
          Effective_Reads  => False,
          Effective_Writes => True;

end ESP32S3_Registers.PWM;
