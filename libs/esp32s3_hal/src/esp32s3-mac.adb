with Interfaces; use Interfaces;
with ESP32S3_Registers.EFUSE;

package body ESP32S3.MAC is

   package EF renames ESP32S3_Registers.EFUSE;

   function Base return MAC_Address is
      --  BLOCK1: low 32 bits in RD_MAC_SPI_SYS_0, high 16 bits in *_1.MAC_1.
      M0 : constant Unsigned_32 := Unsigned_32 (EF.EFUSE_Periph.RD_MAC_SPI_SYS_0);
      M1 : constant Unsigned_32 := Unsigned_32 (EF.EFUSE_Periph.RD_MAC_SPI_SYS_1.MAC_1);
   begin
      return
        (0 => Unsigned_8 (Shift_Right (M1, 8) and 16#FF#),
         1 => Unsigned_8 (M1 and 16#FF#),
         2 => Unsigned_8 (Shift_Right (M0, 24) and 16#FF#),
         3 => Unsigned_8 (Shift_Right (M0, 16) and 16#FF#),
         4 => Unsigned_8 (Shift_Right (M0, 8) and 16#FF#),
         5 => Unsigned_8 (M0 and 16#FF#));
   end Base;

   function Derived (Offset : Interfaces.Unsigned_8) return MAC_Address is
      Result : MAC_Address := Base;
   begin
      Result (5) := Result (5) + Offset;   --  byte-wise: the factory block reserves low bits
      return Result;
   end Derived;

   function Wi_Fi_Station return MAC_Address
   is (Base);
   function Wi_Fi_SoftAP return MAC_Address
   is (Derived (1));
   function Bluetooth return MAC_Address
   is (Derived (2));
   function Ethernet return MAC_Address
   is (Derived (3));

   function Local (Addr : MAC_Address) return MAC_Address is
      Result : MAC_Address := Addr;
   begin
      Result (0) := (Result (0) or 16#02#) and 16#FE#;
      return Result;
   end Local;

   function Image (Addr : MAC_Address) return String is
      Hex : constant array (0 .. 15) of Character := "0123456789abcdef";
      function Hex_Byte (Value : Unsigned_8) return String
      is (Hex (Integer (Shift_Right (Value, 4))) & Hex (Integer (Value and 16#F#)));
   begin
      return
        Hex_Byte (Addr (0))
        & ":"
        & Hex_Byte (Addr (1))
        & ":"
        & Hex_Byte (Addr (2))
        & ":"
        & Hex_Byte (Addr (3))
        & ":"
        & Hex_Byte (Addr (4))
        & ":"
        & Hex_Byte (Addr (5));
   end Image;

end ESP32S3.MAC;
