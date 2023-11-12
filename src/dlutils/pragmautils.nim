##  Pragma utils.
#
#   Version: Version: 2022-04-11

import std/macros

proc pragmas*(n: NimNode): seq[string] =
  ##  Returns object `n` pragmas as a seq of strings.
  runnableExamples:
    type Obj = object
    var o: Obj
    macro check(t: typed): untyped =
      assert t.pragmas == newSeq[string]()
    check o

  runnableExamples:
    template custompragma() {.pragma.}
    type Obj {.packed, custompragma.} = object
    var o: Obj
    macro check(t: typed): untyped =
      assert t.pragmas == @["packed", "custompragma"]
    check o

  n.getType.expectKind nnkObjectTy
  # impl = PragmaExpr
  #   Sym "Obj"
  #   Pragma
  #     Sym "be"
  #     Sym "le"
  let impl = n.getType.getTypeInst.getImpl[0]
  if impl.kind == nnkPragmaExpr:
    for row in impl[1].children:
      # Nim pragma: nnkIdent, custom pragma: nnkSym.
      row.expectKind {nnkIdent, nnkSym}
      result.add $row

proc pragmas*(n: NimNode, field_name: string): seq[string] =
  ##  Returns object's field `field_name` pragmas as a seq of strings.
  runnableExamples:
    type Obj = object
      a: byte
      b*: uint32
    var o: Obj
    macro check(t: typed): untyped =
      assert t.pragmas("a") == newSeq[string]()
      assert t.pragmas("b") == newSeq[string]()
    check o

  runnableExamples:
    template custompragma() {.pragma.}
    type Obj = object
      a {.custompragma, deprecated.}: byte
      b* {.custompragma, deprecated.}: uint32
    var o: Obj
    macro check(t: typed): untyped =
      assert t.pragmas("a") == @["custompragma", "deprecated"]
      assert t.pragmas("b") == @["custompragma", "deprecated"]
    check o

  n.getType.expectKind nnkObjectTy
  #[
  TypeDef
    PragmaExpr
      Sym "Obj"
      Pragma
        Sym "be"
    Empty
    ObjectTy
      Empty
      Empty
      RecList
        IdentDefs … IdentDefs
  ]#
  let impl = n.getType.getTypeInst.getImpl
  # echo impl.treeRepr
  impl.expectKind nnkTypeDef
  impl[2].expectkind nnkObjectTy
  impl[2][2].expectKind nnkRecList
  for idef in impl[2][2].children:
    case idef[0].kind
    of nnkIdent:
      # a: byte
      #
      # IdentDefs:
      #   Ident "a"
      #   Sym "byte"
      #   Empty
      idef[0].expectKind nnkIdent
      if $idef[0] != field_name:
        continue
      return
    of nnkPostfix:
      # a*: byte
      #
      # IdentDefs:
      #   Postfix:
      #     Ident "*"
      #     Ident "a"
      #   Sym "byte"
      #   Empty
      idef[0][1].expectKind nnkIdent
      if $idef[0][1] != field_name:
        continue
      return
    of nnkPragmaExpr:
      # a* {.be.}: uint16       a {.be.}: uint16
      #
      # IdentDefs:              IdentDefs:
      #   PragmaExpr:             PragmaExpr:
      #     Postfix:
      #       Ident "*",            Ident "a",
      #       Ident "b"
      #     Pragma:                 Pragma:
      #       Sym "be"                Sym "be"
      #                               Sym …
      #   Sym "uint16"            Sym "uint16"
      #   Empty                   Empty
      case idef[0][0].kind
      of nnkIdent:
        idef[0][0].expectKind nnkIdent
        if $idef[0][0] != field_name:
          continue
        for pr in idef[0][1].children:
          pr.expectKind {nnkIdent, nnkSym}  # Nim pragma, custom pragma.
          result.add $pr
      of nnkPostfix:
        idef[0][0][1].expectKind nnkIdent
        if $idef[0][0][1] != field_name:
          continue
        for pr in idef[0][1].children:
          pr.expectKind {nnkIdent, nnkSym}  # Nim pragma, custom pragma.
          result.add $pr
      else:
        error("should never happen: " & $idef[0][0].kind, n)
    else:
      error("should never happen: " & $idef[0].kind, n)

# vim: set sts=2 et sw=2:
