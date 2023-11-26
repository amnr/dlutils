##  Nim package for easy shared library loading.
##
##  Usage
##  -----
##
##  The code below creates `proc open_math_library(): bool`
##  and `proc close_math_library()`.
##
##  The open proc tries to load shared library defined in paths and loads
##  all symbols defined in body.
##
##  The proc returns `true` on success
##  or `false` on error (no library found, one of symbols not found).
##  Procs and variables marked with `unchecked`_ pragma do not cause
##  open function to faile and are set to `nil`.
##
##  Allowed definitions in body:
##  - required proc: `proc (a: cint): cint`
##  - optional proc: `proc (a: cint): cint {.unchecked.}`
##  - required variable: `var a: cint`
##  - optional variable: `var a {.unchecked.}: cint`
##  - `where` statement
##
##  .. warning::
##    Do not add `ptr` to variable type, it's done automatically (variable
##    of type `cint` becomes `ptr cint`).
##
##  Source
##  ======
##
##  ```nim
##  import dlutils
##
##  dlgencalls "math", ["libm.so", "libm.so.6"]:
##    proc cbrt (x: cdouble): cdouble
##    proc sqrt (x: cdouble): cdouble {.unchecked.}
##    var reqvar: cint
##    var optvar {.unchecked.}: cint
##  ```
##
##  Generated code
##  ==============
##
##  ```nim
##  import std/dynlib
##
##  var math_handle: LibHandle = nil
##
##  var cbrt*: proc (x, y: cdouble): cdouble {.cdecl, gcsafe, raises: [].} = nil
##  var sqrt*: proc (x, y: cdouble): cdouble {.cdecl, gcsafe, raises: [].} = nil
##  var reqvar*: ptr cint = nil
##  var optvar*: ptr clong = nil
##
##  proc open_math_library*(): bool =
##    result =
##      ##  Open library.
##      if math_handle == nil:
##        math_handle = loadLib "libm.so"
##        if math_handle == nil:
##          return false
##        cbrt = cast[sqrt.type](symAddr(math_handle, "cbrt"))
##        if cbrt == nil:
##          return false
##        sqrt = cast[sqrt.type](symAddr(math_handle, "sqrt"))
##        reqvar = cast[reqvar.type](symAddr(math_handle, "reqvar"))
##        if reqvar == nil:
##          return false
##        optvar = cast[optvar.type](symAddr(math_handle, "optvar"))
##      true
##
##  proc close_math_library*() =
##    ##  Close library.
##    if math_handle != nil:
##      cbrt = nil
##      sqrt = nil
##      reqvar = nil
##      optvar = nil
##      math_handle.unloadLib
##      math_handle = nil
##  ```

{.push raises: [].}

import std/dynlib
import std/macros
when defined windows:
  from std/winlean import getLastError

when defined posix:
  proc c_dlerror(): cstring {.gcsafe, importc: "dlerror", raises: [].}

proc dlerror*(): string =
  ##  Return a human-readable string describing the most recent error that
  ##  occured form a call to `open_name_library()`.
  when defined posix:
    $c_dlerror()
  elif defined windows:
    result = ""
    if getLastError() != 0:
      return "dlopen failed: error " & $getLastError
  else:
    {.fatal: "unsupported platform".}

template unchecked* {.pragma.}
  ##  Functions and variables marked with this pragma do not cause open proc
  ##  to fail and are set to `nil` if not found in shared library.

proc has_pragma(def: NimNode, pragname: string): bool =
  ##  Return `true` if proc node has given pragma.
  case def.kind
  of nnkProcDef:
    # proc name() {.pragmas.}
    for p in def.pragma:
      if $p == pragname:
        return true
  of nnkVarSection:
    # var name {.pragmas.}: type
    if def[0][0].kind == nnkPragmaExpr:
      for p in def[0][0][1]:
        if $p == pragname:
          return true
  else:
    discard
  false

proc has_varargs(def: NimNode): bool =
  ##  Return `true` if proc node has unchecked pragma.
  def.has_pragma "varargs"

proc is_unchecked(def: NimNode): bool =
  ##  Return `true` if proc node has unchecked pragma.
  def.has_pragma "unchecked"

proc make_proc_node(def: NimNode): NimNode =
  ##  Create `proc` node.
  def.expectKind nnkProcDef

  let arg =
    if def.is_unchecked:
      # name* {.unchecked.}.
      nnkPragmaExpr.newTree(
        nnkPostfix.newTree(newIdentNode("*"), def.name),
        nnkPragma.newTree(newIdentNode("unchecked"))
      )
    else:
      # name*.
      nnkPostfix.newTree(newIdentNode("*"), def.name)

  var pragmas =
    # {.cdecl, gcsafe, raises: [].}.
    nnkPragma.newTree(
      newIdentNode("cdecl"),
      newIdentNode("gcsafe"),
      nnkExprColonExpr.newTree(
        newIdentNode("raises"), nnkBracket.newTree()
      )
    )

  if def.has_varargs:
    pragmas.add newIdentNode "varargs"

  nnkVarSection.newTree(
    nnkIdentDefs.newTree(
      arg,
      nnkProcTy.newTree(
        def.params,
        pragmas
      ),
      newNilLit()
    )
  )

proc make_var_node(def: NimNode): NimNode =
  ##  Create `var` node.
  def.expectKind nnkVarSection
  def.expectLen 1

  def[0].expectKind nnkIdentDefs
  def[0].expectLen 3

  # var x: cint                 -> def[0] == (nnkIdent, nnkIdent, nnkEmpty)
  # var x {.unchecked.}: cint   -> def[0] == (nnkPragmaExpr, nnkIdent, nnkEmpty)

  case def[0][0].kind
  of nnkIdent:
    # var x: cint -> (nnkIdent, nnkIdent, nnkEmpty).
    let name = def[0][0]
    let typ = def[0][1]
    return quote do:
      var `name`*: ptr `typ` = nil
  of nnkPragmaExpr:
    # var x {.unchecked.}: cint -> (nnkPragmaExpr, nnkIdent, nnkEmpty).
    def[0][1].expectKind nnkIdent
    def[0][0][0].expectKind nnkIdent
    let name = def[0][0][0]
    let typ = def[0][1]
    return quote do:
      var `name`*: ptr `typ` = nil
  else:
    error "Expected a node of kind nnkIdent or nnkPragmaExpr, got " &
          $def[0].kind

proc create_global_vars(statements: NimNode): NimNode =
  ##  Create global variables.
  statements.expectKind nnkStmtList
  result = nnkStmtList.newTree
  for stmt in statements:
    case stmt.kind
    of nnkProcDef:
      result.add make_proc_node stmt
    of nnkVarSection:
      result.add make_var_node stmt
    of nnkWhenStmt:
      # WhenStmt(ElifBranch(<<condition>>, StmtList(<<statement>>)))
      let cond = stmt[0][0]
      let st = create_global_vars stmt[0][1]
      result.add quote do:
        when `cond`:
          `st`
    else:
      error "Expected a node of kind nnkProcDef, nnkVarSection" &
            " or nnkWhenStmt, got " & $stmt.kind

proc create_casts(libhandle: NimNode, statements: NimNode): NimNode =
  ##  Create proc casts.
  statements.expectKind nnkStmtList
  result = nnkStmtList.newTree
  for stmt in statements:
    case stmt.kind
    of nnkProcDef:
      let n = stmt.name
      let s = $n
      result.add quote do:
        `n` = cast[`n`.type](`libhandle`.symAddr `s`)
      if not stmt.is_unchecked:
        result.add quote do:
          if `n` == nil:
            return false
    of nnkVarSection:
      var n: NimNode
      case stmt[0][0].kind
      of nnkIdent:
        n = stmt[0][0]
      of nnkPragmaExpr:
        n = stmt[0][0][0]
      else:
        error "Expected a node of kind nnkIdent or nnkPragmaExpr, got " &
              $stmt[0][0].kind
      let s = $n
      result.add quote do:
        `n` = cast[`n`.type](`libhandle`.symAddr `s`)
      if not stmt.is_unchecked:
        result.add quote do:
          if `n` == nil:
            return false
    of nnkWhenStmt:
      # WhenStmt(ElifBranch(<<condition>>, StmtList(<<statement>>)))
      let cond = stmt[0][0]
      let st = create_casts(libhandle, stmt[0][1])
      result.add quote do:
        when `cond`:
          `st`
    else:
      error "Expected a node of kind nnkProcDef, nnkVarSection" &
            " or nnkWhenStmt, got " & $stmt.kind

proc create_nils(statements: NimNode): NimNode =
  ##  Set procs and vars to `nil`.
  statements.expectKind nnkStmtList
  result = nnkStmtList.newTree
  for stmt in statements:
    case stmt.kind
    of nnkProcDef:
      let n = stmt.name
      result.add quote do:
        `n` = nil
    of nnkVarSection:
      var n: NimNode
      case stmt[0][0].kind
      of nnkIdent:
        n = stmt[0][0]
      of nnkPragmaExpr:
        n = stmt[0][0][0]
      else:
        error "Expected a node of kind nnkIdent or nnkPragmaExpr, got " &
              $stmt[0][0].kind
      result.add quote do:
        `n` = nil
    of nnkWhenStmt:
      # WhenStmt(ElifBranch(<<condition>>, StmtList(<<statement>>)))
      let cond = stmt[0][0]
      let st = create_nils stmt[0][1]
      result.add quote do:
        when `cond`:
          `st`
    else:
      error "Expected a node of kind nnkProcDef, nnkVarSection" &
            " or nnkWhenStmt, got " & $stmt.kind

macro dlgencalls*(name: static string, libpaths: static openArray[string],
                  body: untyped): untyped =
  ##  Create `open_name_library(): bool`, `close_name_library()`
  ##  and C procesures and variables declared in `body`.
  ##
  ##  Function `open_name_library()` tries to load shared libary defined
  ##  in `libpaths` and loads all symbols defined in `body`. This function
  ##  returns `true` on success or `false` on error (no library found,
  ##  symbol not found). Functions and variables marked with `unchecked`_
  ##  pragam are set to `nil`.
  ##
  ##  Function `close_name_library()` sets all symbols to `nil` and closes
  ##  the library.

  # Check args.
  # libpaths.expectKind {nnkStrLit, nnkSym}
  body.expectKind nnkStmtList

  # Library handle name.
  let soname = $name
  let libhandle = newIdentNode(soname & "_handle")
  let init_name = newIdentNode("open_" & $soname & "_library")
  let deinit_name = newIdentNode("close_" & $soname & "_library")

  let
    procs = create_global_vars body
    pvars = create_casts(libhandle, body)
    nills = create_nils body

  quote do:
    var `libhandle`: LibHandle = nil

    `procs`

    proc `init_name`*(): bool =
      ##  Open library.
      if `libhandle` == nil:
        for path in `libpaths`:
          `libhandle` = loadLib path
          if `libhandle` != nil:
            break
        if `libhandle` == nil:
          return false
        `pvars`
      true

    proc `deinit_name`*() =
      ##  Close library.
      if `libhandle` != nil:
        `nills`
        `libhandle`.unloadLib
        `libhandle` = nil

template dlgencalls*(name: static string, libpath: static string,
                     body: untyped): untyped =
  ##  Create `open_name_library(): bool`, `close_name_library()`
  ##  and C procesures and variables declared in `body`.
  ##
  ##  Function `open_name_library()` tries to load shared libary defined
  ##  in `libpath` and loads all symbols defined in `body`. This function
  ##  returns `true` on success or `false` on error (no library found,
  ##  symbol not found). Functions and variables marked with `unchecked`_
  ##  pragam are set to `nil`.
  ##
  ##  Function `close_name_library()` sets all symbols to `nil` and closes
  ##  the library.
  dlgencalls name, [libpath], body

# vim: set sts=2 et sw=2:
