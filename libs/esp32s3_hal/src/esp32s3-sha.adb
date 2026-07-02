with Ada.Real_Time;
with Interfaces;            use Interfaces;
with ESP32S3.Endian;        use ESP32S3.Endian;
with ESP32S3_Registers;     use ESP32S3_Registers;
with ESP32S3_Registers.SHA; use ESP32S3_Registers.SHA;
with ESP32S3_Registers.SYSTEM;

package body ESP32S3.SHA is

   --  Hardware MODE values (512-bit-block variants).
   SHA_1_Mode   : constant := 0;
   SHA_224_Mode : constant := 1;
   SHA_256_Mode : constant := 2;

   --  A full 8-word read buffer; each variant copies out the words it uses.
   type Word_Buffer is array (0 .. 7) of UInt32;

   --------------------------------------------------------------------------
   --  The accelerator is one shared resource; serialise the whole operation.
   --------------------------------------------------------------------------

   protected Engine is
      procedure Hash (Data : Byte_Array; Mode : UInt32; Words : out Word_Buffer);
   private
      Inited : Boolean := False;
   end Engine;

   protected body Engine is

      procedure Hash (Data : Byte_Array; Mode : UInt32; Words : out Word_Buffer) is
         use ESP32S3_Registers.SYSTEM;
         Msg     : constant Natural := Data'Length;
         Bit_Len : constant Unsigned_64 := Unsigned_64 (Msg) * 8;
         --  Padded length: message + 0x80 + zero pad + 8-byte length, rounded up
         --  to a whole number of 64-byte blocks.
         Padded  : constant Natural := ((Msg + 8) / 64 + 1) * 64;
         Blocks  : constant Natural := Padded / 64;

         --  The padded message byte at absolute index I (0-based).
         function Padded_Byte (I : Natural) return Unsigned_8 is
         begin
            if I < Msg then
               return Data (Data'First + I);
            elsif I = Msg then
               return 16#80#;
            elsif I >= Padded - 8 then
               --  big-endian 64-bit bit length in the last 8 bytes
               return Unsigned_8 (Shift_Right (Bit_Len, 8 * (Padded - 1 - I)) and 16#FF#);
            else
               return 0;
            end if;
         end Padded_Byte;
      begin
         if not Inited then
            SYSTEM_Periph.PERIP_CLK_EN1.CRYPTO_SHA_CLK_EN := True;
            SYSTEM_Periph.PERIP_RST_EN1.CRYPTO_SHA_RST := True;
            SYSTEM_Periph.PERIP_RST_EN1.CRYPTO_SHA_RST := False;
            Inited := True;
         end if;

         SHA_Periph.MODE := (MODE => MODE_MODE_Field (Mode), others => <>);

         for B in 0 .. Blocks - 1 loop
            --  Load the 64-byte block as 16 words.
            for W in 0 .. 15 loop
               declare
                  Byte_Offset : constant Natural := B * 64 + W * 4;
               begin
                  --  Words are written as the little-endian packing of the byte
                  --  stream (matches esp-idf's direct word copy on this
                  --  little-endian core).
                  SHA_Periph.M_MEM (W) :=
                    UInt32
                      (Join_LE
                         (Padded_Byte (Byte_Offset),
                          Padded_Byte (Byte_Offset + 1),
                          Padded_Byte (Byte_Offset + 2),
                          Padded_Byte (Byte_Offset + 3)));
               end;
            end loop;

            if B = 0 then
               SHA_Periph.START := (START => 1, others => <>);
            else
               SHA_Periph.CONTINUE := (CONTINUE => 1, others => <>);
            end if;
            --  A block hash completes in microseconds; bound the poll so a
            --  wedged core can't hang here forever.
            declare
               use type Ada.Real_Time.Time;
               Deadline : constant Ada.Real_Time.Time :=
                 Ada.Real_Time.Clock + Ada.Real_Time.Milliseconds (100);
            begin
               while SHA_Periph.BUSY.STATE loop
                  exit when Ada.Real_Time.Clock >= Deadline;
               end loop;
            end;
         end loop;

         --  Read all 8 result words; callers use the prefix they need.
         for I in 0 .. 7 loop
            Words (I) := SHA_Periph.H_MEM (I);
         end loop;
      end Hash;

   end Engine;

   --  Copy the little-endian bytes of the first N words into a digest.
   procedure Unpack (Words : Word_Buffer; Into : out Byte_Array) is
   begin
      for I in 0 .. Into'Length / 4 - 1 loop
         declare
            Word_Value : constant UInt32 := Words (I);
            Byte_Index : constant Natural := Into'First + I * 4;
         begin
            Split_LE
              (Unsigned_32 (Word_Value),
               Into (Byte_Index),
               Into (Byte_Index + 1),
               Into (Byte_Index + 2),
               Into (Byte_Index + 3));
         end;
      end loop;
   end Unpack;

   ------------
   -- Hash_1 --
   ------------

   function Hash_1 (Data : Byte_Array) return SHA1_Digest is
      Words  : Word_Buffer;
      Digest : SHA1_Digest;
   begin
      Engine.Hash (Data, SHA_1_Mode, Words);
      Unpack (Words, Digest);
      return Digest;
   end Hash_1;

   --------------
   -- Hash_224 --
   --------------

   function Hash_224 (Data : Byte_Array) return SHA224_Digest is
      Words  : Word_Buffer;
      Digest : SHA224_Digest;
   begin
      Engine.Hash (Data, SHA_224_Mode, Words);
      Unpack (Words, Digest);
      return Digest;
   end Hash_224;

   --------------
   -- Hash_256 --
   --------------

   function Hash_256 (Data : Byte_Array) return SHA256_Digest is
      Words  : Word_Buffer;
      Digest : SHA256_Digest;
   begin
      Engine.Hash (Data, SHA_256_Mode, Words);
      Unpack (Words, Digest);
      return Digest;
   end Hash_256;

end ESP32S3.SHA;
