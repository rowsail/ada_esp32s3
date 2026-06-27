--  Native host test for Modbus.Slave: a Test_Server with its own storage overrides
--  some handlers; we feed crafted request ADUs to the socket-free Process and check
--  the reply ADUs and side effects -- so framing, dispatch, the exception path, and
--  the Illegal_Function default are all verified deterministically, no sockets.
with Ada.Text_IO; use Ada.Text_IO;
with Interfaces;
with Modbus;       use Modbus;
with Modbus.Slave;

procedure Modbus_Slave_Host is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   package MS renames Modbus.Slave;

   --  A device that supports holding registers + coils (with bounds checks); it
   --  does NOT override input registers / discrete inputs (-> Illegal_Function).
   package Test_Devices is
      type Test_Server is new MS.Server with record
         Holding : Word_Array (0 .. 99) := (others => 0);
         Coils   : Bit_Array  (0 .. 99) := (others => False);
      end record;
      overriding procedure On_Read_Holding_Registers
        (Self : in out Test_Server; Unit : Unit_Id; Addr : Address; Qty : Positive;
         Into : out Word_Array; Status : out Exception_Code);
      overriding procedure On_Write_Single_Register
        (Self : in out Test_Server; Unit : Unit_Id; Addr : Address; Value : Word;
         Status : out Exception_Code);
      overriding procedure On_Write_Multiple_Registers
        (Self : in out Test_Server; Unit : Unit_Id; Addr : Address;
         Values : Word_Array; Status : out Exception_Code);
      overriding procedure On_Read_Coils
        (Self : in out Test_Server; Unit : Unit_Id; Addr : Address; Qty : Positive;
         Into : out Bit_Array; Status : out Exception_Code);
   end Test_Devices;

   package body Test_Devices is
      overriding procedure On_Read_Holding_Registers
        (Self : in out Test_Server; Unit : Unit_Id; Addr : Address; Qty : Positive;
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
        (Self : in out Test_Server; Unit : Unit_Id; Addr : Address; Value : Word;
         Status : out Exception_Code) is
      begin
         if Natural (Addr) > Self.Holding'Last then
            Status := Illegal_Data_Address;  return;
         end if;
         Self.Holding (Natural (Addr)) := Value;  Status := None;
      end On_Write_Single_Register;

      overriding procedure On_Write_Multiple_Registers
        (Self : in out Test_Server; Unit : Unit_Id; Addr : Address;
         Values : Word_Array; Status : out Exception_Code) is
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
        (Self : in out Test_Server; Unit : Unit_Id; Addr : Address; Qty : Positive;
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
   end Test_Devices;

   use Test_Devices;
   Dev : Test_Server;

   Passed, Failed : Natural := 0;
   procedure Check (Label : String; Cond : Boolean) is
   begin
      if Cond then Passed := Passed + 1; Put_Line ("  ok   " & Label);
      else Failed := Failed + 1; Put_Line ("  FAIL " & Label); end if;
   end Check;

   Buf  : Byte_Array (0 .. Max_ADU - 1) := (others => 0);
   RLen : Natural;

   function Req (PDU_Len : Natural) return Natural is
   begin
      Put_MBAP (Buf, TID => 7, Unit => 1, PDU_Len => PDU_Len);
      return MBAP_Size + PDU_Len;
   end Req;
begin
   --  Read holding 0..2 (seeded)
   Dev.Holding (0 .. 2) := (16#0010#, 16#0020#, 16#0030#);
   Buf (7) := Byte (FC_Read_Holding_Registers);
   Put_U16 (Buf, 8, 0);  Put_U16 (Buf, 10, 3);
   MS.Process (Dev, Buf, Req (5), RLen);
   Check ("read holding: TID echoed", Get_U16 (Buf, 0) = 7);
   Check ("read holding: FC=03",      Buf (7) = 16#03#);
   Check ("read holding: byte count=6", Buf (8) = 6);
   Check ("read holding: data 0x0010 0x0020 0x0030",
          Get_U16 (Buf, 9) = 16#0010# and then Get_U16 (Buf, 11) = 16#0020#
          and then Get_U16 (Buf, 13) = 16#0030#);
   Check ("read holding: reply len", RLen = MBAP_Size + 2 + 6);

   --  Write single register 5 = 0xABCD
   Buf (7) := Byte (FC_Write_Single_Register);
   Put_U16 (Buf, 8, 5);  Put_U16 (Buf, 10, 16#ABCD#);
   MS.Process (Dev, Buf, Req (5), RLen);
   Check ("write single: storage updated", Dev.Holding (5) = 16#ABCD#);
   Check ("write single: echoes addr+value",
          Buf (7) = 16#06# and then Get_U16 (Buf, 8) = 5
          and then Get_U16 (Buf, 10) = 16#ABCD#);

   --  Write multiple registers 10..12 = [1,2,3]
   Buf (7) := Byte (FC_Write_Multiple_Registers);
   Put_U16 (Buf, 8, 10);  Put_U16 (Buf, 10, 3);  Buf (12) := 6;
   Put_U16 (Buf, 13, 1);  Put_U16 (Buf, 15, 2);  Put_U16 (Buf, 17, 3);
   MS.Process (Dev, Buf, Req (7 + 6), RLen);
   Check ("write multi: storage [1,2,3]",
          Dev.Holding (10) = 1 and then Dev.Holding (11) = 2
          and then Dev.Holding (12) = 3);
   Check ("write multi: echoes qty=3",
          Buf (7) = 16#10# and then Get_U16 (Buf, 10) = 3);

   --  Read coils 0..7 (pattern -> LSB-first byte)
   Dev.Coils (0 .. 7) := (True, False, True, False, False, False, False, True);
   Buf (7) := Byte (FC_Read_Coils);
   Put_U16 (Buf, 8, 0);  Put_U16 (Buf, 10, 8);
   MS.Process (Dev, Buf, Req (5), RLen);
   Check ("read coils: byte count=1", Buf (8) = 1);
   Check ("read coils: packed 0x85", Buf (9) = 16#85#);   --  1000_0101

   --  Unsupported FC (input registers not overridden) -> Illegal_Function
   Buf (7) := Byte (FC_Read_Input_Registers);
   Put_U16 (Buf, 8, 0);  Put_U16 (Buf, 10, 1);
   MS.Process (Dev, Buf, Req (5), RLen);
   Check ("unsupported: FC|0x80", Buf (7) = (16#04# or 16#80#));
   Check ("unsupported: code=Illegal_Function(1)", Buf (8) = 1);

   --  Out-of-range read -> Illegal_Data_Address from the handler
   Buf (7) := Byte (FC_Read_Holding_Registers);
   Put_U16 (Buf, 8, 200);  Put_U16 (Buf, 10, 1);
   MS.Process (Dev, Buf, Req (5), RLen);
   Check ("bad addr: FC|0x80", Buf (7) = (16#03# or 16#80#));
   Check ("bad addr: code=Illegal_Data_Address(2)", Buf (8) = 2);

   New_Line;
   Put_Line ("Modbus slave:" & Natural'Image (Passed) & " passed,"
             & Natural'Image (Failed) & " failed");
   if Failed > 0 then
      raise Program_Error with "modbus slave test failed";
   end if;
end Modbus_Slave_Host;
