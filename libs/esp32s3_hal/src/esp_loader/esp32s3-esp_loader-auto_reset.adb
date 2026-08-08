package body ESP32S3.Esp_Loader.Auto_Reset is

   use type Ada.Real_Time.Time;

   procedure Drive_Reset (C : in out Circuit; Asserted : Boolean) is
   begin
      if C.Started and then C.Reset_Out = Asserted then
         return;                       --  no redundant pin writes

      end if;
      C.Reset_Out := Asserted;
      if C.Over.Assert_Reset /= null then
         C.Over.Assert_Reset (C.Over.Ctx, Asserted);
      end if;
   end Drive_Reset;

   procedure Drive_Boot (C : in out Circuit; Asserted : Boolean) is
   begin
      if C.Started and then C.Boot_Out = Asserted then
         return;
      end if;
      C.Boot_Out := Asserted;
      if C.Over.Assert_Boot /= null then
         C.Over.Assert_Boot (C.Over.Ctx, Asserted);
      end if;
   end Drive_Boot;

   procedure Configure
     (C                : out Circuit;
      Over             : Link;
      Release_Delay_Ms : Natural := Default_Release_Delay_Ms) is
   begin
      C.Over := Over;
      C.Hold := Ada.Real_Time.Milliseconds (Release_Delay_Ms);
      C.Started := False;
      C.Release_Pending := False;

      --  Drive both lines to released once, so the target runs from the
      --  moment we take charge of its pins rather than from the first Update.
      Drive_Reset (C, False);
      Drive_Boot (C, False);
      C.Started := True;
   end Configure;

   procedure Update (C : in out Circuit; DTR : Boolean; RTS : Boolean) is
      --  The cross-coupling.  With BOTH lines asserted neither pin moves,
      --  which is what stops a terminal emulator from resetting the target
      --  merely by opening the port.
      Want_Reset : constant Boolean := RTS and then not DTR;
      Want_Boot  : constant Boolean := DTR and then not RTS;
   begin
      --  IO0 follows immediately: it is a plain input to the target, sampled
      --  only at the instant reset is released, so it can never be too early.
      Drive_Boot (C, Want_Boot);

      if Want_Reset then
         --  Asserting is immediate, and cancels any release still waiting.
         C.Release_Pending := False;
         Drive_Reset (C, True);

      elsif C.Reset_Out then
         --  Releasing waits out the emulated capacitor.  Under ClassicReset
         --  this window is exactly what covers the moment when both lines are
         --  briefly asserted, before RTS is dropped a fraction of a
         --  millisecond later.
         if not C.Release_Pending then
            C.Release_Pending := True;
            C.Release_At := Ada.Real_Time.Clock + C.Hold;
         elsif Ada.Real_Time.Clock >= C.Release_At then
            C.Release_Pending := False;
            Drive_Reset (C, False);
         end if;
      end if;
   end Update;

end ESP32S3.Esp_Loader.Auto_Reset;

