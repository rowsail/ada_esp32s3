with ESP32S3.Block_Dev;
with ESP32S3.Block_Dev.W25Q_Source;
with ESP32S3.Block_Dev.WL;
with ESP32S3.Ext4.FS;

--  The flash filesystem stack as LIBRARY-LEVEL objects.  FTP_Server.Run stores
--  the Mount access in a library-level variable, so the Mount (and the WL/source
--  objects it is built on, which are linked by 'Access) must be library-level too
--  -- otherwise the runtime accessibility check on that store fails.  They also
--  live for the whole program, since the server never returns.
package Flash_FS is
   Raw : aliased ESP32S3.Block_Dev.W25Q_Source.Source;
   Vol : aliased ESP32S3.Block_Dev.WL.Volume;
   Dev : ESP32S3.Block_Dev.Device;
   M   : aliased ESP32S3.Ext4.FS.Mount;
end Flash_FS;
