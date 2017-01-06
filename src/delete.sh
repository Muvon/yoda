#!/usr/bin/env bash
set -e

name="$*"
container_path="$DOCKER_ROOT/containers/$name"
test -d $container_path && rm -fr $_
sed "s/ $name/ /" $DOCKER_ROOT/Envfile > $DOCKER_ROOT/.Envfile.swp && mv $DOCKER_ROOT/.Envfile.swp $_
