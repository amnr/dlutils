##  Dynlib module utils.
##
##  Example
##  -------
##
##  .. code-block:: Nim
##    type
##      MathLib = object
##        handle: LibHandle
##
##        cbrt: proc (x: cdouble): cdouble {.cdecl.}
##        sqrt {.unchecked.}: proc (x: cdouble): cdouble {.cdecl.}
##
##    proc main() =
##      let lib = loadLibrary[MathLib]("libm.so(|.6)")
##      defer:
##        lib.unloadLibrary
##
##      echo "cbrt(2.0) = ", lib.cbrt 2.0
##
##      # sqrt is marked as unchecked - it will be nil if not found.
##      if lib.sqrt != nil:
##        echo "sqrt(2.0) = ", lib.sqrt 2.0
##    

import std/dynlib
import std/macros

import dynlibutils/pragmautils

export LibHandle, checkedSymAddr, symAddr

type
  DynLib* = concept lib
    ##  Shared library object.
    lib.handle is LibHandle

  LibraryNotFoundError* = object of LibraryError
    ##  Raised by `loadLibrary proc <#loadLibrary,string>`_ if the library
    ##  could not be found.

template unchecked*() {.pragma.}
  ##  Annotate shared library object field with `unchecked` pragma to use
  ##  `symAddr proc <https://nim-lang.org/docs/dynlib.html#symAddr,LibHandle,cstring>`_
  ##  on that field instead of
  ##  `checkedSymAddr proc <https://nim-lang.org/docs/dynlib.html#checkedSymAddr,LibHandle,cstring>`_.

# proc proc_pragmas(n: NimNode): seq[string] =
#   n.expectKind nnkProcTy
#   n[1].expectKind nnkPragma
#   for item in n[1].children:
#     result.add $item

macro initDynLibImpl(t: typed): untyped =
  # result = t
  # SampleLib = t.getTypeInst
  let impl = t.getTypeImpl
  impl.expectKind nnkObjectTy
  result = newNimNode nnkStmtList
  for def in impl[2].children:
    def.expectKind nnkIdentDefs
    case def[1].typeKind
    of ntyPointer:
      if $def[1] == LibHandle.astToStr:
        continue
      # XXX: check for .cdecl. fields.
    of ntyProc:   # [Sym, ProcTy[FormatParams, Pragma], Empty] with pragma
                  # [Sym, ProcTy[FormatParams, Empry], Empty]  w/o pragma
      if def[1][1].kind == nnkPragma:
        let
          var_node = t
          type_node = t.getTypeInst
          proc_node = def[0]
          symaddr_name =
            if "unchecked" notin t.pragmas($proc_node):
              "checkedSymAddr"
            else:
              "symAddr"
          cst = newNimNode nnkCast
        cst.add newDotExpr(type_node, def[0])
        cst.add newCall(ident symaddr_name,
                        newDotExpr(var_node, ident "handle"),  # XXX: find handle.
                        newLit $proc_node)
        result.add newAssignment(
          newDotExpr(var_node, proc_node),
          cst)
    else:
      discard

proc loadLibrary*[T: DynLib](pattern: string): T =
  ##  Loads a shared library with name matching `pattern` and initializes all
  ##  procs annotated with `cdecl` pragma.
  ##  Raises `LibraryNotFoundError` if the library could not be found.
  ##  Raises `LibraryError` if any of symbols could not be found (unless marked
  ##  with `unchecked` pragma).
  result.handle = loadLibPattern pattern
  if unlikely result.handle == nil:
    raise newException(LibraryNotFoundError,
                       "could not find library: " & pattern)
  initDynLibImpl result

proc unloadLibrary*(self: DynLib) {.raises: [].} =
  ##  Unloads a shared library.
  if self.handle != nil:
    self.handle.unloadLib

# vim: set sts=2 et sw=2:
