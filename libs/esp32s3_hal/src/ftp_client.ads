with System;
with Interfaces;
with GNAT.Sockets;

--  A small, portable FTP client (RFC 959), written entirely against GNAT.Sockets
--  -- so the same source compiles and runs on desktop GNAT.Sockets and on the
--  bare-metal W5500 facade alike (nothing here is chip-specific), like DNS_Client
--  and NTP_Client.
--
--  PASSIVE mode only.  An embedded client should only ever make OUTBOUND
--  connections, so every transfer asks the server to listen (PASV) and the client
--  connects to it -- no listening socket, NAT/firewall friendly.  A session uses
--  two sockets at a time: the persistent control connection plus one transient
--  data connection per transfer (well within the W5500's eight).
--
--  Transfers are BINARY (TYPE I) and STREAMED through a caller callback, so a file
--  never has to be held whole in RAM.  Like every callback in this HAL the sink /
--  source must be a library-level, closure-free subprogram (this build runs under
--  No_Implicit_Dynamic_Code); per-call state travels in the System.Address Ctx.
--
--  Requires the embedded or full profile (GNAT.Sockets uses controlled handles +
--  Ada.Real_Time).
package FTP_Client is

   type Byte_Array is array (Natural range <>) of Interfaces.Unsigned_8;

   --  A logged-in control connection.  Limited (it owns sockets); one object per
   --  server session.  Quit / a failed op leaves it closed.
   type Session is limited private;

   --  Outcome of an operation.  All but OK leave any data connection closed; the
   --  control session stays usable after Server_Error / Timed_Out (retry another
   --  command), but is closed after Connect_Failed / Auth_Failed / Protocol_Error.
   type Status is
     (OK,               --  completed (server gave the expected 2xx)
      Connect_Failed,   --  could not open / greet on the control connection
      Auth_Failed,      --  USER/PASS rejected (530)
      Timed_Out,        --  a reply did not arrive within Timeout
      Protocol_Error,   --  malformed reply, or an unexpected reply code
      Data_Failed,      --  the passive data connection could not be opened
      Server_Error,     --  server refused the operation (4xx/5xx, e.g. no file)
      Not_Connected);   --  operation attempted on a session that is not open

   --  Receives a file body (Retrieve) or a directory listing (List) in chunks, in
   --  order; called once per network read, never with an empty Chunk.  Library-
   --  level + closure-free; state via Ctx.
   type Data_Sink is access procedure (Ctx : System.Address; Chunk : Byte_Array);

   --  Supplies a file body (Store) in chunks: fill Buf and set Last to the number
   --  of bytes written (Buf'First .. Buf'First + Last - 1).  Last = 0 signals
   --  end-of-file.  Library-level + closure-free; state via Ctx.
   type Data_Source is access
     procedure (Ctx : System.Address; Buf : out Byte_Array; Last : out Natural);

   ----------------------------------------------------------------------------
   --  Session
   ----------------------------------------------------------------------------

   --  Open the control connection to Host:Port, read the greeting, log in with
   --  User/Password (PASS is skipped if the server accepts USER outright), and set
   --  binary type.  Timeout caps each reply wait (0.0 = block indefinitely) and is
   --  remembered for every later operation on S.
   procedure Connect (S        : in out Session;
                      Host     : GNAT.Sockets.Inet_Addr_Type;
                      User     : String;
                      Password : String;
                      Result   : out Status;
                      Port     : GNAT.Sockets.Port_Type := 21;
                      Timeout  : Duration               := 0.0);

   --  Send QUIT (best effort) and close the control connection.  Idempotent.
   procedure Quit (S : in out Session);

   --  True once Connect has succeeded and Quit has not run.
   function Is_Open (S : Session) return Boolean;

   ----------------------------------------------------------------------------
   --  Transfers (passive mode, binary)
   ----------------------------------------------------------------------------

   --  Download Path, streaming its bytes to Sink (Ctx) until end of file.
   procedure Retrieve (S      : in out Session;
                       Path   : String;
                       Sink   : Data_Sink;
                       Ctx    : System.Address;
                       Result : out Status);

   --  Upload to Path, pulling its bytes from Source (Ctx) until Source reports
   --  Last = 0.  Creates or overwrites the remote file.
   procedure Store (S      : in out Session;
                    Path   : String;
                    Source : Data_Source;
                    Ctx    : System.Address;
                    Result : out Status);

   --  List a directory (NLST: bare names, one per line, CRLF-separated), streamed
   --  to Sink (Ctx).  Path empty = the current directory.
   procedure List (S      : in out Session;
                   Sink   : Data_Sink;
                   Ctx    : System.Address;
                   Result : out Status;
                   Path   : String := "");

   ----------------------------------------------------------------------------
   --  Simple commands
   ----------------------------------------------------------------------------

   procedure Change_Dir  (S : in out Session; Path : String; Result : out Status);
   procedure Make_Dir    (S : in out Session; Path : String; Result : out Status);
   procedure Remove_Dir  (S : in out Session; Path : String; Result : out Status);
   procedure Delete_File (S : in out Session; Path : String; Result : out Status);

   --  Size of a remote file in bytes (SIZE; binary mode).  Size is 0 on any
   --  non-OK Result.
   procedure File_Size (S      : in out Session;
                        Path   : String;
                        Size   : out Natural;
                        Result : out Status);

private
   --  Control-connection input buffer, so Get_Line can hand back one CRLF-
   --  terminated reply line at a time regardless of how the TCP reads chunk.
   In_Buf_Last : constant := 511;

   type Session is limited record
      Control  : GNAT.Sockets.Socket_Type;
      Host     : GNAT.Sockets.Inet_Addr_Type;   --  control IP; reused for data
      Open     : Boolean  := False;
      Timeout  : Duration := 0.0;
      --  Pending bytes read from Control but not yet consumed as a line.
      Buf      : Byte_Array (0 .. In_Buf_Last);
      Head     : Natural  := 0;     --  next unread index
      Tail     : Natural  := 0;     --  one past the last valid index
   end record;
end FTP_Client;
