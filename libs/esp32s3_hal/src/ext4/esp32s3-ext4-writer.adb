with Interfaces; use Interfaces;
with Ada.Unchecked_Deallocation;
with ESP32S3.Ext4.Bitmap;
with ESP32S3.Ext4.Inode;
with ESP32S3.Ext4.Dir;
with ESP32S3.Ext4.Path;
with ESP32S3.Ext4.Block_Cache;

package body ESP32S3.Ext4.Writer is

   type Bytes_Ptr is access Byte_Array;
   procedure Free is new Ada.Unchecked_Deallocation (Byte_Array, Bytes_Ptr);

   procedure Guard (V : Volume.Context) is
   begin
      if V.Read_Only then
         raise Read_Only with "volume mounted read-only";
      end if;
      if V.SB.Has_Csum then
         raise Read_Only with "write to a metadata_csum filesystem not supported";
      end if;
   end Guard;

   --  Free a direct/single-indirect inode's data blocks (+ its indirect block).
   procedure Free_Inode_Blocks (V : in out Volume.Context; CI : Inode.Info);

   -----------------
   -- Create_File --
   -----------------

   function Create_File (V : in out Volume.Context; Dir_Path, Name : String)
      return Inode_Number
   is
      Dir_I : Inode.Info;
      Child : Inode_Number;
      CI    : Inode.Info;
   begin
      Guard (V);
      Inode.Read (V, Path.Resolve (V, Dir_Path), Dir_I);
      if not Inode.Is_Dir (Dir_I) then
         raise Use_Error with "parent is not a directory";
      end if;

      Child := Bitmap.Alloc_Inode (V, As_Dir => False);
      CI := (Mode       => 16#8180#,        --  S_IFREG | 0644
             Size       => 0,
             Flags      => 0,               --  indirect-mapped (no EXTENTS_FL)
             Links      => 1,
             Blocks_512 => 0,
             I_Block    => [others => 0]);
      Inode.Write (V, Child, CI, Fresh => True);

      Dir.Add_Entry (V, Dir_I, Name, Child, Dir.FT_Reg);
      return Child;
   end Create_File;

   -----------------
   -- Write_Small --
   -----------------

   procedure Write_Small (V : in out Volume.Context; N : Inode_Number;
                          Data : Byte_Array)
   is
      BS    : constant Natural := V.SB.Block_Size;
      PPB   : constant Natural := BS / 4;                  --  pointers per block
      N_Blk : constant Natural := (Data'Length + BS - 1) / BS;
      I     : Inode.Info;
      Buf   : Bytes_Ptr := new Byte_Array (0 .. BS - 1);
      Ind   : Block_Number := 0;                           --  single-indirect block
      Meta  : Natural := 0;                                --  indirect metadata blocks
      Ptr   : Byte_Array (0 .. 3);
   begin
      Guard (V);
      if N_Blk > 12 + PPB then
         Free (Buf);
         raise Use_Error with "file too large (single-indirect maximum)";
      end if;

      Inode.Read (V, N, I);
      for B in 0 .. N_Blk - 1 loop
         declare
            Phys : constant Block_Number := Bitmap.Alloc_Block (V);
            Lo   : constant Natural := B * BS;
            Cnt  : constant Natural := Natural'Min (BS, Data'Length - Lo);
         begin
            Buf.all := [others => 0];
            Buf (0 .. Cnt - 1) := Data (Data'First + Lo .. Data'First + Lo + Cnt - 1);
            ESP32S3.Ext4.Block_Cache.Write (V.Cache, Phys, Buf.all);

            if B < 12 then
               Put_U32 (I.I_Block, B * 4, U32 (Phys));
            else
               if Ind = 0 then                             --  first indirect ref
                  Ind  := Bitmap.Alloc_Block (V);
                  Meta := Meta + 1;
                  Buf.all := [others => 0];
                  ESP32S3.Ext4.Block_Cache.Write (V.Cache, Ind, Buf.all);
                  Put_U32 (I.I_Block, 12 * 4, U32 (Ind));
               end if;
               Put_U32 (Ptr, 0, U32 (Phys));
               ESP32S3.Ext4.Block_Cache.Write_At (V.Cache, Ind, (B - 12) * 4, Ptr);
            end if;
         end;
      end loop;

      I.Size       := U64 (Data'Length);
      I.Blocks_512 := U64 (N_Blk + Meta) * U64 (BS / 512);
      Inode.Write (V, N, I, Fresh => False);
      Free (Buf);
   end Write_Small;

   ------------
   -- Append --
   ------------

   --  Write a freshly-allocated metadata block as all-zero (no stale pointers).
   procedure Zero_Block (V : in out Volume.Context; B : Block_Number) is
      Zeros : constant Byte_Array (0 .. V.SB.Block_Size - 1) := [others => 0];
   begin
      ESP32S3.Ext4.Block_Cache.Write (V.Cache, B, Zeros);
   end Zero_Block;

   --  Read the data-block pointer at slot Slot of indirect block Ind, allocating
   --  the data block (Fresh => True) when the slot is empty.
   function Slot_Block (V     : in out Volume.Context;
                        Ind   : Block_Number;
                        Slot  : Natural;
                        Fresh : out Boolean) return Block_Number
   is
      Ptr  : Byte_Array (0 .. 3);
      Phys : Block_Number;
   begin
      Fresh := False;
      ESP32S3.Ext4.Block_Cache.Read_At (V.Cache, Ind, Slot * 4, Ptr);
      Phys := Block_Number (Get_U32 (Ptr, 0));
      if Phys = 0 then
         Phys := Bitmap.Alloc_Block (V);
         Put_U32 (Ptr, 0, U32 (Phys));
         ESP32S3.Ext4.Block_Cache.Write_At (V.Cache, Ind, Slot * 4, Ptr);
         Fresh := True;
      end if;
      return Phys;
   end Slot_Block;

   --  Map logical block L_Block of inode I to a physical block, allocating it
   --  and any indirect / double-indirect metadata on the way.  Updates I.I_Block
   --  in memory; Fresh is True when a NEW data block was allocated.  Direct +
   --  single + double indirect (up to 12 + PPB + PPB**2 blocks); triple indirect
   --  is not supported -- the same reach as the free/truncate path, so nothing
   --  un-freeable is ever created.
   function Map_Or_Alloc (V       : in out Volume.Context;
                          I       : in out Inode.Info;
                          L_Block : Natural;
                          Fresh   : out Boolean) return Block_Number
   is
      PPB : constant Natural := V.SB.Block_Size / 4;

      --  The indirect pointer at byte Off of the inode, allocating+zeroing a
      --  fresh metadata block there when empty.
      function Inode_Indirect (Off : Natural) return Block_Number is
         B : Block_Number := Block_Number (Get_U32 (I.I_Block, Off));
      begin
         if B = 0 then
            B := Bitmap.Alloc_Block (V);
            Zero_Block (V, B);
            Put_U32 (I.I_Block, Off, U32 (B));
         end if;
         return B;
      end Inode_Indirect;

      --  As Inode_Indirect but for slot Slot inside another indirect block.
      function Child_Indirect (Parent : Block_Number; Slot : Natural)
         return Block_Number
      is
         Ptr : Byte_Array (0 .. 3);
         B   : Block_Number;
      begin
         ESP32S3.Ext4.Block_Cache.Read_At (V.Cache, Parent, Slot * 4, Ptr);
         B := Block_Number (Get_U32 (Ptr, 0));
         if B = 0 then
            B := Bitmap.Alloc_Block (V);
            Zero_Block (V, B);
            Put_U32 (Ptr, 0, U32 (B));
            ESP32S3.Ext4.Block_Cache.Write_At (V.Cache, Parent, Slot * 4, Ptr);
         end if;
         return B;
      end Child_Indirect;

      Phys : Block_Number;
   begin
      Fresh := False;
      if L_Block < 12 then
         Phys := Block_Number (Get_U32 (I.I_Block, L_Block * 4));
         if Phys = 0 then
            Phys := Bitmap.Alloc_Block (V);
            Put_U32 (I.I_Block, L_Block * 4, U32 (Phys));
            Fresh := True;
         end if;
         return Phys;

      elsif L_Block < 12 + PPB then                       --  single indirect
         return Slot_Block (V, Inode_Indirect (48), L_Block - 12, Fresh);

      elsif L_Block < 12 + PPB + PPB * PPB then            --  double indirect
         declare
            Rel : constant Natural := L_Block - 12 - PPB;
            Dbl : constant Block_Number := Inode_Indirect (52);
            Sng : constant Block_Number := Child_Indirect (Dbl, Rel / PPB);
         begin
            return Slot_Block (V, Sng, Rel mod PPB, Fresh);
         end;

      else
         raise Use_Error with "file too large (double-indirect maximum)";
      end if;
   end Map_Or_Alloc;

   procedure Append (V : in out Volume.Context; N : Inode_Number;
                     Data : Byte_Array)
   is
      BS  : constant Natural := V.SB.Block_Size;
      PPB : constant Natural := BS / 4;
      I   : Inode.Info;
      Buf : Bytes_Ptr := new Byte_Array (0 .. BS - 1);
      Pos : U64;
      Src : Natural := Data'First;

      --  i_blocks for a file of Size bytes: data blocks plus the indirect
      --  metadata (the single-indirect block, and for the double-indirect range
      --  the double-indirect block + one single-indirect child per PPB blocks).
      function I_Blocks (Size : U64) return U64 is
         Total : constant Natural := Natural ((Size + U64 (BS) - 1) / U64 (BS));
         Meta  : Natural := 0;
      begin
         if Total > 12 then
            Meta := Meta + 1;
         end if;
         if Total > 12 + PPB then
            Meta := Meta + 1 + (Total - 12 - PPB + PPB - 1) / PPB;
         end if;
         return U64 (Total + Meta) * U64 (BS / 512);
      end I_Blocks;
   begin
      Guard (V);
      if Data'Length = 0 then
         Free (Buf);
         return;
      end if;

      Inode.Read (V, N, I);
      if not Inode.Is_Reg (I) then
         Free (Buf);
         raise Use_Error with "append to a non-regular file";
      end if;
      Pos := I.Size;

      --  Reject an over-large final size up front, before allocating anything.
      if Natural ((Pos + U64 (Data'Length) + U64 (BS) - 1) / U64 (BS))
           > 12 + PPB + PPB * PPB
      then
         Free (Buf);
         raise Use_Error with "file too large (double-indirect maximum)";
      end if;

      declare
         Left : Natural := Data'Length;
      begin
         while Left > 0 loop
            declare
               L_Block : constant Natural := Natural (Pos / U64 (BS));
               Off     : constant Natural := Natural (Pos mod U64 (BS));
               Chunk   : constant Natural := Natural'Min (BS - Off, Left);
               Fresh   : Boolean;
               Phys    : constant Block_Number :=
                           Map_Or_Alloc (V, I, L_Block, Fresh);
            begin
               if Off = 0 and then Chunk = BS then
                  Buf.all := Data (Src .. Src + BS - 1);
               else
                  if Fresh then
                     Buf.all := [others => 0];
                  else
                     ESP32S3.Ext4.Block_Cache.Read (V.Cache, Phys, Buf.all);
                  end if;
                  Buf (Off .. Off + Chunk - 1) := Data (Src .. Src + Chunk - 1);
               end if;
               ESP32S3.Ext4.Block_Cache.Write (V.Cache, Phys, Buf.all);
               Pos := Pos + U64 (Chunk);
               Src := Src + Chunk;
               Left := Left - Chunk;
            end;
         end loop;
      exception
         when others =>          --  e.g. No_Space: commit what was written
            I.Size       := Pos;
            I.Blocks_512 := I_Blocks (Pos);
            Inode.Write (V, N, I, Fresh => False);
            Free (Buf);
            raise;
      end;

      I.Size       := Pos;
      I.Blocks_512 := I_Blocks (Pos);
      Inode.Write (V, N, I, Fresh => False);
      Free (Buf);
   end Append;

   -----------
   -- Mkdir --
   -----------

   procedure Mkdir (V : in out Volume.Context; Dir_Path, Name : String) is
      BS       : constant Natural := V.SB.Block_Size;
      Parent_N : Inode_Number;
      Parent_I : Inode.Info;
      New_N    : Inode_Number;
      Blk      : Block_Number;
      DI       : Inode.Info;
      Buf      : Bytes_Ptr := new Byte_Array (0 .. BS - 1);
   begin
      Guard (V);
      Parent_N := Path.Resolve (V, Dir_Path);
      Inode.Read (V, Parent_N, Parent_I);
      if not Inode.Is_Dir (Parent_I) then
         Free (Buf);
         raise Use_Error with "parent is not a directory";
      end if;

      New_N := Bitmap.Alloc_Inode (V, As_Dir => True);
      Blk   := Bitmap.Alloc_Block (V);

      --  Lay down "." (-> self) and ".." (-> parent), ".." spanning the block.
      Buf.all := [others => 0];
      Put_U32 (Buf.all, 0, U32 (New_N));
      Put_U16 (Buf.all, 4, 12);
      Put_U8  (Buf.all, 6, 1);
      Put_U8  (Buf.all, 7, Dir.FT_Dir);
      Buf (8) := Character'Pos ('.');
      Put_U32 (Buf.all, 12, U32 (Parent_N));
      Put_U16 (Buf.all, 16, U16 (BS - 12));
      Put_U8  (Buf.all, 18, 2);
      Put_U8  (Buf.all, 19, Dir.FT_Dir);
      Buf (20) := Character'Pos ('.');
      Buf (21) := Character'Pos ('.');
      ESP32S3.Ext4.Block_Cache.Write (V.Cache, Blk, Buf.all);
      Free (Buf);

      DI := (Mode       => 16#41ED#,          --  S_IFDIR | 0755
             Size       => U64 (BS),
             Flags      => 0,
             Links      => 2,                  --  "." + the parent's entry
             Blocks_512 => U64 (BS / 512),
             I_Block    => [others => 0]);
      Put_U32 (DI.I_Block, 0, U32 (Blk));
      Inode.Write (V, New_N, DI, Fresh => True);

      Dir.Add_Entry (V, Parent_I, Name, New_N, Dir.FT_Dir);

      Parent_I.Links := Parent_I.Links + 1;    --  the new dir's ".." -> parent
      Inode.Write (V, Parent_N, Parent_I, Fresh => False);
   end Mkdir;

   ------------
   -- Unlink --
   ------------

   procedure Unlink (V : in out Volume.Context; Dir_Path, Name : String) is
      Dir_I : Inode.Info;
      Child : Inode_Number;
      CI    : Inode.Info;
   begin
      Guard (V);
      Inode.Read (V, Path.Resolve (V, Dir_Path), Dir_I);
      if not Inode.Is_Dir (Dir_I) then
         raise Use_Error with "parent is not a directory";
      end if;

      Child := Dir.Lookup (V, Dir_I, Name);
      if Child = 0 then
         raise Name_Error with "no such file: " & Name;
      end if;
      Inode.Read (V, Child, CI);
      if Inode.Is_Dir (CI) then
         raise Use_Error with "is a directory (use Rmdir)";
      end if;

      if CI.Links <= 1 then
         Free_Inode_Blocks (V, CI);
         Bitmap.Free_Inode (V, Child, Was_Dir => False);
         Inode.Mark_Deleted (V, Child);
      else
         CI.Links := CI.Links - 1;
         Inode.Write (V, Child, CI, Fresh => False);
      end if;

      declare
         Removed : constant Inode_Number := Dir.Remove_Entry (V, Dir_I, Name);
         pragma Unreferenced (Removed);
      begin
         null;
      end;
   end Unlink;

   --  ext file_type byte for an inode.
   function FType_Of (CI : Inode.Info) return U8 is
     (if Inode.Is_Dir (CI) then Dir.FT_Dir
      elsif Inode.Is_Symlink (CI) then Dir.FT_Symlink
      else Dir.FT_Reg);

   --  Free the first Count data-block pointers of single-indirect block Sng,
   --  then Sng itself.
   procedure Free_Single (V : in out Volume.Context; Sng : U32; Count : Natural)
   is
      Ptr : Byte_Array (0 .. 3);
   begin
      if Sng = 0 then
         return;
      end if;
      for K in 0 .. Count - 1 loop
         ESP32S3.Ext4.Block_Cache.Read_At (V.Cache, Block_Number (Sng), K * 4, Ptr);
         declare
            P : constant U32 := Get_U32 (Ptr, 0);
         begin
            if P /= 0 then
               Bitmap.Free_Block (V, Block_Number (P));
            end if;
         end;
      end loop;
      Bitmap.Free_Block (V, Block_Number (Sng));
   end Free_Single;

   --  Free a double-indirect block Dbl mapping Data_Count data blocks: every
   --  data block, each single-indirect child, then Dbl itself.
   procedure Free_Double (V : in out Volume.Context; Dbl : U32;
                          Data_Count : Natural)
   is
      PPB  : constant Natural := V.SB.Block_Size / 4;
      Ptr  : Byte_Array (0 .. 3);
      Left : Natural := Data_Count;
      Slot : Natural := 0;
   begin
      if Dbl = 0 then
         return;
      end if;
      while Left > 0 loop
         ESP32S3.Ext4.Block_Cache.Read_At
           (V.Cache, Block_Number (Dbl), Slot * 4, Ptr);
         Free_Single (V, Get_U32 (Ptr, 0), Natural'Min (PPB, Left));
         Left := Left - Natural'Min (PPB, Left);
         Slot := Slot + 1;
      end loop;
      Bitmap.Free_Block (V, Block_Number (Dbl));
   end Free_Double;

   --  Shrink a double-indirect region: free its data blocks [Keep, Old) and the
   --  single-indirect children that become empty, keeping the first Keep blocks
   --  (Keep > 0; for Keep = 0 use Free_Double, which also frees the double block).
   procedure Free_Double_Tail (V : in out Volume.Context; Dbl : U32;
                               Keep, Old : Natural)
   is
      PPB : constant Natural := V.SB.Block_Size / 4;
      Ptr : Byte_Array (0 .. 3);
   begin
      if Dbl = 0 then
         return;
      end if;
      for Child in Keep / PPB .. (Old - 1) / PPB loop
         ESP32S3.Ext4.Block_Cache.Read_At
           (V.Cache, Block_Number (Dbl), Child * 4, Ptr);
         declare
            Sng       : constant U32 := Get_U32 (Ptr, 0);
            Keep_In   : constant Natural :=
              (if Child = Keep / PPB then Keep mod PPB else 0);
            Child_Old : constant Natural := Natural'Min (PPB, Old - Child * PPB);
         begin
            if Keep_In = 0 then                  --  this child is fully freed
               Free_Single (V, Sng, Child_Old);
               Put_U32 (Ptr, 0, 0);
               ESP32S3.Ext4.Block_Cache.Write_At
                 (V.Cache, Block_Number (Dbl), Child * 4, Ptr);
            elsif Sng /= 0 then                  --  straddling child: free its tail
               for S in Keep_In .. Child_Old - 1 loop
                  declare
                     SPtr : Byte_Array (0 .. 3);
                  begin
                     ESP32S3.Ext4.Block_Cache.Read_At
                       (V.Cache, Block_Number (Sng), S * 4, SPtr);
                     declare
                        P : constant U32 := Get_U32 (SPtr, 0);
                     begin
                        if P /= 0 then
                           Bitmap.Free_Block (V, Block_Number (P));
                        end if;
                     end;
                     Put_U32 (SPtr, 0, 0);
                     ESP32S3.Ext4.Block_Cache.Write_At
                       (V.Cache, Block_Number (Sng), S * 4, SPtr);
                  end;
               end loop;
            end if;
         end;
      end loop;
   end Free_Double_Tail;

   --  Free a direct / single / double-indirect inode's data + metadata blocks.
   --  Triple-indirect and extent maps aren't freeable yet.
   procedure Free_Inode_Blocks (V : in out Volume.Context; CI : Inode.Info) is
      BS    : constant Natural := V.SB.Block_Size;
      PPB   : constant Natural := BS / 4;
      N_Blk : constant Natural := Natural ((CI.Size + U64 (BS) - 1) / U64 (BS));
   begin
      --  A symlink's i_block holds either inline target text (fast symlink, no
      --  data blocks) or a single block pointer (slow symlink) -- never the
      --  classic block map, so it must not run through the loops below.
      if Inode.Is_Symlink (CI) then
         if CI.Blocks_512 /= 0 then               --  slow symlink: one block
            declare
               P : constant U32 := Get_U32 (CI.I_Block, 0);
            begin
               if P /= 0 then
                  Bitmap.Free_Block (V, Block_Number (P));
               end if;
            end;
         end if;
         return;
      end if;

      if Inode.Uses_Extents (CI)
        or else Get_U32 (CI.I_Block, 56) /= 0      --  triple indirect
      then
         raise Unsupported_Feature
           with "free of triple-indirect or extent-mapped inode";
      end if;

      for B in 0 .. Natural'Min (N_Blk, 12) - 1 loop
         declare
            Phys : constant U32 := Get_U32 (CI.I_Block, B * 4);
         begin
            if Phys /= 0 then
               Bitmap.Free_Block (V, Block_Number (Phys));
            end if;
         end;
      end loop;

      if N_Blk > 12 then
         Free_Single (V, Get_U32 (CI.I_Block, 48),
                      Natural'Min (N_Blk - 12, PPB));
      end if;
      if N_Blk > 12 + PPB then
         Free_Double (V, Get_U32 (CI.I_Block, 52), N_Blk - 12 - PPB);
      end if;
   end Free_Inode_Blocks;

   -----------
   -- Rmdir --
   -----------

   procedure Rmdir (V : in out Volume.Context; Dir_Path, Name : String) is
      Parent_N : Inode_Number;
      Parent_I : Inode.Info;
      Child    : Inode_Number;
      CI       : Inode.Info;
   begin
      Guard (V);
      Parent_N := Path.Resolve (V, Dir_Path);
      Inode.Read (V, Parent_N, Parent_I);
      if not Inode.Is_Dir (Parent_I) then
         raise Use_Error with "parent is not a directory";
      end if;

      Child := Dir.Lookup (V, Parent_I, Name);
      if Child = 0 then
         raise Name_Error with "no such directory: " & Name;
      end if;
      Inode.Read (V, Child, CI);
      if not Inode.Is_Dir (CI) then
         raise Use_Error with "not a directory (use Unlink)";
      end if;
      if not Dir.Is_Empty (V, CI) then
         raise Not_Empty with "directory not empty: " & Name;
      end if;

      Free_Inode_Blocks (V, CI);
      Bitmap.Free_Inode (V, Child, Was_Dir => True);
      Inode.Mark_Deleted (V, Child);

      declare
         R : constant Inode_Number := Dir.Remove_Entry (V, Parent_I, Name);
         pragma Unreferenced (R);
      begin
         null;
      end;
      Parent_I.Links := Parent_I.Links - 1;   --  the child's ".." is gone
      Inode.Write (V, Parent_N, Parent_I, Fresh => False);
   end Rmdir;

   ------------
   -- Rename --
   ------------

   procedure Rename (V : in out Volume.Context;
                     Old_Dir, Old_Name, New_Dir, New_Name : String)
   is
      ON, NN  : Inode_Number;
      Old_DI  : Inode.Info;
      New_DI  : Inode.Info;
      Child   : Inode_Number;
      CI      : Inode.Info;
   begin
      Guard (V);
      ON := Path.Resolve (V, Old_Dir);
      NN := Path.Resolve (V, New_Dir);
      Inode.Read (V, ON, Old_DI);
      if ON = NN then
         New_DI := Old_DI;
      else
         Inode.Read (V, NN, New_DI);
      end if;
      if not Inode.Is_Dir (Old_DI) or else not Inode.Is_Dir (New_DI) then
         raise Use_Error with "rename endpoint is not a directory";
      end if;

      Child := Dir.Lookup (V, Old_DI, Old_Name);
      if Child = 0 then
         raise Name_Error with "no such file: " & Old_Name;
      end if;
      if Dir.Lookup (V, New_DI, New_Name) /= 0 then
         raise Use_Error with "rename target already exists: " & New_Name;
      end if;
      Inode.Read (V, Child, CI);

      Dir.Add_Entry (V, New_DI, New_Name, Child, FType_Of (CI));
      declare
         R : constant Inode_Number := Dir.Remove_Entry (V, Old_DI, Old_Name);
         pragma Unreferenced (R);
      begin
         null;
      end;

      --  Moving a directory to a different parent: repoint its ".." and adjust
      --  both parents' link counts.
      if Inode.Is_Dir (CI) and then ON /= NN then
         declare
            Ok : constant Boolean := Dir.Set_Entry_Inode (V, CI, "..", NN);
            NP : Inode.Info;
         begin
            if not Ok then
               raise Corrupt with "directory has no "".."" entry";
            end if;
            Old_DI.Links := Old_DI.Links - 1;
            Inode.Write (V, ON, Old_DI, Fresh => False);
            Inode.Read (V, NN, NP);
            NP.Links := NP.Links + 1;
            Inode.Write (V, NN, NP, Fresh => False);
         end;
      end if;
   end Rename;

   --------------
   -- Truncate --
   --------------

   procedure Truncate (V : in out Volume.Context; N : Inode_Number; New_Size : U64) is
      I   : Inode.Info;
      BS  : constant Natural := V.SB.Block_Size;
      PPB : constant Natural := BS / 4;
      Ptr : Byte_Array (0 .. 3);
   begin
      Guard (V);
      Inode.Read (V, N, I);
      if not Inode.Is_Reg (I) then
         raise Use_Error with "not a regular file";
      end if;
      if Inode.Uses_Extents (I)
        or else Get_U32 (I.I_Block, 56) /= 0          --  triple indirect
      then
         raise Unsupported_Feature with "truncate of triple-indirect / extent file";
      end if;

      declare
         Old_NB : constant Natural := Natural ((I.Size   + U64 (BS) - 1) / U64 (BS));
         New_NB : constant Natural := Natural ((New_Size + U64 (BS) - 1) / U64 (BS));
      begin
         if New_NB < Old_NB then
            --  Direct region [0 .. 12).
            if New_NB < 12 then
               for B in New_NB .. Natural'Min (Old_NB, 12) - 1 loop
                  declare
                     Phys : constant U32 := Get_U32 (I.I_Block, B * 4);
                  begin
                     if Phys /= 0 then
                        Bitmap.Free_Block (V, Block_Number (Phys));
                     end if;
                     Put_U32 (I.I_Block, B * 4, 0);
                  end;
               end loop;
            end if;

            --  Single-indirect region [12 .. 12+PPB).
            if Old_NB > 12 then
               declare
                  Keep : constant Natural := (if New_NB > 12 then New_NB - 12 else 0);
                  Old_Single : constant Natural := Natural'Min (Old_NB - 12, PPB);
                  Sng  : constant U32 := Get_U32 (I.I_Block, 48);
               begin
                  if Keep < Old_Single then
                     if Keep = 0 then
                        Free_Single (V, Sng, Old_Single);
                        Put_U32 (I.I_Block, 48, 0);
                     elsif Sng /= 0 then
                        for S in Keep .. Old_Single - 1 loop
                           ESP32S3.Ext4.Block_Cache.Read_At
                             (V.Cache, Block_Number (Sng), S * 4, Ptr);
                           declare
                              P : constant U32 := Get_U32 (Ptr, 0);
                           begin
                              if P /= 0 then
                                 Bitmap.Free_Block (V, Block_Number (P));
                              end if;
                           end;
                           Put_U32 (Ptr, 0, 0);
                           ESP32S3.Ext4.Block_Cache.Write_At
                             (V.Cache, Block_Number (Sng), S * 4, Ptr);
                        end loop;
                     end if;
                  end if;
               end;
            end if;

            --  Double-indirect region [12+PPB .. 12+PPB+PPB**2).
            if Old_NB > 12 + PPB then
               declare
                  Keep : constant Natural :=
                    (if New_NB > 12 + PPB then New_NB - 12 - PPB else 0);
                  Old_Double : constant Natural := Old_NB - 12 - PPB;
                  Dbl  : constant U32 := Get_U32 (I.I_Block, 52);
               begin
                  if Keep = 0 then
                     Free_Double (V, Dbl, Old_Double);
                     Put_U32 (I.I_Block, 52, 0);
                  elsif Keep < Old_Double then
                     Free_Double_Tail (V, Dbl, Keep, Old_Double);
                  end if;
               end;
            end if;

            --  i_blocks for the new size: data blocks + indirect metadata.
            declare
               Meta : Natural := 0;
            begin
               if New_NB > 12 then
                  Meta := Meta + 1;
               end if;
               if New_NB > 12 + PPB then
                  Meta := Meta + 1 + (New_NB - 12 - PPB + PPB - 1) / PPB;
               end if;
               I.Blocks_512 := U64 (New_NB + Meta) * U64 (BS / 512);
            end;
         end if;
      end;

      I.Size := New_Size;
      Inode.Write (V, N, I, Fresh => False);
   end Truncate;

   ----------
   -- Link --
   ----------

   procedure Link (V : in out Volume.Context;
                   Target_Path, New_Dir, New_Name : String)
   is
      TN  : constant Inode_Number := Path.Resolve (V, Target_Path);
      TI  : Inode.Info;
      NDI : Inode.Info;
   begin
      Guard (V);
      Inode.Read (V, TN, TI);
      if Inode.Is_Dir (TI) then
         raise Use_Error with "hard link to a directory";
      end if;
      Inode.Read (V, Path.Resolve (V, New_Dir), NDI);
      if not Inode.Is_Dir (NDI) then
         raise Use_Error with "link parent is not a directory";
      end if;
      if Dir.Lookup (V, NDI, New_Name) /= 0 then
         raise Use_Error with "link target already exists: " & New_Name;
      end if;
      Dir.Add_Entry (V, NDI, New_Name, TN, FType_Of (TI));
      TI.Links := TI.Links + 1;
      Inode.Write (V, TN, TI, Fresh => False);
   end Link;

   ------------------
   -- Make_Symlink --
   ------------------

   procedure Make_Symlink (V : in out Volume.Context;
                           Dir_Path, Name, Target : String)
   is
      BS    : constant Natural := V.SB.Block_Size;
      Dir_I : Inode.Info;
      Child : Inode_Number;
      CI    : Inode.Info;
   begin
      Guard (V);
      if Target'Length = 0 then
         raise Use_Error with "empty symlink target";
      end if;
      if Target'Length > BS then
         raise Use_Error with "symlink target longer than one block";
      end if;

      Inode.Read (V, Path.Resolve (V, Dir_Path), Dir_I);
      if not Inode.Is_Dir (Dir_I) then
         raise Use_Error with "parent is not a directory";
      end if;
      if Dir.Lookup (V, Dir_I, Name) /= 0 then
         raise Use_Error with "symlink target already exists: " & Name;
      end if;

      Child := Bitmap.Alloc_Inode (V, As_Dir => False);
      CI := (Mode       => 16#A1FF#,         --  S_IFLNK | 0777
             Size       => U64 (Target'Length),
             Flags      => 0,
             Links      => 1,
             Blocks_512 => 0,
             I_Block    => [others => 0]);

      if Target'Length < 60 then
         --  Fast symlink: the link text lives inline in the 60-byte i_block.
         for K in 0 .. Target'Length - 1 loop
            CI.I_Block (K) := Character'Pos (Target (Target'First + K));
         end loop;
         Inode.Write (V, Child, CI, Fresh => True);
      else
         --  Slow symlink: one data block holds the link text.
         declare
            Phys : constant Block_Number := Bitmap.Alloc_Block (V);
            Buf  : Bytes_Ptr := new Byte_Array (0 .. BS - 1);
         begin
            Buf.all := [others => 0];
            for K in 0 .. Target'Length - 1 loop
               Buf (K) := Character'Pos (Target (Target'First + K));
            end loop;
            ESP32S3.Ext4.Block_Cache.Write (V.Cache, Phys, Buf.all);
            Put_U32 (CI.I_Block, 0, U32 (Phys));
            CI.Blocks_512 := U64 (BS / 512);
            Inode.Write (V, Child, CI, Fresh => True);
            Free (Buf);
         end;
      end if;

      Dir.Add_Entry (V, Dir_I, Name, Child, Dir.FT_Symlink);
   end Make_Symlink;

end ESP32S3.Ext4.Writer;
