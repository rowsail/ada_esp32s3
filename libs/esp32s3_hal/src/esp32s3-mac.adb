with Interfaces; use Interfaces;
with ESP32S3_Registers.EFUSE;

package body ESP32S3.MAC is

   package EF renames ESP32S3_Registers.EFUSE;

   function Base return MAC_Address is
      --  BLOCK1: low 32 bits in RD_MAC_SPI_SYS_0, high 16 bits in *_1.MAC_1.
      M0 : constant Unsigned_32 :=
        Unsigned_32 (EF.EFUSE_Periph.RD_MAC_SPI_SYS_0);
      M1 : constant Unsigned_32 :=
        Unsigned_32 (EF.EFUSE_Periph.RD_MAC_SPI_SYS_1.MAC_1);
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
      A : MAC_Address := Base;
   begin
      A (5) :=
        A (5) + Offset;   --  byte-wise: the factory block reserves low bits
      return A;
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
      A : MAC_Address := Addr;
   begin
      A (0) := (A (0) or 16#02#) and 16#FE#;
      return A;
   end Local;

   function Image (Addr : MAC_Address) return String is
      Hex : constant array (0 .. 15) of Character := "0123456789abcdef";
      function H (B : Unsigned_8) return String
      is (Hex (Integer (Shift_Right (B, 4))) & Hex (Integer (B and 16#F#)));
   begin
      return
        H (Addr (0))
        & ":"
        & H (Addr (1))
        & ":"
        & H (Addr (2))
        & ":"
        & H (Addr (3))
        & ":"
        & H (Addr (4))
        & ":"
        & H (Addr (5));
   end Image;

end ESP32S3.MAC;
