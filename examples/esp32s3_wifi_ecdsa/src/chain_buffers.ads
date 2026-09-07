--  Library-level holding buffers for the certificates the server sends during
--  the handshake, so they can be referenced by access for Chain_Verify (whose
--  Cert_Ref.Data is a non-local access-to-constant -- it cannot point at a local
--  object).  Fill them from TLS_Client.Server_Chain_Cert, then build the chain.
with X509;
with Chain_Verify;

package Chain_Buffers is

   --  Copy the certs (leaf first) in, then ask for the chain to validate.
   procedure Reset;
   procedure Add (Data : X509.Byte_Array);
   function Chain return Chain_Verify.Cert_List;

end Chain_Buffers;
