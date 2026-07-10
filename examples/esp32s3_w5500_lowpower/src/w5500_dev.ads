with ESP32S3.W5500;

--  The W5500 as a library-level, aliased board resource, so a self-contained
--  socket handle (ESP32S3.W5500.Sockets.Socket, which stores a Device_Access)
--  can take Dev'Access.

package W5500_Dev is
   Dev : aliased ESP32S3.W5500.Device;
end W5500_Dev;
