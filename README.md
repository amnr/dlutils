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

The proc returns `true` on success or `false` on error (no library found,
one of symbols not found).
Procs and variables marked with `unchecked`_ pragma do not cause
open function to faile and are set to `nil`.

Allowed definitions in body:
- proc: `proc (a: cint): cint`
- var: `var a: cint`
- `where` statement

Allowed `proc` pragmas:
- `{.importc: "source_name".}` - used when original name is invalid in Nim
                                 or you want to change it
- `{.unchecked.}` - used when definiton is optional - the proc pointer
                    is set to `nil` if no such proc is found in library
- `{.varargs.}` - used when proc takes varargs

Allowed `var` pragmas:
- `{.importc: "source_name".}` - used when original name is invalid in Nim
                                 or you want to change it
- `{.unchecked.}` - used when defintion is optional

All other proc/var pragmas are ignored.

> **_Note:_**
  Multiple variables in single `var` statement are not allowed.
  Use single `var` statement per variable.

> **_Warning:_**
  Do not add `ptr` to variable type, it's done automatically (variable
  of type `cint` becomes `ptr cint`).

### Source Code

This code creates `proc open_math_library(): bool`
and `proc close_math_library()` functions.

```nim
import dlutils

# Create open_math_library, close_math_library and proc/var defined in:
dlgencalls "math", ["libm.so", "libm.so.6"]:
  # Required proc. open_math_library returns false if not found.
  proc cbrt (x: cdouble): cdouble

  # Optional proc. open_math_library sets sqrt to nil if not found.
  proc sqrt (x: cdouble): cdouble {.unchecked.}

  # Function "sqrtf" imported as "sqrt2".
  proc sqrt2 (x: cfloat): cfloat {.importc: "sqrtf".}

  # Required var of type ptr cint.
  var reqvar: cint

  # Optional var of type ptr clong.
  var optvar {.unchecked.}: clong
```

### Generated Code

```nim
var math_handle: LibHandle = nil

var cbrt*: proc (x, y: cdouble): cdouble {.cdecl, gcsafe, raises: [].} = nil
var sqrt*: proc (x, y: cdouble): cdouble {.cdecl, gcsafe, raises: [].} = nil
var sqrt2*: proc (x, y: cfloat): cfloat {.cdecl, gcsafe, raises: [].} = nil
var reqvar*: ptr cint = nil
var optvar*: ptr clong = nil

proc open_math_library*(): bool =
  result =
    ##  Open library.
    if math_handle == nil:
      math_handle = loadLib "libm.so"
      if math_handle == nil:
        return false
      cbrt = cast[cbrt.type](symAddr(math_handle, "cbrt"))
      if cbrt == nil:
        return false
      sqrt = cast[sqrt.type](symAddr(math_handle, "sqrt"))
      sqrt2 = cast[sqrt2.type](symAddr(math_handle, "sqrtf"))
      if sqrt2 == nil:
        return false
      reqvar = cast[reqvar.type](symAddr(math_handle, "reqvar"))
      if reqvar == nil:
        return false
      optvar = cast[optvar.type](symAddr(math_handle, "optvar"))
    true

proc close_math_library*() =
  ##  Close library.
  if math_handle != nil:
    cbrt = nil
    sqrt = nil
    sqrt2 = nil
    reqvar = nil
    optvar = nil
    math_handle.unloadLib
    math_handle = nil
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
