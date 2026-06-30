------------------------------------------------------------------------------
--                                                                          --
--                         GNAT RUN-TIME COMPONENTS                         --
--                                                                          --
--                        S Y S T E M . T E X T _ I O                       --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--          Copyright (C) 2011-2026, Free Software Foundation, Inc.         --
--                                                                          --
-- GNAT is free software;  you can  redistribute it  and/or modify it under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 3,  or (at your option) any later ver- --
-- sion.  GNAT is distributed in the hope that it will be useful, but WITH- --
-- OUT ANY WARRANTY;  without even the  implied warranty of MERCHANTABILITY --
-- or FITNESS FOR A PARTICULAR PURPOSE.                                     --
--                                                                          --
-- As a special exception under Section 7 of GPL version 3, you are granted --
-- additional permissions described in the GCC Runtime Library Exception,   --
-- version 3.1, as published by the Free Software Foundation.               --
--                                                                          --
------------------------------------------------------------------------------

--  ESP32-S3 implementation: route console characters through the ROM's
--  esp_rom_printf, which drives the built-in USB-serial-JTAG port (the
--  /dev/ttyACM console) the bootloader has already brought up.  Poking the EP1
--  FIFO registers directly proved unreliable once the ROM console driver had
--  been used (the first thing the boot glue does), so System.Text_IO reuses
--  the same ROM path -- the one console output known to work on this board.
--  This makes Ada.Text_IO work on the bare boot.

--  System (the ancestor) is directly visible here; no `with` needed.

package body System.Text_IO is

   --  ROM console output: int esp_rom_printf (const char *fmt, ...).  Imported
   --  as a procedure (the return value is ignored), and called with a constant
   --  "%c" format so a literal '%' in the data is printed verbatim.
   procedure Rom_Printf (Format : System.Address; Item : Integer);
   pragma Import (C, Rom_Printf, "esp_rom_printf");

   Char_Fmt : constant String := "%c" & ASCII.NUL;

   --  Optional console redirection.  When a hook is installed -- the HAL's
   --  ESP32S3.Serial does so at elaboration -- console characters route there
   --  instead of the ROM printf, so Ada.Text_IO follows the same serial-device
   --  multiplexer as ESP32S3.Log (and can be sent to a UART).  Null by
   --  default, so a program that does not pull in the HAL console keeps the
   --  proven ROM path -- and so does the early-boot / last-chance path, which
   --  runs before (or without) the hook.
   type Console_Hook is access procedure (C : Character);
   pragma Convention (C, Console_Hook);

   Hook : Console_Hook := null;

   procedure Install_Console_Hook (H : Console_Hook)
     with Export, Convention => C,
          External_Name => "__esp32s3_install_console_hook";

   procedure Install_Console_Hook (H : Console_Hook) is
   begin
      Hook := H;
   end Install_Console_Hook;

   ---------
   -- Get --
   ---------

   function Get return Character is
   begin
      raise Program_Error;     --  input from the console is not supported
      return ASCII.NUL;
   end Get;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize is
   begin
      Initialized := True;
   end Initialize;

   -----------------
   -- Is_Rx_Ready --
   -----------------

   function Is_Rx_Ready return Boolean is
   begin
      return False;
   end Is_Rx_Ready;

   -----------------
   -- Is_Tx_Ready --
   -----------------

   function Is_Tx_Ready return Boolean is
   begin
      return True;             --  esp_rom_printf always accepts the byte
   end Is_Tx_Ready;

   ---------
   -- Put --
   ---------

   procedure Put (C : Character) is
   begin
      if Hook /= null then
         Hook (C);
         return;
      end if;
      Rom_Printf (Char_Fmt'Address, Character'Pos (C));
   end Put;

   ----------------------------
   -- Use_Cr_Lf_For_New_Line --
   ----------------------------

   function Use_Cr_Lf_For_New_Line return Boolean is
   begin
      return True;
   end Use_Cr_Lf_For_New_Line;

end System.Text_IO;
