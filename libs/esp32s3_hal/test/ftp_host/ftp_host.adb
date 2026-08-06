--  Drives FTP_Client against the local Python FTP server (ftp_server.py), whose
--  control port is passed as argv(1).  Exercises login, SIZE, RETR, STOR, a RETR
--  round-trip, NLST, DELE and Quit; exits non-zero if any check fails.  The sink/
--  source callbacks live in FTP_Test_Support (library level, as the API requires).
with Ada.Command_Line;    use Ada.Command_Line;
with Ada.Text_IO;         use Ada.Text_IO;
with Ada.Strings.Fixed;   use Ada.Strings.Fixed;
with GNAT.Sockets;
with System;
with FTP_Client;
with FTP_Test_Support;    use FTP_Test_Support;

procedure FTP_Host is
   use type FTP_Client.Status;

   Fail_Count : Natural := 0;

   procedure Check (Label : String; Cond : Boolean) is
   begin
      Put_Line ((if Cond then "  PASS  " else "  FAIL  ") & Label);
      if not Cond then Fail_Count := Fail_Count + 1; end if;
   end Check;

   S    : FTP_Client.Session;
   St   : FTP_Client.Status;
   Sz   : Natural;
   Port : GNAT.Sockets.Port_Type;
begin
   if Argument_Count < 1 then
      Put_Line ("usage: ftp_host <control-port>");
      Set_Exit_Status (2);
      return;
   end if;
   Port := GNAT.Sockets.Port_Type'Value (Argument (1));

   FTP_Client.Connect
     (S, Host => GNAT.Sockets.Inet_Addr ("127.0.0.1"),
      User => "demo", Password => "password", Result => St,
      Port => Port, Timeout => 5.0);
   Check ("Connect / login", St = FTP_Client.OK);

   FTP_Client.File_Size (S, "hello.txt", Sz, St);
   Check ("SIZE hello.txt = 30", St = FTP_Client.OK and then Sz = 30);

   declare
      Stamp : String (1 .. 24);
      SLen  : Natural;
   begin
      FTP_Client.Mod_Time (S, "hello.txt", Stamp, SLen, St);
      Check ("MDTM hello.txt = 14-digit stamp",
             St = FTP_Client.OK and then SLen = 14
             and then (for all C of Stamp (1 .. SLen) => C in '0' .. '9'));
      FTP_Client.Mod_Time (S, "no-such-file.txt", Stamp, SLen, St);
      Check ("MDTM missing file -> Server_Error",
             St = FTP_Client.Server_Error and then SLen = 0);
   end;

   Reset_Acc;
   FTP_Client.Retrieve (S, "hello.txt", Append_Sink'Access, System.Null_Address, St);
   Check ("RETR hello.txt content",
          St = FTP_Client.OK
          and then Acc_String = "hello from the ftp host test" & ASCII.CR & ASCII.LF);

   Reset_Upload;
   FTP_Client.Store (S, "uploaded.txt", Upload_Source'Access, System.Null_Address, St);
   Check ("STOR uploaded.txt", St = FTP_Client.OK);

   Reset_Acc;
   FTP_Client.Retrieve (S, "uploaded.txt", Append_Sink'Access, System.Null_Address, St);
   Check ("RETR uploaded.txt round-trip",
          St = FTP_Client.OK and then Acc_String = Upload_Text);

   Reset_Acc;
   FTP_Client.List (S, Append_Sink'Access, System.Null_Address, St);
   Check ("NLST lists uploaded.txt",
          St = FTP_Client.OK and then Index (Acc_String, "uploaded.txt") > 0);

   FTP_Client.Delete_File (S, "uploaded.txt", St);
   Check ("DELE uploaded.txt", St = FTP_Client.OK);

   --  Robustness: a server refusal (5xx) must NOT tear the session down -- the
   --  control link is intact, so the session stays usable for the next command.
   Reset_Acc;
   FTP_Client.Retrieve (S, "does-not-exist.txt",
                        Append_Sink'Access, System.Null_Address, St);
   Check ("RETR missing -> Server_Error", St = FTP_Client.Server_Error);
   Check ("session survives Server_Error", FTP_Client.Is_Open (S));
   FTP_Client.File_Size (S, "hello.txt", Sz, St);
   Check ("command still works after Server_Error",
          St = FTP_Client.OK and then Sz = 30);

   --  And after Quit, the session is closed and further ops report Not_Connected.
   FTP_Client.Quit (S);
   Check ("Quit closes session", not FTP_Client.Is_Open (S));
   FTP_Client.File_Size (S, "hello.txt", Sz, St);
   Check ("op on closed session -> Not_Connected", St = FTP_Client.Not_Connected);

   New_Line;
   if Fail_Count = 0 then
      Put_Line ("ftp_host: ALL PASS");
      Set_Exit_Status (0);
   else
      Put_Line ("ftp_host:" & Fail_Count'Image & " FAILED");
      Set_Exit_Status (1);
   end if;
end FTP_Host;
