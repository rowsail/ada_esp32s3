--  Bouncing hidden-line wireframe cube on a 240x240 ST7789 panel (bare-metal
--  ESP32-S3, no FreeRTOS, no IDF).  A rotating 3D cube drawn with hidden-line
--  removal and perspective, each visible face's edges in its own colour, its
--  bounding window bouncing around the edges of the screen.
--
--  Rendering (the panel is write-only -- no framebuffer to read back):
--    * The cube is drawn into a small in-RAM framebuffer (FB_W x FB_W RGB565)
--      that is a moving WINDOW always containing the whole cube.  Each frame the
--      FB is cleared, the cube is rasterised into it, and it is blitted with
--      ESP32S3.ST7789.Draw_Bitmap at the window's current position.
--    * The window bounces around the 240x240 limits.  Only the thin strips the
--      window UNCOVERS as it moves are cleared to black (Fill_Rect) -- no
--      full-screen clears, so there is no flicker and no trails.
--
--  Hidden-line removal: for a convex cube, HLR is back-face culling.  Each
--  face's outward normal is rotated; if it points toward the viewer (rotated
--  normal z > 0) the face is front-facing and its four edges are drawn (in that
--  face's colour).  Edges shared only by back faces are never drawn -- hidden.
--
--  Maths is fixed-point Q12 integers with an embedded sine table -- no libm /
--  trig dependency, no floating point needed.
--
--  Display: SPI2 SCLK=IO12 MOSI=IO13 DC=IO16 CS=IO10; backlight IO6 driven HERE.
with Interfaces.C; use Interfaces.C;
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.GPIO;
with ESP32S3.ST7789;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   package LCD renames ESP32S3.ST7789;

   procedure Banner;  pragma Import (C, Banner, "native_cube_banner");
   procedure Fps_C (N : int);
                      pragma Import (C, Fps_C, "native_cube_fps");

   Backlight : constant ESP32S3.GPIO.Pin_Id := 6;
   Screen    : constant := 240;

   One : constant := 4096;         --  1.0 in Q12

   --  Moving framebuffer window: big enough to hold the rotating cube under
   --  perspective (near faces project larger -- sized from a host sweep so the
   --  worst-case vertex stays inside).
   FB_W   : constant := 128;
   Centre : constant := FB_W / 2;

   --  Perspective: eye on +Z at distance Eye (Q12); a vertex projects to
   --  Centre + coord * Focal / (Eye - z), so nearer (larger z) faces are bigger.
   Eye   : constant := 4 * One;
   Focal : constant := 120;

   Dev : LCD.Device;
   S   : LCD.Session;

   --  The framebuffer (row-major RGB565), held in internal RAM.
   FB : LCD.Color_Array (0 .. FB_W * FB_W - 1) := (others => LCD.Black);

   --  Q12 sine table (4096 * sin), 256 steps around the circle.
   Sin_T : constant array (0 .. 255) of Integer :=
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

   function Sin (A : Integer) return Integer is (Sin_T (A mod 256));
   function Cos (A : Integer) return Integer is (Sin_T ((A + 64) mod 256));

   type Vec3 is record X, Y, Z : Integer; end record;   --  Q12

   --  Eight cube vertices (+/-1 on each axis), Q12.
   Verts : constant array (0 .. 7) of Vec3 :=
     ((-One, -One, -One), (One, -One, -One), (One, One, -One), (-One, One, -One),
      (-One, -One,  One), (One, -One,  One), (One, One,  One), (-One, One,  One));

   --  Six faces: an outward normal, the four corner vertices in boundary order,
   --  and the colour to draw that face's edges in (a distinct hue per face -- a
   --  shared visible edge takes the colour of whichever front face draws last).
   type Corners is array (0 .. 3) of Integer;
   type Face is record
      N    : Vec3;
      Corn : Corners;
      Col  : LCD.Color;
   end record;

   Faces : constant array (0 .. 5) of Face :=
     (((0, 0, -One), (0, 1, 2, 3), LCD.RGB (255,  40,  40)),   --  -Z  red
      ((0, 0,  One), (4, 5, 6, 7), LCD.RGB ( 60, 255,  60)),   --  +Z  green
      ((0, -One, 0), (0, 1, 5, 4), LCD.RGB ( 60, 120, 255)),   --  -Y  blue
      ((0,  One, 0), (3, 2, 6, 7), LCD.RGB (255, 230,   0)),   --  +Y  yellow
      ((-One, 0, 0), (0, 3, 7, 4), LCD.RGB (230,  60, 255)),   --  -X  magenta
      (( One, 0, 0), (1, 2, 6, 5), LCD.RGB (  0, 230, 255)));  --  +X  cyan

   --  Projected screen coords of each vertex within the FB.
   SX, SY : array (0 .. 7) of Integer;

   --  Rotation angles (table steps) and the moving-window state.
   Ax : Integer := 0;
   Ay : Integer := 0;
   Px : Integer := 12;       --  FB window top-left
   Py : Integer := 20;
   Vx : Integer := 2;        --  window velocity
   Vy : Integer := 3;
   OPx, OPy : Integer;       --  previous window position (for strip clearing)

   --  Rotate a Q12 vector by Ay (about Y) then Ax (about X).
   function Rotate (V : Vec3; Cax, Sax, Cay, Say : Integer) return Vec3 is
      X1 : constant Integer := (V.X * Cay + V.Z * Say) / One;
      Z1 : constant Integer := (V.Z * Cay - V.X * Say) / One;
      Y2 : constant Integer := (V.Y * Cax - Z1 * Sax) / One;
      Z2 : constant Integer := (Z1 * Cax + V.Y * Sax) / One;
   begin
      return (X1, Y2, Z2);
   end Rotate;

   --  Set one FB pixel (clipped to the window).
   procedure Plot (X, Y : Integer; C : LCD.Color) is
   begin
      if X in 0 .. FB_W - 1 and then Y in 0 .. FB_W - 1 then
         FB (Y * FB_W + X) := C;
      end if;
   end Plot;

   --  Bresenham line into the FB.
   procedure Line (X0, Y0, X1, Y1 : Integer; C : LCD.Color) is
      DX : constant Integer := abs (X1 - X0);
      DY : constant Integer := abs (Y1 - Y0);
      Sx : constant Integer := (if X0 < X1 then 1 else -1);
      Sy : constant Integer := (if Y0 < Y1 then 1 else -1);
      Err : Integer := DX - DY;
      X   : Integer := X0;
      Y   : Integer := Y0;
      E2  : Integer;
   begin
      loop
         Plot (X, Y, C);
         exit when X = X1 and then Y = Y1;
         E2 := 2 * Err;
         if E2 > -DY then Err := Err - DY; X := X + Sx; end if;
         if E2 <  DX then Err := Err + DX; Y := Y + Sy; end if;
      end loop;
   end Line;

   procedure Render_Cube is
      Cax : constant Integer := Cos (Ax);
      Sax : constant Integer := Sin (Ax);
      Cay : constant Integer := Cos (Ay);
      Say : constant Integer := Sin (Ay);
      R   : Vec3;
   begin
      --  Clear the window, rotate + perspective-project the 8 vertices.
      FB := (others => LCD.Black);
      for I in Verts'Range loop
         R := Rotate (Verts (I), Cax, Sax, Cay, Say);
         declare
            Den : constant Integer := Eye - R.Z;   --  > 0 (Eye > max |z|)
         begin
            SX (I) := Centre + (R.X * Focal) / Den;
            SY (I) := Centre + (R.Y * Focal) / Den;
         end;
      end loop;

      --  Draw the edges of front-facing faces only (hidden-line removal), each
      --  in its own colour.
      for F of Faces loop
         if Rotate (F.N, Cax, Sax, Cay, Say).Z > 0 then    --  faces the viewer
            for K in 0 .. 3 loop
               declare
                  A : constant Integer := F.Corn (K);
                  B : constant Integer := F.Corn ((K + 1) mod 4);
               begin
                  Line (SX (A), SY (A), SX (B), SY (B), F.Col);
               end;
            end loop;
         end if;
      end loop;
   end Render_Cube;

   --  Clear the strips the window uncovers moving from (OPx,OPy) to (Px,Py).
   procedure Clear_Trail is
   begin
      if Px > OPx then
         LCD.Fill_Rect (S, OPx, OPy, Px - OPx, FB_W, LCD.Black);
      elsif Px < OPx then
         LCD.Fill_Rect (S, Px + FB_W, OPy, OPx - Px, FB_W, LCD.Black);
      end if;
      if Py > OPy then
         LCD.Fill_Rect (S, OPx, OPy, FB_W, Py - OPy, LCD.Black);
      elsif Py < OPy then
         LCD.Fill_Rect (S, OPx, Py + FB_W, FB_W, OPy - Py, LCD.Black);
      end if;
   end Clear_Trail;

   Frames : Integer := 0;
   T0     : Time;
begin
   delay until Clock + Milliseconds (200);
   Banner;

   ESP32S3.GPIO.Configure (Backlight, Mode => ESP32S3.GPIO.Output);
   ESP32S3.GPIO.Set (Backlight);

   LCD.Setup (Dev, Sclk => 12, Mosi => 13, DC => 16, CS => 10);
   LCD.Acquire (S, Dev);
   LCD.Init (S);
   LCD.Fill (S, LCD.Black);

   OPx := Px;
   OPy := Py;
   T0  := Clock;

   loop
      Render_Cube;
      Clear_Trail;
      LCD.Draw_Bitmap (S, Px, Py, FB_W, FB_W, FB);

      --  Advance rotation.
      Ax := (Ax + 2) mod 256;
      Ay := (Ay + 3) mod 256;

      --  Advance + bounce the window within [0 .. Screen - FB_W].
      OPx := Px;
      OPy := Py;
      Px := Px + Vx;
      Py := Py + Vy;
      if Px <= 0 then Px := 0; Vx := -Vx;
      elsif Px >= Screen - FB_W then Px := Screen - FB_W; Vx := -Vx;
      end if;
      if Py <= 0 then Py := 0; Vy := -Vy;
      elsif Py >= Screen - FB_W then Py := Screen - FB_W; Vy := -Vy;
      end if;

      --  Report frame-rate roughly once a second.
      Frames := Frames + 1;
      if To_Duration (Clock - T0) >= 1.0 then
         Fps_C (int (Frames));
         Frames := 0;
         T0 := Clock;
      end if;

      delay until Clock + Milliseconds (8);   --  pace the animation
   end loop;
end Main;
