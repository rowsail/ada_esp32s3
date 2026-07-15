package body Chain_Buffers is

   Cap : constant := 4096;       --  max DER size per certificate

   --  These must have an UNCONSTRAINED nominal subtype (bounds fixed by the
   --  initializer) so 'Access statically matches Chain_Verify's
   --  access-constant-X509.Byte_Array; an array of constrained components would
   --  not.  X509.Parse reads the leading SEQUENCE and ignores the trailing
   --  zero slack, so a fixed-size buffer per cert is fine.  Library-level so the
   --  access values outlive any local scope.  Max chain length = 4.
   Buf1, Buf2, Buf3, Buf4 : aliased X509.Byte_Array := (0 .. Cap - 1 => 0);
   Count                  : Natural := 0;

   procedure Reset is
   begin
      Count := 0;
   end Reset;

   procedure Store (Slot : Positive; Data : X509.Byte_Array) is
   begin
      for I in 0 .. Data'Length - 1 loop
         case Slot is
            when 1      =>
               Buf1 (I) := Data (Data'First + I);

            when 2      =>
               Buf2 (I) := Data (Data'First + I);

            when 3      =>
               Buf3 (I) := Data (Data'First + I);

            when others =>
               Buf4 (I) := Data (Data'First + I);
         end case;
      end loop;
   end Store;

   procedure Add (Data : X509.Byte_Array) is
   begin
      if Count < 4 and then Data'Length <= Cap then
         Count := Count + 1;
         Store (Count, Data);
      end if;
   end Add;

   function Ref (Slot : Positive) return Chain_Verify.Cert_Ref is
   begin
      case Slot is
         when 1      =>
            return (Data => Buf1'Access);

         when 2      =>
            return (Data => Buf2'Access);

         when 3      =>
            return (Data => Buf3'Access);

         when others =>
            return (Data => Buf4'Access);
      end case;
   end Ref;

   function Chain return Chain_Verify.Cert_List is
      R : Chain_Verify.Cert_List (1 .. Count);
   begin
      for I in 1 .. Count loop
         R (I) := Ref (I);
      end loop;
      return R;
   end Chain;

end Chain_Buffers;
