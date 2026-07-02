with Interfaces; use Interfaces;
with Ada.Unchecked_Deallocation;
with ESP32S3.Block_Dev;
with ESP32S3.Ext4.Inode;
with ESP32S3.Ext4.Block_Map;
with ESP32S3.Ext4.Block_Cache;
with ESP32S3.Ext4.Superblock;

package body ESP32S3.Ext4.Journal is

   Magic : constant U32 := 16#C03B_3998#;

   BT_Descriptor : constant U32 := 1;
   BT_Commit     : constant U32 := 2;
   BT_Revoke     : constant U32 := 5;

   FL_Escape    : constant U32 := 1;
   FL_Same_UUID : constant U32 := 2;
   FL_Last      : constant U32 := 8;

   JF_64Bit  : constant U32 := 16#0002#;
   JF_CSUMv2 : constant U32 := 16#0008#;
   JF_CSUMv3 : constant U32 := 16#0010#;

   type Bytes_Ptr is access Byte_Array;
   procedure Free is new Ada.Unchecked_Deallocation (Byte_Array, Bytes_Ptr);

   function Needs_Recovery (V : Volume.Context) return Boolean
   is ((V.SB.Feature_Incompat and Superblock.Incompat_Recover) /= 0);

   procedure Replay (V : in out Volume.Context) is
      BS        : constant Natural := V.SB.Block_Size;
      Jin       : Inode.Info;
      Meta      : Bytes_Ptr := new Byte_Array (0 .. BS - 1);
      Data      : Bytes_Ptr := new Byte_Array (0 .. BS - 1);
      First     : U64;
      Maxlen    : U64;
      Start     : U64;
      Seq0      : U64;
      End_Seq   : U64;
      JIncompat : U32;
      Use_64    : Boolean;

      procedure RJ (Jrel : U64; Buf : out Byte_Array) is
         Phys : constant Block_Number :=
           Block_Map.Logical_To_Physical (V, Jin, Jrel);
      begin
         if Phys = 0 then
            raise Corrupt with "journal block hole";
         end if;
         Block_Cache.Read (V.Cache, Phys, Buf);
      end RJ;

      function Wrap (X : U64) return U64
      is (if X >= Maxlen then First + (X - Maxlen) else X);

      function Get16BE (B : Byte_Array; Off : Natural) return U32
      is (Shift_Left (U32 (B (B'First + Off)), 8)
          or U32 (B (B'First + Off + 1)));

      Max_Rev : constant := 256;
      type Rev_Rec is record
         Blk, Seq : U64;
      end record;
      Rev     : array (1 .. Max_Rev) of Rev_Rec;
      N_Rev   : Natural := 0;

      function Revoked (B, At_Seq : U64) return Boolean is
      begin
         for I in 1 .. N_Rev loop
            if Rev (I).Blk = B and then Rev (I).Seq >= At_Seq then
               return True;
            end if;
         end loop;
         return False;
      end Revoked;

      --  Number of tags in the descriptor currently in Meta.
      function Tag_Count return Natural is
         Pos  : Natural := 12;
         N    : Natural := 0;
         Last : Boolean := False;
      begin
         while not Last and then Pos + 8 <= BS loop
            declare
               Flags : constant U32 := Get16BE (Meta.all, Pos + 6);
            begin
               N := N + 1;
               Pos := Pos + 8;
               if Use_64 then
                  Pos := Pos + 4;
               end if;
               if (Flags and FL_Same_UUID) = 0 then
                  Pos := Pos + 16;
               end if;
               Last := (Flags and FL_Last) /= 0;
            end;
         end loop;
         return N;
      end Tag_Count;

   begin
      Inode.Read (V, Journal_Inode, Jin);
      RJ (0, Meta.all);
      if Get_U32_BE (Meta.all, 0) /= Magic then
         Free (Meta);
         Free (Data);
         raise Corrupt with "bad journal superblock magic";
      end if;
      JIncompat := Get_U32_BE (Meta.all, 16#28#);
      if (JIncompat and (JF_CSUMv2 or JF_CSUMv3)) /= 0 then
         Free (Meta);
         Free (Data);
         raise Unsupported_Feature with "checksummed journal (CSUM_V2/V3)";
      end if;
      Use_64 := (JIncompat and JF_64Bit) /= 0;
      Maxlen := U64 (Get_U32_BE (Meta.all, 16#10#));
      First := U64 (Get_U32_BE (Meta.all, 16#14#));
      Seq0 := U64 (Get_U32_BE (Meta.all, 16#18#));
      Start := U64 (Get_U32_BE (Meta.all, 16#1C#));
      End_Seq := Seq0;

      if Start /= 0 then
         --  Pass 1: find the last committed sequence + collect revoke records.
         declare
            Cur    : U64 := Start;
            Seq    : U64 := Seq0;
            Safety : Natural := 0;
         begin
            Scan :
            loop
               Safety := Safety + 1;
               exit Scan when Safety > Natural (Maxlen) + 2;
               RJ (Cur, Meta.all);
               exit Scan when
                 Get_U32_BE (Meta.all, 0) /= Magic
                 or else Get_U32_BE (Meta.all, 8)
                         /= U32 (Seq and 16#FFFF_FFFF#);
               declare
                  BType : constant U32 := Get_U32_BE (Meta.all, 4);
               begin
                  if BType = BT_Descriptor then
                     Cur := Wrap (Cur + 1 + U64 (Tag_Count));
                  elsif BType = BT_Revoke then
                     declare
                        Count : constant Natural :=
                          Natural (Get_U32_BE (Meta.all, 12));
                        Pos   : Natural := 16;
                        RSz   : constant Natural := (if Use_64 then 8 else 4);
                     begin
                        while Pos + RSz <= Count loop
                           declare
                              B : constant U64 :=
                                (if Use_64
                                 then
                                   Shift_Left
                                     (U64 (Get_U32_BE (Meta.all, Pos)), 32)
                                   or U64 (Get_U32_BE (Meta.all, Pos + 4))
                                 else U64 (Get_U32_BE (Meta.all, Pos)));
                           begin
                              if N_Rev < Max_Rev then
                                 N_Rev := N_Rev + 1;
                                 Rev (N_Rev) := (B, Seq);
                              end if;
                              Pos := Pos + RSz;
                           end;
                        end loop;
                        Cur := Wrap (Cur + 1);
                     end;
                  elsif BType = BT_Commit then
                     Seq := Seq + 1;
                     End_Seq := Seq;
                     Cur := Wrap (Cur + 1);
                  else
                     exit Scan;
                  end if;
               end;
            end loop Scan;
         end;

         --  Pass 2: replay committed transactions (honouring revokes).
         declare
            Cur    : U64 := Start;
            Seq    : U64 := Seq0;
            Safety : Natural := 0;
         begin
            Rep :
            loop
               exit Rep when Seq >= End_Seq;
               Safety := Safety + 1;
               exit Rep when Safety > Natural (Maxlen) + 2;
               RJ (Cur, Meta.all);
               exit Rep when
                 Get_U32_BE (Meta.all, 0) /= Magic
                 or else Get_U32_BE (Meta.all, 8)
                         /= U32 (Seq and 16#FFFF_FFFF#);
               declare
                  BType : constant U32 := Get_U32_BE (Meta.all, 4);
               begin
                  if BType = BT_Descriptor then
                     declare
                        Pos      : Natural := 12;
                        Data_Rel : U64 := Wrap (Cur + 1);
                        Last     : Boolean := False;
                     begin
                        while not Last and then Pos + 8 <= BS loop
                           declare
                              Lo    : constant U32 :=
                                Get_U32_BE (Meta.all, Pos);
                              Flags : constant U32 :=
                                Get16BE (Meta.all, Pos + 6);
                              Hi    : U32 := 0;
                           begin
                              Pos := Pos + 8;
                              if Use_64 then
                                 Hi := Get_U32_BE (Meta.all, Pos);
                                 Pos := Pos + 4;
                              end if;
                              if (Flags and FL_Same_UUID) = 0 then
                                 Pos := Pos + 16;
                              end if;
                              declare
                                 Target : constant U64 :=
                                   Shift_Left (U64 (Hi), 32) or U64 (Lo);
                              begin
                                 RJ (Data_Rel, Data.all);
                                 if (Flags and FL_Escape) /= 0 then
                                    Put_U32_BE (Data.all, 0, Magic);
                                 end if;
                                 if not Revoked (Target, Seq) then
                                    Block_Cache.Write
                                      (V.Cache,
                                       Block_Number (Target),
                                       Data.all);
                                 end if;
                                 Data_Rel := Wrap (Data_Rel + 1);
                              end;
                              Last := (Flags and FL_Last) /= 0;
                           end;
                        end loop;
                        Cur := Data_Rel;
                     end;
                  elsif BType = BT_Revoke then
                     Cur := Wrap (Cur + 1);
                  elsif BType = BT_Commit then
                     Seq := Seq + 1;
                     Cur := Wrap (Cur + 1);
                  else
                     exit Rep;
                  end if;
               end;
            end loop Rep;
         end;
      end if;

      --  Reset the journal superblock (empty) and clear the fs RECOVER flag.
      RJ (0, Meta.all);
      Put_U32_BE
        (Meta.all, 16#1C#, 0);                                  --  s_start
      Put_U32_BE
        (Meta.all, 16#18#, U32 (End_Seq and 16#FFFF_FFFF#));    --  s_sequence
      Block_Cache.Write
        (V.Cache, Block_Map.Logical_To_Physical (V, Jin, 0), Meta.all);

      V.SB.Feature_Incompat :=
        V.SB.Feature_Incompat and not Superblock.Incompat_Recover;

      Free (Meta);
      Free (Data);
   end Replay;

   ------------
   -- Commit --
   ------------

   procedure Commit
     (V : in out Volume.Context; Targets : Target_Array; New_Data : Byte_Array)
   is
      BS        : constant Natural := V.SB.Block_Size;
      N         : constant Natural := Targets'Length;
      Jin       : Inode.Info;
      Meta      : Bytes_Ptr := new Byte_Array (0 .. BS - 1);
      Blk       : Bytes_Ptr := new Byte_Array (0 .. BS - 1);
      First     : U64;
      S_Seq     : U32;
      JIncompat : U32;
      Use_64    : Boolean;
      UUID      : Byte_Array (0 .. 15);

      function Jphys (Jrel : U64) return Block_Number
      is (Block_Map.Logical_To_Physical (V, Jin, Jrel));
   begin
      Inode.Read (V, Journal_Inode, Jin);
      Block_Cache.Read (V.Cache, Jphys (0), Meta.all);
      if Get_U32_BE (Meta.all, 0) /= Magic then
         Free (Meta);
         Free (Blk);
         raise Corrupt with "bad journal superblock magic";
      end if;
      JIncompat := Get_U32_BE (Meta.all, 16#28#);
      if (JIncompat and (JF_CSUMv2 or JF_CSUMv3)) /= 0 then
         Free (Meta);
         Free (Blk);
         raise Unsupported_Feature with "checksummed journal (CSUM_V2/V3)";
      end if;
      Use_64 := (JIncompat and JF_64Bit) /= 0;
      First := U64 (Get_U32_BE (Meta.all, 16#14#));
      S_Seq := Get_U32_BE (Meta.all, 16#18#);
      UUID := Meta.all (16#30# .. 16#3F#);

      --  Descriptor block at journal block First: header + one tag per target.
      Blk.all := [others => 0];
      Put_U32_BE (Blk.all, 0, Magic);
      Put_U32_BE (Blk.all, 4, BT_Descriptor);
      Put_U32_BE (Blk.all, 8, S_Seq);
      declare
         Pos : Natural := 12;
      begin
         for I in 0 .. N - 1 loop
            declare
               Off   : constant Natural := New_Data'First + I * BS;
               Esc   : constant Boolean := Get_U32_BE (New_Data, Off) = Magic;
               Flags : U32 := 0;
            begin
               if I = N - 1 then
                  Flags := Flags or FL_Last;
               end if;
               if I > 0 then
                  Flags := Flags or FL_Same_UUID;
               end if;
               if Esc then
                  Flags := Flags or FL_Escape;
               end if;
               Put_U32_BE (Blk.all, Pos, U32 (Targets (Targets'First + I)));
               Blk.all (Pos + 6) := 0;                      --  t_flags (be16)
               Blk.all (Pos + 7) := U8 (Flags and 16#FF#);
               Pos := Pos + 8;
               if Use_64 then
                  Put_U32_BE
                    (Blk.all,
                     Pos,
                     U32
                       (Shift_Right (U64 (Targets (Targets'First + I)), 32)));
                  Pos := Pos + 4;
               end if;
               if I = 0 then
                  Blk.all (Pos .. Pos + 15) := UUID;
                  Pos := Pos + 16;
               end if;
            end;
         end loop;
      end;
      Block_Cache.Write (V.Cache, Jphys (First), Blk.all);

      --  Data blocks at First+1 .. First+N (escaping any that begin with magic).
      for I in 0 .. N - 1 loop
         declare
            Off : constant Natural := New_Data'First + I * BS;
         begin
            Blk.all := New_Data (Off .. Off + BS - 1);
            if Get_U32_BE (Blk.all, 0) = Magic then
               Put_U32_BE (Blk.all, 0, 0);                  --  escape

            end if;
            Block_Cache.Write (V.Cache, Jphys (First + 1 + U64 (I)), Blk.all);
         end;
      end loop;

      --  Commit block at First+N+1.
      Blk.all := [others => 0];
      Put_U32_BE (Blk.all, 0, Magic);
      Put_U32_BE (Blk.all, 4, BT_Commit);
      Put_U32_BE (Blk.all, 8, S_Seq);
      Block_Cache.Write (V.Cache, Jphys (First + 1 + U64 (N)), Blk.all);

      --  Point the journal superblock at the new transaction.
      Block_Cache.Read (V.Cache, Jphys (0), Meta.all);
      Put_U32_BE (Meta.all, 16#1C#, U32 (First));   --  s_start
      Put_U32_BE (Meta.all, 16#18#, S_Seq);         --  s_sequence
      Block_Cache.Write (V.Cache, Jphys (0), Meta.all);

      --  Mark the filesystem as needing recovery (persisted on Close).
      V.SB.Feature_Incompat :=
        V.SB.Feature_Incompat or Superblock.Incompat_Recover;

      Free (Meta);
      Free (Blk);
   end Commit;

   -----------------------
   -- Transaction_Commit --
   -----------------------

   procedure Transaction_Commit
     (V : in out Volume.Context; Simulate_Crash : Boolean := False)
   is
      BS    : constant Natural := V.SB.Block_Size;
      SPB   : constant Natural := BS / 512;
      Jin   : Inode.Info;
      Jsb   : Bytes_Ptr := new Byte_Array (0 .. BS - 1);
      Blk   : Bytes_Ptr := new Byte_Array (0 .. BS - 1);
      SBblk : Bytes_Ptr :=
        new Byte_Array (0 .. BS - 1);   --  journaled SB (recover-set)

      Max_WS  : constant := 256;
      Targets : array (1 .. Max_WS) of Block_Number;
      N       : Natural := 0;

      procedure Collect (B : Block_Number) is
      begin
         if N < Max_WS - 1 then
            --  leave room for the SB target
            N := N + 1;
            Targets (N) := B;
         end if;
      end Collect;

      function Jphys (Jrel : U64) return Block_Number
      is (Block_Map.Logical_To_Physical (V, Jin, Jrel));

      procedure Dwrite (Phys : Block_Number; Buf : Byte_Array) is
         Sec : ESP32S3.Block_Dev.Sector;
      begin
         for S in 0 .. SPB - 1 loop
            for I in 0 .. 511 loop
               Sec (I) := Buf (S * 512 + I);
            end loop;
            ESP32S3.Block_Dev.Write_Sector
              (V.Dev,
               ESP32S3.Block_Dev.Sector_Index
                 (U64 (Phys) * U64 (SPB) + U64 (S)),
               Sec);
         end loop;
      end Dwrite;

      procedure Dread (Phys : Block_Number; Buf : out Byte_Array) is
         Sec : ESP32S3.Block_Dev.Sector;
      begin
         for S in 0 .. SPB - 1 loop
            ESP32S3.Block_Dev.Read_Sector
              (V.Dev,
               ESP32S3.Block_Dev.Sector_Index
                 (U64 (Phys) * U64 (SPB) + U64 (S)),
               Sec);
            for I in 0 .. 511 loop
               Buf (S * 512 + I) := Sec (I);
            end loop;
         end loop;
      end Dread;

      --  Raw-write the on-disk superblock (sectors 2..3) with the given RECOVER
      --  state and V.SB's current counts.
      procedure Write_SB_Raw (Recover : Boolean) is
         Tmp : Superblock.Info := V.SB;
         Buf : Byte_Array (0 .. 1023);
         Sec : ESP32S3.Block_Dev.Sector;
      begin
         if Recover then
            Tmp.Feature_Incompat :=
              Tmp.Feature_Incompat or Superblock.Incompat_Recover;
         else
            Tmp.Feature_Incompat :=
              Tmp.Feature_Incompat and not Superblock.Incompat_Recover;
         end if;
         ESP32S3.Block_Dev.Read_Sector (V.Dev, 2, Sec);
         Buf (0 .. 511) := Byte_Array (Sec);
         ESP32S3.Block_Dev.Read_Sector (V.Dev, 3, Sec);
         Buf (512 .. 1023) := Byte_Array (Sec);
         Superblock.Encode (Tmp, Buf, 0);
         Sec := ESP32S3.Block_Dev.Sector (Buf (0 .. 511));
         ESP32S3.Block_Dev.Write_Sector (V.Dev, 2, Sec);
         Sec := ESP32S3.Block_Dev.Sector (Buf (512 .. 1023));
         ESP32S3.Block_Dev.Write_Sector (V.Dev, 3, Sec);
      end Write_SB_Raw;

      JIncompat : U32;
      Use_64    : Boolean;
      First     : U64;
      S_Seq     : U32;
      UUID      : Byte_Array (0 .. 15);
      SB_Blk    : constant Block_Number := Superblock.SB_Block (BS);
      SB_Base   : constant Natural := Superblock.SB_Offset (BS);
   begin
      --  1. Gather the write-set: the dirty metadata blocks, plus the SB block.
      --  Use the callback-free Dirty_Tags (not For_Each_Dirty with a nested
      --  collector): 'Access of a nested subprogram makes GNAT emit a stack
      --  trampoline, which faults when called on this target's non-executable
      --  stacks -- a silent hang in the commit.
      declare
         Dirty : Block_Cache.Block_List (1 .. Max_WS - 1);
         DN    : Natural;
      begin
         Block_Cache.Dirty_Tags (V.Cache, Dirty, DN);
         for I in 1 .. DN loop
            Collect (Dirty (I));
         end loop;
      end;
      if N = 0 then
         Free (Jsb);
         Free (Blk);
         Free (SBblk);
         return;                       --  nothing changed

      end if;
      N := N + 1;
      Targets (N) := SB_Blk;           --  SB is the last target

      --  Build the journaled SB block content with RECOVER SET (so a replay
      --  reproduces the "recovering" superblock, which Replay then clears).
      Dread (SB_Blk, SBblk.all);
      declare
         Tmp : Superblock.Info := V.SB;
      begin
         Tmp.Feature_Incompat :=
           Tmp.Feature_Incompat or Superblock.Incompat_Recover;
         Superblock.Encode (Tmp, SBblk.all, SB_Base);
      end;

      --  2. Read the journal superblock + layout (direct).
      Inode.Read (V, Journal_Inode, Jin);
      Dread (Jphys (0), Jsb.all);
      if Get_U32_BE (Jsb.all, 0) /= Magic then
         Free (Jsb);
         Free (Blk);
         Free (SBblk);
         raise Corrupt with "bad journal superblock magic";
      end if;
      JIncompat := Get_U32_BE (Jsb.all, 16#28#);
      if (JIncompat and (JF_CSUMv2 or JF_CSUMv3)) /= 0 then
         Free (Jsb);
         Free (Blk);
         Free (SBblk);
         raise Unsupported_Feature with "checksummed journal (CSUM_V2/V3)";
      end if;
      Use_64 := (JIncompat and JF_64Bit) /= 0;
      First := U64 (Get_U32_BE (Jsb.all, 16#14#));
      S_Seq := Get_U32_BE (Jsb.all, 16#18#);
      UUID := Jsb.all (16#30# .. 16#3F#);

      --  3. Descriptor block (direct) at journal block First.
      Blk.all := [others => 0];
      Put_U32_BE (Blk.all, 0, Magic);
      Put_U32_BE (Blk.all, 4, BT_Descriptor);
      Put_U32_BE (Blk.all, 8, S_Seq);
      declare
         Pos : Natural := 12;
         Esc : Boolean;
         Tmp : Byte_Array (0 .. BS - 1);
      begin
         for I in 1 .. N loop
            if Targets (I) = SB_Blk then
               Tmp := SBblk.all;
            else
               Block_Cache.Read (V.Cache, Targets (I), Tmp);
            end if;
            Esc := Get_U32_BE (Tmp, 0) = Magic;
            declare
               Flags : U32 := 0;
            begin
               if I = N then
                  Flags := Flags or FL_Last;
               end if;
               if I > 1 then
                  Flags := Flags or FL_Same_UUID;
               end if;
               if Esc then
                  Flags := Flags or FL_Escape;
               end if;
               Put_U32_BE (Blk.all, Pos, U32 (Targets (I)));
               Blk.all (Pos + 6) := 0;
               Blk.all (Pos + 7) := U8 (Flags and 16#FF#);
               Pos := Pos + 8;
               if Use_64 then
                  Put_U32_BE
                    (Blk.all, Pos, U32 (Shift_Right (U64 (Targets (I)), 32)));
                  Pos := Pos + 4;
               end if;
               if I = 1 then
                  Blk.all (Pos .. Pos + 15) := UUID;
                  Pos := Pos + 16;
               end if;
            end;
         end loop;
      end;
      Dwrite (Jphys (First), Blk.all);

      --  4. Data blocks (direct) at First+1 .. First+N.
      for I in 1 .. N loop
         if Targets (I) = SB_Blk then
            Blk.all := SBblk.all;
         else
            Block_Cache.Read (V.Cache, Targets (I), Blk.all);
         end if;
         if Get_U32_BE (Blk.all, 0) = Magic then
            Put_U32_BE (Blk.all, 0, 0);     --  escape (flag set in the tag)

         end if;
         Dwrite (Jphys (First + U64 (I)), Blk.all);
      end loop;

      --  5. Commit block (direct) at First+N+1.
      Blk.all := [others => 0];
      Put_U32_BE (Blk.all, 0, Magic);
      Put_U32_BE (Blk.all, 4, BT_Commit);
      Put_U32_BE (Blk.all, 8, S_Seq);
      Dwrite (Jphys (First + U64 (N) + 1), Blk.all);

      --  6. Point the journal superblock at this transaction (direct).
      Dread (Jphys (0), Jsb.all);
      Put_U32_BE (Jsb.all, 16#1C#, U32 (First));
      Put_U32_BE (Jsb.all, 16#18#, S_Seq);
      Dwrite (Jphys (0), Jsb.all);

      --  7. THE BARRIER: set RECOVER on disk.  Now the transaction is committed.
      Write_SB_Raw (Recover => True);

      if Simulate_Crash then
         --  stop -- metadata NOT yet checkpointed
         Free (Jsb);
         Free (Blk);
         Free (SBblk);
         return;
      end if;

      --  8. Checkpoint the metadata to its final locations.
      Block_Cache.Flush (V.Cache);

      --  9. Clear RECOVER (final state) and reset the journal.
      Write_SB_Raw (Recover => False);
      Dread (Jphys (0), Jsb.all);
      Put_U32_BE (Jsb.all, 16#1C#, 0);
      Put_U32_BE (Jsb.all, 16#18#, S_Seq + 1);
      Dwrite (Jphys (0), Jsb.all);

      Free (Jsb);
      Free (Blk);
      Free (SBblk);
   end Transaction_Commit;

end ESP32S3.Ext4.Journal;
