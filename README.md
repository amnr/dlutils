# `dlutils`

`dlutils` is a Nim package for easy shared library loading.

## Installing

```sh
$ git clone https://github.com/amnr/dlutils/
$ cd dlutils
$ nimble install
```

## Usage

The code below creates `proc open_math_library(): bool`
and `proc close_math_library()`.

The open proc tries to load shared library defined in paths and loads
all symbols defined in body.

The proc returns `true` on success
or `false` on error (no library found, one of symbols not found).
Procs and variables marked with `unchecked`_ pragma do not cause
open function to faile and are set to `nil`.

Allowed definitions in body:
- required proc: `proc (a: cint): cint`
- optional proc: `proc (a: cint): cint {.unchecked.}`
- required variable: `var a: cint`
- optional variable: `var a {.unchecked.}: cint`
- `where` statement

> **_Warning:_**
  Do not add `ptr` to variable type, it's done automatically (variable
  of type `cint` becomes `ptr cint`).

### Source Code

This code creates `proc open_math_library(): bool`
and `proc close_math_library()` functions.

```nim
import dlutils

dlgencalls "math", ["libm.so", "libm.so.6"]:
  proc cbrt (x: cdouble): cdouble
  proc sqrt (x: cdouble): cdouble {.unchecked.}
  var reqvar: cint
  var optvar {.unchecked.}: clong
```

### Generated Code

```nim
var math_handle: LibHandle = nil

var cbrt*: proc (x, y: cdouble): cdouble {.cdecl, gcsafe, raises: [].} = nil
var sqrt*: proc (x, y: cdouble): cdouble {.cdecl, gcsafe, raises: [].} = nil
var reqvar*: ptr cint = nil
var optvar*: ptr clong = nil

proc open_math_library*(): bool {.raises: [].} =
  # (generated code)

proc close_math_library*() {.raises: [].} =
  # (generated code)

```

## Sample Code

```Nim
import dlutils

# This dlgencalls will create two functions:
# - proc open_math_library(): bool
# - close_math_library()
dlgencalls "math", ["libm.so", "libm.so.6"]:
  # Required proc - open_math_library will fail (return false)
  # if not found.
  proc cbrt (x: cdouble): cdouble

  # Optional proc - sqrt will be nil if not found.
  proc sqrt (x: cdouble): cdouble {.unchecked.}

  # Required global variable (ptr cint) - open_math_library
  # will fail if not found.
  var reqvar: cint

  # Optional global variable (ptr clong) - optval will be set
  # to nil if not found.
  var optvar {.unchecked.}: clong

proc main() =
  if not open_math_library():
    echo "Failed to open library"
    quit QuitFailure

  defer:
    close_math_library()

  echo "cbrt(2.0) = ", cbrt 2.0

  if sqrt != nil:
    echo "sqrt(2.0) = ", sqrt 2.0

  echo "reqvar: ", reqvar[]

  if optval != nil:
    echo "optvar: ", optvar[]

when isMainModule:
  main()
```

## License

`dlutils` is released under (either or both):

- [**MIT**](LICENSE-MIT.txt) &mdash; Nim license
- [**NCSA**](LICENSE-NCSA.txt) &mdash; author's license of choice

[//]: # (vim: set sts=4 et sw=4)
