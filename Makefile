.PHONY: check
BASH_EXISTS := $(shell which bash)
SHELL := $(shell which bash)
YODA_DIR := $(shell pwd)
INSTALL_TO = /usr/local/bin
BASH_VERSION_OK := $(shell test "$${BASH_VERSION//[!0-9]/}" -gt 4 && echo 1 || echo 0)

check:
	which docker
	which docker-compose
	which bash
	which sed
	which awk
	which grep
	test $(BASH_VERSION_OK) -eq 1 || exit 1

install:
	@echo "Installing Yoda to "$(INSTALL_TO)
	ln -fs $(YODA_DIR)/yoda $(INSTALL_TO)/yoda
