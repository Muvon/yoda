.PHONY: check

INSTALL_TO=/opt/yoda
BUILD_DIR=build

check:
	which docker

install:
	@echo "Installing Yoda into "$(INSTALL_TO)
	mkdir -p $(INSTALL_TO)
	cp -r * $(INSTALL_TO)
	echo "#!/usr/bin/env bash" > /usr/local/bin/yoda
	echo "exec $(INSTALL_TO)/yoda \"$$"'@'"\"" >> /usr/local/bin/yoda
	chmod +x /usr/local/bin/yoda

uninstall:
	@echo "Uninstalling Yoda from $(INSTALL_TO)"
	rm -fr "$(INSTALL_TO)"
