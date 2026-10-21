--  The screen: a grid of (character, attribute) cells that everything draws
--  into, and Flush, which sends the terminal only the cells that changed.
--
--  Coordinates are 1-based (column X, row Y), like the terminal's own.
--  Drawing outside the clip rectangle is silently dropped, so a window can
--  draw its contents without checking its own edges.

package Turbo.Screen is

   type Cell is record
      Ch : Wide_Wide_Character := ' ';
      A  : Attribute := Light_Gray / Black;
   end record;

   --  The characters the Turbo look is made of (code page 437 in the
   --  original, Unicode here).

   H_Single  : constant Wide_Wide_Character := Wide_Wide_Character'Val (16#2500#);
   V_Single  : constant Wide_Wide_Character := Wide_Wide_Character'Val (16#2502#);
   TL_Single : constant Wide_Wide_Character := Wide_Wide_Character'Val (16#250C#);
   TR_Single : constant Wide_Wide_Character := Wide_Wide_Character'Val (16#2510#);
   BL_Single : constant Wide_Wide_Character := Wide_Wide_Character'Val (16#2514#);
   BR_Single : constant Wide_Wide_Character := Wide_Wide_Character'Val (16#2518#);
   H_Double  : constant Wide_Wide_Character := Wide_Wide_Character'Val (16#2550#);
   V_Double  : constant Wide_Wide_Character := Wide_Wide_Character'Val (16#2551#);
   TL_Double : constant Wide_Wide_Character := Wide_Wide_Character'Val (16#2554#);
   TR_Double : constant Wide_Wide_Character := Wide_Wide_Character'Val (16#2557#);
   BL_Double : constant Wide_Wide_Character := Wide_Wide_Character'Val (16#255A#);
   BR_Double : constant Wide_Wide_Character := Wide_Wide_Character'Val (16#255D#);
   L_Tee     : constant Wide_Wide_Character := Wide_Wide_Character'Val (16#251C#);
   R_Tee     : constant Wide_Wide_Character := Wide_Wide_Character'Val (16#2524#);
   Shade_1   : constant Wide_Wide_Character := Wide_Wide_Character'Val (16#2591#);
   Shade_2   : constant Wide_Wide_Character := Wide_Wide_Character'Val (16#2592#);
   Full_Block : constant Wide_Wide_Character := Wide_Wide_Character'Val (16#2588#);
   Upper_Half : constant Wide_Wide_Character := Wide_Wide_Character'Val (16#2580#);
   Lower_Half : constant Wide_Wide_Character := Wide_Wide_Character'Val (16#2584#);
   Square    : constant Wide_Wide_Character := Wide_Wide_Character'Val (16#25A0#);
   Arrow_Up  : constant Wide_Wide_Character := Wide_Wide_Character'Val (16#25B2#);
   Arrow_Dn  : constant Wide_Wide_Character := Wide_Wide_Character'Val (16#25BC#);
   Arrow_Lt  : constant Wide_Wide_Character := Wide_Wide_Character'Val (16#25C4#);
   Arrow_Rt  : constant Wide_Wide_Character := Wide_Wide_Character'Val (16#25BA#);
   Up_Arrow  : constant Wide_Wide_Character := Wide_Wide_Character'Val (16#2191#);
   Up_Down   : constant Wide_Wide_Character := Wide_Wide_Character'Val (16#2195#);
   Triple_Bar : constant Wide_Wide_Character := Wide_Wide_Character'Val (16#2261#);
   Check     : constant Wide_Wide_Character := Wide_Wide_Character'Val (16#221A#);
   Bullet    : constant Wide_Wide_Character := Wide_Wide_Character'Val (16#2022#);
   Middle_Dot : constant Wide_Wide_Character := Wide_Wide_Character'Val (16#00B7#);
   Small_Right : constant Wide_Wide_Character := Wide_Wide_Character'Val (16#25BA#);

   procedure Init;
   --  Size the grid to the terminal.  Call again after a resize.

   function Width return Positive;
   function Height return Positive;

   procedure Set_True_Color (On : Boolean);
   --  24-bit colour gives the exact CGA palette (brown is brown); off, the
   --  sixteen ANSI colours, which follow the terminal's own palette.

   function True_Color return Boolean;

   --  Clipping

   procedure Set_Clip (X1, Y1, X2, Y2 : Integer);
   procedure Reset_Clip;

   --  Drawing

   procedure Put (X, Y : Integer; C : Wide_Wide_Character; A : Attribute);
   procedure Put_Wide (X, Y : Integer; S : Wide_Wide_String; A : Attribute);
   procedure Put (X, Y : Integer; S : String; A : Attribute);
   --  A String is Latin-1: one Character, one cell.

   procedure Put_Hot (X, Y : Integer; S : String; Normal, Hot : Attribute);
   --  "~F~ile": the characters between tildes in Hot.

   function Hot_Length (S : String) return Natural;
   --  The displayed length of a Put_Hot label (tildes not counted).

   function Hot_Key (S : String) return Character;
   --  The lower-cased character after the first tilde, or NUL.

   procedure Fill
     (X, Y, W, H : Integer; C : Wide_Wide_Character; A : Attribute);

   procedure Paint (X, Y, W, H : Integer; A : Attribute);
   --  Change the attribute, keep the characters.

   procedure Shadow (X, Y, W, H : Integer);
   --  The Turbo drop shadow: what is underneath, in dark gray on black.

   procedure Frame
     (X, Y, W, H : Integer; A : Attribute; Double : Boolean);

   function Get (X, Y : Integer) return Cell;

   --  Cursor

   procedure Set_Cursor (X, Y : Integer; Block : Boolean := False);
   --  Show the hardware cursor at X, Y after the next Flush.  Block for
   --  overwrite mode, an underline for insert (as Turbo C did).

   procedure Hide_Cursor;

   procedure Flush;
   --  Send the changes since the last Flush.

   procedure Invalidate;
   --  The next Flush repaints every cell (after a child program has used the
   --  terminal, or a resize).

end Turbo.Screen;
