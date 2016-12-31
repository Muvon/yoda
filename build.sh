#!/usr/bin/env bash
for line in "$(cat $DOCKER_ROOT/images/Buildfile)"; do
  name=${line%%:*}
  build_args=${line#*:}
  docker build "$build_args" -f "$DOCKER_ROOT/images/Dockerfile-$name" .
done
