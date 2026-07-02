with Interfaces; use Interfaces;

package body Modbus is

   function To_Byte (E : Exception_Code) return Byte is
   begin
      case E is
         when None                             =>
            return 0;

         when Illegal_Function                 =>
            return 1;

         when Illegal_Data_Address             =>
            return 2;

         when Illegal_Data_Value               =>
            return 3;

         when Slave_Device_Failure             =>
            return 4;

         when Acknowledge                      =>
            return 5;

         when Slave_Device_Busy                =>
            return 6;

         when Memory_Parity_Error              =>
            return 8;

         when Gateway_Path_Unavailable         =>
            return 10;

         when Gateway_Target_Failed_To_Respond =>
            return 11;
      end case;
   end To_Byte;

   function To_Exception (B : Byte) return Exception_Code is
   begin
      case B is
         when 0      =>
            return None;

         when 1      =>
            return Illegal_Function;

         when 2      =>
            return Illegal_Data_Address;

         when 3      =>
            return Illegal_Data_Value;

         when 4      =>
            return Slave_Device_Failure;

         when 5      =>
            return Acknowledge;

         when 6      =>
            return Slave_Device_Busy;

         when 8      =>
            return Memory_Parity_Error;

         when 10     =>
            return Gateway_Path_Unavailable;

         when 11     =>
            return Gateway_Target_Failed_To_Respond;

         when others =>
            return Slave_Device_Failure;     --  reserved/unknown
      end case;
   end To_Exception;

   function Get_U16 (B : Byte_Array; Pos : Natural) return Word
   is (Shift_Left (Word (B (Pos)), 8) or Word (B (Pos + 1)));

   procedure Put_U16 (B : in out Byte_Array; Pos : Natural; V : Word) is
   begin
      B (Pos) := Byte (Shift_Right (V, 8));
      B (Pos + 1) := Byte (V and 16#FF#);
   end Put_U16;

   procedure Put_MBAP (B : in out Byte_Array; TID : Word; Unit : Unit_Id; PDU_Len : Natural) is
   begin
      Put_U16 (B, B'First, TID);                     --  transaction id
      Put_U16 (B, B'First + 2, 0);                       --  protocol id = 0
      Put_U16 (B, B'First + 4, Word (PDU_Len + 1));      --  length = unit + PDU
      B (B'First + 6) := Byte (Unit);
   end Put_MBAP;

   procedure Get_MBAP (B : Byte_Array; TID : out Word; Unit : out Unit_Id; Length : out Natural) is
   begin
      TID := Get_U16 (B, B'First);
      Length := Natural (Get_U16 (B, B'First + 4));
      Unit := Unit_Id (B (B'First + 6));
   end Get_MBAP;

end Modbus;
