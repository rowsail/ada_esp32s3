with System;
with Ada.Real_Time; use Ada.Real_Time;
with Ada.Synchronous_Task_Control;
with ESP32S3.GPIO.Interrupts;
with ESP32S3.GPS.NMEA;

package body ESP32S3.GPS is

   use type ESP32S3.GPIO.Pad_Number;

   --  Wiring captured by Setup, read by the reader task once released.
   type Config is record
      Port : ESP32S3.UART.UART_Port := ESP32S3.UART.UART0;
      Rx   : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Tx   : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Pps  : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Baud : ESP32S3.UART.Baud_Rate := 9600;
   end record;

   Cfg          : Config;
   Start_Signal : Ada.Synchronous_Task_Control.Suspension_Object;

   ---------------------------------------------------------------------------
   --  The published store.  Every value is read and written under this one
   --  lock, so a reader never sees a half-updated record -- Latitude/Longitude
   --  in particular are one Position, set in a single action.
   ---------------------------------------------------------------------------

   Max_Raw : constant := 100;

   --  Satellites in view, keyed by System+PRN, with a per-entry timestamp so
   --  ones that drop out of the GSV stream age away.  (Declared here, not inside
   --  the protected type, where nested type declarations are not allowed.)
   type Sat_Entry is record
      Sat        : Satellite;
      Updated_At : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
      Used       : Boolean := False;
   end record;
   type Sat_Table is array (1 .. Max_Satellites) of Sat_Entry;

   protected Store is
      procedure Apply (R : NMEA.Parsed; Now : Ada.Real_Time.Time);
      procedure Set_Raw (S : String);
      procedure Get_Raw (Buffer : out String; Length : out Natural);
      function Position_Of return Position_Reading;
      function Fix_Of return Fix_Reading;
      function Time_Of return Time_Reading;
      function Date_Of return Date_Reading;
      function Velocity_Of return Velocity_Reading;
      function Signal_Of return Signal_Reading;
      procedure Get_Sky
        (List : out Satellite_List; Count : out Natural; Max_Age : Ada.Real_Time.Time_Span);
   private
      Pos     : Position_Reading;
      Fix     : Fix_Reading;
      Tim     : Time_Reading;
      Dat     : Date_Reading;
      Vel     : Velocity_Reading;
      Sig     : Signal_Reading;
      Sky     : Sat_Table;
      Raw     : String (1 .. Max_Raw) := (others => ' ');
      Raw_Len : Natural := 0;
   end Store;

   protected body Store is

      --  Insert or refresh one satellite (keyed by System+PRN); when the table
      --  is full, evict the stalest entry.
      procedure Upsert (New_Sat : Satellite; Now : Ada.Real_Time.Time) is
         Free         : Natural := 0;
         Stalest      : Natural := 0;
         Stalest_Time : Ada.Real_Time.Time := Ada.Real_Time.Time_Last;
      begin
         for I in Sky'Range loop
            if Sky (I).Used
              and then Sky (I).Sat.System = New_Sat.System
              and then Sky (I).Sat.PRN = New_Sat.PRN
            then
               Sky (I) := (Sat => New_Sat, Updated_At => Now, Used => True);
               return;
            end if;
         end loop;
         for I in Sky'Range loop
            if not Sky (I).Used then
               Free := I;
               exit;
            elsif Sky (I).Updated_At < Stalest_Time then
               Stalest_Time := Sky (I).Updated_At;
               Stalest := I;
            end if;
         end loop;
         if Free = 0 then
            Free := Stalest;
         end if;
         if Free /= 0 then
            Sky (Free) := (Sat => New_Sat, Updated_At => Now, Used => True);
         end if;
      end Upsert;

      procedure Apply (R : NMEA.Parsed; Now : Ada.Real_Time.Time) is
      begin
         if R.Has_Position then
            Pos := (Value => R.Pos, Updated_At => Now, Valid => True);
         end if;
         if R.Has_Quality then
            Fix.Quality := R.Quality;
            Fix.Updated_At := Now;
            Fix.Valid := True;
         end if;
         if R.Has_Sats then
            Fix.Satellites := R.Satellites;
            Fix.Updated_At := Now;
            Fix.Valid := True;
         end if;
         if R.Has_Altitude then
            Fix.Altitude_MM := R.Altitude_MM;
            Fix.Updated_At := Now;
            Fix.Valid := True;
         end if;
         if R.Has_Time then
            Tim := (Value => R.Time, Updated_At => Now, Valid => True);
         end if;
         if R.Has_Date then
            Dat := (Value => R.Day, Updated_At => Now, Valid => True);
         end if;
         if R.Has_Velocity then
            Vel :=
              (Speed_MMS   => R.Speed_MMS,
               Course_CDeg => R.Course_CDeg,
               Updated_At  => Now,
               Valid       => True);
         end if;
         if R.Has_Sky then
            Sig.In_View := R.In_View;
            Sig.Max_SNR := R.Max_SNR;
            Sig.Updated_At := Now;
            Sig.Valid := True;
            for I in 1 .. R.Sat_Count loop
               Upsert (R.Sats (I), Now);
            end loop;
         end if;
         if R.Has_DOP then
            Sig.Mode := R.Mode;
            Sig.Used := R.Used;
            Sig.PDOP_C := R.PDOP_C;
            Sig.HDOP_C := R.HDOP_C;
            Sig.VDOP_C := R.VDOP_C;
            Sig.Updated_At := Now;
            Sig.Valid := True;
         end if;
      end Apply;

      procedure Set_Raw (S : String) is
         Copy_Len : constant Natural := Natural'Min (S'Length, Max_Raw);
      begin
         Raw (1 .. Copy_Len) := S (S'First .. S'First + Copy_Len - 1);
         Raw_Len := Copy_Len;
      end Set_Raw;

      procedure Get_Raw (Buffer : out String; Length : out Natural) is
      begin
         Length := Natural'Min (Raw_Len, Buffer'Length);
         Buffer (Buffer'First .. Buffer'First + Length - 1) := Raw (1 .. Length);
      end Get_Raw;

      function Position_Of return Position_Reading
      is (Pos);
      function Fix_Of return Fix_Reading
      is (Fix);
      function Time_Of return Time_Reading
      is (Tim);
      function Date_Of return Date_Reading
      is (Dat);
      function Velocity_Of return Velocity_Reading
      is (Vel);
      function Signal_Of return Signal_Reading
      is (Sig);

      procedure Get_Sky
        (List : out Satellite_List; Count : out Natural; Max_Age : Ada.Real_Time.Time_Span)
      is
         Now     : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
         Written : Natural := 0;
      begin
         for I in Sky'Range loop
            exit when Written >= List'Length;
            if Sky (I).Used and then Now - Sky (I).Updated_At <= Max_Age then
               Written := Written + 1;
               List (List'First + Written - 1) := Sky (I).Sat;
            end if;
         end loop;
         Count := Written;
      end Get_Sky;
   end Store;

   ---------------------------------------------------------------------------
   --  PPS capture.  The 1PPS edge is timestamped in the GPIO interrupt, which
   --  runs at the level-3 device ceiling -- so this object sits at interrupt
   --  priority (a normal-ceiling object could not be touched from the ISR).
   ---------------------------------------------------------------------------

   protected PPS_Box
     with Interrupt_Priority => System.Interrupt_Priority'Last
   is
      procedure Tick;
      function Get return PPS_Reading;
   private
      Data : PPS_Reading;
   end PPS_Box;

   protected body PPS_Box is
      procedure Tick is
      begin
         Data := (Last => Ada.Real_Time.Clock, Count => Data.Count + 1, Valid => True);
      end Tick;
      function Get return PPS_Reading
      is (Data);
   end PPS_Box;

   procedure PPS_ISR is
   begin
      PPS_Box.Tick;
   end PPS_ISR;

   ---------------------------------------------------------------------------
   --  Outbox: bytes queued by Send, transmitted by the reader task (which owns
   --  the UART Session).  Overflowing bytes are dropped.
   ---------------------------------------------------------------------------

   Max_Out : constant := 256;

   protected Outbox is
      procedure Put (S : String);
      procedure Take (Buf : out String; Count : out Natural);
   private
      Data : String (1 .. Max_Out);
      Len  : Natural := 0;
   end Outbox;

   protected body Outbox is
      procedure Put (S : String) is
      begin
         if S'Length > 0 and then Len + S'Length <= Max_Out then
            Data (Len + 1 .. Len + S'Length) := S;
            Len := Len + S'Length;
         end if;
      end Put;

      procedure Take (Buf : out String; Count : out Natural) is
      begin
         Count := Len;
         if Len > 0 then
            Buf (Buf'First .. Buf'First + Len - 1) := Data (1 .. Len);
            Len := 0;
         end if;
      end Take;
   end Outbox;

   ---------------------------------------------------------------------------
   --  Decode one framed sentence and publish whatever it carried.
   ---------------------------------------------------------------------------

   procedure Process (Sentence : String; Accepted : out Boolean) is
      Result : NMEA.Parsed;
      Now    : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
   begin
      Store.Set_Raw (Sentence);   --  capture every framed line for diagnostics
      NMEA.Parse (Sentence, Result);
      Accepted := Result.Recognised;
      if Result.Recognised then
         Store.Apply (Result, Now);
      end if;
   end Process;

   ---------------------------------------------------------------------------
   --  The reader: owns the UART for life, frames sentences on CR/LF, decodes.
   ---------------------------------------------------------------------------

   Max_Line : constant := 100;     --  NMEA sentences are <= 82 chars

   --  Run the reader BELOW the application's priority: it is a background
   --  consumer of a continuous byte stream, so the app (and anything reading the
   --  store) must always preempt it -- otherwise, at equal priority with data
   --  always available, the reader would never yield.
   task Reader
     with Priority => System.Default_Priority - 1;
   task body Reader is
      Port_Session : ESP32S3.UART.Session;
      Chunk        : ESP32S3.UART.Byte_Array (1 .. 64);
      Read_Count   : Natural;
      Line         : String (1 .. Max_Line) := (others => ' ');
      Len          : Natural := 0;
      Junk         : Boolean;
   begin
      --  Idle until Setup has recorded the port, pins and baud.
      Ada.Synchronous_Task_Control.Suspend_Until_True (Start_Signal);

      --  Own the port and shape it to the link in one call -- configuration is
      --  part of Acquire, so it cannot precede ownership.
      ESP32S3.UART.Acquire
        (Port_Session, Cfg.Port, Baud => Cfg.Baud, Tx => Cfg.Tx, Rx => Cfg.Rx);

      loop
         --  Transmit anything queued by Send (we hold the UART Session).
         declare
            Out_Buf : String (1 .. Max_Out);
            Out_Len : Natural;
         begin
            Outbox.Take (Out_Buf, Out_Len);
            if Out_Len > 0 then
               declare
                  Bytes : ESP32S3.UART.Byte_Array (1 .. Out_Len);
               begin
                  for I in 1 .. Out_Len loop
                     Bytes (I) := ESP32S3.UART.Byte (Character'Pos (Out_Buf (I)));
                  end loop;
                  ESP32S3.UART.Write (Port_Session, Bytes);
               end;
            end if;
         end;

         ESP32S3.UART.Read (Port_Session, Chunk, Read_Count);
         if Read_Count = 0 then
            delay until Ada.Real_Time.Clock + Milliseconds (5);  --  idle pacing

         end if;
         for I in 1 .. Read_Count loop
            declare
               Ch : constant Character := Character'Val (Natural (Chunk (I)));
            begin
               if Ch = ASCII.CR or else Ch = ASCII.LF then
                  if Len > 0 then
                     --  Defence in depth: a malformed sentence must only drop that
                     --  line, never propagate out and terminate this reader task
                     --  (which would silence GPS until reboot).  The parser is
                     --  hardened against overflow, so this should never fire.
                     begin
                        Process (Line (1 .. Len), Junk);
                     exception
                        when others =>
                           null;
                     end;
                     Len := 0;
                  end if;
               elsif Len < Max_Line then
                  Len := Len + 1;
                  Line (Len) := Ch;
               else
                  Len := 0;     --  oversized line: drop and resync
               end if;
            end;
         end loop;
      end loop;
   end Reader;

   -----------
   -- Setup --
   -----------

   procedure Setup
     (Port : ESP32S3.UART.UART_Port;
      Rx   : ESP32S3.GPIO.Optional_Pin;
      Tx   : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Pps  : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Baud : ESP32S3.UART.Baud_Rate := 9600) is
   begin
      --  Record the link parameters; the Reader task applies them through its
      --  held Session once it owns the port (UART config requires ownership).
      Cfg := (Port => Port, Rx => Rx, Tx => Tx, Pps => Pps, Baud => Baud);

      if Pps /= ESP32S3.GPIO.No_Pin then
         declare
            Pin : constant ESP32S3.GPIO.Pin_Id := ESP32S3.GPIO.Pin_Id (Pps);
         begin
            ESP32S3.GPIO.Configure
              (Pin, Mode => ESP32S3.GPIO.Input, Pull => ESP32S3.GPIO.Pull_Down);
            ESP32S3.GPIO.Interrupts.Enable
              (Pin, On => ESP32S3.GPIO.Interrupts.Rising_Edge, Action => PPS_ISR'Access);
         end;
      end if;

      Ada.Synchronous_Task_Control.Set_True (Start_Signal);   --  release Reader
   end Setup;

   ---------------------------------------------------------------------------
   --  Readers.
   ---------------------------------------------------------------------------

   function Current_Position return Position_Reading
   is (Store.Position_Of);
   function Current_Fix return Fix_Reading
   is (Store.Fix_Of);
   function Current_Time return Time_Reading
   is (Store.Time_Of);
   function Current_Date return Date_Reading
   is (Store.Date_Of);
   function Current_Velocity return Velocity_Reading
   is (Store.Velocity_Of);
   function Current_Signal return Signal_Reading
   is (Store.Signal_Of);
   function Current_PPS return PPS_Reading
   is (PPS_Box.Get);

   procedure Satellites_In_View
     (List    : out Satellite_List;
      Count   : out Natural;
      Max_Age : Ada.Real_Time.Time_Span := Ada.Real_Time.Milliseconds (3000)) is
   begin
      Store.Get_Sky (List, Count, Max_Age);
   end Satellites_In_View;

   function Age (Updated_At : Ada.Real_Time.Time) return Ada.Real_Time.Time_Span
   is (Ada.Real_Time.Clock - Updated_At);

   procedure Send (Command : String) is
   begin
      Outbox.Put (Command);
   end Send;

   procedure Last_Sentence (Buffer : out String; Length : out Natural) is
   begin
      Store.Get_Raw (Buffer, Length);
   end Last_Sentence;

   ------------
   -- Inject --
   ------------

   procedure Inject (Sentence : String; Accepted : out Boolean) is
   begin
      Process (Sentence, Accepted);
   end Inject;

end ESP32S3.GPS;
