# Simple test using math library.

import std/strformat
import std/unittest

import dlutils

abortOnError = true

when defined posix:
  const libm = ["libm.so", "libm.so.6"]
elif defined macosx:
  const libm = "libm.dynlib"
else:
  {.fatal: "platform not supported".}

dlgencalls "math", libm:
  proc cbrt (x: cdouble): cdouble
  proc sqrt (x: cdouble): cdouble {.unchecked.}

test "libm":
  check open_math_library()
  defer:
    close_math_library()

  check cbrt != nil
  check fmt"{cbrt(2):.3f}" == "1.260"

  if sqrt != nil:
    check fmt"{sqrt(2):.3f}" == "1.414"

# vim: set sts=2 et sw=2:
