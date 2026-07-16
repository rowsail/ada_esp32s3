pragma Warnings (Off);
with Interfaces.C;
with System;
with Ada.Real_Time; use Ada.Real_Time;

package body Comm is

   function Core_Id return Interfaces.C.int;       --  PRID-derived (0 or 1)
   pragma Import (C, Core_Id, "native_core_id");

   --  Cross-core transfer log (was smp/glue.c; now Ada calling the ROM printf
   --  directly).  esp_rom_printf keeps each line a single atomic write, so the
   --  two cores' output (producer rate, consumer xfer) never interleaves.
   procedure Rom_Printf3 (Fmt : System.Address; A, B, C : Interfaces.C.int);
   pragma Import (C, Rom_Printf3, "esp_rom_printf");
   procedure Rom_Printf2 (Fmt : System.Address; A, B : Interfaces.C.int);
   pragma Import (C, Rom_Printf2, "esp_rom_printf");

   Xfer_Fmt : constant String :=
     "value %2d:  producer core %d  -->  consumer core %d" & ASCII.LF & ASCII.NUL;
   Rate_Fmt : constant String :=
     "[rate] posted %d:  consumer entry Get completed %d time(s) this period"
     & ASCII.LF & ASCII.NUL;

   procedure Log_Xfer (Value, From_Core, To_Core : Interfaces.C.int) is
   begin
      Rom_Printf3 (Xfer_Fmt'Address, Value, From_Core, To_Core);
   end Log_Xfer;

   procedure Log_Rate (Gets, Posted : Interfaces.C.int) is
   begin
      Rom_Printf2 (Rate_Fmt'Address, Posted, Gets);
   end Log_Rate;

   --  Cross-core handoff via a real protected-object ENTRY.  The producer
   --  (core 1) writes the mailbox and opens the barrier; the consumer (core 0)
   --  blocks in `entry Get when Full` until served.  Serving the entry on
   --  core 1 hands the caller to core 0 through the GNARL served-entry list
   --  plus an inter-core poke (see System.Tasking.Protected_Objects.
   --  Multiprocessors).  Gets counts how many entry calls completed in a
   --  period: it stays ~1, proving the consumer truly blocks between posts
   --  rather than busy-returning.
   Gets : Integer := 0
   with Atomic, Volatile;

   --  GNARL numbers CPUs from 1 (System.Multiprocessors.CPU_Range), so the
   --  `CPU =>` aspect is one more than the hardware core the task runs on:
   --  CPU 2 is hardware core 1, CPU 1 is hardware core 0.
   Producer_CPU : constant := 2;   --  hardware core 1
   Consumer_CPU : constant := 1;   --  hardware core 0

   --  Producer cadence: one value posted per period.
   Post_Period : constant Time_Span := Milliseconds (500);

   protected Mailbox is
      procedure Post (Value, From : Integer);
      entry Get (Value, From : out Integer);
   private
      Full : Boolean := False;
      Item : Integer := 0;
      Src  : Integer := 0;
   end Mailbox;

   protected body Mailbox is
      procedure Post (Value, From : Integer) is
      begin
         Item := Value;
         Src := From;
         Full := True;
      end Post;
      entry Get (Value, From : out Integer) when Full is
      begin
         Value := Item;
         From := Src;
         Full := False;
      end Get;
   end Mailbox;

   --  Producer on core 1: posts an incrementing value every 500 ms and reports
   --  how many consumer entry calls completed in the period (~1 == healthy).
   task Producer
     with Priority => System.Priority'Last - 1, CPU => Producer_CPU;
   task body Producer is
      Count : Integer := 0;
      Next  : Time := Clock + Post_Period;
   begin
      loop
         delay until Next;
         Count := Count + 1;
         Log_Rate (Interfaces.C.int (Gets), Interfaces.C.int (Count));
         Gets := 0;
         Mailbox.Post (Count, Integer (Core_Id));   --  value + this core (1)
         Next := Next + Post_Period;
      end loop;
   end Producer;

   --  Consumer on core 0: blocks in the entry until the core-1 producer posts,
   --  then reads and logs the cross-core transfer on a single line.
   task Consumer
     with Priority => System.Priority'Last - 1, CPU => Consumer_CPU;
   task body Consumer is
      Value     : Integer;
      From_Core : Integer;
   begin
      loop
         Mailbox.Get (Value, From_Core);          --  blocks across cores
         Gets := Gets + 1;
         Log_Xfer (Interfaces.C.int (Value), Interfaces.C.int (From_Core), Core_Id);
      end loop;
   end Consumer;

end Comm;
