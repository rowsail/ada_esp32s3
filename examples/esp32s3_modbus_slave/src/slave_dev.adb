package body Slave_Dev is

   procedure Seed (Self : in out Device) is
   begin
      for R in Self.Holding'Range loop
         Self.Holding (R) := Word (1000 + R);
      end loop;
      for C in Self.Coils'Range loop
         Self.Coils (C) := (C mod 2 = 0);
      end loop;
   end Seed;

   overriding procedure On_Read_Holding_Registers
     (Self : in out Device; Unit : Unit_Id; Addr : Address; Qty : Positive;
      Into : out Word_Array; Status : out Exception_Code) is
   begin
      if Natural (Addr) + Qty - 1 > Self.Holding'Last then
         Into := (Into'Range => 0);  Status := Illegal_Data_Address;  return;
      end if;
      for I in 0 .. Qty - 1 loop
         Into (Into'First + I) := Self.Holding (Natural (Addr) + I);
      end loop;
      Status := None;
   end On_Read_Holding_Registers;

   overriding procedure On_Write_Single_Register
     (Self : in out Device; Unit : Unit_Id; Addr : Address; Value : Word;
      Status : out Exception_Code) is
   begin
      if Natural (Addr) > Self.Holding'Last then
         Status := Illegal_Data_Address;  return;
      end if;
      Self.Holding (Natural (Addr)) := Value;  Status := None;
   end On_Write_Single_Register;

   overriding procedure On_Write_Multiple_Registers
     (Self : in out Device; Unit : Unit_Id; Addr : Address; Values : Word_Array;
      Status : out Exception_Code) is
   begin
      if Natural (Addr) + Values'Length - 1 > Self.Holding'Last then
         Status := Illegal_Data_Address;  return;
      end if;
      for I in 0 .. Values'Length - 1 loop
         Self.Holding (Natural (Addr) + I) := Values (Values'First + I);
      end loop;
      Status := None;
   end On_Write_Multiple_Registers;

   overriding procedure On_Read_Coils
     (Self : in out Device; Unit : Unit_Id; Addr : Address; Qty : Positive;
      Into : out Bit_Array; Status : out Exception_Code) is
   begin
      if Natural (Addr) + Qty - 1 > Self.Coils'Last then
         Into := (Into'Range => False);  Status := Illegal_Data_Address;  return;
      end if;
      for I in 0 .. Qty - 1 loop
         Into (Into'First + I) := Self.Coils (Natural (Addr) + I);
      end loop;
      Status := None;
   end On_Read_Coils;

   overriding procedure On_Write_Single_Coil
     (Self : in out Device; Unit : Unit_Id; Addr : Address; Value : Boolean;
      Status : out Exception_Code) is
   begin
      if Natural (Addr) > Self.Coils'Last then
         Status := Illegal_Data_Address;  return;
      end if;
      Self.Coils (Natural (Addr)) := Value;  Status := None;
   end On_Write_Single_Coil;

end Slave_Dev;
