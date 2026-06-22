------------------------------------------------------------------------------
--                                                                          --
--                         GNAT RUN-TIME COMPONENTS                         --
--                                                                          --
--                    S Y S T E M . S E M I H O S T I N G                   --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--            Copyright (C) 2017-2025, Free Software Foundation, Inc.       --
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
-- You should have received a copy of the GNU General Public License and    --
-- a copy of the GCC Runtime Library Exception along with this program;     --
-- see the files COPYING3 and COPYING.RUNTIME respectively.  If not, see    --
-- <http://www.gnu.org/licenses/>.                                          --
--                                                                          --
-- GNAT was originally developed  by the GNAT team at  New York University. --
-- Extensive contributions were provided by Ada Core Technologies Inc.      --
--                                                                          --
------------------------------------------------------------------------------

with Interfaces;              use Interfaces;
with System.Machine_Code;     use System.Machine_Code;
with System.Storage_Elements; use System.Storage_Elements;

package body System.Semihosting is

   type SH_Word is mod System.Memory_Size with
     Size => System.Word_Size;
   --  Native word type used to hold the result of a semihosting call

   type Syscall is new Interfaces.Unsigned_32;

   SYS_WRITEC : constant Syscall := 16#03#;
   SYS_WRITE0 : constant Syscall := 16#04#;
   SYS_READC  : constant Syscall := 16#07#;
   SYS_EXIT   : constant Syscall := 16#18#;

   function Generic_SH_Call
     (Op    : Syscall;
      Param : System.Address)
      return SH_Word;
   --  Handles the low-level part of semihosting, setting the registers and
   --  executing a breakpoint instruction.

   --  Output buffer

   --  Because most of the time required for semihosting is not consumed for
   --  the data itself but rather in the handling of breakpoint and
   --  communication between the target and debugger, sending one byte costs
   --  almost as much time as sending a buffer of multiple bytes.
   --
   --  For this reason, we use an output buffer for the semihosting Put
   --  functions. The buffer is flushed when full or when a line feed or NUL
   --  character is transmitted.

   Buffer_Size : constant := 128;
   type Buffer_Range is range 1 .. Buffer_Size;
   Buffer : array (Buffer_Range) of Unsigned_8;
   Buffer_Index : Buffer_Range := Buffer_Range'First;

   procedure Flush;
   --  Send the content of the buffer with semihosting WRITE0 call

   ---------------------
   -- Generic_SH_Call --
   ---------------------

   function Generic_SH_Call
     (Op    : Syscall;
      Param : System.Address)
      return SH_Word is separate;

   -----------
   -- Flush --
   -----------

   procedure Flush is
      Unref : SH_Word;
      pragma Unreferenced (Unref);
   begin
      if Buffer_Index /= Buffer'First then
         --  Set null-termination
         Buffer (Buffer_Index) := 0;

         --  Send the buffer with a semihosting call
         Unref := Generic_SH_Call (SYS_WRITE0, Buffer'Address);

         --  Reset buffer index
         Buffer_Index := Buffer'First;
      end if;
   end Flush;

   -------------
   -- SH_Exit --
   -------------

   procedure SH_Exit (Reason : Exit_Reason; Subcode : Exit_Subcode) is
      Is_32bit : constant Boolean := Word_Size = 32;

      Unref : SH_Word;
      pragma Unreferenced (Unref);

   begin
      if Is_32bit then
         --  On 32-bit systems the parameter register is set to the reason
         --  code describing the cause of the trap. The subcode is not used.

         Unref := Generic_SH_Call
                    (SYS_EXIT, To_Address (Integer_Address (Reason)));

      else
         --  On 64-bit systems the parameter register is a pointer to a
         --  two-field argument block containing the reason and subcode.

         declare
            type Sys_Exit_Params is record
               Reason  : Exit_Reason;
               Subcode : Exit_Subcode;
            end record with
              Volatile,
              Size => Word_Size * 2;

            Params : aliased constant Sys_Exit_Params := (Reason, Subcode);
         begin
            Unref := Generic_SH_Call (SYS_EXIT, Params'Address);
         end;
      end if;
   end SH_Exit;

   ---------
   -- Put --
   ---------

   procedure Put (Item : Character) is
      Unref : SH_Word;
      pragma Unreferenced (Unref);

      C : Character with Volatile;
      --  Use a volatile variable to avoid compiler's optimization

   begin
      if Item = ASCII.NUL then
         --  The WRITE0 semihosting call that we use to send the output buffer
         --  expects a null terminated C string. Therefore it is not possible
         --  to have an ASCII.NUL character in the middle of the buffer as this
         --  would truncate the buffer.
         --
         --  For this reason the ASCII.NUL character is sent separately with a
         --  WRITEC semihosting call.

         --  Flush the current buffer
         Flush;

         --  Send the ASCII.NUL with a WRITEC semihosting call
         C := Item;
         Unref := Generic_SH_Call (SYS_WRITEC, C'Address);

      else

         Buffer (Buffer_Index) := Character'Pos (Item);
         Buffer_Index := Buffer_Index + 1;

         --  Flush the buffer when it is full or if the character is a line
         --  feed.
         if Buffer_Index = Buffer'Last or else Item = ASCII.LF then
            Flush;
         end if;
      end if;
   end Put;

   ---------
   -- Put --
   ---------

   procedure Put (Item : String) is
   begin
      for Index in Item'Range loop
         Put (Item (Index));
      end loop;
   end Put;

   ---------
   -- Get --
   ---------

   procedure Get (Item : out Character) is
      Ret : SH_Word;
   begin
      Ret := Generic_SH_Call (SYS_READC, System.Null_Address);
      Item := Character'Val (Ret);
   end Get;

end System.Semihosting;
