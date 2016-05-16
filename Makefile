.PHONY: check
YODA_DIR=$(shell pwd)

check:
	which docker
	which bash

install:
	echo "#!/usr/bin/env bash" > /usr/local/bin/yoda
	echo "exec $(YODA_DIR)/yoda \"$$"'@'"\"" >> /usr/local/bin/yoda
	chmod +x /usr/local/bin/yoda
