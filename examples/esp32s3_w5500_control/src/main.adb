--  WIZnet W5500 control registers on the bare-metal ESP32-S3
--  ============================================================================
--  What it demonstrates
--    The app-controlled register knobs the driver exposes (see the "Tuning the
--    chip" section of the book): link mode, the mode-register switches (WoL /
--    ping-block / force-ARP), retransmission timing, per-socket options, and the
--    fault diagnostics.  Most only bite with a live network, but two things prove
--    the whole register path ON THIS BOARD with no cable:
--      * Set_Retransmission then Get_Retransmission -- a write/read round-trip;
--      * Open_TCP reaching SOCK_INIT (a local chip op, no link needed), after
--        which the per-socket options are accepted.
--
--  Build & run:  ./x run esp32s3_w5500_control       (embedded profile)
--  Wiring: same as esp32s3_w5500 (SPI2, CS=IO39, RST=IO11, INT=IO3).
with Interfaces;
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.SPI;
with ESP32S3.W5500;
with ESP32S3.W5500.Sockets;
with ESP32S3.Log;  use ESP32S3.Log;
with W5500_Dev;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   package Net renames ESP32S3.W5500;
   package Sk  renames ESP32S3.W5500.Sockets;
   use type Sk.Status;
   use type Net.Power_Mode;

   Dev : Net.Device renames W5500_Dev.Dev;
   Ok  : Boolean;

   Sclk_Pin : constant := 1;   Mosi_Pin : constant := 4;   Miso_Pin : constant := 45;
   Cs_Pin   : constant := 39;  Rst_Pin  : constant := 11;  Int_Pin  : constant := 3;

   My_MAC     : constant Net.MAC_Address := (16#00#, 16#08#, 16#DC#, 16#01#, 16#02#, 16#03#);
   My_IP      : constant Net.IPv4_Address := Net.IPv4 (192, 168, 1, 50);
   My_Subnet  : constant Net.IPv4_Address := Net.IPv4 (255, 255, 255, 0);
   My_Gateway : constant Net.IPv4_Address := Net.IPv4 (192, 168, 1, 1);

   --  A Duration as "N.NNN s" (millisecond precision), no floating point.
   function Ms (D : Duration) return String is
      T  : constant Integer := Integer (D * 1000.0);
      S  : constant String := Integer'Image (T);
   begin
      return (if T < 0 then S else S (S'First + 1 .. S'Last)) & " ms";
   end Ms;

begin
   delay until Clock + Milliseconds (200);
   Put_Line ("[ctl] W5500 control-register demo");

   Net.Setup (Dev, Sclk => Sclk_Pin, Mosi => Mosi_Pin, Miso => Miso_Pin,
              Cs => Cs_Pin, Rst => Rst_Pin, Int => Int_Pin,
              Host => ESP32S3.SPI.SPI2, Clock_Hz => 10_000_000);
   Net.Reset (Dev, Ok);
   Put ("[ctl] VERSIONR = 0x");
   Put_Hex (Interfaces.Unsigned_32 (Net.Version (Dev)), 2);
   Put_Line (if Ok then "  (present)" else "  (check wiring!)");
   if not Ok then loop delay until Clock + Seconds (3600); end loop; end if;
   Net.Configure (Dev, MAC => My_MAC, IP => My_IP, Subnet => My_Subnet, Gateway => My_Gateway);

   ---------------------------------------------------------------------------
   --  1) Retransmission: a write/read round-trip proves the register path.
   ---------------------------------------------------------------------------
   Put_Line ("");
   Put_Line ("[ctl] --- retransmission (write then read back) ---");
   declare
      T : Duration; N : Natural;
   begin
      Net.Get_Retransmission (Dev, T, N);
      Put_Line ("[ctl] default : " & Ms (T) & " x" & Natural'Image (N));
      Net.Set_Retransmission (Dev, Timeout => 0.5, Retries => 4);
      Net.Get_Retransmission (Dev, T, N);
      Put_Line ("[ctl] set 500 ms x4 -> read " & Ms (T) & " x" & Natural'Image (N));
      Put_Line (if T = 0.5 and then N = 4
                then "[ctl]   -> round-trip OK (register path verified)"
                else "[ctl]   -> MISMATCH");
      Net.Set_Retransmission (Dev, Timeout => 0.2, Retries => 8);   --  restore
   end;

   ---------------------------------------------------------------------------
   --  2) Mode-register switches + link mode + fault read (fire-and-forget).
   ---------------------------------------------------------------------------
   Put_Line ("");
   Put_Line ("[ctl] --- mode switches, link mode, diagnostics ---");
   Net.Set_Ping_Block   (Dev, Blocked => True);   Put_Line ("[ctl] ping-block on");
   Net.Set_Wake_On_LAN  (Dev, On => True);         Put_Line ("[ctl] wake-on-LAN on");
   Net.Set_Force_ARP    (Dev, On => True);         Put_Line ("[ctl] force-ARP on");
   Net.Set_Common_Interrupts (Dev, IP_Conflict => True, Magic_Packet => True);
   Put_Line ("[ctl] conflict + magic-packet interrupts routed to INTn");
   Net.Set_Link_Mode (Dev, Net.M10_Half);
   Put_Line ("[ctl] link pinned to 10BASE-T half (lower PHY current)");
   Put_Line ("[ctl] PHY still powered: "
             & Boolean'Image (Net.Power (Dev) = Net.Normal));
   declare
      F : Net.Fault_Report;
   begin
      Net.Read_Faults (Dev, F);
      Put_Line ("[ctl] faults: conflict=" & Boolean'Image (F.IP_Conflict)
                & " unreachable=" & Boolean'Image (F.Dest_Unreachable));
      Put_Line ("[ctl] magic packet pending: "
                & Boolean'Image (Net.Magic_Packet_Pending (Dev)));
   end;

   ---------------------------------------------------------------------------
   --  3) Open a socket (reaches SOCK_INIT with no cable) + per-socket options.
   ---------------------------------------------------------------------------
   Put_Line ("");
   Put_Line ("[ctl] --- per-socket options on an opened TCP socket ---");
   declare
      S  : Sk.Socket;
      St : Sk.Status;
   begin
      Sk.Open_TCP (Dev'Access, S, Index => 0, Local_Port => 5000,
                   Result => St, No_Delay => True);
      Put_Line ("[ctl] Open_TCP (No_Delay) -> " & Sk.Status'Image (St)
                & "  state=" & Sk.Socket_State'Image (Sk.State (S)));
      if St = Sk.OK then
         Sk.Set_Keepalive        (S, 30.0);
         Sk.Set_TTL              (S, 64);
         Sk.Set_Type_Of_Service  (S, 16);
         Sk.Set_Max_Segment_Size (S, 1460);
         Sk.Set_Buffer_Sizes     (S, RX => Sk.KB_8, TX => Sk.KB_4);
         Put_Line ("[ctl] keepalive/TTL/ToS/MSS/buffers set (chip accepted the writes)");
      end if;
      Sk.Close (S);
   end;

   --  Restore auto-negotiation for the next user of the board.
   Net.Set_Link_Mode (Dev, Net.Auto);
   Net.Set_Ping_Block (Dev, Blocked => False);
   Net.Set_Wake_On_LAN (Dev, On => False);
   Net.Set_Force_ARP (Dev, On => False);

   Put_Line ("");
   Put_Line ("[ctl] done.");
   loop delay until Clock + Seconds (3600); end loop;
end Main;
