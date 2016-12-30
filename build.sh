#!/usr/bin/env bash
lock_file=$DOCKER_ROOT/.build.lock
lock() {
  touch $lock_file
}

unlock() {
  test -f $lock_file && rm -f $_
}

if [[ -f $lock_file ]]; then
  echo "Build is already in progress."
  echo "If something went wrong you should just remove lock file: $lock_file"
  exit 1
fi

trap unlock EXIT
lock

for line in "$(cat $DOCKER_ROOT/images/Buildfile)"; do
  name=${line%%:*}
  build_args=${line#*:}
  echo "$DOCKER_ROOT/images/Dockerfile-$name"
  docker build "$build_args" -f "$DOCKER_ROOT/images/Dockerfile-$name" .
done
