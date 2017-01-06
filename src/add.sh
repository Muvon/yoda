#!/usr/bin/env bash
set -e

name="$*"
container_path="$DOCKER_ROOT/containers/$name"
if [[ -d $container_path ]]; then
  echo "Container exists: '$name'. Skipping: '$container_path'."
  exit 0
fi

mkdir -p $container_path
sed "s/%name%/$name/g" $YODA_PATH/templates/container.yml > $container_path/container.yml
cp $YODA_PATH/templates/entrypoint $container_path
sed "s/^dev\:\(.*\)/dev\:\1 $name/" $DOCKER_ROOT/Envfile > $DOCKER_ROOT/.Envfile.swp && mv $DOCKER_ROOT/.Envfile.swp $_
