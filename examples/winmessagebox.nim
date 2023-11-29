##  Message box example (WinAPI).
#[
  SPDX-License-Identifier: MIT or NCSA
]#

{.push raises: [].}

import dlutils

when not defined windows:
  {.fatal: "platform not supported".}

const
  libpath = "user32.dll"

const
  MB_ICONINFORMATION  = 0x0000_0040
  MB_OK               = 0x0000_0000

dlgencalls "user32", libpath:
  proc MessageBoxA(wnd: pointer, text, caption: cstring, typ: cuint): cint

proc show_info_box(message: string, title = "Info") =
  ##  Proc for convenience.
  discard MessageBoxA(nil, message, title, MB_ICONINFORMATION or MB_OK)

proc main() =
  if not open_user32_library():
    echo "Failed to open library: ", last_user32_error()
    quit QuitFailure
  defer:
    close_user32_library()

  show_info_box "Hello from Nim."

when isMainModule:
  main()

# vim: set sts=2 et sw=2:
