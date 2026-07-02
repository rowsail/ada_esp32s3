with ESP32S3.SDMMC;

--  Adapter: present an initialised SD card (native SDMMC host) as a
--  Block_Dev.Device for the filesystem.  The Card must already be Setup +
--  Initialize'd and must outlive the returned Device.  Unlike the SD-SPI source,
--  SDMMC reports the card's true size (Capacity_Blocks), so Count is exact.
--  (Embedded/full only -- pulls in the finalization-based SDMMC stack.)

package ESP32S3.Block_Dev.SDMMC_Source is

   function Make (C : not null access ESP32S3.SDMMC.Card) return Device;

end ESP32S3.Block_Dev.SDMMC_Source;
