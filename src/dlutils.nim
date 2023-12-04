##  Nim package for easy shared library loading.
##
##  Usage
##  -----
##
##  ```nim
##  dlgencalls "somelib", paths:
##    # proc and var definitions
##  ```
##
##  `dlgencalls` creates three procs: `proc open_somelib_library(): bool`,
##  `proc close_somelib_library()` and `proc last_somelib_error()`.
##
##  Open proc
##  =========
##
##  The open proc tries to load shared library defined in paths and loads
##  all symbols defined in body. Paths may be either single string or an array
##  of strings. Subsequent calls are ignored.
##
##  The open proc returns `true` on success or `false` on error (no library
##  found, one of symbols not found).
##
##  Procs and variables marked with `unchecked`_ pragma do not cause
##  open function to faile and are set to `nil`.
##
##  Allowed definitions in body:
##  - proc: `proc (a: cint): cint`
##  - var: `var a: cint`
##  - `where` statement
##
##  Not allowed in body:
##  - export marker `*` in variable; all functions and variables are exported
##    by default
##  - multiple variables in single `var` statement; use single `var` statement
##    per variable
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
##  .. warning::
##    Do not add `ptr` to variable type, it's done automatically (variable
##    of type `cint` becomes `ptr cint`).
##
##  Close proc
##  ==========
##
##  The close proc unloads the shared library. All symbols loaded are set
##  to `nil`. Subsequent calls are ignored.
##
##  Error proc
##  ==========
##
##  The error proc returns a human-readable string describing the error that
##  occured from a call to `open_name_library()` or empty string on no error.
##
##  The returned string does not include a trailing newline.
##
##  Example
##  -------
##
##  Source:
##
##  ```nim
##  import dlutils
##
##  # Create open_math_library, close_math_library, last_math_error
##  # and proc/var symbols defined in body.
##
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
##  Generated code:
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
##
##  proc last_math_error*(): string =
##    ##  Returns a string describing the error that occured from a call
##    ##  to open proc.
##    #[
##      code follows…
##    ]#
##  ```

{.push raises: [].}

import std/dynlib
when defined uselogging:
  import std/logging
import std/macros

template unchecked* {.pragma.}
  ##  Functions and variables marked with this pragma do not cause open proc
  ##  to fail and are set to `nil` if not found in shared library.

when defined posix:
  proc c_dlerror(): cstring {.gcsafe, importc: "dlerror", raises: [].}
elif defined windows:
  {.pragma: wincall, importc, raises: [], stdcall.}

  type
    DWORD   = uint32
    HANDLE  = PVOID
    HLOCAL  = HANDLE
    LPCVOID = pointer
    LPSTR   = pointer
    PVOID   = pointer

  proc GetLastError(): DWORD {.dynlib: "kernel32", wincall, sideEffect.}

  proc FormatMessageA(flags: DWORD, source: LPCVOID, message_id: DWORD,
                      language_id: DWORD, buffer: LPSTR, size: DWORD,
                      args: pointer): DWORD {.dynlib: "kernel32", wincall.}

  proc LocalFree(mem: HLOCAL): HLOCAL {.dynlib: "kernel32", wincall.}

proc error_message(): string =
  ##  Return a human-readable string describing the error that occured
  ##  from a call to `open_name_library()` or empty string on no error.
  ##
  ##  The returned string does not include a trailing newline.
  ##
  ##  On Windows it returns:
  ##    - "Module not found." -- DLL was not found.
  ##    - "Procedure not found."  -- A function/variable was not found in DLL.
  ##                                 No additional information is supplied.
  when defined posix:
    return $c_dlerror()
  elif defined windows:
    const flags = 0x00000100 or   # FORMAT_MESSAGE_ALLOCATE_BUFFER
                  0x00001000 or   # FORMAT_MESSAGE_FROM_SYSTEM
                  0x00000200      # FORMAT_MESSAGE_IGNORE_INSERTS

    # FormatMessageA returns "Success.\r\n" on no error.
    let err = GetLastError()
    if err == 0:
      return ""

    # FormatMessageA returns the number of characters stored in buffer,
    # excluding the terminating null character.
    var buf: cstring = nil
    if FormatMessageA(flags, nil, err, 0, buf.addr, 0, nil) != 0:
      result = $buf
      # Strip "\r\n".
      if result.len >= 2 and result[^2] == '\r' and result[^1] == '\n':
        result.setLen result.len - 2
    else:
      result = ""

    # It is safe to pass nil to LocalFree.
    discard LocalFree buf
  else:
    {.fatal: "unsupported platform".}

when defined uselogging:
  proc log_symbol_error(symbol: string) =
    try:
      error "dlutils: Failed to load symbol '", symbol, "': ", error_message()
    except:
      discard

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
    return node.pragma_value "importc"
  else:
    # Variable with pragma or not.
    # XXX: check above whether there is a pragma at all to simplify
    #      and not to repeat the checks.
    if node.kind == nnkProcDef:
      return $node.name
    elif node.kind == nnkIdentDefs:
      node[0].expectKind {nnkIdent, nnkPragmaExpr}
      if node[0].kind == nnkIdent:
        return $node[0]
      if node[0].kind == nnkPragmaExpr:
        return $node[0][0]

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
            when defined use_logging:
              log_symbol_error `s`
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
            when defined use_logging:
              log_symbol_error `s`
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
  ##  Create `open_name_library(): bool`, `close_name_library()`,
  ##  `last_name_error(): string` and C procedures/variables declared in `body`.
  ##
  ##  Function `open_name_library()` tries to load shared libary defined
  ##  in `libpaths` and loads all symbols defined in `body`. This function
  ##  returns `true` on success or `false` on error (no library found,
  ##  symbol not found). Functions and variables marked with `unchecked`_
  ##  pragam are set to `nil`. Subsequent calls are ignored.
  ##
  ##  `close_name_library()` proc unloads the shared library. All symbols
  ##  loaded are set to `nil`. Subsequent calls are ignored.
  ##
  ##  `last_name_error()` proc returns a human-readable string describing
  ##  the error that occured from a call to `open_name_library()` or empty
  ##  string on no error.
  ##
  ##  The returned string does not include a trailing newline.

  # Check args.
  # libpaths.expectKind {nnkStrLit, nnkSym}
  body.expectKind nnkStmtList

  # Library handle name.
  let soname = $name
  let libhandle = newIdentNode soname & "_handle"
  let
    init_name = newIdentNode "open_" & $soname & "_library"
    deinit_name = newIdentNode "close_" & $soname & "_library"
    dlerror_name = newIdentNode "last_" & $soname & "_error"
    dlerror_str = "last_" & $soname & "_error"

  let
    procs = create_global_vars body
    pvars = create_casts(libhandle, body)
    nills = create_nils body

  quote do:
    var `libhandle`: LibHandle = nil

    `procs`

    proc `dlerror_name`*(): string {.inline.} =
      ##  Return a human-readable string describing the error that occured
      ##  from a call to `open_name_library()` or empty string on no error.
      ##
      ##  The returned string does not include a trailing newline.
      ##
      ##  On POSIX it returns:
      ##    - "libname.so: cannot open shared object file: No such file or directory"
      ##    - "/lib/path/libname.so: undefined symbol: foo"
      ##
      ##  On Windows it returns:
      ##    - "Module not found." -- DLL was not found.
      ##    - "Procedure not found."  -- A function/variable was not found in DLL.
      ##                                 No additional information is supplied.
      error_message()

    proc `init_name`*(): bool =
      ##  Open library.
      if `libhandle` == nil:
        for path in `libpaths`:
          when defined uselogging:
            try:
              debug "dlutils: Loading ", `soname` , " library, path ", path
            except:
              discard
          `libhandle` = loadLib path
          if `libhandle` != nil:
            break
        if `libhandle` == nil:
          when defined uselogging:
            try:
              error "dlutils: Failed to load ", `soname`, " library: ",
                    `dlerror_name`()
            except:
              discard
          return false
        `pvars`
      true

    proc `deinit_name`*() =
      ##  Close library.
      when defined uselogging:
        try:
          debug "dlutils: Closing ", `soname`, " library"
        except:
          discard
      if `libhandle` != nil:
        `nills`
        `libhandle`.unloadLib
        `libhandle` = nil

    proc dlerror*(): string {.deprecated: "Use " & `dlerror_str` & " instead.".} =
      `dlerror_name`()

template dlgencalls*(name: static string, libpath: static string,
                     body: untyped): untyped =
  ##  Create `open_name_library(): bool`, `close_name_library()`,
  ##  `last_name_error(): string` and C procedures/variables declared in `body`.
  ##
  ##  Accepts single library path.
  ##
  ##  See `dlgencalls <#dlgencalls,staticstring,staticopenArray[string],untyped>`_ for details.
  dlgencalls name, [libpath], body

# vim: set sts=2 et sw=2:
