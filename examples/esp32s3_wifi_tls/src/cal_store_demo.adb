with Interfaces;   use Interfaces;
with ESP32S3.Log;  use ESP32S3.Log;

package body Cal_Store_Demo is

   use ESP32S3.WiFi;

   --  How to use (verified on hardware):
   --    1. Build + flash with Present => False.  The first boot runs a FULL RF
   --       calibration ("RF cal FULL") and Store prints a line
   --       "CALBLOB:<3808 hex chars>" -- the 1904-byte baseline for THIS chip.
   --    2. Paste those bytes into Baseline below and set Present => True.
   --    3. Rebuild + flash.  The next boot loads the baseline and runs a fast
   --       PARTIAL calibration instead ("RF cal PARTIAL (stored baseline)").
   --
   --  This is a source-constant reference store: it shows the Set_Cal_Store
   --  contract (a valid, MAC-matching blob -> PARTIAL) without binding the driver
   --  to any flash layout.  A production store would keep Baseline in NV memory
   --  (a flash partition) and fill it from Store at runtime.
   Present  : constant Boolean := False;
   Baseline : constant Cal_Blob := (others => 0);

   function Load (Blob : out Cal_Blob) return Boolean is
   begin
      if Present then
         Blob := Baseline;
         return True;
      end if;
      Blob := (others => 0);
      return False;
   end Load;

   procedure Store (Blob : Cal_Blob) is
   begin
      Put_Line ("[cal] fresh RF-cal baseline (paste into Cal_Store_Demo.Baseline):");
      Put ("CALBLOB:");
      for B of Blob loop
         Put_Hex (Interfaces.Unsigned_32 (B), 2);
      end loop;
      New_Line;
   end Store;

end Cal_Store_Demo;
