# Package dlutils.

version       = "1.0.0"
author        = "Amun-Ra"
description   = "Package for easy shared library loading"
license       = "MIT"
srcDir        = "src"

import std/os
import std/strformat
from std/algorithm import sorted
from std/sequtils import toSeq

task examples, "build examples":
  const optflags = when defined release: " -d=release --opt=speed" else: ""
  for entry in (thisDir() / "examples").walkDir.toSeq.sorted:
    if entry.kind == pcFile and entry.path.endswith ".nim":
      # exec "nimble" & optflags & " --silent c " & entry.path
      exec "nimble" & optflags & " c " & entry.path

task gendoc, "build documentation":
  const
    project = projectName()
    docdir  = &"/tmp/{project}-docs"
    docopts = "--hint=Conf=off --hint=SuccessX=off --github.commit=master"
  var ghopts = ""
  if "GITHUB_BASEURL".getEnv != "":
    ghopts = &" --github.url=" & "GITHUB_BASEURL".getEnv & "/{project}"
  let mainfile = thisDir() / srcDir / &"{project}.nim"
  if not docdir.dirExists:
    mkDir docdir
  exec &"nim doc {docopts} {ghopts} --index=on --project -o={docdir} {mainfile}"
  exec &"mv -f '{docdir}/{project}.html' '{docdir}/index.html'"

# vim: set sts=2 et sw=2:
