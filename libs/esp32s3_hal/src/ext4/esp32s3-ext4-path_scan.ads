--  Pure '/'-separated path-component scanner, shared by ESP32S3.Ext4.Path
--  (multi-component resolution) and ESP32S3.Ext4.VFS (leading-component mount
--  routing).  Both walk attacker-/user-supplied path strings, so the scan is
--  split out here and formally proved never to index or slice outside the input
--  (see libs/esp32s3_hal/test/path_scan_prove).  No I/O, no state -- just index
--  arithmetic over a String.

package ESP32S3.Ext4.Path_Scan
  with SPARK_Mode => On
is

   --  One '/'-separated component of a path.  The component text is
   --  Path (First .. Last) -- EMPTY when Last < First (a run of '/', or the end
   --  of the string) -- and Next is where the following scan resumes (just past
   --  the component, or one past Path'Last at the end).
   type Component is record
      First : Positive;
      Last  : Natural;
      Next  : Positive;
   end record;

   --  Scan the next component of Path at or after From: skip a run of '/', then
   --  take the run of non-'/'.  From may be Path'Last + 1 ("already at the end"),
   --  which yields an empty component.
   --
   --  The Post has two halves.  The first bounds every returned index, so the
   --  caller's Path (First .. Last) slice and its resume at Next are always
   --  within the string -- memory safety on an attacker-supplied path.  The
   --  second says what a "component" actually IS, and is the half a caller's
   --  own correctness rests on:
   --
   --    * PROGRESS -- Next > From whenever there was any input left.  Without
   --      this a walker (Ext4.Path, Ext4.VFS) has no proof its loop terminates:
   --      the bounds alone permit Next = From, i.e. a hostile path spinning the
   --      resolver forever.  It is the one clause here that closes a real gap.
   --    * The component holds no '/' -- so the returned slice can never be a
   --      multi-component path smuggled through as one name.
   --    * Only '/' was skipped, and the scan stopped only at a '/' or the end
   --      (maximality).  Together with the above these pin Next_Component to
   --      exactly one answer for every (Path, From): the whole specification,
   --      not a safety envelope around it.
   function Next_Component (Path : String; From : Positive) return Component
     with
       Pre  => Path'First >= 1
               and then Path'Last < Positive'Last
               and then From >= Path'First
               and then From <= Path'Last + 1,
       Post =>
         --  ---- in bounds -----------------------------------------------------
         Next_Component'Result.First >= Path'First
         and then Next_Component'Result.First <= Path'Last + 1
         and then Next_Component'Result.Last <= Path'Last
         and then Next_Component'Result.Last >= Next_Component'Result.First - 1
         and then Next_Component'Result.Next >= From
         and then Next_Component'Result.Next <= Path'Last + 1
         and then Next_Component'Result.Next >= Next_Component'Result.First
         --  ---- what a component is -------------------------------------------
         --  progress: a caller's walk over Path terminates.
         and then (if From <= Path'Last then Next_Component'Result.Next > From)
         --  Next resumes just past the component.
         and then Next_Component'Result.Next = Next_Component'Result.Last + 1
         --  the component text contains no separator.
         and then (for all K in Next_Component'Result.First
                             .. Next_Component'Result.Last => Path (K) /= '/')
         --  everything skipped before it was a separator ...
         and then (for all K in From .. Next_Component'Result.First - 1
                   => Path (K) = '/')
         --  ... and the scan stopped only at a separator, never early.
         and then (if Next_Component'Result.Next <= Path'Last
                   then Path (Next_Component'Result.Next) = '/');

end ESP32S3.Ext4.Path_Scan;
