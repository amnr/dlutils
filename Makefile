# Makefile for nimble project.

all: build

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
