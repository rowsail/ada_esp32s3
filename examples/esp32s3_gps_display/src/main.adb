--  Multi-sensor dashboard on a 240x240 ST7789 panel (bare-metal ESP32-S3, no
--  FreeRTOS, no IDF).  Four reusable HAL drivers feed four views that cycle on
--  screen, five seconds each:
--
--    GPS  ESP32S3.GPS        UART0 (GPS TXD->U0RXD=IO44, U0TXD->GPS RXD=IO43,
--                            9600) -- live UTC / latitude / longitude / fix.
--    ENV  ESP32S3.SHT41      I2C0 0x44 -- temperature + relative humidity.
--    RTC  ESP32S3.PCF85063A  I2C0 0x51 -- calendar date / time / weekday.
--    IMU  ESP32S3.QMI8658C   I2C0 0x6B/0x6A -- 3-axis accel (g) + die temp.
--
--  All three I2C parts share one bus (SDA=IO8 SCL=IO7); each driver opens a
--  short-lived I2C Session per read, so they coexist.  The GPS is a background
--  task publishing into a protected store.  The display (SPI2: SCLK=IO12
--  MOSI=IO13 DC=IO16 CS=IO10; backlight IO6 driven HERE) is held in ONE Session
--  for the whole run -- so no task can corrupt the controller -- while each text
--  update locks the SPI host only for its own transfers.
--
--  The console mirrors every row pushed to the panel, so a live run can be
--  checked over serial too (the panel itself is write-only).
with System;
with Interfaces;    use type Interfaces.Integer_32;
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.GPIO;
with ESP32S3.UART;
with ESP32S3.GPS;
with ESP32S3.SHT41;
with ESP32S3.PCF85063A;
with ESP32S3.QMI8658C;
with ESP32S3.ST7789;
with ESP32S3.ST7789.Text;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   package GPS renames ESP32S3.GPS;
   package SHT renames ESP32S3.SHT41;
   package RTC renames ESP32S3.PCF85063A;
   package IMU renames ESP32S3.QMI8658C;
   package LCD renames ESP32S3.ST7789;
   use type GPS.Fix_Type;
   use type SHT.Status;
   use type RTC.Status;
   use type IMU.Status;

   procedure Banner;  pragma Import (C, Banner, "native_gd_banner");
   procedure Row_C (S : System.Address);
                      pragma Import (C, Row_C, "native_gd_row");

   Backlight : constant ESP32S3.GPIO.Pin_Id := 6;
   Sda       : constant ESP32S3.GPIO.Pin_Id := 8;
   Scl       : constant ESP32S3.GPIO.Pin_Id := 7;

   Disp    : LCD.Device;
   S       : LCD.Session;
   Env     : SHT.Device;
   Clk     : RTC.Device;
   Imu_Dev : IMU.Device;

   --  Display layout (240x240): scale-3 title, scale-1 subtitle, then up to four
   --  value rows in the scale-2 font (cell 12x16), each padded to a fixed width
   --  so the opaque redraw overwrites the previous value.
   Field_Width : constant := 19;
   R1 : constant := 64;
   R2 : constant := 92;
   R3 : constant := 120;
   R4 : constant := 148;

   White : constant LCD.Color := LCD.White;
   Green : constant LCD.Color := LCD.RGB (0, 255, 0);
   Cyan  : constant LCD.Color := LCD.RGB (0, 220, 255);
   Amber : constant LCD.Color := LCD.RGB (255, 190, 0);
   Dim   : constant LCD.Color := LCD.RGB (130, 130, 130);

   Digit : constant String := "0123456789";

   ----------------------------------------------------------------------------
   --  Formatting helpers (no Text_IO on bare metal -- build strings by hand).
   ----------------------------------------------------------------------------

   --  Right-justified, zero-padded Width-digit rendering of Value (mod 10**W).
   function Nat_Fixed (Value, Width : Natural) return String is
      R : String (1 .. Width);
      V : Natural := Value;
   begin
      for I in reverse 1 .. Width loop
         R (I) := Digit (V mod 10 + 1);
         V := V / 10;
      end loop;
      return R;
   end Nat_Fixed;

   --  Minimal-width rendering (no leading zeros).
   function Nat_Img (V : Natural) return String is
     (if V < 10 then (1 => Digit (V + 1))
      else Nat_Img (V / 10) & Digit (V mod 10 + 1));

   --  Pad / clip Str to exactly W characters.
   function Pad (Str : String; W : Natural) return String is
     (if Str'Length >= W then Str (Str'First .. Str'First + W - 1)
      else Str & (1 .. W - Str'Length => ' '));

   --  A milli-unit integer (e.g. 23_450) -> "23.45"; Signed prefixes '+' for
   --  non-negative values (handy for accelerometer axes).
   function Fmt_Milli (M : Integer; Signed : Boolean := False) return String is
      A   : constant Natural := abs M;
      Sgn : constant String  :=
        (if M < 0 then "-" elsif Signed then "+" else "");
   begin
      return Sgn & Nat_Img (A / 1000) & "." & Nat_Fixed ((A mod 1000) / 10, 2);
   end Fmt_Milli;

   function Fmt_Time (T : GPS.UTC_Time) return String is
     ("UTC " & Nat_Fixed (T.Hour, 2) & ":" & Nat_Fixed (T.Minute, 2)
      & ":" & Nat_Fixed (T.Second, 2));

   --  1e-7-degree integer -> "DD.DDDDDDD H" (Int_W integer digits + hemisphere).
   function Fmt_Deg
     (V : Interfaces.Integer_32; Int_W : Positive; Pos, Neg : Character)
      return String
   is
      A : constant Natural := Natural (abs V);
   begin
      return Nat_Fixed (A / 10_000_000, Int_W) & "."
             & Nat_Fixed (A mod 10_000_000, 7) & ' '
             & (if V < 0 then Neg else Pos);
   end Fmt_Deg;

   function Mode_Str (M : GPS.Fix_Type) return String is
     (case M is when GPS.Fix_None => "--",
                when GPS.Fix_2D   => "2D",
                when GPS.Fix_3D   => "3D");

   function Day_Str (W : RTC.Weekday) return String is
     (case W is when RTC.Sunday => "Sun", when RTC.Monday    => "Mon",
                when RTC.Tuesday => "Tue", when RTC.Wednesday => "Wed",
                when RTC.Thursday => "Thu", when RTC.Friday   => "Fri",
                when RTC.Saturday => "Sat");

   ----------------------------------------------------------------------------
   --  Output helpers.
   ----------------------------------------------------------------------------

   --  Mirror one line to the console (NUL-terminate for the C %s glue).
   procedure Console (Line : String) is
      Buf : aliased String (1 .. Line'Length + 1);
   begin
      Buf (1 .. Line'Length) := Line;
      Buf (Buf'Last) := Character'Val (0);
      delay until Clock + Milliseconds (25);   --  space out the 64-byte FIFO
      Row_C (Buf'Address);
   end Console;

   --  Paint one fixed-width row to the panel (over the view's black background)
   --  and echo it to the console.
   procedure Draw_Row (Y : Natural; Text : String; FG : LCD.Color) is
      P : constant String := Pad (Text, Field_Width);
   begin
      LCD.Text.Draw_Text (S, X => 6, Y => Y, Str => P,
                          FG => FG, BG => LCD.Black, Scale => 2);
      Console (P);
   end Draw_Row;

   --  Clear the panel and draw a view's title + subtitle (once per view entry).
   procedure Header (Title, Sub : String; C : LCD.Color) is
   begin
      LCD.Fill (S, LCD.Black);
      LCD.Text.Draw_Text (S, X => 8, Y => 8,  Str => Title,
                          FG => C, BG => LCD.Black, Scale => 3);
      LCD.Text.Draw_Text (S, X => 8, Y => 40, Str => Sub,
                          FG => Dim, BG => LCD.Black, Scale => 1);
      Console ("== " & Title & " : " & Sub & " ==");
   end Header;

   ----------------------------------------------------------------------------
   --  Per-view value updates (called once a second while the view is showing).
   ----------------------------------------------------------------------------

   procedure Update_GPS is
      T : constant GPS.Time_Reading     := GPS.Current_Time;
      P : constant GPS.Position_Reading := GPS.Current_Position;
      F : constant GPS.Fix_Reading      := GPS.Current_Fix;
      G : constant GPS.Signal_Reading   := GPS.Current_Signal;
      Time_Fresh : constant Boolean :=
        T.Valid and then To_Duration (GPS.Age (T.Updated_At)) < 5.0;
      Pos_Fresh : constant Boolean :=
        P.Valid and then To_Duration (GPS.Age (P.Updated_At)) < 3.0;
   begin
      if Time_Fresh then
         Draw_Row (R1, Fmt_Time (T.Value), White);
      else
         Draw_Row (R1, "UTC --:--:--", White);
      end if;
      if Pos_Fresh then
         Draw_Row (R2, "Lat " & Fmt_Deg (P.Value.Latitude, 2, 'N', 'S'), White);
         Draw_Row (R3, "Lon " & Fmt_Deg (P.Value.Longitude, 3, 'E', 'W'), White);
         Draw_Row (R4, "Fix " & Mode_Str (G.Mode) & " Sat "
                       & Nat_Fixed (F.Satellites, 2), Green);
      else
         Draw_Row (R2, "Lat --", White);
         Draw_Row (R3, "Lon --", White);
         Draw_Row (R4, "* searching", Amber);
      end if;
   end Update_GPS;

   procedure Update_Env is
      M  : SHT.Measurement;
      St : SHT.Status;
   begin
      SHT.Measure (Env, M, St);
      if St = SHT.OK then
         Draw_Row (R1, "Temp " & Fmt_Milli (M.Temperature) & " C", White);
         Draw_Row (R2, "Hum  " & Fmt_Milli (M.Humidity) & " %", Cyan);
      else
         Draw_Row (R1, "Temp  --", Amber);
         Draw_Row (R2, "Hum   --", Amber);
      end if;
   end Update_Env;

   procedure Update_RTC is
      T     : RTC.Time;
      Valid : Boolean;
      St    : RTC.Status;
   begin
      RTC.Get_Time (Clk, T, Valid, St);
      if St = RTC.OK then
         Draw_Row (R1, "Date " & Nat_Fixed (T.Year, 4) & "-"
                       & Nat_Fixed (T.Month, 2) & "-" & Nat_Fixed (T.Day, 2),
                   White);
         Draw_Row (R2, "Time " & Nat_Fixed (T.Hour, 2) & ":"
                       & Nat_Fixed (T.Minute, 2) & ":" & Nat_Fixed (T.Second, 2),
                   White);
         Draw_Row (R3, "Day  " & Day_Str (T.Day_Of_Week)
                       & (if Valid then "" else " (unset)"), Cyan);
      else
         Draw_Row (R1, "RTC bus error", Amber);
      end if;
   end Update_RTC;

   procedure Update_IMU is
      A   : IMU.Axes;
      Raw : Interfaces.Integer_16;
      St  : IMU.Status;
      St2 : IMU.Status;
      LSB : constant Positive := IMU.Accel_LSB_Per_G (Imu_Dev);
   begin
      IMU.Read_Accelerometer (Imu_Dev, A, St);
      IMU.Read_Temperature (Imu_Dev, Raw, St2);
      if St = IMU.OK then
         Draw_Row (R1, "Ax " & Fmt_Milli (Integer (A.X) * 1000 / LSB, True)
                       & " g", White);
         Draw_Row (R2, "Ay " & Fmt_Milli (Integer (A.Y) * 1000 / LSB, True)
                       & " g", White);
         Draw_Row (R3, "Az " & Fmt_Milli (Integer (A.Z) * 1000 / LSB, True)
                       & " g", White);
      else
         Draw_Row (R1, "IMU bus error", Amber);
      end if;
      if St2 = IMU.OK then
         Draw_Row (R4, "Temp " & Fmt_Milli (Integer (Raw) * 1000 / 256) & " C",
                   Cyan);
      end if;
   end Update_IMU;

   type View_Kind is (V_GPS, V_Env, V_RTC, V_IMU);
begin
   delay until Clock + Milliseconds (200);
   Banner;

   --  Backlight first (example's job, not the driver's), then bring up the panel.
   ESP32S3.GPIO.Configure (Backlight, Mode => ESP32S3.GPIO.Output);
   ESP32S3.GPIO.Set (Backlight);

   LCD.Setup (Disp, Sclk => 12, Mosi => 13, DC => 16, CS => 10);   --  240x240
   LCD.Acquire (S, Disp);
   LCD.Init (S);
   LCD.Fill (S, LCD.Black);

   --  Bring up the GPS service (releases its reader task) and the I2C sensors.
   GPS.Setup (Port => ESP32S3.UART.UART0, Rx => 44, Tx => 43, Baud => 9_600);
   SHT.Setup (Env, Sda => Sda, Scl => Scl);
   RTC.Setup (Clk, Sda => Sda, Scl => Scl);

   --  IMU: probe the SA0-low address (0x6B); fall back to 0x6A, then configure.
   declare
      Id : Interfaces.Unsigned_8;
      St : IMU.Status;
      use type Interfaces.Unsigned_8;
   begin
      IMU.Setup (Imu_Dev, Sda => Sda, Scl => Scl,
                 Address => IMU.Address_SA0_Low);
      IMU.Read_Who_Am_I (Imu_Dev, Id, St);
      if St /= IMU.OK or else Id /= IMU.Who_Am_I_Value then
         IMU.Setup (Imu_Dev, Sda => Sda, Scl => Scl,
                    Address => IMU.Address_SA0_High);
      end if;
      IMU.Reset (Imu_Dev, St);
      delay until Clock + Milliseconds (20);
      IMU.Configure (Imu_Dev, Accel => IMU.Range_8G, Gyro => IMU.Range_512DPS,
                     Rate => IMU.ODR_235_Hz, Result => St);
   end;

   --  Cycle the views, five seconds (five 1 Hz updates) on each.
   loop
      for V in View_Kind loop
         case V is
            when V_GPS => Header ("GPS", "NMEA receiver",    Green);
            when V_Env => Header ("ENV", "SHT41 temp/humid", Cyan);
            when V_RTC => Header ("RTC", "PCF85063A clock",  White);
            when V_IMU => Header ("IMU", "QMI8658C 6-axis",  Amber);
         end case;

         for Sec in 1 .. 5 loop
            case V is
               when V_GPS => Update_GPS;
               when V_Env => Update_Env;
               when V_RTC => Update_RTC;
               when V_IMU => Update_IMU;
            end case;
            delay until Clock + Seconds (1);
         end loop;
      end loop;
   end loop;
end Main;
