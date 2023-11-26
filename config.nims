# config.nims.

switch "hint", "name:off"

if not defined release:
  switch "hint", "CondTrue:on"
  switch "hint", "CondFalse:on"
  switch "hint", "ConvFromXtoItselfNotNeeded:on"
  switch "hint", "ConvToBaseNotNeeded:on"
  switch "hint", "DuplicateModuleImport:on"
  switch "hint", "ExprAlwaysX:on"
  switch "hint", "LineTooLong:on"
  switch "hint", "Performance:on"

switch "spellSuggest", "auto"
switch "styleCheck", "hint"

# vim: set sts=2 et sw=2:
