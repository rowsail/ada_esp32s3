with Interfaces.C;

package body Turbo.Term is

   use Interfaces.C;

   ESC : constant Character := Character'Val (27);
   CSI : constant String := ESC & "[";

   Active : Boolean := False;

   function C_Init return int
     with Import, Convention => C, External_Name => "tada_term_init";
   procedure C_Restore
     with Import, Convention => C, External_Name => "tada_term_restore";
   function C_Read (Buf : out Byte_Array; Max : int; Timeout : int) return int
     with Import, Convention => C, External_Name => "tada_term_read";
   function C_Write (Buf : String; Len : int) return int
     with Import, Convention => C, External_Name => "tada_term_write";
   procedure C_Size (Rows, Cols : out int)
     with Import, Convention => C, External_Name => "tada_term_size";
   function C_Take_Resized return int
     with Import, Convention => C, External_Name => "tada_term_take_resized";
   function C_Is_Windows return int
     with Import, Convention => C, External_Name => "tada_is_windows";

   Enter_Sequence : constant String :=
     CSI & "?1049h"             --  alternate screen
     & CSI & "?25l"             --  cursor off until the first Flush
     & CSI & "?1000h"           --  mouse buttons
     & CSI & "?1002h"           --  ... and drags
     & CSI & "?1006h"           --  ... in SGR encoding (no 223-column limit)
     & CSI & "?2004h"           --  bracketed paste
     & CSI & "2J";

   Leave_Sequence : constant String :=
     CSI & "?2004l"
     & CSI & "?1006l"
     & CSI & "?1002l"
     & CSI & "?1000l"
     & CSI & "0m"
     & CSI & "0 q"              --  the terminal's own cursor shape
     & CSI & "?25h"
     & CSI & "?1049l";

   procedure Start is
   begin
      if Active then
         return;
      end if;
      if C_Init /= 0 then
         raise Not_A_Terminal;
      end if;
      Active := True;
      Write (Enter_Sequence);
   end Start;

   procedure Stop is
   begin
      if not Active then
         return;
      end if;
      Write (Leave_Sequence);
      C_Restore;
      Active := False;
   end Stop;

   procedure Wait_Key is
      Buf : Byte_Array (1 .. 64);
      N   : int;
   begin
      if Active or else C_Init /= 0 then
         return;
      end if;
      N := C_Read (Buf, Buf'Length, -1);
      --  Swallow the rest of an escape sequence (an arrow key, say).
      while N > 0 loop
         N := C_Read (Buf, Buf'Length, 30);
      end loop;
      C_Restore;
   end Wait_Key;

   procedure Show_User_Screen is
      Buf : Byte_Array (1 .. 64);
      N   : int;
   begin
      if not Active then
         return;
      end if;
      Write (CSI & "0m" & CSI & "?25l" & CSI & "?1049l");
      N := C_Read (Buf, Buf'Length, -1);
      while N > 0 loop
         N := C_Read (Buf, Buf'Length, 30);
      end loop;
      Write (CSI & "?1049h");
   end Show_User_Screen;

   function Read (Buf : out Byte_Array; Timeout_Ms : Integer) return Natural is
      N : int;
   begin
      N := C_Read (Buf, int (Buf'Length), int (Timeout_Ms));
      return (if N < 0 then 0 else Natural (N));
   end Read;

   procedure Write (S : String) is
      Ignore : int;
   begin
      if S'Length > 0 then
         Ignore := C_Write (S, int (S'Length));
      end if;
   end Write;

   procedure Size (Rows, Cols : out Positive) is
      R, C : int;
   begin
      C_Size (R, C);
      Rows := Positive (int'Max (R, 10));
      Cols := Positive (int'Max (C, 40));
   end Size;

   function Take_Resized return Boolean is (C_Take_Resized /= 0);

   function Is_Windows return Boolean is (C_Is_Windows /= 0);

   function Is_Active return Boolean is (Active);

end Turbo.Term;
