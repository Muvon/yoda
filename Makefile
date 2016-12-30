.PHONY: check
YODA_DIR=$(shell pwd)
INSTALL_TO=/usr/local/bin

check: SHELL:=/bin/bash
check:
	which docker
	which docker-compose
	which bash
	which sed

install:
	@echo "Installing Yoda to "$(INSTALL_TO)
	ln -fs $(YODA_DIR)/yoda $(INSTALL_TO)/yoda
