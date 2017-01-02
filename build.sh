#!/usr/bin/env bash
for line in "$(cat $DOCKER_ROOT/images/Buildfile)"; do
  image=$(eval echo $line | grep -Eo '\-t [^ ]+' | cut -d' ' -f2)
  image_id=$(docker images -q $image)
  if [[ -z "$image_id" ]]; then
    name=${line%%:*}
    build_args=${line#*:}
    docker build $(eval echo $build_args) -f "$DOCKER_ROOT/images/Dockerfile-$name" .
  else
    echo "Image '$image' is already exist."
  fi
done
