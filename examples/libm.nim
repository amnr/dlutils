##  Math library example.
#[
  SPDX-License-Identifier: MIT or NCSA
]#

{.push raises: [].}

import dlutils

when defined posix:
  const libpaths = [ "libm.so.6" ]
elif defined windows:
  const libpaths = [ "libopenlibm.dll" ]
else:
  {.fatal: "platform not supported".}

dlgencalls "math", libpaths:
  proc sqrt(x: cdouble): cdouble
  proc sqrtf(x: cfloat): cfloat

proc main() =
  if not open_math_library():
    echo "Failed to open library: ", last_math_error()
    quit QuitFailure
  defer:
    close_math_library()

  echo "sqrt(2)  = ", sqrt 2.0
  echo "sqrtf(2) = ", sqrtf 2.0f

when isMainModule:
  main()

# vim: set sts=2 et sw=2:
