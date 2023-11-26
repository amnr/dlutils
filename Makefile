# Makefile for nimble project.

NIMBLE ?= nimble
NIM ?= nim

MAIN_SOURCE ?= $(wildcard src/*.nim)

ifeq ($(VERBOSE),1)
V :=
else
V := @
endif

all:
	$(V)$(NIM) check --styleCheck=hint --hint:name:off $(MAIN_SOURCE)

build:
	$(V)$(NIMBLE) build

check:
	$(V)$(NIMBLE) check

test:
	$(V)$(NIMBLE) test

.PHONY: doc
doc:
	$(V)$(NIMBLE) gendoc

.PHONY: install
install:
	$(V)$(NIMBLE) install

.PHONY:
force-install:
	$(V)$(NIMBLE) install -y

.PHONY:
reinstall:
	$(V)$(NIMBLE) uninstall dlutils
	$(V)$(NIMBLE) install

.PHONY: clean
clean:

# vim: set ts=4 noet sw=4:
