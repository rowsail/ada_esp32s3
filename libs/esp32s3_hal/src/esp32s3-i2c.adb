with ESP32S3.I2C.Engine;

package body ESP32S3.I2C is

   package E renames ESP32S3.I2C.Engine;

   --  One protected guard per host -- arbitrates exclusive ownership.  The
   --  guarded section is tiny (flip a flag); the actual transaction runs
   --  outside.
   protected type Host_Guard is
      entry Acquire;
      procedure Release;
   private
      Held : Boolean := False;
   end Host_Guard;

   protected body Host_Guard is
      entry Acquire when not Held is
      begin
         Held := True;
      end Acquire;

      procedure Release is
      begin
         Held := False;
      end Release;
   end Host_Guard;

   Guards : array (I2C_Host) of Host_Guard;

   ----------------------------------------------------------------------------
   --  State -- the single, ownership-checked gateway to the raw register bus.
   --
   --  The per-host Bus array lives in this package's BODY, so nothing else in
   --  ESP32S3.I2C can name it.  Owned (S) is the ONLY export that returns a Bus,
   --  and it raises Not_Owned unless S currently holds the host -- so a
   --  transaction physically cannot reach the registers without proving
   --  ownership, and a new op cannot be written that skips the check.  The
   --  startup config entries are host-keyed (single-threaded, pre-Acquire) and
   --  never hand a Bus back out.
   ----------------------------------------------------------------------------

   package State is
      procedure Open (Host : I2C_Host; Clock_Hz : Positive);
      procedure Configure_Pins
        (Host : I2C_Host; Scl : ESP32S3.GPIO.Pin_Id; Sda : ESP32S3.GPIO.Pin_Id);
      function Ready (Host : I2C_Host) return Boolean;
      function Owned (S : Session) return E.Bus;
   end State;

   package body State is
      Buses     : array (I2C_Host) of E.Bus;   --  raw bus per host, hidden here
      Ready_Map : array (I2C_Host) of Boolean := (others => False);

      procedure Open (Host : I2C_Host; Clock_Hz : Positive) is
      begin
         Buses (Host) := E.Open (Host, Clock_Hz);
         Ready_Map (Host) := True;
      end Open;

      procedure Configure_Pins
        (Host : I2C_Host; Scl : ESP32S3.GPIO.Pin_Id; Sda : ESP32S3.GPIO.Pin_Id) is
      begin
         E.Configure_Pins (Buses (Host), Scl, Sda);
      end Configure_Pins;

      function Ready (Host : I2C_Host) return Boolean
      is (Ready_Map (Host));

      function Owned (S : Session) return E.Bus is
      begin
         if not S.Active then
            raise Not_Owned with "I2C host used without holding it -- Acquire first";
         end if;
         return Buses (S.Host);
      end Owned;
   end State;

   -----------
   -- Setup --
   -----------

   procedure Setup (Host : I2C_Host; Clock_Hz : Positive := 100_000) is
   begin
      State.Open (Host, Clock_Hz);
   end Setup;

   procedure Configure_Pins (Host : I2C_Host; Scl : ESP32S3.GPIO.Pin_Id; Sda : ESP32S3.GPIO.Pin_Id)
   is
   begin
      State.Configure_Pins (Host, Scl, Sda);
   end Configure_Pins;

   -------------
   -- Acquire --
   -------------

   procedure Acquire (S : in out Session; Host : I2C_Host) is
   begin
      if S.Active then
         --  Re-acquiring a live Session would block on its own guard forever, or
         --  (for a different host) orphan the first host's guard for the run.
         raise Program_Error with "I2C Session already active; Release first";
      end if;
      if not State.Ready (Host) then
         raise Not_Initialized with "I2C host acquired before Setup";
      end if;
      Guards (Host).Acquire;          --  suspends here until the host is free
      S.Host := Host;
      S.Active := True;
   end Acquire;

   -----------
   -- Write --
   -----------

   procedure Write
     (S         : Session;
      Addr      : Slave_Address;
      Data      : Byte_Array;
      Success   : out Boolean;
      Check_Ack : Boolean := True) is
   begin
      --  Owned raises unless we hold the host; runs OUTSIDE the guard.
      E.Write (State.Owned (S), Addr, Data, Success, Check_Ack);
   end Write;

   ----------
   -- Read --
   ----------

   procedure Read (S : Session; Addr : Slave_Address; Data : out Byte_Array; Success : out Boolean)
   is
   begin
      E.Read (State.Owned (S), Addr, Data, Success);
   end Read;

   ----------------
   -- Write_Read --
   ----------------

   procedure Write_Read
     (S       : Session;
      Addr    : Slave_Address;
      Tx      : Byte_Array;
      Rx      : out Byte_Array;
      Success : out Boolean) is
   begin
      E.Write_Read (State.Owned (S), Addr, Tx, Rx, Success);
   end Write_Read;

   -------------
   -- Release --
   -------------

   procedure Release (S : in out Session) is
   begin
      if S.Active then
         S.Active := False;
         Guards (S.Host).Release;
      end if;
   end Release;

   --  Scope-exit / exception-unwind cleanup: hand the host back if still held.
   overriding
   procedure Finalize (S : in out Session) is
   begin
      Release (S);
   end Finalize;

end ESP32S3.I2C;
