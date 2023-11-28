# Makefile for nimble project.

NIM       ?= nim
NIMBLE    ?= nimble
TESTAMENT ?= testament
RMDIR     ?= rmdir
PYTHON    ?= python3

PACKAGE_NAME = $(basename $(wildcard *.nimble))

EXAMPLES ?= $(patsubst %.nim, %, $(wildcard examples/*.nim))

ifeq ($(VERBOSE),1)
V :=
else
V := @
endif

.DEFAULT_GOAL := help

# $(VERBOSE).SILENT:

all:

.PHONY: help
help:
	@echo "Usage: $(MAKE) <target>"
	@echo
	@echo "Targets:"
	@grep -E '^[a-z]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "    \033[36m%-10s\033[0m %s\n", $$1, $$2}'

.PHONY: help
help2:
	$(info Usage: $(MAKE) <target>)
	$(info )
	$(info Targets:)
	@awk 'BEGIN {FS = ":.*?##"} \
		/^[a-zA-Z0-9_-]+:.*?##/ { printf "    \033[36m%-10s\033[0m %s\n", $$1, $$2 } \
		/^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) }' \
		$(MAKEFILE_LIST)

.PHONY: check
check:	## verify nimble package
	$(V)$(NIMBLE) check
	$(V)$(NIM) check --hint:name:off --styleCheck=hint src/$(PACKAGE_NAME).nim

.PHONY: examples
examples:
	$(V)echo $(EXAMPLES)

.PHONY: test
test:	## run tests
	$(V)$(TESTAMENT) pattern 'tests/test_*.nim'

.PHONY: doc
doc:	## generate package documentation
	$(V)$(NIMBLE) gendoc

.PHONY: install
install:	## install the package
	$(V)$(NIMBLE) install

.PHONY:
force-install:
	$(V)$(NIMBLE) install -y

.PHONY:
reinstall:
	$(V)$(NIMBLE) uninstall $(PACKAGE_NAME)
	$(V)$(NIMBLE) install

.PHONY: clean
clean:
	-$(V)$(RM) $(basename $(wildcard tests/*/test_*.nim))
	-$(V)$(RM) tests/megatest.nim tests/megatest

.PHONY: distclean
distclean: clean
	-$(V)$(RM) -rf nimcache/
	-$(V)$(RM) -rf testresults/
	-$(V)$(RM) outputExpected.txt outputGotten.txt testresults.html

.PHONY:
serve:
	$(V)$(PYTHON) -m http.server -d /tmp/nimdoc

arch: clean
	$(V)set -e; \
		project=`basename \`pwd\``; \
		timestamp=`date '+%Y-%m-%d-%H%M%S'`; \
		destfile=../$$project-$$timestamp.tar.zst; \
		tar -C .. -caf $$destfile $$project && chmod 444 $$destfile; \
		echo -n "$$destfile" | xclip -selection clipboard -i; \
		echo "Archive is $$destfile"

# vim: set ts=8 noet sw=8:
