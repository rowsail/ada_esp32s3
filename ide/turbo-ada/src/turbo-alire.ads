--  Alire itself: finding alr, and fetching it when there is none.
--
--  Every alr command Turbo Ada runs is a plain "alr ..." through the shell,
--  so the alr it uses is the first on PATH.  When there is none, the IDE
--  offers to download the latest release for this machine from GitHub into
--  Home_Dir/bin (Fetch_Command), and Use_Found puts that directory at the
--  front of PATH, for the IDE and everything it starts.  That alr then
--  fetches everything else itself: crates, dependencies, the GNAT
--  toolchain, ada_language_server.

package Turbo.Alire is

   function Home_Dir return String;
   --  Where a fetched alr lives: $TURBO_ADA_ALIRE, else
   --  $XDG_DATA_HOME/turbo-ada/alire, else ~/.local/share/turbo-ada/alire.

   function Find return String;
   --  The alr to use: a fetched one (Home_Dir/bin/alr), else the one on
   --  PATH, else ~/.alire/bin/alr; "" when there is none.

   function Use_Found return Boolean;
   --  Find, and when the alr found is not the one PATH gives, put its
   --  directory first on PATH.  False when there is no alr at all.

   procedure Use_Found;
   --  The same, at start-up, when there may well be none.

   function Fetch_Command return String;
   --  A shell command that downloads the newest alr for this OS and CPU
   --  (curl or wget), unpacks it into Home_Dir (unzip or python3) and prints
   --  its version.  "" where there is no POSIX shell to run it.

   Fallback_Version : constant String := "2.1.1";
   --  The release to fetch when GitHub's "latest" cannot be asked.

   function Needs_Alr (Command : String) return Boolean;
   --  Does this command start with alr?

   function Quote (Arg : String) return String;
   --  Arg as one shell word: as it is when it is plain (letters, digits and
   --  _ . = - / ~ ^ :), else in single quotes.

   function Valid_Crate (Spec : String) return Boolean;
   --  A crate name, optionally with a version: "aunit", "aunit=24.0.0",
   --  "aunit^24", "aunit>=23 & <25".

end Turbo.Alire;
