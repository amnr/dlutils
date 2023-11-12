# Simple test using math library.

import std/strformat
import std/unittest
import dlutils

when defined macosx:
  const libm = "libm.dynlib"
elif defined posix:
  const libm = "libm.so(|.6)"
else:
  const libm = ""

type
  MathLib = object
    handle: LibHandle

    cbrt:               proc (x: cdouble): cdouble {.cdecl.}
    sqrt {.unchecked.}: proc (x: cdouble): cdouble {.cdecl.}

when libm != "":
  test "libm: checked and unchecked":
    let lib = loadLibrary[MathLib](libm)
    defer:
      lib.unloadLibrary

    check lib.cbrt != nil
    check fmt"{lib.cbrt(2):.3f}" == "1.260"

    if lib.sqrt != nil:
      check fmt"{lib.sqrt(2):.3f}" == "1.414"

# vim: set sts=2 et sw=2:
