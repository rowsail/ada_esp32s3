--  Bouncing solid-colour 3D cube on a 240x240 ST7789 panel (bare-metal
--  ESP32-S3, no FreeRTOS, no IDF)
--  ====================================================================
--  What it demonstrates: software 3D rendering driving the ESP32S3.ST7789
--  display HAL -- a rotating cube with each visible face flat-shaded in its own
--  colour (perspective projection + hidden-surface removal, black facet seams),
--  its bounding window bouncing around the edges of the screen.
--
--  Build & run: `./x run esp32s3_st7789_cube`.  Needs the EMBEDDED profile (the
--  controlled-Session display driver); the example's build.sh selects it
--  (ESP32S3_RTS_PROFILE=embedded).
--
--  Output: a two-line banner then a "~NN fps" line about once a second:
--    [cube] bouncing solid-colour 3D cube -> ST7789 240x240
--    [cube]   SPI2 sclk=12 mosi=13 dc=16 cs=10 bl=6
--    [cube] ~57 fps
--  The cube itself appears on the panel.
--
--  Hardware: an ST7789 240x240 panel on SPI2 -- SCLK=IO12, MOSI=IO13,
--  DC (data/command)=IO16, CS=IO10; backlight on IO6, driven by this example.
--  RST is not wired (software reset).
--
--  Rendering (the panel is write-only -- no framebuffer to read back):
--    * The cube is drawn into a small in-RAM framebuffer
--      (FB_Width x FB_Width RGB565) that is a moving WINDOW always containing the
--      whole cube.  Each frame the framebuffer is cleared, the cube is
--      rasterised into it, and it is blitted with ESP32S3.ST7789.Draw_Bitmap at
--      the window's current position.
--    * The window bounces around the 240x240 limits.  Only the thin strips the
--      window UNCOVERS as it moves are cleared to black (Fill_Rect) -- no
--      full-screen clears, so there is no flicker and no trails.
--
--  Hidden-surface removal: for a convex cube, the visible faces are exactly the
--  front-facing ones (back-face culling).  Each face's outward normal is
--  rotated; if it points toward the EYE point (perspective test, Render_Cube)
--  the face is filled solid (scanline) in its colour and outlined in black.  A
--  convex cube's front faces tile the silhouette with no overlap, so they can be
--  filled in any order with no depth sort.
--
--  Maths is fixed-point Q12 integers with an embedded sine table -- no libm /
--  trig dependency, no floating point needed.
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.GPIO;
with ESP32S3.Log;    use ESP32S3.Log;
with ESP32S3.ST7789;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   package LCD renames ESP32S3.ST7789;

   --  ST7789 SPI2 pins (wiring is in the header / README).
   Sclk_Pin      : constant := 12;
   Mosi_Pin      : constant := 13;
   Data_Cmd_Pin  : constant := 16;   --  DC: command/data select line
   Chip_Sel_Pin  : constant := 10;
   Backlight_Pin : constant ESP32S3.GPIO.Pin_Id := 6;

   Screen : constant := 240;         --  panel is 240 x 240 pixels

   --  Fixed-point format: all geometry maths is Q12 (12 fraction bits), so the
   --  value 1.0 is represented by 4096 and a Q12*Q12 product is divided by One
   --  to bring it back to Q12.
   One : constant := 4096;           --  1.0 in Q12

   --  Moving framebuffer window: big enough to hold the rotating cube under
   --  perspective (near faces project larger -- sized from a host sweep so the
   --  worst-case vertex stays inside).
   FB_Width : constant := 128;          --  framebuffer window edge, pixels
   Centre   : constant := FB_Width / 2; --  projection origin within the window

   --  Perspective: eye on +Z at distance Eye (Q12); a vertex projects to
   --  Centre + coord * Focal / (Eye - z), so nearer (larger z) faces are bigger.
   --  Focal is the projection-plane distance in pixels.
   Eye   : constant := 4 * One;
   Focal : constant := 120;

   Device  : LCD.Device;
   Session : LCD.Session;

   --  The framebuffer (row-major RGB565), held in internal RAM.
   Framebuffer : LCD.Color_Array (0 .. FB_Width * FB_Width - 1) :=
     (others => LCD.Black);

   --  Q12 sine table: 4096 * sin, sampled at Table_Steps points around the full
   --  circle (so one table step = 360/256 degrees).  Generated once, offline.
   Table_Steps : constant := 256;
   Sine_Table  : constant array (0 .. Table_Steps - 1) of Integer :=
     (
           0,    101,    201,    301,    401,    501,    601,    700,
         799,    897,    995,   1092,   1189,   1285,   1380,   1474,
        1567,   1660,   1751,   1842,   1931,   2019,   2106,   2191,
        2276,   2359,   2440,   2520,   2598,   2675,   2751,   2824,
        2896,   2967,   3035,   3102,   3166,   3229,   3290,   3349,
        3406,   3461,   3513,   3564,   3612,   3659,   3703,   3745,
        3784,   3822,   3857,   3889,   3920,   3948,   3973,   3996,
        4017,   4036,   4052,   4065,   4076,   4085,   4091,   4095,
        4096,   4095,   4091,   4085,   4076,   4065,   4052,   4036,
        4017,   3996,   3973,   3948,   3920,   3889,   3857,   3822,
        3784,   3745,   3703,   3659,   3612,   3564,   3513,   3461,
        3406,   3349,   3290,   3229,   3166,   3102,   3035,   2967,
        2896,   2824,   2751,   2675,   2598,   2520,   2440,   2359,
        2276,   2191,   2106,   2019,   1931,   1842,   1751,   1660,
        1567,   1474,   1380,   1285,   1189,   1092,    995,    897,
         799,    700,    601,    501,    401,    301,    201,    101,
           0,   -101,   -201,   -301,   -401,   -501,   -601,   -700,
        -799,   -897,   -995,  -1092,  -1189,  -1285,  -1380,  -1474,
       -1567,  -1660,  -1751,  -1842,  -1931,  -2019,  -2106,  -2191,
       -2276,  -2359,  -2440,  -2520,  -2598,  -2675,  -2751,  -2824,
       -2896,  -2967,  -3035,  -3102,  -3166,  -3229,  -3290,  -3349,
       -3406,  -3461,  -3513,  -3564,  -3612,  -3659,  -3703,  -3745,
       -3784,  -3822,  -3857,  -3889,  -3920,  -3948,  -3973,  -3996,
       -4017,  -4036,  -4052,  -4065,  -4076,  -4085,  -4091,  -4095,
       -4096,  -4095,  -4091,  -4085,  -4076,  -4065,  -4052,  -4036,
       -4017,  -3996,  -3973,  -3948,  -3920,  -3889,  -3857,  -3822,
       -3784,  -3745,  -3703,  -3659,  -3612,  -3564,  -3513,  -3461,
       -3406,  -3349,  -3290,  -3229,  -3166,  -3102,  -3035,  -2967,
       -2896,  -2824,  -2751,  -2675,  -2598,  -2520,  -2440,  -2359,
       -2276,  -2191,  -2106,  -2019,  -1931,  -1842,  -1751,  -1660,
       -1567,  -1474,  -1380,  -1285,  -1189,  -1092,   -995,   -897,
        -799,   -700,   -601,   -501,   -401,   -301,   -201,   -101);

   --  A quarter-circle is Table_Steps/4 steps, which turns sine into cosine.
   Quarter_Turn : constant := Table_Steps / 4;

   function Sin (Angle : Integer) return Integer is
     (Sine_Table (Angle mod Table_Steps));
   function Cos (Angle : Integer) return Integer is
     (Sine_Table ((Angle + Quarter_Turn) mod Table_Steps));

   type Vector_3D is record
      X, Y, Z : Integer;            --  Q12 coordinates
   end record;

   --  Eight cube vertices (+/-1 on each axis), Q12.
   Vertex_Count : constant := 8;
   Vertices     : constant array (0 .. Vertex_Count - 1) of Vector_3D :=
     ((-One, -One, -One), (One, -One, -One), (One, One, -One), (-One, One, -One),
      (-One, -One,  One), (One, -One,  One), (One, One,  One), (-One, One,  One));

   --  Six faces: an outward normal, the four corner vertices in boundary order,
   --  and the colour to draw that face's edges in (a distinct hue per face -- a
   --  shared visible edge takes the colour of whichever front face draws last).
   type Corner_Indices is array (0 .. 3) of Integer;   --  indices into Vertices
   type Face is record
      Normal : Vector_3D;           --  outward unit (Q12) normal
      Corner : Corner_Indices;      --  the four corners, in boundary order
      Colour : LCD.Color;           --  fill/edge hue for this face
   end record;

   Face_Count : constant := 6;
   Faces      : constant array (0 .. Face_Count - 1) of Face :=
     (((0, 0, -One), (0, 1, 2, 3), LCD.RGB (255,  40,  40)),   --  -Z  red
      ((0, 0,  One), (4, 5, 6, 7), LCD.RGB ( 60, 255,  60)),   --  +Z  green
      ((0, -One, 0), (0, 1, 5, 4), LCD.RGB ( 60, 120, 255)),   --  -Y  blue
      ((0,  One, 0), (3, 2, 6, 7), LCD.RGB (255, 230,   0)),   --  +Y  yellow
      ((-One, 0, 0), (0, 3, 7, 4), LCD.RGB (230,  60, 255)),   --  -X  magenta
      (( One, 0, 0), (1, 2, 6, 5), LCD.RGB (  0, 230, 255)));  --  +X  cyan

   --  Projected pixel coordinates of each vertex within the framebuffer window.
   Screen_X : array (0 .. Vertex_Count - 1) of Integer;
   Screen_Y : array (0 .. Vertex_Count - 1) of Integer;

   --  Rotation angles (table steps) and the moving-window state.
   --  Motion is paced in 1/Sub_Steps sub-steps so rotation and bounce advance
   --  well under one unit per frame -- the cube moves slowly and is easy to
   --  follow -- WITHOUT touching the frame rate (the loop delay below is
   --  unchanged).  Larger Sub_Steps = slower motion.
   Sub_Steps : constant := 6;

   --  Per-frame increments: how many sub-steps each accumulator advances.
   Angle_X_Step : constant := 2;   --  X-axis spin, sub-steps per frame
   Angle_Y_Step : constant := 3;   --  Y-axis spin, sub-steps per frame

   --  Angle accumulators, in 1/Sub_Steps table steps; divide by Sub_Steps for
   --  the table index.
   Angle_X : Integer := 0;
   Angle_Y : Integer := 0;

   --  Moving-window top-left position accumulators, in 1/Sub_Steps pixels.
   Window_X_Acc : Integer := 12 * Sub_Steps;   --  initial top-left, x
   Window_Y_Acc : Integer := 20 * Sub_Steps;   --  initial top-left, y

   --  Window velocity, in 1/Sub_Steps pixels per frame.
   Velocity_X : Integer := 2;
   Velocity_Y : Integer := 3;

   --  Integer window top-left this frame (the accumulator / Sub_Steps) ...
   Window_X : Integer := 0;
   Window_Y : Integer := 0;
   --  ... and the previous frame's, to know which strips to repaint.
   Prev_Window_X : Integer;
   Prev_Window_Y : Integer;

   --  Rotate a Q12 vector by Angle_Y (about Y) then Angle_X (about X), given the
   --  pre-computed Q12 cos/sin of each angle.  Cos_X/Sin_X are for the X-axis
   --  rotation, Cos_Y/Sin_Y for the Y-axis one.
   function Rotate
     (V            : Vector_3D;
      Cos_X, Sin_X : Integer;
      Cos_Y, Sin_Y : Integer) return Vector_3D
   is
      --  Y-axis rotation first (mixes X and Z); divide each Q12*Q12 by One.
      Rot_X : constant Integer := (V.X * Cos_Y + V.Z * Sin_Y) / One;
      Mid_Z : constant Integer := (V.Z * Cos_Y - V.X * Sin_Y) / One;
      --  then X-axis rotation (mixes the new Y and Z).
      Rot_Y : constant Integer := (V.Y * Cos_X - Mid_Z * Sin_X) / One;
      Rot_Z : constant Integer := (Mid_Z * Cos_X + V.Y * Sin_X) / One;
   begin
      return (Rot_X, Rot_Y, Rot_Z);
   end Rotate;

   --  Set one framebuffer pixel (clipped to the window).
   procedure Plot (X, Y : Integer; Colour : LCD.Color) is
   begin
      if X in 0 .. FB_Width - 1 and then Y in 0 .. FB_Width - 1 then
         Framebuffer (Y * FB_Width + X) := Colour;
      end if;
   end Plot;

   --  Scanline-fill the convex quad given by corner indices Corner in colour
   --  Colour.  For each row, the polygon's two edge crossings bound the span.
   procedure Fill_Face (Corner : Corner_Indices; Colour : LCD.Color) is
      Y_Min : Integer := FB_Width;
      Y_Max : Integer := -1;
   begin
      for K in 0 .. 3 loop
         Y_Min := Integer'Min (Y_Min, Screen_Y (Corner (K)));
         Y_Max := Integer'Max (Y_Max, Screen_Y (Corner (K)));
      end loop;
      Y_Min := Integer'Max (Y_Min, 0);
      Y_Max := Integer'Min (Y_Max, FB_Width - 1);

      for Y in Y_Min .. Y_Max loop
         declare
            Span_Left  : Integer := FB_Width;   --  leftmost crossing on this row
            Span_Right : Integer := -1;         --  rightmost crossing
         begin
            for K in 0 .. 3 loop
               declare
                  --  Edge from corner A to the next corner B (wrapping).
                  Ax : constant Integer := Screen_X (Corner (K));
                  Ay : constant Integer := Screen_Y (Corner (K));
                  Bx : constant Integer := Screen_X (Corner ((K + 1) mod 4));
                  By : constant Integer := Screen_Y (Corner ((K + 1) mod 4));
               begin
                  --  Half-open span [min(Ay,By), max) so each row counts an
                  --  edge once and vertices aren't double-counted.
                  if (Ay <= Y and then Y < By)
                    or else (By <= Y and then Y < Ay)
                  then
                     declare
                        --  X where this edge crosses scanline Y.
                        X : constant Integer :=
                          Ax + (Bx - Ax) * (Y - Ay) / (By - Ay);
                     begin
                        Span_Left  := Integer'Min (Span_Left, X);
                        Span_Right := Integer'Max (Span_Right, X);
                     end;
                  end if;
               end;
            end loop;

            if Span_Right >= Span_Left then
               Span_Left  := Integer'Max (Span_Left, 0);
               Span_Right := Integer'Min (Span_Right, FB_Width - 1);
               for X in Span_Left .. Span_Right loop
                  Framebuffer (Y * FB_Width + X) := Colour;
               end loop;
            end if;
         end;
      end loop;
   end Fill_Face;

   --  Bresenham line into the framebuffer.
   procedure Line (X0, Y0, X1, Y1 : Integer; Colour : LCD.Color) is
      Delta_X : constant Integer := abs (X1 - X0);
      Delta_Y : constant Integer := abs (Y1 - Y0);
      Step_X  : constant Integer := (if X0 < X1 then 1 else -1);
      Step_Y  : constant Integer := (if Y0 < Y1 then 1 else -1);
      Error      : Integer := Delta_X - Delta_Y;   --  running decision variable
      Twice_Error : Integer;
      X : Integer := X0;
      Y : Integer := Y0;
   begin
      loop
         Plot (X, Y, Colour);
         exit when X = X1 and then Y = Y1;
         Twice_Error := 2 * Error;
         if Twice_Error > -Delta_Y then
            Error := Error - Delta_Y;
            X := X + Step_X;
         end if;
         if Twice_Error < Delta_X then
            Error := Error + Delta_X;
            Y := Y + Step_Y;
         end if;
      end loop;
   end Line;

   procedure Render_Cube is
      --  Q12 cos/sin of each rotation angle (accumulator -> table step).
      Cos_X : constant Integer := Cos (Angle_X / Sub_Steps);
      Sin_X : constant Integer := Sin (Angle_X / Sub_Steps);
      Cos_Y : constant Integer := Cos (Angle_Y / Sub_Steps);
      Sin_Y : constant Integer := Sin (Angle_Y / Sub_Steps);
      Rotated : Vector_3D;
   begin
      --  Clear the window, rotate + perspective-project the 8 vertices.
      Framebuffer := (others => LCD.Black);
      for I in Vertices'Range loop
         Rotated := Rotate (Vertices (I), Cos_X, Sin_X, Cos_Y, Sin_Y);
         declare
            --  Perspective denominator Eye - z; always > 0 (Eye > max |z|).
            Depth : constant Integer := Eye - Rotated.Z;
         begin
            Screen_X (I) := Centre + (Rotated.X * Focal) / Depth;
            Screen_Y (I) := Centre + (Rotated.Y * Focal) / Depth;
         end;
      end loop;

      --  Which faces point at the viewer (hidden-surface removal: a convex
      --  cube's front faces tile the silhouette with no overlap, so they can be
      --  filled in any order with no depth sort).
      --
      --  PERSPECTIVE back-face test: a face is visible iff its outward normal
      --  points toward the EYE point, dot(N, Eye - C) > 0.  For this cube the
      --  rotated face centre C equals the rotated normal Nr (each face centre
      --  lies one unit along its normal), so this reduces to Nr.z*Eye > |Nr|^2 =
      --  One^2.  (Using the orthographic test Nr.z > 0 would wrongly draw faces
      --  with 0 < Nr.z < One^2/Eye, which are back-facing under perspective.)
      declare
         Visible : array (Faces'Range) of Boolean;
      begin
         for I in Faces'Range loop
            Visible (I) :=
              Rotate (Faces (I).Normal, Cos_X, Sin_X, Cos_Y, Sin_Y).Z * Eye
                > One * One;
         end loop;

         --  Fill pass: each visible face solid in its own colour.
         for I in Faces'Range loop
            if Visible (I) then
               Fill_Face (Faces (I).Corner, Faces (I).Colour);
            end if;
         end loop;

         --  Edge pass: black facet outlines on top for crisp seams.
         for I in Faces'Range loop
            if Visible (I) then
               for K in 0 .. 3 loop
                  declare
                     A : constant Integer := Faces (I).Corner (K);
                     B : constant Integer := Faces (I).Corner ((K + 1) mod 4);
                  begin
                     Line (Screen_X (A), Screen_Y (A),
                           Screen_X (B), Screen_Y (B), LCD.Black);
                  end;
               end loop;
            end if;
         end loop;
      end;
   end Render_Cube;

   --  Clear the strips the window uncovers moving from the previous window
   --  position (Prev_Window_X, Prev_Window_Y) to (Window_X, Window_Y).
   procedure Clear_Trail is
   begin
      if Window_X > Prev_Window_X then
         LCD.Fill_Rect (Session, Prev_Window_X, Prev_Window_Y,
                        Window_X - Prev_Window_X, FB_Width, LCD.Black);
      elsif Window_X < Prev_Window_X then
         LCD.Fill_Rect (Session, Window_X + FB_Width, Prev_Window_Y,
                        Prev_Window_X - Window_X, FB_Width, LCD.Black);
      end if;
      if Window_Y > Prev_Window_Y then
         LCD.Fill_Rect (Session, Prev_Window_X, Prev_Window_Y,
                        FB_Width, Window_Y - Prev_Window_Y, LCD.Black);
      elsif Window_Y < Prev_Window_Y then
         LCD.Fill_Rect (Session, Prev_Window_X, Window_Y + FB_Width,
                        FB_Width, Prev_Window_Y - Window_Y, LCD.Black);
      end if;
   end Clear_Trail;

   --  Furthest top-left position the window may reach on each axis, in pixels.
   Window_Max : constant := Screen - FB_Width;

   Frame_Count    : Integer := 0;
   Last_Fps_Stamp : Time;
begin
   delay until Clock + Milliseconds (200);
   Put_Line ("[cube] bouncing solid-colour 3D cube -> ST7789 240x240");
   Put_Line ("[cube]   SPI2 sclk=12 mosi=13 dc=16 cs=10 bl=6");

   ESP32S3.GPIO.Configure (Backlight_Pin, Mode => ESP32S3.GPIO.Output);
   ESP32S3.GPIO.Set (Backlight_Pin);

   LCD.Setup (Device,
              Sclk => Sclk_Pin,
              Mosi => Mosi_Pin,
              DC   => Data_Cmd_Pin,
              CS   => Chip_Sel_Pin);
   LCD.Acquire (Session, Device);
   LCD.Init (Session);
   LCD.Fill (Session, LCD.Black);

   Window_X      := Window_X_Acc / Sub_Steps;
   Window_Y      := Window_Y_Acc / Sub_Steps;
   Prev_Window_X := Window_X;
   Prev_Window_Y := Window_Y;
   Last_Fps_Stamp := Clock;

   loop
      Window_X := Window_X_Acc / Sub_Steps;   --  integer window position
      Window_Y := Window_Y_Acc / Sub_Steps;
      Render_Cube;
      Clear_Trail;
      LCD.Draw_Bitmap (Session, Window_X, Window_Y, FB_Width, FB_Width,
                       Framebuffer);

      --  Advance rotation (1/Sub_Steps table steps per frame); wrap at a full
      --  turn expressed in sub-steps.
      Angle_X := (Angle_X + Angle_X_Step) mod (Table_Steps * Sub_Steps);
      Angle_Y := (Angle_Y + Angle_Y_Step) mod (Table_Steps * Sub_Steps);

      --  Advance + bounce the window within [0 .. Window_Max] (sub-pixel).
      Prev_Window_X := Window_X;
      Prev_Window_Y := Window_Y;
      Window_X_Acc := Window_X_Acc + Velocity_X;
      Window_Y_Acc := Window_Y_Acc + Velocity_Y;
      if Window_X_Acc <= 0 then
         Window_X_Acc := 0;
         Velocity_X := -Velocity_X;
      elsif Window_X_Acc >= Window_Max * Sub_Steps then
         Window_X_Acc := Window_Max * Sub_Steps;
         Velocity_X := -Velocity_X;
      end if;
      if Window_Y_Acc <= 0 then
         Window_Y_Acc := 0;
         Velocity_Y := -Velocity_Y;
      elsif Window_Y_Acc >= Window_Max * Sub_Steps then
         Window_Y_Acc := Window_Max * Sub_Steps;
         Velocity_Y := -Velocity_Y;
      end if;

      --  Report frame-rate roughly once a second.
      Frame_Count := Frame_Count + 1;
      if To_Duration (Clock - Last_Fps_Stamp) >= 1.0 then
         Put ("[cube] ~");
         Put (Frame_Count);
         Put_Line (" fps");
         Frame_Count := 0;
         Last_Fps_Stamp := Clock;
      end if;

      delay until Clock + Milliseconds (8);   --  pace the animation
   end loop;
end Main;
