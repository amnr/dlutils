# `dlutils`

`dlutils` is a Nim package for easy shared library loading.

## Installing

```sh
$ make install
```

## Basic Usage

```Nim
import dlutils

type
  MathLib = object
    handle: LibHandle

    cbrt: proc (x: cdouble): cdouble {.cdecl.}
    sqrt {.unchecked.}: proc (x: cdouble): cdouble {.cdecl.}

proc main() =
  let lib = loadLibrary[MathLib]("libm.so(|.6)")
  defer:
    lib.unloadLibrary

  echo "cbrt(2.0) = ", lib.cbrt 2.0

  # sqrt is marked as unchecked - it will be nil if not found.
  if lib.sqrt != nil:
    echo "sqrt(2.0) = ", lib.sqrt 2.0
```

[//]: # (vim: set sts=4 et sw=4)
