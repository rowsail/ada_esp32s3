with Interfaces;
use type Interfaces.Unsigned_8;

package body ESP32S3.GPS.L76K is

   --  Hex digit (0..15) -> ASCII.
   function Hex (V : Interfaces.Unsigned_8) return Character
   is (if V < 10
       then Character'Val (Character'Pos ('0') + Integer (V))
       else Character'Val (Character'Pos ('A') + Integer (V) - 10));

   --  Frame Body ("$" ... "*HH" CR LF) and queue it for transmission.  Body is
   --  the text between '$' and '*' (e.g. "PCAS04,3").
   procedure Send_PCAS (Body_Text : String) is
      Sum      : Interfaces.Unsigned_8 := 0;
      Sentence : String (1 .. Body_Text'Length + 6);
      L        : constant Natural := Body_Text'Length;
   begin
      for C of Body_Text loop
         Sum := Sum xor Interfaces.Unsigned_8 (Character'Pos (C));
      end loop;
      Sentence (1) := '$';
      Sentence (2 .. L + 1) := Body_Text;
      Sentence (L + 2) := '*';
      Sentence (L + 3) := Hex (Sum / 16);
      Sentence (L + 4) := Hex (Sum mod 16);
      Sentence (L + 5) := ASCII.CR;
      Sentence (L + 6) := ASCII.LF;
      ESP32S3.GPS.Send (Sentence);
   end Send_PCAS;

   --  Single decimal digit for a small value.
   function Digit (V : Natural) return Character
   is (Character'Val (Character'Pos ('0') + V));

   -----------------------
   -- Set_Constellation --  PCAS04 (tested)
   -----------------------

   procedure Set_Constellation (Config : Constellation) is
   begin
      --  Modes are 1 .. 7 in Constellation order.
      Send_PCAS ("PCAS04," & Digit (Constellation'Pos (Config) + 1));
   end Set_Constellation;

   -------------------
   -- Set_Baud_Rate --  PCAS01 (untested)
   -------------------

   procedure Set_Baud_Rate (Rate : Baud_Setting) is
   begin
      Send_PCAS ("PCAS01," & Digit (Baud_Setting'Pos (Rate)));
   end Set_Baud_Rate;

   ---------------------
   -- Set_Update_Rate --  PCAS02 (untested)
   ---------------------

   procedure Set_Update_Rate (Rate : Update_Rate) is
      Interval : constant String :=
        (case Rate is
           when Rate_1Hz => "1000",
           when Rate_2Hz => "500",
           when Rate_5Hz => "200");
   begin
      Send_PCAS ("PCAS02," & Interval);
   end Set_Update_Rate;

   ---------------------
   -- Set_NMEA_Output --  PCAS03 (untested)
   ---------------------

   procedure Set_NMEA_Output
     (GGA, GLL, GSA, GSV, RMC, VTG, ZDA, ANT : Output_Rate := 1) is
   begin
      --  8 output rates then the 6 reserved fields the datasheet fixes.
      Send_PCAS
        ("PCAS03,"
         & Digit (GGA)
         & ","
         & Digit (GLL)
         & ","
         & Digit (GSA)
         & ","
         & Digit (GSV)
         & ","
         & Digit (RMC)
         & ","
         & Digit (VTG)
         & ","
         & Digit (ZDA)
         & ","
         & Digit (ANT)
         & ",0,0,,,0,0");
   end Set_NMEA_Output;

   -------------
   -- Restart --  PCAS10 (untested)
   -------------

   procedure Restart (Mode : Restart_Mode) is
   begin
      Send_PCAS ("PCAS10," & Digit (Restart_Mode'Pos (Mode)));
   end Restart;

end ESP32S3.GPS.L76K;
