with ESP32S3.SD_SPI;

--  Adapter: present an initialised SD-over-SPI card as a Block_Dev.Device for
--  the filesystem.  The Card must already be Setup + Initialize'd and must
--  outlive the returned Device.  (Embedded/full only -- pulls in the
--  finalization-based SPI stack.)

package ESP32S3.Block_Dev.SD_SPI_Source is

   function Make (C : not null access ESP32S3.SD_SPI.Card) return Device;

end ESP32S3.Block_Dev.SD_SPI_Source;
