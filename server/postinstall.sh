#!/usr/bin/env bash
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
# shellcheck disable=SC2016  # $(hostname)/$PS1 must stay literal: they expand in the remote zshrc
echo 'export PS1="[$(hostname)] $PS1"' >> ~/.zshrc

