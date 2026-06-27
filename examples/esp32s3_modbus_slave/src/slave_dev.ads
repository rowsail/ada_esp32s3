with Modbus;       use Modbus;
with Modbus.Slave;

--  A concrete Modbus slave device: it owns its register/coil storage and overrides
--  the handlers it supports.  This is the application's data -- the Modbus.Slave
--  library stores nothing.  Holding registers and coils are read/write; the rest
--  default to Illegal_Function.
package Slave_Dev is

   type Device is new Modbus.Slave.Server with record
      Holding : Word_Array (0 .. 63) := (others => 0);
      Coils   : Bit_Array  (0 .. 63) := (others => False);
   end record;

   overriding procedure On_Read_Holding_Registers
     (Self : in out Device; Unit : Unit_Id; Addr : Address; Qty : Positive;
      Into : out Word_Array; Status : out Exception_Code);
   overriding procedure On_Write_Single_Register
     (Self : in out Device; Unit : Unit_Id; Addr : Address; Value : Word;
      Status : out Exception_Code);
   overriding procedure On_Write_Multiple_Registers
     (Self : in out Device; Unit : Unit_Id; Addr : Address; Values : Word_Array;
      Status : out Exception_Code);
   overriding procedure On_Read_Coils
     (Self : in out Device; Unit : Unit_Id; Addr : Address; Qty : Positive;
      Into : out Bit_Array; Status : out Exception_Code);
   overriding procedure On_Write_Single_Coil
     (Self : in out Device; Unit : Unit_Id; Addr : Address; Value : Boolean;
      Status : out Exception_Code);

   --  Seed some recognisable values so a first poll shows something.
   procedure Seed (Self : in out Device);

end Slave_Dev;
