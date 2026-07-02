--  What it demonstrates
--  ---------------------
--  A LISP read-eval-print loop running on the ESP32-S3.  Type S-expressions over
--  the USB-serial console; the board reads, evaluates, and prints the result.
--  The interpreter is pure Ada (libs/lisp); its cell arena lives in the PSRAM heap.
--
--  Build & run
--  -----------
--    ./x run esp32s3_lisp
--  Then open the serial console (e.g. picocom -b 115200 /dev/ttyACM0) and type:
--    (define (sq n) (* n n))
--    (sq 12)                       => 144
--    (define (fact n) (if (< n 2) 1 (* n (fact (- n 1)))))
--    (fact 10)                     => 3628800
--
--  Note: no garbage collector yet, so a very long session eventually exhausts the
--  arena (Phase 5).  Reset the board to start fresh.
with Ada.Real_Time;  use Ada.Real_Time;
with Ada.Exceptions; use Ada.Exceptions;
with ESP32S3.Log;    use ESP32S3.Log;
with ESP32S3_Registers.USB_DEVICE;
with Lisp;           use Lisp;
with Lisp.Reader;
with Lisp.Eval;
with Lisp_HAL;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   package USBD renames ESP32S3_Registers.USB_DEVICE;

   --  One console byte, if the host has sent any (USB-serial-JTAG OUT FIFO).
   function Try_Get (C : out Character) return Boolean is
   begin
      if USBD.USB_DEVICE_Periph.EP1_CONF.SERIAL_OUT_EP_DATA_AVAIL then
         C := Character'Val (Natural (USBD.USB_DEVICE_Periph.EP1.RDWR_BYTE));
         return True;
      end if;
      return False;
   end Try_Get;

   function Get_Char return Character is
      C : Character;
   begin
      loop
         if Try_Get (C) then
            return C;
         end if;
         delay until Clock + Milliseconds (2);
      end loop;
   end Get_Char;

   --  Read a CR/LF-terminated line, echoing input back to the console.
   procedure Read_Line (Buf : out String; Last : out Natural) is
      C : Character;
   begin
      Last := 0;
      loop
         C := Get_Char;
         exit when C = ASCII.CR or else C = ASCII.LF;
         if C = ASCII.BS or else C = ASCII.DEL then
            if Last > 0 then
               Last := Last - 1;
               Put (ASCII.BS);
               Put (' ');
               Put (ASCII.BS);
            end if;
         elsif Last < Buf'Length then
            Last := Last + 1;
            Buf (Buf'First + Last - 1) := C;
            Put (C);                              --  echo
         end if;
      end loop;
      New_Line;
   end Read_Line;

   Line : String (1 .. 512);
   Len  : Natural;
begin
   delay until Clock + Milliseconds (200);
   Lisp.Init (40_000);                            --  arena in PSRAM (~640 KB)
   Lisp.Eval.Init;                                --  build the global environment
   Lisp_HAL.Register;                             --  add the hardware primitives

   New_Line;
   Put_Line ("Ada-LISP on the ESP32-S3 -- a pure-Ada interpreter.");
   Put_Line ("Type S-expressions.  e.g. (define (sq n) (* n n))  then  (sq 12)");
   Put_Line ("Hardware: (gpio-out 2 #t) (gpio-toggle 2) (gpio-in 4) (adc-read 0)");
   Put_Line ("  flash JEDEC id: (define s (spi-open)) (spi-xfer s (list #x9f 0 0 0))");

   loop
      Put ("lisp> ");
      Read_Line (Line, Len);
      if Len > 0 then
         begin
            Put_Line (Print (Lisp.Eval.Eval_Top (Lisp.Reader.Read (Line (1 .. Len)))));
         exception
            when Ex : Lisp_Error =>
               Put_Line ("error: " & Exception_Message (Ex));
            when others =>
               Put_Line ("error");
         end;
      end if;
      --  Reclaim this form's garbage.  Safe here: between forms, the only live
      --  objects are reachable from the global environment (definitions persist;
      --  the just-printed result is no longer referenced).
      declare
         Reclaimed : constant Natural := Lisp.GC (Lisp.Eval.Global_Env);
         pragma Unreferenced (Reclaimed);
      begin
         null;
      end;
   end loop;
end Main;
