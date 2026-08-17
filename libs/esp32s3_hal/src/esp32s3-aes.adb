with Ada.Real_Time;
with Interfaces;            use Interfaces;
with ESP32S3.Endian;        use ESP32S3.Endian;
with ESP32S3_Registers;     use ESP32S3_Registers;
with ESP32S3_Registers.AES; use ESP32S3_Registers.AES;
with ESP32S3_Registers.SYSTEM;

package body ESP32S3.AES is

   --  MODE values: encrypt = 0/2, decrypt = 4/6 for 128/256-bit keys.  (The S3
   --  hardware has no working 192-bit mode -- see the package spec.)
   Encrypt_128 : constant := 0;
   Encrypt_256 : constant := 2;
   Decrypt_128 : constant := 4;
   Decrypt_256 : constant := 6;

   --  Pack 4 bytes into a little-endian word (byte 0 in the LSB) -- matches the
   --  AES register byte order (esp-idf writes the block by direct word copy on
   --  this little-endian core).
   function To_Word (B0, B1, B2, B3 : Unsigned_8) return UInt32
   is (UInt32 (Join_LE (B0, B1, B2, B3)));

   --------------------------------------------------------------------------
   --  One shared accelerator; serialise the whole transform.
   --------------------------------------------------------------------------

   protected Engine is
      procedure Transform
        (Mode : UInt32; Key : Key_Bytes; Input : Block; Output : out Block);
   private
      Inited : Boolean := False;
   end Engine;

   protected body Engine is

      procedure Transform
        (Mode : UInt32; Key : Key_Bytes; Input : Block; Output : out Block)
      is
         use ESP32S3_Registers.SYSTEM;
      begin
         if not Inited then
            SYSTEM_Periph.PERIP_CLK_EN1.CRYPTO_AES_CLK_EN := True;
            SYSTEM_Periph.PERIP_RST_EN1.CRYPTO_AES_RST := True;
            SYSTEM_Periph.PERIP_RST_EN1.CRYPTO_AES_RST := False;
            Inited := True;
         end if;

         AES_Periph.DMA_ENABLE :=
           (DMA_ENABLE => False, others => <>);  --  typical mode
         AES_Periph.MODE := (MODE => MODE_MODE_Field (Mode), others => <>);

         --  Key = Key'Length/4 little-endian words (4/6/8 for 128/192/256-bit);
         --  any higher KEY words are ignored by the selected mode.
         for I in 0 .. Key'Length / 4 - 1 loop
            AES_Periph.KEY (I) :=
              To_Word
                (Key (Key'First + I * 4),
                 Key (Key'First + I * 4 + 1),
                 Key (Key'First + I * 4 + 2),
                 Key (Key'First + I * 4 + 3));
         end loop;

         for I in 0 .. 3 loop
            AES_Periph.TEXT_IN (I) :=
              To_Word
                (Input (I * 4),
                 Input (I * 4 + 1),
                 Input (I * 4 + 2),
                 Input (I * 4 + 3));
         end loop;

         AES_Periph.TRIGGER := (TRIGGER => True, others => <>);
         --  A single-block transform completes in microseconds; bound the poll
         --  with a wall-clock deadline so a wedged core can't hang here forever.
         declare
            use type Ada.Real_Time.Time;
            Deadline : constant Ada.Real_Time.Time :=
              Ada.Real_Time.Clock + Ada.Real_Time.Milliseconds (100);
         begin
            while AES_Periph.STATE.STATE = 1 loop
               --  1 = working
               exit when Ada.Real_Time.Clock >= Deadline;
            end loop;
         end;

         for I in 0 .. 3 loop
            Split_LE
              (Unsigned_32 (AES_Periph.TEXT_OUT (I)),
               Output (I * 4),
               Output (I * 4 + 1),
               Output (I * 4 + 2),
               Output (I * 4 + 3));
         end loop;
      end Transform;

   end Engine;

   --  Encrypt / decrypt MODE for a key of the given byte length.
   function Enc_Mode (Len : Natural) return UInt32
   is (if Len = 32 then Encrypt_256 else Encrypt_128);
   function Dec_Mode (Len : Natural) return UInt32
   is (if Len = 32 then Decrypt_256 else Decrypt_128);

   -----------------
   -- Encrypt_ECB --
   -----------------

   function Encrypt_ECB (Key : Key_Bytes; Plain : Block) return Block is
      Out_Block : Block;
   begin
      Engine.Transform (Enc_Mode (Key'Length), Key, Plain, Out_Block);
      return Out_Block;
   end Encrypt_ECB;

   -----------------
   -- Decrypt_ECB --
   -----------------

   function Decrypt_ECB (Key : Key_Bytes; Cipher : Block) return Block is
      Out_Block : Block;
   begin
      Engine.Transform (Dec_Mode (Key'Length), Key, Cipher, Out_Block);
      return Out_Block;
   end Decrypt_ECB;

end ESP32S3.AES;
