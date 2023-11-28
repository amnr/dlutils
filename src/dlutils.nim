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
##  The proc returns `true` on success or `false` on error (no library found,
##  one of symbols not found).
##  Procs and variables marked with `unchecked`_ pragma do not cause
##  open function to faile and are set to `nil`.
##
##  Allowed definitions in body:
##  - proc: `proc (a: cint): cint`
##  - var: `var a: cint`
##  - `where` statement
##
##  Allowed `proc` pragmas:
##  - `{.importc: "source_name".}` - used when original name is invalid in Nim
##                                   or you want to change it
##  - `{.unchecked.}` - used when definiton is optional - the proc pointer
##                      is set to `nil` if no such proc is found in library
##  - `{.varargs.}` - used when proc takes varargs
##
##  Allowed `var` pragmas:
##  - `{.importc: "source_name".}` - used when original name is invalid in Nim
##                                   or you want to change it
##  - `{.unchecked.}` - used when defintion is optional
##
##  All other proc/var pragmas are ignored.
##
##  .. note::
##    Multiple variables in single `var` statement are not allowed.
##    Use single `var` statement per variable.
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
##  # Create open_math_library, close_math_library and proc/var defined in:
##  dlgencalls "math", ["libm.so", "libm.so.6"]:
##    # Required proc. open_math_library returns false if not found.
##    proc cbrt (x: cdouble): cdouble
##
##    # Optional proc. open_math_library sets sqrt to nil if not found.
##    proc sqrt (x: cdouble): cdouble {.unchecked.}
##
##    # Function "sqrtf" imported as "sqrt2".
##    proc sqrt2 (x: cfloat): cfloat {.importc: "sqrtf".}
##
##    # Required var of type ptr cint.
##    var reqvar: cint
##
##    # Optional var of type ptr clong.
##    var optvar {.unchecked.}: clong
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
##  var sqrt2*: proc (x, y: cfloat): cfloat {.cdecl, gcsafe, raises: [].} = nil
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
##        cbrt = cast[cbrt.type](symAddr(math_handle, "cbrt"))
##        if cbrt == nil:
##          return false
##        sqrt = cast[sqrt.type](symAddr(math_handle, "sqrt"))
##        sqrt2 = cast[sqrt2.type](symAddr(math_handle, "sqrtf"))
##        if sqrt2 == nil:
##          return false
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
##      sqrt2 = nil
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

proc has_pragma(node: NimNode, pragname: string): bool =
  ##  Return `true` if IdentDefs/ProcDef node has given pragma.
  node.expectKind {nnkIdentDefs, nnkProcDef}

  if node.kind == nnkIdentDefs:
    # Node is var.
    node[0].expectKind {nnkIdent, nnkPragmaExpr}

    if node[0].kind == nnkPragmaExpr:   # var with pragma.
      node[0][0].expectKind nnkIdent
      node[0][1].expectKind nnkPragma

      for p in node[0][1]:
        p.expectKind {nnkExprColonExpr, nnkIdent}

        if p.kind == nnkExprColonExpr and $p[0] == pragname:
          # var name {.pragma: "value".}: type
          return true
        if p.kind == nnkIdent and $p == pragname:
          # var name {.pragma.}: type
          return true
    if node[0].kind == nnkIdent:        # var without pragma.
      return false
  elif node.kind == nnkProcDef:
    # Node is: proc name() {.pragmas.}
    for p in node.pragma:
      p.expectKind {nnkExprColonExpr, nnkIdent}
      if p.kind == nnkIdent and $p == pragname:
        # Proc pragma is: {.pragma.}
        return true
      if p.kind == nnkExprColonExpr and $p[0] == pragname:
        # Proc pragma is: {.pragma: "value".}
        return true
  false

proc pragma_value(node: NimNode, pragname: string): string =
  ##  Return the value of IdentDefs/ProcDef pragma or "" if pragma not found.
  node.expectKind {nnkIdentDefs, nnkProcDef}
  if node.kind == nnkIdentDefs:
    node[0].expectKind {nnkIdent, nnkPragmaExpr}
    if node[0].kind == nnkPragmaExpr:     # var with pragma.
      node[0][0].expectKind nnkIdent
      node[0][1].expectKind nnkPragma
      for p in node[0][1]:
        p.expectKind {nnkExprColonExpr, nnkIdent}
        if p.kind == nnkExprColonExpr and $p[0] == pragname:
          # var name {.pragma: value.}: type
          return $p[1]
        if p.kind == nnkIdent and $p == pragname:
          return ""
      return ""
    elif node[0].kind == nnkIdent:        # var without pragma.
      return ""
  elif node.kind == nnkProcDef:
    for p in node.pragma:
      p.expectKind nnkExprColonExpr
      if $p[0] == pragname:
        return $p[1]
  return ""

proc has_varargs(node: NimNode): bool =
  ##  Return `true` if proc node has varargs pragma.
  node.expectKind nnkProcDef
  node.has_pragma "varargs"

proc is_unchecked(def: NimNode): bool =
  ##  Return `true` if prov/var node has unchecked pragma.
  def.has_pragma "unchecked"

proc source_name(node: NimNode): string =
  ##  Return source name stored in importc pragma of proc or var.
  node.expectKind {nnkProcDef, nnkIdentDefs}

  if node.has_pragma "importc":
    node.pragma_value "importc"
  else:
    $node.name

proc make_proc_node(def: NimNode): NimNode =
  ##  Create `proc` node.
  def.expectKind nnkProcDef

  var pragmas =
    # Default pragmas: {.cdecl, gcsafe, raises: [].}.
    nnkPragma.newTree(
      newIdentNode("cdecl"),
      newIdentNode("gcsafe"),
      nnkExprColonExpr.newTree(
        newIdentNode("raises"), nnkBracket.newTree()
      )
    )

  if def.has_varargs:
    # Optional pragma: varargs.
    pragmas.add newIdentNode "varargs"

  nnkVarSection.newTree(
    nnkIdentDefs.newTree(
      nnkPostfix.newTree(
        newIdentNode("*"), def.name
      ),
      nnkProcTy.newTree(
        def.params,
        pragmas
      ),
      newNilLit()
    )
  )

proc make_var_node(def: NimNode): NimNode =
  ##  Create `var` node from var section.
  ##  Only single var sections are supported.
  def.expectKind nnkVarSection
  def.expectLen 1

  def[0].expectKind nnkIdentDefs
  def[0].expectLen 3

  # var x: cint                 -> def[0] == (nnkIdent, nnkIdent, nnkEmpty)
  # var x {.unchecked.}: cint   -> def[0] == (nnkPragmaExpr, nnkIdent, nnkEmpty)

  def[0][0].expectKind {nnkIdent, nnkPragmaExpr}

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
    discard

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
  ##  Create proc cast statements.
  statements.expectKind nnkStmtList

  result = nnkStmtList.newTree
  for stmt in statements:
    case stmt.kind
    of nnkProcDef:
      let n = stmt.name
      let s = stmt.source_name
      result.add quote do:
        `n` = cast[`n`.type](`libhandle`.symAddr `s`)
      if not stmt.is_unchecked:
        result.add quote do:
          if `n` == nil:
            return false
    of nnkVarSection:
      stmt[0][0].expectKind {nnkIdent, nnkPragmaExpr}
      var n: NimNode
      case stmt[0][0].kind
      of nnkIdent:
        n = stmt[0][0]
      of nnkPragmaExpr:
        n = stmt[0][0][0]
      else:
        discard

      let s = stmt[0].source_name

      result.add quote do:
        `n` = cast[`n`.type](`libhandle`.symAddr `s`)
      if not stmt[0].is_unchecked:
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
