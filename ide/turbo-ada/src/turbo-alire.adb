with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with GNAT.OS_Lib;
with Turbo.Projects;
with Turbo.Term;

package body Turbo.Alire is

   use Ada.Directories;
   use type GNAT.OS_Lib.String_Access;

   function Env (Name : String) return String is
     (if Ada.Environment_Variables.Exists (Name)
      then Ada.Environment_Variables.Value (Name) else "");

   function Home return String is
     (if Env ("HOME") /= "" then Env ("HOME") else Env ("USERPROFILE"));

   function Exe return String is
     (if Term.Is_Windows then "alr.exe" else "alr");

   function Home_Dir return String is
   begin
      if Env ("TURBO_ADA_ALIRE") /= "" then
         return Env ("TURBO_ADA_ALIRE");
      elsif Env ("XDG_DATA_HOME") /= "" then
         return Env ("XDG_DATA_HOME") & "/turbo-ada/alire";
      end if;
      return Home & "/.local/share/turbo-ada/alire";
   end Home_Dir;

   function On_Path return String is
      P : GNAT.OS_Lib.String_Access := GNAT.OS_Lib.Locate_Exec_On_Path ("alr");
   begin
      if P = null then
         return "";
      end if;
      declare
         R : constant String := P.all;
      begin
         GNAT.OS_Lib.Free (P);
         return R;
      end;
   end On_Path;

   function Is_File (Path : String) return Boolean is
     (Exists (Path) and then Kind (Path) = Ordinary_File);

   function Find return String is
      Fetched   : constant String := Home_Dir & "/bin/" & Exe;
      Installed : constant String := Home & "/.alire/bin/" & Exe;
   begin
      if Is_File (Fetched) then
         return Fetched;
      elsif On_Path /= "" then
         return On_Path;
      elsif Is_File (Installed) then
         return Installed;
      end if;
      return "";
   end Find;

   function Normalize (Path : String) return String is
     (if Path = "" then "" else GNAT.OS_Lib.Normalize_Pathname (Path));

   function Use_Found return Boolean is
      Alr : constant String := Find;
   begin
      if Alr = "" then
         return False;
      end if;
      if Normalize (On_Path) /= Normalize (Alr) then
         Ada.Environment_Variables.Set
           ("PATH", Containing_Directory (Alr) & GNAT.OS_Lib.Path_Separator & Env ("PATH"));
      end if;
      return True;
   end Use_Found;

   procedure Use_Found is
   begin
      if Use_Found then
         null;
      end if;
   end Use_Found;

   function Quote (Arg : String) return String is
      R : String (1 .. 4 * Arg'Length + 2);
      N : Natural := 1;
   begin
      if Arg /= ""
        and then (for all C of Arg =>
                    C in 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9'
                       | '_' | '.' | '=' | '-' | '/' | '~' | '^' | ':')
      then
         return Arg;
      end if;
      R (1) := ''';
      for C of Arg loop
         if C = ''' then
            R (N + 1 .. N + 4) := "'\''";
            N := N + 4;
         else
            N := N + 1;
            R (N) := C;
         end if;
      end loop;
      N := N + 1;
      R (N) := ''';
      return R (1 .. N);
   end Quote;

   function Fetch_Command return String is
      LF  : constant Character := Character'Val (10);
      D   : constant String := Quote (Home_Dir);
      V   : constant String := Fallback_Version;
   begin
      if Projects.Shell_Program = "cmd.exe" then
         return "";
      end if;
      return
        "set -e" & LF
        & "d=" & D & LF
        & "case ""$(uname -s)"" in" & LF
        & "  Linux) os=linux ;; Darwin) os=macos ;;" & LF
        & "  MINGW*|MSYS*|CYGWIN*) os=windows ;;" & LF
        & "  *) echo ""error: Alire has no build for $(uname -s)""; exit 1 ;;" & LF
        & "esac" & LF
        & "case ""$(uname -m)"" in" & LF
        & "  x86_64|amd64) cpu=x86_64 ;; aarch64|arm64) cpu=aarch64 ;;" & LF
        & "  *) echo ""error: Alire has no build for $(uname -m)""; exit 1 ;;" & LF
        & "esac" & LF
        & "get () {" & LF
        & "  if command -v curl >/dev/null 2>&1; then curl -fsSL ""$1""" & LF
        & "  elif command -v wget >/dev/null 2>&1; then wget -qO- ""$1""" & LF
        & "  else echo ""error: downloading needs curl or wget"" >&2; return 1; fi" & LF
        & "}" & LF
        & "echo ""Asking GitHub for the latest Alire release ($cpu-$os)""" & LF
        & "url=$(get https://api.github.com/repos/alire-project/alire/releases/latest"
        & " 2>/dev/null | grep -o 'https://[^""]*-bin-'""$cpu-$os""'\.zip' | head -n 1)"
        & " || true" & LF
        & "[ -n ""$url"" ] || url=https://github.com/alire-project/alire/releases/download/"
        & "v" & V & "/alr-" & V & "-bin-$cpu-$os.zip" & LF
        & "echo ""Downloading $url""" & LF
        & "mkdir -p ""$d""" & LF
        & "get ""$url"" > ""$d/alr.zip""" & LF
        & "if command -v unzip >/dev/null 2>&1; then unzip -o -q ""$d/alr.zip"" -d ""$d""" & LF
        & "else python3 -m zipfile -e ""$d/alr.zip"" ""$d""; fi" & LF
        & "rm -f ""$d/alr.zip""" & LF
        & "chmod +x ""$d""/bin/alr*" & LF
        & """$d/bin/alr"" --version" & LF
        & "echo ""Installed in $d/bin""";
   end Fetch_Command;

   function Needs_Alr (Command : String) return Boolean is
      C : constant String := Ada.Strings.Fixed.Trim (Command, Ada.Strings.Left);
   begin
      return C = "alr" or else (C'Length > 4 and then C (C'First .. C'First + 3) = "alr ");
   end Needs_Alr;

   function Valid_Crate (Spec : String) return Boolean is
      Name_End : Natural := Spec'First - 1;
   begin
      for K in Spec'Range loop
         exit when Spec (K) not in 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_';
         Name_End := K;
      end loop;
      return Name_End >= Spec'First
        and then Spec (Spec'First) in 'a' .. 'z' | 'A' .. 'Z'
        and then (Name_End = Spec'Last
                  or else (Spec (Name_End + 1) in '=' | '^' | '~' | '<' | '>'
                           and then (for all C of Spec (Name_End + 1 .. Spec'Last) =>
                                       C in '0' .. '9' | 'a' .. 'z' | 'A' .. 'Z'
                                          | '.' | '=' | '^' | '~' | '<' | '>'
                                          | '&' | '|' | ' ' | '*' | '-' | '+' | '_')));
   end Valid_Crate;

end Turbo.Alire;
