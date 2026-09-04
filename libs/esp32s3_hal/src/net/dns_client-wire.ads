with Interfaces;
with DNS_Client.Parse;

--  The outbound dual of DNS_Client.Parse: building the standard recursive
--  A-record query, factored out of the UDP client so every transport --
--  UDP, TCP (RFC 7766), DNS-over-TLS, DNS-over-HTTPS -- assembles the same
--  proven bytes.  The wire format is identical across all of them; only the
--  carriage differs (TCP-family transports add a two-byte length prefix,
--  which stays with the transport, not here).
--
--  Unlike the inline builder this replaces, the name is VALIDATED: RFC 1035
--  bounds (a label is 1..63 bytes, the whole name at most 253, no empty
--  label from a leading/trailing/double dot) are checked and refused, where
--  the old code would silently emit a malformed query.
package DNS_Client.Wire with SPARK_Mode => On is

   use type Interfaces.Unsigned_16;

   --  An A query for a maximal name fits well inside this; one buffer size
   --  for every caller.
   Max_Query_Bytes : constant := 512;
   subtype Query_Buffer is Parse.Byte_Array (0 .. Max_Query_Bytes - 1);

   --  Longest legal presentation-form name (RFC 1035 section 2.3.4).
   Max_Name_Length : constant := 253;

   --  Build a standard recursive IN A query for Name, stamped with Id (the
   --  transaction id the reply must echo; see Parse.Find_A_Record).  Ok is
   --  False -- and Length 0 -- when Name violates the RFC bounds.
   procedure Build_A_Query
     (Name   : String;
      Id     : Interfaces.Unsigned_16;
      Buffer : out Query_Buffer;
      Length : out Natural;
      Ok     : out Boolean)
   with
     Pre  => Name'Length >= 1
             and then Name'Length <= Max_Name_Length
             and then Name'Last < Natural'Last,
     Post => (if Ok then Length in 1 .. Max_Query_Bytes else Length = 0);

end DNS_Client.Wire;
