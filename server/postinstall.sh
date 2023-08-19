#!/usr/bin/env bash
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
echo 'export PS1="[$(hostname)] $PS1"' >> ~/.zshrc

