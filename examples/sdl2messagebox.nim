##  Message box example (SDL2).
#[
  SPDX-License-Identifier: MIT or NCSA
]#

{.push raises: [].}

import dlutils

when defined posix:
  const libpaths = [ "libSDL2-2.0.so", "libSDL2-2.0.so.0" ]
elif defined windows:
  const libpaths = "SDL.dll"
else:
  {.fatal: "platform not supported".}

const
  SDL_MESSAGEBOX_INFORMATION  = 0x00000040

dlgencalls "sdl2", libpaths:
  proc SDL_ShowSimpleMessageBox(flags: uint32, title, message: cstring,
                                window: pointer): cint

proc show_info_box(message: string, title = "Info") =
  ##  Proc for convenience.
  const flags = SDL_MESSAGEBOX_INFORMATION
  discard SDL_ShowSimpleMessageBox(flags, title, message, nil)

proc main() =
  if not open_sdl2_library():
    echo "Failed to open library: ", last_sdl2_error()
    quit QuitFailure
  defer:
    close_sdl2_library()

  show_info_box "Hello from Nim."

when isMainModule:
  main()

# vim: set sts=2 et sw=2:
