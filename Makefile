# Makefile for nimble project.

NIM ?= nim

MAIN_SOURCE ?= $(wildcard src/*.nim)

all:
	@$(NIM) check --styleCheck=hint --hint:name:off $(MAIN_SOURCE)

build:
	@nimble build

check:
	@nimble check

test:
	@nimble test

install:
	@nimble install

.PHONY: clean
clean:

# vim: set ts=4 noet sw=4:
