.PHONY: check
BASH_EXISTS := $(shell which bash)
SHELL := $(shell which bash)
YODA_DIR := $(shell pwd)
INSTALL_TO = /usr/local/bin
IF_VER_GT = $(shell echo -e "$2\n$1" | sort -ct. -k1,1n -k2,2n && echo "OK" || exit 1)
BASH_VERSION := $(shell echo $${BASH_VERSION%%.*})
DOCKER_VERSION := $(shell docker version -f '{{.Server.Version}}' | cut -d. -f-2)
DOCKER_COMPOSE_VERSION := $(shell docker-compose --version | cut -d' ' -f3 | cut -d. -f-2)
GIT_VERSION := $(shell git version | cut -d' ' -f3)

check:
	which docker
	which docker-compose
	which bash
	which sed
	which grep
	which tput
	test -n 'bash >= 4' -a -n "$(call IF_VER_GT, $(BASH_VERSION), 4)"
	test -n 'docker >= 1.13' -a -n "$(call IF_VER_GT, $(DOCKER_VERSION), 1.13)"
	test -n 'docker-compose >= 1.12' -a -n "$(call IF_VER_GT, $(DOCKER_COMPOSE_VERSION), 1.12)"
	test -n 'git >= 1.9' -a -n "$(call IF_VER_GT, $(GIT_VERSION), 1.9)"

install:
	@echo "Installing Yoda to "$(INSTALL_TO)
	ln -fs $(YODA_DIR)/yoda $(INSTALL_TO)/yoda
