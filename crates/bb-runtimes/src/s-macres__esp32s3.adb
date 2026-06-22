------------------------------------------------------------------------------
--                         GNAT RUN-TIME COMPONENTS                         --
--                   S Y S T E M .  M A C H I N E _ R E S E T               --
--                                 B o d y                                  --
--                                                                          --
--  Xtensa LX7 (ESP32-S3) port.  Unlike s-macres__none, this body does NOT  --
--  export _exit/abort (ESP-IDF's newlib provides those); System.BB's       --
--  __gnat_stop just performs an ESP-IDF software reset.                     --
------------------------------------------------------------------------------

package body System.Machine_Reset is

   procedure Esp_Restart
     with Import, Convention => C, External_Name => "esp_restart",
          No_Return;
   --  ESP-IDF software reset of the SoC.

   ----------
   -- Stop --
   ----------

   procedure Stop is
   begin
      Esp_Restart;
   end Stop;

end System.Machine_Reset;
