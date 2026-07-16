--  The ESP32-S3 application image descriptor (esp_app_desc_t), in Ada -- the
--  pure-Ada replacement for the former app_desc.c.  The vendored 2nd-stage
--  bootloader asserts that image segment #0 (the DROM segment) begins with this
--  256-byte structure whose first word is the magic 0xABCD5432; vendor/sections.ld
--  KEEPs .rodata_desc first in .flash.appdesc, so this lands exactly there.
--
--  Compiled ZFP-style by bare_boot.gpr (no binder / No_Elaboration): it must be a
--  STATIC .rodata datum -- a value needing elaboration would read back as zero at
--  boot and the bootloader's magic-word assert would fail.  A flat byte aggregate
--  with static components + `others => 0` is emitted as initialised .rodata, no
--  elaboration code, and mirrors the exact on-disk layout the bootloader reads.

with Interfaces; use Interfaces;

package App_Desc is

   type Byte_Array is array (Natural range <>) of Unsigned_8;

   --  Layout (offsets): magic_word@0, secure_version@4, reserv1@8, version[32]@16,
   --  project_name[32]@48, time[16]@80, date[16]@96, idf_ver[32]@112,
   --  app_elf_sha256[32]@144, min/max_efuse_blk_rev@176/178, mmu_page_size@180,
   --  reserv3@181, reserv2[18]@184 -- 256 bytes total.  Only the magic and three
   --  name strings are set; everything else is zero (0 = chip-default page size).
   Descriptor : constant Byte_Array (0 .. 255) :=
     (--  magic_word = 0xABCD5432, little-endian
      0 => 16#32#, 1 => 16#54#, 2 => 16#CD#, 3 => 16#AB#,
      --  version[32] @16 = "noidf-spike"
      16 => Character'Pos ('n'), 17 => Character'Pos ('o'), 18 => Character'Pos ('i'),
      19 => Character'Pos ('d'), 20 => Character'Pos ('f'), 21 => Character'Pos ('-'),
      22 => Character'Pos ('s'), 23 => Character'Pos ('p'), 24 => Character'Pos ('i'),
      25 => Character'Pos ('k'), 26 => Character'Pos ('e'),
      --  project_name[32] @48 = "gpio0_blink"
      48 => Character'Pos ('g'), 49 => Character'Pos ('p'), 50 => Character'Pos ('i'),
      51 => Character'Pos ('o'), 52 => Character'Pos ('0'), 53 => Character'Pos ('_'),
      54 => Character'Pos ('b'), 55 => Character'Pos ('l'), 56 => Character'Pos ('i'),
      57 => Character'Pos ('n'), 58 => Character'Pos ('k'),
      --  idf_ver[32] @112 = "v5.4.4"
      112 => Character'Pos ('v'), 113 => Character'Pos ('5'), 114 => Character'Pos ('.'),
      115 => Character'Pos ('4'), 116 => Character'Pos ('.'), 117 => Character'Pos ('4'),
      others => 0)
   with
     Export,
     Convention     => C,
     External_Name  => "esp_app_desc",
     Linker_Section => ".rodata_desc",
     Alignment      => 4;

end App_Desc;
