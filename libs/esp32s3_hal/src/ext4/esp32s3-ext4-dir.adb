with Interfaces; use Interfaces;
with ESP32S3.Ext4.Block_Cache;
with ESP32S3.Ext4.Block_Map;

package body ESP32S3.Ext4.Dir is

   --  Convert raw name bytes to a String.
   function To_String (B : Byte_Array) return String is
      S : String (1 .. B'Length);
   begin
      for I in S'Range loop
         S (I) := Character'Val (B (B'First + I - 1));
      end loop;
      return S;
   end To_String;

   --  Walk every entry of Dir, invoking Visit; if Visit returns True, stop.
   generic
      with function Visit (Name : String; Ino : Inode_Number; File_Type : U8) return Boolean;
   procedure Walk (V : in out Volume.Context; Dir : Inode.Info);

   procedure Walk (V : in out Volume.Context; Dir : Inode.Info) is
      BS    : constant Natural := V.SB.Block_Size;
      N_Blk : constant U64 := (Dir.Size + U64 (BS) - 1) / U64 (BS);
      Hdr   : Byte_Array (0 .. 7);
   begin
      for LB in 0 .. N_Blk - 1 loop
         declare
            Phys : constant Block_Number := Block_Map.Logical_To_Physical (V, Dir, LB);
            Pos  : Natural := 0;
         begin
            if Phys /= 0 then
               while Pos + 8 <= BS loop
                  ESP32S3.Ext4.Block_Cache.Read_At (V.Cache, Phys, Pos, Hdr);
                  declare
                     Ino      : constant U32 := Get_U32 (Hdr, 0);
                     Rec_Len  : constant Natural := Natural (Get_U16 (Hdr, 4));
                     Name_Len : constant Natural := Natural (Get_U8 (Hdr, 6));
                     Ftype    : constant U8 := Get_U8 (Hdr, 7);
                  begin
                     exit when Rec_Len < 8;            --  malformed: avoid a loop
                     exit when Pos + Rec_Len > BS;     --  entry must stay in-block
                     if Ino /= 0 and then Name_Len > 0 and then Pos + 8 + Name_Len <= BS then
                        declare
                           Nm : Byte_Array (0 .. Name_Len - 1);
                        begin
                           ESP32S3.Ext4.Block_Cache.Read_At (V.Cache, Phys, Pos + 8, Nm);
                           if Visit (To_String (Nm), Inode_Number (Ino), Ftype) then
                              return;
                           end if;
                        end;
                     end if;
                     Pos := Pos + Rec_Len;
                  end;
               end loop;
            end if;
         end;
      end loop;
   end Walk;

   ------------
   -- Lookup --
   ------------

   function Lookup (V : in out Volume.Context; Dir : Inode.Info; Name : String) return Inode_Number
   is
      Found : Inode_Number := 0;

      function Match (Nm : String; Ino : Inode_Number; Ft : U8) return Boolean is
         pragma Unreferenced (Ft);
      begin
         if Nm = Name then
            Found := Ino;
            return True;            --  stop the walk

         end if;
         return False;
      end Match;

      procedure Do_Walk is new Walk (Match);
   begin
      Do_Walk (V, Dir);
      return Found;
   end Lookup;

   -------------
   -- Iterate --
   -------------

   procedure Iterate
     (V     : in out Volume.Context;
      Dir   : Inode.Info;
      Visit : not null access procedure (Name : String; Ino : Inode_Number; File_Type : U8))
   is
      function Call (Nm : String; Ino : Inode_Number; Ft : U8) return Boolean is
      begin
         Visit (Nm, Ino, Ft);
         return False;             --  never stop early
      end Call;

      procedure Do_Walk is new Walk (Call);
   begin
      Do_Walk (V, Dir);
   end Iterate;

   ---------------
   -- Add_Entry --
   ---------------

   procedure Add_Entry
     (V         : in out Volume.Context;
      Dir       : Inode.Info;
      Name      : String;
      Child     : Inode_Number;
      File_Type : U8)
   is
      function R4 (N : Natural) return Natural
      is ((N + 3) / 4 * 4);
      BS     : constant Natural := V.SB.Block_Size;
      N_Blk  : constant U64 := (Dir.Size + U64 (BS) - 1) / U64 (BS);
      Needed : constant Natural := 8 + R4 (Name'Length);
      Hdr    : Byte_Array (0 .. 7);

      procedure Place (Phys : Block_Number; At_Pos : Natural; Rec : Natural) is
         Ent : Byte_Array (0 .. 8 + Name'Length - 1);
      begin
         Put_U32 (Ent, 0, U32 (Child));
         Put_U16 (Ent, 4, U16 (Rec));
         Put_U8 (Ent, 6, U8 (Name'Length));
         Put_U8 (Ent, 7, File_Type);
         for K in Name'Range loop
            Ent (8 + (K - Name'First)) := Character'Pos (Name (K));
         end loop;
         ESP32S3.Ext4.Block_Cache.Write_At (V.Cache, Phys, At_Pos, Ent);
      end Place;
   begin
      --  Reject a name that already exists: ext directory entries must be unique,
      --  and a blind append would create a DUPLICATE dirent (an e2fsck error, and
      --  Lookup/Remove would then only ever see the first). Callers that mean to
      --  replace remove the old entry first; this makes "create" fail cleanly
      --  instead of silently corrupting the directory -- e.g. FTP MKD of an
      --  existing dir. Use_Error matches the Link/Rename "already exists" checks.
      if Lookup (V, Dir, Name) /= 0 then
         raise Use_Error with "entry already exists: " & Name;
      end if;

      for LB in 0 .. N_Blk - 1 loop
         declare
            Phys : constant Block_Number := Block_Map.Logical_To_Physical (V, Dir, LB);
            Pos  : Natural := 0;
         begin
            if Phys /= 0 then
               while Pos + 8 <= BS loop
                  ESP32S3.Ext4.Block_Cache.Read_At (V.Cache, Phys, Pos, Hdr);
                  declare
                     Ino    : constant U32 := Get_U32 (Hdr, 0);
                     Rec    : constant Natural := Natural (Get_U16 (Hdr, 4));
                     NLen   : constant Natural := Natural (Get_U8 (Hdr, 6));
                     Actual : constant Natural := (if Ino = 0 then 0 else 8 + R4 (NLen));
                  begin
                     exit when Rec < 8;
                     exit when Pos + Rec > BS;          --  entry must stay in-block
                     if Rec - Actual >= Needed then
                        if Ino /= 0 then
                           Put_U16 (Hdr, 4, U16 (Actual));      --  shrink current
                           ESP32S3.Ext4.Block_Cache.Write_At (V.Cache, Phys, Pos, Hdr);
                           Place (Phys, Pos + Actual, Rec - Actual);
                        else
                           Place (Phys, Pos, Rec);              --  reuse empty slot
                        end if;
                        return;
                     end if;
                     Pos := Pos + Rec;
                  end;
               end loop;
            end if;
         end;
      end loop;
      raise No_Space with "directory full (block extension not implemented)";
   end Add_Entry;

   ------------------
   -- Remove_Entry --
   ------------------

   function Remove_Entry
     (V : in out Volume.Context; Dir : Inode.Info; Name : String) return Inode_Number
   is
      BS    : constant Natural := V.SB.Block_Size;
      N_Blk : constant U64 := (Dir.Size + U64 (BS) - 1) / U64 (BS);
      Hdr   : Byte_Array (0 .. 7);
      PHdr  : Byte_Array (0 .. 7);
   begin
      for LB in 0 .. N_Blk - 1 loop
         declare
            Phys     : constant Block_Number := Block_Map.Logical_To_Physical (V, Dir, LB);
            Pos      : Natural := 0;
            Prev_Pos : Integer := -1;
         begin
            if Phys /= 0 then
               while Pos + 8 <= BS loop
                  ESP32S3.Ext4.Block_Cache.Read_At (V.Cache, Phys, Pos, Hdr);
                  declare
                     Ino  : constant U32 := Get_U32 (Hdr, 0);
                     Rec  : constant Natural := Natural (Get_U16 (Hdr, 4));
                     NLen : constant Natural := Natural (Get_U8 (Hdr, 6));
                     Nm   : Byte_Array (0 .. (if NLen = 0 then 0 else NLen - 1));
                  begin
                     exit when Rec < 8;
                     exit when Pos + Rec > BS;          --  entry must stay in-block
                     if Ino /= 0 and then NLen = Name'Length then
                        ESP32S3.Ext4.Block_Cache.Read_At (V.Cache, Phys, Pos + 8, Nm);
                        if To_String (Nm) = Name then
                           if Prev_Pos >= 0 then
                              --  merge into previous
                              ESP32S3.Ext4.Block_Cache.Read_At (V.Cache, Phys, Prev_Pos, PHdr);
                              Put_U16 (PHdr, 4, U16 (Natural (Get_U16 (PHdr, 4)) + Rec));
                              ESP32S3.Ext4.Block_Cache.Write_At (V.Cache, Phys, Prev_Pos, PHdr);
                           else
                              --  first: zero its inode
                              Put_U32 (Hdr, 0, 0);
                              ESP32S3.Ext4.Block_Cache.Write_At (V.Cache, Phys, Pos, Hdr);
                           end if;
                           return Inode_Number (Ino);
                        end if;
                     end if;
                     Prev_Pos := Pos;
                     Pos := Pos + Rec;
                  end;
               end loop;
            end if;
         end;
      end loop;
      return 0;
   end Remove_Entry;

   --------------
   -- Is_Empty --
   --------------

   function Is_Empty (V : in out Volume.Context; Dir : Inode.Info) return Boolean is
      Only_Dots : Boolean := True;

      function Check (Nm : String; Ino : Inode_Number; Ft : U8) return Boolean is
         pragma Unreferenced (Ino, Ft);
      begin
         if Nm /= "." and then Nm /= ".." then
            Only_Dots := False;
            return True;            --  stop early

         end if;
         return False;
      end Check;

      procedure Do_Walk is new Walk (Check);
   begin
      Do_Walk (V, Dir);
      return Only_Dots;
   end Is_Empty;

   ---------------------
   -- Set_Entry_Inode --
   ---------------------

   function Set_Entry_Inode
     (V : in out Volume.Context; Dir : Inode.Info; Name : String; New_Ino : Inode_Number)
      return Boolean
   is
      BS    : constant Natural := V.SB.Block_Size;
      N_Blk : constant U64 := (Dir.Size + U64 (BS) - 1) / U64 (BS);
      Hdr   : Byte_Array (0 .. 7);
   begin
      for LB in 0 .. N_Blk - 1 loop
         declare
            Phys : constant Block_Number := Block_Map.Logical_To_Physical (V, Dir, LB);
            Pos  : Natural := 0;
         begin
            if Phys /= 0 then
               while Pos + 8 <= BS loop
                  ESP32S3.Ext4.Block_Cache.Read_At (V.Cache, Phys, Pos, Hdr);
                  declare
                     Ino  : constant U32 := Get_U32 (Hdr, 0);
                     Rec  : constant Natural := Natural (Get_U16 (Hdr, 4));
                     NLen : constant Natural := Natural (Get_U8 (Hdr, 6));
                     Nm   : Byte_Array (0 .. (if NLen = 0 then 0 else NLen - 1));
                  begin
                     exit when Rec < 8;
                     exit when Pos + Rec > BS;          --  entry must stay in-block
                     if Ino /= 0 and then NLen = Name'Length then
                        ESP32S3.Ext4.Block_Cache.Read_At (V.Cache, Phys, Pos + 8, Nm);
                        if To_String (Nm) = Name then
                           Put_U32 (Hdr, 0, U32 (New_Ino));
                           ESP32S3.Ext4.Block_Cache.Write_At (V.Cache, Phys, Pos, Hdr);
                           return True;
                        end if;
                     end if;
                     Pos := Pos + Rec;
                  end;
               end loop;
            end if;
         end;
      end loop;
      return False;
   end Set_Entry_Inode;

end ESP32S3.Ext4.Dir;
