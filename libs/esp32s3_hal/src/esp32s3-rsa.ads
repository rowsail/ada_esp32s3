with Interfaces;

--  ESP32-S3 RSA accelerator -- big-integer modular exponentiation (Z = X^Y mod M),
--  the core of RSA signature verification.  The hardware does Montgomery
--  exponentiation up to 4096-bit; this driver loads the operands, supplies the
--  Montgomery constants (M' is computed here; R2 is provided), runs the operation
--  and reads the result.
--
--  Operands are little-endian arrays of 32-bit words, all the same length N
--  (1 .. 128 words = 32 .. 4096 bit).  M must be odd (true of every RSA modulus).
--  Lock-free and ZFP-safe: a sequence of register accesses, no tasking, no heap.

package ESP32S3.RSA is

   type Word is new Interfaces.Unsigned_32;
   type Word_Array is array (Natural range <>) of Word;   --  little-endian limbs

   --  Z := X^Y mod M.  R2 is the Montgomery constant R^2 mod M with R = 2^(32*N)
   --  (N = M'Length words); compute it on the host or with a bignum helper.  Ok is
   --  False if the accelerator did not become ready / finish within a bounded wait
   --  (a hardware fault) -- Z is then meaningless.
   procedure Mod_Exp (X, Y, M, R2 : Word_Array; Z : out Word_Array; Ok : out Boolean)
   with
     Pre =>
       M'Length in 1 .. 128
       and then X'Length = M'Length
       and then Y'Length = M'Length
       and then R2'Length = M'Length
       and then Z'Length = M'Length;

   --  As above, but compute the Montgomery constant R^2 mod M in software
   --  (shift / compare / subtract -- no multiply, the hardware does that), so it
   --  works on any modulus, e.g. an X.509 certificate's, with no host-precomputed
   --  constant.  M must be odd.
   procedure Mod_Exp (X, Y, M : Word_Array; Z : out Word_Array; Ok : out Boolean)
   with
     Pre =>
       M'Length in 1 .. 128
       and then X'Length = M'Length
       and then Y'Length = M'Length
       and then Z'Length = M'Length;

end ESP32S3.RSA;
