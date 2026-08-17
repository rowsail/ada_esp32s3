--  Guide step 14 -- a multi-phase SPI command with CS held across it.
--
--  Mode and clock are per-DEVICE, applied at Acquire under the exclusive hold,
--  which is why two devices with different speeds can share one host.
--
--  The DMA_Buffer overload of Transfer is the one to prefer: the type carries
--  Alignment => 32, and its precondition additionally requires the buffer
--  FOOTPRINT to be a whole number of 32-byte cache lines, so cache maintenance
--  cannot reach into a neighbouring object.
with ESP32S3.SPI;
with ESP32S3.GDMA;

procedure SPI_Txn is
   use ESP32S3.SPI;

   S      : Session;
   Tx_Buf : ESP32S3.GDMA.DMA_Buffer (0 .. 63) := (others => 0);   --  2 whole lines
   Rx_Buf : ESP32S3.GDMA.DMA_Buffer (0 .. 63) := (others => 0);
begin
   Setup (SPI2);                                            --  per host, once
   Configure_Pins (SPI2, Sclk => 12, Mosi => 11, Miso => 13);

   --  Per device: this one runs mode 0 at 8 MHz with its CS on an ordinary GPIO
   --  that the driver drives itself.
   Acquire (S, SPI2, Mode => 0, Clock_Hz => 8_000_000, CS_Pin => 21);

   --  Hold CS low across every phase, so the device sees ONE command.  If an
   --  exception escapes here, Finalize deselects before releasing the host.
   Select_Device (S, True);
   Transfer (S, Tx_Buf, Rx_Buf, 64);
   Select_Device (S, False);
end SPI_Txn;
