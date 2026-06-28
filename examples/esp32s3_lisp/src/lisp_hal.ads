--  The HAL bridge: register hardware primitives into the LISP global environment,
--  so REPL code can drive the board.  Kept in the application (not libs/lisp, which
--  stays pure and host-testable) -- each primitive is a library-level Ada function
--  calling the HAL directly.
--
--  Primitives added:
--    (gpio-out PIN VAL)   configure PIN as output, drive it high/low; returns VAL
--    (gpio-toggle PIN)    flip an output pin
--    (gpio-in PIN)        configure PIN as input, return its level (#t / #f)
--    (adc-read CH)        one ADC1 sample on channel CH (0 .. 9) -> 0 .. 4095
package Lisp_HAL is
   procedure Register;
end Lisp_HAL;
