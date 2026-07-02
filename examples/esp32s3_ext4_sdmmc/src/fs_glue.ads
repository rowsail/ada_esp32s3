with ESP32S3.Ext4;

--  Library-level console glue for the ext4_sdmmc example.  These are declared in
--  a package (not nested in Main) on purpose: the directory-iterator callback
--  passed to ESP32S3.Ext4.FS.Iterate by 'Access calls them, and a callback that
--  references entities nested in Main would make GNAT emit a stack trampoline --
--  which faults on this target's non-executable stack (the HAL forbids that via
--  No_Implicit_Dynamic_Code; see libs/esp32s3_hal/no_dynamic_code.adc).  Keeping
--  the glue library-level makes the callback closure-free.
--
--  Output goes through the buffered ESP32S3.Text_IO console (was esp_rom_printf).

package FS_Glue is
   procedure Banner;
   procedure Card_R (Ok : Boolean);
   procedure Mount_R (Ok : Boolean; Block_Size : Natural);
   procedure File_R (Ok : Boolean; Size : Natural; Preview : String);
   procedure Err_R (Stage : String);
   procedure Done;

   --  Sanitise a string for the console: non-printables -> '.'.
   function Clean (Str : String) return String;

   --  Directory-iterator callback for ESP32S3.Ext4.FS.Iterate.  It MUST be
   --  library-level (here, not nested in Main): 'Access of a nested subprogram
   --  passed to Iterate's anonymous access-to-subprogram parameter would need a
   --  GNAT stack trampoline, which faults on this non-executable stack.
   procedure Visit (Name : String; Ino : ESP32S3.Ext4.Inode_Number; File_Type : ESP32S3.Ext4.U8);
end FS_Glue;
