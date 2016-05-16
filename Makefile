.PHONY: check
YODA_DIR=$(shell pwd)

check:
	which docker
	which bash
	ls ~/.bashrc

install:
	echo "export PATH=$$"'PATH'":$(YODA_DIR)/bin" >> ~/.bashrc
	source ~/.bashrc
