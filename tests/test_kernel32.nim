##  Test shared library loading on Windows.
#[
  SPDX-License-Identifier: MIT or NCSA
]#

discard """
  action: "run"
  batchable: true
  joinable: true
  matrix: "; -d=release"
  sortoutput: true
  valgrind: false
  targets: "c"
  disabled: "macosx"
  disabled: "posix"
"""

import std/strformat
import std/unittest

import dlutils

abortOnError = true

when not defined windows:
  {.fatal: "platform not supported".}

const
  libpath = "kernel32.dll"

dlgencalls "kernel32", libpath:
  proc GetLastError(): uint32
  proc SetLastError(err_code: uint32)

test "kernel32":
  check open_kernel32_library()
  defer:
    close_kernel32_library()

  SetLastError 0
  check GetLastError() == 0

  SetLastError 666
  check GetLastError() == 666

# vim: set sts=2 et sw=2:
