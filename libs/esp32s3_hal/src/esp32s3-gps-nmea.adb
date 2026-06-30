with Interfaces; use type Interfaces.Unsigned_8;

package body ESP32S3.GPS.NMEA is

   subtype LLI is Long_Long_Integer;

   ---------------------------------------------------------------------------
   --  Small string helpers (no secondary stack: all return scalars or work on
   --  slices of the caller's Sentence).
   ---------------------------------------------------------------------------

   --  Hex value of one ASCII nibble, or -1 if not a hex digit.
   function Hex_Val (C : Character) return Integer is
     (case C is
         when '0' .. '9' => Character'Pos (C) - Character'Pos ('0'),
         when 'A' .. 'F' => Character'Pos (C) - Character'Pos ('A') + 10,
         when 'a' .. 'f' => Character'Pos (C) - Character'Pos ('a') + 10,
         when others     => -1);

   --  Unsigned integer value of the leading digits of S (stops at the first
   --  non-digit); empty / no digits -> 0.
   function To_Nat (S : String) return Natural is
      Acc : Natural := 0;
   begin
      for C of S loop
         exit when C not in '0' .. '9';
         --  Saturate rather than overflow Natural on a garbled (over-long) field:
         --  UART line noise can present many digits, and an unguarded Acc*10 would
         --  raise Constraint_Error that kills the GPS reader task.  No real NMEA
         --  numeric field needs anywhere near this many digits.
         exit when Acc > (Natural'Last - 9) / 10;
         Acc := Acc * 10 + (Character'Pos (C) - Character'Pos ('0'));
      end loop;
      return Acc;
   end To_Nat;

   --  Fractional digits of S scaled to exactly Places digits (pad or truncate).
   --  e.g. Frac ("123", 5) = 12300 ;  Frac ("123456", 5) = 12345.
   function Frac (S : String; Places : Natural) return Natural is
      Acc : Natural := 0;
      N   : Natural := 0;
   begin
      for C of S loop
         exit when C not in '0' .. '9' or else N = Places;
         Acc := Acc * 10 + (Character'Pos (C) - Character'Pos ('0'));
         N := N + 1;
      end loop;
      while N < Places loop
         Acc := Acc * 10;
         N := N + 1;
      end loop;
      return Acc;
   end Frac;

   --  Return field number N (0-based) of a comma-separated payload, as a slice
   --  of S.  Out-of-range -> an empty slice.
   function Field (S : String; N : Natural) return String is
      Start : Integer := S'First;
      Count : Natural := 0;
   begin
      for I in S'Range loop
         if S (I) = ',' then
            if Count = N then
               return S (Start .. I - 1);
            end if;
            Count := Count + 1;
            Start := I + 1;
         end if;
      end loop;
      if Count = N then
         return S (Start .. S'Last);
      end if;
      return S (S'First .. S'First - 1);   --  empty
   end Field;

   ---------------------------------------------------------------------------
   --  Decimal "iii.fff" -> integer scaled by 10**Places (e.g. metres -> mm with
   --  Places = 3).  Missing fraction is treated as zero.
   ---------------------------------------------------------------------------

   function Scaled (S : String; Places : Natural) return Integer is
      Dot : Integer := 0;
   begin
      if S = "" then
         return 0;
      end if;
      for I in S'Range loop
         if S (I) = '.' then
            Dot := I;
         end if;
      end loop;
      declare
         --  Compute in 64-bit and clamp to Integer: To_Nat is saturated but
         --  To_Nat * 10**Places can still exceed Integer on garbage input.
         Whole : constant LLI :=
           (if Dot = 0
            then LLI (To_Nat (S)) * 10 ** Places
            else LLI (To_Nat (S (S'First .. Dot - 1))) * 10 ** Places
                 + LLI (Frac (S (Dot + 1 .. S'Last), Places)));
      begin
         if Whole > LLI (Integer'Last) then
            return Integer'Last;
         elsif Whole < LLI (Integer'First) then
            return Integer'First;
         end if;
         return Integer (Whole);
      end;
   end Scaled;

   ---------------------------------------------------------------------------
   --  NMEA coordinate "ddmm.mmmmm" + hemisphere -> 1e-7 degrees, signed.
   --  The two integer digits before the dot are minutes; everything before that
   --  is degrees (2 for latitude, 3 for longitude -- handled the same way).
   ---------------------------------------------------------------------------

   function Coord (S : String; Hemi : Character) return Interfaces.Integer_32 is
      Dot     : Integer := 0;
      Degrees : Natural;
      Min_E5  : LLI;        --  minutes in units of 1e-5 minute
      Deg_E7  : LLI;
   begin
      if S = "" then
         return 0;
      end if;
      for I in S'Range loop
         if S (I) = '.' then
            Dot := I;
         end if;
      end loop;
      if Dot < S'First + 3 then
         return 0;          --  too short to hold dd + mm.
      end if;

      Degrees := To_Nat (S (S'First .. Dot - 3));
      if Degrees > 180 then
         return 0;          --  implausible (real |lat|<=90, |lon|<=180): reject,
      end if;               --  and keeps Deg_E7 well within Integer_32 below
      Min_E5  := LLI (To_Nat (S (Dot - 2 .. Dot - 1))) * 100_000
                 + LLI (Frac (S (Dot + 1 .. S'Last), 5));
      --  1e-5 minute = (1e7 / 60) / 1e5 deg_e7 = 5/3 deg_e7.
      Deg_E7 := LLI (Degrees) * 10_000_000 + (Min_E5 * 5) / 3;

      if Hemi = 'S' or else Hemi = 'W' then
         Deg_E7 := -Deg_E7;
      end if;
      return Interfaces.Integer_32 (Deg_E7);
   end Coord;

   --  "hhmmss.ss" -> UTC_Time.
   function To_Time (S : String) return UTC_Time is
      T   : UTC_Time;
      Dot : Integer := 0;
   begin
      if S'Length < 6 then
         return T;
      end if;
      T.Hour   := To_Nat (S (S'First     .. S'First + 1));
      T.Minute := To_Nat (S (S'First + 2 .. S'First + 3));
      T.Second := To_Nat (S (S'First + 4 .. S'First + 5));
      for I in S'Range loop
         if S (I) = '.' then
            Dot := I;
         end if;
      end loop;
      if Dot /= 0 then
         T.Centi := Frac (S (Dot + 1 .. S'Last), 2);
      end if;
      return T;
   end To_Time;

   --  "ddmmyy" -> Date (year 2000+yy).
   function To_Date (S : String) return Date is
      D : Date;
   begin
      if S'Length < 6 then
         return D;
      end if;
      D.Day   := To_Nat (S (S'First     .. S'First + 1));
      D.Month := To_Nat (S (S'First + 2 .. S'First + 3));
      D.Year  := 2000 + To_Nat (S (S'First + 4 .. S'First + 5));
      return D;
   end To_Date;

   ---------------------------------------------------------------------------
   --  Checksum: XOR of the bytes between '$' and '*', compared to the two hex
   --  digits after '*'.  Returns the payload slice (between '$' and '*') and
   --  whether it validated.
   ---------------------------------------------------------------------------

   procedure Check
     (Sentence : String; First, Last : out Integer; Ok : out Boolean)
   is
      Star : Integer := 0;
      Sum  : Interfaces.Unsigned_8 := 0;
      Hi, Lo : Integer;
   begin
      First := 0; Last := -1; Ok := False;
      if Sentence'Length < 4 or else Sentence (Sentence'First) /= '$' then
         return;
      end if;
      for I in Sentence'First + 1 .. Sentence'Last loop
         if Sentence (I) = '*' then
            Star := I;
            exit;
         end if;
         Sum := Sum xor Interfaces.Unsigned_8 (Character'Pos (Sentence (I)));
      end loop;
      if Star = 0 or else Star + 2 > Sentence'Last then
         return;   --  no '*HH'
      end if;
      Hi := Hex_Val (Sentence (Star + 1));
      Lo := Hex_Val (Sentence (Star + 2));
      if Hi < 0 or else Lo < 0 then
         return;
      end if;
      First := Sentence'First + 1;
      Last  := Star - 1;
      Ok    := Interfaces.Unsigned_8 (Hi * 16 + Lo) = Sum;
   end Check;

   --  Does talker+type field T end with the 3-letter sentence type Kind?
   function Is_Type (T : String; Kind : String) return Boolean is
     (T'Length >= 3 and then T (T'Last - 2 .. T'Last) = Kind);

   --  Constellation from a sentence's two-letter talker prefix.
   function System_Of (Kind : String) return GNSS_System is
      T : constant String :=
        (if Kind'Length >= 2 then Kind (Kind'First .. Kind'First + 1) else "");
   begin
      if    T = "GP" then return GPS;
      elsif T = "GL" then return GLONASS;
      elsif T = "GA" then return Galileo;
      elsif T = "GB" or else T = "BD" then return BeiDou;
      elsif T = "GQ" then return QZSS;
      else  return Other;
      end if;
   end System_Of;

   -----------
   -- Parse --
   -----------

   procedure Parse (Sentence : String; Result : out Parsed) is
      First, Last : Integer;
      Ok          : Boolean;
   begin
      Result := (others => <>);
      Check (Sentence, First, Last, Ok);
      if not Ok then
         return;
      end if;

      declare
         P    : String renames Sentence (First .. Last);
         Kind : constant String := Field (P, 0);
      begin
         if Is_Type (Kind, "GGA") then
            --  $..GGA,time,lat,N/S,lon,E/W,qual,sats,hdop,alt,M,...
            Result.Recognised := True;
            declare
               Tm   : constant String := Field (P, 1);
               La   : constant String := Field (P, 2);
               Ns   : constant String := Field (P, 3);
               Lo   : constant String := Field (P, 4);
               Ew   : constant String := Field (P, 5);
               Q    : constant Natural := To_Nat (Field (P, 6));
               Sats : constant String := Field (P, 7);
               Alt  : constant String := Field (P, 9);
            begin
               if Tm /= "" then
                  Result.Has_Time := True;
                  Result.Time := To_Time (Tm);
               end if;
               Result.Has_Quality := True;
               Result.Quality :=
                 (case Q is
                     when 1      => GPS_Fix,
                     when 2      => DGPS_Fix,
                     when others => No_Fix);
               Result.Fix_Valid := Q > 0;
               if Sats /= "" then
                  Result.Has_Sats := True;
                  Result.Satellites := To_Nat (Sats);
               end if;
               if Alt /= "" then
                  Result.Has_Altitude := True;
                  Result.Altitude_MM := Scaled (Alt, 3);
               end if;
               if Result.Fix_Valid and then La /= "" and then Lo /= "" then
                  Result.Has_Position := True;
                  Result.Pos := (Latitude  => Coord (La, (if Ns = "" then 'N'
                                                          else Ns (Ns'First))),
                                 Longitude => Coord (Lo, (if Ew = "" then 'E'
                                                          else Ew (Ew'First))));
               end if;
            end;

         elsif Is_Type (Kind, "RMC") then
            --  $..RMC,time,status,lat,N/S,lon,E/W,speed,course,date,...
            Result.Recognised := True;
            declare
               Tm  : constant String := Field (P, 1);
               St  : constant String := Field (P, 2);
               La  : constant String := Field (P, 3);
               Ns  : constant String := Field (P, 4);
               Lo  : constant String := Field (P, 5);
               Ew  : constant String := Field (P, 6);
               Spd : constant String := Field (P, 7);   --  knots
               Cog : constant String := Field (P, 8);   --  degrees true
               Dt  : constant String := Field (P, 9);   --  ddmmyy
            begin
               Result.Fix_Valid := St = "A";
               if Tm /= "" then
                  Result.Has_Time := True;
                  Result.Time := To_Time (Tm);
               end if;
               if Dt /= "" then
                  Result.Has_Date := True;
                  Result.Day := To_Date (Dt);
               end if;
               if Result.Fix_Valid and then La /= "" and then Lo /= "" then
                  Result.Has_Position := True;
                  Result.Pos := (Latitude  => Coord (La, (if Ns = "" then 'N'
                                                          else Ns (Ns'First))),
                                 Longitude => Coord (Lo, (if Ew = "" then 'E'
                                                          else Ew (Ew'First))));
               end if;
               if Result.Fix_Valid and then (Spd /= "" or else Cog /= "") then
                  Result.Has_Velocity := True;
                  --  knots -> mm/s : 1 knot = 1852/3600 m/s.  Spd is milli-knots.
                  Result.Speed_MMS :=
                    Natural (LLI (Scaled (Spd, 3)) * 1852 / 3600);
                  Result.Course_CDeg := Scaled (Cog, 2);   --  centi-degrees
               end if;
            end;

         elsif Is_Type (Kind, "ZDA") then
            --  $..ZDA,hhmmss.ss,dd,mm,yyyy,zonehh,zonemm -- UTC time + date,
            --  NOT gated on a fix, so it updates the clock before lock.  The
            --  year is the full 4 digits here (unlike RMC's ddmmyy).
            Result.Recognised := True;
            declare
               Tm : constant String := Field (P, 1);
               Dd : constant String := Field (P, 2);
               Mm : constant String := Field (P, 3);
               Yy : constant String := Field (P, 4);
            begin
               if Tm /= "" then
                  Result.Has_Time := True;
                  Result.Time := To_Time (Tm);
               end if;
               if Dd /= "" and then Mm /= "" and then Yy /= "" then
                  Result.Has_Date := True;
                  Result.Day := (Day   => To_Nat (Dd),
                                 Month => To_Nat (Mm),
                                 Year  => To_Nat (Yy));
               end if;
            end;

         elsif Is_Type (Kind, "GLL") then
            --  $..GLL,lat,N/S,lon,E/W,hhmmss.ss,status,mode
            Result.Recognised := True;
            declare
               La : constant String := Field (P, 1);
               Ns : constant String := Field (P, 2);
               Lo : constant String := Field (P, 3);
               Ew : constant String := Field (P, 4);
               Tm : constant String := Field (P, 5);
               St : constant String := Field (P, 6);
            begin
               Result.Fix_Valid := St = "A";
               if Tm /= "" then
                  Result.Has_Time := True;
                  Result.Time := To_Time (Tm);
               end if;
               if Result.Fix_Valid and then La /= "" and then Lo /= "" then
                  Result.Has_Position := True;
                  Result.Pos := (Latitude  => Coord (La, (if Ns = "" then 'N'
                                                          else Ns (Ns'First))),
                                 Longitude => Coord (Lo, (if Ew = "" then 'E'
                                                          else Ew (Ew'First))));
               end if;
            end;

         elsif Is_Type (Kind, "VTG") then
            --  $..VTG,course_true,T,course_mag,M,speed_kn,N,speed_kmh,K,mode
            --  Velocity only.  The NMEA 2.3+ mode field (9) reports 'N' when the
            --  data is invalid; absent mode is treated as valid.
            Result.Recognised := True;
            declare
               Cog  : constant String := Field (P, 1);   --  true course, degrees
               Spd  : constant String := Field (P, 5);   --  knots
               Mode : constant String := Field (P, 9);   --  may be absent
            begin
               if Mode /= "N" and then (Spd /= "" or else Cog /= "") then
                  Result.Has_Velocity := True;
                  Result.Speed_MMS :=
                    Natural (LLI (Scaled (Spd, 3)) * 1852 / 3600);
                  Result.Course_CDeg := Scaled (Cog, 2);
               end if;
            end;

         elsif Is_Type (Kind, "GSV") then
            --  $..GSV,total,msg#,in_view,{prn,elev,azim,snr} x up to 4[,signalId]
            --  Read only as many satellite blocks as this message actually holds
            --  (derived from in_view + message number) -- otherwise a trailing
            --  NMEA-4.10 signalId field is misread as a PRN.
            Result.Recognised := True;
            declare
               Msg_No : constant Natural := To_Nat (Field (P, 2));
               View   : constant String := Field (P, 3);
               In_V   : constant Natural := To_Nat (View);
               Sys    : constant GNSS_System := System_Of (Kind);
               Before : constant Natural :=
                 (if Msg_No >= 1 then 4 * (Msg_No - 1) else 0);
               Here   : constant Natural :=
                 (if In_V > Before then Natural'Min (4, In_V - Before) else 0);
               Best   : Natural := 0;
               N      : Natural := 0;
            begin
               if View /= "" then
                  Result.In_View := In_V;
               end if;
               for K in 0 .. Here - 1 loop
                  declare
                     Prn : constant String := Field (P, 4 + 4 * K);
                     Elv : constant String := Field (P, 5 + 4 * K);
                     Azm : constant String := Field (P, 6 + 4 * K);
                     Snr : constant String := Field (P, 7 + 4 * K);
                  begin
                     if Prn /= "" then
                        N := N + 1;
                        Result.Sats (N) := (System    => Sys,
                                            PRN       => To_Nat (Prn),
                                            Elevation => To_Nat (Elv),
                                            Azimuth   => To_Nat (Azm),
                                            SNR       => To_Nat (Snr));
                        if Snr /= "" then
                           Best := Natural'Max (Best, To_Nat (Snr));
                        end if;
                     end if;
                  end;
               end loop;
               Result.Sat_Count := N;
               Result.Max_SNR := Best;
               Result.Has_Sky := View /= "" or else N > 0;
            end;

         elsif Is_Type (Kind, "GSA") then
            --  $..GSA,mode,fixtype,{prn} x12,PDOP,HDOP,VDOP
            Result.Recognised := True;
            declare
               FT : constant Natural := To_Nat (Field (P, 2));
               N  : Natural := 0;
            begin
               Result.Has_DOP := True;
               Result.Mode := (case FT is
                                  when 2      => Fix_2D,
                                  when 3      => Fix_3D,
                                  when others => Fix_None);
               for K in 3 .. 14 loop
                  if Field (P, K) /= "" then
                     N := N + 1;
                  end if;
               end loop;
               Result.Used   := N;
               Result.PDOP_C := Scaled (Field (P, 15), 2);
               Result.HDOP_C := Scaled (Field (P, 16), 2);
               Result.VDOP_C := Scaled (Field (P, 17), 2);
            end;
         end if;
      end;
   end Parse;

end ESP32S3.GPS.NMEA;
